class_name WaveManager extends Node2D

enum SpecialEventType { SWARM_RUSH, TANK_COLUMN, ELITE_WAVE }

enum SubPhase {
	TRICKLE_LIGHT,
	TRICKLE_MEDIUM,
	TRICKLE_HEAVY,
	BURST_WAVE,
	BOSS_WAVE,
	BREATHER,
	BOSS_SPAWN
}

enum WaveType {
	SURROUND,
	DIRECTIONAL,
	AMBUSH
}

@export var safe_zone_radius: float = 450.0
@export var spawn_ring_margin: float = 150.0
@export var max_enemies_on_screen: int = 200
@export var max_orbs_on_screen: int = 150

const MIN_SPAWN_DIST: float = 600.0
const MAX_SPAWN_DIST: float = 800.0

var difficulty_manager: DifficultyManager
var spawn_entries: Array[EnemySpawnEntry] = []

var _wave_timer: float = 0.0
var _special_event_timer: float = 0.0
var _spawn_delay: float = 0.0
var _player_last_dir: Vector2 = Vector2.RIGHT
var _heart_timer: float = 0.0
var _power_up_timer: float = 0.0
var _orb_spawn_timer: float = 0.0
var _sub_phase: int = SubPhase.TRICKLE_LIGHT
var _sub_phase_timer: float = 0.0
var _phase_index: int = 0
var _prev_phase_index: int = -1
var _sub_phase_index: int = 0
var _boss_phase_num: int = 0
var _boss_active: bool = false
var _boss_dead: bool = false
var _boss_chest_collected: bool = false
var _boss_dead_timer: float = 0.0  # safety timeout: auto-advance if chest is ignored
var _trickle_accumulator: float = 0.0
var _first_wave: bool = true
var _spawn_queue: Array = []

var _heart_pool_name: StringName = &"HealthHeart"
var _power_up_pool_name: StringName = &"PowerUp"
var _heart_scene: PackedScene = null
var _power_up_scene: PackedScene = null
var _initialized: bool = false

var _small_data: EnemyData
var _medium_data: EnemyData
var _big_data: EnemyData
var _mine_data: EnemyData
var _overlord_data: EnemyData
var _rampage_data: EnemyData

var _phase_schedule: Array[Dictionary] = []

var _cached_hp_mult: float = 1.0
var _cached_speed_mult: float = 1.0
var _cached_dmg_mult: float = 1.0
var _cached_scaled: Dictionary = {}

func _ready() -> void:
	difficulty_manager = get_node_or_null("DifficultyManager")
	if not difficulty_manager:
		difficulty_manager = DifficultyManager.new()
		add_child(difficulty_manager)

	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.game_started.connect(_on_game_started)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.chest_opened.connect(_on_chest_opened)
	EventBus.artifact_equipped.connect(_on_artifact_equipped)
	call_deferred("_setup_defaults")

func _setup_defaults() -> void:
	if _initialized:
		return

	_small_data = EnemyData.new()
	_small_data.enemy_name = "Swarm"
	_small_data.enemy_class = EnemyData.EnemyClass.SMALL_FAST
	_small_data.max_hp = 8.0
	_small_data.speed = 140.0
	_small_data.damage = 6.0
	_small_data.xp_value = 0.53
	_small_data.explodes_on_contact = true
	_small_data.explosion_damage = 10.0
	_small_data.seek_weight = 1.0
	_small_data.separation_weight = 2.0
	_small_data.separation_radius = 25.0

	_medium_data = EnemyData.new()
	_medium_data.enemy_name = "Drone"
	_medium_data.enemy_class = EnemyData.EnemyClass.MEDIUM
	_medium_data.max_hp = 18.0
	_medium_data.speed = 83.7
	_medium_data.damage = 10.0
	_medium_data.xp_value = 1.6

	_medium_data.seek_weight = 1.0
	_medium_data.separation_weight = 1.5
	_medium_data.separation_radius = 30.0

	_big_data = EnemyData.new()
	_big_data.enemy_name = "Golem"
	_big_data.enemy_class = EnemyData.EnemyClass.BIG_TANK
	_big_data.max_hp = 150.0
	_big_data.speed = 80.0
	_big_data.damage = 26.0
	_big_data.xp_value = 5.9
	_big_data.cannot_be_pushed = true
	_big_data.pushback_force = 350.0
	_big_data.collision_radius = 28.8

	_big_data.seek_weight = 1.2
	_big_data.separation_weight = 1.0
	_big_data.separation_radius = 40.0

	_mine_data = EnemyData.new()
	_mine_data.enemy_name = "Mine"
	_mine_data.enemy_class = EnemyData.EnemyClass.MINE
	_mine_data.max_hp = 55.0
	_mine_data.speed = 95.0
	_mine_data.damage = 10.0
	_mine_data.xp_value = 2.1

	_mine_data.explodes_on_contact = true
	_mine_data.explosion_damage = 40.0
	_mine_data.seek_weight = 1.0
	_mine_data.separation_weight = 1.5
	_mine_data.separation_radius = 30.0

	_overlord_data = EnemyData.new()
	_overlord_data.enemy_name = "Overlord"
	_overlord_data.enemy_class = EnemyData.EnemyClass.OVERLORD
	_overlord_data.max_hp = 350.0
	_overlord_data.speed = 75.0
	_overlord_data.damage = 24.0
	_overlord_data.xp_value = 10.7

	_overlord_data.explodes_on_contact = true
	_overlord_data.explosion_damage = 70.0
	_overlord_data.collision_radius = 28.0
	_overlord_data.seek_weight = 1.0
	_overlord_data.separation_weight = 2.0
	_overlord_data.separation_radius = 50.0

	_rampage_data = EnemyData.new()
	_rampage_data.enemy_name = "Rampage"
	_rampage_data.enemy_class = EnemyData.EnemyClass.RAMPAGE
	_rampage_data.max_hp = 75.0
	_rampage_data.speed = 65.0
	_rampage_data.damage = 14.0
	_rampage_data.xp_value = 2.7
	_rampage_data.rampage_speed_mult = 3.0
	_rampage_data.rampage_enrage_duration = 2.0

	var entry_small := EnemySpawnEntry.new()
	entry_small.enemy_data = _small_data
	entry_small.weight = 1.0
	entry_small.min_difficulty = 0.0
	entry_small.max_count_per_spawn = 3
	entry_small.elite_chance = 0.0

	var entry_medium := EnemySpawnEntry.new()
	entry_medium.enemy_data = _medium_data
	entry_medium.weight = 0.6
	entry_medium.min_difficulty = 0.0
	entry_medium.max_count_per_spawn = 2
	entry_medium.elite_chance = 0.0

	var entry_big := EnemySpawnEntry.new()
	entry_big.enemy_data = _big_data
	entry_big.weight = 0.15
	entry_big.min_difficulty = 1.0
	entry_big.max_count_per_spawn = 1
	entry_big.elite_chance = 0.0

	var entry_mine := EnemySpawnEntry.new()
	entry_mine.enemy_data = _mine_data
	entry_mine.weight = 0.3
	entry_mine.min_difficulty = 0.5
	entry_mine.max_count_per_spawn = 2
	entry_mine.elite_chance = 0.0

	var entry_overlord := EnemySpawnEntry.new()
	entry_overlord.enemy_data = _overlord_data
	entry_overlord.weight = 0.05
	entry_overlord.min_difficulty = 2.0
	entry_overlord.max_count_per_spawn = 1
	entry_overlord.elite_chance = 0.0

	var entry_rampage := EnemySpawnEntry.new()
	entry_rampage.enemy_data = _rampage_data
	entry_rampage.weight = 0.2
	entry_rampage.min_difficulty = 0.5
	entry_rampage.max_count_per_spawn = 2
	entry_rampage.elite_chance = 0.0

	spawn_entries = [entry_small, entry_medium, entry_big, entry_mine, entry_overlord, entry_rampage]

	PoolManager.register_pool(&"MagicBolt", preload("res://magic_bolt.tscn"), 5, 3)
	PoolManager.register_pool(&"Fireball", preload("res://fireball.tscn"), 5, 3)
	PoolManager.register_pool(&"OrbitArcane", preload("res://orbit_arcane.tscn"), 10)
	PoolManager.register_pool(&"CurrencyOrb", preload("res://Entities/Pickups/currency_orb.tscn"), 20, 5)

	_heart_scene = PackedScene.new()
	var heart_node := HealthHeart.new()
	heart_node.name = "HealthHeart"
	_heart_scene.pack(heart_node)
	heart_node.free()
	PoolManager.register_pool(_heart_pool_name, _heart_scene, 10)

	_power_up_scene = PackedScene.new()
	var pu_node := PowerUpPickup.new()
	pu_node.name = "PowerUpPickup"
	_power_up_scene.pack(pu_node)
	pu_node.free()
	PoolManager.register_pool(_power_up_pool_name, _power_up_scene, 10)

	_build_phase_schedule()
	_initialized = true

func _build_phase_schedule() -> void:
	_phase_schedule = [
			{
				"name": "Phase 1: Drone Invasion",
				"sub_phases": [
					{"type": SubPhase.TRICKLE_LIGHT, "duration": 30.0, "composition": {"small": 0.4, "medium": 0.6}, "rate_mult": 0.8, "batch": 2},
					{"type": SubPhase.TRICKLE_MEDIUM, "duration": 30.0, "composition": {"small": 0.3, "medium": 0.7}, "rate_mult": 1.5, "batch": 3},
					{"type": SubPhase.BURST_WAVE, "duration": 20.0, "composition": {"small": 0.25, "medium": 0.75}, "rate_mult": 2.5, "batch": 5},
					{"type": SubPhase.BOSS_SPAWN, "duration": 1.0, "composition": {"small": 0.4, "medium": 0.6}, "rate_mult": 0.0, "batch": 1, "boss_phase": 1},
					{"type": SubPhase.BREATHER, "duration": 20.0, "composition": {"small": 1.0}, "rate_mult": 0.4, "batch": 2},
				]
			},
			{
				"name": "Phase 2: Minefield",
				"sub_phases": [
					{"type": SubPhase.TRICKLE_LIGHT, "duration": 25.0, "composition": {"small": 0.4, "mine": 0.6}, "rate_mult": 1.0, "batch": 2},
					{"type": SubPhase.TRICKLE_MEDIUM, "duration": 25.0, "composition": {"small": 0.35, "mine": 0.65}, "rate_mult": 1.8, "batch": 3},
					{"type": SubPhase.BURST_WAVE, "duration": 15.0, "composition": {"small": 0.3, "mine": 0.7}, "rate_mult": 3.0, "batch": 5},
					{"type": SubPhase.BOSS_SPAWN, "duration": 1.0, "composition": {"small": 0.4, "mine": 0.6}, "rate_mult": 0.0, "batch": 1, "boss_phase": 2},
					{"type": SubPhase.BREATHER, "duration": 20.0, "composition": {"small": 1.0}, "rate_mult": 0.4, "batch": 2},
				]
			},
			{
				"name": "Phase 3: Iron Wall",
				"sub_phases": [
					{"type": SubPhase.TRICKLE_LIGHT, "duration": 25.0, "composition": {"small": 0.45, "big": 0.55}, "rate_mult": 1.3, "batch": 2},
					{"type": SubPhase.TRICKLE_MEDIUM, "duration": 25.0, "composition": {"small": 0.4, "big": 0.6}, "rate_mult": 2.2, "batch": 3},
					{"type": SubPhase.BURST_WAVE, "duration": 15.0, "composition": {"small": 0.35, "big": 0.65}, "rate_mult": 3.5, "batch": 5},
					{"type": SubPhase.BOSS_SPAWN, "duration": 1.0, "composition": {"small": 0.4, "big": 0.6}, "rate_mult": 0.0, "batch": 1, "boss_phase": 3},
					{"type": SubPhase.BREATHER, "duration": 20.0, "composition": {"small": 1.0}, "rate_mult": 0.4, "batch": 2},
				]
			},
			{
				"name": "Phase 4: Berserk",
				"sub_phases": [
					{"type": SubPhase.TRICKLE_LIGHT, "duration": 20.0, "composition": {"small": 0.35, "rampage": 0.65}, "rate_mult": 1.6, "batch": 2},
					{"type": SubPhase.TRICKLE_MEDIUM, "duration": 20.0, "composition": {"small": 0.3, "rampage": 0.7}, "rate_mult": 2.7, "batch": 3},
					{"type": SubPhase.BURST_WAVE, "duration": 15.0, "composition": {"small": 0.25, "rampage": 0.75}, "rate_mult": 4.2, "batch": 4},
					{"type": SubPhase.BOSS_SPAWN, "duration": 1.0, "composition": {"small": 0.3, "rampage": 0.7}, "rate_mult": 0.0, "batch": 1, "boss_phase": 4},
					{"type": SubPhase.BREATHER, "duration": 15.0, "composition": {"small": 1.0}, "rate_mult": 0.4, "batch": 2},
				]
			},
			{
				"name": "Phase 5: Overlord",
				"sub_phases": [
					{"type": SubPhase.TRICKLE_LIGHT, "duration": 20.0, "composition": {"small": 0.4, "overlord": 0.6}, "rate_mult": 2.0, "batch": 2},
					{"type": SubPhase.TRICKLE_MEDIUM, "duration": 20.0, "composition": {"small": 0.35, "overlord": 0.65}, "rate_mult": 3.3, "batch": 3},
					{"type": SubPhase.BURST_WAVE, "duration": 15.0, "composition": {"small": 0.3, "overlord": 0.7}, "rate_mult": 5.0, "batch": 4},
					{"type": SubPhase.BOSS_SPAWN, "duration": 1.0, "composition": {"small": 0.3, "overlord": 0.7}, "rate_mult": 0.0, "batch": 1, "boss_phase": 5},
					{"type": SubPhase.BREATHER, "duration": 15.0, "composition": {"small": 1.0}, "rate_mult": 0.4, "batch": 2},
				]
			},
	]

func _on_game_started() -> void:
	_spawn_delay = 1.5
	_wave_timer = 0.0
	_heart_timer = 30.0
	_power_up_timer = 60.0
	_orb_spawn_timer = 1.5
	_special_event_timer = 60.0
	_player_last_dir = Vector2.RIGHT
	_phase_index = 0
	_sub_phase_index = 0
	_sub_phase_timer = 0.0
	_cached_dirty = true
	_boss_chest_collected = false
	if _phase_schedule.size() > 0 and _phase_schedule[0]["sub_phases"].size() > 0:
		_sub_phase = _phase_schedule[0]["sub_phases"][0]["type"]

var _cached_comp: Dictionary = {}
var _cached_dirty: bool = true

func _process(delta: float) -> void:
	if not _initialized or not GameManager.is_playing():
		return

	_process_spawn_queue(delta)

	if GameManager.is_boss_fight():
		return

	# Tick safety timeout for boss-chest collection.
	if _boss_dead and not _boss_chest_collected:
		_boss_dead_timer += delta
	else:
		_boss_dead_timer = 0.0

	# Re-evaluate the on-screen cap only when the phase actually changes.
	if _phase_index != _prev_phase_index:
		_prev_phase_index = _phase_index
		max_enemies_on_screen = mini(300 + _phase_index * 120, 800)

	if _spawn_delay > 0.0:
		_spawn_delay -= delta
		return

	_update_player_direction()

	var prev_sub := _sub_phase_index
	_advance_sub_phase(delta)
	if _sub_phase_index != prev_sub:
		_cached_dirty = true

	if _cached_dirty:
		_cached_comp = _get_current_composition()
		_cached_hp_mult = difficulty_manager.get_enemy_hp_multiplier()
		_cached_speed_mult = difficulty_manager.get_enemy_speed_multiplier()
		_cached_dmg_mult = difficulty_manager.get_enemy_damage_multiplier()
		_cached_scaled.clear()
		_cached_dirty = false

	var player := GameManager.get_player()
	if player:
		var player_pos := player.global_position
		var player_dir := _player_last_dir

		# Density is now driven by the active sub-phase's rate_mult
		# (with a gentle +15% global escalation toward the 10-minute mark).
		var is_breather := _sub_phase == SubPhase.BREATHER
		var rate_mult := _get_current_rate_mult()

		# Waves are disabled during the breather (only trickle of swarm).
		if not is_breather:
			_wave_timer += delta
			if _first_wave:
				_wave_timer = maxf(5.0 / rate_mult, 1.2) * 0.5
				_first_wave = false

			var wave_interval := maxf(5.0 / rate_mult, 1.2)
			if _wave_timer >= wave_interval:
				_wave_timer = 0.0
				var config := _build_wave_config(GameManager.game_time)
				for g in range(config["num_groups"]):
					var effective := SwarmManager.get_count() + EnemyMeshManager.get_total_count()
					if effective >= max_enemies_on_screen:
						break
					_spawn_wave_group(config, player_pos, player_dir)

		# Trickle: fixed low rate (swarm-only) during breather, else scales with rate_mult.
		var trickle_rate: float = 0.4 if is_breather else rate_mult * 0.5
		if trickle_rate > 0.0:
			var trickle_interval := 1.0 / trickle_rate
			_trickle_accumulator += delta
			while _trickle_accumulator >= trickle_interval:
				_trickle_accumulator -= trickle_interval
				var effective := SwarmManager.get_count() + EnemyMeshManager.get_total_count()
				if effective >= max_enemies_on_screen:
					_trickle_accumulator = 0.0
					break
				_spawn_trickle_enemy(player_pos, player_dir)

	_special_event_timer -= delta
	if _special_event_timer <= 0.0:
		_special_event_timer = difficulty_manager.get_special_event_interval()
		_trigger_special_event()

	_heart_timer -= delta
	if _heart_timer <= 0.0:
		_heart_timer = randf_range(25.0, 45.0)
		_spawn_heart()

	_power_up_timer -= delta
	if _power_up_timer <= 0.0:
		_power_up_timer = randf_range(45.0, 90.0)
		_spawn_power_up()

	_orb_spawn_timer -= delta
	if _orb_spawn_timer <= 0.0:
		_orb_spawn_timer = randf_range(1.5, 3.5)
		_spawn_ambient_orb()

func _advance_sub_phase(delta: float) -> void:
	if _phase_index >= _phase_schedule.size():
		if not _boss_active:
			EventBus.all_phases_completed.emit()
		return

	var phase: Dictionary = _phase_schedule[_phase_index]
	var sub_phases: Array = phase["sub_phases"]
	if _sub_phase_index >= sub_phases.size():
		_phase_index += 1
		_sub_phase_index = 0
		_sub_phase_timer = 0.0
		if _phase_index < _phase_schedule.size():
			_sub_phase = _phase_schedule[_phase_index]["sub_phases"][0]["type"]
			if not _phase_schedule[_phase_index]["name"].begins_with("Break"):
				ActionProfiler.probe("wave", _phase_schedule[_phase_index]["name"])
				SoundManager.play_sound("wave_start")
		return

	var current_sub: Dictionary = sub_phases[_sub_phase_index]
	var duration: float = current_sub["duration"]

	if current_sub["type"] == SubPhase.BOSS_SPAWN:
		if GameManager.is_boss_fight():
			return
		if not _boss_active and not _boss_dead:
			var boss_phase_num: int = current_sub.get("boss_phase", 1)
			var player := GameManager.get_player()
			if player:
				BossManager.spawn_boss(boss_phase_num, player.global_position)
				_boss_active = true
				_boss_phase_num = boss_phase_num
				GameManager.enter_boss_fight()
			return
		if _boss_active and not _boss_dead:
			return
		# Safety timeout: auto-advance if chest is ignored for 30s.
		if _boss_dead and not _boss_chest_collected and _boss_dead_timer >= 30.0:
			_boss_chest_collected = true
		if _boss_dead and _boss_chest_collected:
			_boss_dead = false
			_boss_chest_collected = false
			_sub_phase_timer = 0.0
			_sub_phase_index += 1
			if _sub_phase_index >= sub_phases.size():
				_phase_index += 1
				_sub_phase_index = 0
				if _phase_index < _phase_schedule.size():
					_sub_phase = _phase_schedule[_phase_index]["sub_phases"][0]["type"]
					if not _phase_schedule[_phase_index]["name"].begins_with("Break"):
						ActionProfiler.probe("wave", _phase_schedule[_phase_index]["name"])
						SoundManager.play_sound("wave_start")
		return

	if duration <= 0.0:
		return

	_sub_phase_timer += delta
	if _sub_phase_timer >= duration:
		_sub_phase_timer = 0.0
		_sub_phase_index += 1
		var phase_ended := _sub_phase_index >= sub_phases.size()
		if phase_ended:
			_phase_index += 1
			_sub_phase_index = 0
			if _phase_index < _phase_schedule.size():
				_sub_phase = _phase_schedule[_phase_index]["sub_phases"][0]["type"]
				if not _phase_schedule[_phase_index]["name"].begins_with("Break"):
					ActionProfiler.probe("wave", _phase_schedule[_phase_index]["name"])
					SoundManager.play_sound("wave_start")
		else:
			_sub_phase = sub_phases[_sub_phase_index]["type"]

func _get_current_composition() -> Dictionary:
	if _phase_index >= _phase_schedule.size():
		return {"small": 0.5, "medium": 0.5}
	var sub_phases: Array = _phase_schedule[_phase_index]["sub_phases"]
	if _sub_phase_index >= sub_phases.size():
		return {"small": 0.5, "medium": 0.5}
	return sub_phases[_sub_phase_index]["composition"]

# Returns the dict describing the active sub-phase, or {} when out of schedule.
func _get_current_sub_phase_dict() -> Dictionary:
	if _phase_index >= _phase_schedule.size():
		return {}
	var sub_phases: Array = _phase_schedule[_phase_index]["sub_phases"]
	if _sub_phase_index >= sub_phases.size():
		return {}
	return sub_phases[_sub_phase_index]

# Density multiplier for the active sub-phase. A gentle global escalation of
# up to +15% toward the 10-minute mark keeps the late game tense without
# overriding the per-phase curve.
func _get_current_rate_mult() -> float:
	var base := float(_get_current_sub_phase_dict().get("rate_mult", 2.0))
	var t := clampf(GameManager.game_time / 600.0, 0.0, 1.0)
	var global_escalation := lerpf(1.0, 1.15, t)
	return base * global_escalation

func _pick_from_composition(comp: Dictionary) -> EnemyData:
	var roll := randf()
	var cumulative := 0.0
	var keys := ["small", "medium", "mine", "big", "overlord", "rampage"]
	var datas := [_small_data, _medium_data, _mine_data, _big_data, _overlord_data, _rampage_data]
	for i in range(keys.size()):
		var w: float = comp.get(keys[i], 0.0)
		cumulative += w
		if roll <= cumulative:
			return datas[i]
	return _small_data

func _ramp_enemies_per_group(elapsed: float) -> int:
	var step := mini(int(elapsed / 60.0), 4)
	var counts := [3, 6, 10, 14, 18]
	return counts[step]

func _ramp_spawn_arc_degrees(elapsed: float) -> float:
	var t := minf(elapsed / 300.0, 1.0)
	return lerpf(80.0, 120.0, t)

func _get_directional_spawn_pos(wave_type: WaveType, player_pos: Vector2, player_dir: Vector2) -> Vector2:
	var angle: float
	match wave_type:
		WaveType.SURROUND:
			angle = randf_range(0.0, TAU)
		WaveType.DIRECTIONAL:
			angle = player_dir.angle() + randf_range(-PI * 0.3, PI * 0.3)
		WaveType.AMBUSH:
			angle = player_dir.angle() + PI + randf_range(-PI * 0.15, PI * 0.15)
	var dist := randf_range(MIN_SPAWN_DIST, MAX_SPAWN_DIST)
	return player_pos + Vector2(cos(angle), sin(angle)) * dist

func _build_wave_config(elapsed: float) -> Dictionary:
	var count := _ramp_enemies_per_group(elapsed)
	var arc := _ramp_spawn_arc_degrees(elapsed)
	# Wave grouping grows from 1 to 2 groups after the first minute.
	# (Wave frequency itself is driven by the sub-phase rate_mult in _process.)
	var num_groups := 1 if elapsed < 60.0 else 2

	var wave_type: WaveType
	if elapsed < 30.0:
		wave_type = WaveType.SURROUND
	elif elapsed < 120.0:
		wave_type = WaveType.DIRECTIONAL if randf() > 0.3 else WaveType.SURROUND
	else:
		var roll := randf()
		if roll < 0.4:
			wave_type = WaveType.SURROUND
		elif roll < 0.75:
			wave_type = WaveType.DIRECTIONAL
		else:
			wave_type = WaveType.AMBUSH

	return {
		"wave_type": wave_type,
		"count": count,
		"arc": arc,
		"num_groups": num_groups,
	}

func _spawn_wave_group(config: Dictionary, player_pos: Vector2, player_dir: Vector2) -> void:
	var wave_type: WaveType = config["wave_type"]
	var count: int = config["count"]
	var comp := _get_current_composition()

	for i in range(count):
		var effective_count := SwarmManager.get_count() + EnemyMeshManager.get_total_count()
		if effective_count >= max_enemies_on_screen:
			return
		var data := _pick_from_composition(comp)
		var spawn_pos := _get_directional_spawn_pos(wave_type, player_pos, player_dir)
		var scaled_data := _apply_difficulty_scaling(data)
		_spawn_queue.append({"pos": spawn_pos, "data": scaled_data})

func _process_spawn_queue(_delta: float) -> void:
	var budget: int = 2
	while budget > 0 and _spawn_queue.size() > 0:
		var entry: Dictionary = _spawn_queue.pop_front()
		_spawn_single_enemy(entry["pos"], entry["data"])
		budget -= 1

func _spawn_trickle_enemy(player_pos: Vector2, player_dir: Vector2) -> void:
	var effective_count := SwarmManager.get_count() + EnemyMeshManager.get_total_count()
	if effective_count >= max_enemies_on_screen:
		return
	# During a breather only swarm (small/fast) trickles in — no waves, no tanks.
	var data: EnemyData = _small_data if _sub_phase == SubPhase.BREATHER else _pick_from_composition(_get_current_composition())
	var spawn_pos := _get_directional_spawn_pos(WaveType.SURROUND, player_pos, player_dir)
	var scaled_data := _apply_difficulty_scaling(data)
	_spawn_single_enemy(spawn_pos, scaled_data)

func _update_player_direction() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var vel: Vector2 = player.velocity
	if vel.length_squared() > 4.0:
		_player_last_dir = vel.normalized()

func _spawn_single_enemy(spawn_pos: Vector2, data: EnemyData) -> void:
	var hp_mod: float = 1.0
	var player := GameManager.get_player()
	if player and "stats" in player and player.stats:
		hp_mod = clampf(player.stats.enemy_max_hp_mult, 0.1, 1.0)
	if data.enemy_class == EnemyData.EnemyClass.SMALL_FAST:
		var direction := spawn_pos.direction_to(GameManager.get_player().global_position)
		SwarmManager.spawn(spawn_pos, direction, data.max_hp * hp_mod, data.speed, data.explosion_damage, data.xp_value)
		return
	match data.enemy_class:
		EnemyData.EnemyClass.MEDIUM:
			EnemyMeshManager.spawn_medium(spawn_pos, data.max_hp * hp_mod, data.speed, data.damage, data.xp_value)
		EnemyData.EnemyClass.BIG_TANK:
			EnemyMeshManager.spawn_big(spawn_pos, data.max_hp * hp_mod, data.speed, data.damage, data.explosion_damage, data.pushback_force, data.xp_value)
		EnemyData.EnemyClass.MINE:
			EnemyMeshManager.spawn_mine(spawn_pos, data.max_hp * hp_mod, data.speed, data.damage, data.explosion_damage, data.xp_value)
		EnemyData.EnemyClass.OVERLORD:
			EnemyMeshManager.spawn_overlord(spawn_pos, data.max_hp * hp_mod, data.max_hp * hp_mod, data.speed, data.damage, data.explosion_damage, data.xp_value)
		EnemyData.EnemyClass.RAMPAGE:
			EnemyMeshManager.spawn_rampage(spawn_pos, data.max_hp * hp_mod, data.speed, data.damage, data.xp_value)

func _apply_difficulty_scaling(base_data: EnemyData) -> EnemyData:
	var cache_key: int = base_data.enemy_class
	if _cached_scaled.has(cache_key):
		return _cached_scaled[cache_key]
	var scaled := EnemyData.new()
	scaled.enemy_name = base_data.enemy_name
	scaled.enemy_class = base_data.enemy_class
	var hp_mult := _cached_hp_mult
	if base_data.enemy_class == EnemyData.EnemyClass.SMALL_FAST:
		hp_mult = 1.0 + (hp_mult - 1.0) * 0.3
	elif base_data.enemy_class == EnemyData.EnemyClass.MINE:
		hp_mult = 1.0 + (hp_mult - 1.0) * 0.2
	elif base_data.enemy_class == EnemyData.EnemyClass.RAMPAGE:
		hp_mult = 1.0 + (hp_mult - 1.0) * 0.4
	scaled.max_hp = base_data.max_hp * hp_mult
	scaled.speed = base_data.speed * _cached_speed_mult
	scaled.damage = base_data.damage * _cached_dmg_mult
	scaled.xp_value = base_data.xp_value * difficulty_manager.get_xp_multiplier()
	scaled.collision_radius = base_data.collision_radius
	scaled.seek_weight = base_data.seek_weight
	scaled.separation_weight = base_data.separation_weight
	scaled.separation_radius = base_data.separation_radius
	scaled.avoid_player_radius = base_data.avoid_player_radius
	scaled.explodes_on_contact = base_data.explodes_on_contact
	scaled.explosion_damage = base_data.explosion_damage * _cached_dmg_mult
	scaled.cannot_be_pushed = base_data.cannot_be_pushed
	scaled.pushback_force = base_data.pushback_force
	scaled.pool_name = base_data.pool_name
	scaled.sprite_texture = base_data.sprite_texture
	scaled.sprite_scale = base_data.sprite_scale
	scaled.modulate_color = base_data.modulate_color
	_cached_scaled[cache_key] = scaled
	return scaled

func _trigger_special_event() -> void:
	var event_type: int = _pick_special_event()
	var event_name: String = ["swarm_rush", "tank_column", "elite_wave"][event_type]
	ActionProfiler.probe("wave", "special_%s" % event_name)
	match event_type:
		SpecialEventType.SWARM_RUSH:
			_event_swarm_rush()
		SpecialEventType.TANK_COLUMN:
			_event_tank_column()
		SpecialEventType.ELITE_WAVE:
			_event_elite_wave()

func _pick_special_event() -> int:
	var difficulty := difficulty_manager.get_difficulty_multiplier()
	var weights := [3.0, 0.5, 0.3]
	if difficulty >= 2.0:
		weights[1] = 1.5
		weights[2] = 1.0
	if difficulty >= 4.0:
		weights[1] = 2.0
		weights[2] = 2.5
	var total := 0.0
	for w in weights:
		total += w
	var roll := randf() * total
	var cumulative := 0.0
	for i in range(weights.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return i
	return 0

func _event_swarm_rush() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var count := 25 + int(difficulty_manager.get_difficulty_multiplier() * 10)
	var comp := _cached_comp
	for i in range(count):
		var spawn_pos := _get_directional_spawn_pos(WaveType.SURROUND, player.global_position, _player_last_dir)
		var data := _pick_from_composition(comp)
		var scaled_data := _apply_difficulty_scaling(data)
		if data.enemy_class == EnemyData.EnemyClass.SMALL_FAST:
			var direction := spawn_pos.direction_to(player.global_position)
			SwarmManager.spawn(spawn_pos, direction, scaled_data.max_hp, scaled_data.speed, scaled_data.explosion_damage, scaled_data.xp_value)
		else:
			match data.enemy_class:
				EnemyData.EnemyClass.MEDIUM:
					EnemyMeshManager.spawn_medium(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.xp_value)
				EnemyData.EnemyClass.MINE:
					EnemyMeshManager.spawn_mine(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, scaled_data.xp_value)
				EnemyData.EnemyClass.BIG_TANK:
					EnemyMeshManager.spawn_big(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, data.pushback_force, scaled_data.xp_value)
				EnemyData.EnemyClass.OVERLORD:
					EnemyMeshManager.spawn_overlord(spawn_pos, scaled_data.max_hp, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, scaled_data.xp_value)
				EnemyData.EnemyClass.RAMPAGE:
					EnemyMeshManager.spawn_rampage(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.xp_value)

func _event_tank_column() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var count := 4 + int(difficulty_manager.get_difficulty_multiplier() * 2)
	for i in range(count):
		var spawn_pos := _get_directional_spawn_pos(WaveType.DIRECTIONAL, player.global_position, _player_last_dir)
		var data := _big_data if randf() > 0.3 else _overlord_data
		var scaled_data := _apply_difficulty_scaling(data)
		if data.enemy_class == EnemyData.EnemyClass.BIG_TANK:
			EnemyMeshManager.spawn_big(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, data.pushback_force, scaled_data.xp_value)
		else:
			EnemyMeshManager.spawn_overlord(spawn_pos, scaled_data.max_hp, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, scaled_data.xp_value)

func _event_elite_wave() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var count := 10 + int(difficulty_manager.get_difficulty_multiplier() * 5)
	var comp := _cached_comp
	for i in range(count):
		var data := _pick_from_composition(comp)
		var spawn_pos := _get_directional_spawn_pos(WaveType.SURROUND, player.global_position, _player_last_dir)
		var scaled_data := _apply_difficulty_scaling(data)
		if data.enemy_class == EnemyData.EnemyClass.SMALL_FAST:
			var direction := spawn_pos.direction_to(player.global_position)
			SwarmManager.spawn(spawn_pos, direction, scaled_data.max_hp, scaled_data.speed, scaled_data.explosion_damage, scaled_data.xp_value)
			continue
		match data.enemy_class:
			EnemyData.EnemyClass.MEDIUM:
				EnemyMeshManager.spawn_medium(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.xp_value)
			EnemyData.EnemyClass.BIG_TANK:
				EnemyMeshManager.spawn_big(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, data.pushback_force, scaled_data.xp_value)
			EnemyData.EnemyClass.MINE:
				EnemyMeshManager.spawn_mine(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, scaled_data.xp_value)
			EnemyData.EnemyClass.OVERLORD:
				EnemyMeshManager.spawn_overlord(spawn_pos, scaled_data.max_hp, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.explosion_damage, scaled_data.xp_value)
			EnemyData.EnemyClass.RAMPAGE:
				EnemyMeshManager.spawn_rampage(spawn_pos, scaled_data.max_hp, scaled_data.speed, scaled_data.damage, scaled_data.xp_value)

func _on_enemy_died(_pos: Vector2, _xp: float, _type: StringName) -> void:
	GameManager.enemies_killed += 1

func _on_boss_defeated(_boss_name: String, _pos: Vector2) -> void:
	_boss_active = false
	_boss_dead = true

func _on_chest_opened(_artifacts: Array, _rarity: int, is_boss_chest: bool = false) -> void:
	if _boss_dead and is_boss_chest:
		_boss_chest_collected = true

func _on_artifact_equipped(_artifact: Resource) -> void:
	if _boss_dead and _boss_chest_collected:
		GameManager.call_deferred(&"exit_boss_fight")

func _spawn_heart() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var spawn_pos := _get_directional_spawn_pos(WaveType.SURROUND, player.global_position, _player_last_dir)
	var heart := PoolManager.spawn(_heart_pool_name, spawn_pos)
	if heart:
		if heart.has_method("on_spawn"):
			heart.on_spawn()

func _spawn_power_up() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var spawn_pos := _get_directional_spawn_pos(WaveType.SURROUND, player.global_position, _player_last_dir)
	var pickup := PoolManager.spawn(_power_up_pool_name, spawn_pos)
	if pickup:
		var type_roll := randf()
		var pu_type: PowerUpData.PowerUpType
		if type_roll < 0.2:
			pu_type = PowerUpData.PowerUpType.INVULNERABILITY
		elif type_roll < 0.4:
			pu_type = PowerUpData.PowerUpType.DAMAGE_MULTIPLIER
		elif type_roll < 0.55:
			pu_type = PowerUpData.PowerUpType.SPEED_BOOST
		elif type_roll < 0.7:
			pu_type = PowerUpData.PowerUpType.FREEZE_ENEMIES
		elif type_roll < 0.85:
			pu_type = PowerUpData.PowerUpType.FIRE_RATE_BOOST
		else:
			pu_type = PowerUpData.PowerUpType.MEGA_MAGNET
		var data := PowerUpData.new()
		data.power_up_type = pu_type
		if pickup.has_method("set_data"):
			pickup.set_data(data)
		if pickup.has_method("on_spawn"):
			pickup.on_spawn()

func _spawn_ambient_orb() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	if OrbManager.get_active_count() >= max_orbs_on_screen:
		return
	var count := 2
	var time := GameManager.game_time
	if time > 60.0:
		count = 3
	if time > 180.0:
		count = 5
	for _i in range(count):
		var spawn_pos := _get_orb_spawn_pos(player)
		var orb_value: float
		var roll := randf()
		if time < 30.0:
			if roll < 0.5:
				orb_value = 3.0
			elif roll < 0.85:
				orb_value = 12.0
			else:
				orb_value = 35.0
		else:
			if roll < 0.3:
				orb_value = 3.0
			elif roll < 0.65:
				orb_value = 12.0
			elif roll < 0.9:
				orb_value = 35.0
			else:
				orb_value = 80.0
		OrbManager.spawn_orb(spawn_pos, orb_value)

func _get_orb_spawn_pos(player: Node2D) -> Vector2:
	if randf() < 0.2:
		var angle := randf() * TAU
		var dist := randf_range(80.0, 300.0)
		return player.global_position + Vector2.RIGHT.rotated(angle) * dist
	return _get_directional_spawn_pos(WaveType.SURROUND, player.global_position, _player_last_dir)
