extends Node

var spell_damage: Dictionary = {}
var total_damage_dealt: float = 0.0
var kills_by_type: Dictionary = {}
var max_combo: int = 0
var artifacts_collected: Array = []
var strongest_spell_id: StringName = &""
var strongest_spell_damage: float = 0.0
static var _active_spell_id: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.game_started.connect(_on_game_started)
	EventBus.combo_changed.connect(_on_combo_changed)

func _on_game_started() -> void:
	spell_damage.clear()
	total_damage_dealt = 0.0
	kills_by_type.clear()
	max_combo = 0
	artifacts_collected.clear()
	strongest_spell_id = &""
	strongest_spell_damage = 0.0
	_active_spell_id = &""

func set_current_spell(spell_id: StringName) -> void:
	_active_spell_id = spell_id

func record_damage(amount: float) -> void:
	if _active_spell_id == &"" or amount <= 0.0:
		return
	spell_damage[_active_spell_id] = spell_damage.get(_active_spell_id, 0.0) + amount
	total_damage_dealt += amount
	if spell_damage[_active_spell_id] > strongest_spell_damage:
		strongest_spell_damage = spell_damage[_active_spell_id]
		strongest_spell_id = _active_spell_id

func _on_enemy_died(_pos: Vector2, _xp: float, enemy_type: StringName) -> void:
	kills_by_type[enemy_type] = kills_by_type.get(enemy_type, 0) + 1

func _on_combo_changed(combo: int) -> void:
	if combo > max_combo:
		max_combo = combo

func snapshot_artifacts() -> void:
	artifacts_collected.clear()
	for art in ArtifactManager.equipped:
		artifacts_collected.append(art)

func get_spell_damage_percent(spell_id: StringName) -> float:
	if total_damage_dealt <= 0.0:
		return 0.0
	return spell_damage.get(spell_id, 0.0) / total_damage_dealt * 100.0

func get_total_kills() -> int:
	var total: int = 0
	for k in kills_by_type.values():
		total += k
	return total

func get_sorted_spell_damage() -> Array:
	var result: Array = []
	for spell_id in spell_damage:
		result.append({"id": spell_id, "damage": spell_damage[spell_id]})
	result.sort_custom(func(a, b): return a["damage"] > b["damage"])
	return result
