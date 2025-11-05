extends CharacterBody2D

@export var initial_velocity: Vector2 = Vector2.ZERO
@export var gravity_multiplier: float = 1.0
@export var thrust_accel: float = 180.0
@export var max_speed: float = 10.0
@export var deadzone_px: float = 6.0
@export var rotate_with_motion: bool = true
@export var rotate_offset_deg: float = 0.0
@export var gravitational_constant: float = 10000.0
@export var thrust: GPUParticles2D
@export var health: int = 200

# --- Fuel settings ---
@export var fuel_max: float = 100.0          # maximum fuel
@export var fuel_use_rate: float = 20.0      # fuel per second while thrusting
@export var fuel_recharge_rate: float = 15.0 # fuel per second while not thrusting
# After fully draining fuel, how much of the tank (0.0–1.0) must be refilled
# before thrust can be used again.
@export var fuel_fulluse_recharge: float = 0.05

# --- Dynamic speed limit settings ---
# max_speed is your "cruise" cap; you can push above it a bit while thrusting
@export var extra_speed_limit: float = 20.0      # how much above max_speed you can go
@export var speed_limit_grow_rate: float = 3.0   # how fast limit rises while thrusting
@export var speed_limit_decay_rate: float = 2.0  # how fast it returns to max_speed

var a_total: Vector2 = Vector2.ZERO
var fuel: float = 0.0
var current_speed_limit: float = 0.0
var was_fully_depleted: bool = false

@onready var planets: Array = get_tree().get_nodes_in_group("Planets")

func force_g() -> void:
	for i in range(planets.size()):
		var planet_node: Node = planets[i]
		if not "mass" in planet_node:
			continue
		var direction_g: Vector2 = global_position - planet_node.global_position
		var accel: Vector2 = direction_g.normalized() * planet_node.mass * 30000.0 / pow(direction_g.length(), 2)
		velocity -= accel


func _ready() -> void:
	print("[Player] ready")
	velocity = initial_velocity
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	up_direction = Vector2.RIGHT
	fuel = fuel_max
	current_speed_limit = max_speed


func take_damage(amount: int) -> void:
	health -= amount
	print(name + " took " + str(amount) + " damage, remaining health: " + str(health))

	if has_node("Sprite2D"):
		var sprite: Sprite2D = $Sprite2D
		_flash_red(sprite)

	if health <= 0:
		die()


func _flash_red(sprite: Sprite2D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0), 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.1)


func die() -> void:
	print(name + " has died")
	health = 100
	global_position = Vector2(0.0, 0.0)
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	# 1) Build total acceleration
	var a_total_local: Vector2 = Vector2.ZERO

	# --- Gravity toward all planets ---
	var planet_list: Array = get_tree().get_nodes_in_group("Planets")
	for planet in planet_list:
		if not "mass" in planet or not "radius" in planet:
			continue
		
		var to_planet: Vector2 = planet.global_position - global_position
		var distance: float = to_planet.length()
		if distance == 0.0:
			continue
		
		var min_distance: float = planet.radius
		if distance < min_distance:
			continue  # No gravity if overlapping
		
		var direction: Vector2 = to_planet / distance
		var force: float = gravitational_constant * gravity_multiplier * planet.mass / pow(distance, 2)
		a_total_local += direction * force
	# -----------------------------------

	# --- Thrust toward mouse while RMB held, with fuel and depletion lockout ---
	var is_thrusting: bool = Input.is_action_pressed("thrust_mouse")
	var applied_thrust: bool = false

	# Clamp the recharge fraction to [0, 1]
	var recharge_fraction: float = fuel_fulluse_recharge
	if recharge_fraction < 0.0:
		recharge_fraction = 0.0
	if recharge_fraction > 1.0:
		recharge_fraction = 1.0
	var recharge_threshold: float = fuel_max * recharge_fraction

	# If we have recharged enough after full depletion, clear the lock
	if was_fully_depleted and fuel >= recharge_threshold:
		was_fully_depleted = false

	# Can we currently use thrust?
	var can_use_thrust: bool = not was_fully_depleted

	if is_thrusting and fuel > 0.0 and can_use_thrust:
		var mouse_world: Vector2 = get_global_mouse_position()
		var to_mouse: Vector2 = mouse_world - global_position
		var d: float = to_mouse.length()

		if d > deadzone_px:
			var thrust_dir: Vector2 = to_mouse / d
			a_total_local += thrust_dir * thrust_accel
			applied_thrust = true

		# consume fuel
		fuel -= fuel_use_rate * delta
		if fuel < 0.0:
			fuel = 0.0

		# if we just fully depleted, set lockout flag
		if fuel == 0.0:
			was_fully_depleted = true
	else:
		applied_thrust = false

	# recharge fuel only when not pressing thrust
	if not is_thrusting:
		fuel += fuel_recharge_rate * delta
		if fuel > fuel_max:
			fuel = fuel_max

	# thrust particles only when actually pushing
	if applied_thrust:
		thrust.emitting = true
	else:
		thrust.emitting = false

	# 2) Integrate velocity
	velocity += a_total_local * delta

	# 3) Dynamic speed limit
	# While thrusting, let the cap rise towards max_speed + extra_speed_limit
	# When not thrusting, smoothly return to base max_speed
	if applied_thrust and velocity.length() > 0.1:
		var target_limit_up: float = max_speed + extra_speed_limit
		current_speed_limit = lerp(current_speed_limit, target_limit_up, speed_limit_grow_rate * delta)
	else:
		current_speed_limit = lerp(current_speed_limit, max_speed, speed_limit_decay_rate * delta)

	# Ensure the limit never goes below max_speed
	if current_speed_limit < max_speed:
		current_speed_limit = max_speed

	# 4) Cap speed with dynamic limit
	var speed: float = velocity.length()
	if speed > current_speed_limit:
		velocity = velocity.normalized() * current_speed_limit

	# 5) Move
	move_and_slide()
	
	# 6) Rotate with motion or face mouse
	if rotate_with_motion and velocity.length() > 0.001:
		rotation = velocity.angle() + deg_to_rad(rotate_offset_deg)
	else:
		look_at(get_global_mouse_position())


func get_fuel_ratio() -> float:
	if fuel_max <= 0.0:
		return 0.0
	var ratio: float = fuel / fuel_max
	if ratio < 0.0:
		ratio = 0.0
	if ratio > 1.0:
		ratio = 1.0
	return ratio
