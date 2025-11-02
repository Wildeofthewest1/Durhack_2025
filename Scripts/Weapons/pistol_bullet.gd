extends CharacterBody2D
class_name ProjectileBasic

@export var life_time: float = 2.0

var _velocity_vec: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _life_timer: float = 0.0

func initialize_projectile(dir: Vector2, speed: float, dmg: float) -> void:
	_velocity_vec = dir.normalized() * speed
	_damage = dmg
	rotation = dir.angle()
	_life_timer = life_time

func _physics_process(delta: float) -> void:
	velocity = _velocity_vec
	move_and_slide()

	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()

	# TODO: detect collisions, apply damage to enemies, etc.
