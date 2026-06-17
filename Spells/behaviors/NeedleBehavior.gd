class_name NeedleBehavior
extends BaseSpellBehavior

enum MainState { CASCADE, COOLDOWN }
enum ModType { NONE, VOLLEY, FROST, RICOCHET }

@export var needle_range: float = 220.0
@export var needle_count: int = 1
@export var needle_speed: float = 500.0
@export var cooldown_time: float = 1.2
@export var dir_smooth_speed: float = 4.0
@export var spawn_offset: float = 15.0
@export var stabbed_duration: float = 0.5
@export var return_pierce_ratio: float = 0.5
@export var return_detect_radius: float = 30.0
@export var cascade_delay: float = 0.1
@export var cascade_spread: float = 8.0

var _main_state: int = MainState.COOLDOWN
var _cooldown_timer: float = 0.0
var _cascade_index: int = 0
var _cascade_timer: float = 0.0
var _caster_ref: Node2D = null
var _spell: Spell = null
var _player_stats: PlayerStats = null
var _smoothed_dir: Vector2 = Vector2.RIGHT
var _last_dir: Vector2 = Vector2.RIGHT
var _mod_type: int = ModType.NONE

var _puffs: Array = []
const POOL_SIZE: int = 24

func needs_periodic_cast() -> bool:
	return false

func requires_aim() -> bool:
	return false

func cast(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_added(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_spell = spell
	_player_stats = player_stats
	_detect_mod()
	_init_pool(caster)
	_cooldown_timer = 0.0
	for puff in _puffs:
		if is_instance_valid(puff):
			puff.returned_to_player.connect(_on_puff_returned)

func on_spell_upgraded(_caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_spell = spell
	_player_stats = player_stats
	_detect_mod()

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	for puff in _puffs:
		if is_instance_valid(puff):
			if puff.returned_to_player.is_connected(_on_puff_returned):
				puff.returned_to_player.disconnect(_on_puff_returned)
			puff.queue_free()
	_puffs.clear()

func _detect_mod() -> void:
	_mod_type = ModType.NONE
	if _spell and _spell.active_modification:
		var mid := _spell.active_modification.mod_id
		if mid == &"needle_volley":
			_mod_type = ModType.VOLLEY
		elif mid == &"needle_frost":
			_mod_type = ModType.FROST
		elif mid == &"needle_ricochet":
			_mod_type = ModType.RICOCHET

func tick(delta: float) -> void:
	var raw_dir := _get_player_direction()
	if raw_dir.length_squared() > 0.001:
		raw_dir = raw_dir.normalized()
		var dot_val: float = _smoothed_dir.dot(raw_dir)
		if dot_val < -0.5:
			_smoothed_dir = raw_dir
		else:
			_smoothed_dir = _smoothed_dir.lerp(raw_dir, minf(dir_smooth_speed * delta, 1.0)).normalized()

	var player := GameManager.get_player()
	if not player:
		return

	match _main_state:
		MainState.CASCADE:
			_cascade_timer += delta
			if _cascade_timer >= cascade_delay:
				_cascade_timer -= cascade_delay
				_launch_next(player)
				_cascade_index += 1
				if _cascade_index >= _get_cascade_total():
					_main_state = MainState.COOLDOWN
					_cooldown_timer = _get_cooldown_time()
		MainState.COOLDOWN:
			_cooldown_timer -= delta
			if _cooldown_timer <= 0.0:
				_cascade_index = 0
				_cascade_timer = 0.0
				_main_state = MainState.CASCADE

func get_cooldown_progress() -> float:
	if _main_state != MainState.COOLDOWN:
		return 0.0
	var cd_time := _get_cooldown_time()
	if cd_time <= 0.0:
		return 0.0
	return clampf(_cooldown_timer / cd_time, 0.0, 1.0)

func _get_cascade_total() -> int:
	match _mod_type:
		ModType.VOLLEY:
			return 1
		ModType.FROST:
			return 1
		ModType.RICOCHET:
			return 1
		_:
			return _get_effective_count()

func _launch_next(player: Node2D) -> void:
	var dmg_mult := 1.0
	if _player_stats:
		dmg_mult = _player_stats.magic_power
	var dmg := _spell.get_damage(dmg_mult) * _spell.roll_crit_mult(_player_stats)
	if _spell.was_last_crit(): EventBus.crit_landed.emit(dmg, player.global_position)
	var eff_range := _get_effective_range()
	var base_dir := _get_target_dir(player, eff_range)
	var origin := player.global_position + base_dir * spawn_offset
	var tint := _get_primary_color()

	match _mod_type:
		ModType.VOLLEY:
			var fans := 7
			var spread := deg_to_rad(45.0) / 6.0
			for f in range(fans):
				var dir := base_dir
				if fans > 1:
					var offset: float = (float(f) - (float(fans - 1) / 2.0)) * spread
					dir = base_dir.rotated(offset)
				_launch_puff(origin, dir, eff_range, dmg, tint, 0)
		ModType.FROST:
			var fans := 8
			var spread := TAU / 8.0
			for f in range(fans):
				var dir := base_dir.rotated(float(f) * spread)
				_launch_puff(origin, dir, eff_range, dmg, tint, 2)
		ModType.RICOCHET:
			_launch_puff(origin, base_dir, eff_range, dmg, tint, 3)
		_:
			var eff_count := _get_effective_count()
			var spread_rad := deg_to_rad(cascade_spread)
			for f in range(eff_count):
				var dir := base_dir
				if eff_count > 1:
					var offset: float = (float(f) - (float(eff_count - 1) / 2.0)) * spread_rad
					dir = base_dir.rotated(offset)
				_launch_puff(origin, dir, eff_range, dmg, tint, 0)

func _get_target_dir(player: Node2D, search_range: float) -> Vector2:
	var closest_s := SwarmManager.find_closest_pos(player.global_position, search_range * 1.2)
	var closest_m := EnemyMeshManager.find_closest_pos(player.global_position, search_range * 1.2)
	var best_pos := Vector2.ZERO
	var best_dist_sq := (search_range * 1.2) * (search_range * 1.2)
	if closest_s != Vector2.ZERO:
		var ds := player.global_position.distance_squared_to(closest_s)
		if ds < best_dist_sq:
			best_dist_sq = ds
			best_pos = closest_s
	if closest_m != Vector2.ZERO:
		var dm := player.global_position.distance_squared_to(closest_m)
		if dm < best_dist_sq:
			best_dist_sq = dm
			best_pos = closest_m
	if best_pos == Vector2.ZERO:
		return _smoothed_dir if _smoothed_dir.length_squared() > 0.001 else Vector2.RIGHT
	return (best_pos - player.global_position).normalized()

func _launch_puff(origin: Vector2, dir: Vector2, eff_range: float, damage: float, tint: Color, mod_type: int) -> void:
	var puff: NeedlePuff = null
	for p in _puffs:
		if is_instance_valid(p) and not p._alive:
			puff = p
			break
	if not puff:
		return
	var eff_stabbed := stabbed_duration
	if _spell:
		eff_stabbed *= _spell.get_duration_multiplier()
	puff.launch(origin, dir, eff_range, needle_speed, damage, _spell, mod_type, tint, return_pierce_ratio, return_detect_radius, eff_stabbed)

func _on_puff_returned() -> void:
	pass

func _get_effective_range() -> float:
	var r := needle_range
	if _spell:
		r *= _spell.get_area_multiplier()
	return r

func _get_effective_count() -> int:
	var count := needle_count
	if _spell:
		count += _spell.get_projectile_count() - 1
	return count

func _get_cooldown_time() -> float:
	if _spell:
		var cd_reduction: float = 0.0
		if _player_stats:
			cd_reduction = _player_stats.cooldown_reduction
		return _spell.get_cooldown(cd_reduction)
	return cooldown_time

func _get_player_direction() -> Vector2:
	var player := GameManager.get_player()
	if not player:
		return _last_dir
	var vel: Vector2 = player.velocity if "velocity" in player else Vector2.ZERO
	if vel.length_squared() > 4.0:
		_last_dir = vel.normalized()
		return _last_dir
	if is_instance_valid(_caster_ref) and _caster_ref is SpellCaster and "_last_cast_dir" in _caster_ref:
		var ld: Vector2 = _caster_ref._last_cast_dir
		if ld.length_squared() > 0.01:
			return ld
	return _last_dir

func _init_pool(caster: Node2D) -> void:
	for i in range(POOL_SIZE):
		var puff := NeedlePuff.new()
		caster.add_child(puff)
		_puffs.append(puff)

func _get_primary_color() -> Color:
	if _spell is SpellData and _spell.vfx_color_primary != Color.WHITE:
		return _spell.vfx_color_primary
	if _spell and _spell.active_modification and _spell.active_modification.color_tint != Color.WHITE:
		var tint := _spell.active_modification.color_tint
		return Color(tint.r, tint.g, tint.b, 0.95)
	return Color(0.85, 0.75, 0.95)
