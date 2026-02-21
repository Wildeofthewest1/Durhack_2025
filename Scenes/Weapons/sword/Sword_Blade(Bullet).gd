extends CharacterBody2D
class_name SwordBlade

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var life_time: float = 0.3
@export var explosion: PackedScene = preload("res://Scenes/particles/explosion.tscn")
@export var trail_particles: PackedScene = preload("res://Scenes/particles/trail_particles.tscn")
@export var trail_enabled: bool = true

@onready var _hitbox: Area2D = $Hitbox

@export var visual_rotation_offset_deg: float = 0.0
@export var face_aim_instead_of_velocity: bool = true

var _velocity_vec: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _life_timer: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _knockback: float = 100.0

@onready var _trail: Node = $Trail
@onready var _trail_line: Line2D = $Trail as Line2D

func _ready() -> void:
	_life_timer = life_time
	if _hitbox != null:
		_hitbox.body_entered.connect(_on_hitbox_body_entered)
	if _trail_line != null:
		_trail_line.visible = trail_enabled

	if trail_particles != null:
		var trailer: GPUParticles2D = trail_particles.instantiate() as GPUParticles2D
		get_parent().add_child(trailer)
		trailer.follower = self

	# Optional: safety
	if _sprite != null:
		_sprite.visible = true

func _on_hitbox_body_entered(body: Node) -> void:
	if body == null:
		return

	var is_enemy := false

	if body.is_in_group("Enemy"):
		is_enemy = true
	elif "team" in body:
		if String(body.team) == "Enemy":
			is_enemy = true

	if not is_enemy:
		return

	if body.has_method("take_damage"):
		body.take_damage(_damage, _aim_dir, _knockback)

func initialize_projectile(dir: Vector2, speed: float, dmg: float, carrier_vel: Vector2, knockback: float) -> void:
	_aim_dir = dir.normalized()
	_velocity_vec = _aim_dir * speed + carrier_vel
	_damage = dmg
	_life_timer = life_time
	_knockback = knockback

	# Seed the trail immediately at the projectile's CURRENT position (prevents (0,0) spike)
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

	rotation = facing_dir.angle() + offset_rad

func _physics_process(delta: float) -> void:
	var collision: KinematicCollision2D = move_and_collide(_velocity_vec * delta)

	move_and_collide(_velocity_vec * delta)

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
