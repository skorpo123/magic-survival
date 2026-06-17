extends Node

var _master_volume: float = 0.8
var _sfx_volume: float = 0.8
var _enabled: bool = false

const _POOL_SIZE: int = 12

var _players: Array[AudioStreamPlayer] = []
var _registry: Dictionary = {}
var _variants: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = false
	_init_pool()
	_init_registry()
	call_deferred("_init_volume")

func _init_pool() -> void:
	for i in range(_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func _init_registry() -> void:
	_reg_var("hit_player", [
		preload("res://assets/audio/sfx/impacts/impactPunch_heavy_000.ogg"),
		preload("res://assets/audio/sfx/impacts/impactPunch_heavy_001.ogg"),
		preload("res://assets/audio/sfx/impacts/impactPunch_heavy_002.ogg"),
		preload("res://assets/audio/sfx/impacts/impactPunch_heavy_003.ogg"),
		preload("res://assets/audio/sfx/impacts/impactPunch_heavy_004.ogg"),
	])
	_reg_var("enemy_explode", [
		preload("res://assets/audio/sfx/sci-fi/explosionCrunch_000.ogg"),
		preload("res://assets/audio/sfx/sci-fi/explosionCrunch_001.ogg"),
		preload("res://assets/audio/sfx/sci-fi/explosionCrunch_002.ogg"),
		preload("res://assets/audio/sfx/sci-fi/explosionCrunch_003.ogg"),
	])
	_reg_var("enemy_die", [
		preload("res://assets/audio/sfx/impacts/impactGeneric_light_000.ogg"),
		preload("res://assets/audio/sfx/impacts/impactGeneric_light_001.ogg"),
		preload("res://assets/audio/sfx/impacts/impactGeneric_light_002.ogg"),
		preload("res://assets/audio/sfx/impacts/impactGeneric_light_003.ogg"),
	])
	_reg_var("hit_enemy", [
		preload("res://assets/audio/sfx/impacts/impactPunch_medium_000.ogg"),
		preload("res://assets/audio/sfx/impacts/impactPunch_medium_001.ogg"),
		preload("res://assets/audio/sfx/impacts/impactPunch_medium_002.ogg"),
		preload("res://assets/audio/sfx/impacts/impactPunch_medium_003.ogg"),
		preload("res://assets/audio/sfx/impacts/impactPunch_medium_004.ogg"),
	])
	_reg_var("wave_start", [
		preload("res://assets/audio/sfx/sci-fi/laserLarge_000.ogg"),
		preload("res://assets/audio/sfx/sci-fi/laserLarge_001.ogg"),
		preload("res://assets/audio/sfx/sci-fi/laserLarge_002.ogg"),
	])
	_reg_var("pickup_orb", [
		preload("res://assets/audio/sfx/magic/handleCoins.ogg"),
		preload("res://assets/audio/sfx/magic/handleCoins2.ogg"),
	])
	_reg_var("pickup_heart", [
		preload("res://assets/audio/sfx/magic/metalClick.ogg"),
		preload("res://assets/audio/sfx/ui/switch1.ogg"),
		preload("res://assets/audio/sfx/ui/switch2.ogg"),
		preload("res://assets/audio/sfx/ui/switch3.ogg"),
	])
	_reg_var("level_up", [
		preload("res://assets/audio/jingles/jingles_NES00.ogg"),
		preload("res://assets/audio/jingles/jingles_NES01.ogg"),
		preload("res://assets/audio/jingles/jingles_NES02.ogg"),
	])
	_reg_var("button_click", [
		preload("res://assets/audio/sfx/ui/click1.ogg"),
		preload("res://assets/audio/sfx/ui/click2.ogg"),
		preload("res://assets/audio/sfx/ui/click3.ogg"),
		preload("res://assets/audio/sfx/ui/click4.ogg"),
		preload("res://assets/audio/sfx/ui/click5.ogg"),
	])

func _reg_var(name: String, streams: Array) -> void:
	_variants[name] = streams
	if streams.size() > 0:
		_registry[name] = streams[0]

func _init_volume() -> void:
	_master_volume = SettingsManager.get_volume() / 100.0
	_sfx_volume = _master_volume
	_apply_volume()
	SettingsManager.volume_changed.connect(_on_volume_changed)

func _on_volume_changed() -> void:
	_master_volume = SettingsManager.get_volume() / 100.0
	_sfx_volume = _master_volume
	_apply_volume()

func _apply_volume() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(_master_volume))

func play_sound(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _enabled:
		return

	var variants: Array = _variants.get(sound_name, [])
	if variants.is_empty():
		return

	var stream: AudioStream
	if variants.size() == 1:
		stream = variants[0]
	else:
		stream = variants[randi() % variants.size()]

	var player := _get_free_player()
	if not player:
		return

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	_players[0].stop()
	return _players[0]

func set_master_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_sfx_volume = _master_volume
	_apply_volume()
