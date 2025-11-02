extends CharacterBody2D

<<<<<<< HEAD
@export var mass: float = 1.0
@export var radius: float = 10.0
@export var gravitational_constant: float = 100
=======
@export var mass = 100.00
@export var initial_speed = 0
@export var initial_direction: Vector2
>>>>>>> parent of 8500381 (f)


func _ready():
	velocity = initial_speed * initial_direction

func _physics_process(delta: float) -> void:
	move_and_slide()
	force_g()

@onready var planets =  get_tree().get_nodes_in_group("Planets")

<<<<<<< HEAD
		var to_other = other.global_position - global_position
		var distance = to_other.length()
		if distance == 0:
			continue
		
		var min_distance = radius + other.radius
		if distance < min_distance:
			continue
		
		var direction = to_other / distance
		var force = gravitational_constant * (mass * other.mass) / pow(distance, 2)
		var acceleration = force / mass

		# Apply acceleration to velocity
		velocity += direction * acceleration * delta
=======
func force_g():
	for i in range(len(planets)):
		if i != get_index():
			var direction_g = position - planets[i].global_position
			velocity -= (direction_g.normalized()
							* planets[i].mass * 1e4/direction_g.length()**2)
>>>>>>> parent of 8500381 (f)
