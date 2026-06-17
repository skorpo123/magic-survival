class_name SpiritBehavior
extends BaseSpellBehavior

@export var base_orb_count: int = 1
@export var orbit_radius: float = 55.0
@export var chain_delay: float = 0.2
@export var chain_cooldown: float = 1.5
@export var bolt_speed: float = 600.0
@export var y_offset: float = -60.0
@export var spacing: float = 40.0
@export var row_gap: float = 32.0
@export var detect_range: float = 550.0

var _orbs: Array[SpiritOrb] = []
var _active_bolts: Array[SpiritBolt] = []
var _inactive_bolts: Array[SpiritBolt] = []
var _caster_parent: Node2D = null
var _chain_active: bool = false
var _chain_index: int = 0
var _chain_timer: float = 0.0
var _chain_cooldown_timer: float = 0.0
var _chain_target_pos: Vector2 = Vector2.ZERO
var _spell: Spell = null
var _player_stats: PlayerStats = null
var _is_phantom_legion: bool = false
var _is_phantom_blades: bool = false
var _is_haunt: bool = false

func needs_periodic_cast() -> bool:
	return false

func requires_aim() -> bool:
	return false

func cast(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_added(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_parent = caster
	_spell = spell
	_player_stats = player_stats
	_is_phantom_legion = spell.active_modification and spell.active_modification.mod_id == &"spirit_phantom"
	_is_phantom_blades = spell.active_modification and spell.active_modification.mod_id == &"spirit_blades"
	_is_haunt = spell.active_modification and spell.active_modification.mod_id == &"spirit_haunt"
	_create_orbs(spell, player_stats)

func on_spell_upgraded(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_spell = spell
	_player_stats = player_stats
	_is_phantom_legion = spell.active_modification and spell.active_modification.mod_id == &"spirit_phantom"
	_is_phantom_blades = spell.active_modification and spell.active_modification.mod_id == &"spirit_blades"
	_is_haunt = spell.active_modification and spell.active_modification.mod_id == &"spirit_haunt"
	var target_count := _get_effective_orb_count(spell)
	if target_count != _orbs.size():
		_clear_orbs()
		_create_orbs(spell, player_stats)
	else:
		var primary := _get_primary_color(spell)
		var secondary := _get_secondary_color(spell)
		for orb in _orbs:
			orb._color_primary = primary
			orb._color_secondary = secondary
		_rearrange_orbs()

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	_clear_orbs()
	for bolt in _active_bolts:
		if is_instance_valid(bolt):
			bolt.queue_free()
	for bolt in _inactive_bolts:
		if is_instance_valid(bolt):
			bolt.queue_free()
	_active_bolts.clear()
	_inactive_bolts.clear()

func tick(delta: float) -> void:
	if _chain_active:
		_chain_timer -= delta
		if _chain_timer <= 0.0 and _chain_index < _orbs.size():
			var orb := _orbs[_chain_index]
			var target_pos := _chain_target_pos
			if _is_phantom_legion:
				var own_target := _find_enemy_pos(orb.global_position, detect_range * 2.0)
				if own_target != Vector2.ZERO:
					target_pos = own_target
			if _is_phantom_blades:
				var dmg := _get_bolt_damage()
				RunTracker.set_current_spell(_spell.spell_id)
				SwarmManager.damage_area(target_pos, 25.0, dmg)
				EnemyMeshManager.damage_area(target_pos, 25.0, dmg)
				RunTracker.record_damage(dmg)
				JuiceManager.spawn_attack_flash(target_pos, _get_primary_color(_spell))
				orb.fire(target_pos)
			elif _is_haunt:
				orb.start_haunt(target_pos, _get_bolt_damage())
			else:
				var bolt := _acquire_bolt()
				var dir := orb.global_position.direction_to(target_pos)
				var dmg := _get_bolt_damage()
				var spd := bolt_speed
				if _spell and _spell.active_modification:
					spd *= _spell.active_modification.speed_multiplier
				var is_piercing := _spell and _spell.active_modification and _spell.active_modification.mod_id == &"spectral_pierce"
				bolt.launch(orb.global_position, dir, dmg, spd, _get_primary_color(_spell), _get_secondary_color(_spell), is_piercing, _spell.get_area_multiplier() if _spell else 1.0)
				orb.fire(target_pos)
			_chain_index += 1
			_chain_timer = _get_effective_chain_delay(_spell)
			if _chain_index >= _orbs.size():
				_chain_active = false
				_chain_cooldown_timer = _get_effective_cooldown(_spell)
	else:
		if _chain_cooldown_timer > 0.0:
			_chain_cooldown_timer -= delta
		else:
			_check_for_enemy()
	_update_haunting_orbs(delta)

func get_cooldown_progress() -> float:
	if _chain_active:
		return 0.0
	if _chain_cooldown_timer <= 0.0:
		return 0.0
	var cd_dur := _get_effective_cooldown(_spell)
	if cd_dur <= 0.0:
		return 0.0
	return clampf(_chain_cooldown_timer / cd_dur, 0.0, 1.0)

func _check_for_enemy() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var detect: float = detect_range
	if _spell and _spell.active_modification and _spell.active_modification.mod_id == &"spirit_haunt":
		detect *= 3.0
	var target_pos := _find_enemy_pos(player.global_position, detect)
	if target_pos != Vector2.ZERO:
		_chain_active = true
		_chain_index = 0
		_chain_timer = 0.0
		_chain_target_pos = target_pos

func _find_enemy_pos(pos: Vector2, max_range: float) -> Vector2:
	var best_pos: Vector2 = Vector2.ZERO
	var min_dist: float = max_range
	var swarm_pos: Vector2 = SwarmManager.find_closest_pos(pos, max_range)
	if swarm_pos != Vector2.ZERO:
		var d: float = pos.distance_to(swarm_pos)
		if d < min_dist:
			min_dist = d
			best_pos = swarm_pos
	var mesh_pos: Vector2 = EnemyMeshManager.find_closest_pos(pos, max_range)
	if mesh_pos != Vector2.ZERO:
		var d: float = pos.distance_to(mesh_pos)
		if d < min_dist:
			best_pos = mesh_pos
	return best_pos

func _create_orbs(spell: Spell, _player_stats: PlayerStats) -> void:
	var count := _get_effective_orb_count(spell)
	var primary := _get_primary_color(spell)
	var secondary := _get_secondary_color(spell)
	var is_haunt := spell.active_modification and spell.active_modification.mod_id == &"spirit_haunt"
	for i in range(count):
		var offset := _compute_offset(i, count)
		var orb := SpiritOrb.new()
		_caster_parent.add_child(orb)
		orb.setup(offset, primary, secondary, is_haunt)
		_orbs.append(orb)

func _compute_offset(index: int, total: int) -> Vector2:
	if total <= 1:
		return Vector2(0.0, -orbit_radius)
	var angle_step := TAU / total
	var angle := angle_step * index
	return Vector2(cos(angle) * orbit_radius, sin(angle) * orbit_radius)

func _rearrange_orbs() -> void:
	var total := _orbs.size()
	for i in range(total):
		var new_offset := _compute_offset(i, total)
		_orbs[i].update_offset(new_offset)

func _clear_orbs() -> void:
	for orb in _orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbs.clear()

func _acquire_bolt() -> SpiritBolt:
	if _inactive_bolts.size() > 0:
		var b: SpiritBolt = _inactive_bolts.pop_back()
		_active_bolts.append(b)
		return b
	var b := SpiritBolt.new()
	b._on_deactivate_callback = _return_bolt_to_pool
	var tree_node: Node = _caster_parent if _caster_parent else GameManager.get_player()
	if tree_node:
		tree_node.get_parent().add_child(b)
	_active_bolts.append(b)
	return b

func _return_bolt_to_pool(bolt: SpiritBolt) -> void:
	_active_bolts.erase(bolt)
	_inactive_bolts.append(bolt)

func _get_bolt_damage() -> float:
	if not _spell:
		return 10.0
	var dmg_mult := 1.0
	if _player_stats:
		dmg_mult = _player_stats.magic_power
	var _d := _spell.get_damage(dmg_mult) * _spell.roll_crit_mult(_player_stats)
	if _spell.was_last_crit(): EventBus.crit_landed.emit(_d, GameManager.get_player().global_position if GameManager.get_player() else Vector2.ZERO)
	return _d

func _get_effective_orb_count(spell: Spell) -> int:
	var count: int = base_orb_count
	for i in range(mini(spell.current_level - 1, spell.level_data.size())):
		count += spell.level_data[i].projectile_count_add
	if spell.active_modification:
		count += spell.active_modification.projectile_count_add
	return count

func _get_effective_chain_delay(spell: Spell) -> float:
	var delay := chain_delay
	if spell.active_modification and spell.active_modification.mod_id == &"spirit_haunt":
		delay *= 0.25
	return delay

func _get_effective_cooldown(spell: Spell) -> float:
	var cd := chain_cooldown
	var cd_mult := 1.0
	if spell.current_level >= 3:
		cd_mult *= 0.85
	if spell.current_level >= 4:
		cd_mult *= 0.82
	if spell.current_level >= 5:
		cd_mult *= 0.86
	cd *= cd_mult
	return cd

func _get_primary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_primary != Color.WHITE:
		return spell.vfx_color_primary
	if spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r, tint.g, tint.b, 0.95)
	return Color(0.85, 0.75, 1.0)

func _get_secondary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_secondary != Color.GRAY:
		return spell.vfx_color_secondary
	if spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r * 0.5, tint.g * 0.6, tint.b, 0.9)
	return Color(0.5, 0.35, 0.8)

func _update_haunting_orbs(_delta: float) -> void:
	pass
