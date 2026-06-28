shader_type canvas_item;

uniform float start_y: hint_range(0, 1) = .3;
uniform float strength: hint_range(0, 1) = .15;
uniform float curve_scale: hint_range(0, 3) = 1.5;
uniform float speed : hint_range(0, 10) = 2;
uniform float wind_start: hint_range(-1.57, 1.57) = 0;
varying vec4 v_color;

void vertex() {
    v_color = COLOR;
    float scale = (pow(2.0, curve_scale) * strength * 2.0);
    VERTEX *= 1. + scale;
}

void fragment() {
    float scale = (pow(2.0, curve_scale) * strength * 2.0);
	float total_scale = 1.0 + scale;
	vec2 local_uv = (UV - REGION_RECT.xy) / REGION_RECT.zw;
	vec2 adjusted_local_uv = (local_uv - 0.5) * total_scale + 0.5;
	
	vec2 wind_uv = adjusted_local_uv;
	wind_uv.x += sin(TIME * speed + wind_start) * smoothstep(start_y , 1. + start_y , pow((1. - wind_uv.y),  .5 )) * pow((1. - wind_uv.y + 1.), curve_scale) * strength;
	if (wind_uv.x < 0.0 || wind_uv.x > 1.0 || wind_uv.y < 0.0 || wind_uv.y > 1.0) {
		discard;
	}
   
	vec2 wind_final_uv = wind_uv * REGION_RECT.zw + REGION_RECT.xy;
	COLOR = texture(TEXTURE, wind_final_uv) * v_color;
}
