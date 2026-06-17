class_name BurstEffectPool

const POOL_SIZE: int = 200
const MAX_SPAWN_PER_FRAME: int = 60
const MAX_PER_TYPE_PER_SECOND: int = 30

static var _pool: Array = []
static var _free_stack: PackedInt32Array = PackedInt32Array()
static var _initialized: bool = false
static var _spawn_count_this_frame: int = 0
static var _last_spawn_frame: int = -1

static var _scene_map: Dictionary = {}
static var _scale_map: Dictionary = {}
static var _key_cache: Dictionary = {}
static var _type_spawn_data: Dictionary = {}
static var _pool_parent: Node = null

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_scene_map = {
		"small":     preload("res://Scenes/death_default.tscn"),
		"medium":    preload("res://Scenes/death_cold.tscn"),
		"big":       preload("res://Scenes/death_fire.tscn"),
		"overlord":  preload("res://Scenes/death_arcane.tscn"),
		"mine":      preload("res://Scenes/death_fire.tscn"),
		"rampage":   preload("res://Scenes/death_rage.tscn"),
		"lightning": preload("res://Scenes/death_cold.tscn"),
		"bolt":      preload("res://Scenes/death_cold.tscn"),
		"fireball":  preload("res://Scenes/death_fire.tscn"),
		"orbit":     preload("res://Scenes/death_arcane.tscn"),
		"explosion":     preload("res://Scenes/death_fire.tscn"),
		"electric_spark": preload("res://Scenes/death_cold.tscn"),
		"arcane_impact":  preload("res://Scenes/death_arcane.tscn"),
		"fire_ember":     preload("res://Scenes/death_fire.tscn"),
		"poison":         preload("res://Scenes/death_cold.tscn"),
		"frost_nova":     preload("res://Scenes/death_cold.tscn"),
		"thread_dissolve": preload("res://Scenes/death_arcane.tscn"),
		"meteor":          preload("res://Scenes/death_fire.tscn"),
	}
	_scale_map = {
		"small":     0.7,
		"medium":    1.0,
		"big":       3.5,
		"overlord":  3.5,
		"mine":      1.5,
		"rampage":   2.0,
		"lightning": 1.3,
		"bolt":      0.6,
		"fireball":  1.8,
		"orbit":     0.5,
		"explosion": 2.5,
		"electric_spark": 0.8,
		"arcane_impact":  1.0,
		"fire_ember":     0.4,
		"poison":         1.0,
		"frost_nova":     1.5,
		"thread_dissolve": 0.3,
		"meteor":         5.0,
	}
	for key in _scene_map:
		_key_cache[key] = "burst_pool_%s" % key
	_type_spawn_data.clear()
	_pool.resize(POOL_SIZE)
	_free_stack.resize(POOL_SIZE)
	var tree := Engine.get_main_loop()
	if tree and tree.root and not _pool_parent:
		_pool_parent = Node.new()
		_pool_parent.name = "BurstEffectPool"
		_pool_parent.process_mode = Node.PROCESS_MODE_DISABLED
		tree.root.add_child(_pool_parent)
	for i in range(POOL_SIZE):
		var player := BurstEffectPlayer.new()
		player._setup()
		_pool[i] = player
		_free_stack[i] = POOL_SIZE - 1 - i
		if _pool_parent:
			_pool_parent.add_child(player)
	_initialized = true

static func spawn(effect_type: String, pos: Vector2, color: Color = Color.WHITE, scale_mult_override: float = 1.0) -> void:
	_ensure_initialized()
	var now: float = Time.get_ticks_msec() * 0.001
	if not _type_spawn_data.has(effect_type):
		var arr := PackedFloat32Array()
		arr.resize(MAX_PER_TYPE_PER_SECOND)
		for i in range(MAX_PER_TYPE_PER_SECOND):
			arr[i] = 0.0
		_type_spawn_data[effect_type] = {times = arr, head = 0}
	var td: Dictionary = _type_spawn_data[effect_type]
	var times: PackedFloat32Array = td.times
	var head: int = td.head
	var count: int = 0
	for i in range(MAX_PER_TYPE_PER_SECOND):
		var idx := (head + i) % MAX_PER_TYPE_PER_SECOND
		if times[idx] >= now - 1.0:
			count += 1
	if count >= MAX_PER_TYPE_PER_SECOND:
		return
	times[head] = now
	td.head = (head + 1) % MAX_PER_TYPE_PER_SECOND
	var probe_key: String = _key_cache.get(effect_type, "burst_pool_%s" % effect_type)
	ActionProfiler.probe("vfx", probe_key)
	var frame: int = Engine.get_process_frames()
	if frame != _last_spawn_frame:
		_last_spawn_frame = frame
		_spawn_count_this_frame = 0
	if _spawn_count_this_frame >= MAX_SPAWN_PER_FRAME:
		return
	_spawn_count_this_frame += 1
	var scene: PackedScene = _scene_map.get(effect_type, _scene_map["small"])
	var scale_mult: float = _scale_map.get(effect_type, 1.0)
	var player: BurstEffectPlayer = null
	if _free_stack.size() > 0:
		var idx: int = _free_stack[_free_stack.size() - 1]
		_free_stack.resize(_free_stack.size() - 1)
		if idx >= 0 and idx < _pool.size():
			var p: BurstEffectPlayer = _pool[idx]
			if is_instance_valid(p) and not p._active:
				player = p
	if not player:
		return
	var final_scale: float = scale_mult * scale_mult_override
	player.play(scene, effect_type, pos, final_scale, color)

static func _return_to_pool(p: BurstEffectPlayer) -> void:
	p._active = false
	p.visible = false
	var idx := _pool.find(p)
	if idx >= 0:
		_free_stack.append(idx)
