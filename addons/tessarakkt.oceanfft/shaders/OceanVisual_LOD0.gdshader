shader_type spatial;
render_mode world_vertex_coords, depth_draw_always, cull_disabled;


const int CASCADE_COUNT = 3;


uniform float fft_resolution = 256.0;
uniform sampler2D cascade_displacements[CASCADE_COUNT];
uniform float cascade_uv_scales[CASCADE_COUNT];
uniform float cascade_steepness_scales[CASCADE_COUNT];
uniform float cascade_amplitude_scales[CASCADE_COUNT];

uniform float amplitude_scale_min = 0.25;
uniform float amplitude_scale_max = 1.0;
uniform float amplitude_scale_fade_distance = 12000.0;

uniform vec4 deep_color:source_color = vec4(0.004f, 0.016f, 0.047f, 1.0);
uniform vec4 shallow_color:source_color = vec4(0, 0.729412, 0.988235, 1);
uniform vec4 sky_color:source_color = vec4(1.6f, 4.8f, 6.4f, 1.0);
uniform float background_color_brightness = 0.2;

uniform float sss_backlight_strength = 0.0125;
uniform float sss_backlight_fov = 10.0;
uniform float sss_backlight_depth = 15.0;
uniform float sss_upwelling = 0.075;
uniform float sss_bubbles_density = 1.0;
uniform vec4 scatter_color:source_color = vec4(0, 0.729412, 0.988235, 1);
uniform vec4 bubbles_color:source_color;

uniform float planetary_curve_strength = 0.000001;

uniform float metallic_strength = 0.1;

uniform float fresnel_offset = 0.02;
uniform float fresnel_strength = 0.02;
uniform float fresnel_power = 5.0;

uniform float exposure = 0.03;

uniform float specular_strength = 1.0;
uniform float specular_power = 1500.0;

// Adjusts how strong the refraction is based on the distance between the ocean
// pixel and the object behind it.
uniform float refraction_depth_factor = 0.00001;

uniform float refraction_factor_min = 0.0;
uniform float refraction_factor_max = 0.025;

uniform float refraction_distance_power = 1.55;
uniform float refraction_distance_max = 10000.0;

uniform float uv_scale = 0.001953125;
uniform vec2 wind_uv_offset = vec2(0.0, 0.0);

uniform float view_distance_max = 16000.0;
uniform float view_fade_start = 0.05;

uniform float foam_strength_pre = 0.1;
uniform float foam_strength_post = 0.5;
uniform float foam_jacobian_limit = -0.1;
uniform sampler2D foam_texture : hint_default_white;

uniform float normal_factor = 1.0;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

instance uniform float patch_size = 512.0;
instance uniform float vertex_resolution = 256.0;
instance uniform float min_lod_morph_distance;
instance uniform float max_lod_morph_distance;

varying vec3 world_vertex;
varying float jacobian_determinant;
varying float wave_height;
varying float foam_mix_factor;


// Get the total wave displacement of a vertex from all cascades.
// TODO: Move scaling operations to compute shader for performance. As the
//       displacement map is tiled, doing this calcuation in the compute shader
//       that generates the map will avoid duplicate calculations done here.
vec3 get_displacement(vec2 uv) {
	vec3 displacement = vec3(0.0);
	
	for (int i = 0; i < CASCADE_COUNT; i++) {
		displacement += textureLod(cascade_displacements[i],
				uv * uv_scale * (1.0 / cascade_uv_scales[i]) + wind_uv_offset * cascade_uv_scales[i], 1.0).rgb
				* vec3(cascade_steepness_scales[i], cascade_amplitude_scales[i], 1.0);
	}
	
	return displacement;
}


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
	
	// Vertex Offset
	// Use the world vertex XZ coordinates as UV for simplicity
	vec3 displacement = get_displacement(VERTEX.xz);
	
	// Planetary Curve
	// Take distance squared from camera to vertex, multiply by strength factor,
	// subtract from vertex Y.
	float curvation = planetary_curve_strength * (pow(VERTEX.x - CAMERA_POSITION_WORLD.x, 2.0) + pow(VERTEX.z - CAMERA_POSITION_WORLD.z, 2.0));
	
	VERTEX += displacement;
	VERTEX.y -= curvation;
	
	world_vertex = VERTEX;
	
	// Surface Normals
	float offset = 1.0 / (fft_resolution * (1.0 / fft_resolution));
	
	vec3 right = (vec3(offset, get_displacement(VERTEX.xz + vec2(offset, 0.0)).y, 0.0)) - displacement;
	vec3 left = (vec3(-offset, get_displacement(VERTEX.xz + vec2(-offset, 0.0)).y, 0.0)) - displacement;
	vec3 bottom = (vec3(0.0, get_displacement(VERTEX.xz + vec2(0.0, offset)).y, offset)) - displacement;
	vec3 top = (vec3(0.0, get_displacement(VERTEX.xz + vec2(0.0, -offset)).y, -offset)) - displacement;
	
	vec3 top_right = cross(right, top);
	vec3 top_left = cross(top, left);
	vec3 bottom_left = cross(left, bottom);
	vec3 bottom_right = cross(bottom, right);
	
	NORMAL = normalize(top_right + top_left + bottom_left + bottom_right) * normal_factor;
	
	// Jacobian Determinant
	// Used for foam/whitecap rendering
	float jxx = right.x / offset;
	float jxy = right.y / offset;
	float jyx = bottom.x / offset;
	float jyy = bottom.y / offset;
	jacobian_determinant = (jxx * jyy) - (jxy * jyx);
	
	// Wave Amplitude Distance Fade
	// Flattens the waves with increasing distance from camera. This is done
	// after surface normal calculations to retain normals in the distance.
	float amplitude_fade_range = clamp(linear_dist, 0.0, amplitude_scale_fade_distance) / amplitude_scale_fade_distance;
	VERTEX.y *= mix(amplitude_scale_max, amplitude_scale_min, amplitude_fade_range);
}


void fragment() {
	// Calculate fragments Fresnel factor
	float fresnel = pow(1.0 - dot(NORMAL, normalize(VIEW)), fresnel_power) * fresnel_strength + fresnel_offset;
	
	// Get the linear depth between each ocean pixel and whatever is behind it.
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV * 2.0 - 1.0, depth), 1.0);
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
	vec3 water_color = mix(background_color * shallow_color.rgb * background_color_brightness, deep_color.rgb, refraction_blend_factor * (1.0 - fresnel));
	
	// Fresnel Shading
	vec3 sky = sky_color.rgb * fresnel;
	vec3 water = (1.0 - fresnel) * water_color * sky_color.rgb;
	water_color = HDR(sky + water, exposure);
	
	// Whitecap Rendering
	foam_mix_factor = clamp((-jacobian_determinant + foam_jacobian_limit) * foam_strength_pre, 0.0, 1.0);
	foam_mix_factor = (foam_mix_factor * foam_mix_factor) * foam_strength_post;
	ALBEDO = mix(water_color, texture(foam_texture, world_vertex.xz * uv_scale).rgb, foam_mix_factor);
	
	// Distance Fade
	float fade_start = view_distance_max * (1.0 - view_fade_start);
	ALPHA = 1.0 - (clamp(linear_dist, fade_start, view_distance_max) - fade_start) / (view_distance_max - fade_start);
	
	// Misc. PBR Settings
	ROUGHNESS = foam_mix_factor * 0.5;
	METALLIC = metallic_strength;
	SPECULAR = 0.0;
	
	wave_height = world_vertex.y;
}


void light() {
	vec3 half_vector = normalize(LIGHT + VIEW);
	
	// Specular
	float spec = clamp(pow(dot(NORMAL, half_vector), specular_power), 0.0, 1.0) * specular_strength;
	SPECULAR_LIGHT += (LIGHT_COLOR * ALBEDO * ATTENUATION / PI) * clamp(dot(NORMAL, half_vector), 0.0, 1.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec;
	
	// Sub Surface Scattering
	vec3 sss_sun_light = scatter_color.rgb * ATTENUATION;
	
	// SSS Wave Backlight
	float sss = sss_backlight_strength * max(0.0, wave_height + sss_backlight_depth) * pow(max(0.0, dot(-LIGHT, VIEW)), 4.0);
	sss *= pow(0.5 - 0.5 * dot(-LIGHT, half_vector), 3.0);
	sss *= sss_backlight_fov * pow(max(0.0, dot(VIEW, half_vector)) , 2.0);
	vec3 sss_result = sss * sss_sun_light;
	
	// SSS Upwelling Light
	sss_result += sss_upwelling * max(0.0, dot(LIGHT, half_vector)) * sss_sun_light;
	
	// SSS Bubbles Contribution
	sss_result += sss_bubbles_density * foam_mix_factor * bubbles_color.rgb * ATTENUATION;
	SPECULAR_LIGHT += sss_result;
}