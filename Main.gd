extends Node2D

@onready var _main_menu: MainMenu = $UI/MainMenu
@onready var _game_over_screen: Control = $UI/GameOverScreen
@onready var _victory_screen: Control = $UI/VictoryScreen
@onready var _level_up_screen: Control = $UI/LevelUpScreen
@onready var _modification_screen: Control = $UI/ModificationScreen
@onready var _pause_menu: Control = $UI/PauseMenu
@onready var _artifact_screen: Control = $UI/ArtifactSelectScreen
@onready var _world_manager_mod: Node2D = $WorldManager

var _class_select_screen: CharacterSelectScreen = null
var _wave_manager: WaveManager = null
var _boss_arena: Node2D = null
var _color_filter: ColorRect = null
var _target_mod_color: Color = Color(1.0, 1.0, 1.0)
var _current_mod_color: Color = Color(1.0, 1.0, 1.0)
var _prev_phase_index: int = -1
var _transition_overlay: ColorRect = null

const PHASE_COLORS: PackedColorArray = [
	Color(1.00, 1.00, 1.00),
	Color(0.88, 0.92, 1.00),
	Color(0.90, 1.00, 0.85),
	Color(1.00, 0.92, 0.82),
	Color(1.00, 0.85, 0.80),
	Color(0.92, 0.85, 1.00),
	Color(0.85, 0.80, 0.92),
]

func _ready() -> void:
	EventBus.game_over.connect(_on_game_over)
	EventBus.victory.connect(_on_victory)
	_wave_manager = get_node_or_null("Systems/WaveManager")

	_class_select_screen = CharacterSelectScreen.new()
	_class_select_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_class_select_screen.visible = false
	$UI.add_child(_class_select_screen)

	_main_menu.play_pressed.connect(_on_play_pressed)
	_class_select_screen.back_requested.connect(_on_class_select_back)
	_class_select_screen.class_selected.connect(_on_class_selected)

	_transition_overlay = ColorRect.new()
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.color = Color(0, 0, 0, 1)
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.z_index = 200
	_transition_overlay.visible = false
	$UI.add_child(_transition_overlay)

	var boss_arena_script := preload("res://Systems/BossArena.gd")
	_boss_arena = Node2D.new()
	_boss_arena.set_script(boss_arena_script)
	_boss_arena.name = "BossArena"
	add_child(_boss_arena)

	_color_filter = $UI/ColorFilter as ColorRect

	_apply_saved_ui_scale()

func _process(delta: float) -> void:
	if GameManager.is_menu():
		var class_select_open: bool = _class_select_screen and _class_select_screen.visible
		if _main_menu:
			_main_menu.visible = not class_select_open
		if _class_select_screen and not class_select_open:
			pass
		if _game_over_screen and _game_over_screen.visible:
			_game_over_screen.visible = false
		if _victory_screen and _victory_screen.visible:
			_victory_screen.visible = false
		if _level_up_screen and _level_up_screen.visible:
			_level_up_screen.visible = false
		if _modification_screen and _modification_screen.visible:
			_modification_screen.visible = false
		if _pause_menu and _pause_menu.visible:
			_pause_menu.visible = false
		if _artifact_screen and _artifact_screen.visible:
			_artifact_screen.visible = false
		_target_mod_color = Color(1.0, 1.0, 1.0)
	if _color_filter:
		var overlay_visible: bool = (
			(_level_up_screen and _level_up_screen.visible)
			or (_modification_screen and _modification_screen.visible)
			or (_artifact_screen and _artifact_screen.visible)
			or (_pause_menu and _pause_menu.visible)
			or (_game_over_screen and _game_over_screen.visible)
			or (_victory_screen and _victory_screen.visible)
		)
		_color_filter.visible = not overlay_visible
	_update_ambient(delta)

func _on_play_pressed() -> void:
	_main_menu.visible = false
	_class_select_screen.show_screen()

func _on_class_select_back() -> void:
	_class_select_screen.hide_screen()
	_main_menu.visible = true

func _on_class_selected(class_data: Dictionary) -> void:
	_class_select_screen.hide_screen()
	_transition_overlay.visible = true
	_transition_overlay.color = Color(0, 0, 0, 1)
	GameManager.start_game(class_data)
	var t := create_tween()
	t.tween_property(_transition_overlay, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: _transition_overlay.visible = false)

func _update_ambient(delta: float) -> void:
	if not _world_manager_mod:
		return
	if GameManager.is_playing() and is_instance_valid(_wave_manager):
		var pi: int = _wave_manager._phase_index
		if pi != _prev_phase_index:
			_prev_phase_index = pi
			if pi >= 0 and pi < PHASE_COLORS.size():
				_target_mod_color = PHASE_COLORS[pi]
			elif pi >= PHASE_COLORS.size():
				_target_mod_color = PHASE_COLORS[PHASE_COLORS.size() - 1]
	_current_mod_color = _current_mod_color.lerp(_target_mod_color, delta * 1.5)
	_world_manager_mod.modulate = _current_mod_color

func _on_game_over() -> void:
	if _game_over_screen:
		if _game_over_screen.has_method("show_game_over"):
			_game_over_screen.show_game_over()
		else:
			_game_over_screen.visible = true

func _on_victory() -> void:
	if _victory_screen:
		_victory_screen.visible = true

func _apply_saved_ui_scale() -> void:
	pass
