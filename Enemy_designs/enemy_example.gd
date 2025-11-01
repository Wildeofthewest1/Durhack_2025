extends CharacterBody2D

@onready var gread: GravitySensor = $GravitySensor

@export var initial_velocity: Vector2 = Vector2.ZERO
@export var use_gravity: bool = true
@export var gravity_multiplier: float = 1.0
@export var thrust_accel: float = 1200.0
@export var max_speed: float = 800.0
@export var detection_radius: float = 150.0
@export var far_away_radius: float = 500.0
@export var far_away_max_speed: float = 1200.0
@export var rotate_with_motion: bool = true
@export var rotate_offset_deg: float = 0.0
@export var randomisation_strength: float = 50.0
@export var randomisation_interval: float = 2.0

var player: CharacterBody2D = null
var is_close_to_player: bool = false
var is_far_from_player: bool = false
var randomization: Vector2 = Vector2(0.0, 0.0)
var randomization_timer: float = 0.0


func _ready() -> void:
	print("[Enemy] ready")
	velocity = initial_velocity
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	up_direction = Vector2.ZERO
	_recompute_randomization()
	
	# Find the player
	await get_tree().process_frame
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("[Enemy] found player")
	else:
		print("[Enemy] WARNING: no player found")


func _physics_process(delta: float) -> void:
	# Update randomization timer
	randomization_timer += delta
	if randomization_timer >= randomisation_interval:
		_recompute_randomization()
		randomization_timer = 0.0
	
	# 1) Build total acceleration starting with gravity (if enabled)
	var a_total: Vector2 = Vector2.ZERO
	if use_gravity:
		a_total = gread.compute_accel_now() * gravity_multiplier
	
	# 2) Check if player is valid and get distance
	if is_instance_valid(player):
		var to_player: Vector2 = player.global_position + randomization - global_position
		var distance: float = to_player.length()
		
		# Update state based on distance
		is_close_to_player = distance <= detection_radius
		is_far_from_player = distance > far_away_radius
		
		# Determine current max speed based on state
		var current_max_speed: float = max_speed
		
		# State 1: Far away (fast chase)
		if is_far_from_player:
			current_max_speed = far_away_max_speed
			if distance > 0.0:
				var direction: Vector2 = to_player / distance
				a_total += direction * thrust_accel
			use_gravity = true
		# State 2: Medium distance (normal chase)
		elif not is_close_to_player and distance > 0.0:
			current_max_speed = max_speed
			var direction: Vector2 = to_player / distance
			a_total += direction * thrust_accel
			use_gravity = false
		# State 3: Close to player (stop thrusting)
		else:
			use_gravity = false
		
		# 3) Integrate velocity using total acceleration
		velocity += a_total * delta
		
		# 4) Cap velocity to current max_speed
		var speed: float = velocity.length()
		if speed > current_max_speed and speed > 0.0:
			velocity = (velocity / speed) * current_max_speed
	else:
		# No player found, just apply gravity
		velocity += a_total * delta
	
	# 5) Move
	move_and_slide()
	
	# 6) Rotate to face movement direction
	if rotate_with_motion and velocity.length() > 0.001:
		rotation = velocity.angle() + deg_to_rad(rotate_offset_deg)


func _recompute_randomization() -> void:
	randomization = Vector2(
		randf_range(-randomisation_strength, randomisation_strength),
		randf_range(-randomisation_strength, randomisation_strength)
	)
