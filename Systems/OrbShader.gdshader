shader_type canvas_item;
render_mode blend_add;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;
	if (dist > 1.0) {
		discard;
	}
	float core = 1.0 - smoothstep(0.0, 0.4, dist);
	float glow = 1.0 - smoothstep(0.15, 1.0, dist);
	float alpha = core * 1.0 + glow * 0.6;
	vec3 col = mix(COLOR.rgb * 0.7, COLOR.rgb * 3.0, core);
	COLOR = vec4(col, alpha * COLOR.a);
}
