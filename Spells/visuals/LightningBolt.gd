class_name LightningBolt
extends Node2D

const POOL_SIZE: int = 30
const FLICKER_INTERVAL: float = 0.04

var _points: PackedVector2Array = PackedVector2Array()
var _forks: Array[PackedVector2Array] = []
var _core_color: Color = Color(1.5, 1.5, 1.5)
var _bolt_color: Color = Color(0.5, 0.8, 1.0)
var _glow_color: Color = Color(0.3, 0.5, 1.0, 0.45)
var _lifetime: float = 0.35
var _age: float = 0.0
var _flicker_timer: float = 0.0
var _core_width: float = 2.0
var _bolt_width: float = 6.0
var _glow_width: float = 16.0
var _branch_color: Color = Color(0.4, 0.7, 1.0)
var _branch_width: float = 3.0
var _active: bool = false
var _source: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _segments: int = 12
var _jitter: float = 25.0
var _regenerate: bool = true

static var _pool: Array[LightningBolt] = []
static var _pool_parent: Node = null

func _ready() -> void:
	top_level = true
	z_index = 3
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

static func _ensure_pool() -> void:
	if _pool.size() >= POOL_SIZE:
		return
	if not _pool_parent or not is_instance_valid(_pool_parent):
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree and tree.current_scene:
			_pool_parent = tree.current_scene
		else:
			return
	for i in range(POOL_SIZE - _pool.size()):
		var bolt := LightningBolt.new()
		_pool_parent.add_child(bolt)
		_pool.append(bolt)

static func acquire() -> LightningBolt:
	_ensure_pool()
	for bolt in _pool:
		if not bolt._active:
			bolt._active = true
			bolt._age = 0.0
			bolt._flicker_timer = 0.0
			bolt.visible = true
			bolt.process_mode = Node.PROCESS_MODE_INHERIT
			return bolt
	var bolt := LightningBolt.new()
	if _pool_parent and is_instance_valid(_pool_parent):
		_pool_parent.add_child(bolt)
	_pool.append(bolt)
	bolt._active = true
	bolt.visible = true
	bolt.process_mode = Node.PROCESS_MODE_INHERIT
	return bolt

func setup(source: Vector2, target: Vector2, segments: int, jitter: float) -> void:
	_source = source
	_target = target
	_segments = segments
	_jitter = jitter
	_generate_bolt()

func _generate_bolt() -> void:
	_points = PackedVector2Array()
	_points.append(_source)
	var dir := _target - _source
	var length := dir.length()
	var step_len := length / maxf(_segments, 1)
	var tangent := dir.normalized()
	var perp := Vector2(-tangent.y, tangent.x)
	for i in range(1, _segments):
		var t := float(i) / float(_segments)
		var pos := _source + dir * t
		var jitter_mult := sin(t * PI)
		pos += perp * randf_range(-_jitter, _jitter) * jitter_mult
		_points.append(pos)
	_points.append(_target)
	_generate_forks()
	queue_redraw()

func _generate_forks() -> void:
	_forks.clear()
	var dir := _target - _source
	var length := dir.length()
	var tangent := dir.normalized()
	_generate_branch(_source, tangent, length, 3, 0.45, 0)
	_generate_branch(_target - dir * 0.15, tangent, length * 0.3, 2, 0.3, 1)

func _generate_branch(origin: Vector2, base_dir: Vector2, max_len: float, depth: int, angle_spread: float, _seed: int) -> void:
	if depth <= 0:
		return
	var fork_len := max_len * randf_range(0.2, 0.45)
	var sign: float = -1.0 if randf() < 0.5 else 1.0
	var angle := randf_range(0.3, angle_spread) * sign
	var perp := Vector2(-base_dir.y, base_dir.x)
	var fork_dir := (base_dir * cos(angle) + perp * sin(angle)).normalized()
	var fork_pts: PackedVector2Array = PackedVector2Array()
	fork_pts.append(origin)
	var fork_segments := maxi(int(fork_len / 8.0), 3)
	var step := fork_dir * (fork_len / float(fork_segments))
	for j in range(1, fork_segments + 1):
		var p := origin + step * float(j)
		var sub_perp := Vector2(-fork_dir.y, fork_dir.x)
		p += sub_perp * randf_range(-_jitter * 0.3, _jitter * 0.3)
		fork_pts.append(p)
	_forks.append(fork_pts)
	if depth > 1 and fork_len > 20.0:
		var branch_origin := fork_pts[fork_pts.size() / 2]
		_generate_branch(branch_origin, fork_dir, fork_len * 0.5, depth - 1, angle_spread * 0.7, _seed + 1)

func _draw() -> void:
	if _points.size() < 2:
		return
	var alpha := clampf(1.0 - _age / _lifetime, 0.0, 1.0)
	var flicker := 0.8 + randf() * 0.2
	var fade_core := alpha * flicker
	var fade_bolt := alpha * flicker
	var fade_glow := alpha
	draw_polyline(_points, Color(_glow_color.r, _glow_color.g, _glow_color.b, _glow_color.a * fade_glow), _glow_width, true)
	draw_polyline(_points, Color(_bolt_color.r, _bolt_color.g, _bolt_color.b, fade_bolt), _bolt_width, true)
	draw_polyline(_points, Color(_core_color.r, _core_color.g, _core_color.b, fade_core), _core_width, true)
	for fork in _forks:
		draw_polyline(fork, Color(_glow_color.r, _glow_color.g, _glow_color.b, _glow_color.a * fade_glow * 0.5), _glow_width * 0.4, true)
		draw_polyline(fork, Color(_bolt_color.r, _bolt_color.g, _bolt_color.b, fade_bolt * 0.6), _bolt_width * 0.4, true)
		draw_polyline(fork, Color(_core_color.r, _core_color.g, _core_color.b, fade_core * 0.5), _core_width * 0.3, true)

func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		_release()
		return
	_flicker_timer += delta
	if _regenerate and _flicker_timer >= FLICKER_INTERVAL:
		_flicker_timer = 0.0
		_apply_flicker()
	queue_redraw()

func _apply_flicker() -> void:
	if _points.size() < 3:
		return
	for i in range(1, _points.size() - 1):
		var prev: Vector2 = _points[i - 1]
		var nxt: Vector2 = _points[i + 1]
		var dir := (nxt - prev).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var t := float(i) / float(_points.size())
		var jitter_mult := sin(t * PI)
		_points[i] += perp * randf_range(-_jitter * 0.6, _jitter * 0.6) * jitter_mult

func _release() -> void:
	_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_points = PackedVector2Array()
	_forks.clear()

static func create_strike(source: Vector2, target: Vector2, _parent: Node) -> LightningBolt:
	var bolt := acquire()
	bolt.setup(source, target, 14, 30.0)
	return bolt
