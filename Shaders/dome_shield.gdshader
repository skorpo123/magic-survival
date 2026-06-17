shader_type canvas_item;

uniform vec2 player_pos : hint_screen_position = vec2(0.0, 0.0);
uniform float shield_radius : hint_range(10.0, 200.0) = 72.0;
uniform vec4 dome_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float alpha_base : hint_range(0.0, 1.0) = 0.10;
uniform float alpha_edge : hint_range(0.0, 1.0) = 0.40;
uniform float fresnel_power : hint_range(0.5, 5.0) = 2.5;

// Hit flash
uniform vec2 hit_pos = vec2(-1000.0, -1000.0);
uniform float hit_time = -1.0;
uniform float hit_radius : hint_range(10.0, 200.0) = 80.0;
uniform float hit_duration : hint_range(0.1, 2.0) = 0.35;

void fragment() {
	vec2 frag_pos = FRAGCOORD.xy;
	float d = distance(frag_pos, player_pos);
	float t = d / shield_radius;

	if (t > 1.0) {
		COLOR = vec4(0.0);
		return;
	}

	float dome_alpha = mix(alpha_base, alpha_edge, smoothstep(0.55, 1.0, t));
	float edge_fresnel = pow(1.0 - t, fresnel_power);
	dome_alpha += edge_fresnel * 0.35;
	float inner_glow = smoothstep(0.8, 0.0, t) * 0.08;
	dome_alpha += inner_glow;
	dome_alpha = clamp(dome_alpha, 0.0, 1.0);

	float hit_contribution = 0.0;
	if (hit_time >= 0.0 && hit_time < hit_duration) {
		float progress = hit_time / hit_duration;
		float wave_r = progress * hit_radius;
		float dh = distance(frag_pos, hit_pos);
		float ring_width = 10.0 * (1.0 - progress * 0.5);
		float ring = smoothstep(wave_r - ring_width, wave_r, dh) 
		           - smoothstep(wave_r, wave_r + ring_width, dh);
		hit_contribution = ring * (1.0 - progress) * 0.8;
	}

	float final_alpha = clamp(dome_alpha + hit_contribution, 0.0, 1.0);
	COLOR = vec4(dome_color.rgb, final_alpha);
}
