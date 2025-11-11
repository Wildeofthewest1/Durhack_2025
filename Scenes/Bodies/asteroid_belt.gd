extends Area2D

class_name AsteroidBelt

# Belt parameters
@export var inner_radius: float = 100.0
@export var outer_radius: float = 200.0
@export var damage_per_second: float = 10.0

# Visual parameters
@export var asteroid_count: int = 80
@export var asteroid_color_1: Color = Color(0.6, 0.5, 0.4, 1.0)
@export var asteroid_color_2: Color = Color(0.5, 0.4, 0.3, 1.0)
@export var asteroid_color_3: Color = Color(0.7, 0.6, 0.5, 1.0)
@export var base_transparency: float = 0.3

# Private variables
var _bodies_in_belt: Array[Node2D] = []
var _asteroids: Array[Dictionary] = []
var _damage_timers: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_generate_asteroids()
	_update_shader_asteroids()

func _physics_process(delta: float) -> void:
	_apply_damage(delta)

# --- Asteroid Generation ---

func _generate_asteroids() -> void:
	_asteroids.clear()
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	
	for i: int in range(asteroid_count):
		var angle: float = rng.randf() * TAU
		var radius: float = randf_range(inner_radius, outer_radius)
		var position: Vector2 = Vector2.from_angle(angle) * radius
		
		var size: float = randf_range(2.0, 8.0)
		var color_index: int = rng.randi_range(0, 2)
		var color: Color = _get_asteroid_color(color_index)
		var rotation: float = rng.randf() * TAU
		
		_asteroids.append({
			"position": position,
			"size": size,
			"color": color,
			"rotation": rotation,
			"color_index": color_index
		})

func _get_asteroid_color(index: int) -> Color:
	match index:
		0:
			return asteroid_color_1
		1:
			return asteroid_color_2
		_:
			return asteroid_color_3

func _update_shader_asteroids() -> void:
	if _asteroids.is_empty():
		return
	
	var mat: Material = $"ColorRect".get_material()
	if mat is not ShaderMaterial:
		return
	
	# Pass asteroid data to shader
	var asteroid_positions: PackedVector2Array = PackedVector2Array()
	var asteroid_sizes: PackedColorArray = PackedColorArray()
	var asteroid_colors: PackedColorArray = PackedColorArray()
	
	for asteroid: Dictionary in _asteroids:
		asteroid_positions.append(asteroid["position"])
		asteroid_sizes.append(Color(asteroid["size"], asteroid["rotation"], 0.0, 0.0))
		asteroid_colors.append(asteroid["color"])
	
	mat.set_shader_parameter("asteroid_count", len(_asteroids))
	mat.set_shader_parameter("asteroid_positions", asteroid_positions)
	mat.set_shader_parameter("asteroid_sizes", asteroid_sizes)
	mat.set_shader_parameter("asteroid_colors", asteroid_colors)
	mat.set_shader_parameter("inner_radius", inner_radius)
	mat.set_shader_parameter("outer_radius", outer_radius)
	mat.set_shader_parameter("base_transparency", base_transparency)

# --- Collision Handling ---

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_bodies_in_belt.append(body)
		_damage_timers[body] = 0.0

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_bodies_in_belt.erase(body)
		_damage_timers.erase(body)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		_bodies_in_belt.append(area)
		_damage_timers[area] = 0.0

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("player"):
		_bodies_in_belt.erase(area)
		_damage_timers.erase(area)

# --- Damage System ---

func _apply_damage(delta: float) -> void:
	var bodies_to_remove: Array[Node2D] = []
	
	for body: Node2D in _bodies_in_belt:
		if not is_instance_valid(body):
			bodies_to_remove.append(body)
			continue
		
		_damage_timers[body] = _damage_timers.get(body, 0.0) + delta
		
		if _damage_timers[body] >= 1.0:
			_damage_timers[body] = 0.0
			_damage_body(body)
	
	for body: Node2D in bodies_to_remove:
		_bodies_in_belt.erase(body)
		_damage_timers.erase(body)

func _damage_body(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage_per_second)
	elif body.has_method("damage"):
		body.damage(damage_per_second)
