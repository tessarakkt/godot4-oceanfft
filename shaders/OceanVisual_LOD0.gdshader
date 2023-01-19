shader_type spatial;
render_mode world_vertex_coords, depth_draw_always;


const int CASCADE_COUNT = 3;


uniform float fft_resolution = 256.0;
uniform sampler2D cascade_displacements[CASCADE_COUNT];
uniform float cascade_uv_scales[CASCADE_COUNT];
uniform float cascade_steepness_scales[CASCADE_COUNT];
uniform float cascade_amplitude_scales[CASCADE_COUNT];

uniform vec4 deep_color:source_color;
uniform vec4 shallow_color:source_color;
uniform float background_color_brightness = 0.3;

uniform float sss_strength = 1.5;
uniform float planetary_curve_strength = 0.000001;

uniform float fresnel_strength = 0.3;
uniform float fresnel_power = 5.0;
uniform float fresnel_limit = 0.7;

uniform float specular_strength = 0.75;
uniform float specular_power = 500.0;

// Adjusts how strong the refraction is based on the distance between the ocean
// pixel and the object behind it.
uniform float refraction_depth_factor = 0.00001;

// Adjusts how much the refracted image is blended with the base water color
// based on the distance from the cameras Z Near plane to the ocean pixel.
uniform float refraction_distance_factor = 0.0025;

uniform float refraction_factor_min = 0.0;
uniform float refraction_factor_max = 0.025;

uniform float refraction_blend_factor_min = 0.6;
uniform float refraction_blend_factor_max = 1.0;

uniform float uv_scale = 0.00390625;
uniform vec2 wind_uv_offset = vec2(0.0, 0.0);

uniform float view_distance_max = 16000.0;
uniform float view_fade_start = 0.005;

instance uniform float patch_size = 512.0;
instance uniform float vertex_resolution = 256.0;
instance uniform float min_lod_morph_distance;
instance uniform float max_lod_morph_distance;

varying mat3 invview3;
varying vec3 world_vertex;


// Get the total wave displacement of a vertex from all cascades.
vec3 get_displacement(vec2 uv) {
	vec3 displacement = vec3(0.0);
	
	for (int i = 0; i < CASCADE_COUNT; i++) {
		displacement += texture(cascade_displacements[i],
				uv * uv_scale * (1.0 / cascade_uv_scales[i]) + wind_uv_offset * cascade_uv_scales[i]).rgb
				* vec3(cascade_steepness_scales[i], cascade_amplitude_scales[i], 1.0);
	}
	
	return displacement;
}


vec2 lod_morph(float morph_factor, vec2 grid_pos) {
	vec2 fracPart = fract(grid_pos.xy * vertex_resolution * 0.5) * 2.0 / vertex_resolution;
	return fracPart * patch_size * morph_factor;
}


void vertex() {
	// LOD Morph
	float morph_factor = (clamp(length(VERTEX - CAMERA_POSITION_WORLD), min_lod_morph_distance, max_lod_morph_distance) - min_lod_morph_distance) / (max_lod_morph_distance - min_lod_morph_distance);
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
	float offset = 1.0 / (fft_resolution * uv_scale);
	
	vec3 right = vec3(1.0, get_displacement(VERTEX.xz + vec2(offset, 0.0)).y, 0.0) - displacement;
	vec3 left = vec3(-1.0, get_displacement(VERTEX.xz + vec2(-offset, 0.0)).y, 0.0) - displacement;
	vec3 bottom = vec3(0.0, get_displacement(VERTEX.xz + vec2(0.0, offset)).y, 1.0) - displacement;
	vec3 top = vec3(0.0, get_displacement(VERTEX.xz + vec2(0.0, -offset)).y, -1.0) - displacement;
	
	vec3 top_right = cross(right, top);
	vec3 top_left = cross(top, left);
	vec3 bottom_left = cross(left, bottom);
	vec3 bottom_right = cross(bottom, right);
	
	NORMAL = normalize(top_right + top_left + bottom_left + bottom_right);
}


void fragment() {
	// Setting this varying is needed in light() for subsurface scattering.
	// Godot bug #67256 prevents accessing this variable directly from light()
	// https://github.com/godotengine/godot/issues/67256
	invview3 = mat3(INV_VIEW_MATRIX);
	
	// Get the linear depth between each ocean pixel and whatever is behind it.
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV * 2.0 - 1.0, depth), 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	
	// Get the distance between the camera and each ocean pixel.
	float linear_dist = length(world_vertex - CAMERA_POSITION_WORLD); //-view_dist.z;
	
	// Refraction, based on depth between ocean pixel and object behind.
	// Fades out with distance so as to be smooth transition to lower LOD shaders
	// which may exclude this.
	float refraction_factor = clamp(linear_depth * refraction_depth_factor, refraction_factor_min, refraction_factor_max);
	float refraction_blend_factor = clamp(linear_dist * refraction_distance_factor, refraction_blend_factor_min, refraction_blend_factor_max);
	vec2 refracted_uv = SCREEN_UV - NORMAL.xz * refraction_factor;
	vec3 background_color = textureLod(SCREEN_TEXTURE, refracted_uv, 0.0).rgb;
	ALBEDO = mix(background_color * background_color_brightness, deep_color.rgb, refraction_blend_factor);
	
	// Distance Fade
	ALPHA = 1.0 - clamp(linear_dist, view_distance_max * view_fade_start, view_distance_max) / view_distance_max;
	
	ROUGHNESS = 0.02;
	SPECULAR = 0.0;
}


void light() {
	float fresnel = pow(fresnel_limit - clamp(dot(NORMAL, normalize(VIEW)), 0.0, fresnel_limit), fresnel_power) * fresnel_strength;
	
	// Specular
	float spec = clamp(pow(dot(reflect(LIGHT, NORMAL), -VIEW), specular_power), 0.0, 1.0) * specular_strength;
	SPECULAR_LIGHT += (LIGHT_COLOR * ALBEDO * ATTENUATION / PI) * clamp(dot(NORMAL, LIGHT), 0.0, 1.0) + fresnel;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec + fresnel;
	
	// Sub Surface Scattering
	float sss = clamp(smoothstep(0.65, 0.7, dot(NORMAL, VIEW) * 0.5 + 0.5) * smoothstep(0.5, 1.0, dot(-LIGHT, VIEW) * 0.5 + 0.5) * (dot(-invview3[2].xyz, vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5), 0.0, 1.0) * sss_strength;
	SPECULAR_LIGHT += (LIGHT_COLOR * ALBEDO * ATTENUATION / PI) * sss;
}