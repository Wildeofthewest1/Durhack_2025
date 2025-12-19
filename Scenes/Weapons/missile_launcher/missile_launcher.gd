# WeaponTwin.gd
extends WeaponBase
class_name WeaponMissile

@export var muzzle_l_path: NodePath = NodePath("MuzzleL")
@export var muzzle_r_path: NodePath = NodePath("MuzzleR")
@export var spawn_offset_px: float = 20.0

# Firing mode
@export var fire_both_at_once: bool = false
@export var alternate_start_left: bool = true

@onready var _audio:= $AudioStreamPlayer

var _muzzle_l: Node2D
var _muzzle_r: Node2D
var _next_left: bool = true

func _ready() -> void:
	super._ready()
	_muzzle_l = get_node(muzzle_l_path) as Node2D
	_muzzle_r = get_node(muzzle_r_path) as Node2D
	_next_left = alternate_start_left
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
	# rotation is controlled by parent (socket / player), so we leave it alone


func request_fire() -> void:
	# WeaponManager calls this while fire is held
	try_fire(_aim_dir)


func _fire_projectile(dir: Vector2) -> void:
	if data == null:
		return
	if data.bullet_scene == null:
		push_error("WeaponTwin: bullet_scene not set in WeaponData")
		return

	if fire_both_at_once:
		_spawn_from_muzzle(_muzzle_l, dir)
		_spawn_from_muzzle(_muzzle_r, dir)

	else:
		var use_left: bool = _next_left
		var muzzle: Node2D = null
		if use_left:
			muzzle = _muzzle_l
		else:
			muzzle = _muzzle_r
		_spawn_from_muzzle(muzzle, dir)
		_next_left = not _next_left
	_audio.pitch_scale = 1 + randf_range(-0.01,0.01)
	_audio.play()

# --- helpers ---

func _spawn_from_muzzle(muzzle: Node2D, _base_dir: Vector2) -> void:
	if muzzle == null:
		return

	var world_root: Node = get_parent().get_parent().get_parent().get_parent()

	# Instance missile
	var missile: MissileProjectile = data.bullet_scene.instantiate() as MissileProjectile
	world_root.add_child(missile)

	# Forward direction = where the muzzle is pointing
	var muzzle_forward: Vector2 = Vector2.RIGHT.rotated(muzzle.global_rotation)

	# Optional: still apply spread *around* the muzzle direction
	var half_spread: float = data.spread_deg * 0.5
	var spread_rad: float = deg_to_rad(randf_range(-half_spread, half_spread))
	var fire_dir: Vector2 = muzzle_forward.rotated(spread_rad).normalized()

	# Spawn in front of the muzzle
	var spawn_pos: Vector2 = muzzle.global_position + fire_dir * spawn_offset_px
	missile.global_position = spawn_pos

	# Let the missile script set its own rotation/velocity
	missile.initialize(fire_dir)

	# Muzzle flash stays the same
	if data.flash_scene != null:
		var flash_instance: Node2D = data.flash_scene.instantiate() as Node2D
		muzzle.add_child(flash_instance)
		flash_instance.position = Vector2.ZERO
		flash_instance.rotation = 0.0
		flash_instance.scale = Vector2(1.0, 1.0)
