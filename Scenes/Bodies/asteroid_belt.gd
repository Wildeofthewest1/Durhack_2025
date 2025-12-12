extends Area2D

class_name AsteroidBelt

# Belt parameters
@export var inner_radius: float = 100.0
@export var outer_radius: float = 200.0
@export var damage_per_second: float = 10.0

# Visual parameters (for later drawing / shader)
@export var asteroid_count: int = 80
@export var asteroid_color_1: Color = Color(0.6, 0.5, 0.4, 1.0)
@export var asteroid_color_2: Color = Color(0.5, 0.4, 0.3, 1.0)
@export var asteroid_color_3: Color = Color(0.7, 0.6, 0.5, 1.0)
@export var base_transparency: float = 0.3

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# NEW: reference to the screen effect controller
var _belt_fx: AsteroidBeltScreenFX = null

var _bodies_in_belt: Array[Node2D] = []
var _asteroids: Array[Dictionary] = []
var _damage_timers: Dictionary = {}


func _ready() -> void:
	# Configure the outer collision circle
	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = outer_radius

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# NEW: find the screen FX node (CanvasLayer with AsteroidBeltScreenFX)
	_belt_fx = get_tree().get_first_node_in_group("asteroid_belt_fx") as AsteroidBeltScreenFX


func _physics_process(delta: float) -> void:
	_apply_damage_and_fx(delta)


# --- Enter / exit tracking ---

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if _bodies_in_belt.has(body) == false:
			_bodies_in_belt.append(body)
			_damage_timers[body] = 0.0

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_bodies_in_belt.erase(body)
		_damage_timers.erase(body)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		if _bodies_in_belt.has(area) == false:
			_bodies_in_belt.append(area)
			_damage_timers[area] = 0.0

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("player"):
		_bodies_in_belt.erase(area)
		_damage_timers.erase(area)


# --- Damage + FX System ---

func _apply_damage_and_fx(delta: float) -> void:
	var bodies_to_remove: Array[Node2D] = []
	var any_in_ring: bool = false

	for body: Node2D in _bodies_in_belt:
		if is_instance_valid(body) == false:
			bodies_to_remove.append(body)
			continue

		# ---- RING CHECK HERE ----
		var offset: Vector2 = body.global_position - global_position
		var distance: float = offset.length()

		var inside_outer: bool = distance <= outer_radius
		var outside_inner: bool = distance >= inner_radius
		var in_ring: bool = inside_outer and outside_inner

		if in_ring:
			any_in_ring = true

			_damage_timers[body] = _damage_timers.get(body, 0.0) + delta

			# Apply damage every 1 second (or change to continuous if you want)
			if _damage_timers[body] >= 1.0:
				_damage_timers[body] = 0.0
				_damage_body(body)
		else:
			# Optional: reset timer if outside ring
			_damage_timers[body] = 0.0

	for body: Node2D in bodies_to_remove:
		_bodies_in_belt.erase(body)
		_damage_timers.erase(body)

	# ---- SCREEN FX TOGGLE ----
	if _belt_fx != null:
		_belt_fx.set_inside_belt(any_in_ring)


func _damage_body(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage_per_second)
	elif body.has_method("damage"):
		body.damage(damage_per_second)
