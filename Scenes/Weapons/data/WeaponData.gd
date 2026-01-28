# WeaponData.gd
extends Resource
class_name WeaponData

enum AmmoModel {
	STANDARD = 0,             # banks mags in background
	INFINITE_WITH_RELOAD = 1  # pistol option B
}

@export var id: StringName = &""

@export_category("UI")
@export var display_name: String = "Pistol"
@export var icon: Texture2D

@export_category("Scenes")
@export var weapon_scene: PackedScene
@export var bullet_scene: PackedScene
@export var flash_scene: PackedScene

@export_category("Firing")
@export var fire_cooldown: float = 0.25
@export var automatic: bool = true
@export var bullets_per_shot: int = 1

# NOTE:
# WeaponBase now treats accuracy as spread control.
# It uses spread_rad internally; keep spread_deg for editor convenience.
@export var spread_deg: float = 4.0
@export var spread_rad: float = deg_to_rad(4.0) # base half-angle spread in radians

@export_category("Damage")
@export var damage: float = 10.0
@export var muzzle_velocity: float = 800.0
@export var knockback: float = 100.0

@export_category("Reload")
@export var max_magazine: int = 12
@export var reload_time: float = 1.2

@export_category("Passive Mag Regen (STANDARD only)")
@export var mag_regen_time: float = 2.5
@export var max_stored_mags: int = 3
@export var use_stored_for_instant_reload: bool = true

@export_category("Meta")
@export var slot_hint: int = 0
@export var weapon_type: String = "ballistic"
@export var ammo_model: AmmoModel = AmmoModel.STANDARD

func _validate_property(property: Dictionary) -> void:
	# Keep spread_deg and spread_rad in sync when editing in inspector.
	# Godot will call this in the editor; runtime is fine too.
	if property.has("name") and String(property["name"]) == "spread_deg":
		spread_rad = deg_to_rad(spread_deg)
	elif property.has("name") and String(property["name"]) == "spread_rad":
		spread_deg = rad_to_deg(spread_rad)
