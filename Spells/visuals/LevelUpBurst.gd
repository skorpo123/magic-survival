extends Node2D

var _lifetime: float = 0.0
var _max_lifetime: float = 0.7
var vfx_key: String = ""

static var _shared_mat: CanvasItemMaterial = null

func _ready() -> void:
	z_index = 6
	material = _get_shared_mat()

static func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _shared_mat

func reset() -> void:
	_lifetime = 0.0

func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= _max_lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := _lifetime / _max_lifetime
	var fade := 1.0 - t

	draw_circle(Vector2.ZERO, 30.0 * (1.0 + t * 4.0), Color(1.0, 0.6, 2.0, fade * 0.15))
	draw_circle(Vector2.ZERO, 18.0 * (1.0 + t * 3.0), Color(1.2, 0.8, 2.0, fade * 0.3))

	draw_arc(Vector2.ZERO, 25.0 * (1.0 + t * 2.5), 0.0, TAU, 24, Color(1.4, 1.0, 2.0, fade * 0.5), 3.0 * fade, true)
	draw_arc(Vector2.ZERO, 35.0 * (1.0 + t * 2.0), 0.0, TAU, 24, Color(1.8, 1.4, 2.0, fade * 0.3), 2.0 * fade, true)

	for i in range(16):
		var angle := TAU * i / 16.0 + _lifetime * 5.0
		var dist := 15.0 + t * 55.0
		var pos := Vector2.RIGHT.rotated(angle) * dist
		draw_circle(pos, 2.5 * fade, Color(0.7, 0.5, 1.0, fade * 0.7))

	for i in range(8):
		var angle := TAU * i / 8.0 - _lifetime * 3.0
		var dist := 8.0 + t * 25.0
		var pos := Vector2.RIGHT.rotated(angle) * dist
		draw_circle(pos, 1.5 * fade, Color(1.0, 0.85, 0.4, fade * 0.9))

	if t < 0.15:
		var flash_t := t / 0.15
		draw_circle(Vector2.ZERO, 28.0 * (1.0 - flash_t), Color(0.9, 0.8, 1.0, (1.0 - flash_t) * 0.7))
