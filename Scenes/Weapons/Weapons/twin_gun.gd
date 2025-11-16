extends WeaponBase

@export var bullet_scene: PackedScene = preload("res://Scenes/weapons/twin_bullet.tscn")

# Firing mode
@export var fire_both_at_once: bool = false
@export var alternate_start_left: bool = true

# Muzzles
@onready var muzzle_l: Node2D = $MuzzleL
@onready var muzzle_r: Node2D = $MuzzleR

var _next_left := true

func _ready() -> void:
	super._ready()
	_next_left = alternate_start_left

func _process(delta: float) -> void:
	super._process(delta)
	# Aim the gun body toward the mouse in world space (rotation only)
	look_at(_get_global_mouse())

func _on_fire_effects() -> void:
	if fire_both_at_once:
		_spawn_from_muzzle(muzzle_l)
		if magazine > 0:
			_spawn_from_muzzle(muzzle_r)
			magazine -= 1
		_emit_ui()
		return

	var use_left := _next_left
	var muzzle := muzzle_l if use_left else muzzle_r
	if is_instance_valid(muzzle):
		_spawn_from_muzzle(muzzle)
	_next_left = not _next_left

# --- helpers ---

func _spawn_from_muzzle(m: Node2D) -> void:
	if not bullet_scene or not is_instance_valid(m):
		return
	var flash := m.get_node_or_null("MuzzleFlash") as GPUParticles2D
	if flash:
		flash.restart()
		flash.emitting = true
	# PARALLEL FIRE: use the WEAPON'S forward vector (no convergence to mouse)
	# (global_transform.x points "right" in Node2D, i.e., your barrel direction)
	var dir := global_transform.x.normalized()

	var b := bullet_scene.instantiate()
	if (get_parent()):
		get_parent().get_parent().get_parent().add_child(b) # add to world/root
	b.global_position = m.global_position                 # spawn at that muzzle
	b.global_rotation = dir.angle()

	var shooter_vel := Vector2.ZERO
	if owner and "velocity" in owner:
		shooter_vel = owner.velocity
	if b.has_method("setup"):
		b.setup(dir, shooter_vel)

func _get_global_mouse() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	return cam.get_global_mouse_position() if cam else get_global_mouse_position()
