shader_type spatial;
render_mode world_vertex_coords;


uniform float fft_resolution = 256.0;
uniform sampler2D displacement_cascade0:hint_default_black,repeat_enable;
uniform sampler2D displacement_cascade1:hint_default_black,repeat_enable;
uniform sampler2D displacement_cascade2:hint_default_black,repeat_enable;

uniform vec4 deep_color:source_color;
uniform vec4 shallow_color:source_color;

uniform float sss_strength = 2.0;
uniform float planetary_curve_strength = 0.000001;

uniform float uv_scale = 1.0;
uniform vec2 wind_uv_offset = vec2(0.0, 0.0);


varying vec3 camera_vector;
varying vec3 world_normal;
varying mat3 invview3;


vec3 get_displacement(vec2 uv) {
	vec3 displacement = vec3(0.0);

	displacement += texture(displacement_cascade0, uv * uv_scale + wind_uv_offset).rgb;
	displacement += texture(displacement_cascade1, uv * uv_scale + wind_uv_offset * 0.7).rgb;
	displacement += texture(displacement_cascade2, uv * uv_scale + wind_uv_offset * 0.3).rgb;
	
	return displacement;
}


void vertex() {
	// Vertex Offset
	// Use the world vertex XZ coordinates as UV for simplicity
	vec3 displacement = get_displacement(VERTEX.xz);
	
	// Planetary Curve
	// Take distance squared from camera to vertex, multiply by strength factor,
	// subtract from vertex Y.
	float curvation = planetary_curve_strength * (pow(VERTEX.x - CAMERA_POSITION_WORLD.x, 2.0) + pow(VERTEX.z - CAMERA_POSITION_WORLD.z, 2.0));
	
	VERTEX += displacement;
	VERTEX.y -= curvation;
	
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
	invview3 = mat3(INV_VIEW_MATRIX);
	
	camera_vector = normalize((VERTEX * invview3) - CAMERA_POSITION_WORLD);
	world_normal = NORMAL * invview3;
	
	ALBEDO = deep_color.rgb;
	ROUGHNESS = 0.02;
	SPECULAR = 1.0;
}


void light() {
	float fresnel = 1.0 - abs(dot(world_normal, camera_vector));
	
	// Specular
	float spec = clamp(pow(dot(reflect(LIGHT, NORMAL), -VIEW), 1500.0), 0.0, 1.0);
	float spec_glare = clamp(pow(dot(reflect(LIGHT, NORMAL), -VIEW), 850.0), 0.0, 1.0) * 1.0;
	SPECULAR_LIGHT += (LIGHT_COLOR * ALBEDO * ATTENUATION / PI) * clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * fresnel;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * (spec + spec_glare) * fresnel;
	
	// Sub Surface Scattering
	float sss = clamp(smoothstep(0.65, 0.7, dot(NORMAL, VIEW) * 0.5 + 0.5) * smoothstep(0.5, 1.0, dot(-LIGHT, VIEW) * 0.5 + 0.5) * (dot(-invview3[2].xyz, vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5), 0.0, 1.0) * sss_strength;
	SPECULAR_LIGHT += (LIGHT_COLOR * ALBEDO * ATTENUATION / PI) * sss;
}