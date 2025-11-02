extends CharacterBody2D

@export var mass = 10000
@export var initial_velocity = 0.00
@export var initial_direction = Vector2.ZERO
@export var auto_orbit = false

@export var orbital_parent: CharacterBody2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not auto_orbit:
		velocity = initial_velocity * initial_direction 
	if auto_orbit:
		var central_direction = (position - orbital_parent.position).normalized()
		var autospeed = (orbital_parent.mass * 1e3)/(position - orbital_parent.position).length()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func _physics_process(delta: float) -> void:
	move_and_slide()
	force_g()

@onready var planets = get_tree().get_nodes_in_group("Planets") #calls the group with planets
func force_g():
	for i in range(len(planets)):
		if i != get_index():
			var direction_g = (global_position - planets[i].global_position)
			velocity -= (direction_g.normalized() 
							* planets[i].mass *1e3/direction_g.length()**2)
			
			
		
