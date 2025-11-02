extends Node


# List of all drones the player currently owns/controls.
var drones: Array[DroneFollower] = []

func register_drone(dr: DroneFollower) -> void:
	if drones.has(dr) == false:
		drones.append(dr)

func unregister_drone(dr: DroneFollower) -> void:
	if drones.has(dr):
		drones.erase(dr)

func get_drones() -> Array[DroneFollower]:
	return drones
