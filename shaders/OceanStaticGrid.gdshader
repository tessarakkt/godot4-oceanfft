shader_type spatial;
render_mode world_vertex_coords;


uniform sampler2D displacement:hint_default_black,repeat_enable;
uniform sampler2D normal_map:hint_normal,repeat_enable;

uniform vec4 deep_color:source_color;
uniform vec4 shallow_color:source_color;

uniform float sss_strength = 2.0;

uniform float uv_scale = 1.0;
uniform float wind_angle = 0.0;
uniform vec2 wind_uv_offset = vec2(0.0, 0.0);


varying vec3 camera_vector;
varying vec3 world_normal;
varying mat3 invview3;


void vertex() {
	float angle = wind_angle;
	float costheta = cos(angle);
	float sintheta = sin(angle);

	vec2 rotated_uv = vec2((UV.x - 0.5) * costheta - (UV.y - 0.5) * sintheta,
			(UV.y - 0.5) * costheta + (UV.x - 0.5) * sintheta) + wind_uv_offset;

	vec3 rotated_displacement = texture(displacement, rotated_uv * uv_scale).rgb;
	//rotated_displacement.xz = vec2((rotated_displacement.x - 0.5) * costheta - (rotated_displacement.z - 0.5) * sintheta,
	//		(rotated_displacement.z - 0.5) * costheta + (rotated_displacement.x - 0.5) * sintheta);
	
	vec3 rotated_normal = texture(normal_map, rotated_uv * uv_scale).rgb;
	//rotated_normal.xz = vec2((rotated_normal.x - 0.5) * costheta - (rotated_normal.z - 0.5) * sintheta,
	//		(rotated_normal.z - 0.5) * costheta + (rotated_normal.x - 0.5) * sintheta);
	
	// TODO: Correct horizontal displacement and normal maps when rotated
	VERTEX += rotated_displacement;
	NORMAL = rotated_normal;
}


void fragment() {
	invview3 = mat3(INV_VIEW_MATRIX);
	
	camera_vector = normalize((VERTEX * invview3) - CAMERA_POSITION_WORLD);
	world_normal = NORMAL * invview3;
	
	ALBEDO = deep_color.rgb;
	ROUGHNESS = 0.02;
	SPECULAR = 1.0;
	//NORMAL_MAP = normalize(texture(normal_map, UV).rgb - NORMAL);
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