extends CharacterBody2D
class_name ProjectileBasic

@export var life_time: float = 2.0
@export var explosion: PackedScene = preload("res://Scenes/particles/explosion.tscn")
@export var trail_particles: PackedScene = preload("res://Scenes/particles/trail_particles.tscn")
@export var trail_enabled: bool = true

@export var visual_rotation_offset_deg: float = 0.0

# IMPORTANT: default false to preserve your old behaviour (face travel direction)
@export var face_aim_instead_of_velocity: bool = false

var _velocity_vec: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _life_timer: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _knockback: float = 100.0

@onready var _trail: Node = $Trail
@onready var _trail_line: Line2D = $Trail as Line2D

func _ready() -> void:
	_life_timer = life_time
	if _trail_line != null:
		_trail_line.visible = trail_enabled

	if trail_particles != null:
		var trailer: GPUParticles2D = trail_particles.instantiate() as GPUParticles2D
		get_parent().add_child(trailer)
		trailer.follower = self

func initialize_projectile(dir: Vector2, speed: float, dmg: float, carrier_vel: Vector2,knockback:float) -> void:
	_aim_dir = dir.normalized()
	_velocity_vec = _aim_dir * speed + carrier_vel
	_damage = dmg
	_life_timer = life_time
	_knockback = knockback

	# Seed the trail immediately at the bullet's CURRENT position (prevents (0,0) spike)
	# Requires your Trail script to have reset_to_world_pos(p)
	if _trail != null and _trail.has_method("reset_to_world_pos"):
		_trail.call("reset_to_world_pos", global_position)

	_update_facing()

func _update_facing() -> void:
	var offset_rad: float = deg_to_rad(visual_rotation_offset_deg)

	var facing_dir: Vector2 = _velocity_vec
	if face_aim_instead_of_velocity:
		facing_dir = _aim_dir

	if facing_dir.length() <= 0.001:
		return

	# Use local rotation (more stable than global_rotation)
	rotation = facing_dir.angle() + offset_rad

func _physics_process(delta: float) -> void:
	var collision: KinematicCollision2D = move_and_collide(_velocity_vec * delta)

	if collision != null:
		var target: Object = collision.get_collider()
		if target != null:
			if target.is_in_group("Enemy"):
				if target.has_method("take_damage"):
					target.take_damage(_damage,Vector2.RIGHT.rotated(global_rotation),_knockback)
			elif "team" in target:
				if String(target.team) == "Enemy" and target.has_method("take_damage"):
					target.take_damage(_damage,Vector2.RIGHT.rotated(global_rotation),_knockback)
		_spawn_explosion()
		queue_free()
		return

	# Only rotate in ONE place (no competing global_rotation assignment)
	_update_facing()

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
		explo.global_rotation = global_rotation
		explo.emitting = true

func _die() -> void:
	_spawn_explosion()
	queue_free()
