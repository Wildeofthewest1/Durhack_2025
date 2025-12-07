extends Node
class_name EnemyRangedMovement

var enemy: CharacterBody2D

@export var ideal_range: float = 180.0
@export var min_range: float = 120.0
@export var strafe_speed: float = 120.0
@export var strafe_interval: float = 2.0
@export var strafe_smoothness: float = 4.0
@export var accel_speed: float = 6.0   # how fast enemy accelerates to desired velocity

var strafe_target := 1
var strafe_current := 1.0
var strafe_timer := 0.0

func update(delta: float) -> void:
	if enemy == null or enemy.player == null:
		return

	var player_pos = enemy.player.global_position
	var to_player = player_pos - enemy.global_position
	var distance = to_player.length()
	var dir_to_player = to_player.normalized()

	# ------------------------------------------------------
	# 1) Smoothly update strafing direction
	# ------------------------------------------------------
	strafe_timer += delta
	if strafe_timer >= strafe_interval:
		strafe_timer = 0.0
		strafe_target = 1 if randf() > 0.5 else -1

	# Smoothly blend toward target strafing direction
	strafe_current = lerp(strafe_current, float(strafe_target), delta * strafe_smoothness)

	var perpendicular := Vector2(-dir_to_player.y, dir_to_player.x)

	# ------------------------------------------------------
	# 2) Build desired velocity (NO smoothing yet)
	# ------------------------------------------------------
	var desired_velocity := Vector2.ZERO

	# A) Too far → move toward player
	if distance > ideal_range:
		desired_velocity += dir_to_player * enemy.speed

	# B) Too close → retreat
	elif distance < min_range:
		desired_velocity -= dir_to_player * enemy.speed

	# C) In ideal range → no forward/back movement

	# D) Add strafing
	desired_velocity += perpendicular * strafe_current * strafe_speed

	# ------------------------------------------------------
	# 3) SMOOTH ACCELERATION toward desired velocity
	# ------------------------------------------------------
	enemy.velocity = lerp(enemy.velocity, desired_velocity, delta * accel_speed)

	# ------------------------------------------------------
	# 4) Apply movement
	# ------------------------------------------------------
	enemy.move_and_slide()
