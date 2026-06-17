class_name RefractionBolt
extends Node2D

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 450.0
var _damage: float = 0.0
var _lifetime: float = 1.8
var _age: float = 0.0
var _homing_strength: float = 4.5
var _color: Color = Color(1.0, 0.85, 0.3)
var _trail: PackedVector2Array = PackedVector2Array()

static var _shared_mat: CanvasItemMaterial = null

func _ready() -> void:
	top_level = true
	z_index = 4
	material = _get_shared_mat()

static func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _shared_mat

func launch(pos: Vector2, dir: Vector2, damage: float, color: Color = Color(1.0, 0.85, 0.3)) -> void:
	global_position = pos
	_direction = dir.normalized()
	_damage = damage
	_color = color
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	_age = 0.0
	_trail.clear()
	set_process(true)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return

	_trail.append(global_position)
	if _trail.size() > 6:
		_trail.remove_at(0)

	var best_pos := _find_closest_enemy_pos()
	if best_pos != Vector2.ZERO:
		var desired := (best_pos - global_position).normalized()
		_direction = _direction.move_toward(desired, _homing_strength * delta)

	global_position += _direction * _speed * delta

	var killed := SwarmManager.damage_area(global_position, 14.0, _damage)
	killed += EnemyMeshManager.damage_area(global_position, 14.0, _damage)
	if killed > 0:
		JuiceManager.spawn_attack_flash(global_position, _color)
		queue_free()
		return
	queue_redraw()

func _find_closest_enemy_pos() -> Vector2:
	var best_pos: Vector2 = Vector2.ZERO
	var min_dist: float = 550.0
	var swarm_pos: Vector2 = SwarmManager.find_closest_pos(global_position, 550.0)
	if swarm_pos != Vector2.ZERO:
		min_dist = global_position.distance_to(swarm_pos)
		best_pos = swarm_pos
	var mesh_pos: Vector2 = EnemyMeshManager.find_closest_pos(global_position, 550.0)
	if mesh_pos != Vector2.ZERO:
		var mesh_dist: float = global_position.distance_to(mesh_pos)
		if mesh_dist < min_dist:
			best_pos = mesh_pos
	return best_pos

func _draw() -> void:
	var alpha := 1.0 - clampf(_age / _lifetime, 0.0, 1.0)
	var head := _direction * 8.0
	draw_line(Vector2.ZERO, head, Color(_color.r, _color.g, _color.b, alpha * 0.7), 5.0, true)
	draw_line(Vector2.ZERO, head, Color(1.0, 1.0, 1.0, alpha * 0.9), 2.0, true)
	for i in range(_trail.size()):
		var t := float(i) / float(maxf(_trail.size(), 1))
		var tp := _trail[i] - global_position
		draw_circle(tp, 3.0 * t, Color(_color.r * 0.5, _color.g * 0.5, _color.b * 0.5, alpha * 0.3 * t))
