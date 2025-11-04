extends CharacterBody2D
class_name DroneFollower

@export var follow_body: Node2D = null         # who we orbit
@export var orbit_radius: float = 128.0
@export var orbit_speed: float = 1.0
@export var follow_lerp_speed: float = 5.0
@export var face_velocity: bool = true
@export var tangent_mode: bool = true
@export var rotation_speed: float = 6.0
@export var drone_name: String = "Drone"

@export var health: int = 200
@export var respawn_delay: float = 5.0         # ⏱ seconds before respawn

var _orbit_angle: float = 0.0
var _prev_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	FleetManager.register_drone(self)
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
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0, 0), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)


func die() -> void:
	print("%s has died" % name)

	FleetManager.unregister_drone(self)
	FleetManager.respawn_drone(global_position, follow_body, 5.0)

	queue_free()



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

	_orbit_angle += orbit_speed * delta
	if _orbit_angle > TAU:
		_orbit_angle -= TAU

	var orbit_offset: Vector2 = Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_radius
	var desired_pos: Vector2 = follow_body.global_position + orbit_offset
	var new_pos: Vector2 = global_position.lerp(desired_pos, follow_lerp_speed * delta)
	var frame_velocity: Vector2 = (new_pos - _prev_position) / delta

	global_position = new_pos

	if face_velocity:
		var desired_angle: float = rotation
		if tangent_mode:
			var tangent_vec: Vector2 = Vector2(-sin(_orbit_angle), cos(_orbit_angle))
			desired_angle = tangent_vec.angle()
		else:
			var speed_len: float = frame_velocity.length()
			if speed_len > 1.0:
				desired_angle = frame_velocity.angle()
		rotation = lerp_angle(rotation, desired_angle, rotation_speed * delta)

	_prev_position = global_position
