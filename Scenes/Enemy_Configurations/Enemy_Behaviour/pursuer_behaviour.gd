extends Node
class_name EnemyChaseBehaviour

var enemy: CharacterBody2D = null

# Config (local to the behaviour; tweak as needed)
var initial_velocity: Vector2 = Vector2.ZERO
var thrust_accel: float = 1000.0
var max_speed: float = 800.0
var detection_radius: float = 150.0
var far_away_radius: float = 500.0
var far_away_max_speed: float = 500.0
var rotate_with_motion: bool = true
var rotate_offset_deg: float = 0.0
var randomisation_strength: float = 50.0
var randomisation_interval: float = 2.0

# State
var is_close_to_player: bool = false
var is_far_from_player: bool = false
var randomization: Vector2 = Vector2.ZERO
var randomization_timer: float = 0.0
var _initialised_velocity: bool = false


func update(delta: float) -> void:
	# Same guard as your simple behaviour
	if enemy == null or enemy.player == null:
		return

	# One-time initial velocity, mirroring `velocity = initial_velocity` in _ready()
	if not _initialised_velocity:
		enemy.velocity = initial_velocity
		_initialised_velocity = true

	# -----------------------------
	# Randomisation timer / offset
	# -----------------------------
	randomization_timer += delta
	if randomization_timer >= randomisation_interval:
		_recompute_randomization()
		randomization_timer = 0.0

	# -----------------------------
	# 1) Build total acceleration
	# (no gravity sensor, so we start from zero)
	# -----------------------------
	var a_total: Vector2 = Vector2.ZERO

	# -----------------------------
	# 2) Distance and state logic
	# -----------------------------
	var target_pos: Vector2 = enemy.player.global_position + randomization
	var to_player: Vector2 = target_pos - enemy.global_position
	var distance: float = to_player.length()

	is_close_to_player = distance <= detection_radius
	is_far_from_player = distance > far_away_radius

	var current_max_speed: float = max_speed

	if is_far_from_player:
		# State 1: far away → fast chase
		current_max_speed = far_away_max_speed
		if distance > 0.0:
			var dir_far: Vector2 = to_player / distance
			a_total += dir_far * thrust_accel

	elif not is_close_to_player and distance > 0.0:
		# State 2: medium distance → normal chase
		current_max_speed = max_speed
		var dir_mid: Vector2 = to_player / distance
		a_total += dir_mid * thrust_accel

	else:
		# State 3: close to player → stop thrusting (drift with current velocity)
		pass

	# -----------------------------
	# 3) Integrate velocity
	# -----------------------------
	enemy.velocity += a_total * delta

	# -----------------------------
	# 4) Cap speed to current_max_speed
	# -----------------------------
	var speed: float = enemy.velocity.length()
	if speed > current_max_speed and speed > 0.0:
		enemy.velocity = (enemy.velocity / speed) * current_max_speed

	# -----------------------------
	# 5) Move
	# -----------------------------
	enemy.move_and_slide()

	# -----------------------------
	# 6) Rotate to face movement
	# -----------------------------
	if rotate_with_motion and enemy.velocity.length() > 0.001:
		enemy.rotation = enemy.velocity.angle() + deg_to_rad(rotate_offset_deg)


func _recompute_randomization() -> void:
	randomization = Vector2(
		randf_range(-randomisation_strength, randomisation_strength),
		randf_range(-randomisation_strength, randomisation_strength)
	)
