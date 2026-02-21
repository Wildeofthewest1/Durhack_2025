# WeaponSword.gd
extends WeaponBase
class_name WeaponSword

@export var muzzle_path: NodePath = NodePath("Muzzle") # optional but recommended
@export var spawn_offset_px: float = 20.0

@export var blade_scene: PackedScene # assign your SwordBlade scene here

# Projectile stats for the sword blade
@export var blade_speed: float = 1
@export var blade_knockback: float = 100.0

@onready var _audio_template := $AudioStreamPlayer # use as template; do NOT play this directly
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

func _play_swing_sound() -> void:
	if _audio_template == null:
		return
	if _audio_template.stream == null:
		return

	# Duplicate the template so multiple instances can overlap
	var sfx := _audio_template.duplicate() as AudioStreamPlayer
	if sfx == null:
		return

	# Ensure it doesn't keep template connections / state
	sfx.autoplay = false

	# Keep it in the same place in the scene so 2D positioning works (if applicable)
	add_child(sfx)

	# Per-swing random pitch
	sfx.pitch_scale = 1.0 + randf_range(-0.25, 0.25)

	# Free itself when done
	if not sfx.finished.is_connected(sfx.queue_free):
		sfx.finished.connect(sfx.queue_free)

	sfx.play()

func _fire_projectile(dir: Vector2) -> void:
	if data == null:
		return

	if blade_scene == null:
		push_error("WeaponSword: blade_scene not assigned")
		return

	# Spawn point: prefer muzzle if present, else weapon position
	var spawn_origin: Vector2 = global_position
	if _muzzle != null:
		spawn_origin = _muzzle.global_position

	# NEW: overlapping audio
	_play_swing_sound()

	var proj: Node2D = blade_scene.instantiate() as Node2D
	if proj == null:
		push_error("WeaponSword: failed to instance blade_scene")
		return

	# IMPORTANT: match pistol world-root parenting exactly
	var world_root: Node = get_parent().get_parent().get_parent().get_parent()
	world_root.add_child(proj)

	# small recoil like pistol (optional)
	get_parent().get_parent().get_parent().global_position += -2.0 * dir.normalized()

	var fire_dir: Vector2 = dir.normalized()

	# spawn in front so it doesn't overlap weapon/player
	var spawn_pos: Vector2 = spawn_origin + fire_dir * spawn_offset_px
	proj.global_position = spawn_pos
	proj.rotation = fire_dir.angle()

	# call same init signature as your bullet
	var dmg := float(data.damage)
	var carrier_vel: Vector2 = get_parent().get_parent().get_parent().velocity

	if proj.has_method("initialize_projectile"):
		proj.call("initialize_projectile", fire_dir, blade_speed, dmg, carrier_vel, blade_knockback)
	else:
		push_error("WeaponSword: blade projectile missing initialize_projectile()")
