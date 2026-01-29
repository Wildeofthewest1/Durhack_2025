extends Node2D

@export var debris_scene: PackedScene  # Drag your RandomDebris scene here
@export var spawn_count: int = 20
@export var inner_radius: float = 50.0
@export var outer_radius: float = 100.0
@export var spawn_on_ready: bool = true
@export var rotation_speed: float = 1.0  # Radians per second

func _ready() -> void:
	if spawn_on_ready:
		spawn_debris_in_ring()

func _process(delta: float) -> void:
	# Rotate the parent node (this rotates all children with it)
	rotation += rotation_speed * delta

func spawn_debris_in_ring() -> void:
	for i in range(spawn_count):
		spawn_random_debris()

func spawn_random_debris() -> void:
	if not debris_scene:
		push_error("No debris scene assigned!")
		return
	
	var debris: Area2D = debris_scene.instantiate()
	add_child(debris)
	
	# Random angle
	var angle: float = randf() * TAU
	
	# Random distance between inner and outer radius
	var distance: float = randf_range(inner_radius, outer_radius)
	
	# Position at random angle and distance
	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * distance
	debris.position = offset
	
	# Randomize the debris sprite
	var sprite: AnimatedSprite2D = debris.get_node("AnimatedSprite2D")
	if sprite and sprite.sprite_frames:
		var frame_count: int = sprite.sprite_frames.get_frame_count("default")
		if frame_count > 0:
			sprite.frame = randi() % frame_count
	
	# Optional: randomize rotation of individual debris pieces
	debris.rotation = randf() * TAU

func spawn_debris_at_position(world_pos: Vector2, count: int = 20, inner_r: float = 50.0, outer_r: float = 100.0) -> void:
	global_position = world_pos
	spawn_count = count
	inner_radius = inner_r
	outer_radius = outer_r
	spawn_debris_in_ring()
