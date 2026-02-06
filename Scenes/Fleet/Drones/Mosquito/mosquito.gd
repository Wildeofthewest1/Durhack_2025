extends DroneBase
class_name MosquitoDrone

## Mosquito drone that harasses enemies when they come in range
## Orbits around enemies while attacking, returns to player when too far
## Can only move in the direction it's facing

@export var detection_range: float = 400.0
@export var max_chase_distance: float = 500.0  # How far from player before returning
@export var orbit_distance: float = 80.0       # Distance to orbit around enemy
@export var follow_distance: float = 100.0     # How close to stay to player when following
@export var orbit_speed_multiplier: float = 2.0  # How fast to orbit (multiplier)
@export var turn_rate: float = 3.0             # How fast the drone turns (radians/sec)
@export var speed_boost_range: float = 200.0  # Distance at which speed boost activates
@export var speed_boost_multiplier: float = 2.0  # Speed multiplier when far from target
@export var speed_transition_rate: float = 3.0  # How fast speed changes (higher = faster transition)
@export var enemy_group: String = "enemies"

enum State {
	FOLLOWING,   # Following player
	HARASSING,   # Orbiting and attacking an enemy
	RETURNING    # Returning to player (got too far)
}

var current_state: State = State.FOLLOWING
var target_enemy: Node2D = null
var orbit_angle: float = 0.0
var current_speed_multiplier: float = 1.0  # Smoothly interpolated speed multiplier

func _ready() -> void:
	super._ready()
	orbit_angle = randf() * TAU

func _physics_process(delta: float) -> void:
	if follow_body == null:
		return
	
	# Determine desired direction and target distance based on state
	var desired_direction: Vector2 = Vector2.ZERO
	var distance_to_target: float = 0.0
	
	match current_state:
		State.FOLLOWING:
			var result: Dictionary = _state_following(delta)
			desired_direction = result.get("direction", Vector2.ZERO)
			distance_to_target = result.get("distance", 0.0)
		State.HARASSING:
			var result: Dictionary = _state_harassing(delta)
			desired_direction = result.get("direction", Vector2.ZERO)
			distance_to_target = result.get("distance", 0.0)
		State.RETURNING:
			var result: Dictionary = _state_returning(delta)
			desired_direction = result.get("direction", Vector2.ZERO)
			distance_to_target = result.get("distance", 0.0)
	
	# Turn toward desired direction
	if desired_direction.length() > 0.01:
		var desired_angle: float = desired_direction.angle() + PI / 2.0
		var angle_diff: float = angle_difference(rotation, desired_angle)
		var turn_amount: float = sign(angle_diff) * min(abs(angle_diff), turn_rate * delta)
		rotation += turn_amount
	
	# Smoothly transition speed multiplier based on distance
	var target_multiplier: float = 1.0
	if distance_to_target > speed_boost_range:
		target_multiplier = speed_boost_multiplier
	
	# Lerp current multiplier toward target multiplier
	current_speed_multiplier = lerp(current_speed_multiplier, target_multiplier, speed_transition_rate * delta)
	
	# Apply speed with smooth multiplier
	var current_speed: float = effective_speed * current_speed_multiplier
	
	# Move forward in the direction we're facing
	var forward: Vector2 = Vector2(cos(rotation - PI / 2.0), sin(rotation - PI / 2.0))
	global_position += forward * current_speed * delta

func _state_following(delta: float) -> Dictionary:
	# Move toward player slot
	var slot_pos: Vector2 = follow_body.global_position + get_slot_offset()
	var to_slot: Vector2 = slot_pos - global_position
	var distance: float = to_slot.length()
	
	# Look for enemies to harass
	var nearest: Node2D = _find_nearest_enemy()
	if nearest != null:
		target_enemy = nearest
		current_state = State.HARASSING
		# Initialize orbit angle based on current position
		var to_enemy: Vector2 = target_enemy.global_position - global_position
		orbit_angle = to_enemy.angle()
	
	return {
		"direction": to_slot.normalized(),
		"distance": distance
	}

func _state_harassing(delta: float) -> Dictionary:
	# Check if target is still valid
	if not is_instance_valid(target_enemy):
		target_enemy = null
		current_state = State.FOLLOWING
		return {"direction": Vector2.ZERO, "distance": 0.0}
	
	# Check if too far from player - if so, return
	var dist_from_player: float = global_position.distance_to(follow_body.global_position)
	if dist_from_player > max_chase_distance:
		current_state = State.RETURNING
		return {"direction": Vector2.ZERO, "distance": 0.0}
	
	# Check if target moved too far from player
	var target_dist_from_player: float = target_enemy.global_position.distance_to(follow_body.global_position)
	if target_dist_from_player > detection_range * 1.2:
		target_enemy = null
		current_state = State.RETURNING
		return {"direction": Vector2.ZERO, "distance": 0.0}
	
	# Orbit around the enemy
	orbit_angle += (effective_speed / orbit_distance) * orbit_speed_multiplier * delta
	
	# Calculate desired orbit position
	var orbit_offset: Vector2 = Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_distance
	var desired_pos: Vector2 = target_enemy.global_position + orbit_offset
	
	# Direction to desired orbit position
	var to_desired: Vector2 = desired_pos - global_position
	var distance: float = to_desired.length()
	
	# Attack if can fire
	if can_fire():
		_attack_enemy()
		start_fire_cooldown()
	
	return {
		"direction": to_desired.normalized(),
		"distance": distance
	}

func _state_returning(delta: float) -> Dictionary:
	# Move back toward player
	var to_player: Vector2 = follow_body.global_position - global_position
	var dist: float = to_player.length()
	
	# If close enough, return to following
	if dist < follow_distance * 1.5:
		current_state = State.FOLLOWING
		target_enemy = null
		return {"direction": Vector2.ZERO, "distance": 0.0}
	
	# Can still look for closer enemies while returning
	if dist < detection_range:
		var nearest: Node2D = _find_nearest_enemy()
		if nearest != null:
			var enemy_dist: float = global_position.distance_to(nearest.global_position)
			if enemy_dist < detection_range * 0.5:  # Only re-engage if very close
				target_enemy = nearest
				current_state = State.HARASSING
				orbit_angle = (nearest.global_position - global_position).angle()
	
	return {
		"direction": to_player.normalized(),
		"distance": dist
	}

func _find_nearest_enemy() -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group(enemy_group)
	var nearest: Node2D = null
	var nearest_dist: float = detection_range
	
	for enemy in enemies:
		var e: Node2D = enemy as Node2D
		if not is_instance_valid(e):
			continue
		
		# Only consider enemies that are reasonably close to player
		var enemy_dist_from_player: float = follow_body.global_position.distance_to(e.global_position)
		if enemy_dist_from_player > detection_range:
			continue
		
		var dist: float = global_position.distance_to(e.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = e
	
	return nearest

func _attack_enemy() -> void:
	if not is_instance_valid(target_enemy):
		return
	
	# Apply damage with some accuracy variance
	var actual_damage: float = effective_damage
	
	# Accuracy affects damage variance
	var variance: float = (1.0 - effective_accuracy) * 0.3
	actual_damage = actual_damage * randf_range(1.0 - variance, 1.0 + variance)
	
	if target_enemy.has_method("take_damage"):
		target_enemy.take_damage(actual_damage)

func get_slot_offset() -> Vector2:
	if slot_index < 0:
		return Vector2.ZERO
	
	var total_slots: int = 32
	var angle: float = (TAU / float(total_slots)) * float(slot_index)
	var radius: float = follow_distance
	
	return Vector2(cos(angle), sin(angle)) * radius
