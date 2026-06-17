class_name PickupVisualGenerator extends RefCounted

static func generate_orb(color: Color = Color(0.3, 0.8, 1.0), size: int = 24) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := size / 2.0

	for px in range(size):
		for py in range(size):
			var dx := px - center
			var dy := py - center
			var dist := Vector2(dx, dy).length()
			var max_r := center - 1.0
			if dist <= max_r:
				var t := 1.0 - dist / max_r
				var core := pow(t, 4.0)
				var glow := pow(t, 0.4) * 0.6
				var r := color.r * glow + core
				var g := color.g * glow + core
				var b := color.b * glow + core
				var a := clampf(glow + core, 0.0, 1.0)
				img.set_pixel(px, py, Color(minf(r, 1.0), minf(g, 1.0), minf(b, 1.0), a))

	return ImageTexture.create_from_image(img)
