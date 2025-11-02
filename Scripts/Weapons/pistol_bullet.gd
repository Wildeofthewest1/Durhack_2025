extends CharacterBody2D
class_name ProjectileBasic

@export var life_time: float = 2.0
@export var explosion: PackedScene = preload("res://Scenes/particles/explosion.tscn")

var _velocity_vec: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _life_timer: float = 0.0

func initialize_projectile(dir: Vector2, speed: float, dmg: float) -> void:
	# dir is world-space direction from the weapon toward the mouse
	# speed is muzzle velocity in pixels/sec
	# dmg is damage to apply on hit

	_velocity_vec = dir.normalized() * speed
	_damage = dmg
	_life_timer = life_time
	
	# set initial facing so it looks correct on frame 1
	if _velocity_vec.length() > 0.0:
		rotation = _velocity_vec.angle()

func _physics_process(delta: float) -> void:
	# move the bullet according to its stored velocity
	velocity = _velocity_vec
	move_and_slide()

	# rotate sprite so it always faces where it's actually going
	if _velocity_vec.length() > 0.0:
		global_rotation = _velocity_vec.angle()

	# lifetime countdown
	_life_timer -= delta
	if _life_timer <= 0.0:
		_spawn_explosion()
		queue_free()

	# TODO: collision, damage application, etc.

func _spawn_explosion() -> void:
	if explosion == null:
		return

	var explo: GPUParticles2D = explosion.instantiate() as GPUParticles2D
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.add_child(explo)
		explo.global_position = global_position
		explo.emitting = true
