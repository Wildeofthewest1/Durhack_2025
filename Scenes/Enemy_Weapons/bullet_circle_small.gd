extends Node2D
class_name BulletGroup

# This is the actual Bullet scene (your normal bullet.tscn)
@export var bullet_scene: PackedScene

# Group pattern params
@export var bullet_count: int = 8
@export var radius: float = 48.0
@export var orbit_speed: float = 2.0          # radians/sec
@export var face_outward: bool = true

# --- IMPORTANT: these fields exist so your weapon script can set them
@export var initial_speed: float = 300.0
@export var lifetime: float = 3.0
@export var team: String = ""                 # "Enemy", "Fleet", "player"

var direction: Vector2 = Vector2.UP
var inherited_velocity: Vector2 = Vector2.ZERO

# Internals
var _life_left: float = 0.0
var _angle_offset: float = 0.0
var _orbital_bullets: Array[Node2D] = []
var _world_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_life_left = lifetime
	_world_velocity = direction.normalized() * initial_speed + inherited_velocity
	_spawn_ring()
	_update_orbit_positions()

func _physics_process(delta: float) -> void:
	# Lifetime
	_life_left -= delta
	if _life_left <= 0.0:
		_die()
		return

	# Move like a normal bullet
	global_position += _world_velocity * delta

	# Orbit
	_angle_offset += orbit_speed * delta
	_update_orbit_positions()

func _spawn_ring() -> void:
	_orbital_bullets.clear()

	if bullet_scene == null:
		push_warning("BulletGroup: bullet_scene is null.")
		return

	for i: int in range(bullet_count):
		var b: Node = bullet_scene.instantiate()
		var b2d: Node2D = b as Node2D
		if b2d == null:
			push_warning("BulletGroup: bullet_scene must instance a Node2D-based bullet.")
			continue

		# Put bullets under the SAME parent as the group, so top_level works cleanly
		var parent_node: Node = get_parent()
		if parent_node == null:
			parent_node = self
		parent_node.add_child(b2d)

		# Make bullet independent of transforms; we drive its global_position manually
		b2d.top_level = true

		# Make the child bullet "dumb / stationary" (the group controls its position)
		# (Your bullet script will see initial_speed = 0 and direction = ZERO and won't move.)
		if "initial_speed" in b2d:
			b2d.initial_speed = 0.0
		if "direction" in b2d:
			b2d.direction = Vector2.ZERO
		if "inherited_velocity" in b2d:
			b2d.inherited_velocity = Vector2.ZERO

		# Team + lifetime forwarded (so collisions filter correctly, and bullets auto-die if you want)
		if "team" in b2d:
			b2d.team = team
		if "lifetime" in b2d:
			b2d.lifetime = lifetime

		_orbital_bullets.append(b2d)

func _update_orbit_positions() -> void:
	var n: int = _orbital_bullets.size()
	if n <= 0:
		return

	for i: int in range(n):
		var b: Node2D = _orbital_bullets[i]
		if b == null:
			continue

		var t: float = float(i) / float(n)
		var angle: float = TAU * t + _angle_offset
		var offset: Vector2 = Vector2.RIGHT.rotated(angle) * radius

		b.global_position = global_position + offset

		if face_outward:
			# outward-facing orientation
			b.global_rotation = (offset).angle() + deg_to_rad(90.0)
		else:
			# spin with orbit angle
			b.global_rotation = angle + deg_to_rad(90.0)

func _die() -> void:
	# Kill children we spawned
	for b: Node2D in _orbital_bullets:
		if b != null and is_instance_valid(b):
			b.queue_free()
	_orbital_bullets.clear()

	queue_free()
