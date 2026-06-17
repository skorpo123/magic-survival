shader_type canvas_item;

void fragment() {
	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float vignette = 1.0 - dot(center, center) * 8.5;
	vignette = clamp(vignette, 0.0, 1.0);
	float core_glow = smoothstep(0.5, 0.0, dist) * 0.2;
	vec3 core_col = mix(vec3(0.7, 0.1, 0.05), COLOR.rgb, 0.3) * core_glow;
	COLOR.rgb = COLOR.rgb * vignette + core_col;
}
