class_name ShieldBehavior
extends BaseSpellBehavior

@export var base_charges: int = 2
@export var base_recharge_time: float = 15.0

static var shield_active: bool = false
static var shield_radius: float = 70.0
static var _instance: ShieldBehavior = null

var _max_charges: int = 2
var _current_charges: int = 2
var _recharge_timer: float = 0.0
var _recharge_time: float = 15.0
var _aura: ShieldAura = null
var _caster_ref: Node2D = null
var _thorns_active: bool = false
var _thorns_damage: float = 15.0
var _thorns_range: float = 100.0

func needs_periodic_cast() -> bool:
	return false

func requires_aim() -> bool:
	return false

func cast(_caster: Node2D, _spell: Spell, _player_stats: PlayerStats) -> void:
	pass

func on_spell_added(caster: Node2D, spell: Spell, _player_stats: PlayerStats) -> void:
	_caster_ref = caster
	_max_charges = _get_effective_charges(spell)
	_current_charges = _max_charges
	_recharge_time = _get_effective_recharge_time(spell)
	_thorns_active = spell.active_modification and spell.active_modification.mod_id == &"shield_thorns"
	shield_active = true
	_instance = self
	_create_aura(caster, spell)

func on_spell_upgraded(_caster: Node2D, spell: Spell, _player_stats: PlayerStats) -> void:
	var new_max := _get_effective_charges(spell)
	_recharge_time = _get_effective_recharge_time(spell)
	_thorns_active = spell.active_modification and spell.active_modification.mod_id == &"shield_thorns"
	if new_max != _max_charges:
		_max_charges = new_max
		_current_charges = minf(_current_charges, _max_charges)
	if _aura and is_instance_valid(_aura):
		_aura.set_charges(_current_charges, _max_charges)
		_aura.set_thorns(_thorns_active)
		_aura.set_aegis(spell.active_modification and spell.active_modification.mod_id == &"shield_aegis")

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	shield_active = false
	_instance = null
	if _aura and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null

func intercept_damage() -> bool:
	if _current_charges <= 0:
		return false
	_current_charges -= 1
	_recharge_timer = 0.0
	if _aura and is_instance_valid(_aura):
		_aura.on_charge_used(GameManager.get_player().global_position if GameManager.get_player() else Vector2.ZERO)
		_aura.set_charges(_current_charges, _max_charges)
	_do_thorns_if_active()
	_do_refraction_if_active()
	return true

static func is_in_shield(pos: Vector2) -> bool:
	if not shield_active:
		return false
	var player := GameManager.get_player()
	if not player:
		return false
	var dx: float = pos.x - player.global_position.x
	var dy: float = pos.y - player.global_position.y
	return dx * dx + dy * dy < shield_radius * shield_radius

static func get_instance() -> ShieldBehavior:
	return _instance

func intercept_contact(_enemy_pos: Vector2) -> bool:
	if _current_charges <= 0:
		return false
	_current_charges -= 1
	_recharge_timer = 0.0
	if _aura and is_instance_valid(_aura):
		_aura.on_charge_used(GameManager.get_player().global_position if GameManager.get_player() else Vector2.ZERO)
		_aura.set_charges(_current_charges, _max_charges)
	_do_thorns_if_active()
	_do_refraction_if_active()
	return true

func tick(_delta: float) -> void:
	if _current_charges >= _max_charges:
		_recharge_timer = 0.0
	else:
		_recharge_timer += _delta
		if _recharge_timer >= _recharge_time:
			_recharge_timer = 0.0
			_current_charges = mini(_current_charges + 1, _max_charges)
			if _aura and is_instance_valid(_aura):
				_aura.on_charge_recovered()
				_aura.set_charges(_current_charges, _max_charges)

func get_cooldown_progress() -> float:
	if _current_charges >= _max_charges:
		return 0.0
	if _recharge_time <= 0.0:
		return 0.0
	return 1.0 - (_recharge_timer / _recharge_time)

func _create_aura(caster: Node2D, spell: Spell) -> void:
	_aura = ShieldAura.new()
	caster.add_child(_aura)
	_aura.setup(caster)
	_aura.set_charges(_current_charges, _max_charges)
	_aura.set_thorns(_thorns_active)
	_aura.set_aegis(spell.active_modification and spell.active_modification.mod_id == &"shield_aegis")
	_aura.set_colors(_get_primary_color(spell), _get_secondary_color(spell))

func _do_thorns_if_active() -> void:
	if not _thorns_active:
		return
	var player := GameManager.get_player()
	if not player:
		return
	var mp: float = 1.0
	if "stats" in player and player.stats is PlayerStats:
		mp = player.stats.magic_power
	var spell := _get_spell()
	if spell:
		mp *= spell.roll_crit_mult(player.stats)
	var dmg := _thorns_damage * mp
	if spell and spell.was_last_crit(): EventBus.crit_landed.emit(dmg, player.global_position)
	var eff_range := _thorns_range * (spell.get_area_multiplier() if spell else 1.0)
	if spell:
		RunTracker.set_current_spell(spell.spell_id)
	SwarmManager.damage_area(player.global_position, eff_range, dmg)
	EnemyMeshManager.damage_area(player.global_position, eff_range, dmg)
	RunTracker.record_damage(dmg)

func _do_refraction_if_active() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var spell := _get_spell()
	if not spell or not spell.active_modification:
		return
	if spell.active_modification.mod_id != &"shield_refraction":
		return
	var mp: float = 1.0
	if "stats" in player and player.stats is PlayerStats:
		mp = player.stats.magic_power
	var dmg := 10.0 * mp * spell.active_modification.damage_multiplier * spell.roll_crit_mult(player.stats)
	if spell.was_last_crit(): EventBus.crit_landed.emit(dmg, player.global_position)
	var parent := player.get_tree().current_scene
	if not parent:
		return
	for i in range(6):
		var angle := TAU * float(i) / 6.0
		var dir := Vector2.RIGHT.rotated(angle)
		var bolt: RefractionBolt = RefractionBolt.new()
		bolt.launch(player.global_position, dir, dmg, _get_primary_color(spell))
		parent.add_child(bolt)

func _get_spell() -> Spell:
	if not _caster_ref or not is_instance_valid(_caster_ref):
		return null
	if not _caster_ref is SpellCaster:
		return null
	return _caster_ref.spell

func _get_effective_charges(spell: Spell) -> int:
	var charges := base_charges
	if spell.current_level >= 2:
		charges += 1
	if spell.current_level >= 3:
		charges += 1
	if spell.current_level >= 4:
		charges += 1
	if spell.current_level >= 5:
		charges += 2
	if spell.active_modification:
		if spell.active_modification.mod_id == &"shield_thorns":
			charges += 0
		elif spell.active_modification.mod_id == &"shield_aegis":
			charges = 1
	return charges

func _get_effective_recharge_time(spell: Spell) -> float:
	var rt := base_recharge_time
	var cd_mult := 1.0
	if spell.current_level >= 2:
		cd_mult *= 0.85
	if spell.current_level >= 3:
		cd_mult *= 0.88
	if spell.current_level >= 4:
		cd_mult *= 0.8
	if spell.current_level >= 5:
		cd_mult *= 0.83
	rt *= cd_mult
	if spell.active_modification:
		if spell.active_modification.mod_id == &"shield_thorns":
			rt *= 1.2
		elif spell.active_modification.mod_id == &"shield_aegis":
			rt *= 0.4
	return rt

func _get_primary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_primary != Color.WHITE:
		return spell.vfx_color_primary
	if spell and spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r, tint.g, tint.b, 0.95)
	return Color(0.3, 0.7, 1.0)

func _get_secondary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_secondary != Color.GRAY:
		return spell.vfx_color_secondary
	if spell and spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r * 0.5, tint.g * 0.6, tint.b, 0.9)
	return Color(0.2, 0.4, 0.8)
