# WeaponData.gd
extends Resource
class_name WeaponData

@export_category("UI")
@export var display_name: String = "Pistol"
@export var icon: Texture2D

@export_category("Scenes")
@export var weapon_scene: PackedScene        # scene of the held weapon
@export var bullet_scene: PackedScene        # projectile scene
@export var flash_scene: PackedScene         # muzzle flash

@export_category("Firing")
@export var fire_cooldown: float = 0.25      # seconds between shots
@export var automatic: bool = false
@export var bullets_per_shot: int = 1
@export var spread_deg: float = 4.0

@export_category("Damage")
@export var damage: float = 10.0
@export var muzzle_velocity: float = 800.0

@export_category("Reload")
@export var max_magazine: int = 12           # magazine size only
@export var reload_time: float = 1.2         # seconds

@export_category("Meta")
@export var slot_hint: int = 0
@export var weapon_type: String = "ballistic"
