extends Node2D

# Path to the actual Fleet node in the game world
const FLEET_NODE_PATH := "Main/SubViewportContainer/SubViewport/Game/Fleet"

# Dictionary of drone types:  { "DroneName": PackedScene }
var drone_types: Dictionary = {}

# All active drones
var drones: Array[DroneFollower] = []

var respawning: Array = []   # each entry is a dictionary
var _uid_counter := 0        # used for unique drone IDs



@export var drone_directory: String = "res://Scenes/Fleet/"
@export var respawn_delay: float = 3.0

@export var player: CharacterBody2D

func _find_player() -> void:
	var root := get_tree().get_root()
	var path := "Main/SubViewportContainer/SubViewport/Game/PlayerContainer/Player"

	if root.has_node(path):
		player = root.get_node(path)
		print("🎯 Player found:", player.name)
	else:
		push_error("❌ Could not find player at: %s" % path)




func _ready() -> void:
	_find_player()      # find the player
	_scan_drone_scenes()
	_spawn_initial_drones()

# =========================================================
# 🔍 Scan folder for drone scenes
# =========================================================
func _scan_drone_scenes() -> void:
	var dir := DirAccess.open(drone_directory)
	if dir == null:
		push_error("❌ Couldn't open drone directory.")
		return

	dir.list_dir_begin()

	while true:
		var file := dir.get_next()
		if file == "":
			break

		if file.ends_with(".tscn"):
			var full_path := drone_directory + file
			var scene: PackedScene = load(full_path)

			if scene:
				var name := file.get_basename()
				drone_types[name] = scene
				print("🔹 Loaded drone type:", name)

	dir.list_dir_end()
	print("✅ Loaded %d drone types." % drone_types.size())



# =========================================================
# 📌 Register / Unregister
# =========================================================
func register_drone(dr: DroneFollower) -> void:
	if not drones.has(dr):
		drones.append(dr)

func unregister_drone(dr: DroneFollower) -> void:
	if drones.has(dr):
		drones.erase(dr)

func get_drones() -> Array[DroneFollower]:
	return drones

func drone_died(dr: DroneFollower) -> void:
	# find the index of this drone in the array
	var index := drones.find(dr)
	if index == -1:
		return  # shouldn't happen but safe

	# store exact respawn info for THIS drone
	var respawn_data := {
		"type": dr.drone_type,
		"pos": dr.global_position,
		"target": dr.follow_body,
		"index": index
	}

	respawning.append(respawn_data)

	# free the drone, but keep its array slot intact
	dr.queue_free()

	_respawn_after_delay(respawn_data)


func _respawn_after_delay(respawn_data: Dictionary) -> void:
	var timer := get_tree().create_timer(respawn_delay)

	timer.timeout.connect(func():
		# remove THIS exact respawn entry
		respawning.erase(respawn_data)

		_spawn_drone(
			respawn_data["type"],
			respawn_data["pos"],
			respawn_data["target"],
			respawn_data["index"]   # ⭐ put new drone in same slot
		)
	)





func _spawn_drone(type_name: String, pos: Vector2, target: Node2D, index := -1) -> DroneFollower:
	if not drone_types.has(type_name):
		push_error("❌ Tried to spawn unknown drone type: %s" % type_name)
		return null

	var scene: PackedScene = drone_types[type_name]
	var new_drone: DroneFollower = scene.instantiate()

	new_drone.global_position = pos
	new_drone.follow_body = target
	new_drone.drone_type = type_name

	# assign a unique id
	_uid_counter += 1
	new_drone.uid = _uid_counter

	_get_fleet_node().add_child(new_drone)

	if index == -1:
		drones.append(new_drone)
	else:
		drones[index] = new_drone   # ⭐ replace old entry

	return new_drone



func _spawn_initial_drones() -> void:
	var offset := Vector2(40, 0)
	var pos := Vector2(200, 300)

	for drone_name in drone_types.keys():
		_spawn_drone(drone_name, pos, player)
		pos += offset

	print("🚀 Spawned initial drones:", drones.size())


# =========================================================
# Helper: Get fleet node
# =========================================================
func _get_fleet_node() -> Node:
	var root := get_tree().get_root()
	if root.has_node(FLEET_NODE_PATH):
		return root.get_node(FLEET_NODE_PATH)
	
	push_error("❌ Fleet node not found at: %s" % FLEET_NODE_PATH)
	return get_tree().get_current_scene()
