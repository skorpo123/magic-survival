class_name OrbitProjectile extends Node2D

static var _arcana_tex: Texture2D = null
static var _shared_mat: CanvasItemMaterial = null
static var _glow_texture: ImageTexture = null

var spell: Spell
var _is_active: bool = false
var _orbit_angle: float = 0.0
var _orbit_radius: float = 120.0
var _orbit_speed: float = 2.5
var _player_ref: Node2D = null
var _attacking: bool = false
var _attack_target: Node2D = null
var _attack_pos: Vector2 = Vector2.ZERO
var _attacking_pos: bool = false
var _attack_speed: float = 800.0
var _return_speed: float = 500.0
var _cooldown: float = 0.0
var _pulse_phase: float = 0.0
var _accel: float = 0.0
var _sprite: Sprite2D = null
var _glow_sprite: Sprite2D = null
var _reverse: bool = false
var _is_blade_strike: bool = false
var _pulse_orbit: bool = false
var _base_orbit_radius: float = 120.0
var _detect_range: float = 600.0
var _base_attack_cooldown: float = 0.4
var _dmg_mult: float = 1.0
var _spell_id: StringName = &""
var _trail_positions: PackedVector2Array = PackedVector2Array()
var _trail_line_positions: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	z_index = 3
	_sprite = get_node_or_null("Sprite2D")
	if not _arcana_tex:
		_arcana_tex = load("res://Sprites/orbiting_arcana.png")
	_ensure_glow_texture()
	set_physics_process(false)

static func _ensure_glow_texture() -> void:
	if _glow_texture:
		return
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for px in range(size):
		for py in range(size):
			var dx := (px - c) / c
			var dy := (py - c) / c
			var dist := sqrt(dx * dx + dy * dy)
			if dist > 1.0:
				img.set_pixel(px, py, Color(0, 0, 0, 0))
			else:
				var fade := 1.0 - dist
				var r: float = lerp(0.3, 0.95, fade)
				var g: float = lerp(0.6, 1.0, fade)
				var b := 1.0
				var a := fade * fade * 0.65
				img.set_pixel(px, py, Color(r, g, b, a))
	_glow_texture = ImageTexture.create_from_image(img)

func _get_shared_mat() -> CanvasItemMaterial:
	if not _shared_mat:
		_shared_mat = CanvasItemMaterial.new()
		_shared_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_mat

func on_spawn() -> void:
	_is_active = true
	_attacking = false
	_attack_target = null
	_attacking_pos = false
	_attack_pos = Vector2.ZERO
	_cooldown = 0.0
	_accel = 0.0
	_pulse_phase = randf() * TAU
	_reverse = false
	_pulse_orbit = false
	_base_orbit_radius = 120.0
	_detect_range = 600.0
	_base_attack_cooldown = 0.4
	_attack_speed = 800.0
	_return_speed = 500.0
	_trail_positions.clear()
	_trail_line_positions.clear()
	modulate = Color(1, 1, 1, 1)
	z_index = 3
	visible = true
	_sprite = get_node_or_null("Sprite2D")
	var mat := _get_shared_mat()
	if _sprite:
		_sprite.texture = _arcana_tex
		_sprite.scale = Vector2(0.062, 0.062)
		_sprite.modulate = Color(1, 1, 1, 1)
		_sprite.z_index = 2
		_sprite.material = mat
	if not _glow_sprite:
		_glow_sprite = Sprite2D.new()
		_glow_sprite.texture = _glow_texture
		_glow_sprite.centered = true
		_glow_sprite.scale = Vector2(0.8, 0.8)
		_glow_sprite.z_index = 1
		_glow_sprite.material = mat
		add_child(_glow_sprite)
	_glow_sprite.visible = true
	set_physics_process(true)

func on_despawn() -> void:
	_is_active = false
	_attacking = false
	_attack_target = null
	_attacking_pos = false
	_attack_pos = Vector2.ZERO
	spell = null
	_trail_positions.clear()
	_trail_line_positions.clear()
	set_physics_process(false)
	if _glow_sprite:
		_glow_sprite.visible = false

func setup(spell_data: Spell, orbit_angle: float, orbit_radius: float, orbit_speed: float = 2.5, reverse: bool = false, dmg_mult: float = 1.0, sid: StringName = &"") -> void:
	spell = spell_data
	_orbit_angle = orbit_angle
	_orbit_radius = orbit_radius
	_base_orbit_radius = orbit_radius
	_orbit_speed = orbit_speed
	_reverse = reverse
	_dmg_mult = dmg_mult
	_spell_id = sid
	if spell_data.active_modification:
		match spell_data.active_modification.mod_name:
			"Pulsating Vortex":
				_pulse_orbit = true
			"Blade Strike":
				_is_blade_strike = true
				_detect_range = 600.0
				_attack_speed = 1200.0
				_return_speed = 800.0
				_base_attack_cooldown = 3.0
	var area_mult := spell.get_area_multiplier()
	if area_mult > 1.01:
		var vis := sqrt(area_mult)
		if _sprite:
			_sprite.scale = Vector2(0.062, 0.062) * vis
		if _glow_sprite:
			_glow_sprite.scale = Vector2(0.8, 0.8) * vis

func _physics_process(delta: float) -> void:
	if not _is_active or not spell:
		return

	if not is_instance_valid(_player_ref):
		_player_ref = GameManager.get_player()
		if not _player_ref:
			return

	_cooldown -= delta

	_trail_positions.append(global_position)
	if _trail_positions.size() > 12:
		_trail_positions.remove_at(0)

	_trail_line_positions.append(global_position)
	if _trail_line_positions.size() > 20:
		_trail_line_positions.remove_at(0)

	_pulse_phase += delta * 6.0
	if _glow_sprite:
		var pulse := 1.0 + 0.15 * sin(_pulse_phase)
		_glow_sprite.scale = Vector2(0.8, 0.8) * pulse

	if _attacking:
		var target_pos: Vector2
		if _attacking_pos:
			target_pos = _attack_pos
		elif is_instance_valid(_attack_target):
			target_pos = _attack_target.global_position
		else:
			_attacking = false
			_attack_target = null
			_attacking_pos = false
			_accel = 0.0
			return

		var to_target := target_pos - global_position
		var dist := to_target.length()
		if dist < 18.0:
			var player := GameManager.get_player()
			var mp := 1.0
			var crit_mult := 1.0
			if player and "stats" in player and player.stats is PlayerStats:
				mp = player.stats.magic_power
				crit_mult = spell.roll_crit_mult(player.stats)
			var base_dmg := spell.get_damage(mp) * crit_mult
			if spell.was_last_crit():
				EventBus.crit_landed.emit(base_dmg, global_position)
			var blade_mult := 2.0 if _is_blade_strike else _dmg_mult
			var dmg := base_dmg * blade_mult
			RunTracker.set_current_spell(spell.spell_id)
			SwarmManager.damage_area(global_position, 22.0, dmg)
			EnemyMeshManager.damage_area(global_position, 26.0, dmg)
			RunTracker.record_damage(dmg)
			JuiceManager.spawn_attack_flash(global_position, spell.color)
			_attacking = false
			_attack_target = null
			_attacking_pos = false
			_attack_pos = Vector2.ZERO
			_cooldown = _base_attack_cooldown
			_accel = 0.0
			return

		_accel = minf(_accel + delta * 3000.0, 1200.0)
		var dir := to_target.normalized()
		global_position += dir * (_attack_speed + _accel) * delta
		rotation = dir.angle()
	else:
		if _reverse:
			_orbit_angle -= _orbit_speed * delta
		else:
			_orbit_angle += _orbit_speed * delta
		if _pulse_orbit:
			_pulse_phase += delta * PI
			_orbit_radius = _base_orbit_radius * (1.2 + 0.6 * sin(_pulse_phase))
		var target_pos := _player_ref.global_position + Vector2.RIGHT.rotated(_orbit_angle) * _orbit_radius
		var to_target := target_pos - global_position
		var dist_to_target := to_target.length()
		if dist_to_target > 2.0:
			var move_dist := minf(_return_speed * delta, dist_to_target)
			global_position += to_target.normalized() * move_dist
		rotation = _orbit_angle + PI * 0.5

		if not _is_blade_strike and _cooldown <= 0.0:
			var contact_range := 30.0
			var s_pos := SwarmManager.find_closest_pos(global_position, contact_range)
			if s_pos == Vector2.ZERO:
				s_pos = EnemyMeshManager.find_closest_pos(global_position, contact_range)
			if s_pos != Vector2.ZERO:
				var player := GameManager.get_player()
				var mp := 1.0
				if player and "stats" in player and player.stats is PlayerStats:
					mp = player.stats.magic_power
				var dmg := spell.get_damage(mp) * _dmg_mult
				RunTracker.set_current_spell(spell.spell_id)
				SwarmManager.damage_area(global_position, 22.0, dmg)
				EnemyMeshManager.damage_area(global_position, 26.0, dmg)
				RunTracker.record_damage(dmg)
				JuiceManager.spawn_attack_flash(global_position, spell.color)
				_cooldown = _base_attack_cooldown

		if _is_blade_strike and _cooldown <= 0.0:
			var s_pos := SwarmManager.find_closest_pos(global_position, _detect_range)
			if s_pos != Vector2.ZERO:
				_attacking = true
				_attacking_pos = true
				_attack_pos = s_pos
				_attack_target = null
				_accel = 0.0
			else:
				var m_pos := EnemyMeshManager.find_closest_pos(global_position, _detect_range)
				if m_pos != Vector2.ZERO:
					_attacking = true
					_attacking_pos = true
					_attack_pos = m_pos
					_attack_target = null
					_accel = 0.0

func _draw() -> void:
	if _trail_line_positions.size() >= 2:
		var points := PackedVector2Array()
		for i in range(_trail_line_positions.size()):
			points.append(_trail_line_positions[i] - global_position)
		var col_outer := Color(0.3, 0.6, 1.0, 0.25)
		var col_inner := Color(0.7, 0.9, 1.0, 0.4)
		draw_polyline(points, col_outer, 4.0, true)
		draw_polyline(points, col_inner, 1.5, true)

	if _trail_positions.size() >= 2:
		for i in range(_trail_positions.size()):
			var t := float(i) / float(_trail_positions.size())
			var pos := _trail_positions[i] - global_position
			var alpha := t * 0.5
			var r := 5.0 * t
			draw_circle(pos, r, Color(0.4, 0.75, 1.0, alpha))
			draw_circle(pos, r * 0.4, Color(0.85, 0.95, 1.0, alpha * 1.5))
