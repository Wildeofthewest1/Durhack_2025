extends Node
class_name InteractionFleetController

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

	var drones: Array = []
	if Engine.has_singleton("FleetManager"):
		drones = Engine.get_singleton("FleetManager").get_drones()
	elif has_node("/root/FleetManager"):
		drones = get_node("/root/FleetManager").get_drones()
	else:
		# Fall back to global class name access if you have it
		drones = FleetManager.get_drones()

	for dr in drones:
		if dr == null or not is_instance_valid(dr):
			fleet_list.add_item("Respawning drone...")
			continue

		var follow_name: String = "None"
		if dr.follow_body != null and is_instance_valid(dr.follow_body):
			follow_name = String(dr.follow_body.name)

		var label: String = String(dr.drone_name) + " (guarding: " + follow_name + ")"
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

	var drones: Array = FleetManager.get_drones()
	if idx < 0 or idx >= drones.size():
		return

	var drone: Object = drones[idx]
	if drone == null or not is_instance_valid(drone):
		return

	# Toggle between guarding planet and guarding player
	if drone.follow_body == _planet:
		drone.follow_body = FleetManager.player
	else:
		drone.follow_body = _planet

	refresh()
