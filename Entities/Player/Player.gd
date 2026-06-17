class_name Player extends CharacterBody2D

const ShadowTexture = preload("res://Systems/ShadowTexture.gd")
@export var stats: PlayerStats

var _invuln_timer: float = 0.0
var _is_dead: bool = false
var _anim: AnimatedSprite2D = null
var _contact_damage_timer: float = 0.0
var _hurt_detector: Area2D = null
var _knockback_velocity: Vector2 = Vector2.ZERO
var _hit_flash_timer: float = -1.0
var _heal_accum: float = 0.0
var _regen_flash_timer: float = 0.0
var _shadow_sprite: Sprite2D = null

signal hp_changed(current: float, maximum: float)
signal xp_changed(current: float, required: float)
signal leveled_up(new_level: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player")
	# NOTE: stats are overwritten in GameManager.start_game() / enter_endless() → apply_to_player()
	# This default init is for first-frame rendering before apply_to_player runs
	if not stats:
		stats = PlayerStats.new()
	stats.current_hp = stats.max_hp
	stats.current_level = stats.starting_level
	stats.current_xp = 0.0
	EventBus.player_died.connect(_on_player_died_event)
	EventBus.enemy_died.connect(_on_enemy_died_event)

	_anim = get_node_or_null("AnimatedSprite2D")
	_setup_animation()
	_setup_shadow()

	var detector := get_node_or_null("PickupDetector")
	if detector:
		detector.area_entered.connect(_on_pickup_detected)

	var hurt := get_node_or_null("HurtDetector")
	if hurt:
		hurt.body_entered.connect(_on_hurt_body_entered)
		_hurt_detector = hurt
	else:
		_create_hurt_detector()

func _create_hurt_detector() -> void:
	_hurt_detector = Area2D.new()
	_hurt_detector.name = "HurtDetector"
	_hurt_detector.collision_layer = 0
	_hurt_detector.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	_hurt_detector.add_child(shape)
	add_child(_hurt_detector)
	_hurt_detector.body_entered.connect(_on_hurt_body_entered)

func _setup_animation() -> void:
	if not _anim:
		return
	var frames := SpriteFrames.new()

	frames.add_animation("idle")
	frames.set_animation_speed("idle", 5.0)
	frames.set_animation_loop("idle", true)
	for i in range(6):
		var num: String = ("0" + str(i)) if i < 10 else str(i)
		frames.add_frame("idle", load("res://Sprites/" + num + "_player_idle_pix.png"))

	frames.add_animation("walk_down")
	frames.set_animation_speed("walk_down", 10.0)
	frames.set_animation_loop("walk_down", true)
	for i in range(6):
		var num: String = ("0" + str(i)) if i < 10 else str(i)
		frames.add_frame("walk_down", load("res://Sprites/" + num + "_mage_down_pix.png"))

	frames.add_animation("walk_up")
	frames.set_animation_speed("walk_up", 10.0)
	frames.set_animation_loop("walk_up", true)
	for i in range(6):
		var num: String = ("0" + str(i)) if i < 10 else str(i)
		frames.add_frame("walk_up", load("res://Sprites/" + num + "_mage_up_pix.png"))

	frames.add_animation("walk_left")
	frames.set_animation_speed("walk_left", 10.0)
	frames.set_animation_loop("walk_left", true)
	for i in range(6):
		var num: String = ("0" + str(i)) if i < 10 else str(i)
		frames.add_frame("walk_left", load("res://Sprites/" + num + "_mage_left_pix.png"))

	frames.add_animation("walk_right")
	frames.set_animation_speed("walk_right", 10.0)
	frames.set_animation_loop("walk_right", true)
	for i in range(6):
		var num: String = ("0" + str(i)) if i < 10 else str(i)
		frames.add_frame("walk_right", load("res://Sprites/" + num + "_mage_right_pix.png"))

	_anim.sprite_frames = frames
	_anim.play("idle")
	_anim.scale = Vector2(0.255, 0.255)

func _setup_shadow() -> void:
	_shadow_sprite = Sprite2D.new()
	_shadow_sprite.texture = ShadowTexture.get_texture()
	_shadow_sprite.z_index = -1
	_shadow_sprite.z_as_relative = false
	_shadow_sprite.top_level = true
	_shadow_sprite.scale = Vector2(3.5, 1.75)
	var shadow_mat := ShaderMaterial.new()
	shadow_mat.shader = load("res://Shaders/shadow_oval.gdshader") as Shader
	shadow_mat.set_shader_parameter("shadow_tex", ShadowTexture.get_texture())
	shadow_mat.set_shader_parameter("shadow_color", Color(0.03, 0.03, 0.03, 0.7))
	_shadow_sprite.material = shadow_mat
	_shadow_sprite.scale = Vector2(1.8, 0.5)
	add_child(_shadow_sprite)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if GameManager.current_state == GameManager.GameState.LEVEL_UP or GameManager.current_state == GameManager.GameState.ARTIFACT_SELECT:
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * stats.move_speed + _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
	move_and_slide()

	if _shadow_sprite:
		_shadow_sprite.global_position = global_position + Vector2(0.0, 52.0)

	if is_instance_valid(_anim):
		if direction != Vector2.ZERO:
			_anim.scale = Vector2(0.255, 0.255)
			var abs_x := absf(direction.x)
			var abs_y := absf(direction.y)
			if abs_x >= abs_y:
				if direction.x > 0.0:
					_anim.play("walk_right")
				else:
					_anim.play("walk_left")
			else:
				if direction.y > 0.0:
					_anim.play("walk_down")
				else:
					_anim.play("walk_up")
		else:
			_anim.scale = Vector2(0.183, 0.183)
			_anim.play("idle")

	if _invuln_timer > 0.0:
		_invuln_timer -= delta

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0 and _anim:
			_anim.modulate = Color(1, 1, 1, 1)

	if _regen_flash_timer > 0.0:
		_regen_flash_timer -= delta
		if _regen_flash_timer <= 0.0 and _anim and _hit_flash_timer <= 0.0:
			_anim.modulate = Color(1, 1, 1, 1)

	if stats.hp_regen > 0.0 and not ArtifactManager.regen_disabled():
		_heal_accum += stats.hp_regen * delta
		if _heal_accum >= 0.5:
			var healed_hp := _heal_accum
			heal(_heal_accum)
			_heal_accum = 0.0
			if stats.current_hp < stats.max_hp:
				_show_regen_flash()

func _show_regen_flash() -> void:
	if _anim and _regen_flash_timer <= 0.0 and _hit_flash_timer <= 0.0:
		_anim.modulate = Color(0.5, 1.0, 0.5, 1.0)
		_regen_flash_timer = 0.15

func take_damage(amount: float, _source: Node2D = null) -> void:
	if _invuln_timer > 0.0 or _is_dead:
		return
	if PowerUpManager.is_invulnerable():
		return
	var shield := _get_shield_behavior()
	if shield and shield.intercept_damage():
		_invuln_timer = 0.2
		return

	if randf() < stats.dodge_chance:
		_spawn_dodge_text()
		return

	var effective_damage := stats.get_mitigated_damage(amount)
	stats.current_hp -= effective_damage

	EventBus.player_damaged.emit(effective_damage, _source)
	SoundManager.play_sound("hit_player")
	hp_changed.emit(stats.current_hp, stats.max_hp)

	if _anim:
		_anim.modulate = Color(3.0, 3.0, 3.0, 1.0)
		_hit_flash_timer = 0.1

	if stats.current_hp <= 0.0:
		die()
	else:
		var cd: float = 0.15
		if _source and "enemy_data" in _source:
			var eclass = _source.enemy_data.enemy_class
			if eclass == EnemyData.EnemyClass.MEDIUM:
				cd = 0.12
			elif eclass == EnemyData.EnemyClass.RAMPAGE:
				cd = 0.2
		_invuln_timer = cd

func heal(amount: float) -> void:
	if _is_dead:
		return
	var before: float = stats.current_hp
	stats.current_hp = minf(stats.current_hp + amount, stats.max_hp)
	if amount > 0.0 and stats.current_hp > before:
		EventBus.player_healed.emit(amount)
		hp_changed.emit(stats.current_hp, stats.max_hp)

func add_xp(amount: float) -> void:
	if _is_dead:
		return

	var effective: float = amount
	effective *= ArtifactManager.get_xp_mult()
	if stats:
		effective *= stats.mana_gain
	stats.current_xp += effective
	EventBus.player_xp_gained.emit(effective)

	while stats.current_xp >= stats.get_xp_required():
		stats.current_xp -= stats.get_xp_required()
		stats.current_level += 1
		EventBus.player_level_up.emit(stats.current_level)
		SoundManager.play_sound("level_up")
		leveled_up.emit(stats.current_level)

	xp_changed.emit(stats.current_xp, stats.get_xp_required())

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	EventBus.player_died.emit()
	GameManager.trigger_game_over()

func _on_player_died_event() -> void:
	set_physics_process(false)

func _on_enemy_died_event(_pos: Vector2, xp_value: float, _enemy_type: StringName) -> void:
	if ArtifactManager.has_artifact("Soul Harvest"):
		heal(1.0)
	var on_kill_regen := ArtifactManager.get_on_kill_regen()
	if on_kill_regen > 0.0:
		heal(on_kill_regen)
	var life_steal: float = 0.0
	if stats:
		life_steal = stats.life_steal
	if life_steal > 0.0:
		heal(xp_value * life_steal * 2.0)

func apply_power_up(data: PowerUpData) -> void:
	PowerUpManager.apply_power_up(data)

func get_pickup_range() -> float:
	return stats.pickup_range

func update_pickup_detector() -> void:
	var detector := get_node_or_null("PickupDetector")
	if detector:
		var shape := detector.get_node_or_null("CollisionShape2D")
		if shape and shape.shape is CircleShape2D:
			shape.shape.radius = stats.pickup_range

func _on_pickup_detected(area: Area2D) -> void:
	if "_is_collected" in area and area._is_collected:
		return

	var pickup: PickupData = null
	if "data" in area and area.data:
		pickup = area.data
	elif area.has_method("_get_data"):
		pickup = area._get_data()

	if area is PowerUpPickup and "_data" in area and area._data:
		var pu_data: PowerUpData = area._data
		apply_power_up(pu_data)
		JuiceManager.screen_flash(Color(pu_data.color.r, pu_data.color.g, pu_data.color.b, 0.15), 0.12)
		EventBus.pickup_collected.emit(&"power_up", pu_data.value)
		PoolManager.despawn(pu_data.pool_name, area)
		return

	if not pickup:
		return

	if pickup.pickup_type == PickupData.PickupType.EXPERIENCE_ORB:
		return

	if "_is_collected" in area:
		area._is_collected = true

	match pickup.pickup_type:
		PickupData.PickupType.HEART:
			heal(pickup.value)
			EventBus.pickup_collected.emit(&"heart", pickup.value)
			SoundManager.play_sound("pickup_heart")
		PickupData.PickupType.POWER_UP:
			EventBus.pickup_collected.emit(&"power_up", pickup.value)
	PoolManager.despawn(pickup.pool_name, area)

func _on_hurt_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and "enemy_data" in body and is_instance_valid(body):
		take_damage(body.enemy_data.damage, body)
		_contact_damage_timer = 0.5

func _check_contact_damage() -> void:
	var hurt := _hurt_detector if _hurt_detector else get_node_or_null("HurtDetector")
	if not hurt:
		return
	var overlapping: Array[Node2D] = hurt.get_overlapping_bodies()
	for body in overlapping:
		if body.is_in_group("enemies") and "enemy_data" in body and is_instance_valid(body):
			take_damage(body.enemy_data.damage, body)
			_contact_damage_timer = 0.5
			return

func apply_knockback(dir: Vector2, force: float) -> void:
	_knockback_velocity = dir * force

func _spawn_dodge_text() -> void:
	var label := Label.new()
	label.text = SettingsManager.t(&"stat_dodge")
	label.modulate = Color(0.6, 0.9, 1.0, 1.0)
	label.add_theme_font_size_override("font_size", SettingsManager.font_size(18))
	label.position = Vector2(randf_range(-10, 10), -24)
	label.z_index = 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	
	var start_pos := label.position
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", start_pos.y - 50.0, 0.8).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:x", start_pos.x + randf_range(-15, 15), 0.8).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.1)
	t.chain().tween_callback(label.queue_free)

func _get_shield_behavior() -> ShieldBehavior:
	var spells_node: Node = get_node_or_null("Spells")
	if not spells_node:
		return null
	for child in spells_node.get_children():
		if child is SpellCaster and child.spell and child.spell.behavior is ShieldBehavior:
			return child.spell.behavior
	return null
