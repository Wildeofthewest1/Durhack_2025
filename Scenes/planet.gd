extends CharacterBody2D

@export var mass = 100.00
@export var initial_speed = 0
@export var initial_direction = Vector2.ZERO


func _ready():
	velocity = initial_speed * initial_direction

func _physics_process(delta: float) -> void:
	move_and_slide()
	force_g()

@onready var planets =  get_tree().get_nodes_in_group("Planets")
func force_g():
	for i in range(len(planets)):
		if i != get_index():
			var direction_g = position - planets[i].global_position
			velocity -= (direction_g.normalized()
							* planets[i].mass * 1e4/direction_g.length()**2)
