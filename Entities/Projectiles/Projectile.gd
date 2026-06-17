class_name Projectile extends Node2D

@export_group("Sprite Sheet")
@export var anim_fps: float = 20.0

@export_group("Visual")
@export var sprite_scale: float = 0.0275

static var _shared_material: CanvasItemMaterial = null
static var _shared_frames: SpriteFrames = null
static var _glow_texture: ImageTexture = null

var direction: Vector2 = Vector2.ZERO
var spell: Spell
var current_pierce: int = 1
var _fade_tween: Tween = null
var _is_active: bool = false
var _pulse_phase: float = 0.0
var _is_split_child: bool = false
var _spawned: bool = false
var _homing_age: float = 0.0
var _hit_check_cd: float = 0.0
var _prev_position: Vector2 = Vector2.ZERO
var _trail_positions: PackedVector2Array = PackedVector2Array()

var _anim: AnimatedSprite2D = null
var _glow_sprite: Sprite2D = null

func _ready() -> void:
	var notifier := get_node_or_null("VisibleOnScreenNotifier2D")
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)
	z_index = 2
	_build_visual()
	set_physics_process(false)

func _get_shared_material() -> CanvasItemMaterial:
	if not _shared_material:
		_shared_material = CanvasItemMaterial.new()
		_shared_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_shared_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _shared_material

func _get_shared_frames() -> SpriteFrames:
	if not _shared_frames:
		_shared_frames = SpriteFrames.new()
		_shared_frames.add_animation("fly")
		_shared_frames.set_animation_speed("fly", anim_fps)
		_shared_frames.set_animation_loop("fly", true)
		for i in range(8):
			var num: String = ("0" + str(i)) if i < 10 else str(i)
			var tex := load("res://Sprites/" + num + "_magic_bolt_fly.png") as Texture2D
			if tex:
				_shared_frames.add_frame("fly", tex)
	return _shared_frames

func _get_glow_texture() -> ImageTexture:
	if not _glow_texture:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := size / 2.0
		for px in range(size):
			for py in range(size):
				var dx := (px - center) / center
				var dy := (py - center) / center
				var dist := sqrt(dx * dx + dy * dy)
				if dist > 1.0:
					img.set_pixel(px, py, Color(0, 0, 0, 0))
				else:
					var fade := 1.0 - dist
					var r: float = lerp(0.3, 0.9, fade)
					var g: float = lerp(0.5, 1.0, fade)
					var b := 1.0
					var a := fade * fade * 0.6
					img.set_pixel(px, py, Color(r, g, b, a))
		_glow_texture = ImageTexture.create_from_image(img)
	return _glow_texture

func _build_visual() -> void:
	_anim = AnimatedSprite2D.new()
	_anim.material = _get_shared_material()
	_anim.centered = true
	_anim.scale = Vector2(sprite_scale, sprite_scale)
	_anim.z_index = 1
	_anim.sprite_frames = _get_shared_frames()
	add_child(_anim)

	_glow_sprite = Sprite2D.new()
	_glow_sprite.texture = _get_glow_texture()
	_glow_sprite.material = _get_shared_material()
	_glow_sprite.centered = true
	_glow_sprite.scale = Vector2(1.8, 1.8)
	_glow_sprite.z_index = 0
	_glow_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	add_child(_glow_sprite)

func on_spawn() -> void:
	_is_active = true
	_is_split_child = false
	_spawned = true
	_hit_check_cd = 0.0
	_prev_position = Vector2.ZERO
	_trail_positions.clear()
	modulate = Color(2.0, 2.0, 2.0, 1)
	_pulse_phase = randf() * TAU
	visible = true
	if _anim:
		_anim.play("fly")
	if _glow_sprite:
		_glow_sprite.visible = true
	set_physics_process(true)

func on_despawn() -> void:
	_is_active = false
	_is_split_child = false
	_spawned = false
	_trail_positions.clear()
	direction = Vector2.ZERO
	spell = null
	current_pierce = 0
	modulate = Color(1, 1, 1, 1)
	if _anim:
		_anim.stop()
	if _glow_sprite:
		_glow_sprite.visible = false
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	set_physics_process(false)

func setup(dir: Vector2, spell_data: Spell, _player_stats: PlayerStats = null) -> void:
	direction = dir.normalized()
	spell = spell_data
	current_pierce = spell.get_pierce()
	_homing_age = 0.0
	rotation = direction.angle()
	var area_mult := spell.get_area_multiplier()
	if area_mult > 1.01:
		var vis := sqrt(area_mult)
		if _anim:
			_anim.scale = Vector2(sprite_scale, sprite_scale) * vis
		if _glow_sprite:
			_glow_sprite.scale = Vector2(1.8, 1.8) * vis

func _physics_process(delta: float) -> void:
	if not spell or not _is_active:
		return
	_prev_position = global_position
	var speed := spell.get_speed()
	position += direction * speed * delta
	_pulse_phase += delta * 8.0

	if _glow_sprite:
		var pulse := 1.0 + 0.12 * sin(_pulse_phase)
		_glow_sprite.scale = Vector2(1.0, 1.0) * pulse

	if spell.active_modification and spell.active_modification.mod_type == SpellModification.ModType.HOMING:
		_apply_homing(delta)
		_trail_positions.append(global_position)
		if _trail_positions.size() > 8:
			_trail_positions.remove_at(0)
		queue_redraw()

	_check_line_hit()

func _check_line_hit() -> void:
	if not spell or not _is_active:
		return
	var dmg_mult := 1.0
	var player := GameManager.get_player()
	if player and "stats" in player and player.stats is PlayerStats:
		dmg_mult = player.stats.magic_power
	var dmg := spell.get_damage(dmg_mult) * ComboTracker.get_damage_multiplier()
	var crit_chance: float = 0.0
	if player and player.stats:
		crit_chance = player.stats.crit_chance
	if randf() < clampf(crit_chance, 0.0, 1.0):
		var crit_mult: float = 2.0
		if player and player.stats:
			crit_mult = player.stats.crit_damage_mult
		dmg *= crit_mult
		JuiceManager.spawn_bolt_hit(global_position, Color(2.0, 2.0, 0.4, 1.0))
	RunTracker.set_current_spell(spell.spell_id)
	var result := SwarmManager.damage_line(_prev_position, global_position, 18.0, dmg)
	var killed: int = result[0]
	var hit: int = result[1]
	var result2 := EnemyMeshManager.damage_line(_prev_position, global_position, 20.0, dmg)
	killed += result2[0]
	hit += result2[1]
	if hit > 0:
		RunTracker.record_damage(dmg * killed)
		current_pierce -= hit
		SoundManager.play_sound("hit_enemy")
		if spell.active_modification and spell.active_modification.mod_type == SpellModification.ModType.CHAIN:
			_chain_to_next(self)
		if current_pierce <= 0:
			JuiceManager.spawn_bolt_hit(global_position, spell.color)
			if spell.active_modification and spell.active_modification.mod_type == SpellModification.ModType.EXPLODE:
				_do_explode()
			_deferred_despawn()

func _apply_homing(delta: float) -> void:
	_homing_age += delta
	var search_range: float = 550.0
	if _homing_age < 0.1:
		search_range = 300.0
	var closest_pos := _find_closest_enemy_pos_cone(search_range)
	if closest_pos == Vector2.ZERO:
		if _homing_age >= 0.1:
			closest_pos = _find_closest_enemy_pos(550.0)
		if closest_pos == Vector2.ZERO:
			return
	var desired := (closest_pos - global_position).normalized()
	direction = direction.move_toward(desired, spell.active_modification.homing_strength * delta)
	rotation = direction.angle()

func _find_closest_enemy_pos_cone(search_range: float) -> Vector2:
	var forward := direction
	var cone_cos: float = cos(PI * 0.5)
	var best_pos: Vector2 = Vector2.ZERO
	var best_d_sq: float = search_range * search_range
	var swarm_pos: Vector2 = SwarmManager.find_closest_pos(global_position, search_range)
	if swarm_pos != Vector2.ZERO:
		var to_enemy := swarm_pos - global_position
		var d_sq: float = to_enemy.length_squared()
		if d_sq < best_d_sq:
			var dot_val: float = forward.dot(to_enemy.normalized())
			if dot_val >= cone_cos:
				best_d_sq = d_sq
				best_pos = swarm_pos
	var mesh_pos: Vector2 = EnemyMeshManager.find_closest_pos(global_position, search_range)
	if mesh_pos != Vector2.ZERO:
		var to_enemy := mesh_pos - global_position
		var d_sq: float = to_enemy.length_squared()
		if d_sq < best_d_sq:
			var dot_val: float = forward.dot(to_enemy.normalized())
			if dot_val >= cone_cos:
				best_pos = mesh_pos
	return best_pos

func _find_closest_enemy_pos(search_range: float) -> Vector2:
	var best_pos: Vector2 = Vector2.ZERO
	var min_dist: float = search_range
	var swarm_pos: Vector2 = SwarmManager.find_closest_pos(global_position, search_range)
	if swarm_pos != Vector2.ZERO:
		min_dist = global_position.distance_to(swarm_pos)
		best_pos = swarm_pos
	var mesh_pos: Vector2 = EnemyMeshManager.find_closest_pos(global_position, search_range)
	if mesh_pos != Vector2.ZERO:
		var mesh_dist: float = global_position.distance_to(mesh_pos)
		if mesh_dist < min_dist:
			best_pos = mesh_pos
	return best_pos

func _spawn_bolt_hit() -> void:
	JuiceManager.spawn_bolt_hit(global_position, spell.color)

func _deferred_despawn() -> void:
	_is_active = false
	_spawned = false
	if _anim:
		_anim.stop()
	if _glow_sprite:
		_glow_sprite.visible = false
	var pool_name := spell.pool_name
	(func() -> void:
		PoolManager.despawn(pool_name, self)
	).call_deferred()

func _do_explode() -> void:
	if not spell or not spell.active_modification:
		return
	var player := GameManager.get_player()
	var dmg_mult := 1.0
	if player and "stats" in player and player.stats is PlayerStats:
		dmg_mult = player.stats.magic_power
	var explode_dmg := spell.get_damage(dmg_mult) * 0.5
	var explode_r := 40.0 * spell.get_area_multiplier()
	RunTracker.set_current_spell(spell.spell_id)
	SwarmManager.damage_area(global_position, explode_r, explode_dmg)
	EnemyMeshManager.damage_area(global_position, explode_r, explode_dmg)
	RunTracker.record_damage(explode_dmg * 3.0)
	BurstEffectPool.spawn("explosion", global_position, spell.color, clampf(explode_r / 40.0, 0.3, 5.0))

func _chain_to_next(source: Node2D) -> void:
	if not spell or not spell.active_modification:
		return
	var chain_range: float = spell.active_modification.chain_range
	var player := GameManager.get_player()
	var dmg_mult := 1.0
	if player and "stats" in player and player.stats is PlayerStats:
		dmg_mult = player.stats.magic_power
	var chain_dmg := spell.get_damage(dmg_mult) * spell.active_modification.chain_damage_mult
	var swarm_pos: Vector2 = SwarmManager.find_closest_pos(source.global_position, chain_range)
	var mesh_pos: Vector2 = EnemyMeshManager.find_closest_pos(source.global_position, chain_range)
	var best_pos: Vector2 = Vector2.ZERO
	if swarm_pos != Vector2.ZERO and mesh_pos != Vector2.ZERO:
		if source.global_position.distance_to(swarm_pos) < source.global_position.distance_to(mesh_pos):
			best_pos = swarm_pos
		else:
			best_pos = mesh_pos
	elif swarm_pos != Vector2.ZERO:
		best_pos = swarm_pos
	elif mesh_pos != Vector2.ZERO:
		best_pos = mesh_pos
	if best_pos != Vector2.ZERO:
		RunTracker.set_current_spell(spell.spell_id)
		SwarmManager.damage_area(best_pos, 30.0, chain_dmg)
		EnemyMeshManager.damage_area(best_pos, 30.0, chain_dmg)
		RunTracker.record_damage(chain_dmg)
		var parent := source.get_tree().current_scene
		if parent:
			var arc := LightningBolt.acquire()
			arc._bolt_color = Color(spell.color.r * 0.7, spell.color.g * 0.7, spell.color.b, 0.9)
			arc._glow_color = Color(spell.color.r * 0.3, spell.color.g * 0.3, spell.color.b, 0.2)
			arc._core_color = Color(1.0, 1.0, 1.0)
			arc._lifetime = 0.25
			arc._glow_width = 12.0
			arc._bolt_width = 5.0
			arc._core_width = 1.5
			arc.setup(source.global_position, best_pos, 6, 15.0)

func _split_on_hit(hit_pos: Vector2) -> void:
	if not spell or not spell.active_modification:
		return
	var split_count := spell.active_modification.split_count
	var spread := spell.active_modification.split_angle_spread
	var player := GameManager.get_player()
	var player_stats: PlayerStats = null
	if player and "stats" in player and player.stats is PlayerStats:
		player_stats = player.stats
	var base_angle := direction.angle()
	for i in range(split_count):
		var angle: float
		if split_count > 1:
			angle = base_angle - spread / 2.0 + spread * (float(i) / float(split_count - 1))
		else:
			angle = base_angle
		var dir := Vector2.RIGHT.rotated(angle)
		var proj := PoolManager.spawn(spell.pool_name, hit_pos)
		if proj:
			if proj.has_method("setup"):
				proj.setup(dir, spell, player_stats)
			if proj.has_method("on_spawn"):
				proj.on_spawn()
			if "_is_split_child" in proj:
				proj._is_split_child = true

func _on_screen_exited() -> void:
	if not _is_active:
		return
	_start_fade()

func _draw() -> void:
	if not spell or not _is_active:
		return
	if not spell.active_modification or spell.active_modification.mod_type != SpellModification.ModType.HOMING:
		return
	for i in range(_trail_positions.size()):
		var t := float(i) / float(maxf(_trail_positions.size(), 1))
		var a := 0.15 * t
		var tp := _trail_positions[i] - global_position
		draw_circle(tp, 3.0 * (0.5 + 0.5 * t), Color(spell.color.r, spell.color.g, spell.color.b, a))

func _start_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	_fade_tween.tween_callback(func() -> void:
		if spell:
			PoolManager.despawn(spell.pool_name, self)
	)

func _get_spell_type(s: Spell) -> StringName:
	if not s:
		return &""
	var id: StringName = s.spell_id
	match id:
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
		_: return &""
