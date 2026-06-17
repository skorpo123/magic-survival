shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D shadow_tex : repeat_disable, filter_linear;
uniform vec4 shadow_color : source_color = vec4(0.03, 0.03, 0.03, 0.7);

void fragment() {
	vec4 tex = texture(shadow_tex, UV);
	COLOR = vec4(shadow_color.rgb, tex.a * shadow_color.a);
}
