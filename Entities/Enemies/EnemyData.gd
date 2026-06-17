class_name EnemyData extends Resource

enum EnemyClass { SMALL_FAST, MEDIUM, BIG_TANK, MINE, OVERLORD, RAMPAGE }

@export var enemy_name: String = "Enemy"
@export var enemy_class: EnemyClass = EnemyClass.MEDIUM
@export var scene: PackedScene

@export_group("Stats")
@export var max_hp: float = 20.0
@export var speed: float = 100.0
@export var damage: float = 10.0
@export var xp_value: float = 2.0
@export var collision_radius: float = 16.0

@export_group("Steering")
@export var seek_weight: float = 1.0
@export var separation_weight: float = 1.5
@export var separation_radius: float = 30.0
@export var avoid_player_radius: float = 25.0

@export_group("Small Fast Specific")
@export var explodes_on_contact: bool = false
@export var explosion_damage: float = 15.0

@export_group("Big Tank Specific")
@export var cannot_be_pushed: bool = false
@export var pushback_force: float = 0.0

@export_group("Mine Specific")
@export var mine_explosion_radius: float = 80.0
@export var mine_trigger_radius: float = 40.0
@export var mine_fuse_time: float = 0.8

@export_group("Overlord Specific")
@export var overlord_buff_radius: float = 150.0
@export var overlord_buff_speed_mult: float = 1.3
@export var overlord_buff_damage_mult: float = 1.5

@export_group("Rampage Specific")
@export var rampage_speed_mult: float = 3.0
@export var rampage_enrage_duration: float = 2.0

@export_group("Pooling")
@export var pool_name: StringName = &"Enemy"
@export var pool_initial_size: int = 100

@export_group("Visual")
@export var sprite_texture: Texture2D
@export var sprite_scale: Vector2 = Vector2.ONE
@export var modulate_color: Color = Color.WHITE
