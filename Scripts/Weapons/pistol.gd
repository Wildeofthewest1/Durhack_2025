extends WeaponBase
class_name WeaponPistol

@export var bullet_scene: PackedScene
@export var muzzle_velocity: float = 800.0
@export var damage: float = 10.0

@onready var muzzle: Node2D = $Muzzle

var _aim_dir: Vector2 = Vector2.RIGHT  # direction toward mouse, normalized

func _process(delta: float) -> void:
	# keep WeaponBase cooldown ticking
	look_at(get_global_mouse_position())
	super._process(delta)
	_update_aim()

func _update_aim() -> void:
	# 1. get mouse position in world space
	var mouse_world: Vector2 = get_global_mouse_position()

	# 2. compute direction from this weapon to the mouse
	var to_mouse: Vector2 = mouse_world - global_position
	var dist: float = to_mouse.length()
	if dist > 0.0:
		_aim_dir = to_mouse / dist  # normalized

	# 3. rotate weapon to face that direction
	# IMPORTANT:
	# if your pistol art is drawn facing right (+X), use this:
	#rotation = _aim_dir.angle()

	# if your pistol sprite is drawn facing UP (+Y), then use this instead:
	# rotation = _aim_dir.angle() + PI / 2.0

func request_fire() -> void:
	# WeaponManager will call this every frame while fire is held
	# We reuse WeaponBase.try_fire() so cooldown applies
	try_fire(_aim_dir)

func _fire_projectile(dir: Vector2) -> void:
	# This gets called by WeaponBase.try_fire(dir) once cooldown is clear

	if bullet_scene == null:
		push_error("[WeaponPistol] bullet_scene is not set")
		return

	if muzzle == null:
		push_error("[WeaponPistol] muzzle is missing")
		return

	# 1. instance bullet
	var proj: Node2D = bullet_scene.instantiate() as Node2D

	# 2. add bullet to world root (current scene), not as a child of the gun
	var world_root: Node = get_parent().get_parent().get_parent()
	world_root.add_child(proj)

	# 3. set bullet position and orientation
	proj.global_position = muzzle.global_position
	proj.look_at(get_global_mouse_position())
	# 4. initialize bullet
	# Your ProjectileBasic expects exactly 3 args:
	#     dir, speed, dmg
	# So we call it with exactly that.
	dir = Vector2(get_global_mouse_position() - proj.global_position)
	if proj.has_method("initialize_projectile"):
		proj.call(
			"initialize_projectile",
			dir,
			muzzle_velocity,
			damage
		)
