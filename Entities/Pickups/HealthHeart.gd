class_name HealthHeart extends Area2D

@export var data: PickupData

const COLLECT_DIST: float = 12.0
const COLLECT_ANIM_SPEED: float = 6.0
const MAGNET_SPEED: float = 200.0
const MAGNET_RANGE: float = 60.0
const SPRITE_SCALE: float = 0.07
const COLLISION_RADIUS: float = 7.0

var _is_magnetized: bool = false
var _is_collected: bool = false
var _collecting: bool = false
var _collect_t: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _player_ref: Node2D = null
var _sprite: Sprite2D = null
var _pulse_tween: Tween = null
var _default_data: PickupData = null
var _mega_magnet: bool = false
var _collision_shape: CollisionShape2D = null

func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	_create_visual()
	_create_collision()
	_default_data = PickupData.new()
	_default_data.pickup_type = PickupData.PickupType.HEART
	_default_data.value = 20.0
	_default_data.magnet_range = MAGNET_RANGE
	_default_data.magnet_speed = MAGNET_SPEED
	_default_data.pool_name = &"HealthHeart"

func _get_data() -> PickupData:
	if data:
		return data
	return _default_data

func _create_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://Sprites/health_item.png")
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.z_index = -1
	add_child(_sprite)

func _create_collision() -> void:
	_collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLLISION_RADIUS
	_collision_shape.shape = circle
	_collision_shape.disabled = true
	add_child(_collision_shape)

func on_spawn() -> void:
	_is_magnetized = false
	_is_collected = false
	_collecting = false
	_collect_t = 0.0
	_velocity = Vector2.ZERO
	_mega_magnet = false
	modulate.a = 1.0
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_player_ref = GameManager.get_player()
	if _collision_shape:
		_collision_shape.disabled = false
	if _default_data:
		_default_data.value = 20.0
	if _sprite:
		_sprite.modulate = Color(1, 1, 1, 1)
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	if not EventBus.mega_magnet_activated.is_connected(activate_mega_magnet):
		EventBus.mega_magnet_activated.connect(activate_mega_magnet)
	if not EventBus.mega_magnet_ended.is_connected(_deactivate_mega_magnet):
		EventBus.mega_magnet_ended.connect(_deactivate_mega_magnet)
	_start_pulse()

func on_despawn() -> void:
	_is_magnetized = false
	_is_collected = true
	_collecting = false
	_collect_t = 0.0
	_mega_magnet = false
	_velocity = Vector2.ZERO
	_player_ref = null
	process_mode = Node.PROCESS_MODE_DISABLED
	if _collision_shape:
		_collision_shape.disabled = true
	if EventBus.mega_magnet_activated.is_connected(activate_mega_magnet):
		EventBus.mega_magnet_activated.disconnect(activate_mega_magnet)
	if EventBus.mega_magnet_ended.is_connected(_deactivate_mega_magnet):
		EventBus.mega_magnet_ended.disconnect(_deactivate_mega_magnet)
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null

func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_sprite, "modulate", Color(1.2, 0.5, 0.5, 1.0), 0.4).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4).set_ease(Tween.EASE_IN)
	_pulse_tween.tween_property(_sprite, "scale", Vector2(SPRITE_SCALE * 1.2, SPRITE_SCALE * 1.2), 0.25).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_sprite, "scale", Vector2(SPRITE_SCALE * 0.9, SPRITE_SCALE * 0.9), 0.25).set_ease(Tween.EASE_IN)
	_pulse_tween.tween_property(_sprite, "scale", Vector2(SPRITE_SCALE * 1.05, SPRITE_SCALE * 1.05), 0.15).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_sprite, "scale", Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.15).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	if _is_collected:
		return
	if not is_instance_valid(_player_ref):
		_player_ref = GameManager.get_player()
		if not is_instance_valid(_player_ref):
			return

	if _collecting:
		_collect_t += delta * COLLECT_ANIM_SPEED
		if _collect_t >= 1.0:
			_finish_collect()
			return
		var t: float = _collect_t
		var alpha: float = maxf(1.0 - t, 0.0)
		if _sprite:
			_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE) * (1.0 + t * 0.5)
			_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)
		modulate.a = alpha
		global_position = global_position.move_toward(_player_ref.global_position, 800.0 * delta)
		return

	var dist := global_position.distance_to(_player_ref.global_position)
	var pickup_range: float = MAGNET_RANGE
	if _player_ref.has_method("get_pickup_range"):
		pickup_range = _player_ref.get_pickup_range()

	if _mega_magnet:
		_is_magnetized = true
		var vp := get_viewport_rect().size
		pickup_range = maxf(vp.x, vp.y) * 0.8

	if not _is_magnetized:
		if dist < pickup_range:
			_is_magnetized = true

	if _is_magnetized:
		var direction := global_position.direction_to(_player_ref.global_position)
		var speed_factor := 1.0 - clampf(dist / maxf(pickup_range, 1.0), 0.0, 0.8)
		var speed: float = MAGNET_SPEED * (0.5 + speed_factor * 1.5)
		if _mega_magnet:
			speed = maxf(speed, 500.0)
		if dist < 50.0:
			speed = maxf(speed, 600.0)
		_velocity = direction * speed
		global_position += _velocity * delta

		if dist < COLLECT_DIST:
			_start_collect()
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, 100.0 * delta)
		global_position += _velocity * delta

func _start_collect() -> void:
	_collecting = true
	_collect_t = 0.0
	if _collision_shape:
		_collision_shape.disabled = true
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null

func _finish_collect() -> void:
	_is_collected = true
	var pd := _get_data()
	if is_instance_valid(_player_ref) and _player_ref.has_method("heal") and pd:
		_player_ref.heal(pd.value)
		EventBus.pickup_collected.emit(&"heart", pd.value)
		SoundManager.play_sound("pickup_heart")
	PoolManager.despawn(&"HealthHeart", self)

func activate_mega_magnet() -> void:
	_mega_magnet = true
	_is_magnetized = true

func _deactivate_mega_magnet() -> void:
	_mega_magnet = false
