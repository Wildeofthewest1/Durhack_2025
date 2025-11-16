extends CharacterBody2D

@export var mass: float = 1.0
@export var radius: float = 10.0
@export var gravitational_constant: float = 1

func _ready() -> void:
	add_to_group("Planets")

func _physics_process(delta: float) -> void:
	# Move using built-in velocity (CharacterBody2D property)
	_apply_gravity_to_other_planets(delta)
	move_and_slide()

func _apply_gravity_to_other_planets(delta):
	for other in get_tree().get_nodes_in_group("Planets"):
		if other == self:
			continue

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
