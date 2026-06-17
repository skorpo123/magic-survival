extends Node

var _shake_end_msec: int = 0
var _shake_intensity: float = 0.0
var _hitstop_end_msec: int = 0
var _flash_overlay: ColorRect = null
var _flash_tween: Tween = null
var _cached_cam: Camera2D = null
var _cam_frame: int = -1
var _idle: bool = true
var _spark_active_count: int = 0
var _pending_shake_intensity: float = 0.0

const MAX_SPARKS: int = 32
const SPARK_DURATION: float = 0.25
var _spark_data: PackedFloat32Array = PackedFloat32Array()
var _spark_alive: PackedInt32Array = PackedInt32Array()
var _spark_colors: PackedFloat32Array = PackedFloat32Array()
var _spark_node: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_level_up.connect(_on_player_level_up)
	EventBus.game_started.connect(_on_game_started)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	_create_flash_overlay()
	call_deferred("_init_spark_pool")

func _init_spark_pool() -> void:
	_spark_data.resize(MAX_SPARKS * 4)
	_spark_alive.resize(MAX_SPARKS)
	_spark_colors.resize(MAX_SPARKS * 4)
	_spark_node = Node2D.new()
	_spark_node.z_index = 6
	_spark_node.visible = false
	_spark_node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_spark_node)
	_spark_node.set_script(preload("res://Systems/SparkCanvas.gd"))
	_spark_node._owner = self
	for i in range(MAX_SPARKS):
		_spark_alive[i] = 0

func _create_flash_overlay() -> void:
	await get_tree().process_frame
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	if get_tree().current_scene:
		get_tree().current_scene.add_child(canvas)
	_flash_overlay = ColorRect.new()
	_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.color = Color(1, 0.2, 0.15, 0.0)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_flash_overlay)

func _on_game_started() -> void:
	_cached_cam = null
	_cam_frame = -1
	_idle = true

func _get_camera() -> Camera2D:
	var f: int = Engine.get_process_frames()
	if f == _cam_frame and _cached_cam and is_instance_valid(_cached_cam):
		return _cached_cam
	var player := GameManager.get_player()
	if player:
		_cached_cam = player.get_node_or_null("Camera2D") as Camera2D
	else:
		_cached_cam = null
	_cam_frame = f
	return _cached_cam

func _process(delta: float) -> void:
	if _pending_shake_intensity > 0.0:
		_apply_shake(_pending_shake_intensity, 0.1)
		_pending_shake_intensity = 0.0
	var now := Time.get_ticks_msec()
	var busy: bool = false

	if _hitstop_end_msec > 0:
		busy = true
		if now >= _hitstop_end_msec:
			Engine.time_scale = 1.0
			_hitstop_end_msec = 0

	if get_tree().paused:
		return

	if _shake_end_msec > 0:
		busy = true
		if now < _shake_end_msec:
			var cam := _get_camera()
			if cam:
				var mult := SettingsManager.get_screen_shake() / 100.0
				if mult <= 0.0:
					cam.offset = Vector2.ZERO
					_shake_end_msec = 0
				else:
					cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_intensity * mult
		else:
			_shake_end_msec = 0
			var cam := _get_camera()
			if cam:
				cam.offset = Vector2.ZERO

	_update_sparks(delta)
	if _spark_active_count > 0:
		busy = true

	if not busy:
		if _idle:
			return
		if _hitstop_end_msec <= 0 and _shake_end_msec <= 0:
			_idle = true

func _update_sparks(delta: float) -> void:
	var any_alive: bool = false
	for i in range(MAX_SPARKS):
		if _spark_alive[i] == 0:
			continue
		var off: int = i * 4
		_spark_data[off] += _spark_data[off + 2] * delta
		_spark_data[off + 1] += _spark_data[off + 3] * delta
		_spark_data[off + 3] *= 0.955
		_spark_data[off + 2] *= 0.955
		var coff: int = i * 4
		_spark_colors[coff + 3] -= delta * 4.0
		if _spark_colors[coff + 3] <= 0.0:
			_return_spark_by_idx(i)
		else:
			any_alive = true
	if any_alive and _spark_node:
		_spark_node.visible = true
		_spark_node.queue_redraw()
	elif _spark_node:
		_spark_node.visible = false

func _emit_sparks(pos: Vector2, count: int, color: Color, speed_min: float, speed_max: float, _duration: float) -> void:
	for i in range(count):
		var found: bool = false
		for j in range(MAX_SPARKS):
			if _spark_alive[j] == 0:
				var off: int = j * 4
				_spark_data[off] = pos.x
				_spark_data[off + 1] = pos.y
				var angle: float = randf() * TAU
				var speed: float = randf_range(speed_min, speed_max)
				_spark_data[off + 2] = cos(angle) * speed
				_spark_data[off + 3] = sin(angle) * speed
				_spark_alive[j] = 1
				_spark_active_count += 1
				var coff: int = j * 4
				_spark_colors[coff] = color.r
				_spark_colors[coff + 1] = color.g
				_spark_colors[coff + 2] = color.b
				_spark_colors[coff + 3] = 0.8
				_idle = false
				found = true
				break
		if not found:
			break

func _return_spark_by_idx(idx: int) -> void:
	if _spark_alive[idx] != 0:
		_spark_active_count -= 1
	_spark_alive[idx] = 0

func screen_shake(intensity: float = 5.0, duration_sec: float = 0.15) -> void:
	ActionProfiler.probe("vfx", "screen_shake")
	_apply_shake(intensity, duration_sec)

func _apply_shake(intensity: float, duration_sec: float) -> void:
	var mult := SettingsManager.get_screen_shake() / 100.0
	if mult <= 0.0:
		_shake_intensity = 0.0
		_shake_end_msec = 0
		var cam := _get_camera()
		if cam:
			cam.offset = Vector2.ZERO
		return
	var new_intensity := intensity * mult
	if new_intensity > _shake_intensity:
		_shake_intensity = new_intensity
	var new_end := Time.get_ticks_msec() + int(duration_sec * 1000.0)
	if new_end > _shake_end_msec:
		_shake_end_msec = new_end
	_idle = false

func hitstop(duration_sec: float = 0.05) -> void:
	ActionProfiler.probe("vfx", "hitstop")
	Engine.time_scale = 0.001
	_hitstop_end_msec = Time.get_ticks_msec() + int(duration_sec * 1000.0)
	_idle = false

func screen_flash(color: Color = Color(1, 0.2, 0.15, 0.35), duration: float = 0.15) -> void:
	if not _flash_overlay:
		return
	_flash_overlay.color = color
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = _flash_overlay.create_tween()
	_flash_tween.tween_property(_flash_overlay, "color:a", 0.0, duration).set_ease(Tween.EASE_IN)

func spawn_death_effect(pos: Vector2, color: Color = Color.WHITE, enemy_type: String = "small", _damage_type: StringName = &"") -> void:
	BurstEffectPool.spawn(enemy_type, pos, color)

func spawn_explosion_visual(pos: Vector2, radius: float, color: Color = Color(1.0, 0.6, 0.2)) -> void:
	var scale_mult: float = clampf(radius / 50.0, 0.3, 5.0)
	BurstEffectPool.spawn("explosion", pos, color, scale_mult)

func _on_player_damaged(_amount: float, _source: Node2D) -> void:
	screen_shake(8.0, 0.14)
	hitstop(0.06)
	screen_flash(Color(1, 0.15, 0.1, 0.35), 0.18)

func _on_enemy_died(_pos: Vector2, _xp: float, _type: StringName) -> void:
	_pending_shake_intensity = minf(_pending_shake_intensity + 2.6, 12.0)

func _on_player_level_up(_new_level: int) -> void:
	screen_flash(Color(0.6, 0.4, 1.0, 0.2), 0.25)
	var player := GameManager.get_player()
	if player:
		VFXManager.register("level_up", player.global_position, 0.7)

func _on_boss_defeated(_boss_name: String, pos: Vector2) -> void:
	screen_shake(12.0, 0.25)
	screen_flash(Color(1.0, 0.6, 0.2, 0.3), 0.3)
	var shockwave := BossShockwave.new()
	add_child(shockwave)
	shockwave.play(pos)

func spawn_xp_sparkle(pos: Vector2) -> void:
	_emit_sparks(pos, 4, Color(0.5, 0.8, 1.0, 0.8), 60.0, 180.0, SPARK_DURATION)

func spawn_heal_flash(pos: Vector2) -> void:
	VFXManager.register("heal", pos, 0.45)

func spawn_bolt_hit(pos: Vector2, color: Color = Color(0.55, 0.8, 1.0)) -> void:
	BurstEffectPool.spawn("bolt", pos, color)

func spawn_fireball_explosion(pos: Vector2, radius: float) -> void:
	var scale_mult: float = clampf(radius / 40.0, 0.3, 5.0)
	BurstEffectPool.spawn("fireball", pos, Color(1.0, 0.55, 0.1), scale_mult)

func spawn_attack_flash(pos: Vector2, color: Color = Color(0.7, 0.5, 1.0)) -> void:
	BurstEffectPool.spawn("orbit", pos, color)
