extends Node2D
const InterceptMath = preload("PredictiveAim.gd")

@export var bullet_scene: PackedScene = preload("res://Scenes/Enemy_Weapons/bullet.tscn")
@export var fire_rate: float = 2.0
@export var rotation_speed: float = 10.0
@export var vision_cone_path: NodePath = "../../VisionCone"
@export var bullet_lifetime: float = 5.0
@export var initial_speed: float = 300.0

# --- TELEGRAPH (AnimatedSprite2D) ---
@export var telegraph_time: float = 0.35
@export var telegraph_anim: StringName = &"telegraph"
@export var telegraph_idle_anim: StringName = &"idle"
@export var telegraph_sprite_path: NodePath = NodePath("TelegraphSprite")
@export var telegraph_show_only_when_aiming: bool = true

var target: Node2D = null
var can_fire: bool = false
var owner_body: CharacterBody2D
var target_groups: Array[String] = []
var targets_in_cone: Array[Node2D] = []

# --- muzzle kinematics ---
var muzzle_world_velocity: Vector2 = Vector2.ZERO
var _prev_muzzle_pos: Vector2 = Vector2.ZERO
var _has_prev_muzzle_pos: bool = false

# Telegraph state
var _is_telegraphing: bool = false

@onready var timer: Timer = $FireTimer
@onready var cone: Area2D = get_node_or_null(vision_cone_path) as Area2D
@onready var telegraph_sprite: AnimatedSprite2D = get_node_or_null(telegraph_sprite_path) as AnimatedSprite2D

func _ready() -> void:
	owner_body = get_parent().get_parent() as CharacterBody2D
	if owner_body == null:
		push_error("❌ Could not find owning CharacterBody2D for " + name)
		return

	if owner_body.is_in_group("Enemy"):
		target_groups = ["player", "Fleet"]
	elif owner_body.is_in_group("Fleet"):
		target_groups = ["Enemy"]
	else:
		target_groups = ["player"]

	if cone != null:
		cone.body_entered.connect(_on_cone_body_entered)
		cone.body_exited.connect(_on_cone_body_exited)
	else:
		push_error("❌ Could not find VisionCone at path: " + str(vision_cone_path))

	timer.wait_time = fire_rate
	timer.timeout.connect(_on_fire_timer_timeout)
	timer.start()

	_prev_muzzle_pos = global_position
	_has_prev_muzzle_pos = true
	muzzle_world_velocity = Vector2.ZERO

	if telegraph_sprite != null:
		telegraph_sprite.visible = false
		telegraph_sprite.stop()

func _physics_process(delta: float) -> void:
	# --- update muzzle world velocity ---
	if _has_prev_muzzle_pos:
		muzzle_world_velocity = (global_position - _prev_muzzle_pos) / max(delta, 0.000001)
	_prev_muzzle_pos = global_position
	_has_prev_muzzle_pos = true

	# Aim
	if target != null and is_instance_valid(target) and owner_body != null:
		var target_velocity: Vector2 = Vector2.ZERO
		if target is CharacterBody2D:
			target_velocity = (target as CharacterBody2D).velocity

		var aim_dir: Vector2 = InterceptMath.get_intercept_direction(
			global_position,
			muzzle_world_velocity,
			target.global_position,
			target_velocity,
			initial_speed
		)

		var desired_angle: float = aim_dir.angle()
		global_rotation = desired_angle - deg_to_rad(90.0)
	else:
		if owner_body != null and is_instance_valid(owner_body):
			global_rotation = lerp_angle(
				global_rotation,
				owner_body.global_rotation,
				delta * rotation_speed * 0.8
			)

	if cone != null:
		cone.rotation = 0.0

	# Optional: hide telegraph sprite when not aiming (unless mid-telegraph)
	if telegraph_sprite != null and telegraph_show_only_when_aiming and not _is_telegraphing:
		telegraph_sprite.visible = can_fire and target != null and is_instance_valid(target)

func _on_cone_body_entered(body: Node) -> void:
	for group: String in target_groups:
		if body.is_in_group(group):
			var n: Node2D = body as Node2D
			if n != null:
				targets_in_cone.append(n)
			_update_closest_target()
			break

func _on_cone_body_exited(body: Node) -> void:
	targets_in_cone.erase(body as Node2D)
	if body == target:
		_update_closest_target()

func _update_closest_target() -> void:
	if targets_in_cone.is_empty():
		target = null
		can_fire = false
		return

	var closest: Node2D = null
	var min_dist: float = INF

	for candidate: Node2D in targets_in_cone:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var dist: float = global_position.distance_to(candidate.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = candidate

	target = closest
	can_fire = target != null
	if can_fire:
		timer.start()

func _on_fire_timer_timeout() -> void:
	if _is_telegraphing:
		return
	if can_fire and target != null and is_instance_valid(target):
		_start_telegraph_then_fire()

func _start_telegraph_then_fire() -> void:
	_is_telegraphing = true

	if telegraph_sprite != null:
		telegraph_sprite.visible = true
		if telegraph_sprite.sprite_frames != null and telegraph_sprite.sprite_frames.has_animation(telegraph_anim):
			telegraph_sprite.play(telegraph_anim)
		else:
			telegraph_sprite.play()

	await get_tree().create_timer(telegraph_time).timeout

	# Cancel if lost target
	if not can_fire:
		_end_telegraph()
		_is_telegraphing = false
		return
	if target == null or not is_instance_valid(target):
		_end_telegraph()
		_is_telegraphing = false
		return

	_fire_bullet()

	_end_telegraph()
	_is_telegraphing = false

func _end_telegraph() -> void:
	if telegraph_sprite == null:
		return

	if telegraph_sprite.sprite_frames != null and telegraph_sprite.sprite_frames.has_animation(telegraph_idle_anim):
		telegraph_sprite.play(telegraph_idle_anim)
		telegraph_sprite.visible = false
	else:
		telegraph_sprite.stop()
		telegraph_sprite.visible = false

func _fire_bullet() -> void:
	if bullet_scene == null:
		return
	if owner_body == null or not is_instance_valid(owner_body):
		return
	if target == null or not is_instance_valid(target):
		return

	var spawn_origin: Vector2 = global_position
	var shooter_velocity: Vector2 = muzzle_world_velocity

	var target_velocity: Vector2 = Vector2.ZERO
	if target is CharacterBody2D:
		target_velocity = (target as CharacterBody2D).velocity

	var aim_dir: Vector2 = InterceptMath.get_intercept_direction(
		spawn_origin,
		shooter_velocity,
		target.global_position,
		target_velocity,
		initial_speed
	)

	var bullet: Node = bullet_scene.instantiate()

	# Identify shooter
	var shooter: Node = get_parent().get_parent()

	if "team" in bullet:
		if shooter.is_in_group("Enemy"):
			bullet.team = "Enemy"
			if "col" in bullet:
				bullet.col = Color("ff1212")
			if "glowcol" in bullet:
				bullet.glowcol = Color("ff121214")
		elif shooter.is_in_group("Fleet"):
			bullet.team = "Fleet"
			if "col" in bullet:
				bullet.col = Color("5dff76ff")
			if "glowcol" in bullet:
				bullet.glowcol = Color("5dff7614")
		elif shooter.is_in_group("player"):
			bullet.team = "player"

	if "lifetime" in bullet:
		bullet.lifetime = bullet_lifetime
	if "initial_speed" in bullet:
		bullet.initial_speed = initial_speed
	if "inherited_velocity" in bullet:
		bullet.inherited_velocity = shooter_velocity
	if "direction" in bullet:
		bullet.direction = aim_dir

	add_child(bullet)
	if bullet is Node2D:
		var b2d: Node2D = bullet as Node2D
		b2d.top_level = true
		b2d.global_position = spawn_origin
		b2d.global_rotation = aim_dir.angle()
