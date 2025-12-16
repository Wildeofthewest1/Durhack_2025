extends Node2D
const InterceptMath = preload("PredictiveAim.gd")

@export var bullet_scene: PackedScene = preload("res://Scenes/Enemy_Weapons/bullet.tscn")
@export var fire_rate: float = 2.0
@export var rotation_speed: float = 10.0
@export var vision_cone_path: NodePath = "../../VisionCone"
@export var bullet_lifetime: float = 5
@export var initial_speed: float = 300 # bullet speed (muzzle speed relative to muzzle)

var target: Node2D = null
var can_fire: bool = false
var owner_body: CharacterBody2D
var target_groups: Array[String] = []
var targets_in_cone: Array[Node2D] = []

# --- muzzle kinematics (weapon node) ---
var muzzle_world_velocity: Vector2 = Vector2.ZERO
var _prev_muzzle_pos: Vector2
var _has_prev_muzzle_pos: bool = false

@onready var timer: Timer = $FireTimer
@onready var cone: Area2D = get_node_or_null(vision_cone_path)

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

	if cone:
		cone.connect("body_entered", Callable(self, "_on_cone_body_entered"))
		cone.connect("body_exited", Callable(self, "_on_cone_body_exited"))
	else:
		push_error("❌ Could not find VisionCone at path: " + str(vision_cone_path))

	timer.wait_time = fire_rate
	timer.connect("timeout", Callable(self, "_on_fire_timer_timeout"))
	timer.start()

	# Initialise muzzle tracking
	_prev_muzzle_pos = global_position
	_has_prev_muzzle_pos = true
	muzzle_world_velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	# --- update muzzle world velocity (includes translation + rotation) ---
	if _has_prev_muzzle_pos:
		muzzle_world_velocity = (global_position - _prev_muzzle_pos) / max(delta, 0.000001)
	_prev_muzzle_pos = global_position
	_has_prev_muzzle_pos = true
	#print("Muzzle world velocity:", muzzle_world_velocity)


	if target and is_instance_valid(target) and owner_body:
		var target_velocity := Vector2.ZERO
		if target is CharacterBody2D:
			target_velocity = target.velocity

		# Predict using muzzle position + muzzle world velocity
		var aim_dir := InterceptMath.get_intercept_direction(
			global_position,          # ✅ muzzle position
			muzzle_world_velocity,    # ✅ muzzle world velocity
			target.global_position,
			target_velocity,
			initial_speed
		)

		var desired_angle := aim_dir.angle()
		global_rotation = desired_angle - deg_to_rad(90)
		#lerp_angle(
		#	global_rotation,
		#	desired_angle - deg_to_rad(90),
		#	delta * rotation_speed
		#)
	else:
		if owner_body and is_instance_valid(owner_body):
			global_rotation = lerp_angle(
				global_rotation,
				owner_body.global_rotation,
				delta * rotation_speed * 0.8
			)

	if cone:
		cone.rotation = 0

func _on_cone_body_entered(body: Node) -> void:
	for group in target_groups:
		if body.is_in_group(group):
			targets_in_cone.append(body)
			_update_closest_target()
			break

func _on_cone_body_exited(body: Node) -> void:
	targets_in_cone.erase(body)
	if body == target:
		_update_closest_target()

func _update_closest_target() -> void:
	if targets_in_cone.is_empty():
		target = null
		can_fire = false
		return

	var closest: Node2D = null
	var min_dist: float = INF

	for candidate in targets_in_cone:
		if not is_instance_valid(candidate):
			continue
		var dist = global_position.distance_to(candidate.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = candidate

	target = closest
	can_fire = target != null
	if can_fire:
		timer.start()

func _on_fire_timer_timeout() -> void:
	if can_fire and target and is_instance_valid(target):
		_fire_bullet()

func _fire_bullet() -> void:
	if bullet_scene == null:
		return
	if owner_body == null or not is_instance_valid(owner_body):
		return
	if target == null or not is_instance_valid(target):
		return

	var spawn_origin: Vector2 = global_position
	var shooter_velocity: Vector2 = muzzle_world_velocity

	var target_velocity := Vector2.ZERO
	if target is CharacterBody2D:
		target_velocity = target.velocity

	# Predict using muzzle position + muzzle world velocity
	var aim_dir := InterceptMath.get_intercept_direction(
		spawn_origin,          # ✅ muzzle position
		shooter_velocity,      # ✅ muzzle world velocity
		target.global_position,
		target_velocity,
		initial_speed
	)

	var bullet := bullet_scene.instantiate()

	# Team
	if "team" in bullet:
		if owner_body.is_in_group("Enemy"):
			bullet.team = "Enemy"
		elif owner_body.is_in_group("Fleet"):
			bullet.team = "Fleet"
		elif owner_body.is_in_group("player"):
			bullet.team = "player"

	# Bullet parameters
	if "lifetime" in bullet:
		bullet.lifetime = bullet_lifetime
	if "initial_speed" in bullet:
		bullet.initial_speed = initial_speed

	# IMPORTANT: inherit muzzle world velocity (not just body.velocity)
	if "inherited_velocity" in bullet:
		bullet.inherited_velocity = shooter_velocity

	bullet.direction = aim_dir

	add_child(bullet)
	bullet.top_level = true
	bullet.global_position = spawn_origin
	bullet.global_rotation = aim_dir.angle()
