class_name LevelUpCard extends Resource

enum CardType { NEW_SPELL, SPELL_UPGRADE, SPELL_MODIFICATION, STAT_BOOST, SPELL_FUSION }
enum Rarity { COMMON, RARE, EPIC }

@export var card_type: CardType = CardType.NEW_SPELL
@export var title: String = "New Spell"
@export var description: String = ""
@export var icon: Texture2D
@export var rarity_color: Color = Color.WHITE
@export var rarity: Rarity = Rarity.COMMON

@export_group("New Spell")
@export var spell: Spell

@export_group("Spell Upgrade")
@export var spell_id: StringName = &""
@export var new_level: int = 1

@export_group("Spell Modification")
@export var modification: SpellModification

@export_group("Stat Boost")
@export var stat_name: StringName = &""
@export var stat_value: float = 0.0
@export var stat_level: int = 0
@export var stat_max_level: int = 5

@export_group("Spell Fusion")
@export var fusion_main_id: StringName = &""
@export var fusion_secondary_id: StringName = &""
@export var fusion_main_mod_id: StringName = &""
@export var fusion_secondary_mod_id: StringName = &""
@export var fusion_name: String = ""
