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


func _physics_process(_delta: float) -> void:
	
	var player_dir = (get_global_mouse_position() - position).normalized()
	if Input.is_action_pressed("thrust_mouse"):
		velocity = 200 * player_dir
	if Input.is_action_pressed("kill_velocity"):
		velocity = Vector2.ZERO
		
	move_and_slide()
	#force_g()

@onready var planets = get_tree().get_nodes_in_group("Planets") #calls the group with planets
func force_g():
	for i in range(len(planets)):
		var direction_g = (global_position - planets[i].global_position)
		velocity -= (direction_g.normalized() 
						* planets[i].mass * 3e4/direction_g.length()**2)
