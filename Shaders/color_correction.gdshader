shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.1;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.7;

void fragment() {
	vec4 color = texture(screen_tex, SCREEN_UV);
	color.rgb = (color.rgb - 0.5) * contrast + 0.5;
	float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(vec3(luma), color.rgb, saturation);
	vec2 uv = SCREEN_UV - 0.5;
	float dist = length(uv);
	float vig = smoothstep(vignette_radius, vignette_radius - 0.35, dist);
	color.rgb *= mix(1.0, vig, vignette_strength);
	COLOR = color;
}
