class_name ExperienceOrb extends Node2D

enum OrbTier { SMALL, MEDIUM, LARGE, EPIC }

const TIER_COLORS: Dictionary = {OrbTier.SMALL: Color(0.5, 0.8, 1.0), OrbTier.MEDIUM: Color(0.3, 1.0, 0.5), OrbTier.LARGE: Color(1.0, 0.85, 0.2), OrbTier.EPIC: Color(1.0, 0.3, 0.8)}
const TIER_RADII: Dictionary = {OrbTier.SMALL: 5.0, OrbTier.MEDIUM: 8.0, OrbTier.LARGE: 11.0, OrbTier.EPIC: 14.0}
const TIER_VALUES: Dictionary = {OrbTier.SMALL: 2.4, OrbTier.MEDIUM: 9.6, OrbTier.LARGE: 28.0, OrbTier.EPIC: 64.0}

static var _orb_textures: Dictionary = {}

var _tier: OrbTier = OrbTier.SMALL
var _is_magnetized: bool = false
var _is_collected: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _mega_magnet: bool = false
var _spawned: bool = false
var _idle_time: float = 0.0
var _collect_anim: bool = false
var _collect_t: float = 0.0
var _sprite: Sprite2D = null

var _default_data: PickupData = null

@export var data: PickupData

func _ready() -> void:
	z_index = -1
	z_as_relative = false
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	_default_data = PickupData.new()
	_default_data.pickup_type = PickupData.PickupType.EXPERIENCE_ORB
	_default_data.value = 1.0
	_default_data.magnet_range = 100.0
	_default_data.magnet_speed = 300.0
	_default_data.pool_name = &"ExperienceOrb"
	for tier in [OrbTier.SMALL, OrbTier.MEDIUM, OrbTier.LARGE, OrbTier.EPIC]:
		_get_orb_texture(tier)

static func _get_orb_texture(tier: OrbTier) -> ImageTexture:
	if _orb_textures.has(tier):
		return _orb_textures[tier]
	var size: int = 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var color: Color = TIER_COLORS[tier]
	var center := size / 2.0
	var radius: float = TIER_RADII[tier]
	for px in range(size):
		for py in range(size):
			var dx := (px - center) / center
			var dy := (py - center) / center
			var dist := sqrt(dx * dx + dy * dy)
			if dist > 1.0:
				img.set_pixel(px, py, Color(0, 0, 0, 0))
			else:
				var fade := 1.0 - dist
				var a := fade * fade
				var r: float = lerp(color.r * 0.5, color.r, fade)
				var g: float = lerp(color.g * 0.5, color.g, fade)
				var b: float = lerp(color.b * 0.5, color.b, fade)
				img.set_pixel(px, py, Color(r, g, b, a))
	var tex := ImageTexture.create_from_image(img)
	_orb_textures[tier] = tex
	return tex

func _get_data() -> PickupData:
	if data:
		return data
	return _default_data

func on_spawn() -> void:
	_is_magnetized = false
	_is_collected = false
	_mega_magnet = false
	_collect_anim = false
	_collect_t = 0.0
	_velocity = Vector2.ZERO
	_spawned = true
	_idle_time = 0.0
	modulate = Color.WHITE
	scale = Vector2.ONE
	visible = true

	if data and data.value > 0:
		if data.value >= TIER_VALUES[OrbTier.EPIC]:
			_tier = OrbTier.EPIC
		elif data.value >= TIER_VALUES[OrbTier.LARGE]:
			_tier = OrbTier.LARGE
		elif data.value >= TIER_VALUES[OrbTier.MEDIUM]:
			_tier = OrbTier.MEDIUM
		else:
			_tier = OrbTier.SMALL
	else:
		_tier = OrbTier.SMALL

	_default_data.value = TIER_VALUES[_tier]
	if _sprite:
		_sprite.texture = _get_orb_texture(_tier)
		var r: float = TIER_RADII[_tier]
		_sprite.scale = Vector2(r / 5.0, r / 5.0)
	set_process(false)

func on_despawn() -> void:
	_is_magnetized = false
	_is_collected = true
	_mega_magnet = false
	_spawned = false
	_velocity = Vector2.ZERO
	_collect_anim = false
	_idle_time = 0.0

func activate_mega_magnet() -> void:
	_mega_magnet = true
	_is_magnetized = true

func tick_idle(player: Node2D) -> void:
	if not _spawned or _is_magnetized or _collect_anim:
		return
	var orb_data := _get_data()
	var dist_sq: float = global_position.distance_squared_to(player.global_position)
	var pickup_range: float = orb_data.magnet_range
	if player.has_method("get_pickup_range"):
		pickup_range = player.get_pickup_range()
	if _mega_magnet:
		_is_magnetized = true
		return
	var range_sq: float = pickup_range * pickup_range
	if dist_sq < range_sq:
		_is_magnetized = true

func tick_magnetized(delta: float, player: Node2D) -> void:
	if not _spawned:
		return

	if _collect_anim:
		_collect_t += delta * 6.0
		modulate.a = maxf(1.0 - _collect_t, 0.0)
		scale = Vector2.ONE * (1.0 + _collect_t * 0.5)
		if _collect_t >= 1.0:
			_collect_anim = false
			_finish_collect()
		return

	if not _is_magnetized:
		_velocity = _velocity.move_toward(Vector2.ZERO, 100.0 * delta)
		if _velocity.length_squared() > 1.0:
			global_position += _velocity * delta
		else:
			_idle_time += delta
		return

	var orb_data := _get_data()
	var dist: float = global_position.distance_to(player.global_position)
	var pickup_range: float = orb_data.magnet_range
	if player.has_method("get_pickup_range"):
		pickup_range = player.get_pickup_range()

	if _mega_magnet:
		var viewport := get_viewport_rect().size
		pickup_range = maxf(viewport.x, viewport.y) * 0.8

	var direction := global_position.direction_to(player.global_position)
	var speed_factor := 1.0 - clampf(dist / maxf(pickup_range, 1.0), 0.0, 0.8)
	var speed := orb_data.magnet_speed * (0.5 + speed_factor * 1.5)
	if _mega_magnet:
		speed = maxf(speed, 500.0)
	if dist < 50.0:
		speed = maxf(speed, 600.0)
	_velocity = direction * speed
	global_position += _velocity * delta
	_idle_time = 0.0

	if dist < 14.0:
		_start_collect()
		return

func _start_collect() -> void:
	if _is_collected:
		return
	_is_collected = true
	_collect_anim = true
	_collect_t = 0.0

	JuiceManager.spawn_xp_sparkle(global_position)

	var orb_data := _get_data()
	var player := GameManager.get_player()
	if is_instance_valid(player) and player.has_method("add_xp"):
		player.add_xp(orb_data.value)
	EventBus.pickup_collected.emit(&"experience_orb", orb_data.value)
	SoundManager.play_sound("pickup_orb")

func _finish_collect() -> void:
	_spawned = false
	var orb_data := _get_data()
	PoolManager.despawn(orb_data.pool_name, self)
