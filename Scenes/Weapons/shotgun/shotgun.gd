# WeaponShotgun.gd
extends WeaponBase
class_name WeaponShotgun

@export var muzzle_path: NodePath = NodePath("Muzzle")
@export var spawn_offset_px: float = 20.0

# Shotgun-specific
@export var pellets_per_shot: int = 8
@export var pellet_spread_deg: float = 10.0   # extra spread around base direction

var _muzzle: Node2D


func _ready() -> void:
	super._ready()
	_muzzle = get_node(muzzle_path) as Node2D


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_aim()


func _update_aim() -> void:
	var mouse_world: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_world - global_position
	var dist: float = to_mouse.length()
	if dist > 0.0:
		_aim_dir = to_mouse / dist
	# rotation handled by parent (socket / player)


func request_fire() -> void:
	# WeaponManager calls this while fire is held
	try_fire(_aim_dir)


func _fire_projectile(dir: Vector2) -> void:
	if data == null:
		return
	if _muzzle == null:
		push_error("WeaponShotgun: muzzle is missing")
		return
	if data.bullet_scene == null:
		push_error("WeaponShotgun: bullet_scene not set in WeaponData")
		return

	# base cone from data.spread_deg, extra from pellet_spread_deg
	var base_half_spread: float = data.spread_deg * 0.5
	var pellet_half_spread: float = pellet_spread_deg * 0.5

	for i in range(pellets_per_shot):
		_spawn_pellet(dir, base_half_spread, pellet_half_spread)

	# one common muzzle flash
	if data.flash_scene != null:
		var flash_instance: Node2D = data.flash_scene.instantiate() as Node2D
		_muzzle.add_child(flash_instance)
		flash_instance.position = Vector2.ZERO
		flash_instance.rotation = 0.0
		flash_instance.scale = Vector2(1.0, 1.0)


func _spawn_pellet(base_dir: Vector2, base_half_spread: float, pellet_half_spread: float) -> void:
	var world_root: Node = get_parent().get_parent().get_parent().get_parent()

	var proj: Node2D = data.bullet_scene.instantiate() as Node2D
	world_root.add_child(proj)

	# random spread: global cone (data.spread_deg) + per-pellet jitter
	var spread_deg_total: float = randf_range(-base_half_spread, base_half_spread) \
		+ randf_range(-pellet_half_spread, pellet_half_spread)
	var spread_rad: float = deg_to_rad(spread_deg_total)
	var fire_dir: Vector2 = base_dir.rotated(spread_rad).normalized()

	var spawn_pos: Vector2 = _muzzle.global_position + fire_dir * spawn_offset_px
	proj.global_position = spawn_pos
	proj.rotation = fire_dir.angle()

	if proj.has_method("initialize_projectile"):
		proj.call("initialize_projectile", fire_dir, data.muzzle_velocity*randf_range(0.9,1.1), data.damage)
