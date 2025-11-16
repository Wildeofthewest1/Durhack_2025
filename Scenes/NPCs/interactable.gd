extends Area2D
class_name Interactable

signal interaction_started(interactable: Interactable)
signal interaction_ended(interactable: Interactable)

@export var interaction_name: String = "Unknown"
@export var interaction_sprite: Texture2D
@export var interaction_range: float = 150.0
@export var can_interact: bool = true

# Type of interactable (ship, station, planet, enemy)
@export_enum("Ship", "Station", "Planet", "Enemy", "Object") var interactable_type: String = "Object"

# Dialogue data for talk interactions
@export var has_dialogue: bool = false
@export var dialogue_start_node: String = "start"

# Custom interaction data
var custom_data: Dictionary = {}

func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 0
	collision_mask = 0
	monitoring = true
	monitorable = true

func get_interaction_name() -> String:
	return interaction_name

func get_interaction_sprite() -> Texture2D:
	return interaction_sprite

func get_interactable_type() -> String:
	return interactable_type

func can_be_interacted() -> bool:
	return can_interact

# Override this in child classes for custom interaction logic
func on_interact(player: Node) -> void:
	interaction_started.emit(self)

# Override this for when interaction ends
func on_interaction_end(player: Node) -> void:
	interaction_ended.emit(self)

# For dialogue system
func get_dialogue_data() -> Dictionary:
	return custom_data.get("dialogue", {})

func set_dialogue_data(data: Dictionary) -> void:
	custom_data["dialogue"] = data
	has_dialogue = not data.is_empty()
