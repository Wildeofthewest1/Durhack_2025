extends Node
class_name InteractionFleetController

## UI controller for assigning drones to guard different bodies (planets, stations, etc.)
## Works with the DroneManager autoload

@export var fleet_list: ItemList
@export var assign_button: Button

var _planet: Node = null

func _ready() -> void:
	if assign_button != null:
		assign_button.pressed.connect(_on_assign_pressed)

func setup_for_planet(planet: Node) -> void:
	_planet = planet
	refresh()

func refresh() -> void:
	if fleet_list == null:
		return
	
	fleet_list.clear()
	
	# Get all active drones from DroneManager
	var drones: Array = DroneManager.get_active_drones()
	
	for drone in drones:
		if drone == null or not is_instance_valid(drone):
			fleet_list.add_item("Invalid drone...")
			continue
		
		# Get drone info
		var drone_info: Dictionary = drone.get_drone_info()
		var drone_name: String = drone_info.get("name", "Unknown Drone")
		
		# Get what it's following
		var follow_name: String = "None"
		if drone.follow_body != null and is_instance_valid(drone.follow_body):
			follow_name = String(drone.follow_body.name)
		
		# Create label with drone type and health
		var health: int = drone_info.get("health", 0)
		var max_health: int = drone_info.get("max_health", 1)
		var label: String = "%s [%d/%d HP] (guarding: %s)" % [drone_name, health, max_health, follow_name]
		fleet_list.add_item(label)

func _on_assign_pressed() -> void:
	if _planet == null or not is_instance_valid(_planet):
		return
	
	if fleet_list == null:
		return
	
	var selected: PackedInt32Array = fleet_list.get_selected_items()
	if selected.is_empty():
		return
	
	var idx: int = int(selected[0])
	var drones: Array = DroneManager.get_active_drones()
	
	if idx < 0 or idx >= drones.size():
		return
	
	var drone: Node2D = drones[idx] as Node2D
	if drone == null or not is_instance_valid(drone):
		return
	
	# Get player reference - adjust this path to match your game structure
	var player: Node2D = get_node_or_null("/root/Player")
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	
	if player == null:
		push_warning("[InteractionFleetController] Could not find player to assign drones to")
		return
	
	# Toggle between guarding planet and guarding player
	if drone.follow_body == _planet:
		# Switch to guarding player
		drone.follow_body = player
		# Release old slot and assign new slot
		DroneManager.release_slot(drone, _planet)
		drone.slot_index = DroneManager.assign_slot(drone, player)
		print("[InteractionFleetController] Assigned %s to guard player" % drone.name)
	else:
		# Switch to guarding planet
		var old_body: Node2D = drone.follow_body
		drone.follow_body = _planet
		# Release old slot and assign new slot
		if old_body != null:
			DroneManager.release_slot(drone, old_body)
		drone.slot_index = DroneManager.assign_slot(drone, _planet)
		print("[InteractionFleetController] Assigned %s to guard %s" % [drone.name, _planet.name])
	
	refresh()
