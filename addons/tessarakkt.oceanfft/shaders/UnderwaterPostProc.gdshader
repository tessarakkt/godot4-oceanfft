shader_type canvas_item;

uniform sampler2D screen_texture:hint_screen_texture,repeat_disable,filter_nearest;
uniform sampler2D noise_texture:repeat_enable;
uniform float distortion_speed = 5;
uniform float distortion_amount = 1;

void fragment(){
	vec3 noise = texture(noise_texture, SCREEN_UV + (TIME / 100.0 * distortion_speed)).rgb;
	vec3 color = texture(screen_texture, SCREEN_UV + (noise.b / 100.0 * distortion_amount)).rgb;

	COLOR.rgb = color;
}