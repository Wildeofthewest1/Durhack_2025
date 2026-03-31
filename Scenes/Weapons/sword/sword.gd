extends WeaponBase
class_name WeaponSword

@export var muzzle_path: NodePath = NodePath("Muzzle")
@export var spawn_offset_px: float = 30
@export var blade_scene: PackedScene
@export var blade_knockback: float = 100.0

var _muzzle: Node2D

func _ready() -> void:
	super._ready()
	_muzzle = get_node_or_null(muzzle_path) as Node2D
	_update_aim()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_aim()

func _update_aim() -> void:
	var mouse_world: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_world - global_position
	var dist: float = to_mouse.length()
	if dist > 0.0:
		_aim_dir = to_mouse / dist

func request_fire() -> void:
	try_fire(_aim_dir)

func _fire_projectile(dir: Vector2) -> void:
	if data == null:
		return

	if blade_scene == null:
		push_error("WeaponSword: blade_scene not assigned")
		return

	var spawn_origin: Vector2 = global_position
	if _muzzle != null:
		spawn_origin = _muzzle.global_position

	var proj: Node2D = blade_scene.instantiate() as Node2D
	if proj == null:
		push_error("WeaponSword: failed to instance blade_scene")
		return

	var world_root: Node = get_parent().get_parent().get_parent().get_parent()
	world_root.add_child(proj)

	var player_node = get_parent().get_parent().get_parent()
	player_node.global_position += -2.0 * dir.normalized()

	var fire_dir: Vector2 = dir.normalized()
	var spawn_pos: Vector2 = spawn_origin + fire_dir * spawn_offset_px
	proj.global_position = spawn_pos
	proj.rotation = fire_dir.angle()

	var dmg := float(data.damage)
	var move_speed := float(data.muzzle_velocity)
	var carrier_vel: Vector2 = player_node.velocity

	if proj.has_method("initialize_projectile"):
		proj.call("initialize_projectile", fire_dir, move_speed, dmg, carrier_vel, blade_knockback)
	else:
		push_error("WeaponSword: blade projectile missing initialize_projectile()")
