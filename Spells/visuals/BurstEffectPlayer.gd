class_name BurstEffectPlayer
extends Node2D

const SPATIAL_DIV := 300.0
const CONCENTRATION_DIV := 10.0
const CURVE_CAP := 1.5
const TARGET_COMBINED := 0.07

var _group: BurstParticleGroup2D = null
var _scene_key: String = ""
var _active: bool = false
var _generation: int = 0
var _timer: SceneTreeTimer = null

func _setup() -> void:
	z_index = 10
	visible = false
	process_mode = Node.PROCESS_MODE_PAUSABLE

func play(scene: PackedScene, scene_key: String, pos: Vector2, scale_mult: float, color: Color = Color.WHITE) -> void:
	_generation += 1
	var gen := _generation
	if _scene_key != scene_key or not _group or not is_instance_valid(_group):
		_free_group()
		_group = scene.instantiate() as BurstParticleGroup2D
		if not _group:
			return
		_group.autostart = false
		_group.repeat = false
		_group.free_when_finished = false
		add_child(_group)
		for child in _group.get_children():
			if child is BurstParticles2D:
				_scale_burst_particle(child)
		_scene_key = scene_key
	else:
		for child in _group.get_children():
			if child is BurstParticles2D:
				child.kill()
	global_position = pos
	scale = Vector2(scale_mult, scale_mult)
	if color != Color.WHITE and _group:
		_group.modulate = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, color.a)
	elif _group:
		_group.modulate = Color(1.5, 1.5, 1.5, 1.0)
	visible = true
	_active = true
	_group.burst()
	var max_life: float = 0.5
	for child in _group.get_children():
		if child is BurstParticles2D:
			if child.lifetime > max_life:
				max_life = child.lifetime
	if _timer and is_instance_valid(_timer):
		_timer.timeout.disconnect(_on_timer_timeout)
	_timer = get_tree().create_timer(max_life + 0.05, false)
	_timer.timeout.connect(_on_timer_timeout.bind(gen))

func _on_timer_timeout(gen: int) -> void:
	if gen != _generation:
		return
	if _group and is_instance_valid(_group):
		for child in _group.get_children():
			if child is BurstParticles2D:
				child.kill()
	_active = false
	visible = false
	BurstEffectPool._return_to_pool(self)

func _free_group() -> void:
	if _group and is_instance_valid(_group):
		for child in _group.get_children():
			if child is BurstParticles2D:
				child.kill()
		_group.queue_free()
		_group = null
		_scene_key = ""

func _scale_burst_particle(p: BurstParticles2D) -> void:
	p.repeat = false
	p.free_when_finished = false
	p.distance /= SPATIAL_DIV
	p.start_radius /= SPATIAL_DIV
	if p.offset != Vector2.ZERO:
		p.offset /= SPATIAL_DIV
	if p.center_concentration > 2.0:
		p.center_concentration /= CONCENTRATION_DIV
	_cap_curve(p, "scale_curve", CURVE_CAP)
	_cap_curve(p, "x_scale_curve", CURVE_CAP)
	_cap_curve(p, "y_scale_curve", CURVE_CAP)
	var scale_peak := _get_curve_peak(p.scale_curve, 1.0)
	var x_peak := _get_curve_peak(p.x_scale_curve, 1.0)
	var y_peak := _get_curve_peak(p.y_scale_curve, 1.0)
	var combined := scale_peak * x_peak * y_peak
	if combined > 0.01:
		p.image_scale = TARGET_COMBINED / combined

func _get_curve_peak(curve: Curve, default: float) -> float:
	if not curve:
		return default
	var max_y := 0.0
	for i in curve.point_count:
		max_y = maxf(max_y, absf(curve.get_point_position(i).y))
	return maxf(max_y, default)

func _cap_curve(p: BurstParticles2D, prop: String, cap: float) -> void:
	var curve: Curve = p.get(prop)
	if not curve:
		return
	var max_y := 0.0
	for i in curve.point_count:
		max_y = maxf(max_y, absf(curve.get_point_position(i).y))
	if max_y <= cap:
		return
	var div := max_y / cap
	var scaled := curve.duplicate()
	for i in scaled.point_count:
		scaled.set_point_value(i, scaled.get_point_position(i).y / div)
		scaled.set_point_left_tangent(i, scaled.get_point_left_tangent(i) / div)
		scaled.set_point_right_tangent(i, scaled.get_point_right_tangent(i) / div)
	if scaled.max_value > cap:
		scaled.max_value /= div
	p.set(prop, scaled)

func stop() -> void:
	_free_group()
	_active = false
	visible = false
