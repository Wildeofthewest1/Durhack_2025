extends Resource
class_name DroneResource

## Defines a drone type with its properties and stat modifiers
## Integrates with the existing PlayerValues stat system

@export_group("Basic Info")
@export var drone_id: String = ""
@export var drone_display_name: String = "Drone"
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export_group("Appearance")
@export var sprite_texture: Texture2D = null
@export var base_color: Color = Color.WHITE
@export var scale: float = 1.0

@export_group("Base Stats")
@export var max_health: int = 200
@export var base_damage: float = 10.0
@export var base_speed: float = 300.0
@export var base_fire_rate: float = 1.0  # Shots per second (or rams per second for melee)
@export var base_accuracy: float = 1.0    # 0.0 to 1.0, affects spread
@export var base_defence: float = 0.0     # Flat damage reduction

@export_group("Behavior")
@export var behavior_script: GDScript = null  # The specific behavior script (OrbitDrone, MosquitoDrone, etc.) - Optional, for reference only
@export var weapon_scene: PackedScene = null

@export_group("Resource Costs")
@export var build_cost_metal: int = 100
@export var build_cost_energy: int = 50
@export var build_time: float = 10.0
@export var maintenance_cost: float = 1.0

func _init() -> void:
	pass

## Get total build cost
func get_total_build_cost() -> Dictionary:
	return {
		"metal": build_cost_metal,
		"energy": build_cost_energy,
		"time": build_time
	}
