extends Node2D

@export var planet_scene: PackedScene = preload("res://Scenes/Bodies/planet.tscn")
@onready var bodies_container: Node2D = get_node("../Environment/Bodies") # Adjust path if needede

func spawn_planet(
	position: Vector2,
	velocity: Vector2,
	mass: float,
	radius: float,
	colour: Color
) -> void:
	if planet_scene == null:
		push_error("❌ No planet scene assigned to PlanetSpawner.")
		return

	var planet: CharacterBody2D = planet_scene.instantiate()
	planet.global_position = position

	# ✅ Set properties
	if "velocity" in planet:
		planet.velocity = velocity
	if "mass" in planet:
		planet.mass = mass
	if "radius" in planet:
		planet.radius = radius

	# ✅ Scale the sprite here — works every time
	var sprite = planet.get_node("Sprite2D")
	var sprite_half_width = sprite.texture.get_width() / 2.0
	sprite.scale = Vector2.ONE * (radius / sprite_half_width)
	sprite.modulate = colour
	
	var minimap = planet.get_node("MinimapMark")
	minimap.dot_color = colour
	minimap.dot_size = radius/10

	# ✅ Add to scene after configuration
	bodies_container.add_child(planet)

	print("🪐 Spawned planet at:", position,
		  " | mass:", mass, " | radius:", radius)
