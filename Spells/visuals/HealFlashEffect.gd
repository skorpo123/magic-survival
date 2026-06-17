extends Node2D

var _lifetime: float = 0.0
var _max_lifetime: float = 0.45
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
	var expand := 1.0 + t * 2.5

	draw_circle(Vector2.ZERO, 18.0 * expand, Color(0.4, 2.0, 0.8, fade * 0.15))
	draw_circle(Vector2.ZERO, 12.0 * expand, Color(0.7, 2.0, 1.0, fade * 0.25))

	draw_circle(Vector2.ZERO, 3.0 * expand, Color(1.0, 2.0, 1.2, fade * 0.9))
	draw_rect(Rect2(-1.5 * expand, -8.0 * expand, 3.0 * expand, 16.0 * expand), Color(1.0, 2.0, 1.2, fade * 0.65))
	draw_rect(Rect2(-8.0 * expand, -1.5 * expand, 16.0 * expand, 3.0 * expand), Color(1.0, 2.0, 1.2, fade * 0.65))

	draw_arc(Vector2.ZERO, 14.0 * expand, 0.0, TAU, 16, Color(0.3, 0.9, 0.5, fade * 0.35), 2.0 * fade, true)

	for i in range(10):
		var angle := TAU * i / 10.0 + _lifetime * 8.0
		var dist := 10.0 + t * 35.0
		var pos := Vector2.RIGHT.rotated(angle) * dist
		draw_circle(pos, 2.0 * fade, Color(0.4, 1.0, 0.5, fade * 0.7))

	if t < 0.12:
		var flash_t := t / 0.12
		draw_circle(Vector2.ZERO, 22.0 * (1.0 - flash_t), Color(0.85, 1.0, 0.9, (1.0 - flash_t) * 0.6))
