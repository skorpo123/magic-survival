class_name BaseEnemy extends CharacterBody2D

@export var enemy_data: EnemyData

var current_hp: float = 20.0
var target: Node2D = null
var _steering_force: Vector2 = Vector2.ZERO
var _is_active: bool = false
var _anim: AnimatedSprite2D = null
var _straight_dir: Vector2 = Vector2.ZERO
var _color_variant: Color = Color.WHITE
var _scale_variant: float = 1.0
var _death_tween: Tween = null
var _is_culled: bool = false
var _cull_check_timer: float = 0.0
var _hit_flash_timer: float = -1.0
var _is_elite: bool = false
var _enraged: bool = false
var _slow_timer: float = 0.0
var last_damage_type: StringName = &""
var _base_anim_scale: Vector2 = Vector2.ONE
const CULL_DISTANCE_SQ: float = 1440000.0

const ELITE_COLOR: Color = Color(1.0, 0.85, 0.2)

static var _shared_vignette_mat: ShaderMaterial = null
static var _small_frames: SpriteFrames = null
static var _medium_frames: SpriteFrames = null
static var _big_frames: SpriteFrames = null
static var _mine_frames: SpriteFrames = null
static var _overlord_frames: SpriteFrames = null

func _ready() -> void:
	_anim = get_node_or_null("AnimatedSprite2D")
	_ensure_data()
	current_hp = enemy_data.max_hp
	target = GameManager.get_player()

func _ensure_data() -> void:
	if not enemy_data:
		enemy_data = EnemyData.new()
		enemy_data.speed = 100.0
		enemy_data.seek_weight = 1.0
		enemy_data.separation_weight = 1.5
		enemy_data.separation_radius = 30.0
		enemy_data.avoid_player_radius = 25.0
		enemy_data.collision_radius = 16.0
		enemy_data.xp_value = 1.8
		enemy_data.pool_name = &"Enemy"

func on_spawn() -> void:
	_is_active = true
	set_physics_process(true)
	add_to_group("enemies")
	_ensure_data()
	current_hp = enemy_data.max_hp
	target = GameManager.get_player()
	_is_elite = enemy_data.enemy_name.begins_with("Elite")
	_enraged = false
	_assign_visual_variant()
	_setup_animation()
	if enemy_data.enemy_class == EnemyData.EnemyClass.SMALL_FAST:
		if is_instance_valid(target):
			_straight_dir = global_position.direction_to(target.global_position)
		else:
			_straight_dir = Vector2.RIGHT.rotated(randf() * TAU)
	_is_culled = false
	_cull_check_timer = 0.0
	_hit_flash_timer = -1.0
	_set_collisions_enabled(true)

func on_despawn() -> void:
	_is_active = false
	_is_elite = false
	_enraged = false
	_slow_timer = 0.0
	remove_from_group("enemies")
	target = null
	_color_variant = Color.WHITE
	_scale_variant = 1.0
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
		_death_tween = null
	if _anim:
		_anim.stop()
		_anim.modulate = Color(1, 1, 1, 1)
		_anim.scale = _base_anim_scale
	_is_culled = false
	modulate = Color(1, 1, 1, 1)

func _assign_visual_variant() -> void:
	_scale_variant = randf_range(0.85, 1.15)
	if _is_elite:
		_color_variant = ELITE_COLOR
		_scale_variant = randf_range(1.1, 1.25)
		return
	match enemy_data.enemy_class:
		EnemyData.EnemyClass.SMALL_FAST:
			_scale_variant = randf_range(0.5, 0.8)
		EnemyData.EnemyClass.MEDIUM:
			_scale_variant = randf_range(1.0, 1.3)
		EnemyData.EnemyClass.BIG_TANK:
			_scale_variant = randf_range(1.0, 1.2)
		EnemyData.EnemyClass.MINE:
			_scale_variant = randf_range(0.9, 1.2)
		EnemyData.EnemyClass.OVERLORD:
			_scale_variant = randf_range(0.95, 1.25)

func _setup_animation() -> void:
	if not _anim:
		_anim = get_node_or_null("AnimatedSprite2D")
		if not _anim:
			return

	match enemy_data.enemy_class:
		EnemyData.EnemyClass.SMALL_FAST:
			if not _small_frames:
				_small_frames = SpriteFrames.new()
				_small_frames.add_animation("walk")
				_small_frames.set_animation_speed("walk", 10.0)
				_small_frames.set_animation_loop("walk", true)
				for i in range(6):
					var num: String = ("0" + str(i)) if i < 10 else str(i)
					_small_frames.add_frame("walk", load("res://Sprites/%s_small_fast_enemy_pix.png" % num))
			_anim.sprite_frames = _small_frames
			_anim.scale = Vector2(0.41, 0.41) * _scale_variant
		EnemyData.EnemyClass.MEDIUM:
			if not _medium_frames:
				_medium_frames = SpriteFrames.new()
				_medium_frames.add_animation("walk")
				_medium_frames.set_animation_speed("walk", 8.0)
				_medium_frames.set_animation_loop("walk", true)
				for i in range(6):
					var num: String = ("0" + str(i)) if i < 10 else str(i)
					_medium_frames.add_frame("walk", load("res://Sprites/%s_enemy_pix.png" % num))
			_anim.sprite_frames = _medium_frames
			_anim.scale = Vector2(0.35, 0.35) * _scale_variant
		EnemyData.EnemyClass.BIG_TANK:
			if not _big_frames:
				_big_frames = SpriteFrames.new()
				_big_frames.add_animation("walk")
				_big_frames.set_animation_speed("walk", 6.0)
				_big_frames.set_animation_loop("walk", true)
				for i in range(6):
					var num: String = ("0" + str(i)) if i < 10 else str(i)
					_big_frames.add_frame("walk", load("res://Sprites/%s_big_enemy_pix.png" % num))
			_anim.sprite_frames = _big_frames
			_anim.scale = Vector2(0.67, 0.67) * _scale_variant
		EnemyData.EnemyClass.MINE:
			if not _mine_frames:
				_mine_frames = SpriteFrames.new()
				_mine_frames.add_animation("walk")
				_mine_frames.set_animation_speed("walk", 8.0)
				_mine_frames.set_animation_loop("walk", true)
				for i in range(6):
					var num: String = ("0" + str(i)) if i < 10 else str(i)
					_mine_frames.add_frame("walk", load("res://Sprites/%s_mine_enemy_pix.png" % num))
			_anim.sprite_frames = _mine_frames
			_anim.scale = Vector2(0.35, 0.35) * _scale_variant
		EnemyData.EnemyClass.OVERLORD:
			if not _overlord_frames:
				_overlord_frames = SpriteFrames.new()
				_overlord_frames.add_animation("walk")
				_overlord_frames.set_animation_speed("walk", 6.0)
				_overlord_frames.set_animation_loop("walk", true)
				for i in range(6):
					var num: String = ("0" + str(i)) if i < 10 else str(i)
					_overlord_frames.add_frame("walk", load("res://Sprites/%s_overlord_enemy_normal_pix.png" % num))
				_overlord_frames.add_animation("rage")
				_overlord_frames.set_animation_speed("rage", 8.0)
				_overlord_frames.set_animation_loop("rage", true)
				for i in range(6):
					var num: String = ("0" + str(i)) if i < 10 else str(i)
					_overlord_frames.add_frame("rage", load("res://Sprites/%s_overlord_enemy_rage_pix.png" % num))
			_anim.sprite_frames = _overlord_frames
			_anim.scale = Vector2(0.5, 0.5) * _scale_variant

	_anim.play("walk")
	_anim.visible = true
	_anim.modulate = _color_variant
	_base_anim_scale = _anim.scale
	if not _shared_vignette_mat:
		_shared_vignette_mat = ShaderMaterial.new()
		_shared_vignette_mat.shader = preload("res://Systems/EnemyVignetteShader.gdshader")
	if not _anim.material:
		_anim.material = _shared_vignette_mat
	z_index = 1

func _physics_process(_delta: float) -> void:
	if not _is_active or not enemy_data or not GameManager.is_playing():
		return
	if not is_instance_valid(target):
		target = GameManager.get_player()
		if not target:
			return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= _delta
		if _hit_flash_timer <= 0.0 and _anim:
			_anim.modulate = _color_variant

	var slow_mult: float = 1.0
	if _slow_timer > 0.0:
		_slow_timer -= _delta
		if _slow_timer > 2.0:
			slow_mult = 0.0
		elif _slow_timer > 0.0:
			slow_mult = 1.0 - _slow_timer / 2.0
		if _anim and _hit_flash_timer <= 0.0:
			if _slow_timer > 2.0:
				if _anim.is_playing():
					_anim.stop()
					_anim.frame = 0
				_anim.speed_scale = 0.0
				_anim.modulate = Color(0.65, 0.85, 1.0, 1.0)
			else:
				var freeze: float = minf(_slow_timer / 4.0, 1.0)
				_anim.speed_scale = 0.0
				_anim.modulate = Color(
					lerpf(_color_variant.r, 0.65, freeze),
					lerpf(_color_variant.g, 0.85, freeze),
					lerpf(_color_variant.b, 1.0, freeze),
					1.0
				)
	elif _anim and _hit_flash_timer <= 0.0:
		if not _anim.is_playing():
			_anim.play("walk")
		_anim.modulate = _color_variant
		_anim.speed_scale = 1.0

	_cull_check_timer -= _delta
	if _cull_check_timer <= 0.0:
		_cull_check_timer = 0.5
		_update_culling()

	if _is_culled:
		if enemy_data.enemy_class == EnemyData.EnemyClass.SMALL_FAST:
			global_position += _straight_dir * enemy_data.speed * slow_mult * _delta
		else:
			var dir := global_position.direction_to(target.global_position)
			global_position += dir * enemy_data.speed * slow_mult * _delta
		if enemy_data.explodes_on_contact:
			_check_contact_explosion()
		if enemy_data.pushback_force > 0.0:
			_check_pushback()
		set_physics_process(false)
		set_process(true)
		return

	if not is_physics_processing():
		set_physics_process(true)
		set_process(false)

	_steering_force = Vector2.ZERO
	if enemy_data.enemy_class == EnemyData.EnemyClass.SMALL_FAST:
		velocity = _straight_dir * enemy_data.speed * slow_mult
	else:
		_steering_force += _seek(target.global_position) * enemy_data.seek_weight
		_steering_force += _separation() * enemy_data.separation_weight
		_steering_force += _avoid_player() * 0.5
		velocity = _steering_force.limit_length(enemy_data.speed * slow_mult)

	global_position += velocity * _delta

	if _anim:
		if velocity.x < -1.0:
			_anim.flip_h = true
		elif velocity.x > 1.0:
			_anim.flip_h = false

	if enemy_data.explodes_on_contact:
		_check_contact_explosion()

	if enemy_data.pushback_force > 0.0:
		_check_pushback()

	if enemy_data.enemy_class == EnemyData.EnemyClass.OVERLORD and not _enraged:
		if current_hp < enemy_data.max_hp * 0.5:
			_enraged = true
			if _anim and is_instance_valid(_anim):
				_anim.play("rage")

	if _enraged and _anim and is_instance_valid(_anim):
		var enraged_scale := _base_anim_scale * 2.0
		_anim.scale = _anim.scale.lerp(enraged_scale, _delta * 1.5)

func _process(delta: float) -> void:
	if not _is_culled or not _is_active or not enemy_data or not GameManager.is_playing():
		set_process(false)
		return
	if not is_instance_valid(target):
		target = GameManager.get_player()
		if not target:
			return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0 and _anim:
			_anim.modulate = _color_variant

	_cull_check_timer -= delta
	if _cull_check_timer <= 0.0:
		_cull_check_timer = 0.5
		_update_culling()

	if _is_culled:
		if enemy_data.enemy_class == EnemyData.EnemyClass.SMALL_FAST:
			global_position += _straight_dir * enemy_data.speed * delta
		else:
			var dir := global_position.direction_to(target.global_position)
			global_position += dir * enemy_data.speed * delta
		if enemy_data.explodes_on_contact:
			_check_contact_explosion()
		if enemy_data.pushback_force > 0.0:
			_check_pushback()
	else:
		set_process(false)
		set_physics_process(true)

func _update_culling() -> void:
	if not is_instance_valid(target):
		return
	var dist_sq := global_position.distance_squared_to(target.global_position)
	if dist_sq > CULL_DISTANCE_SQ and not _is_culled:
		_is_culled = true
		_set_collisions_enabled(false)
		if _anim:
			_anim.stop()
	elif dist_sq <= CULL_DISTANCE_SQ and _is_culled:
		_is_culled = false
		_set_collisions_enabled(true)
		if _anim:
			_anim.play("walk")

func _set_collisions_enabled(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled
		elif child is CollisionPolygon2D:
			child.disabled = not enabled
		elif child is Area2D:
			for sub in child.get_children():
				if sub is CollisionShape2D:
					sub.disabled = not enabled
				elif sub is CollisionPolygon2D:
					sub.disabled = not enabled

func _seek(target_pos: Vector2) -> Vector2:
	var desired := (target_pos - global_position).normalized() * enemy_data.speed
	return desired - velocity

func _separation() -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	var steer: Vector2 = Vector2.ZERO
	var count: int = 0
	for e in all_enemies:
		if e == self or not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < enemy_data.separation_radius and d > 0.0:
			steer += (global_position - e.global_position).normalized() / d
			count += 1
	if count > 0:
		steer /= float(count)
		return steer.normalized() * enemy_data.speed
	return Vector2.ZERO

func _avoid_player() -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	var dist_to_player := global_position.distance_to(target.global_position)
	if dist_to_player < enemy_data.avoid_player_radius and dist_to_player > 0.0:
		return (global_position - target.global_position).normalized() * enemy_data.speed * 0.5
	return Vector2.ZERO

func _check_contact_explosion() -> void:
	if not is_instance_valid(target):
		return
	var dist := global_position.distance_to(target.global_position)
	if dist < enemy_data.collision_radius + 16.0:
		var is_chance_exploder := enemy_data.enemy_class == EnemyData.EnemyClass.MINE or enemy_data.enemy_class == EnemyData.EnemyClass.OVERLORD
		if is_chance_exploder:
			if randf() < 0.5:
				if target.has_method("take_damage"):
					target.take_damage(enemy_data.explosion_damage, self)
				SoundManager.play_sound("enemy_explode")
				JuiceManager.spawn_explosion_visual(global_position, 60.0, Color(1.0, 0.7, 0.1))
				JuiceManager.screen_shake(6.0, 0.12)
				_die_no_xp()
			else:
				if target.has_method("take_damage"):
					target.take_damage(enemy_data.damage, self)
		else:
			if target.has_method("take_damage"):
				target.take_damage(enemy_data.explosion_damage, self)
			SoundManager.play_sound("enemy_explode")
			_die_no_xp()

func _check_pushback() -> void:
	if not is_instance_valid(target):
		return
	var dist := global_position.distance_to(target.global_position)
	if dist < enemy_data.collision_radius + 20.0:
		if target.has_method("take_damage"):
			target.take_damage(enemy_data.explosion_damage, self)
		_die_no_xp()

func take_damage(amount: float, damage_type: StringName = &"") -> void:
	if not _is_active:
		return
	if damage_type != &"":
		last_damage_type = damage_type
	current_hp -= amount
	if _anim:
		_anim.modulate = Color(3.0, 3.0, 3.0, 1.0)
		_hit_flash_timer = 0.08
	if current_hp <= 0.0:
		SoundManager.play_sound("enemy_die")
		die()

func _get_death_type() -> String:
	match enemy_data.enemy_class:
		EnemyData.EnemyClass.SMALL_FAST:
			return "small"
		EnemyData.EnemyClass.MEDIUM:
			return "medium"
		EnemyData.EnemyClass.BIG_TANK:
			return "big"
		EnemyData.EnemyClass.MINE:
			return "mine"
		EnemyData.EnemyClass.OVERLORD:
			return "overlord"
		EnemyData.EnemyClass.RAMPAGE:
			return "rampage"
	return "small"

func apply_slow(duration: float = 4.0) -> void:
	_slow_timer = maxf(_slow_timer, duration)

func die() -> void:
	if not _is_active:
		return
	_is_active = false
	remove_from_group("enemies")
	set_physics_process(false)
	JuiceManager.spawn_death_effect(global_position, _color_variant, _get_death_type(), last_damage_type)
	var kill_xp := enemy_data.xp_value
	var player := GameManager.get_player()
	if is_instance_valid(player) and player.has_method("add_xp"):
		player.add_xp(kill_xp)
	EventBus.enemy_died.emit(global_position, enemy_data.xp_value, enemy_data.enemy_name)
	_play_death_animation()

func _die_no_xp() -> void:
	if not _is_active:
		return
	_is_active = false
	remove_from_group("enemies")
	set_physics_process(false)
	JuiceManager.spawn_death_effect(global_position, _color_variant, _get_death_type(), last_damage_type)
	_play_death_animation()

func _play_death_animation() -> void:
	if _anim and is_instance_valid(_anim):
		if _death_tween and _death_tween.is_valid():
			_death_tween.kill()
		_death_tween = create_tween()
		_death_tween.tween_property(_anim, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
		_death_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
		_death_tween.tween_callback(func() -> void:
			_death_tween = null
			PoolManager.despawn(enemy_data.pool_name, self)
		)
	else:
		PoolManager.despawn(enemy_data.pool_name, self)

