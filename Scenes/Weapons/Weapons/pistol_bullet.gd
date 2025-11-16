extends CharacterBody2D
class_name ProjectileBasic

@export var life_time: float = 2.0
@export var explosion: PackedScene = preload("res://Scenes/particles/explosion.tscn")
@export var trail_particles: PackedScene = preload("res://Scenes/particles/trail_particles.tscn")

@export var trail_enabled: bool = true

var _velocity_vec: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _life_timer: float = 0.0

@onready var _trail: Line2D = $Trail as Line2D


func _ready() -> void:
	_life_timer = life_time
	if _trail != null:
		_trail.visible = trail_enabled
	var trailer: GPUParticles2D = trail_particles.instantiate() as GPUParticles2D
	get_parent().add_child(trailer)
	trailer.follower = self

func initialize_projectile(dir: Vector2, speed: float, dmg: float) -> void:
	_velocity_vec = dir.normalized() * speed
	_damage = dmg
	_life_timer = life_time

	if _velocity_vec.length() > 0.0:
		global_rotation = _velocity_vec.angle()
	

func _physics_process(delta: float) -> void:
	var collision: KinematicCollision2D = move_and_collide(_velocity_vec * delta)

	if collision != null:
		var target: Object = collision.get_collider()
		if target != null:
			if target.is_in_group("Enemy"):
				if target.has_method("take_damage"):
					target.take_damage(_damage)
			elif "team" in target:
				if String(target.team) == "Enemy" and target.has_method("take_damage"):
					target.take_damage(_damage)
		_spawn_explosion()
		queue_free()
		return

	if _velocity_vec.length() > 0.0:
		global_rotation = _velocity_vec.angle()

	_life_timer -= delta
	if _life_timer <= 0.0:
		_die()


func _spawn_explosion() -> void:
	if explosion == null:
		return

	var explo: GPUParticles2D = explosion.instantiate() as GPUParticles2D
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.add_child(explo)
		explo.global_position = global_position
		explo.emitting = true
		
func _die() -> void:
	_spawn_explosion()
	queue_free()
