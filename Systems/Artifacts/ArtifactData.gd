class_name ArtifactData extends Resource

@export var artifact_name: String = ""
@export var description: String = ""
@export var name_key: StringName = &""
@export var desc_key: StringName = &""
@export var icon: Texture2D
@export var rarity: int = ItemRarity.Tier.COMMON

@export var target_spell_name: StringName = &""
@export var target_spell_type: StringName = &""

# Explicit spell_id list (e.g. poison/spirit/physical/fusion groups that have no spell_type).
# When non-empty, matches only if the spell's spell_id is in this list.
@export var target_spell_ids: Array[StringName] = []

@export var bonuses: Array[ArtifactEffect] = []
@export var debuffs: Array[ArtifactEffect] = []
@export var extra_value: float = 0.0
