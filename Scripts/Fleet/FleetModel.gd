extends CharacterBody2D
class_name DroneFollower

@export var follow_body: Node2D = null         # who we orbit
@export var orbit_radius: float = 128.0        # how far from the follow_body we stay
@export var orbit_speed: float = 1.0           # radians per second
@export var follow_lerp_speed: float = 5.0     # how fast we slide toward the ideal orbit point
@export var face_velocity: bool = true         # turn to face our motion
@export var tangent_mode: bool = true          # if true, face along orbit path instead of movement
@export var rotation_speed: float = 6.0        # rotation smoothing
@export var drone_name: String = "Drone"

var _orbit_angle: float = 0.0
var _prev_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	FleetManager.register_drone(self)
	_prev_position = global_position

func _physics_process(delta: float) -> void:
	if follow_body == null:
		_prev_position = global_position
		return

	# 1. advance the orbit phase
	_orbit_angle += orbit_speed * delta
	if _orbit_angle > TAU:
		_orbit_angle -= TAU

	# 2. compute the ideal orbit position around follow_body
	var orbit_offset: Vector2 = Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_radius
	var desired_pos: Vector2 = follow_body.global_position + orbit_offset

	# 3. smoothly move toward that desired_pos
	#    lerp = no jitter, no overshoot, always smooth
	var new_pos: Vector2 = global_position.lerp(desired_pos, follow_lerp_speed * delta)
	
	# store velocity BEFORE we commit to rotation calc
	var frame_velocity: Vector2 = (new_pos - _prev_position) / delta

	global_position = new_pos

	# 4. update rotation if requested
	if face_velocity == true:
		var desired_angle: float = rotation

		if tangent_mode == true:
			# face along orbit path (tangent)
			# tangent is perpendicular to radius vector
			var tangent_vec: Vector2 = Vector2(-sin(_orbit_angle), cos(_orbit_angle))
			desired_angle = tangent_vec.angle()
		else:
			# face along how we actually moved this frame
			var speed_len: float = frame_velocity.length()
			if speed_len > 1.0:
				desired_angle = frame_velocity.angle()

		rotation = lerp_angle(rotation, desired_angle, rotation_speed * delta)

	# 5. save for next frame
	_prev_position = global_position
