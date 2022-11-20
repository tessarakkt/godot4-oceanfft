shader_type spatial;
render_mode world_vertex_coords;

uniform sampler2D displacement:hint_default_black,repeat_enable;
uniform sampler2D normal_map:hint_normal;

uniform vec4 deep_color:source_color;
uniform vec4 shallow_color:source_color;

uniform float uv_scale = 1.0;

varying vec3 camera_vector;


float fresnel(float n1, float n2, float cos_theta) {
	float R0 = pow((n1 - n2) / (n1 + n2), 2);
	return R0 + (1.0 - R0) * pow(1.0 - cos_theta, 5);
}


void vertex() {
	VERTEX += texture(displacement, UV * uv_scale).rgb;
	NORMAL = texture(normal_map, UV * uv_scale).rgb;
	camera_vector = normalize(VERTEX - CAMERA_POSITION_WORLD);
}


void fragment() {
	float cam_dot_normal = dot(camera_vector, NORMAL);
	float n1 = 1.0, n2 = 1.33333;
	float fres = fresnel(n1, n2, abs(cam_dot_normal));
	
	ALBEDO = deep_color.rgb;
	ROUGHNESS = 0.02 * fres;
	SPECULAR = 1.0;
	//NORMAL_MAP = normalize(texture(normal_map, UV).rgb - NORMAL);
}
