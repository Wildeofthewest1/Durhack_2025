extends CharacterBody2D
class_name DroneFollower

@export var follow_body: Node2D = null
@export var orbit_radius: float = 128.0
@export var orbit_speed: float = 1.0
@export var follow_lerp_speed: float = 5.0
@export var face_velocity: bool = true
@export var tangent_mode: bool = true
@export var rotation_speed: float = 6.0
@export var drone_name: String = "Drone"

@export var health: int = 200
@export var respawn_delay: float = 5.0

@export var drone_type: String = ""     #

@export var uid: int = 0

@export var inner_radius: float = 60.0
@export var outer_radius: float = 160.0
@export var max_follow_speed: float = 300.0
@export var follow_force_scale: float = 0.00002   # tune this
@export var min_safe_speed: float = 50.0  # Drone never slows below this in safe zone
@export var damping: float = 0.95          # 0.90–0.99 recommended


var vel: Vector2 = Vector2.ZERO   # <--- replace use of CharacterBody2D velocity


var _orbit_angle: float = 0.0
var _prev_position: Vector2 = Vector2.ZERO
var _default_color: Color

func _ready() -> void:
	if has_node("Sprite2D"):
		var sprite: Sprite2D = $Sprite2D
		_default_color = sprite.modulate

	_prev_position = global_position
	attach_weapons()

func take_damage(amount: int) -> void:
	health -= amount
	print("%s took %d damage, remaining health: %d" % [name, amount, health])

	if has_node("Sprite2D"):
		var sprite: Sprite2D = $Sprite2D
		_flash_red(sprite)

	if health <= 0:
		die()

func _flash_red(sprite: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0, 0), 0.05)
	tween.tween_property(sprite, "modulate", _default_color, 0.1)

func die() -> void:
	print("%s has died" % name)
	FleetManager.drone_died(self)

func attach_weapons() -> void:
	var weapon_scenes = [
		preload("res://Scenes/Enemy_Weapons/Shotgun.tscn")
	]

	if not has_node("WeaponSlots"):
		push_warning("Fleet has no WeaponSlots node: " + str(name))
		return

	var weapon_slots = $WeaponSlots.get_children()

	if not has_node("Weapons"):
		var weapons_node = Node2D.new()
		weapons_node.name = "Weapons"
		add_child(weapons_node)

	for i in range(weapon_slots.size()):
		var weapon_scene = weapon_scenes[i % weapon_scenes.size()]
		var weapon = weapon_scene.instantiate()
		weapon.position = weapon_slots[i].position
		$Weapons.add_child(weapon)

func _physics_process(delta: float) -> void:
	if follow_body == null:
		_prev_position = global_position
		return

	var frame_velocity := Vector2.ZERO

	# =====================================================
	# ORBIT MODE
	# =====================================================
	if tangent_mode:
		_orbit_angle += orbit_speed * delta
		if _orbit_angle > TAU:
			_orbit_angle -= TAU

		var orbit_offset := Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_radius
		var desired_pos := follow_body.global_position + orbit_offset

		var new_pos := global_position.lerp(desired_pos, follow_lerp_speed * delta)
		frame_velocity = (new_pos - _prev_position) / delta
		global_position = new_pos

	# =====================================================
	# FORCE-BASED FOLLOW MODE
	# =====================================================
	else:
		# Vector from drone → target
		var to_target := follow_body.global_position - global_position
		var dist := to_target.length()

		# Normalized direction
		var dir := Vector2.ZERO
		if dist > 0.0001:
			dir = to_target / dist

		# ======================================================
		# OUTER ZONE → ATTRACT
		# ======================================================
		if dist > outer_radius:
			var force_mag: float = pow(dist, 3) * follow_force_scale
			var accel := dir * force_mag
			vel += accel * delta

		# ======================================================
		# INNER ZONE → REPULSE
		# ======================================================
		elif dist < inner_radius:
			#var safe_dist = max(dist, 1.0)  # avoid infinity explosion
			var force_mag: float = follow_force_scale
			var accel := -dir * 500  # negative = repulsion
			vel += accel * delta
			
		else:
			# damp velocity
			vel *= damping
			# if speed drops below the minimum, normalise to min speed
			var speed := vel.length()
			if speed < min_safe_speed and speed > 0.001:
				vel = vel.normalized() * min_safe_speed

		# Clamp maximum speed
		if vel.length() > max_follow_speed:
			vel = vel.normalized() * max_follow_speed

		# Integrate motion
		global_position += vel * delta
		frame_velocity = vel

	# =====================================================
	# ROTATION
	# =====================================================
	if face_velocity:
		var desired_angle := rotation

		if tangent_mode:
			var tangent_vec := Vector2(-sin(_orbit_angle), cos(_orbit_angle))
			tangent_vec = -tangent_vec           # face outward
			desired_angle = tangent_vec.angle()
		else:
			if frame_velocity.length() > 1.0:
				desired_angle = frame_velocity.angle() - PI/2

		rotation = lerp_angle(rotation, desired_angle, rotation_speed * delta)

	_prev_position = global_position
