extends ColorRect
class_name AsteroidBeltScreenFX

@export var max_tracked_craters: int = 32
@export var spawn_interval: float = 0.7
@export var min_radius: float = 0.08
@export var max_radius: float = 0.25
@export var min_strength: float = 0.3
@export var max_strength: float = 1.0

@export var intensity_rise_speed: float = 2.0
@export var intensity_fall_speed: float = 2.5
@export var min_spawn_distance_from_center: float = 0.25

# If true, always behave as if inside the belt (for testing)
@export var debug_always_on: bool = false

var _shader_material: ShaderMaterial
var _inside_belt: bool = false
var _timer: float = 0.0

var _centers: Array[Vector2] = []
var _radii: Array[float] = []
var _strengths: Array[float] = []


func _ready() -> void:
	_shader_material = material as ShaderMaterial
	if _shader_material == null:
		push_error("AsteroidBeltScreenFX: ShaderMaterial missing on ColorRect.")
		return

	add_to_group("asteroid_belt_fx")

	_shader_material.set_shader_parameter("global_intensity", 0.0)
	_shader_material.set_shader_parameter("active_craters", 0)

	_timer = spawn_interval

	if debug_always_on:
		_inside_belt = true
		for i in range(0, 4):
			_add_random_crater()
		_shader_material.set_shader_parameter("global_intensity", 1.0)


func set_inside_belt(is_inside: bool) -> void:
	_inside_belt = is_inside


func _process(delta: float) -> void:
	if _shader_material == null:
		return

	# --- crater spawning / decay ---
	if _inside_belt or debug_always_on:
		_timer -= delta
		if _timer <= 0.0:
			_timer += spawn_interval
			_add_random_crater()
	else:
		# Optional: slowly clear history when outside
		if _centers.size() > 0:
			var remove_chance: float = delta * 0.5
			if remove_chance > 1.0:
				remove_chance = 1.0
			var roll: float = randf()
			if roll < remove_chance:
				_centers.pop_front()
				_radii.pop_front()
				_strengths.pop_front()

	# --- intensity fade ---
	var current_intensity: float = float(_shader_material.get_shader_parameter("global_intensity"))
	var target_intensity: float = 1.0
	if _inside_belt == false and debug_always_on == false:
		target_intensity = 0.0

	var speed: float = intensity_rise_speed
	if target_intensity < current_intensity:
		speed = intensity_fall_speed

	var new_intensity: float = lerp(current_intensity, target_intensity, delta * speed)
	_shader_material.set_shader_parameter("global_intensity", new_intensity)

	# --- push data for the 4 latest craters to the shader ---
	_sync_first_four_to_shader()


func _add_random_crater() -> void:
	if _centers.size() >= max_tracked_craters:
		_centers.pop_front()
		_radii.pop_front()
		_strengths.pop_front()

	var center: Vector2 = Vector2.ZERO
	var tries: int = 0
	var max_tries: int = 8
	var accepted: bool = false

	while accepted == false and tries < max_tries:
		# Random UV on screen
		center = Vector2(randf(), randf())

		# Distance from screen center (0.5, 0.5) in UV space
		var to_center: Vector2 = center - Vector2(0.5, 0.5)
		var dist: float = to_center.length()

		# Accept only if outside minimum spawn distance
		if dist >= min_spawn_distance_from_center:
			accepted = true

		tries += 1

	# If it fails all tries, it will just use the last generated center,
	# which is fine and rare.

	var radius: float = randf_range(min_radius, max_radius)
	var strength: float = randf_range(min_strength, max_strength)

	_centers.append(center)
	_radii.append(radius)
	_strengths.append(strength)

func _sync_first_four_to_shader() -> void:
	if _shader_material == null:
		return

	var count: int = _centers.size()
	if count > 4:
		count = 4

	_shader_material.set_shader_parameter("active_craters", count)

	if count >= 1:
		var idx0: int = _centers.size() - 1
		_shader_material.set_shader_parameter("crater_center0", _centers[idx0])
		_shader_material.set_shader_parameter("crater_radius0", _radii[idx0])
		_shader_material.set_shader_parameter("crater_strength0", _strengths[idx0])

	if count >= 2:
		var idx1: int = _centers.size() - 2
		_shader_material.set_shader_parameter("crater_center1", _centers[idx1])
		_shader_material.set_shader_parameter("crater_radius1", _radii[idx1])
		_shader_material.set_shader_parameter("crater_strength1", _strengths[idx1])

	if count >= 3:
		var idx2: int = _centers.size() - 3
		_shader_material.set_shader_parameter("crater_center2", _centers[idx2])
		_shader_material.set_shader_parameter("crater_radius2", _radii[idx2])
		_shader_material.set_shader_parameter("crater_strength2", _strengths[idx2])

	if count >= 4:
		var idx3: int = _centers.size() - 4
		_shader_material.set_shader_parameter("crater_center3", _centers[idx3])
		_shader_material.set_shader_parameter("crater_radius3", _radii[idx3])
		_shader_material.set_shader_parameter("crater_strength3", _strengths[idx3])
