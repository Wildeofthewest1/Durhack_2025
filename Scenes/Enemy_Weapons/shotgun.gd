extends Node2D

@export var bullet_scene: PackedScene = preload("res://Scenes/Enemy_Weapons/bullet.tscn")
@export var fire_rate: float = 1.5
@export var rotation_speed: float = 10
@export var vision_cone_path: NodePath = "../../VisionCone"

# 🔹 Shotgun-specific settings
@export var pellet_count: int = 6
@export var spread_angle_deg: float = 30
@export var pellet_speed_variance: float = 0.2
@export var pellet_deceleration: float = 300
@export var pellet_lifetime: float = 1
@export var initial_speed: float = 400 #bullet speed

var target: Node2D = null
var can_fire: bool = false
var owner_body: CharacterBody2D
var target_groups: Array[String] = []

@onready var timer: Timer = $FireTimer
@onready var cone: Area2D = get_node_or_null(vision_cone_path)

func _ready() -> void:
	print("🔫 Shotgun ready:", name)

	# 🔹 Find owning CharacterBody2D (Weapons → CharacterBody2D)
	owner_body = get_parent().get_parent() as CharacterBody2D
	if owner_body == null:
		push_error("❌ Could not find owning CharacterBody2D for " + name)
		return

	# 🔹 Determine target groups
	if owner_body.is_in_group("Enemy"):
		target_groups = ["player", "Fleet"]
		# determine who owns this weapon
	elif owner_body.is_in_group("Fleet"):
		target_groups = ["Enemy"]
	else:
		push_warning("⚠️ Owner of " + name + " is not in 'Enemy' or 'Fleet' group.")
		target_groups = ["player"]

	print("🎯 Target groups for", name, ":", target_groups)

	# 🔹 Connect signals
	if cone:
		cone.connect("body_entered", Callable(self, "_on_cone_body_entered"))
		cone.connect("body_exited", Callable(self, "_on_cone_body_exited"))
	else:
		push_error("❌ Could not find VisionCone at path: " + str(vision_cone_path))

	timer.wait_time = fire_rate
	timer.connect("timeout", Callable(self, "_on_fire_timer_timeout"))
	timer.start()


func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		var dir = (target.global_position - global_position).normalized()
		var desired_angle = dir.angle()
		global_rotation = lerp_angle(global_rotation, desired_angle - deg_to_rad(90), delta * rotation_speed)
	else:
		if owner_body and is_instance_valid(owner_body):
			global_rotation = lerp_angle(global_rotation, owner_body.global_rotation, delta * rotation_speed * 0.8)

	if cone:
		cone.rotation = 0


var targets_in_cone: Array[Node2D] = []  # store all detected bodies

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
		_fire_shotgun_blast()

func _fire_shotgun_blast() -> void:
	if bullet_scene == null:
		return

	var half_spread := deg_to_rad(spread_angle_deg / 2.0)
	var spawn_origin: Vector2 = global_position
	var spawn_rotation: float = global_rotation

	for i in range(pellet_count):
		var bullet := bullet_scene.instantiate()
		
		# Identify the shooter
		var shooter = get_parent().get_parent()  # CharacterBody2D (enemy or drone)

		if shooter.is_in_group("Enemy"):
			bullet.team = "Enemy"
			#bullet.collision_layer = 6          # Enemy Bullets
			#bullet.collision_mask = 1 | 4       # Player + Fleet

		elif shooter.is_in_group("Fleet"):
			bullet.team = "Fleet"
			#bullet.collision_layer = 5          # Allied Bullets
			#bullet.collision_mask = 3           # Enemies

		elif shooter.is_in_group("player"):
			bullet.team = "player"
			#bullet.collision_layer = 5          # Allied Bullets
			#bullet.collision_mask = 3           # Enemies


		if "lifetime" in bullet:
			bullet.lifetime = pellet_lifetime

		var speed_factor := randf_range(1.0 - pellet_speed_variance, 1.0 + pellet_speed_variance)
		if "initial_speed" in bullet:
			bullet.initial_speed = initial_speed*speed_factor

		if "deceleration" in bullet:
			bullet.deceleration = pellet_deceleration
		
		var random_offset := randf_range(-half_spread, half_spread)
		bullet.direction = Vector2.RIGHT.rotated(spawn_rotation + deg_to_rad(90) + random_offset)
		
		add_child(bullet)
		bullet.position = spawn_origin
		bullet.global_rotation = spawn_rotation
		bullet.top_level = true

		
		
