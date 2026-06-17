extends Node2D

const FADE_WIDTH: float = 80.0
const RADIUS_SCREEN_MULT: float = 2.0

var _arena_active: bool = false
var _center: Vector2 = Vector2.ZERO
var _radius: float = 900.0

var _canvas_layer: CanvasLayer = null
var _overlay: ColorRect = null
var _shader_mat: ShaderMaterial = null

var _wall_root: Node2D = null

func _ready() -> void:
	_build_overlay()
	_build_wall()

	EventBus.boss_fight_started.connect(_on_boss_fight_started)
	EventBus.boss_fight_ended.connect(_on_boss_fight_ended)
	EventBus.game_started.connect(_on_game_started)

func _build_overlay() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 10
	add_child(_canvas_layer)

	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0, 0, 0, 1)
	_overlay.visible = false
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.offset_left = 0
	_overlay.offset_top = 0
	_overlay.offset_right = 0
	_overlay.offset_bottom = 0
	_canvas_layer.add_child(_overlay)

	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;

uniform vec2 arena_center_screen;
uniform float arena_radius_screen;
uniform float fade_width;

void fragment() {
	vec2 screen_uv = FRAGCOORD.xy;
	float dist = length(screen_uv - arena_center_screen);
	float inner_edge = arena_radius_screen - fade_width;
	float alpha = smoothstep(inner_edge, arena_radius_screen, dist);
	alpha = clamp(alpha * 0.95, 0.0, 0.95);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = sh
	_shader_mat.set_shader_parameter("fade_width", FADE_WIDTH)
	_overlay.material = _shader_mat

func _build_wall() -> void:
	_wall_root = Node2D.new()
	add_child(_wall_root)

func _rebuild_perimeter() -> void:
	for child in _wall_root.get_children():
		child.queue_free()
	var segments := 24
	var seg_angle := TAU / segments
	var seg_thickness: float = 12.0
	for i in range(segments):
		var angle := seg_angle * i
		var mid_angle := angle + seg_angle * 0.5
		var mid_pos := Vector2(cos(mid_angle), sin(mid_angle)) * _radius
		var seg_len := 2.0 * _radius * sin(seg_angle * 0.5) + 4.0
		var seg_body := StaticBody2D.new()
		seg_body.collision_layer = 1
		seg_body.collision_mask = 1
		seg_body.position = mid_pos
		seg_body.rotation = mid_angle
		var box := RectangleShape2D.new()
		box.size = Vector2(seg_len, seg_thickness)
		var col := CollisionShape2D.new()
		col.shape = box
		seg_body.add_child(col)
		_wall_root.add_child(seg_body)

func _on_game_started() -> void:
	deactivate()

func _on_boss_fight_started() -> void:
	var player := GameManager.get_player()
	if player:
		_center = player.global_position
	_compute_radius()
	activate(_center)

func _on_boss_fight_ended() -> void:
	if _arena_active:
		deactivate()

func _compute_radius() -> void:
	var vp := get_viewport_rect().size
	var player := GameManager.get_player()
	var cam_zoom := Vector2(1.5, 1.5)
	if player:
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam_zoom = cam.zoom
	var half_w := vp.x * 0.5 / cam_zoom.x
	var half_h := vp.y * 0.5 / cam_zoom.y
	_radius = maxf(half_w, half_h) * RADIUS_SCREEN_MULT
	_rebuild_perimeter()

func activate(center: Vector2) -> void:
	_center = center
	_arena_active = true
	_wall_root.global_position = _center
	_wall_root.visible = true
	_overlay.visible = true
	_update_shader()

func deactivate() -> void:
	_arena_active = false
	_overlay.visible = false
	_wall_root.visible = false

func _process(delta: float) -> void:
	if _arena_active:
		_clamp_player_to_arena()
		_update_shader()

func _clamp_player_to_arena() -> void:
	var player := GameManager.get_player()
	if not player:
		return
	var offset: Vector2 = player.global_position - _center
	var dist: float = offset.length()
	var limit: float = _radius - FADE_WIDTH * 0.5
	if dist > limit:
		player.global_position = _center + offset.normalized() * limit

func _update_shader() -> void:
	if not _shader_mat or not _arena_active:
		return
	var player := GameManager.get_player()
	if not player:
		return
	var vp := get_viewport_rect().size
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	var cam_zoom := Vector2(1.5, 1.5)
	if cam:
		cam_zoom = cam.zoom
	var world_to_screen := (_center - player.global_position) * cam_zoom + vp * 0.5
	var radius_screen := _radius * cam_zoom.x
	_shader_mat.set_shader_parameter("arena_center_screen", world_to_screen)
	_shader_mat.set_shader_parameter("arena_radius_screen", radius_screen)
