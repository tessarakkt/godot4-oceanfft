shader_type spatial;
render_mode cull_disabled;

uniform float border_size = 0.01;

instance uniform vec3 albedo = vec3(1.0, 1.0, 1.0);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ALBEDO = albedo;
	if (UV.x < border_size || UV.x > 1.0 - border_size || UV.y < border_size || UV.y > 1.0 - border_size) {
		ALPHA = 1.0;
	} else {
		//ALBEDO = vec3(1.0);
		ALPHA = 0.1;
	}
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
