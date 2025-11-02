extends CharacterBody2D

@export var initial_velocity: Vector2 = Vector2.ZERO
@export var gravity_multiplier: float = 1.0
@export var thrust_accel: float = 180
@export var max_speed: float = 10
@export var deadzone_px: float = 6.0
@export var rotate_with_motion: bool = true
@export var rotate_offset_deg: float = 0.0
@export var gravitational_constant: float = 10000

var a_total: Vector2 = Vector2.ZERO


func _ready() -> void:
	print("[Player] ready")
	velocity = initial_velocity
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	up_direction = Vector2.ZERO


func _physics_process(delta: float) -> void:
	# 1) Build total acceleration
	var a_total = Vector2.ZERO

	# --- Gravity toward all planets ---
	for planet in get_tree().get_nodes_in_group("Planets"):
		if not "mass" in planet or not "radius" in planet:
			continue  # Skip if not a proper planet
		
		var to_planet = planet.global_position - global_position
		var distance = to_planet.length()
		if distance == 0:
			continue
		
		var min_distance = planet.radius
		if distance < min_distance:
			continue  # No gravity if overlapping
		
		var direction = to_planet / distance
		var force = gravitational_constant * gravity_multiplier * planet.mass / pow(distance, 2)
		a_total += direction * force
	# -----------------------------------

	# --- Thrust toward mouse while RMB held ---
	if Input.is_action_pressed("thrust_mouse"):
		var mouse_world: Vector2 = get_global_mouse_position()
		var to_mouse: Vector2 = mouse_world - global_position
		var d: float = to_mouse.length()
		if d > deadzone_px:
			a_total += (to_mouse / d) * thrust_accel

	# 2) Integrate velocity
	velocity += a_total * delta

	# 3) Cap speed
	#var speed: float = velocity.length()
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	# 4) Move
	move_and_slide()

	# 5) Rotate with motion
	if rotate_with_motion and velocity.length() > 0.001:
		rotation = velocity.angle() + deg_to_rad(rotate_offset_deg)
