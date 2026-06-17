class_name PickupData extends Resource

enum PickupType { EXPERIENCE_ORB, HEART, POWER_UP }

@export var pickup_type: PickupType = PickupType.EXPERIENCE_ORB
@export var value: float = 1.0
@export var sprite_texture: Texture2D
@export var magnet_range: float = 100.0
@export var magnet_speed: float = 300.0
@export var pool_name: StringName = &"Pickup"
