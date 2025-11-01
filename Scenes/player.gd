extends CharacterBody2D

@export var initial_velocity: Vector2 = Vector2.ZERO
@export var gravity_multiplier: float = 1.0
@export var thrust_accel: float = 1800.0
@export var max_speed: float = 1200.0
@export var deadzone_px: float = 6.0
@export var rotate_with_motion: bool = true
@export var rotate_offset_deg: float = 0.0
var a_total:= Vector2(0.0,0.0)


func _ready() -> void:
	print("[Player] ready")
	velocity = initial_velocity
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	up_direction = Vector2.ZERO


func _physics_process(delta: float) -> void:
	# 1) Build total acceleration
	
	# Thrust toward mouse while RMB held
	if Input.is_action_pressed("thrust_mouse"):
		var mouse_world: Vector2 = get_global_mouse_position()
		var to_mouse: Vector2 = mouse_world - global_position
		var d: float = to_mouse.length()
		if d > deadzone_px:
			a_total += (to_mouse / d) * thrust_accel
	
	# 2) Integrate once using total acceleration
	velocity += a_total * delta
	
	# 3) Post-integration cap: keep direction, cap magnitude
	var speed: float = velocity.length()
	if speed > max_speed and speed > 0.0:
		velocity = (velocity / speed) * max_speed
	
	# 4) Round velocity to reduce subpixel movement
	velocity = velocity
	# 5) Move
	move_and_slide()
	
	# 6) Snap to pixel grid to prevent ghosting
	global_position = global_position.round()
	
	# 7) Face velocity
	if rotate_with_motion and velocity.length() > 0.001:
		rotation = velocity.angle() + deg_to_rad(rotate_offset_deg)
