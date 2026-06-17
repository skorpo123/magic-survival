class_name PoisonPool
extends Node2D

enum State { FORMING, ACTIVE, FADING }

var _damage: float = 8.0
var _damage_interval: float = 0.3
var _damage_timer: float = 0.0
var _radius: float = 85.0
var _lifetime: float = 5.0
var _spawn_delay: float = 0.3
var _tint: Color = Color(0.4, 1.0, 0.2)
var _age: float = 0.0
var _state: int = State.FORMING
var _pulse_tween: Tween = null

var _pool_group: Node2D = null
var _pool_layers: Array[Polygon2D] = []
var _highlight_dots: Array[Polygon2D] = []
var _bubbles: GPUParticles2D = null

const _RY_RATIO: float = 0.34
const _OUTER_COLOR: Color = Color(0.15, 0.65, 0.20, 0.95)
const _INNER_COLOR: Color = Color(0.35, 1.00, 0.30, 0.90)
const _DOT_COLOR: Color = Color(0.85, 1.00, 0.75, 0.95)

signal expired

static var _shared_mat: CanvasItemMaterial = null

func _ready() -> void:
	z_index = -2
	material = _get_shared_mat()
	_build_visual()
	scale = Vector2.ZERO
	modulate = Color(1.0, 1.0, 1.0, 1.0)

func setup(pos: Vector2, radius: float, damage: float, damage_interval: float, lifetime: float, tint: Color) -> void:
	global_position = pos
	_radius = radius
	_damage = damage
	_damage_interval = damage_interval
	_lifetime = lifetime
	_tint = tint
	_damage_timer = damage_interval
	_apply_pool_tint(tint)
	scale = Vector2.ONE

func _apply_pool_tint(tint: Color) -> void:
	if not _pool_group:
		return
	_pool_group.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _pool_layers.size() >= 2:
		_pool_layers[0].color = _OUTER_COLOR
		_pool_layers[1].color = _INNER_COLOR
	for dot in _highlight_dots:
		dot.color = _DOT_COLOR

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_age += delta
	match _state:
		State.FORMING:
			var t: float = clampf(_age / _spawn_delay, 0.0, 1.0)
			var ease_t: float = 1.0 - pow(1.0 - t, 3.0)
			scale = Vector2.ONE * ease_t
			modulate.a = ease_t
			if t >= 1.0:
				_state = State.ACTIVE
				scale = Vector2.ONE
				_start_bubbles()
		State.ACTIVE:
			_damage_timer -= delta
			if _damage_timer <= 0.0:
				_damage_timer = _damage_interval
				_deal_damage()
				_start_pulse()
			if _age >= _spawn_delay + _lifetime:
				_state = State.FADING
				_age = 0.0
				_stop_bubbles()
		State.FADING:
			var t: float = clampf(_age / 0.4, 0.0, 1.0)
			var ease_t: float = t * t
			scale = Vector2.ONE * (1.0 + ease_t * 0.2)
			modulate.a = 1.0 - ease_t
			if t >= 1.0:
				expired.emit()
				queue_free()

func _build_visual() -> void:
	_pool_group = Node2D.new()
	_pool_group.z_index = 0
	_pool_group.material = _get_shared_mat()
	add_child(_pool_group)

	var outer := Polygon2D.new()
	outer.polygon = _build_ellipse_polygon(_radius, _radius * _RY_RATIO, 28)
	outer.color = _OUTER_COLOR
	outer.z_index = 0
	_pool_group.add_child(outer)
	_pool_layers.append(outer)

	var inner := Polygon2D.new()
	inner.polygon = _build_ellipse_polygon(_radius * 0.88, _radius * _RY_RATIO * 0.88, 28)
	inner.color = _INNER_COLOR
	inner.z_index = 1
	_pool_group.add_child(inner)
	_pool_layers.append(inner)

	var dot_positions: Array = [
		Vector2(-_radius * 0.40, -_radius * 0.08),
		Vector2(-_radius * 0.05, -_radius * 0.16),
		Vector2(_radius * 0.28, -_radius * 0.06),
		Vector2(_radius * 0.42, _radius * 0.04),
	]
	for pos in dot_positions:
		var dot := Polygon2D.new()
		var dot_rx: float = 2.8
		var dot_ry: float = 1.6
		dot.polygon = PackedVector2Array([
			pos + Vector2(-dot_rx, 0),
			pos + Vector2(0, -dot_ry),
			pos + Vector2(dot_rx, 0),
			pos + Vector2(0, dot_ry),
		])
		dot.color = _DOT_COLOR
		dot.z_index = 2
		_pool_group.add_child(dot)
		_highlight_dots.append(dot)

func _build_ellipse_polygon(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var t: float = float(i) / float(segments) * TAU
		pts.append(Vector2(cos(t) * rx, sin(t) * ry))
	return pts

func _start_bubbles() -> void:
	if _bubbles:
		return
	_bubbles = GPUParticles2D.new()
	_bubbles.amount = 14
	_bubbles.lifetime = 1.6
	_bubbles.one_shot = false
	_bubbles.local_coords = false
	_bubbles.z_index = 5
	_bubbles.emitting = true
	_bubbles.texture = _get_bubble_texture()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bubbles.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(_radius * 0.7, 2.0, 0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 18.0
	pm.initial_velocity_min = 30.0
	pm.initial_velocity_max = 55.0
	pm.gravity = Vector3(0, -10, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	pm.color = Color(_tint.r * 1.6, _tint.g * 1.6, _tint.b * 1.0, 0.9)
	pm.particle_flag_disable_z = true
	var fade_curve := Curve.new()
	fade_curve.add_point(Vector2(0, 0))
	fade_curve.add_point(Vector2(0.12, 1))
	fade_curve.add_point(Vector2(0.8, 0.75))
	fade_curve.add_point(Vector2(1, 0))
	var alpha_tex := CurveTexture.new()
	alpha_tex.curve = fade_curve
	pm.alpha_curve = alpha_tex
	_bubbles.process_material = pm
	_pool_group.add_child(_bubbles)

func _stop_bubbles() -> void:
	if _bubbles:
		_bubbles.emitting = false

func _start_pulse() -> void:
	if not _pool_group:
		return
	if _pulse_tween and _pulse_tween.is_valid():
		return
	_pool_group.scale = Vector2(1.08, 1.08)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_pool_group, "scale", Vector2.ONE, _damage_interval * 0.5).set_ease(Tween.EASE_OUT)

func _deal_damage() -> void:
	var dmg := _damage * ComboTracker.get_damage_multiplier()
	SwarmManager.damage_area(global_position, _radius, dmg)
	EnemyMeshManager.damage_area(global_position, _radius, dmg)

static func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_mat

static var _bubble_tex: ImageTexture = null

static func _get_bubble_texture() -> ImageTexture:
	if _bubble_tex:
		return _bubble_tex
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = size / 2.0
	for px in range(size):
		for py in range(size):
			var dx: float = (px - c) / c
			var dy: float = (py - c) / c
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist <= 1.0:
				var a: float = pow(1.0 - dist, 3.0)
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, a))
			else:
				img.set_pixel(px, py, Color(0, 0, 0, 0))
	_bubble_tex = ImageTexture.create_from_image(img)
	return _bubble_tex
