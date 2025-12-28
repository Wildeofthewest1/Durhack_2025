extends Control
class_name FleetPage

@export var fleet_list: ItemList
@export var assign_selected_button: Button

var _planet: PlanetNPC = null

func _ready() -> void:
	if assign_selected_button != null:
		assign_selected_button.pressed.connect(_on_assign_pressed)

func set_planet(planet: PlanetNPC) -> void:
	_planet = planet
	refresh()

func refresh() -> void:
	if fleet_list == null:
		return

	fleet_list.clear()

	var drones: Array[DroneFollower] = FleetManager.get_drones()
	for dr in drones:
		if dr == null or is_instance_valid(dr) == false:
			fleet_list.add_item("Respawning drone...")
			continue

		var follow_name: String = "None"
		if dr.follow_body != null and is_instance_valid(dr.follow_body):
			follow_name = dr.follow_body.name

		var label: String = dr.drone_name + " (guarding: " + follow_name + ")"
		fleet_list.add_item(label)

func _on_assign_pressed() -> void:
	if _planet == null:
		return
	if fleet_list == null:
		return

	var selected: PackedInt32Array = fleet_list.get_selected_items()
	if selected.size() == 0:
		return

	var idx: int = selected[0]
	var drones: Array[DroneFollower] = FleetManager.get_drones()

	if idx < 0 or idx >= drones.size():
		return

	var drone: DroneFollower = drones[idx]
	if drone == null or is_instance_valid(drone) == false:
		return

	if drone.follow_body == _planet:
		drone.follow_body = FleetManager.player
	else:
		drone.follow_body = _planet

	refresh()
