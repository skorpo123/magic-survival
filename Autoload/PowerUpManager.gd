extends Node

var _active_power_ups: Dictionary = {}
var _player_ref: Player = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.game_started.connect(_on_game_started)
	set_process(false)

func _on_game_started() -> void:
	_active_power_ups.clear()
	_remove_all_effects()
	_player_ref = null

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var to_remove: Array[StringName] = []
	for key: StringName in _active_power_ups:
		var entry: Dictionary = _active_power_ups[key]
		entry.time_left -= delta
		if entry.time_left <= 0.0:
			to_remove.append(key)
			_deactivate_effect(key, entry)

	for key in to_remove:
		_active_power_ups.erase(key)
	if _active_power_ups.is_empty():
		set_process(false)

func apply_power_up(data: PowerUpData) -> void:
	if not _player_ref:
		_player_ref = GameManager.get_player() as Player
	if not _player_ref:
		return

	var key: StringName = &"" + str(data.power_up_type)

	if _active_power_ups.has(key):
		var existing: Dictionary = _active_power_ups[key]
		if data.duration > existing.time_left:
			existing.time_left = data.duration
		return

	var entry := {
		"data": data,
		"time_left": data.duration,
	}
	_active_power_ups[key] = entry
	_activate_effect(key, entry)
	set_process(true)

func _activate_effect(_key: StringName, entry: Dictionary) -> void:
	var data: PowerUpData = entry["data"]
	ActionProfiler.probe("powerup", "activate_%s" % str(data.power_up_type))
	if not _player_ref or not _player_ref.stats:
		return
	match data.power_up_type:
		PowerUpData.PowerUpType.INVULNERABILITY:
			pass
		PowerUpData.PowerUpType.DAMAGE_MULTIPLIER:
			_player_ref.stats.magic_power *= data.value
		PowerUpData.PowerUpType.SPEED_BOOST:
			_player_ref.stats.move_speed *= data.value
		PowerUpData.PowerUpType.FREEZE_ENEMIES:
			_set_enemies_frozen(true, data.value)
		PowerUpData.PowerUpType.FIRE_RATE_BOOST:
			_player_ref.stats.cooldown_reduction = minf(_player_ref.stats.cooldown_reduction + 0.5, 0.75)
		PowerUpData.PowerUpType.MEGA_MAGNET:
			_activate_mega_magnet()

func _deactivate_effect(_key: StringName, entry: Dictionary) -> void:
	var data: PowerUpData = entry["data"]
	ActionProfiler.probe("powerup", "deactivate_%s" % str(data.power_up_type))
	if not _player_ref or not _player_ref.stats:
		return
	match data.power_up_type:
		PowerUpData.PowerUpType.INVULNERABILITY:
			pass
		PowerUpData.PowerUpType.DAMAGE_MULTIPLIER:
			_player_ref.stats.magic_power /= data.value
		PowerUpData.PowerUpType.SPEED_BOOST:
			_player_ref.stats.move_speed /= data.value
		PowerUpData.PowerUpType.FREEZE_ENEMIES:
			_set_enemies_frozen(false, 1.0)
		PowerUpData.PowerUpType.FIRE_RATE_BOOST:
			_player_ref.stats.cooldown_reduction = maxf(_player_ref.stats.cooldown_reduction - 0.5, 0.0)
		PowerUpData.PowerUpType.MEGA_MAGNET:
			_deactivate_mega_magnet()

func _activate_mega_magnet() -> void:
	EventBus.mega_magnet_activated.emit()
	OrbManager.activate_mega_magnet()

func _deactivate_mega_magnet() -> void:
	EventBus.mega_magnet_ended.emit()

func _set_enemies_frozen(frozen: bool, speed_mult: float) -> void:
	EnemyMeshManager.set_speed_mult(speed_mult if frozen else 1.0)
	SwarmManager.set_speed_mult(speed_mult if frozen else 1.0)

func _remove_all_effects() -> void:
	for key: StringName in _active_power_ups:
		_deactivate_effect(key, _active_power_ups[key])
	_active_power_ups.clear()

func has_power_up(type: PowerUpData.PowerUpType) -> bool:
	var key: StringName = &"" + str(type)
	return _active_power_ups.has(key)

func is_invulnerable() -> bool:
	return has_power_up(PowerUpData.PowerUpType.INVULNERABILITY)
