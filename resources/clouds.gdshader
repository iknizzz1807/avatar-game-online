shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D mask_texture : repeat_enable, filter_nearest;
uniform vec2 speed = vec2(0.05, 0.02);

void fragment() {
	vec4 alphaMask = texture(mask_texture, UV);
	vec2 noise_uv = UV + TIME * speed;
	vec4 cloud_color = texture(noise_texture, noise_uv);
	cloud_color.a *= alphaMask.a;
	COLOR = cloud_color;
}
