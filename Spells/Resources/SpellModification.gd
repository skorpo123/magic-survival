class_name SpellModification extends Resource

enum ModType { HOMING, SPLIT, CHAIN, EXPLODE, PIERCE_BOOST, SPEED_BOOST, AREA_BOOST, ON_KILL_EXPLODE, INSTANT_KILL, TICK_RATE }

@export var mod_name: String = "Modification"
@export var mod_id: StringName = &""
@export var mod_type: ModType = ModType.HOMING
@export var icon: Texture2D
@export var description: String = ""
@export var color_tint: Color = Color.WHITE

@export_group("Homing")
@export var homing_strength: float = 4.5

@export_group("Split")
@export var split_count: int = 3
@export var split_angle_spread: float = 0.5

@export_group("Chain")
@export var chain_count: int = 3
@export var chain_range: float = 150.0
@export var chain_damage_mult: float = 0.5

@export_group("Explode")
@export var explosion_radius_mult: float = 2.0

@export_group("Stat Boosts")
@export var damage_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
@export var pierce_add: int = 0
@export var speed_multiplier: float = 1.0
@export var projectile_count_add: int = 0

@export_group("Orbit")
@export var orbit_radius_mult: float = 1.0
@export var orbit_speed_mult: float = 1.0

@export_group("Zone")
@export var zone_radius_mult: float = 1.0
@export var damage_interval_mult: float = 1.0

@export_group("Lightning")
@export var chain_count_add: int = 0

@export_group("On Kill Explode")
@export var on_kill_explode_chance: float = 0.15
@export var on_kill_explode_radius: float = 80.0
@export var on_kill_explode_damage: float = 15.0

@export_group("Instant Kill")
@export var instant_kill_chance: float = 0.08
