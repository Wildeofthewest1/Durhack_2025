extends Node

## Global singleton for managing drone resources and slot assignments
## Handles drone catalog, active tracking, and prevents stacking via slot system

signal drone_spawned(drone: Node2D, drone_resource: DroneResource)
signal drone_destroyed(drone: Node2D, drone_resource: DroneResource)
signal drone_type_registered(drone_id: String, drone_resource: DroneResource)

## All available drone types (DroneResource) keyed by drone_id
var drone_catalog: Dictionary = {}

## Active drone instances tracked by their unique instance id
## Structure: { instance_id: { "node": Node2D, "resource": DroneResource, "slot": int } }
var active_drones: Dictionary = {}

## Player resources
var player_metal: int = 1000
var player_energy: int = 500

## Slot assignment tracking (per follow_body)
## Structure: { follow_body_instance_id: Array[drone_instance_id or null] }
var _slot_assignments: Dictionary = {}

func _ready() -> void:
	# Load and register drone types from resources
	# You can load your .tres files here or register them from your game's initialization
	pass

## Register a drone type in the catalog
func register_drone_type(drone_resource: DroneResource) -> void:
	if drone_resource.drone_id.is_empty():
		push_warning("Cannot register drone resource with empty drone_id")
		return
	
	drone_catalog[drone_resource.drone_id] = drone_resource
	drone_type_registered.emit(drone_resource.drone_id, drone_resource)
	print("[DroneManager] Registered drone type: %s" % drone_resource.drone_id)

## Get a drone resource by ID
func get_drone_resource(drone_id: String) -> DroneResource:
	return drone_catalog.get(drone_id, null)

## Get all available drone types
func get_all_drone_types() -> Array:
	return drone_catalog.values()

## Check if player can afford to build a drone
func can_afford_drone(drone_resource: DroneResource) -> bool:
	return (player_metal >= drone_resource.build_cost_metal and 
			player_energy >= drone_resource.build_cost_energy)

## Deduct resources for building a drone
func pay_for_drone(drone_resource: DroneResource) -> bool:
	if not can_afford_drone(drone_resource):
		return false
	
	player_metal -= drone_resource.build_cost_metal
	player_energy -= drone_resource.build_cost_energy
	return true

## Assign a slot for a drone around a follow body
## Drones of the same type space themselves equally
## Returns the slot index, or -1 if no slots available
func assign_slot(drone_node: Node2D, follow_body: Node2D, max_slots: int = 32) -> int:
	if not is_instance_valid(follow_body):
		return -1
	
	var body_id: int = follow_body.get_instance_id()
	
	# Initialize slot array if needed
	if not _slot_assignments.has(body_id):
		_slot_assignments[body_id] = []
		_slot_assignments[body_id].resize(max_slots)
	
	var slots: Array = _slot_assignments[body_id]
	var drone_id: int = drone_node.get_instance_id()
	
	# Get drone type directly from the drone node
	var drone_type: String = ""
	if "drone_resource" in drone_node and drone_node.drone_resource != null:
		drone_type = drone_node.drone_resource.drone_id
	
	# If we have a type, try to space evenly with same type
	if drone_type != "":
		var same_type_slots: Array = []
		
		# Find all slots occupied by same type drones
		for i: int in range(slots.size()):
			if slots[i] != null:
				var other_drone_id: int = slots[i]
				if active_drones.has(other_drone_id):
					var other_data: Dictionary = active_drones[other_drone_id]
					if other_data.has("resource") and other_data["resource"].drone_id == drone_type:
						same_type_slots.append(i)
		
		# Calculate ideal slot for even spacing
		var same_type_count: int = same_type_slots.size()
		if same_type_count > 0:
			# Determine ideal spacing angle
			var ideal_slot: int = _calculate_ideal_slot(same_type_slots, max_slots)
			
			# If ideal slot is free, use it
			if slots[ideal_slot] == null:
				slots[ideal_slot] = drone_id
				return ideal_slot
	
	# Fall back to finding first available slot
	for i: int in range(slots.size()):
		if slots[i] == null:
			slots[i] = drone_id
			return i
	
	# No slots available
	return -1

## Calculate ideal slot index for even spacing
func _calculate_ideal_slot(occupied_slots: Array, max_slots: int) -> int:
	if occupied_slots.is_empty():
		return 0
	
	# Sort slots
	occupied_slots.sort()
	
	# Find largest gap between occupied slots
	var largest_gap: int = 0
	var largest_gap_start: int = 0
	
	for i: int in range(occupied_slots.size()):
		var current_slot: int = occupied_slots[i]
		var next_slot: int = occupied_slots[(i + 1) % occupied_slots.size()]
		
		# Handle wraparound
		var gap: int
		if next_slot > current_slot:
			gap = next_slot - current_slot
		else:
			gap = (max_slots - current_slot) + next_slot
		
		if gap > largest_gap:
			largest_gap = gap
			largest_gap_start = current_slot
	
	# Place new drone in middle of largest gap
	var ideal_slot: int = (largest_gap_start + largest_gap / 2) % max_slots
	
	return ideal_slot

## Release a slot when drone is destroyed
func release_slot(drone_node: Node2D, follow_body: Node2D) -> void:
	if not is_instance_valid(follow_body):
		return
	
	var body_id: int = follow_body.get_instance_id()
	if not _slot_assignments.has(body_id):
		return
	
	var slots: Array = _slot_assignments[body_id]
	var drone_id: int = drone_node.get_instance_id()
	
	for i: int in range(slots.size()):
		if slots[i] == drone_id:
			slots[i] = null
			return

## Register an active drone instance
func register_active_drone(drone_node: Node2D, drone_resource: DroneResource, slot: int = -1) -> void:
	if not is_instance_valid(drone_node):
		push_warning("Cannot register invalid drone node")
		return
	
	var instance_id: int = drone_node.get_instance_id()
	active_drones[instance_id] = {
		"node": drone_node,
		"resource": drone_resource,
		"slot": slot
	}
	
	drone_spawned.emit(drone_node, drone_resource)
	print("[DroneManager] Registered active drone: %s (ID: %d, Slot: %d)" % [drone_resource.drone_display_name, instance_id, slot])

## Unregister an active drone instance
func unregister_active_drone(drone_node: Node2D) -> void:
	if not is_instance_valid(drone_node):
		return
	
	var instance_id: int = drone_node.get_instance_id()
	if active_drones.has(instance_id):
		var data: Dictionary = active_drones[instance_id]
		drone_destroyed.emit(drone_node, data["resource"])
		active_drones.erase(instance_id)
		print("[DroneManager] Unregistered active drone (ID: %d)" % instance_id)

## Get all active drones
func get_active_drones() -> Array:
	var drones: Array = []
	for instance_id: int in active_drones.keys():
		var data: Dictionary = active_drones[instance_id]
		if is_instance_valid(data["node"]):
			drones.append(data["node"])
		else:
			# Clean up invalid reference
			active_drones.erase(instance_id)
	return drones

## Get count of active drones by type
func get_active_drone_count_by_type(drone_id: String) -> int:
	var count: int = 0
	for instance_id: int in active_drones.keys():
		var data: Dictionary = active_drones[instance_id]
		if is_instance_valid(data["node"]) and data["resource"].drone_id == drone_id:
			count += 1
	return count

## Get total active drone count
func get_total_active_drone_count() -> int:
	return active_drones.size()

## Calculate total maintenance cost of all active drones
func get_total_maintenance_cost() -> float:
	var total: float = 0.0
	for instance_id: int in active_drones.keys():
		var data: Dictionary = active_drones[instance_id]
		if is_instance_valid(data["node"]):
			total += data["resource"].maintenance_cost
	return total

## Get statistics about active drones
func get_drone_statistics() -> Dictionary:
	var stats: Dictionary = {
		"total_drones": 0,
		"by_type": {},
		"total_maintenance": 0.0
	}
	
	for instance_id: int in active_drones.keys():
		var data: Dictionary = active_drones[instance_id]
		if is_instance_valid(data["node"]):
			var drone_resource: DroneResource = data["resource"]
			stats["total_drones"] += 1
			stats["total_maintenance"] += drone_resource.maintenance_cost
			
			if not stats["by_type"].has(drone_resource.drone_id):
				stats["by_type"][drone_resource.drone_id] = 0
			stats["by_type"][drone_resource.drone_id] += 1
	
	return stats

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Clean up all references
		active_drones.clear()
		_slot_assignments.clear()
