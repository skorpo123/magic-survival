shader_type canvas_item;

uniform sampler2D spritesheet;
uniform float frame_count = 4.0;
uniform float anim_fps = 10.0;
uniform float game_time = 0.0;

void fragment() {
	float phase = COLOR.a * frame_count;
	float frame = floor(mod(game_time * anim_fps + phase, frame_count));
	vec2 uv = UV;
	uv.x = (frame + uv.x) / frame_count;
	vec4 tex = texture(spritesheet, uv);
	if (tex.a < 0.05) discard;
	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float vignette = 1.0 - dot(center, center) * 8.5;
	vignette = clamp(vignette, 0.0, 1.0);
	float core_glow = smoothstep(0.55, 0.0, dist) * 0.25;
	vec3 base_col = tex.rgb * COLOR.rgb * 3.0 * vignette;
	vec3 core_col = mix(vec3(0.8, 0.15, 0.05), COLOR.rgb, 0.4) * core_glow;
	vec3 col = base_col + core_col;
	COLOR = vec4(col, 1.0);
}
