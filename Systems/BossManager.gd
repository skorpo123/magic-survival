extends Node

const BOSS_PHASES := {
	1: {name = &"Volt Sentinel", type = &"medium", hp_mult = 3.0, color = Color(0.9, 0.8, 0.2)},
	2: {name = &"Blast Architect", type = &"mine", hp_mult = 2.5, color = Color(0.9, 0.3, 0.15)},
	3: {name = &"Iron Titan", type = &"big", hp_mult = 3.5, color = Color(0.6, 0.6, 0.65)},
	4: {name = &"Fury Monarch", type = &"rampage", hp_mult = 4.0, color = Color(0.85, 0.15, 0.25)},
	5: {name = &"Abyss Warden", type = &"overlord", hp_mult = 5.0, color = Color(0.15, 0.05, 0.35)},
}

var _boss_active: bool = false
var _boss_name: StringName = &""
var _boss_hp: float = 0.0
var _boss_max_hp: float = 0.0
var _boss_pos: Vector2 = Vector2.ZERO
var _boss_timer: float = 0.0
var _boss_attack_timer: float = 0.0
var _boss_minion_timer: float = 0.0
var _boss_phase: int = 0
var _boss_color: Color = Color.WHITE
var _boss_type: StringName = &""
var _boss_mesh_key: StringName = &""
var _boss_base_speed: float = 0.0
var _boss_speed: float = 0.0
var _boss_slot_idx: int = -1
var _is_enraged: bool = false
var _cur_attack_interval: float = 2.5
var _cur_minion_interval: float = 8.0

const MINION_SPAWN_INTERVAL := 8.0

const BOSS_SPEEDS := {
	&"medium": 70.0,
	&"mine": 55.0,
	&"big": 45.0,
	&"rampage": 85.0,
	&"overlord": 40.0,
}

const ENRAGE_HP_RATIO := 0.3

const BOSS_ATTACK_INTERVALS := {
	&"medium": 2.5,
	&"mine": 3.2,
	&"big": 3.8,
	&"rampage": 2.0,
	&"overlord": 2.8,
}

const BOSS_MINION_INTERVALS := {
	&"medium": 8.0,
	&"mine": 10.0,
	&"big": 6.0,
	&"rampage": 7.0,
	&"overlord": 5.0,
}

func _ready() -> void:
	set_process(false)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	_boss_active = false
	_boss_slot_idx = -1
	_is_enraged = false
	set_process(false)

func _on_boss_spawned(_name: String, _max_hp: float, _pos: Vector2) -> void:
	pass

func spawn_boss(phase: int, player_pos: Vector2) -> void:
	if _boss_active:
		return
	if phase not in BOSS_PHASES:
		return

	var bd: Dictionary = BOSS_PHASES[phase]
	_boss_phase = phase
	_boss_name = bd.name
	_boss_type = bd.type
	_boss_color = bd.color
	match _boss_type:
		&"medium": _boss_mesh_key = &"medium_boss"
		&"mine": _boss_mesh_key = &"mine_boss"
		&"big": _boss_mesh_key = &"big_boss"
		&"rampage": _boss_mesh_key = &"rampage_boss"
		&"overlord": _boss_mesh_key = &"overlord_boss"
		_: _boss_mesh_key = &"medium_boss"

	var base_hp: float = 500.0
	var player := GameManager.get_player()
	if player and "stats" in player and player.stats is PlayerStats:
		base_hp += player.stats.max_hp * 2.0

	var phase_scale: float = 1.0 + float(phase) * 0.2
	_boss_max_hp = base_hp * bd.hp_mult * phase_scale
	if player and "stats" in player and player.stats is PlayerStats:
		_boss_max_hp *= clampf(player.stats.enemy_max_hp_mult, 0.1, 1.0)
	_boss_hp = _boss_max_hp

	var angle := randf() * TAU
	var dist := 400.0 + randf() * 200.0
	_boss_pos = player_pos + Vector2(cos(angle), sin(angle)) * dist

	_boss_base_speed = BOSS_SPEEDS.get(_boss_type, 55.0)
	_boss_speed = _boss_base_speed
	_is_enraged = false
	_cur_attack_interval = BOSS_ATTACK_INTERVALS.get(_boss_type, 2.5)
	_cur_minion_interval = BOSS_MINION_INTERVALS.get(_boss_type, 8.0)
	_boss_attack_timer = _cur_attack_interval * 0.5
	_boss_minion_timer = _cur_minion_interval
	_boss_active = true

	_spawn_boss_body()

	set_process(true)
	EventBus.boss_spawned.emit(_boss_name, _boss_max_hp, _boss_pos)

func _spawn_boss_body() -> void:
	var emm: EnemyMeshManager = EnemyMeshManager
	var boss_key: StringName = &"medium_boss"
	match _boss_type:
		&"medium":
			boss_key = &"medium_boss"
		&"mine":
			boss_key = &"mine_boss"
		&"big":
			boss_key = &"big_boss"
		&"rampage":
			boss_key = &"rampage_boss"
		&"overlord":
			boss_key = &"overlord_boss"
	_boss_slot_idx = emm.spawn_boss(_boss_pos, _boss_max_hp, _boss_max_hp, _boss_speed, 25.0, 0.0, 0.0, 50.0, Color.WHITE, boss_key)

func _defeat_boss() -> void:
	if not _boss_active:
		return
	_boss_active = false
	_boss_slot_idx = -1
	set_process(false)
	EventBus.boss_defeated.emit(_boss_name, _boss_pos)
	ChestTracker.spawn_legendary_chest(_boss_pos)

func _process(delta: float) -> void:
	if not _boss_active:
		return

	_boss_timer += delta

	_check_boss_hp()

	var emm: EnemyMeshManager = EnemyMeshManager
	if _boss_slot_idx >= 0 and emm.is_slot_alive(_boss_mesh_key, _boss_slot_idx):
		var player := GameManager.get_player()
		if player:
			var boss_pos: Vector2 = emm.get_slot_pos(_boss_mesh_key, _boss_slot_idx)
			var dir: Vector2 = (player.global_position - boss_pos).normalized()
			var new_pos: Vector2 = boss_pos + dir * _boss_speed * delta
			emm.set_slot_pos(_boss_mesh_key, _boss_slot_idx, new_pos)
			_boss_pos = new_pos

	_boss_attack_timer -= delta
	if _boss_attack_timer <= 0.0:
		_boss_attack_timer = _cur_attack_interval
		_perform_boss_attack()

	_boss_minion_timer -= delta
	if _boss_minion_timer <= 0.0:
		_boss_minion_timer = _cur_minion_interval
		_spawn_boss_minions()

func _check_boss_hp() -> void:
	if _boss_slot_idx < 0:
		return
	var emm: EnemyMeshManager = EnemyMeshManager
	if not emm.is_slot_alive(_boss_mesh_key, _boss_slot_idx):
		_defeat_boss()
		return
	var current_hp: float = emm.get_slot_hp(_boss_mesh_key, _boss_slot_idx)
	_boss_hp = current_hp
	_boss_pos = emm.get_slot_pos(_boss_mesh_key, _boss_slot_idx)

	var hp_ratio := _boss_hp / _boss_max_hp
	if not _is_enraged and hp_ratio <= ENRAGE_HP_RATIO:
		_is_enraged = true
		_cur_attack_interval = BOSS_ATTACK_INTERVALS.get(_boss_type, 2.5) * 0.6
		_cur_minion_interval = BOSS_MINION_INTERVALS.get(_boss_type, 8.0) * 0.5
		_boss_speed = _boss_base_speed * 1.4
		EventBus.boss_enraged.emit(_boss_name)

	EventBus.boss_hp_changed.emit(_boss_hp, _boss_max_hp)

func _perform_boss_attack() -> void:
	var player := GameManager.get_player()
	if not player:
		return

	var dmg: float = 35.0 * (1.0 + _boss_phase * 0.35)
	if _is_enraged:
		dmg *= 1.5

	match _boss_type:
		&"medium":
			var radius := 200.0 if _is_enraged else 160.0
			_explode_nearby(dmg, radius)
		&"mine":
			var count := 8 if _is_enraged else 6
			_deploy_mines(dmg, count)
		&"big":
			var radius := 300.0 if _is_enraged else 220.0
			_ground_slam(dmg, radius)
		&"rampage":
			var dist := 600.0 if _is_enraged else 450.0
			_charge_attack(dmg * 1.5, dist)
		&"overlord":
			var count := 6 if _is_enraged else 5
			_summon_boss_minions(count)
			var radius := 340.0 if _is_enraged else 270.0
			_ground_slam(dmg, radius)

func _deploy_mines(damage: float, count: int) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	JuiceManager.screen_shake(5.0, 0.1)
	for i in range(count):
		var angle := TAU / count * i + randf() * 0.3
		var offset := Vector2(cos(angle), sin(angle)) * (100.0 + randf() * 80.0)
		var mine_pos := _boss_pos + offset
		BurstEffectPool.spawn("spark", mine_pos, Color(0.9, 0.3, 0.15))
		var t := create_tween()
		t.tween_interval(1.2)
		t.tween_callback(func() -> void:
			SwarmManager.damage_area(mine_pos, 60.0, damage * 0.7)
			EnemyMeshManager.damage_area(mine_pos, 60.0, damage * 0.7)
			BurstEffectPool.spawn("explosion", mine_pos, Color(0.9, 0.3, 0.15))
			if player and is_instance_valid(player) and player.global_position.distance_to(mine_pos) < 60.0:
				player.take_damage(damage * 0.7)
		)

func _explode_nearby(damage: float, radius: float) -> void:
	SwarmManager.damage_area(_boss_pos, radius, damage)
	EnemyMeshManager.damage_area(_boss_pos, radius, damage)
	BurstEffectPool.spawn("explosion", _boss_pos, _boss_color)
	JuiceManager.screen_shake(8.0, 0.15)
	var player := GameManager.get_player()
	if player and player.global_position.distance_to(_boss_pos) < radius:
		player.take_damage(damage)

func _ground_slam(damage: float, radius: float) -> void:
	SwarmManager.damage_area(_boss_pos, radius, damage)
	EnemyMeshManager.damage_area(_boss_pos, radius, damage)
	JuiceManager.screen_shake(12.0, 0.2)
	for i in range(8):
		var angle := TAU / 8.0 * i
		var offset := Vector2(cos(angle), sin(angle)) * radius * 0.6
		BurstEffectPool.spawn("explosion", _boss_pos + offset, _boss_color)
	var player := GameManager.get_player()
	if player and player.global_position.distance_to(_boss_pos) < radius:
		player.take_damage(damage)

func _charge_attack(damage: float, distance: float) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var dir := (player.global_position - _boss_pos).normalized()
	var to := _boss_pos + dir * distance
	SwarmManager.damage_line(_boss_pos, to, 30.0, damage)
	EnemyMeshManager.damage_line(_boss_pos, to, 32.0, damage)
	JuiceManager.screen_shake(6.0, 0.1)
	var closest_on_line := Geometry2D.get_closest_point_to_segment(player.global_position, _boss_pos, to)
	if closest_on_line.distance_to(player.global_position) < 36.0:
		player.take_damage(damage)

func _spawn_boss_minions() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var count := 2 + _boss_phase
	for i in range(count):
		var angle := TAU / count * i
		var offset := Vector2(cos(angle), sin(angle)) * 200.0
		var pos := _boss_pos + offset
		EnemyMeshManager.spawn_medium(pos, 30.0, 60.0, 8.0, 10.0, _boss_color)

func _summon_boss_minions(count: int) -> void:
	var player := GameManager.get_player()
	if not player:
		return
	for i in range(count):
		var angle := TAU / count * i + randf() * 0.5
		var offset := Vector2(cos(angle), sin(angle)) * 180.0
		var pos := _boss_pos + offset
		EnemyMeshManager.spawn_medium(pos, 40.0, 55.0, 10.0, 15.0, _boss_color)

func is_boss_active() -> bool:
	return _boss_active

func get_boss_name() -> StringName:
	return _boss_name

func get_boss_hp() -> float:
	return _boss_hp

func get_boss_max_hp() -> float:
	return _boss_max_hp
