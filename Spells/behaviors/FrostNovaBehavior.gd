class_name FrostNovaBehavior
extends BaseSpellBehavior

@export var nova_radius: float = 140.0
@export var freeze_duration: float = 2.0
@export var expansion_time: float = 0.35

var _caster_ref: Node2D = null
var _spell: Spell = null
var _player_stats: PlayerStats = null
var _cast_timer: float = 0.0
var _visual: FrostNovaVisual = null
var _has_shards: bool = false
var _has_permafrost: bool = false
var _has_crystallize: bool = false

func needs_periodic_cast() -> bool:
	return true

func requires_aim() -> bool:
	return false

func cast(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_added(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_spell = spell
	_player_stats = player_stats
	_cast_timer = 0.3
	_apply_mod_flags()

func on_spell_upgraded(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_spell = spell
	_player_stats = player_stats
	_apply_mod_flags()

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	if _visual and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null

func tick(delta: float) -> void:
	_cast_timer -= delta
	if _cast_timer <= 0.0:
		_do_nova()
		_cast_timer = _get_cooldown_time()

func get_cooldown_progress() -> float:
	var cd: float = _get_cooldown_time()
	if cd <= 0.0:
		return 0.0
	return clampf(1.0 - _cast_timer / cd, 0.0, 1.0)

func _do_nova() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var pos: Vector2 = player.global_position
	var dmg_mult := 1.0
	if _player_stats:
		dmg_mult = _player_stats.magic_power
	var dmg := _spell.get_damage(dmg_mult) * _spell.roll_crit_mult(_player_stats)
	if _spell.was_last_crit(): EventBus.crit_landed.emit(dmg, pos)
	var eff_radius := _get_effective_radius()
	var freeze_dur := _get_effective_freeze()

	RunTracker.set_current_spell(_spell.spell_id)
	var killed_swarm := SwarmManager.damage_area(pos, eff_radius, dmg)
	var killed_mesh := EnemyMeshManager.damage_area(pos, eff_radius, dmg)
	RunTracker.record_damage(dmg * (killed_swarm + killed_mesh))

	if freeze_dur > 0.0:
		SwarmManager.apply_slow(pos, eff_radius, freeze_dur)
		EnemyMeshManager.apply_slow(pos, eff_radius, freeze_dur)

	if _has_permafrost:
		var peri_dmg := dmg * 0.25
		SwarmManager.damage_area(pos, eff_radius, peri_dmg)
		EnemyMeshManager.damage_area(pos, eff_radius, peri_dmg)

	if _has_crystallize and (killed_swarm + killed_mesh) > 0:
		var expl_dmg := dmg * 0.5
		var expl_r := eff_radius * 0.5
		SwarmManager.damage_area(pos, expl_r, expl_dmg)
		EnemyMeshManager.damage_area(pos, expl_r, expl_dmg)
		BurstEffectPool.spawn("frost_nova", pos, Color(0.5, 0.8, 1.0))

	if _has_shards:
		_fire_shards(pos, dmg, eff_radius)

	_spawn_visual(pos, eff_radius)
	SoundManager.play_sound("hit_enemy")

func _fire_shards(pos: Vector2, dmg: float, radius: float) -> void:
	var count := 6
	var shard_dmg := dmg * 0.4
	for i in range(count):
		var angle := TAU / count * i
		var dir := Vector2(cos(angle), sin(angle))
		var hit := SwarmManager.damage_line(pos, pos + dir * radius, 10.0, shard_dmg)
		RunTracker.record_damage(shard_dmg * hit[0])
		var hit_m := EnemyMeshManager.damage_line(pos, pos + dir * radius, 10.0, shard_dmg)
		RunTracker.record_damage(shard_dmg * hit_m[0])

func _spawn_visual(pos: Vector2, radius: float) -> void:
	if _visual and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = FrostNovaVisual.new()
	_visual.setup(pos, radius, _get_freeze_color(), expansion_time)
	var tree := _caster_ref.get_tree() if _caster_ref else null
	if tree:
		tree.root.add_child(_visual)

func _apply_mod_flags() -> void:
	if not _spell or not _spell.active_modification:
		return
	var mod_id: StringName = _spell.active_modification.mod_id
	_has_shards = mod_id == &"frost_nova_shards"
	_has_permafrost = mod_id == &"frost_nova_permafrost"
	_has_crystallize = mod_id == &"frost_nova_crystallize"

func _get_effective_radius() -> float:
	var r := nova_radius
	if _spell:
		r *= _spell.get_area_multiplier()
	return r

func _get_effective_freeze() -> float:
	var f := freeze_duration
	if _spell and _spell.current_level >= 3:
		f += 0.3
	if _spell and _spell.current_level >= 5:
		f += 0.5
	return f

func _get_freeze_color() -> Color:
	if _spell is SpellData and _spell.vfx_color_primary != Color.WHITE:
		return _spell.vfx_color_primary
	if _spell and _spell.active_modification and _spell.active_modification.color_tint != Color.WHITE:
		return _spell.active_modification.color_tint
	return Color(0.6, 0.85, 1.0)

func _get_cooldown_time() -> float:
	if _spell:
		var cd_reduction: float = 0.0
		if _player_stats:
			cd_reduction = _player_stats.cooldown_reduction
		return _spell.get_cooldown(cd_reduction)
	return 5.0
