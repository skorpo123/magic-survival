class_name CurrencyOrb extends Area2D

var rarity: int = ItemRarity.Tier.COMMON
var value: int = 1
var _is_magnetized: bool = false
var _is_collected: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _player_ref: Node2D = null
var _pulse_phase: float = 0.0
var _mega_magnet: bool = false
var _collision_shape: CollisionShape2D = null
var _glow_phase: float = 0.0

const VALUES := {
	ItemRarity.Tier.COMMON:    [1, 3],
	ItemRarity.Tier.UNCOMMON:  [5, 10],
	ItemRarity.Tier.RARE:      [20, 40],
	ItemRarity.Tier.LEGENDARY: [80, 120],
}
const SIZES := {
	ItemRarity.Tier.COMMON: 0.6,
	ItemRarity.Tier.UNCOMMON: 0.8,
	ItemRarity.Tier.RARE: 1.0,
	ItemRarity.Tier.LEGENDARY: 1.4,
}
const ORB_RADIUS: float = 12.0

func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	_create_collision()
	EventBus.mega_magnet_activated.connect(activate_mega_magnet)
	EventBus.mega_magnet_ended.connect(_deactivate_mega_magnet)

func _create_collision() -> void:
	_collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ORB_RADIUS
	_collision_shape.shape = circle
	_collision_shape.disabled = true
	add_child(_collision_shape)

func on_spawn() -> void:
	_is_magnetized = false
	_is_collected = false
	_velocity = Vector2.ZERO
	_mega_magnet = false
	_pulse_phase = randf() * TAU
	_glow_phase = randf() * TAU
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not is_in_group("magnet_target"):
		add_to_group("magnet_target")
	_player_ref = GameManager.get_player()
	if _collision_shape:
		_collision_shape.disabled = false

func on_despawn() -> void:
	_is_collected = true
	_is_magnetized = false
	_mega_magnet = false
	_velocity = Vector2.ZERO
	_player_ref = null
	process_mode = Node.PROCESS_MODE_DISABLED
	if _collision_shape:
		_collision_shape.disabled = true

func setup(tier: int) -> void:
	rarity = tier
	var range_arr: Array = VALUES[tier]
	value = randi_range(int(range_arr[0]), int(range_arr[1]))
	scale = Vector2.ONE * SIZES[tier]
	queue_redraw()

func _draw() -> void:
	var col: Color = ItemRarity.COLORS.get(rarity, Color.GRAY)
	var pulse: float = 1.0 + 0.1 * sin(_pulse_phase)
	var r: float = ORB_RADIUS * pulse

	if rarity == ItemRarity.Tier.LEGENDARY:
		for i in range(3):
			draw_circle(Vector2.ZERO, r + 8.0 - i * 3.0, Color(col.r, col.g, col.b, 0.06 + i * 0.03))

	draw_circle(Vector2.ZERO, r, Color(col.r * 0.15, col.g * 0.15, col.b * 0.2, 0.9))

	var inner_r: float = r * 0.6
	draw_circle(Vector2.ZERO, inner_r, Color(col.r * 0.8, col.g * 0.8, col.b * 0.9, 0.7))

	var highlight := Vector2(-r * 0.2, -r * 0.2)
	draw_circle(highlight, r * 0.25, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.5))

func _process(delta: float) -> void:
	if _is_collected:
		return
	if is_in_group("magnet_skip"):
		return

	_pulse_phase += delta * 4.0
	_glow_phase += delta * 2.0
	queue_redraw()

	if not is_instance_valid(_player_ref):
		_player_ref = GameManager.get_player()
		if not is_instance_valid(_player_ref):
			return

	var dist := global_position.distance_to(_player_ref.global_position)
	var pickup_range: float = 60.0
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
		var speed: float = 200.0 * (0.5 + speed_factor * 1.5)
		if _mega_magnet:
			speed = maxf(speed, 500.0)
		if dist < 50.0:
			speed = maxf(speed, 600.0)
		_velocity = direction * speed
		global_position += _velocity * delta

		if dist < 12.0:
			_collect()
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, 100.0 * delta)
		global_position += _velocity * delta

func _collect() -> void:
	_is_collected = true
	EventBus.currency_collected.emit(value, rarity)
	PoolManager.despawn(&"CurrencyOrb", self)

func activate_mega_magnet() -> void:
	_mega_magnet = true
	_is_magnetized = true

func _deactivate_mega_magnet() -> void:
	_mega_magnet = false
