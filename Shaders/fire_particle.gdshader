shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float heat : hint_range(0.0, 3.0) = 2.0;
uniform float noise_scale = 4.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	float n = hash(uv * noise_scale + TIME * 15.0);
	float n2 = hash(uv * noise_scale * 2.0 + TIME * 25.0);

	vec3 hot_color = vec3(1.0, 0.95, 0.4);
	vec3 mid_color = vec3(1.0, 0.55, 0.05);
	vec3 cool_color = vec3(0.9, 0.2, 0.0);

	vec3 flame_color = mix(cool_color, mid_color, uv.y);
	flame_color = mix(flame_color, hot_color, pow(uv.y, 0.4));

	flame_color *= 1.0 + (n + n2) * 0.6;

	float alpha = pow(1.0 - uv.y, 2.5) * (0.6 + n * 0.4);

	COLOR.rgb = flame_color * heat;
	COLOR.a = alpha * texture(TEXTURE, UV).a;
}
