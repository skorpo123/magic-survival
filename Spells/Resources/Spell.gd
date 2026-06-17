class_name Spell extends Resource

enum CastPattern { SINGLE, SPREAD, CIRCLE, ORBIT, AOE }

@export var spell_name: String = "New Spell"
@export var spell_id: StringName = &"new_spell"
@export var icon: Texture2D
@export var max_level: int = 5
@export var cast_pattern: CastPattern = CastPattern.SINGLE

@export_group("Base Stats")
@export var base_damage: float = 10.0
@export var base_cooldown: float = 1.0
@export var projectile_speed: float = 300.0
@export var pierce: int = 1
@export var projectile_count: int = 1
@export var explosion_radius: float = 0.0
@export var spread_angle: float = 0.3

@export_group("Behavior")
@export var behavior: BaseSpellBehavior

@export_group("Visual")
@export var color: Color = Color.WHITE

@export_group("Levels")
@export var level_data: Array[SpellLevelData] = []

@export_group("Level 5 Modifications")
@export var modifications: Array[SpellModification] = []

@export_group("Pool")
@export var projectile_scene: PackedScene
@export var pool_name: StringName = &"MagicBolt"
@export var pool_initial_size: int = 50

var current_level: int = 1
var active_modification: SpellModification = null
var _last_crit_rolled: bool = false

func get_damage(player_magic_power: float = 1.0) -> float:
	var dmg: float = base_damage * player_magic_power
	if current_level > 1 and level_data.size() >= current_level - 1:
		dmg *= level_data[current_level - 2].damage_multiplier
	if active_modification:
		dmg *= active_modification.damage_multiplier
	var t := _get_spell_type_static()
	dmg *= ArtifactManager.get_spell_multiplier(spell_id, t, ArtifactEffect.EffectType.DAMAGE_MULT)
	var mmult := ArtifactManager.get_missing_hp_damage_mult()
	if mmult > 1.0:
		var player := GameManager.get_player()
		if player and "stats" in player and player.stats:
			var stats: PlayerStats = player.stats
			var missing_pct := 1.0 - (stats.current_hp / stats.max_hp)
			dmg *= 1.0 + (mmult - 1.0) * missing_pct
	return dmg

func get_cooldown(cooldown_reduction: float = 0.0) -> float:
	var cd: float = base_cooldown
	if current_level > 1 and level_data.size() >= current_level - 1:
		cd *= level_data[current_level - 2].cooldown_multiplier
	if active_modification:
		cd *= active_modification.cooldown_multiplier
	cd *= (1.0 - clampf(cooldown_reduction, 0.0, 0.75))
	return maxf(cd, 0.05)

func get_speed(speed_mult: float = 1.0) -> float:
	var spd: float = projectile_speed * speed_mult
	if current_level > 1 and level_data.size() >= current_level - 1:
		spd *= level_data[current_level - 2].speed_multiplier
	if active_modification:
		spd *= active_modification.speed_multiplier
	var t := _get_spell_type_static()
	spd *= ArtifactManager.get_spell_multiplier(spell_id, t, ArtifactEffect.EffectType.PROJECTILE_SPEED)
	var player := GameManager.get_player()
	if player and "stats" in player and player.stats:
		spd *= player.stats.projectile_speed_mult
	return spd

func get_pierce() -> int:
	var p: int = pierce
	if current_level > 1 and level_data.size() >= current_level - 1:
		p += level_data[current_level - 2].pierce_add
	if active_modification:
		p += active_modification.pierce_add
	var t := _get_spell_type_static()
	p += ArtifactManager.get_pierce_add(spell_id, t)
	return p

func get_projectile_count() -> int:
	var count: int = projectile_count
	if current_level > 1 and level_data.size() >= current_level - 1:
		count += level_data[current_level - 2].projectile_count_add
	if active_modification:
		count += active_modification.projectile_count_add
	var t := _get_spell_type_static()
	count += ArtifactManager.get_extra_projectile_count(spell_id, t)
	return count

func get_area_multiplier() -> float:
	var area: float = 1.0
	if current_level > 1 and level_data.size() >= current_level - 1:
		area *= level_data[current_level - 2].area_multiplier
	if active_modification:
		match active_modification.mod_type:
			SpellModification.ModType.EXPLODE:
				area *= active_modification.explosion_radius_mult
	var t := _get_spell_type_static()
	area *= ArtifactManager.get_spell_multiplier(spell_id, t, ArtifactEffect.EffectType.AREA_MULT)
	var player := GameManager.get_player()
	if player and "stats" in player and player.stats:
		area *= player.stats.area_multiplier
	return area

func get_duration_multiplier() -> float:
	var dur: float = 1.0
	var t := _get_spell_type_static()
	dur *= ArtifactManager.get_spell_multiplier(spell_id, t, ArtifactEffect.EffectType.DURATION_MULT)
	var player := GameManager.get_player()
	if player and "stats" in player and player.stats:
		dur *= player.stats.spell_duration_mult
	return dur

func get_chain_count(base_count: int = 0) -> int:
	var count: int = base_count
	if current_level > 1 and level_data.size() >= current_level - 1:
		count += level_data[current_level - 2].chain_count_add
	if active_modification:
		count += active_modification.chain_count_add
	var t := _get_spell_type_static()
	count += ArtifactManager.get_chain_count_add(spell_id, t)
	return count

func roll_crit_mult(stats: PlayerStats) -> float:
	_last_crit_rolled = false
	if not stats or stats.crit_chance <= 0.0:
		return 1.0
	if randf() < stats.crit_chance:
		_last_crit_rolled = true
		return stats.crit_damage_mult if stats.crit_damage_mult > 1.0 else stats.crit_damage_mult_bonus + 1.0
	return 1.0

func was_last_crit() -> bool:
	return _last_crit_rolled

func _get_spell_type_static() -> StringName:
	match spell_id:
		&"magic_bolt": return &"arcane"
		&"fireball": return &"fire"
		&"fire_breath": return &"fire"
		&"lightning_strike": return &"lightning"
		&"electric_zone": return &"lightning"
		&"cyclone": return &"arcane"
		&"arcane_ray": return &"arcane"
		&"orbiting_arcana": return &"arcane"
		&"spirit": return &"arcane"
		&"shield": return &"arcane"
		&"needle": return &"cold"
		&"poison_pool": return &"cold"
		&"frost_nova": return &"cold"
		_: return &""

func level_up() -> bool:
	if current_level >= max_level:
		return false
	current_level += 1
	return true

func apply_modification(mod: SpellModification) -> void:
	active_modification = mod
	_notify_death_processor(mod)

func _notify_death_processor(mod: SpellModification) -> void:
	match mod.mod_type:
		SpellModification.ModType.ON_KILL_EXPLODE:
			DeathProcessor.set_iron_maiden(mod.on_kill_explode_chance, mod.on_kill_explode_radius, mod.on_kill_explode_damage)
		SpellModification.ModType.INSTANT_KILL:
			DeathProcessor.set_reaper_scythe(mod.instant_kill_chance)

func is_max_level() -> bool:
	return current_level >= max_level

func get_level_description() -> String:
	if current_level > 1 and level_data.size() >= current_level - 1:
		return level_data[current_level - 2].description
	return ""
