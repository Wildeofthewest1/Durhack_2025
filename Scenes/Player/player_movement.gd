extends Node
class_name PlayerMovement

# --- Movement / gravity settings ---
@export var gravity_multiplier: float = 1.0
@export var thrust_accel: float = 180.0
@export var max_speed: float = 10.0
@export var deadzone_px: float = 6.0
@export var rotate_with_motion: bool = true
@export var rotate_offset_deg: float = 0.0
@export var gravitational_constant: float = 10000.0
@export var thrust_particles: GPUParticles2D

# --- Fuel settings ---
@export var fuel_max: float = 100.0
@export var fuel_use_rate: float = 20.0
@export var fuel_recharge_rate: float = 15.0
@export var fuel_fulluse_recharge: float = 0.05
@export var fuel_recharge_rate_fulluse: float = 10.0

# --- Thrust curve settings ---
@export var thrust_curve_strength: float = 1.0
@export var thrust_curve_decay: float = 1.5
@export var thrust_intensity_max: float = 1.5

# --- Dynamic speed limit settings ---
@export var extra_speed_limit: float = 20.0
@export var speed_limit_grow_rate: float = 3.0
@export var speed_limit_decay_rate: float = 2.0

var player: CharacterBody2D = null
var fuel: float = 0.0
var current_speed_limit: float = 0.0
var was_fully_depleted: bool = false
var thrust_intensity: float = 0.0

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if player == null:
		push_error("PlayerMovement must be a child of a CharacterBody2D.")
		return

	fuel = fuel_max
	current_speed_limit = max_speed

func _physics_process(delta: float) -> void:
	if player == null:
		return

	var gameplay_enabled: bool = InputLock.is_gameplay_enabled()

	# 1) Build total acceleration
	var a_total_local: Vector2 = Vector2.ZERO

	# --- Gravity toward all planets ---
	var planet_list: Array[Node] = get_tree().get_nodes_in_group("Planets")
	for planet: Node in planet_list:
		if not ("mass" in planet) or not ("radius" in planet):
			continue

		var to_planet: Vector2 = (planet as Node2D).global_position - player.global_position
		var distance: float = to_planet.length()
		if distance == 0.0:
			continue

		var min_distance: float = float(planet.get("radius"))
		if distance < min_distance:
			continue

		var direction: Vector2 = to_planet / distance
		var mass_value: float = float(planet.get("mass"))
		var force: float = gravitational_constant * gravity_multiplier * mass_value / pow(distance, 2.0)
		a_total_local += direction * force
	# -----------------------------------

	# --- Thrust / fuel logic ---
	# IMPORTANT: input-only lock: when locked, treat thrust as NOT pressed.
	var is_thrusting: bool = false
	if gameplay_enabled:
		is_thrusting = Input.is_action_pressed("thrust_mouse")

	var applied_thrust: bool = false

	# Update thrust intensity (engine spool)
	if is_thrusting:
		thrust_intensity += delta
	else:
		thrust_intensity -= thrust_curve_decay * delta
		if thrust_intensity < 0.0:
			thrust_intensity = 0.0

	# Clamp intensity
	if thrust_intensity > thrust_intensity_max:
		thrust_intensity = thrust_intensity_max

	# How much of the bar must refill before we lift the lockout
	var recharge_fraction: float = fuel_fulluse_recharge
	if recharge_fraction < 0.0:
		recharge_fraction = 0.0
	if recharge_fraction > 1.0:
		recharge_fraction = 1.0
	var recharge_threshold: float = fuel_max * recharge_fraction

	# Can we use thrust this frame?
	var can_use_thrust: bool = not was_fully_depleted

	# Thrust multiplier: engine gets more powerful as it spools up.
	var thrust_multiplier: float = 1.0 + thrust_curve_strength * thrust_intensity
	if thrust_multiplier < 1.0:
		thrust_multiplier = 1.0

	# --- Apply thrust if allowed (normal mode only) ---
	if is_thrusting and fuel > 0.0 and can_use_thrust:
		# Mouse aiming is also "input"; only use it if gameplay is enabled.
		var mouse_world: Vector2 = player.global_position
		if gameplay_enabled:
			mouse_world = player.get_global_mouse_position()

		var to_mouse: Vector2 = mouse_world - player.global_position
		var d: float = to_mouse.length()

		if d > deadzone_px:
			var thrust_dir: Vector2 = to_mouse / d
			a_total_local += thrust_dir * thrust_accel * thrust_multiplier
			applied_thrust = true

		var fuel_spent: float = fuel_use_rate * delta
		fuel -= fuel_spent
		if fuel < 0.0:
			fuel = 0.0

		if fuel == 0.0:
			was_fully_depleted = true
	else:
		applied_thrust = false

	# --- Recharge fuel ---
	if was_fully_depleted:
		fuel += fuel_recharge_rate_fulluse * delta
	elif not is_thrusting:
		fuel += fuel_recharge_rate * delta

	if fuel > fuel_max:
		fuel = fuel_max

	# Leave lockout once we have enough fuel back
	if was_fully_depleted and fuel >= recharge_threshold:
		was_fully_depleted = false

	# --- Thrust particles ---
	if thrust_particles != null:
		thrust_particles.emitting = applied_thrust

	# 2) Integrate velocity
	player.velocity += a_total_local * delta

	# 3) Dynamic speed limit
	if applied_thrust and player.velocity.length() > 0.1:
		var target_limit_up: float = max_speed + extra_speed_limit
		current_speed_limit = lerp(current_speed_limit, target_limit_up, speed_limit_grow_rate * delta)
	else:
		current_speed_limit = lerp(current_speed_limit, max_speed, speed_limit_decay_rate * delta)

	if current_speed_limit < max_speed:
		current_speed_limit = max_speed

	# 4) Cap speed
	var speed: float = player.velocity.length()
	if speed > current_speed_limit:
		player.velocity = player.velocity.normalized() * current_speed_limit

	# 5) Move (always)
	player.move_and_slide()

	# 6) Rotate with motion or face mouse
	# If locked, DO NOT face mouse (mouse is input). Keep rotate_with_motion behavior.
	if rotate_with_motion and player.velocity.length() > 0.001:
		player.rotation = player.velocity.angle() + deg_to_rad(rotate_offset_deg)
	elif gameplay_enabled:
		player.look_at(player.get_global_mouse_position())

func get_fuel_ratio() -> float:
	if fuel_max <= 0.0:
		return 0.0
	var ratio: float = fuel / fuel_max
	if ratio < 0.0:
		ratio = 0.0
	if ratio > 1.0:
		ratio = 1.0
	return ratio
