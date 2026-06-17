extends Node2D

const MAX_ORBS: int = 300
const TIER_COUNT: int = 4
const COLLECT_DIST: float = 14.0
const COLLECT_ANIM_SPEED: float = 6.0
const MAGNET_BASE: float = 100.0
const MAGNET_SPEED_BASE: float = 300.0
const IDLE_DECEL: float = 100.0
const MEGA_MAGNET_RANGE_FACTOR: float = 0.8

const TIER_RADII: PackedFloat32Array = [6.75, 10.8, 14.85, 18.9]
const TIER_VALUES: PackedFloat32Array = [3.0, 10.0, 28.0, 65.0]
const TIER_COLORS: Array[Color] = [
	Color(0.5, 0.8, 1.0),
	Color(0.3, 1.0, 0.5),
	Color(1.0, 0.85, 0.2),
	Color(1.0, 0.3, 0.8),
]

var _px: PackedFloat32Array = PackedFloat32Array()
var _py: PackedFloat32Array = PackedFloat32Array()
var _vx: PackedFloat32Array = PackedFloat32Array()
var _vy: PackedFloat32Array = PackedFloat32Array()
var _tier: PackedInt32Array = PackedInt32Array()
var _alive: PackedInt32Array = PackedInt32Array()
var _magnetized: PackedInt32Array = PackedInt32Array()
var _collecting: PackedInt32Array = PackedInt32Array()
var _collect_t: PackedFloat32Array = PackedFloat32Array()
var _idle_time: PackedFloat32Array = PackedFloat32Array()
var _mega_magnet: PackedInt32Array = PackedInt32Array()
var _value: PackedFloat32Array = PackedFloat32Array()

var _mm_instance: MultiMeshInstance2D = null
var _glow_mm_instance: MultiMeshInstance2D = null
var _alive_list: PackedInt32Array = PackedInt32Array()
var _count: int = 0
var _spawn_idx: int = 0
var _cached_player: Node2D = null
var _player_frame: int = -1

func _ready() -> void:
	z_index = -1
	z_as_relative = false
	_init_arrays()
	_init_textures()
	_init_multimesh()
	EventBus.game_started.connect(_on_game_started)
	EventBus.mega_magnet_activated.connect(_on_mega_magnet_activated)
	EventBus.mega_magnet_ended.connect(_on_mega_magnet_ended)
	set_process(false)

func _init_arrays() -> void:
	_px.resize(MAX_ORBS)
	_py.resize(MAX_ORBS)
	_vx.resize(MAX_ORBS)
	_vy.resize(MAX_ORBS)
	_tier.resize(MAX_ORBS)
	_alive.resize(MAX_ORBS)
	_magnetized.resize(MAX_ORBS)
	_collecting.resize(MAX_ORBS)
	_collect_t.resize(MAX_ORBS)
	_idle_time.resize(MAX_ORBS)
	_mega_magnet.resize(MAX_ORBS)
	_value.resize(MAX_ORBS)
	_alive.fill(0)
	_magnetized.fill(0)
	_collecting.fill(0)
	_mega_magnet.fill(0)

func _init_textures() -> void:
	pass

func _init_multimesh() -> void:
	_mm_instance = MultiMeshInstance2D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = MAX_ORBS
	mm.visible_instance_count = 0
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Systems/OrbShader.gdshader") as Shader
	_mm_instance.material = mat
	_mm_instance.multimesh = mm
	add_child(_mm_instance)

func _on_game_started() -> void:
	_count = 0
	_spawn_idx = 0
	_alive.fill(0)
	_magnetized.fill(0)
	_collecting.fill(0)
	_mega_magnet.fill(0)
	_alive_list.resize(0)
	if _mm_instance and _mm_instance.multimesh:
		_mm_instance.multimesh.visible_instance_count = 0
	_cached_player = null
	_player_frame = -1
	set_process(false)

func _on_mega_magnet_activated() -> void:
	for i in _alive_list:
		_mega_magnet[i] = 1
		_magnetized[i] = 1

func _on_mega_magnet_ended() -> void:
	for i in _alive_list:
		_mega_magnet[i] = 0

func _get_player() -> Node2D:
	var f: int = Engine.get_process_frames()
	if f == _player_frame and _cached_player and is_instance_valid(_cached_player):
		return _cached_player
	_cached_player = GameManager.get_player()
	_player_frame = f
	return _cached_player

func spawn_orb(pos: Vector2, value: float) -> void:
	if GameManager.is_boss_fight():
		return
	if _count >= MAX_ORBS:
		var min_val: float = INF
		var min_idx: int = -1
		for i in _alive_list:
			if _magnetized[i] == 0 and _collecting[i] == 0:
				if _value[i] < min_val:
					min_val = _value[i]
					min_idx = i
		if min_idx >= 0 and value > min_val:
			_free_slot(min_idx)
		else:
			return

	var start: int = _spawn_idx
	while true:
		if _alive[_spawn_idx] == 0:
			break
		_spawn_idx = (_spawn_idx + 1) % MAX_ORBS
		if _spawn_idx == start:
			return

	var idx: int = _spawn_idx
	_px[idx] = pos.x
	_py[idx] = pos.y
	_vx[idx] = 0.0
	_vy[idx] = 0.0
	_value[idx] = value
	_magnetized[idx] = 0
	_collecting[idx] = 0
	_collect_t[idx] = 0.0
	_idle_time[idx] = 0.0

	var tier: int = 0
	if value >= TIER_VALUES[3]:
		tier = 3
	elif value >= TIER_VALUES[2]:
		tier = 2
	elif value >= TIER_VALUES[1]:
		tier = 1
	_tier[idx] = tier
	_alive[idx] = 1
	_count += 1
	_alive_list.append(idx)
	_spawn_idx = (_spawn_idx + 1) % MAX_ORBS
	set_process(true)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var player: Node2D = _get_player()
	if not player or not is_instance_valid(player):
		return

	var ppx: float = player.global_position.x
	var ppy: float = player.global_position.y
	var magnet_range: float = MAGNET_BASE
	if player.has_method("get_pickup_range"):
		magnet_range = player.get_pickup_range()
	var magnet_range_sq: float = magnet_range * magnet_range
	var mm: MultiMesh = _mm_instance.multimesh
	var write: int = 0
	var dead_count: int = 0

	for list_idx in range(_alive_list.size()):
		var i: int = _alive_list[list_idx]
		if _alive[i] == 0:
			dead_count += 1
			continue

		if _collecting[i] != 0:
			_collect_t[i] += delta * COLLECT_ANIM_SPEED
			if _collect_t[i] >= 1.0:
				_finish_collect(i)
				continue
			var t: float = _collect_t[i]
			var draw_scale: float = TIER_RADII[_tier[i]] * 2.0 * (1.0 + t * 0.5)
			var alpha: float = maxf(1.0 - t, 0.0)
			mm.set_instance_transform_2d(write, Transform2D(Vector2(draw_scale, 0.0), Vector2(0.0, draw_scale), Vector2(_px[i], _py[i])))
			var c: Color = TIER_COLORS[_tier[i]]
			mm.set_instance_color(write, Color(c.r, c.g, c.b, alpha))
			write += 1
			continue

		if _mega_magnet[i] != 0:
			_magnetized[i] = 1

		if _magnetized[i] == 0:
			var ddx: float = _px[i] - ppx
			var ddy: float = _py[i] - ppy
			var dist_sq: float = ddx * ddx + ddy * ddy
			if dist_sq < magnet_range_sq:
				_magnetized[i] = 1

		if _magnetized[i] != 0:
			var ddx: float = _px[i] - ppx
			var ddy: float = _py[i] - ppy
			var dist: float = sqrt(ddx * ddx + ddy * ddy)
			var effective_range: float = magnet_range
			if _mega_magnet[i] != 0:
				var vp := get_viewport_rect().size
				effective_range = maxf(vp.x, vp.y) * MEGA_MAGNET_RANGE_FACTOR

			var direction := Vector2(-ddx, -ddy)
			if dist > 0.0:
				direction = direction / dist
			else:
				direction = Vector2.ZERO

			var speed_factor := 1.0 - clampf(dist / maxf(effective_range, 1.0), 0.0, 0.8)
			var speed := MAGNET_SPEED_BASE * (0.5 + speed_factor * 1.5)
			if _mega_magnet[i] != 0:
				speed = maxf(speed, 500.0)
			if dist < 50.0:
				speed = maxf(speed, 600.0)

			_vx[i] = direction.x * speed
			_vy[i] = direction.y * speed
			_px[i] += _vx[i] * delta
			_py[i] += _vy[i] * delta
			_idle_time[i] = 0.0

			if dist < COLLECT_DIST:
				_start_collect(i)
				continue

			var draw_scale: float = TIER_RADII[_tier[i]] * 2.0
			mm.set_instance_transform_2d(write, Transform2D(Vector2(draw_scale, 0.0), Vector2(0.0, draw_scale), Vector2(_px[i], _py[i])))
			var c: Color = TIER_COLORS[_tier[i]]
			mm.set_instance_color(write, Color(c.r, c.g, c.b, 1.0))
			write += 1
		else:
			_vx[i] = move_toward(_vx[i], 0.0, IDLE_DECEL * delta)
			_vy[i] = move_toward(_vy[i], 0.0, IDLE_DECEL * delta)
			if _vx[i] * _vx[i] + _vy[i] * _vy[i] > 1.0:
				_px[i] += _vx[i] * delta
				_py[i] += _vy[i] * delta
			else:
				_idle_time[i] += delta

			var draw_scale: float = TIER_RADII[_tier[i]] * 2.0
			mm.set_instance_transform_2d(write, Transform2D(Vector2(draw_scale, 0.0), Vector2(0.0, draw_scale), Vector2(_px[i], _py[i])))
			var c: Color = TIER_COLORS[_tier[i]]
			mm.set_instance_color(write, Color(c.r, c.g, c.b, 0.85))
			write += 1

	mm.visible_instance_count = write

	if dead_count > 0:
		var w_idx: int = 0
		for r_idx in range(_alive_list.size()):
			var idx: int = _alive_list[r_idx]
			if _alive[idx] != 0:
				_alive_list[w_idx] = idx
				w_idx += 1
		_alive_list.resize(w_idx)

	if _count <= 0:
		set_process(false)

func _start_collect(idx: int) -> void:
	if _collecting[idx] != 0:
		return
	_collecting[idx] = 1
	_collect_t[idx] = 0.0

func _finish_collect(idx: int) -> void:
	var player: Node2D = _get_player()
	if player and player.has_method("add_xp"):
		player.add_xp(_value[idx])
	EventBus.pickup_collected.emit(&"experience_orb", _value[idx])
	JuiceManager.spawn_xp_sparkle(Vector2(_px[idx], _py[idx]))
	SoundManager.play_sound("pickup_orb")
	_free_slot(idx)

func _free_slot(idx: int) -> void:
	_alive[idx] = 0
	_magnetized[idx] = 0
	_collecting[idx] = 0
	_mega_magnet[idx] = 0
	_count -= 1

func get_active_count() -> int:
	return _count

func reset() -> void:
	_count = 0
	_spawn_idx = 0
	_alive.fill(0)
	_magnetized.fill(0)
	_collecting.fill(0)
	_mega_magnet.fill(0)
	_alive_list.resize(0)
	if _mm_instance and _mm_instance.multimesh:
		_mm_instance.multimesh.visible_instance_count = 0
	_cached_player = null
	_player_frame = -1
	set_process(false)

func register_orb(_orb: Node2D) -> void:
	pass

func unregister_orb(_orb: Node2D) -> void:
	pass

func activate_mega_magnet() -> void:
	_on_mega_magnet_activated()
