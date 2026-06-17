class_name Chest extends Area2D

var rarity: int = ItemRarity.Tier.COMMON
var is_boss_chest: bool = false
var _opened: bool = false
var _pulse_phase: float = 0.0
var _sprite: Sprite2D = null
var _glow: Sprite2D = null

const CHEST_RADIUS: float = 36.0
const SPRITE_TARGET_SIZE: float = 72.0

static var _shared_glow_tex: ImageTexture = null

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CHEST_RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://Sprites/chest_pix.png")
	_sprite.centered = true
	var tex_size: float = _sprite.texture.get_width()
	if tex_size > 0.0:
		var s: float = SPRITE_TARGET_SIZE / tex_size
		_sprite.scale = Vector2(s, s)
	add_child(_sprite)

	_glow = Sprite2D.new()
	_glow.texture = _get_glow_texture()
	_glow.z_index = -1
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = glow_mat
	_glow.visible = false
	add_child(_glow)

	_apply_rarity_visual()
	ChestTracker.register(self)

static func _get_glow_texture() -> ImageTexture:
	if _shared_glow_tex:
		return _shared_glow_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for px in range(size):
		for py in range(size):
			var dx := (px - c) / c
			var dy := (py - c) / c
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= 1.0:
				var fade := 1.0 - dist
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, fade * fade * fade * 0.5))
			else:
				img.set_pixel(px, py, Color(0, 0, 0, 0))
	_shared_glow_tex = ImageTexture.create_from_image(img)
	return _shared_glow_tex

func _apply_rarity_visual() -> void:
	var col: Color = ItemRarity.COLORS.get(rarity, Color.GRAY)
	if _sprite:
		_sprite.modulate = Color.WHITE
	if _glow:
		_glow.modulate = col
		_glow.scale = Vector2(2.4, 2.4) if rarity >= ItemRarity.Tier.RARE else Vector2(1.8, 1.8)
		_glow.visible = rarity >= ItemRarity.Tier.UNCOMMON

func _on_body_entered(body: Node2D) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_opened = true
	ChestTracker.unregister(self)
	_open()

func _open() -> void:
	var artifacts := ArtifactManager.generate_offer(rarity)
	EventBus.chest_opened.emit(artifacts, rarity, is_boss_chest)
	GameManager.enter_artifact_select()

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	_pulse_phase += delta * 3.0
	if _glow and _glow.visible:
		var pulse := 1.0 + 0.15 * sin(_pulse_phase)
		_glow.scale = Vector2(pulse, pulse) * (2.4 if rarity >= ItemRarity.Tier.RARE else 1.8)
