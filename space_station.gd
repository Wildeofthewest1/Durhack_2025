extends CharacterBody2D


@export var initial_velocity = 100
@export var initial_direction = Vector2.RIGHT
@export var planet : CharacterBody2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	velocity = initial_velocity * initial_direction 
	print(planet.mass)
	
func _physics_process(delta: float) -> void:
	move_and_slide()
	force_g_local()

func force_g_local():
	var parent_mass = planet.mass
	var direction_g = (global_position - planet.global_position)
	velocity -= (direction_g.normalized() 
					* parent_mass * 1e6/direction_g.length()**2)
