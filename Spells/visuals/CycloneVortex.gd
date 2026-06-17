class_name CycloneVortex
extends Node2D

signal finished

enum State { GROWING, SUSTAINED, FADING, DONE }

var _direction: Vector2 = Vector2.RIGHT
var _fly_speed: float = 120.0
var _start_radius: float = 15.0
var _max_radius: float = 80.0
var _grow_time: float = 1.0
var _sustain_time: float = 1.5
var _fade_time: float = 0.5
var _damage: float = 8.0
var _damage_interval: float = 0.5
var _damage_timer: float = 0.0
var _rotation_speed: float = 3.0
var _current_radius: float = 15.0
var _age: float = 0.0
var _state: int = State.DONE
var _fade_alpha: float = 1.0
var _seeking: bool = false
var _seek_strength: float = 3.0
var _gravity_pull: bool = false
var _pull_strength: float = 80.0
var _pull_range: float = 200.0
var _sprite_a: Sprite2D = null
var _sprite_b: Sprite2D = null
var _gravity_phase: float = 0.0
var _no_damage: bool = false
var _is_twin: bool = false
var _twin_orbit_phase: float = 0.0
var _twin_orbit_radius: float = 60.0
var _primary_color: Color = Color(0.6, 0.9, 1.0)
var _secondary_color: Color = Color(0.3, 0.6, 0.9)

func _ready() -> void:
	top_level = true
	z_index = 2
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	material = _get_blend_mat()
	_sprite_a = Sprite2D.new()
	_sprite_a.texture = preload("res://Sprites/cyclone_pix.png")
	_sprite_a.z_index = 1
	add_child(_sprite_a)
	_sprite_b = Sprite2D.new()
	_sprite_b.texture = preload("res://Sprites/cyclone_pix.png")
	_sprite_b.z_index = 1
	_sprite_b.modulate = Color(1.2, 1.2, 1.2, 1.0)
	add_child(_sprite_b)

static var _shared_mat: CanvasItemMaterial = null

static func _get_blend_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _shared_mat

func launch(pos: Vector2, direction: Vector2, params: Dictionary) -> void:
	global_position = pos
	_direction = direction.normalized()
	_fly_speed = params.get(&"fly_speed", 120.0)
	_start_radius = params.get(&"start_radius", 15.0)
	_max_radius = params.get(&"max_radius", 80.0)
	_grow_time = params.get(&"grow_time", 1.0)
	_sustain_time = params.get(&"sustain_time", 1.5)
	_fade_time = params.get(&"fade_time", 0.5)
	_damage = params.get(&"damage", 8.0)
	_damage_interval = params.get(&"damage_interval", 0.5)
	_rotation_speed = params.get(&"rotation_speed", 3.0)
	_seeking = params.get(&"seeking", false)
	_seek_strength = params.get(&"seek_strength", 3.0)
	_gravity_pull = params.get(&"gravity_pull", false)
	_pull_strength = params.get(&"pull_strength", 80.0)
	_pull_range = params.get(&"pull_range", 200.0)
	_primary_color = params.get(&"primary_color", _primary_color)
	_secondary_color = params.get(&"secondary_color", _secondary_color)
	_no_damage = params.get(&"no_damage", false)
	_is_twin = params.get(&"is_twin", false)
	_twin_orbit_phase = 0.0
	_current_radius = _start_radius
	_age = 0.0
	_damage_timer = 0.0
	_fade_alpha = 1.0
	_state = State.GROWING
	visible = true
	_sprite_a.scale = Vector2.ONE * (_start_radius * 2.0) / _sprite_a.texture.get_width()
	_sprite_a.modulate = Color(2.0, 2.0, 2.0, 1.0)
	_sprite_a.visible = true
	_sprite_b.scale = Vector2.ONE * (_start_radius * 2.0) / _sprite_b.texture.get_width()
	_sprite_b.modulate = Color(2.4, 2.4, 2.4, 1.0)
	_sprite_b.visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

func update_params(params: Dictionary) -> void:
	_max_radius = params.get(&"max_radius", _max_radius)
	_damage = params.get(&"damage", _damage)
	_damage_interval = params.get(&"damage_interval", _damage_interval)
	_rotation_speed = params.get(&"rotation_speed", _rotation_speed)
	_fly_speed = params.get(&"fly_speed", _fly_speed)
	_seeking = params.get(&"seeking", _seeking)
	_seek_strength = params.get(&"seek_strength", _seek_strength)
	_gravity_pull = params.get(&"gravity_pull", _gravity_pull)
	_pull_strength = params.get(&"pull_strength", _pull_strength)
	_pull_range = params.get(&"pull_range", _pull_range)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_age += delta

	if _is_twin:
		_twin_orbit_phase += _rotation_speed * delta * 1.5
		var offset_a := Vector2(cos(_twin_orbit_phase), sin(_twin_orbit_phase)) * _twin_orbit_radius
		var offset_b := -offset_a
		_sprite_a.position = offset_a
		_sprite_b.position = offset_b
		_sprite_a.rotation += _rotation_speed * delta
		_sprite_b.rotation -= _rotation_speed * delta
		_sprite_a.scale = Vector2.ONE * (_current_radius * 2.0) / _sprite_a.texture.get_width()
		_sprite_b.scale = Vector2.ONE * (_current_radius * 2.0) / _sprite_b.texture.get_width()
	else:
		_sprite_a.position = Vector2.ZERO
		_sprite_b.position = Vector2.ZERO
		_sprite_a.rotation += _rotation_speed * delta
		_sprite_b.rotation += _rotation_speed * delta
		_sprite_a.scale = Vector2.ONE * (_current_radius * 2.0) / _sprite_a.texture.get_width()
		_sprite_b.scale = Vector2.ONE * (_current_radius * 2.0) / _sprite_b.texture.get_width()

	global_position += _direction * _fly_speed * delta

	if _seeking and _state != State.DONE:
		_do_seek(delta)
	if _gravity_pull and _state != State.DONE:
		_gravity_phase += delta * 2.0
		SwarmManager.pull_toward(global_position, _pull_range, _pull_strength * delta)
		EnemyMeshManager.pull_toward(global_position, _pull_range, _pull_strength * delta)

	match _state:
		State.GROWING:
			var t: float = clampf(_age / _grow_time, 0.0, 1.0)
			_current_radius = _start_radius + (_max_radius - _start_radius) * t
			_tick_damage(delta)
			if _age >= _grow_time:
				_current_radius = _max_radius
				_state = State.SUSTAINED
		State.SUSTAINED:
			var sustain_age: float = _age - _grow_time
			_tick_damage(delta)
			if sustain_age >= _sustain_time:
				_state = State.FADING
		State.FADING:
			var fade_age: float = _age - _grow_time - _sustain_time
			var t: float = clampf(fade_age / _fade_time, 0.0, 1.0)
			_fade_alpha = 1.0 - t
			_sprite_a.modulate.a = _fade_alpha
			_sprite_b.modulate.a = _fade_alpha
			_tick_damage(delta)
			if t >= 1.0:
				_state = State.DONE
				visible = false
				_sprite_a.visible = false
				_sprite_b.visible = false
				process_mode = Node.PROCESS_MODE_DISABLED
				finished.emit()
				return
		State.DONE:
			return
	queue_redraw()

func _tick_damage(delta: float) -> void:
	if _no_damage:
		return
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = _damage_interval
		if _is_twin:
			var pos_a: Vector2 = global_position + _sprite_a.position
			var pos_b: Vector2 = global_position + _sprite_b.position
			var r: float = _current_radius * 0.5
			SwarmManager.damage_area(pos_a, r, _damage)
			EnemyMeshManager.damage_area(pos_a, r, _damage)
			SwarmManager.damage_area(pos_b, r, _damage)
			EnemyMeshManager.damage_area(pos_b, r, _damage)
		else:
			SwarmManager.damage_area(global_position, _current_radius, _damage)
			EnemyMeshManager.damage_area(global_position, _current_radius, _damage)

func _draw() -> void:
	if _state == State.DONE:
		return
	if _gravity_pull and _state != State.DONE:
		return
	var spiral_count := 4
	var segs := 20
	var sprites: Array = [_sprite_a, _sprite_b]
	for sp_idx in range(sprites.size()):
		var sp: Sprite2D = sprites[sp_idx]
		if not sp:
			continue
		for s in range(spiral_count):
			var base_angle := sp.rotation + TAU * float(s) / float(spiral_count)
			var pts := PackedVector2Array()
			for i in range(segs):
				var t: float = 1.0 - float(i) / float(segs)
				var r: float = _current_radius * t * 0.5
				var a := base_angle + t * 3.0
				pts.append(sp.position + Vector2(cos(a) * r, sin(a) * r))
			if pts.size() > 1:
				var spiral_alpha := _fade_alpha * 0.3
				draw_polyline(pts, Color(_secondary_color.r, _secondary_color.g, _secondary_color.b, spiral_alpha), 1.5, true)

func _do_seek(delta: float) -> void:
	var best_pos := SwarmManager.find_closest_pos(global_position, 600.0)
	var mesh_pos := EnemyMeshManager.find_closest_pos(global_position, 600.0)
	if mesh_pos != Vector2.ZERO:
		if best_pos == Vector2.ZERO or global_position.distance_to(mesh_pos) < global_position.distance_to(best_pos):
			best_pos = mesh_pos
	if best_pos == Vector2.ZERO:
		return
	var desired := global_position.direction_to(best_pos)
	var current_angle := _direction.angle()
	var desired_angle := desired.angle()
	var angle_diff := desired_angle - current_angle
	while angle_diff > PI:
		angle_diff -= TAU
	while angle_diff < -PI:
		angle_diff += TAU
	var turn_rate := _seek_strength * delta
	if absf(angle_diff) < turn_rate:
		_direction = desired
	else:
		_direction = _direction.rotated(signf(angle_diff) * turn_rate)
