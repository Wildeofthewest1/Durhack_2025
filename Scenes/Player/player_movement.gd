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

# --- Dynamic speed limit settings ---
@export var extra_speed_limit: float = 20.0
@export var speed_limit_grow_rate: float = 3.0
@export var speed_limit_decay_rate: float = 2.0

var player: CharacterBody2D = null
var fuel: float = 0.0
var current_speed_limit: float = 0.0
var was_fully_depleted: bool = false

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if player == null:
		push_error("PlayerMovement must be a child of a CharacterBody2D.")
	fuel = fuel_max
	current_speed_limit = max_speed

func _physics_process(delta: float) -> void:
	if player == null:
		return

	# 1) Build total acceleration
	var a_total_local: Vector2 = Vector2.ZERO

	# --- Gravity toward all planets ---
	var planet_list: Array = get_tree().get_nodes_in_group("Planets")
	for planet in planet_list:
		if not "mass" in planet or not "radius" in planet:
			continue

		var to_planet: Vector2 = planet.global_position - player.global_position
		var distance: float = to_planet.length()
		if distance == 0.0:
			continue

		var min_distance: float = planet.radius
		if distance < min_distance:
			continue

		var direction: Vector2 = to_planet / distance
		var force: float = gravitational_constant * gravity_multiplier * planet.mass / pow(distance, 2)
		a_total_local += direction * force
	# -----------------------------------

	# --- Thrust toward mouse while RMB held, with fuel and depletion lockout ---
	var is_thrusting: bool = Input.is_action_pressed("thrust_mouse")
	var applied_thrust: bool = false

	var recharge_fraction: float = fuel_fulluse_recharge
	if recharge_fraction < 0.0:
		recharge_fraction = 0.0
	if recharge_fraction > 1.0:
		recharge_fraction = 1.0
	var recharge_threshold: float = fuel_max * recharge_fraction

	if was_fully_depleted and fuel >= recharge_threshold:
		was_fully_depleted = false

	var can_use_thrust: bool = not was_fully_depleted

	if is_thrusting and fuel > 0.0 and can_use_thrust:
		var mouse_world: Vector2 = player.get_global_mouse_position()
		var to_mouse: Vector2 = mouse_world - player.global_position
		var d: float = to_mouse.length()

		if d > deadzone_px:
			var thrust_dir: Vector2 = to_mouse / d
			a_total_local += thrust_dir * thrust_accel
			applied_thrust = true

		fuel -= fuel_use_rate * delta
		if fuel < 0.0:
			fuel = 0.0

		if fuel == 0.0:
			was_fully_depleted = true
	else:
		applied_thrust = false

	if not is_thrusting:
		fuel += fuel_recharge_rate * delta
		if fuel > fuel_max:
			fuel = fuel_max

	if thrust_particles != null:
		if applied_thrust:
			thrust_particles.emitting = true
		else:
			thrust_particles.emitting = false

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

	# 5) Move
	player.move_and_slide()

	# 6) Rotate with motion or face mouse
	if rotate_with_motion and player.velocity.length() > 0.001:
		player.rotation = player.velocity.angle() + deg_to_rad(rotate_offset_deg)
	else:
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
