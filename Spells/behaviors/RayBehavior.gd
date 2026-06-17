class_name RayBehavior
extends BaseSpellBehavior

@export var half_width: float = 2.8
@export var grow_time: float = 0.2
@export var sustain_time: float = 0.5
@export var fade_time: float = 0.6
@export var damage_interval: float = 0.1
@export var aim_range: float = 800.0

var _active: Array[ArcaneRay] = []
var _inactive: Array[ArcaneRay] = []
var _caster_parent: Node2D = null
var _is_spinning_prism: bool = false
var _prism_rotation: float = 0.0
var _prism_rotation_speed: float = 1.5
var _prism_fan_angle: float = deg_to_rad(90.0)
var _prism_ray_count: int = 5

func needs_periodic_cast() -> bool:
	return true

func requires_aim() -> bool:
	return false

func cast(caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	if not _caster_parent:
		_caster_parent = caster

	var dmg_mult := 1.0
	if player_stats:
		dmg_mult = player_stats.magic_power

	_is_spinning_prism = spell.active_modification and spell.active_modification.mod_id == &"arcane_ray_prism"

	if _is_spinning_prism:
		_spawn_prism_rays(spell, dmg_mult, player_stats)
		return

	var ray_count := spell.get_projectile_count()
	for i in range(ray_count):
		var angle := randf() * TAU
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var ray := _acquire_ray()
		var params := _build_params(spell, dmg_mult, player_stats)
		ray.launch(dir, params)
		ray.finished.connect(_on_ray_finished.bind(ray), CONNECT_ONE_SHOT)
		_active.append(ray)

func _spawn_prism_rays(spell: Spell, dmg_mult: float, player_stats: PlayerStats) -> void:
	var params := _build_params(spell, dmg_mult, player_stats)
	var count := _prism_ray_count
	var half_fan := _prism_fan_angle / 2.0
	var step := _prism_fan_angle / maxf(count - 1, 1)
	for i in range(count):
		var angle_offset := -half_fan + step * i
		var dir := Vector2.RIGHT.rotated(_prism_rotation + angle_offset)
		var ray := _acquire_ray()
		ray.launch(dir, params)
		ray.finished.connect(_on_ray_finished.bind(ray), CONNECT_ONE_SHOT)
		_active.append(ray)

func on_spell_added(caster: Node2D, spell: Spell, _player_stats: PlayerStats) -> void:
	_caster_parent = caster
	_is_spinning_prism = spell.active_modification and spell.active_modification.mod_id == &"arcane_ray_prism"
	if _is_spinning_prism:
		_prism_rotation = randf() * TAU

func on_spell_upgraded(_caster: Node2D, spell: Spell, player_stats: PlayerStats) -> void:
	var was_prism := _is_spinning_prism
	_is_spinning_prism = spell.active_modification and spell.active_modification.mod_id == &"arcane_ray_prism"
	if not _is_spinning_prism and was_prism:
		for ray in _active:
			if is_instance_valid(ray):
				for conn in ray.finished.get_connections():
					ray.finished.disconnect(conn["callable"])
				ray.visible = false
				ray.process_mode = Node.PROCESS_MODE_DISABLED
		_inactive.append_array(_active)
		_active.clear()
	var dmg_mult := 1.0
	if player_stats:
		dmg_mult = player_stats.magic_power
	var params := _build_params(spell, dmg_mult, player_stats)
	for ray in _active:
		if is_instance_valid(ray):
			ray.update_params(params)

func on_spell_removed(_caster: Node2D, _spell: Spell) -> void:
	for ray in _active:
		if is_instance_valid(ray):
			for conn in ray.finished.get_connections():
				ray.finished.disconnect(conn["callable"])
			ray.queue_free()
	for ray in _inactive:
		if is_instance_valid(ray):
			ray.queue_free()
	_active.clear()
	_inactive.clear()

func tick(delta: float) -> void:
	if _is_spinning_prism:
		_prism_rotation += _prism_rotation_speed * delta
		_update_prism_directions()

func _update_prism_directions() -> void:
	var count := _active.size()
	if count == 0:
		return
	var half_fan := _prism_fan_angle / 2.0
	var step := _prism_fan_angle / maxf(count - 1, 1)
	for i in range(count):
		var angle_offset := -half_fan + step * i
		var dir := Vector2.RIGHT.rotated(_prism_rotation + angle_offset)
		if is_instance_valid(_active[i]):
			_active[i].update_direction(dir)

func _acquire_ray() -> ArcaneRay:
	if _inactive.size() > 0:
		var r: ArcaneRay = _inactive.pop_back()
		return r
	var r := ArcaneRay.new()
	var tree_node: Node = _caster_parent if _caster_parent else GameManager.get_player()
	if tree_node:
		tree_node.get_parent().add_child(r)
	return r

func _on_ray_finished(ray: ArcaneRay) -> void:
	var idx := _active.find(ray)
	if idx >= 0:
		_active.remove_at(idx)
	_inactive.append(ray)

func _build_params(spell: Spell, dmg_mult: float, player_stats: PlayerStats) -> Dictionary:
	var eff_width: float = half_width * spell.get_area_multiplier()
	var eff_damage: float = spell.get_damage(dmg_mult) * spell.roll_crit_mult(player_stats)
	if spell.was_last_crit(): EventBus.crit_landed.emit(eff_damage, GameManager.get_player().global_position)
	var primary := _get_primary_color(spell)
	var secondary := _get_secondary_color(spell)
	var do_reflect := false
	var is_photon := false

	if spell.active_modification:
		eff_width *= spell.active_modification.zone_radius_mult
		if spell.active_modification.mod_type == SpellModification.ModType.AREA_BOOST:
			eff_width *= spell.active_modification.explosion_radius_mult
		if spell.active_modification.mod_id == &"arcane_ray_refraction":
			do_reflect = true
		if spell.active_modification.mod_id == &"arcane_ray_photon":
			is_photon = true
			eff_width *= 1.8

	return {
		&"damage": eff_damage,
		&"half_width": eff_width,
		&"damage_interval": damage_interval,
		&"grow_time": 0.05 if is_photon else grow_time * spell.get_duration_multiplier(),
		&"sustain_time": 0.15 if is_photon else sustain_time * spell.get_duration_multiplier(),
		&"fade_time": 0.3 if is_photon else fade_time * spell.get_duration_multiplier(),
		&"color_primary": primary,
		&"color_secondary": secondary,
		&"reflect": do_reflect,
		&"is_photon": is_photon,
	}

func _get_primary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_primary != Color.WHITE:
		return spell.vfx_color_primary
	if spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r, tint.g, tint.b, 0.95)
	return Color(1.0, 0.4, 0.25)

func _get_secondary_color(spell: Spell) -> Color:
	if spell is SpellData and spell.vfx_color_secondary != Color.GRAY:
		return spell.vfx_color_secondary
	if spell.active_modification and spell.active_modification.color_tint != Color.WHITE:
		var tint := spell.active_modification.color_tint
		return Color(tint.r * 0.5, tint.g * 0.6, tint.b, 0.9)
	return Color(0.8, 0.15, 0.08)
