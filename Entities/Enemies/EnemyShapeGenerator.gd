class_name EnemyShapeGenerator extends RefCounted

static func generate_shape(radius: float, vein_count: int = 3) -> ImageTexture:
	var tex_size := int(radius * 2.0 * 4.0)
	var center := tex_size / 2.0
	var draw_radius := radius * 4.0
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var point_count := 16
	var rng := RandomNumberGenerator.new()
	rng.seed = randi()

	var radii: Array[float] = []
	for i in range(point_count):
		radii.append(draw_radius * rng.randf_range(0.65, 1.0))

	for px in range(tex_size):
		for py in range(tex_size):
			var dx := px - center
			var dy := py - center
			var dist := Vector2(dx, dy).length()
			var angle := atan2(dy, dx)
			if angle < 0:
				angle += TAU

			var t := (angle / TAU) * point_count
			var idx := int(t) % point_count
			var next_idx := (idx + 1) % point_count
			var frac := t - int(t)
			var edge_r := lerpf(radii[idx], radii[next_idx], frac)

			if dist <= edge_r:
				var edge_factor := dist / maxf(edge_r, 1.0)
				var body := 0.08 + 0.07 * (1.0 - edge_factor)
				var r := body * 0.6
				var g := body * 0.55
				var b := body * 0.75
				img.set_pixel(px, py, Color(r, g, b, 1.0))

	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = rng.randi()
	detail_noise.fractal_octaves = 2
	detail_noise.frequency = 0.08
	for px in range(tex_size):
		for py in range(tex_size):
			var existing := img.get_pixel(px, py)
			if existing.a < 0.1:
				continue
			var n := detail_noise.get_noise_2d(px, py) * 0.5 + 0.5
			var detail := n * 0.06
			img.set_pixel(px, py, Color(existing.r + detail, existing.g + detail * 0.8, existing.b + detail, existing.a))

	for v in range(vein_count):
		var start_angle := rng.randf() * TAU
		var start_r := draw_radius * rng.randf_range(0.1, 0.4)
		var cx := center + cos(start_angle) * start_r
		var cy := center + sin(start_angle) * start_r
		var angle := start_angle + rng.randf_range(-0.5, 0.5)
		var vein_length := rng.randf_range(draw_radius * 0.5, draw_radius * 1.2)
		var width_base := rng.randf_range(2.0, 4.0)

		for step in range(int(vein_length)):
			var progress := step / vein_length
			var w := width_base * (1.0 - progress * 0.6)
			for sx in range(-int(w), int(w) + 1):
				for sy in range(-int(w), int(w) + 1):
					var px := int(cx + sx)
					var py := int(cy + sy)
					if px < 0 or px >= tex_size or py < 0 or py >= tex_size:
						continue
					var existing := img.get_pixel(px, py)
					if existing.a < 0.1:
						continue
					var dist_from_center := Vector2(sx, sy).length()
					var falloff := maxf(0.0, 1.0 - dist_from_center / maxf(w, 1.0))
					falloff = pow(falloff, 0.7)
					var fade := 1.0 - progress * 0.7
					var vein_strength := falloff * fade * 0.85
					var r := lerpf(existing.r, 0.85, vein_strength)
					var g := lerpf(existing.g, 0.9, vein_strength)
					var b := lerpf(existing.b, 0.95, vein_strength)
					img.set_pixel(px, py, Color(r, g, b, existing.a))

			angle += rng.randf_range(-0.4, 0.4)
			cx += cos(angle) * 2.0
			cy += sin(angle) * 2.0

	for px in range(tex_size):
		for py in range(tex_size):
			var existing := img.get_pixel(px, py)
			if existing.a < 0.1:
				continue
			var dx := px - center
			var dy := py - center
			var dist := Vector2(dx, dy).length()
			var glow_dist := dist - draw_radius * 0.7
			if glow_dist > 0.0 and glow_dist < draw_radius * 0.4:
				var glow := (1.0 - glow_dist / (draw_radius * 0.4)) * 0.08
				img.set_pixel(px, py, Color(existing.r + glow, existing.g + glow * 0.3, existing.b + glow * 0.6, existing.a))

	var tex := ImageTexture.create_from_image(img)
	return tex
