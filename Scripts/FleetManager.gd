extends Node

# List of all drones the player currently owns/controls.
var drones: Array[DroneFollower] = []

# Path to the drone scene so FleetManager can respawn it
@export var drone_scene: PackedScene = preload("res://Scenes/Fleet/fleet_2.tscn")


func register_drone(dr: DroneFollower) -> void:
	if not drones.has(dr):
		drones.append(dr)


func unregister_drone(dr: DroneFollower) -> void:
	if drones.has(dr):
		drones.erase(dr)


func get_drones() -> Array[DroneFollower]:
	return drones


# =========================================================
# 💫 Drone Respawn Logic
# =========================================================
func respawn_drone(position: Vector2, follow_target: Node2D, delay: float = 5.0) -> void:
	print("⏳ Drone will respawn in %.1f seconds..." % delay)
	var timer := get_tree().create_timer(delay)

	timer.timeout.connect(func():
		if drone_scene == null:
			push_error("❌ No drone scene assigned in FleetManager!")
			return

		var new_drone: DroneFollower = drone_scene.instantiate()
		new_drone.global_position = position
		new_drone.follow_body = follow_target

		# Reparent into the Fleet node (assumed to exist under Game)
		var fleet_node = get_tree().get_root().get_node("Main/SubViewportContainer/SubViewport/Game/Fleet")
		if fleet_node:
			fleet_node.add_child(new_drone)
		else:
			get_tree().get_current_scene().add_child(new_drone)

		register_drone(new_drone)
		print("✅ Drone respawned at", position)
	)
