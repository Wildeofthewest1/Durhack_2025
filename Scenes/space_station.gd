extends CharacterBody2D

#Custom Intial Conditions
@export var mass = 100.00
@export var initial_speed = 0
@export var initial_direction = Vector2.ZERO 


@export var parent_planet: CharacterBody2D #Add planetary moons 
@export var autoorbit = true
var gravity_scale = 5e2

func _ready():
	if not autoorbit:
		velocity = initial_speed * initial_direction
	if autoorbit:
		var direction = (position - parent_planet.position)
		var planet_speed = parent_planet.velocity
		var speed = (60 * parent_planet.mass * gravity_scale/direction.length())**(0.5)
		velocity = speed * direction.normalized().orthogonal() + planet_speed


func _process(_delta: float) -> void:
	#print(name, " ", (position - orbital_parent.position).length())
	if not is_in_group("Star"):
		#print((position - parent_star.position).length())
		print(velocity.length())
		pass
	pass
func _physics_process(delta: float) -> void:
	move_and_slide()
	force_g()

@onready var planets =  get_tree().get_nodes_in_group("Planets")
func force_g():
	for i in range(len(planets)):
		if i != get_index():
			var direction_g = position - planets[i].global_position
			if direction_g.length() > 3:
				velocity -= (direction_g.normalized()
								* planets[i].mass * gravity_scale/direction_g.length()**2)
