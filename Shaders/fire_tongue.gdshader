shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale = 5.0;
uniform float wobble_speed = 6.0;
uniform float wobble_amount = 0.12;
uniform float flicker_speed = 10.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;

	float wobble = sin(uv.y * 6.0 + TIME * wobble_speed) * wobble_amount * (1.0 - uv.y * 0.7);
	uv.x += wobble;

	float n1 = vnoise(uv * noise_scale + vec2(0.0, TIME * flicker_speed));
	float n2 = vnoise(uv * noise_scale * 2.0 + vec2(3.0, TIME * flicker_speed * 1.3));
	float noise = n1 * 0.6 + n2 * 0.4;

	vec3 red_color = vec3(0.9, 0.15, 0.0);
	vec3 orange_color = vec3(1.0, 0.5, 0.05);
	vec3 yellow_color = vec3(1.0, 0.9, 0.3);
	vec3 blue_color = vec3(0.3, 0.5, 1.0);
	vec3 white_color = vec3(1.0, 0.95, 0.8);

	float heat_t = progress + noise * 0.15;
	heat_t = clamp(heat_t, 0.0, 1.0);

	vec3 flame_color;
	if (heat_t < 0.3) {
		flame_color = mix(red_color, orange_color, heat_t / 0.3);
	} else if (heat_t < 0.55) {
		flame_color = mix(orange_color, yellow_color, (heat_t - 0.3) / 0.25);
	} else if (heat_t < 0.8) {
		flame_color = mix(yellow_color, white_color, (heat_t - 0.55) / 0.25);
	} else {
		flame_color = mix(white_color, blue_color, (heat_t - 0.8) / 0.2);
	}

	flame_color *= 1.0 + noise * 0.4;

	float edge_fade = smoothstep(0.0, 0.2, uv.x) * smoothstep(1.0, 0.8, uv.x);
	float tip_fade = pow(1.0 - uv.y, 0.3);
	float base_fade = smoothstep(0.0, 0.05, uv.y);

	float alpha = edge_fade * tip_fade * base_fade * (0.65 + noise * 0.35);

	COLOR.rgb = flame_color;
	COLOR.a = alpha;
}
