shader_type spatial;
render_mode world_vertex_coords;


uniform float fft_resolution = 256.0;
uniform sampler2D displacement:hint_default_black,repeat_enable;

uniform vec4 deep_color:source_color;
uniform vec4 shallow_color:source_color;

uniform float sss_strength = 2.0;

uniform float uv_scale = 1.0;
uniform float wind_angle = 0.0;
uniform vec2 wind_uv_offset = vec2(0.0, 0.0);


varying vec3 camera_vector;
varying vec3 world_normal;
varying mat3 invview3;


vec3 rotate_y(vec3 vector, float sintheta, float costheta) {
	return vec3(
		vector.x * costheta - vector.z * sintheta,
		vector.y,
		vector.z * costheta + vector.x * sintheta
	);
}


vec3 get_rotated_displacement(vec2 rotated_uv, float sintheta, float costheta) {
	return rotate_y(texture(displacement, rotated_uv * uv_scale).rgb, sintheta, costheta);
}


void vertex() {
	float costheta = cos(wind_angle);
	float sintheta = sin(wind_angle);
	
	// Vertex Offset
	vec2 rotated_uv = vec2((UV.x - 0.5) * costheta - (UV.y - 0.5) * sintheta,
			(UV.y - 0.5) * costheta + (UV.x - 0.5) * sintheta) + wind_uv_offset;
	vec3 rotated_displacement = get_rotated_displacement(rotated_uv, sintheta, costheta);
	
	VERTEX += rotated_displacement;
	
	// Surface Normals
	float offset = 1.0 / (fft_resolution * uv_scale);
	
	vec3 right = vec3(1.0, get_rotated_displacement(rotated_uv + vec2(offset, 0.0), sintheta, costheta).y, 0.0) - rotated_displacement;
	vec3 left = vec3(-1.0, get_rotated_displacement(rotated_uv + vec2(-offset, 0.0), sintheta, costheta).y, 0.0) - rotated_displacement;
	vec3 bottom = vec3(0.0, get_rotated_displacement(rotated_uv + vec2(0.0, offset), sintheta, costheta).y, 1.0) - rotated_displacement;
	vec3 top = vec3(0.0, get_rotated_displacement(rotated_uv + vec2(0.0, -offset), sintheta, costheta).y, -1.0) - rotated_displacement;
	
	vec3 top_right = cross(right, top);
	vec3 top_left = cross(top, left);
	vec3 bottom_left = cross(left, bottom);
	vec3 bottom_right = cross(bottom, right);
	
	NORMAL = normalize(rotate_y(top_right + top_left + bottom_left + bottom_right, sin(-wind_angle), cos(-wind_angle)));
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