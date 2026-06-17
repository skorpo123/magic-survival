extends Node2D

var _phase: float = 0.0

func _process(delta: float) -> void:
	var player := GameManager.get_player()
	if not player or not is_instance_valid(player):
		visible = false
		return
	global_position = player.global_position
	_phase += delta * 3.0
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(_phase) * 0.1
	var outer_r := 18.0 * pulse
	var inner_r := 9.0 * pulse
	draw_circle(Vector2.ZERO, outer_r, Color(0.2, 0.5, 1.0, 0.08 * pulse))
	draw_circle(Vector2.ZERO, inner_r, Color(0.4, 0.7, 1.0, 0.15 * pulse))
