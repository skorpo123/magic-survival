shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float size: hint_range(0.0, 1.0) = 0.5;
uniform float force: hint_range(0.0, 100.0) = 15.0;
uniform float thickness: hint_range(0.0, 1.0) = 0.15;
uniform float aberration: hint_range(0.0, 0.5) = 0.03;

void fragment() {
	float dist = distance(UV, vec2(0.5)) * 2.0;
	float ring = 1.0 - smoothstep(0.0, thickness, abs(dist - size));
	vec2 dir = normalize(UV - vec2(0.5));
	if (length(UV - vec2(0.5)) < 0.001) dir = vec2(1.0, 0.0);
	vec2 offset_uv = dir * force * ring * SCREEN_PIXEL_SIZE;
	float r = texture(screen_texture, SCREEN_UV + offset_uv * (1.0 + aberration)).r;
	float g = texture(screen_texture, SCREEN_UV + offset_uv).g;
	float b = texture(screen_texture, SCREEN_UV + offset_uv * (1.0 - aberration)).b;
	COLOR = vec4(r, g, b, 1.0);
}
