extends CharacterBody2D

@export var mass = 100.00
@export var initial_speed = 0
@export var initial_direction = Vector2.ZERO 


@export var autoorbit = false
@export var parent_star: CharacterBody2D #Add the host star of the system
@export var parent_planet: CharacterBody2D #Add planetary moons 

var gravity_scale = 1e3

func _ready():
	if not autoorbit:
		velocity = initial_speed * initial_direction
	if autoorbit and not is_in_group("Star"):
		#times 60 because of the physics framerate
		var speed = (60 * parent_star.mass * gravity_scale/(position - parent_star.position).length())**(0.5)
		print(speed)
		var direction = (position - parent_star.position).normalized()
		velocity = speed * direction.orthogonal()


func _process(_delta: float) -> void:
	#print(name, " ", (position - orbital_parent.position).length())
	if not is_in_group("Star"):
		print((position - parent_star.position).length())
		##print((orbital_parent.mass 
				##* 1e4 * 30/(position - orbital_parent.position).length())**(0.5))
		#pass
	pass
func _physics_process(delta: float) -> void:
	move_and_slide()
	force_g()

@onready var planets =  get_tree().get_nodes_in_group("Planets")
func force_g():
	for i in range(len(planets)):
		if i != get_index():
			var direction_g = position - planets[i].global_position
			velocity -= (direction_g.normalized()
							* planets[i].mass * gravity_scale/direction_g.length()**2)
