class_name BossShockwave extends ColorRect

var _tween: Tween = null
var _canvas_layer: CanvasLayer = null

func play(world_pos: Vector2, duration: float = 0.5, shock_radius: float = 0.0) -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 50
	get_tree().current_scene.add_child(_canvas_layer)

	var cam := _get_camera()
	var viewport := get_viewport_rect()
	var screen_pos: Vector2
	if cam:
		screen_pos = (world_pos - cam.global_position) + viewport.size * 0.5
	else:
		screen_pos = world_pos
	var base_size := 300.0
	var rect_size := base_size if shock_radius <= 0.0 else maxf(shock_radius * 2.0, base_size)

	global_position = screen_pos - Vector2(rect_size, rect_size) * 0.5
	custom_minimum_size = Vector2(rect_size, rect_size)
	size = Vector2(rect_size, rect_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	material = ShaderMaterial.new()
	material.shader = preload("res://Effects/shockwave.gdshader")
	material.set_shader_parameter("size", 0.0)
	material.set_shader_parameter("force", 15.0)
	material.set_shader_parameter("thickness", 0.2)
	material.set_shader_parameter("aberration", 0.03)

	if get_parent():
		get_parent().remove_child(self)
	_canvas_layer.add_child(self)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(material, "shader_parameter/size", 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(material, "shader_parameter/force", 0.0, duration).set_ease(Tween.EASE_OUT)
	_tween.tween_property(material, "shader_parameter/thickness", 0.02, duration).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_on_finished)

func _on_finished() -> void:
	if _canvas_layer:
		_canvas_layer.queue_free()

func _get_camera() -> Camera2D:
	var player := GameManager.get_player()
	if player:
		return player.get_node_or_null("Camera2D") as Camera2D
	return null
