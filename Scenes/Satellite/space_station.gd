#Space Station
extends CharacterBody2D

#Custom Intial Conditions
@export var initial_speed = 0
@export var initial_direction = Vector2.ZERO 

@export var autoorbit = true
@export var parent_planet: CharacterBody2D #Add planetary moons 
var gravity_scale = 7e2

func _ready():
	if not autoorbit:
		velocity = initial_speed * initial_direction
	if autoorbit:
		var direction = (position - parent_planet.global_position)
		var planet_speed = parent_planet.velocity
		var speed = (60 * parent_planet.mass * gravity_scale/direction.length())**(0.5)
		velocity = speed * direction.normalized().orthogonal() + planet_speed


func _process(_delta: float) -> void:
	#print(name, " ", (position - orbital_parent.position).length())
	pass
	
func _physics_process(delta: float) -> void:
	move_and_slide()
	force_g()

func force_g():
	var direction_g = global_position - parent_planet.global_position
	if direction_g.length() > 3:
		velocity -= (direction_g.normalized()
						* parent_planet.mass * gravity_scale/direction_g.length()**2)
