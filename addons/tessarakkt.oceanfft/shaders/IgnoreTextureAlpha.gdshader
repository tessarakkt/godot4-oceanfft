shader_type canvas_item;

void fragment() {
	COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0);
}
