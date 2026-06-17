class_name PowerUpPickup extends Area2D

const ICON_RADIUS: float = 18.0

var _is_collected: bool = false
var _is_magnetized: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _player_ref: Node2D = null
var _pulse_phase: float = 0.0
var _data: PowerUpData = null
var _mega_magnet: bool = false
var _collision_shape: CollisionShape2D = null

func _ready() -> void:
	z_index = -1
	z_as_relative = false
	collision_layer = 16
	collision_mask = 0
	_create_collision()
	EventBus.mega_magnet_activated.connect(activate_mega_magnet)
	EventBus.mega_magnet_ended.connect(_deactivate_mega_magnet)

func _create_collision() -> void:
	_collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ICON_RADIUS
	_collision_shape.shape = circle
	_collision_shape.disabled = true
	add_child(_collision_shape)

func on_spawn() -> void:
	_is_collected = false
	_is_magnetized = false
	_velocity = Vector2.ZERO
	_mega_magnet = false
	_pulse_phase = randf() * TAU
	visible = true
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not is_in_group("magnet_skip"):
		add_to_group("magnet_skip")
	_player_ref = GameManager.get_player()
	if _collision_shape:
		_collision_shape.disabled = false
	queue_redraw()

func on_despawn() -> void:
	_is_collected = true
	_is_magnetized = false
	_mega_magnet = false
	_velocity = Vector2.ZERO
	_player_ref = null
	process_mode = Node.PROCESS_MODE_DISABLED
	if _collision_shape:
		_collision_shape.disabled = true

func set_data(data: PowerUpData) -> void:
	_data = data
	queue_redraw()

func _draw() -> void:
	if not _data:
		return
	var col: Color = _data.color
	var pulse: float = 1.0 + 0.12 * sin(_pulse_phase)
	match _data.power_up_type:
		PowerUpData.PowerUpType.INVULNERABILITY:
			_draw_invulnerability(col, pulse)
		PowerUpData.PowerUpType.DAMAGE_MULTIPLIER:
			_draw_damage(col, pulse)
		PowerUpData.PowerUpType.SPEED_BOOST:
			_draw_speed(col, pulse)
		PowerUpData.PowerUpType.FREEZE_ENEMIES:
			_draw_freeze(col, pulse)
		PowerUpData.PowerUpType.FIRE_RATE_BOOST:
			_draw_rapid_fire(col, pulse)
		PowerUpData.PowerUpType.MEGA_MAGNET:
			_draw_mega_magnet(col, pulse)
		_:
			draw_circle(Vector2.ZERO, ICON_RADIUS, col)

func _draw_invulnerability(col: Color, pulse: float) -> void:
	var r: float = ICON_RADIUS * pulse
	for i in range(3):
		draw_circle(Vector2.ZERO, r + 12.0 - i * 3.0, Color(col.r, col.g, col.b, 0.06 + i * 0.02))
	draw_circle(Vector2.ZERO, r, Color(0.05, 0.1, 0.2, 0.8))
	var pts := PackedVector2Array()
	var sides: int = 6
	for i in range(sides):
		var angle: float = i * TAU / sides - PI / 6.0
		pts.append(Vector2.RIGHT.rotated(angle) * r * 0.75)
	draw_colored_polygon(pts, Color(col.r * 0.3, col.g * 0.3, col.b * 0.5, 0.6))
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.9), 2.0, true)
	var inner_pts := PackedVector2Array()
	for i in range(sides):
		var angle: float = i * TAU / sides - PI / 6.0
		inner_pts.append(Vector2.RIGHT.rotated(angle) * r * 0.5)
	draw_polyline(inner_pts, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.7), 1.5, true)
	var rot: float = _pulse_phase * 0.5
	for i in range(3):
		var a: float = rot + i * TAU / 3.0
		var p1 := Vector2.RIGHT.rotated(a) * r * 0.2
		var p2 := Vector2.RIGHT.rotated(a) * r * 0.65
		draw_line(p1, p2, Color(col.r * 1.8, col.g * 1.8, col.b * 1.8, 0.5), 1.5, true)
	draw_circle(Vector2.ZERO, r * 0.18, Color(col.r, col.g, col.b, 0.9))

func _draw_damage(col: Color, pulse: float) -> void:
	var r: float = ICON_RADIUS * pulse
	for i in range(4):
		var flicker: float = 0.08 + 0.04 * sin(_pulse_phase * 3.0 + i * 1.5)
		draw_circle(Vector2.ZERO, r + 10.0 - i * 3.0, Color(1.0, col.g * 0.5, 0.0, flicker))
	draw_circle(Vector2.ZERO, r, Color(0.2, 0.03, 0.0, 0.85))
	var tip := Vector2(0.0, -r * 0.9)
	var base_l := Vector2(-r * 0.15, -r * 0.3)
	var base_r := Vector2(r * 0.15, -r * 0.3)
	var guard_l := Vector2(-r * 0.55, -r * 0.25)
	var guard_r := Vector2(r * 0.55, -r * 0.25)
	var guard_curve_l := Vector2(-r * 0.35, -r * 0.05)
	var guard_curve_r := Vector2(r * 0.35, -r * 0.05)
	var pommel := Vector2(0.0, r * 0.5)
	draw_line(Vector2(0.0, -r * 0.3), pommel, col, 3.5, true)
	draw_line(tip, base_l, col, 3.0, true)
	draw_line(tip, base_r, col, 3.0, true)
	draw_line(base_l, guard_l, col, 2.5, true)
	draw_line(base_r, guard_r, col, 2.5, true)
	draw_line(guard_l, guard_curve_l, col, 2.5, true)
	draw_line(guard_r, guard_curve_r, col, 2.5, true)
	draw_circle(tip, 4.0, Color(1.0, 0.8, 0.3, 0.8))
	draw_circle(tip, 2.5, Color(1.0, 1.0, 0.8))
	draw_circle(pommel, 3.5, Color(col.r * 0.7, col.g * 0.5, col.b * 0.3))
	for i in range(3):
		var a: float = _pulse_phase * 2.0 + i * TAU / 3.0
		var d: float = r * 0.55
		var spark := Vector2.RIGHT.rotated(a) * d
		draw_circle(spark, 2.0, Color(1.0, 0.9, 0.3, 0.6))

func _draw_speed(col: Color, pulse: float) -> void:
	var r: float = ICON_RADIUS * pulse
	for i in range(3):
		draw_circle(Vector2.ZERO, r + 8.0 - i * 3.0, Color(col.r, col.g, col.b, 0.07 + i * 0.02))
	draw_circle(Vector2.ZERO, r, Color(0.02, 0.12, 0.06, 0.8))
	var rot: float = _pulse_phase * 1.5
	for i in range(3):
		var angle: float = rot + i * TAU / 3.0
		var tip := Vector2.RIGHT.rotated(angle) * r * 0.8
		var mid := Vector2.RIGHT.rotated(angle + 0.4) * r * 0.45
		var base := Vector2.RIGHT.rotated(angle + 0.7) * r * 0.15
		var pts := PackedVector2Array([base, mid, tip])
		draw_colored_polygon(pts, Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.7))
		draw_polyline(pts, col, 1.5, true)
	var boot_y: float = r * 0.1
	var boot_pts := PackedVector2Array()
	boot_pts.append(Vector2(-r * 0.25, -r * 0.4))
	boot_pts.append(Vector2(r * 0.1, -r * 0.4))
	boot_pts.append(Vector2(r * 0.2, -r * 0.15))
	boot_pts.append(Vector2(r * 0.2, boot_y))
	boot_pts.append(Vector2(r * 0.45, boot_y + r * 0.15))
	boot_pts.append(Vector2(r * 0.45, boot_y + r * 0.3))
	boot_pts.append(Vector2(-r * 0.25, boot_y + r * 0.3))
	draw_colored_polygon(boot_pts, col)
	draw_polyline(boot_pts, Color(col.r * 1.3, col.g * 1.3, col.b * 1.3), 1.5, true)
	for i in range(3):
		var lx: float = -r * 0.35 - i * 4.0
		var ly: float = -r * 0.1 + i * 5.0
		var lw: float = r * 0.3 - i * 3.0
		draw_line(Vector2(lx, ly), Vector2(lx + lw, ly), Color(col.r, col.g, col.b, 0.5 - i * 0.12), 2.0 - i * 0.5, true)

func _draw_freeze(col: Color, pulse: float) -> void:
	var r: float = ICON_RADIUS * pulse
	for i in range(3):
		draw_circle(Vector2.ZERO, r + 10.0 - i * 3.0, Color(col.r, col.g, col.b, 0.06 + i * 0.02))
	draw_circle(Vector2.ZERO, r, Color(0.05, 0.1, 0.18, 0.85))
	var diamond := PackedVector2Array()
	diamond.append(Vector2(0.0, -r * 0.85))
	diamond.append(Vector2(r * 0.35, 0.0))
	diamond.append(Vector2(0.0, r * 0.85))
	diamond.append(Vector2(-r * 0.35, 0.0))
	draw_colored_polygon(diamond, Color(col.r * 0.5, col.g * 0.5, col.b * 0.7, 0.6))
	draw_polyline(diamond, col, 2.0, true)
	draw_line(Vector2(-r * 0.6, -r * 0.1), Vector2(r * 0.6, -r * 0.1), Color(col.r, col.g, col.b, 0.4), 1.5, true)
	draw_line(Vector2(-r * 0.5, r * 0.15), Vector2(r * 0.5, r * 0.15), Color(col.r, col.g, col.b, 0.3), 1.0, true)
	for i in range(6):
		var angle: float = i * PI / 3.0 + _pulse_phase * 0.3
		var d: float = r * 0.7
		var tip := Vector2.RIGHT.rotated(angle) * d
		draw_circle(tip, 2.5, Color(0.8, 0.95, 1.0, 0.7))
		draw_circle(tip, 1.5, Color.WHITE)
	draw_circle(Vector2.ZERO, r * 0.15, Color(0.9, 0.95, 1.0, 0.9))

func _draw_rapid_fire(col: Color, pulse: float) -> void:
	var r: float = ICON_RADIUS * pulse
	for i in range(3):
		draw_circle(Vector2.ZERO, r + 9.0 - i * 3.0, Color(col.r, col.g, col.b, 0.06 + i * 0.02))
	draw_circle(Vector2.ZERO, r, Color(0.15, 0.1, 0.02, 0.85))
	var star_pts := PackedVector2Array()
	var points: int = 5
	for i in range(points * 2):
		var angle: float = i * PI / points - PI / 2.0 + _pulse_phase * 0.8
		var rad: float = r * 0.8 if i % 2 == 0 else r * 0.35
		star_pts.append(Vector2.RIGHT.rotated(angle) * rad)
	draw_colored_polygon(star_pts, Color(col.r * 0.8, col.g * 0.7, col.b * 0.3, 0.8))
	draw_polyline(star_pts, Color(col.r * 1.3, col.g * 1.2, col.b * 0.5, 0.9), 1.5, true)
	draw_circle(Vector2.ZERO, r * 0.2, Color(col.r * 1.5, col.g * 1.3, col.b * 0.8))
	for i in range(4):
		var a: float = _pulse_phase * 2.5 + i * PI / 2.0
		var d := Vector2.RIGHT.rotated(a) * r * 0.55
		draw_line(Vector2.ZERO, d, Color(col.r, col.g, col.b, 0.3), 1.0, true)

func _draw_mega_magnet(col: Color, pulse: float) -> void:
	var r: float = ICON_RADIUS * pulse
	for i in range(3):
		draw_circle(Vector2.ZERO, r + 11.0 - i * 3.0, Color(col.r, col.g, col.b, 0.06 + i * 0.02))
	draw_circle(Vector2.ZERO, r, Color(0.1, 0.03, 0.15, 0.85))
	var u_top: float = -r * 0.55
	var u_bot: float = r * 0.65
	var u_left: float = -r * 0.45
	var u_right: float = r * 0.45
	var u_inner_l: float = -r * 0.15
	var u_inner_r: float = r * 0.15
	var u_curve: float = r * 0.25
	draw_line(Vector2(u_left, u_top), Vector2(u_left, u_bot - u_curve), Color(1.0, 0.3, 0.3), 4.0, true)
	draw_line(Vector2(u_right, u_top), Vector2(u_right, u_bot - u_curve), Color(0.3, 0.3, 1.0), 4.0, true)
	draw_arc(Vector2(0.0, u_bot - u_curve), u_curve, 0.0, PI, 8, col, 4.0, true)
	draw_rect(Rect2(u_left - 3.0, u_top - 5.0, u_inner_l - u_left + 6.0, 8.0), Color(1.0, 0.3, 0.3))
	draw_rect(Rect2(u_inner_r - 3.0, u_top - 5.0, u_right - u_inner_r + 6.0, 8.0), Color(0.3, 0.3, 1.0))
	var orbit_r: float = r * 0.65
	for i in range(5):
		var a: float = _pulse_phase * 1.2 + i * TAU / 5.0
		var p := Vector2.RIGHT.rotated(a) * orbit_r
		var alpha: float = 0.3 + 0.3 * absf(sin(a))
		draw_circle(p, 2.5, Color(col.r, col.g, col.b, alpha))
	draw_circle(Vector2.ZERO, 3.0, Color(col.r, col.g, col.b, 0.5))

func _process(delta: float) -> void:
	if _is_collected:
		return
	if is_in_group("magnet_skip"):
		return

	_pulse_phase += delta * 4.0
	queue_redraw()

	if not is_instance_valid(_player_ref):
		_player_ref = GameManager.get_player()
		if not is_instance_valid(_player_ref):
			return

	var dist := global_position.distance_to(_player_ref.global_position)
	var pickup_range: float = 100.0
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
		var speed: float = 300.0 * (0.5 + speed_factor * 1.5)
		if _mega_magnet:
			speed = maxf(speed, 500.0)
		if dist < 50.0:
			speed = maxf(speed, 600.0)
		_velocity = direction * speed
		global_position += _velocity * delta
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, 100.0 * delta)
		global_position += _velocity * delta

func activate_mega_magnet() -> void:
	_mega_magnet = true
	_is_magnetized = true

func _deactivate_mega_magnet() -> void:
	_mega_magnet = false
