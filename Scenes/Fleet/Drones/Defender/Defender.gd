extends DroneBase
class_name OrbitDrone

## Drone that orbits around the follow body
## Uses slot_index to determine orbital position (prevents stacking)

@export var orbit_radius: float = 128.0
@export var orbit_speed: float = 1.0  # Radians per second
@export var follow_smoothing: float = 5.0
@export var rotation_speed: float = 6.0
@export var face_direction: bool = true  # Face direction of movement

var _orbit_angle: float = 0.0
var _prev_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	
	# Initialize orbit angle based on slot
	if slot_index >= 0:
		var total_slots: int = 32
		_orbit_angle = (TAU / float(total_slots)) * float(slot_index)
	else:
		_orbit_angle = randf() * TAU
	
	_prev_position = global_position

func _physics_process(delta: float) -> void:
	if follow_body == null:
		_prev_position = global_position
		return
	
	# Update orbit angle
	_orbit_angle += orbit_speed * delta
	if _orbit_angle > TAU:
		_orbit_angle -= TAU
	
	# Calculate desired position
	var orbit_offset: Vector2 = Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_radius
	var desired_pos: Vector2 = follow_body.global_position + orbit_offset
	
	# Smoothly move toward desired position
	var new_pos: Vector2 = global_position.lerp(desired_pos, follow_smoothing * delta)
	var movement: Vector2 = new_pos - global_position
	
	global_position = new_pos
	
	# Rotation - face away from follow body (outward)
	if face_direction:
		var to_follow: Vector2 = follow_body.global_position - global_position
		var desired_angle: float = to_follow.angle() + PI + PI / 2.0  # Point away + 90 degrees for sprite orientation
		rotation = lerp_angle(rotation, desired_angle, rotation_speed * delta)
	
	_prev_position = global_position

## Override to use orbit_radius
func get_slot_offset() -> Vector2:
	return Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_radius
