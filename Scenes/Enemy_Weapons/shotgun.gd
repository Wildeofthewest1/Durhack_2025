extends Node2D

@export var bullet_scene: PackedScene = preload("res://Scenes/Enemy_Weapons/bullet.tscn")
@export var fire_rate: float = 1.5  # seconds between shots
@export var rotation_speed: float = 1.0  # how fast the weapon rotates
@export var vision_cone_path: NodePath = "../../VisionCone"  # points to Enemy/VisionCone

# 🔹 Shotgun-specific settings
@export var pellet_count: int = 6           # Number of pellets per shot
@export var spread_angle_deg: float = 30  # Total spread (degrees)
@export var pellet_speed_variance: float = 0.2  # Optional random speed variance (10%)

@export var pellet_deceleration: float = 300
@export var pellet_lifetime: float = 1

var target: Node2D = null
var can_fire: bool = false
var owner_enemy: Node2D

@onready var timer: Timer = $FireTimer
@onready var cone: Area2D = get_node_or_null(vision_cone_path)

func _ready() -> void:
	if cone == null:
		push_error("❌ Could not find VisionCone at path: " + str(vision_cone_path))
	else:
		print("✅ Found VisionCone:", cone.name)
		cone.connect("body_entered", Callable(self, "_on_cone_body_entered"))
		cone.connect("body_exited", Callable(self, "_on_cone_body_exited"))

	timer.wait_time = fire_rate
	timer.connect("timeout", Callable(self, "_on_fire_timer_timeout"))
	timer.start()


func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		var dir = (target.global_position - global_position).normalized()
		var desired_angle = dir.angle()

		# 🔹 Rotate shotgun toward player (+90° sprite offset)
		global_rotation = lerp_angle(global_rotation, desired_angle - deg_to_rad(90), delta * rotation_speed)
	else:
		# 🔹 No target → smoothly rotate back to match enemy’s rotation
		if owner_enemy and is_instance_valid(owner_enemy):
			global_rotation = lerp_angle(global_rotation, owner_enemy.global_rotation, delta * rotation_speed * 0.8)

	# Keep vision cone fixed
	if cone:
		cone.rotation = 0


func _on_cone_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		target = body
		can_fire = true
		timer.start()


func _on_cone_body_exited(body: Node) -> void:
	if body == target:
		target = null
		can_fire = false


func _on_fire_timer_timeout() -> void:
	if can_fire and target and is_instance_valid(target):
		_fire_shotgun_blast()


func _fire_shotgun_blast() -> void:
	if bullet_scene == null:
		push_error("❌ No bullet scene assigned to shotgun!")
		return

	var half_spread := deg_to_rad(spread_angle_deg / 2.0)
	var spawn_origin: Vector2 = global_position
	var spawn_rotation: float = global_rotation

	print("🔫 Firing from", name, "at", spawn_origin)

	for i in range(pellet_count):
		var bullet := bullet_scene.instantiate()
		
		if "lifetime" in bullet:
			bullet.lifetime = pellet_lifetime
			
		var speed_factor := randf_range(1.0 - pellet_speed_variance, 1.0 + pellet_speed_variance)
		if "initial_speed" in bullet:
			bullet.initial_speed *= speed_factor

		# 🔹 Apply deceleration for shotgun pellets
		if "deceleration" in bullet:
			bullet.deceleration = pellet_deceleration
		
		# 🔹 Add bullet under the shotgun
		add_child(bullet)

		# 🔹 Set bullet position/rotation in world space
		bullet.position = spawn_origin
		bullet.global_rotation = spawn_rotation

		# 🔹 Prevent bullet from following shotgun rotation or movement
		bullet.top_level = true

		# 🔹 Add random spread for shotgun effect
		var random_offset := randf_range(-half_spread, half_spread)
		bullet.direction = Vector2.RIGHT.rotated(spawn_rotation + deg_to_rad(90) + random_offset)
		
	print("💥 Shotgun blast fired", pellet_count, "pellets from", name)
