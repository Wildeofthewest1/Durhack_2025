extends CharacterBody2D
class_name Bullet

@export var initial_speed: float = 300.0
@export var lifetime: float = 3.0
@export var deceleration: float = 0.0

@export var damage: int = 10
@export var health: float = 1.0

# Movement extras
@export var gravity_multiplier: float = 0.0
@export var gravitational_constant: float = 100000.0

# Collision / behavior
@export var team: String = "" # "Enemy", "Fleet", "player"
@export var destroy_on_hit: bool = true
@export var pierce_count: int = 0        # how many *extra* bodies we can pass through
@export var bounce_count: int = 0        # how many bounces off walls (requires slide collisions)
@export var hit_cooldown: float = 0.05   # seconds before the same target can be hit again

# Optional FX
@export var explosion: PackedScene = preload("res://Scenes/particles/explosion.tscn")

# Injected by spawner/group
var direction: Vector2 = Vector2.UP
var inherited_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox

var _life_left: float = 0.0
var _remaining_pierce: int = 0
var _remaining_bounce: int = 0
var _hit_cooldowns: Dictionary = {} # ObjectID -> float

func _ready() -> void:
	_life_left = lifetime
	_remaining_pierce = pierce_count
	_remaining_bounce = bounce_count

	velocity = direction.normalized() * initial_speed + inherited_velocity

	if hitbox != null:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	# Lifetime
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return

	# Decay hit cooldowns
	_update_hit_cooldowns(delta)

	# Optional gravity (Planets group with mass/radius)
	if gravity_multiplier > 0.0:
		_apply_planet_gravity(delta)

	# Optional deceleration
	if deceleration > 0.0:
		var s: float = velocity.length()
		s = max(s - deceleration * delta, 0.0)
		if s > 0.0:
			velocity = velocity.normalized() * s
		else:
			velocity = Vector2.ZERO

	# Move
	var prev_velocity: Vector2 = velocity
	move_and_slide()

	# Bounce using slide collisions (walls etc.)
	if _remaining_bounce > 0:
		var count: int = get_slide_collision_count()
		if count > 0:
			var col: KinematicCollision2D = get_slide_collision(0)
			if col != null:
				var n: Vector2 = col.get_normal()
				velocity = prev_velocity.bounce(n)
				_remaining_bounce -= 1

	# Face travel direction
	if velocity.length() > 0.01:
		rotation = velocity.angle() + deg_to_rad(-90.0)

func take_damage(amount: int, hit_from_world: Variant = null, knockback_strength: Variant = null) -> void:
	health -= float(amount)
	if health <= 0.0:
		_die()

func _die() -> void:
	queue_free()

# -------------------------
# Collision handling (Area2D)
# -------------------------

func _on_hitbox_body_entered(body: Node) -> void:
	_try_hit_target(body)

func _on_hitbox_area_entered(area: Area2D) -> void:
	# If you have hurtboxes as Area2D, you can hit their owner.
	if area == null:
		return
	var owner_node: Node = area.get_owner()
	if owner_node != null:
		_try_hit_target(owner_node)

func _try_hit_target(target: Node) -> void:
	if target == null:
		return
	if not is_instance_valid(target):
		return
	if target == self:
		return

	# Filter friendly fire
	if _is_friendly(target):
		return

	# Prevent rapid multi-hits on overlap
	var id: int = int(target.get_instance_id())
	if _hit_cooldowns.has(id):
		return
	_hit_cooldowns[id] = hit_cooldown

	# Apply damage
	if target.has_method("take_damage"):
		target.call("take_damage", damage)

	_spawn_explosion()

	# Decide whether to die / pierce
	if destroy_on_hit:
		if _remaining_pierce > 0:
			_remaining_pierce -= 1
		else:
			queue_free()

func _is_friendly(target: Node) -> bool:
	# Team vs groups mapping (tweak to your actual groups)
	if team == "Enemy":
		if target.is_in_group("Enemy"):
			return true
	if team == "Fleet":
		if target.is_in_group("Fleet") or target.is_in_group("player"):
			return true
	if team == "player":
		if target.is_in_group("player") or target.is_in_group("Fleet"):
			return true
	return false

# -------------------------
# Helpers
# -------------------------

func _update_hit_cooldowns(delta: float) -> void:
	if _hit_cooldowns.size() == 0:
		return

	var to_remove: Array[int] = []
	for k: Variant in _hit_cooldowns.keys():
		var id: int = int(k)
		var t: float = float(_hit_cooldowns[id]) - delta
		if t <= 0.0:
			to_remove.append(id)
		else:
			_hit_cooldowns[id] = t

	for id: int in to_remove:
		_hit_cooldowns.erase(id)

func _apply_planet_gravity(delta: float) -> void:
	var planets: Array[Node] = get_tree().get_nodes_in_group("Planets")
	for p: Node in planets:
		# Expect: p.mass (float), p.radius (float)
		if not ("mass" in p and "radius" in p):
			continue

		var to_planet: Vector2 = (p as Node2D).global_position - global_position
		var dist: float = to_planet.length()
		if dist <= 0.001:
			continue

		var radius: float = float(p.radius)
		if dist < radius:
			continue

		var g_dir: Vector2 = to_planet / dist
		var denom: float = dist * dist
		var force: float = gravitational_constant * gravity_multiplier * float(p.mass) / denom
		velocity += g_dir * force * delta

func _spawn_explosion() -> void:
	if explosion == null:
		return
	var node: Node = explosion.instantiate()
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	parent_node.add_child(node)

	# Support either GPUParticles2D or a Node2D scene
	if node is Node2D:
		(node as Node2D).global_position = global_position

	if node is GPUParticles2D:
		var p: GPUParticles2D = node as GPUParticles2D
		p.emitting = true
