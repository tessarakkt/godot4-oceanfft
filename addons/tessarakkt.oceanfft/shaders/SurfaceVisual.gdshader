shader_type spatial;
render_mode world_vertex_coords, depth_draw_always, cull_disabled;


#include "OceanCommon.gdshaderinc"


// Sun specular highlight
uniform float specular_strength = 1.0;
uniform float specular_power = 1500.0;

// ALPHA will begin decreasing to 0.0 after view_distance_max * view_fade_start
uniform float view_fade_start = 0.95;

// Colors
uniform vec4 deep_color:source_color = vec4(0.004f, 0.016f, 0.047f, 1.0);
uniform vec4 shallow_color:source_color = vec4(0, 0.729412, 0.988235, 1);


group_uniforms Fresnel;
/******************************************************************************/
// Note that PBR specular and metallic settings can significantly affect the
// result of fresnel shading. Consider playing with those settings if fresnel
// shading can't be made to look proper with just these settings.

// Fresnel Shading
uniform float fresnel_offset = 0.02;
uniform float fresnel_strength = 0.0;
uniform float fresnel_power = 5.0;
uniform float fresnel_exposure = 0.03;
uniform vec4 fresnel_sky_color:source_color = vec4(1.6f, 4.8f, 6.4f, 1.0);


group_uniforms PhysicallyBasedRendering;
/******************************************************************************/
uniform float pbr_specular_strength = 0.1;
uniform float pbr_specular_offset = 0.1;
uniform float pbr_metallic_strength = 0.0;


group_uniforms Refraction;
/******************************************************************************/
// TODO: Needs to be completely redone;

uniform float refraction_factor_min = 0.0;
uniform float refraction_factor_max = 0.025;
uniform float refraction_distance_power = 1.55;
uniform float refraction_distance_max = 30000.0;
uniform float refraction_background_brightness = 0.2;

// Adjusts how strong the refraction is based on the distance between the ocean
// pixel and the object behind it.
uniform float refraction_depth_factor = 0.00001;


group_uniforms SubSurfaceScattering;
/******************************************************************************/
uniform float sss_backlight_strength = 0.0125;
uniform float sss_backlight_fov = 10.0;
uniform float sss_backlight_depth = 15.0;
uniform float sss_upwelling = 0.075;
uniform vec4 sss_color:source_color = vec4(0, 0.729412, 0.988235, 1);


group_uniforms Whitecaps;
/******************************************************************************/
// Basic whitecap rendering using Jacobian determinant.
// TODO: Calculate Jacobian and foam in another shader to support temporal
//       effects like foam persisting and bubbling out.

uniform float foam_jacobian_limit = 0.5;
uniform float foam_coverage = 0.1;
uniform float foam_mix_strength = 1.0;
uniform float foam_diffuse_strength = 1.0;
uniform vec4 foam_diffuse_color:source_color = vec4(0.91764706373215, 0.96862745285034, 1.0, 1.0);
uniform sampler2D foam_texture : hint_default_white;


group_uniforms Internal;
/******************************************************************************/
// These are intended to be updated during runtime. Setting values in the editor
// may not have the desired result.

// The vertex resolution of the mesh tiles the shader is applied to.
uniform float vertex_resolution = 256.0;


group_uniforms Internal.WaveDeformModifiers;
/******************************************************************************/
// Adjust the wave displacement maps as they are applied to the surface.
// This will be correctly accounted for by normals and whitecaps.
// Settings will only affect buoyancy if set through Ocean3D

// Simple planetary curve approximation.
// Decrease height of surface exponentially as distance from camera increases.
uniform float planetary_curve_strength = 0.000001;

// Decreases the height of the wave deformation as distance from the camera
// increases.
// This occurs after surface normals and whitecap coverage has been calculated.
uniform float amplitude_scale_min = 0.25;
uniform float amplitude_scale_max = 1.0;
uniform float amplitude_scale_fade_distance = 12000.0;


uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;


// Instance Uniforms
/******************************************************************************/
instance uniform float patch_size = 512.0;
instance uniform float min_lod_morph_distance;
instance uniform float max_lod_morph_distance;


// Varyings
/******************************************************************************/
varying vec3 world_vertex;
varying float jacobian_determinant;
varying float wave_height;
varying float foam_mix_factor;
varying float foam_specular_factor;


vec2 lod_morph(float morph_factor, vec2 grid_pos) {
	vec2 fracPart = fract(grid_pos.xy * vertex_resolution * 0.5) * 2.0 / vertex_resolution;
	return fracPart * patch_size * morph_factor;
}


vec3 HDR(vec3 color, float e) {
	return 1.0 - exp(-color * e);
}


void vertex() {
	float linear_dist = length(VERTEX - CAMERA_POSITION_WORLD);
	
	// LOD Morph
	float morph_factor = (clamp(linear_dist, min_lod_morph_distance, max_lod_morph_distance) - min_lod_morph_distance) / (max_lod_morph_distance - min_lod_morph_distance);
	VERTEX.xz -= lod_morph(morph_factor, UV);
	
	// Domain Warp
	vec2 domain_warped_uv = domain_warp(VERTEX.xz, linear_dist);
	
	// Vertex Offset
	// Use the world vertex XZ coordinates as UV for simplicity
	vec3 displacement = get_displacement(domain_warped_uv);
	VERTEX += displacement;
	world_vertex = VERTEX;
	
	// Surface Normals & Jacobian
	vec4 nj = get_normals_jacobian(domain_warped_uv, displacement);
	NORMAL = nj.xyz * normal_factor;
	jacobian_determinant = nj.w;
	
	// Wave Amplitude Distance Fade
	// Flattens the waves with increasing distance from camera. This is done
	// after surface normal calculations to retain normals in the distance.
	float amplitude_fade_range = clamp(linear_dist, 0.0, amplitude_scale_fade_distance) / amplitude_scale_fade_distance;
	VERTEX.y *= mix(amplitude_scale_max, amplitude_scale_min, amplitude_fade_range);
	
	// Planetary Curve
	// Take distance squared from camera to vertex, multiply by strength factor,
	// subtract from vertex Y.
	float curvation = planetary_curve_strength * (pow(abs(domain_warped_uv.x - CAMERA_POSITION_WORLD.x), 2.0) + pow(abs(domain_warped_uv.y - CAMERA_POSITION_WORLD.z), 2.0));
	VERTEX.y -= curvation;
}


void fragment() {
	// Calculate fragments Fresnel factor
	float fresnel_factor = clamp(pow(abs(1.0 - dot(NORMAL, normalize(VIEW))), fresnel_power), -1.0, 1.0);
	float fresnel = fresnel_factor * fresnel_strength + fresnel_offset;
	
	// Get the linear depth between each ocean pixel and whatever is behind it.
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV, depth), 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	
	// Get the distance between the camera and each ocean pixel.
	float linear_dist = length(world_vertex - CAMERA_POSITION_WORLD);
	
	// Refraction, based on depth between ocean pixel and object behind.
	// Fades out with distance so as to be smooth transition to lower LOD shaders
	// which may exclude this.
	float refraction_factor = clamp(linear_depth * refraction_depth_factor, refraction_factor_min, refraction_factor_max);
	vec2 refracted_uv = SCREEN_UV - NORMAL.xz * refraction_factor;
	vec3 background_color = textureLod(screen_texture, refracted_uv, 0.0).rgb;
	float refraction_blend_factor = clamp(pow(linear_depth, refraction_distance_power), 0.0, refraction_distance_max) / refraction_distance_max;
	vec3 water_color = mix(background_color * shallow_color.rgb * refraction_background_brightness, deep_color.rgb, refraction_blend_factor * (1.0 - fresnel));
	
	// Fresnel Shading
	vec3 sky = fresnel_sky_color.rgb * fresnel;
	vec3 water = (1.0 - fresnel) * water_color * fresnel_sky_color.rgb;
	water_color = HDR(sky + water, fresnel_exposure);
	
	// Whitecap Rendering
	foam_mix_factor = clamp((-jacobian_determinant + foam_jacobian_limit) * foam_coverage, 0.0, 1.0);
	foam_mix_factor = (foam_mix_factor * foam_mix_factor) * foam_mix_strength;
	ALBEDO = mix(water_color, texture(foam_texture, world_vertex.xz * uv_scale).rgb, foam_mix_factor);
	foam_specular_factor = (1.0 - foam_mix_factor);
	
	// Distance Fade
	float fade_start = view_distance_max * view_fade_start;
	ALPHA = 1.0 - (clamp(linear_dist, fade_start, view_distance_max) - fade_start) / (view_distance_max - fade_start);
	
	// Misc. PBR Settings
	ROUGHNESS = foam_mix_factor + 0.02;
	METALLIC = pbr_metallic_strength * foam_specular_factor;
	SPECULAR = pbr_specular_strength * foam_specular_factor * fresnel_factor + pbr_specular_offset;
	
	wave_height = world_vertex.y;
}


void light() {
	vec3 half_vector = normalize(LIGHT + VIEW);
	
	// Specular
	float spec = clamp(pow(dot(NORMAL, half_vector), specular_power), 0.0, 1.0) * specular_strength;
	SPECULAR_LIGHT += (LIGHT_COLOR * ALBEDO * ATTENUATION / PI) * clamp(dot(NORMAL, half_vector), 0.0, 1.0) * foam_specular_factor;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * foam_specular_factor;
	
	// Sub Surface Scattering
	vec3 sss_sun_light = sss_color.rgb * ATTENUATION;
	
	// SSS Wave Backlight
	float sss = sss_backlight_strength * max(0.0, wave_height + sss_backlight_depth) * pow(max(0.0, dot(-LIGHT, VIEW)), 4.0);
	sss *= pow(0.5 - 0.5 * dot(-LIGHT, half_vector), 3.0);
	sss *= sss_backlight_fov * pow(max(0.0, dot(VIEW, half_vector)) , 2.0);
	vec3 sss_result = sss * sss_sun_light;
	
	// SSS Upwelling Light
	sss_result += sss_upwelling * max(0.0, dot(LIGHT, half_vector)) * sss_sun_light;
	SPECULAR_LIGHT += sss_result * foam_specular_factor;
	
	// Foam Lighting
	DIFFUSE_LIGHT += foam_diffuse_strength * foam_mix_factor * foam_diffuse_color.rgb * ATTENUATION;
}