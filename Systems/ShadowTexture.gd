extends RefCounted

const SHADOW_SIZE: int = 32

static var _shadow_tex: ImageTexture = null

static func get_texture() -> Texture2D:
	if _shadow_tex:
		return _shadow_tex
	var img := Image.create(SHADOW_SIZE, SHADOW_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = float(SHADOW_SIZE) * 0.5
	var cy: float = float(SHADOW_SIZE) * 0.5
	var rx: float = float(SHADOW_SIZE) * 0.5
	var ry: float = float(SHADOW_SIZE) * 0.25
	for px in range(SHADOW_SIZE):
		for py in range(SHADOW_SIZE):
			var dx: float = (float(px) - cx) / rx
			var dy: float = (float(py) - cy) / ry
			var dist_sq: float = dx * dx + dy * dy
			if dist_sq <= 1.0:
				var t: float = 1.0 - dist_sq
				var alpha: float = t * t * 0.85
				img.set_pixel(px, py, Color(0, 0, 0, alpha))
	_shadow_tex = ImageTexture.create_from_image(img)
	return _shadow_tex
