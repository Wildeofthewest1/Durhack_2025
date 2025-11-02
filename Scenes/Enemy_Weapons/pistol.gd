extends Node2D

@export var bullet_scene: PackedScene = preload("res://Scenes/Enemy_Weapons/bullet.tscn")
@export var fire_rate: float = 1.5  # seconds between shots
@export var rotation_speed: float = 1.0  # how fast the weapon rotates
@export var vision_cone_path: NodePath = "../../VisionCone"  # points to Enemy/VisionCone

var target: Node2D = null
var can_fire: bool = false
var owner_enemy: Node2D

@onready var timer: Timer = $FireTimer
@onready var cone: Area2D = get_node_or_null(vision_cone_path)

func _ready() -> void:
	print("🔫 Pistol ready:", name)

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

		# 🔹 Rotate pistol toward player (+90° sprite offset)
		global_rotation = lerp_angle(global_rotation, desired_angle - deg_to_rad(90), delta * rotation_speed)
	else:
		# 🔹 No target → smoothly rotate back to match enemy’s rotation
		if owner_enemy and is_instance_valid(owner_enemy):
			global_rotation = lerp_angle(global_rotation, owner_enemy.global_rotation, delta * rotation_speed * 0.8)

	# Keep vision cone fixed
	if cone:
		cone.rotation = 0


func _on_cone_body_entered(body: Node) -> void:
	print("👁️ Body entered cone:", body.name)
	if body.is_in_group("player"):
		target = body
		can_fire = true
		print("🎯 Target acquired:", target.name)
		timer.start()


func _on_cone_body_exited(body: Node) -> void:
	print("🚪 Body exited cone:", body.name)
	if body == target:
		print("❌ Lost target:", target.name)
		target = null
		can_fire = false


func _on_fire_timer_timeout() -> void:
	if can_fire and target and is_instance_valid(target):
		print("💥 Timer fired: Shooting at", target.name)
		_fire_bullet()


func _fire_bullet() -> void:
	if bullet_scene == null:
		push_error("❌ No bullet scene assigned to pistol!")
		return

	var bullet = bullet_scene.instantiate()

	# 🔹 Spawn bullet at the pistol’s *local* position
	bullet.position = position  # local to parent (Weapons)
	bullet.rotation = global_rotation  # keep world-facing rotation

	# Add bullet to same parent as pistol (so it spawns in correct local space)
	get_parent().add_child(bullet)

	# 🔹 Set bullet movement direction in world space
	bullet.direction = Vector2.RIGHT.rotated(global_rotation + deg_to_rad(90))

	print("🔸 Spawned bullet from", name, "at local pos:", position, "global rot:", global_rotation)
