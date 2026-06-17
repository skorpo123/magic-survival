extends Node

const CLASS_COST: int = 500
const SAVE_PATH: String = "user://characters.save"

var _unlocked: Array[StringName] = []
var _selected_class_id: StringName = &""

var _classes: Array[Dictionary] = [
	{
		"id": &"arcanist",
		"name_key": &"class_arcanist",
		"desc_key": &"class_arcanist_desc",
		"spell_id": &"magic_bolt",
		"icon_color": Color(0.6, 0.4, 0.9),
		"bonuses": [
			{"stat": "projectile_count", "value": 1, "type": "add"},
			{"stat": "cooldown_reduction", "value": 0.10, "type": "mult"},
		]
	},
	{
		"id": &"pyromancer",
		"name_key": &"class_pyromancer",
		"desc_key": &"class_pyromancer_desc",
		"spell_id": &"fireball",
		"icon_color": Color(0.9, 0.5, 0.1),
		"bonuses": [
			{"stat": "damage", "value": 0.20, "type": "mult"},
			{"stat": "area", "value": 0.15, "type": "mult"},
		]
	},
	{
		"id": &"orbiter",
		"name_key": &"class_orbiter",
		"desc_key": &"class_orbiter_desc",
		"spell_id": &"orbiting_arcana",
		"icon_color": Color(0.3, 0.5, 0.9),
		"bonuses": [
			{"stat": "projectile_count", "value": 1, "type": "add"},
			{"stat": "damage", "value": 0.10, "type": "mult"},
		]
	},
	{
		"id": &"stormcaller",
		"name_key": &"class_stormcaller",
		"desc_key": &"class_stormcaller_desc",
		"spell_id": &"lightning_strike",
		"icon_color": Color(0.4, 0.8, 1.0),
		"bonuses": [
			{"stat": "damage", "value": 0.25, "type": "mult"},
			{"stat": "cooldown_reduction", "value": 0.15, "type": "mult"},
		]
	},
	{
		"id": &"typhoon",
		"name_key": &"class_typhoon",
		"desc_key": &"class_typhoon_desc",
		"spell_id": &"cyclone",
		"icon_color": Color(0.2, 0.8, 0.7),
		"bonuses": [
			{"stat": "damage", "value": 0.10, "type": "mult"},
			{"stat": "duration", "value": 0.20, "type": "mult"},
		]
	},
	{
		"id": &"raycaster",
		"name_key": &"class_raycaster",
		"desc_key": &"class_raycaster_desc",
		"spell_id": &"arcane_ray",
		"icon_color": Color(0.9, 0.85, 0.3),
		"bonuses": [
			{"stat": "damage", "value": 0.20, "type": "mult"},
			{"stat": "width", "value": 0.10, "type": "mult"},
		]
	},
	{
		"id": &"electromant",
		"name_key": &"class_electromant",
		"desc_key": &"class_electromant_desc",
		"spell_id": &"electric_zone",
		"icon_color": Color(0.1, 0.6, 1.0),
		"bonuses": [
			{"stat": "damage", "value": 0.15, "type": "mult"},
			{"stat": "area", "value": 0.25, "type": "mult"},
		]
	},
	{
		"id": &"spiritcaller",
		"name_key": &"class_spiritcaller",
		"desc_key": &"class_spiritcaller_desc",
		"spell_id": &"spirit",
		"icon_color": Color(0.7, 0.7, 0.8),
		"bonuses": [
			{"stat": "projectile_count", "value": 1, "type": "add"},
			{"stat": "damage", "value": 0.10, "type": "mult"},
		]
	},
	{
		"id": &"guardian",
		"name_key": &"class_guardian",
		"desc_key": &"class_guardian_desc",
		"spell_id": &"shield",
		"icon_color": Color(0.85, 0.75, 0.3),
		"bonuses": [
			{"stat": "shield_hp", "value": 0.20, "type": "mult"},
			{"stat": "extra_spell", "value": &"magic_bolt", "type": "spell"},
		]
	},
	{
		"id": &"breathweaver",
		"name_key": &"class_breathweaver",
		"desc_key": &"class_breathweaver_desc",
		"spell_id": &"fire_breath",
		"icon_color": Color(0.9, 0.2, 0.1),
		"bonuses": [
			{"stat": "damage", "value": 0.15, "type": "mult"},
			{"stat": "duration", "value": 0.20, "type": "mult"},
		]
	},
	{
		"id": &"needlemancer",
		"name_key": &"class_needlemancer",
		"desc_key": &"class_needlemancer_desc",
		"spell_id": &"needle",
		"icon_color": Color(0.3, 0.8, 0.4),
		"bonuses": [
			{"stat": "projectile_count", "value": 1, "type": "add"},
			{"stat": "damage", "value": 0.20, "type": "mult"},
		]
	},
	{
		"id": &"venomist",
		"name_key": &"class_venomist",
		"desc_key": &"class_venomist_desc",
		"spell_id": &"poison_pool",
		"icon_color": Color(0.5, 0.8, 0.2),
		"bonuses": [
			{"stat": "area", "value": 0.25, "type": "mult"},
			{"stat": "damage", "value": 0.15, "type": "mult"},
		]
	},
	{
		"id": &"frostcall",
		"name_key": &"class_frostcall",
		"desc_key": &"class_frostcall_desc",
		"spell_id": &"frost_nova",
		"icon_color": Color(0.4, 0.7, 1.0),
		"bonuses": [
			{"stat": "damage", "value": 0.20, "type": "mult"},
			{"stat": "area", "value": 0.15, "type": "mult"},
		]
	},
]

func _ready() -> void:
	_load()

func get_all_classes() -> Array[Dictionary]:
	return _classes

func get_class_by_id(class_id: StringName) -> Dictionary:
	for c in _classes:
		if c.id == class_id:
			return c
	return {}

func is_unlocked(class_id: StringName) -> bool:
	return class_id in _unlocked

func get_unlocked_count() -> int:
	return _unlocked.size()

func get_locked_classes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in _classes:
		if not c.id in _unlocked:
			result.append(c)
	return result

func can_unlock() -> bool:
	return get_locked_classes().size() > 0 and UpgradeManager.persistent_currency >= CLASS_COST

func try_unlock_random() -> Dictionary:
	var locked := get_locked_classes()
	if locked.is_empty():
		return {}
	if UpgradeManager.persistent_currency < CLASS_COST:
		return {}
	UpgradeManager.persistent_currency -= CLASS_COST
	UpgradeManager._save()
	var idx := randi() % locked.size()
	var opened: Dictionary = locked[idx]
	_unlocked.append(opened.id)
	save()
	return opened

func select_class(class_id: StringName) -> void:
	_selected_class_id = class_id

func get_selected_class() -> Dictionary:
	return get_class_by_id(_selected_class_id)

func save() -> void:
	var data := {
		"unlocked": [],
	}
	for id in _unlocked:
		data.unlocked.append(String(id))
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_unlocked = [&"arcanist"]
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_unlocked = [&"arcanist"]
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		_unlocked = [&"arcanist"]
		return
	var data: Dictionary = json.data
	_unlocked = []
	for id in data.get("unlocked", []):
		_unlocked.append(StringName(id))
	if _unlocked.is_empty():
		_unlocked = [&"arcanist"]
