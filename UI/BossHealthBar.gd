class_name BossHealthBar extends Control

const BAR_WIDTH := 320.0
const BAR_HEIGHT := 8.0
const NAME_HEIGHT := 20.0
const HP_COLOR := Color(0.85, 0.15, 0.2, 0.9)
const HP_LOW_COLOR := Color(0.95, 0.35, 0.15, 0.95)
const BG_COLOR := Color(0.03, 0.02, 0.06, 0.85)

var _hp_bar: ColorRect
var _hp_low_bar: ColorRect
var _name_label: Label
var _pulse_t: float = 0.0
var _boss_name: StringName = &""
var _current_hp: float = 0.0
var _max_hp: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_top = 50.0
	offset_left = -BAR_WIDTH * 0.5
	offset_right = BAR_WIDTH * 0.5
	offset_bottom = 50.0 + NAME_HEIGHT + BAR_HEIGHT + 4.0
	custom_minimum_size = Vector2(BAR_WIDTH, NAME_HEIGHT + BAR_HEIGHT + 4.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", SettingsManager.font_size(14))
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.35, 0.95))
	_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_name_label.add_theme_constant_override("outline_size", 2)
	_name_label.custom_minimum_size.y = NAME_HEIGHT
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)

	var bar_center := CenterContainer.new()
	bar_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bar_center)

	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_center.add_child(wrapper)

	_hp_low_bar = ColorRect.new()
	_hp_low_bar.name = "HpLow"
	_hp_low_bar.color = HP_LOW_COLOR
	_hp_low_bar.offset_left = 0.0
	_hp_low_bar.offset_top = 0.0
	_hp_low_bar.offset_right = BAR_WIDTH
	_hp_low_bar.offset_bottom = BAR_HEIGHT
	_hp_low_bar.z_index = 1
	wrapper.add_child(_hp_low_bar)

	_hp_bar = ColorRect.new()
	_hp_bar.name = "Hp"
	_hp_bar.color = HP_COLOR
	_hp_bar.offset_left = 0.0
	_hp_bar.offset_top = 0.0
	_hp_bar.offset_right = BAR_WIDTH
	_hp_bar.offset_bottom = BAR_HEIGHT
	_hp_bar.z_index = 2
	wrapper.add_child(_hp_bar)

	visible = false

const BOSS_NAME_KEYS := {
	&"Volt Sentinel": &"boss_name_volt_sentinel",
	&"Blast Architect": &"boss_name_blast_architect",
	&"Iron Titan": &"boss_name_iron_titan",
	&"Fury Monarch": &"boss_name_fury_monarch",
	&"Abyss Warden": &"boss_name_abyss_warden",
}

func setup(boss_name: StringName, max_hp: float) -> void:
	_boss_name = boss_name
	_max_hp = max_hp
	_current_hp = max_hp
	var key: StringName = BOSS_NAME_KEYS.get(boss_name, &"")
	if key != &"":
		_name_label.text = SettingsManager.t(key)
	else:
		_name_label.text = String(boss_name)
	_update_bar()
	visible = true
	modulate.a = 1.0

func update_hp(current: float, max_val: float) -> void:
	_current_hp = current
	_max_hp = max_val
	_update_bar()

func _process(_delta: float) -> void:
	if visible and not (GameManager.current_state == GameManager.GameState.PLAYING or GameManager.current_state == GameManager.GameState.BOSS_FIGHT):
		visible = false
	elif not visible and (GameManager.current_state == GameManager.GameState.PLAYING or GameManager.current_state == GameManager.GameState.BOSS_FIGHT) and _max_hp > 0.0:
		visible = true

func _update_bar() -> void:
	if _max_hp <= 0.0:
		return
	var ratio := clampf(_current_hp / _max_hp, 0.0, 1.0)
	_hp_bar.offset_right = BAR_WIDTH * ratio
	_hp_low_bar.offset_right = BAR_WIDTH * ratio

	if ratio <= 0.3:
		_pulse_t += get_process_delta_time() * 4.0
		var p := 0.85 + 0.15 * sin(_pulse_t)
		_hp_bar.color = Color(HP_LOW_COLOR.r * p, HP_LOW_COLOR.g * p, HP_LOW_COLOR.b, HP_LOW_COLOR.a)
	else:
		_hp_bar.color = HP_COLOR

func dismiss() -> void:
	visible = false
	_boss_name = &""
	_current_hp = 0.0
	_max_hp = 0.0
