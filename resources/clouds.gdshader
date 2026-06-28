shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform vec2 speed = vec2(0.05, 0.02);

void fragment() {
    vec2 noise_uv = UV + TIME * speed;
    vec4 cloud_color = texture(noise_texture, noise_uv);
    vec4 base = texture(TEXTURE, UV) * COLOR;
    COLOR = cloud_color;
}
