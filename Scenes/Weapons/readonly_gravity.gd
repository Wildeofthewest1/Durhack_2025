extends Node2D
class_name GravityToParent2D

@export var gravitational_constant: float = 10000.0
@export var gravity_multiplier: float = 1.0
@export var planets_group_name: String = "Planets"

# Name of the velocity variable on the parent (ProjectileBasic uses _velocity_vec)
@export var velocity_property_name: String = "_velocity_vec"


func _physics_process(delta: float) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var origin: Vector2 = parent_node.global_position
	var accel: Vector2 = Vector2.ZERO

	var planet_list: Array = get_tree().get_nodes_in_group(planets_group_name)
	for planet in planet_list:
		# require planet.mass and planet.radius
		if not "mass" in planet or not "radius" in planet:
			continue

		var to_planet: Vector2 = planet.global_position - origin
		var distance: float = to_planet.length()
		if distance == 0.0:
			continue

		var min_distance: float = float(planet.radius)
		if distance < min_distance:
			continue

		var direction: Vector2 = to_planet / distance
		var mass_value: float = float(planet.mass)
		var distance_sq: float = distance * distance
		var force: float = gravitational_constant * gravity_multiplier * mass_value / distance_sq

		accel += direction * force

	# Apply acceleration to parent's velocity, if it has the requested property
	if velocity_property_name in parent_node:
		var current_vel_var: Variant = parent_node.get(velocity_property_name)
		if current_vel_var is Vector2:
			var current_vel: Vector2 = current_vel_var
			current_vel += accel * delta
			parent_node.set(velocity_property_name, current_vel)
	elif parent_node is CharacterBody2D:
		# Fallback: if parent uses built-in CharacterBody2D.velocity
		var body: CharacterBody2D = parent_node
		body.velocity += accel * delta
