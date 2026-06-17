class_name FusionSpell
extends Spell

@export var fusion_id: StringName = &""
@export var main_id: StringName = &""
@export var secondary_id: StringName = &""

func _init() -> void:
	max_level = 1
	current_level = 1
