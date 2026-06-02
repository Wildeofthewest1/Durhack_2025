extends WeaponBase
class_name WeaponPistol

@export var muzzle_path: NodePath = NodePath("Muzzle")
@export var spawn_offset_px: float = 20.0

@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer

var _muzzle: Node2D = null

func _ready() -> void:
	super._ready()
	_muzzle = get_node(muzzle_path) as Node2D
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
	if _muzzle == null:
		push_error("WeaponPistol: muzzle is missing")
		return
	if data.bullet_scene == null:
		push_error("WeaponPistol: bullet_scene not set in WeaponData")
		return
	
	var clone = _audio.duplicate()
	self.add_child(clone)
	clone.pitch_scale = 1.0 + randf_range(-0.1, 0.1)
	clone.play()
	# Delete the clone when playback finishes
	clone.finished.connect(clone.queue_free)

	var proj: Node2D = data.bullet_scene.instantiate() as Node2D
	var world_root: Node = get_parent().get_parent().get_parent().get_parent()
	world_root.add_child(proj)

	# Player recoil (unchanged)
	get_parent().get_parent().get_parent().global_position += -2.0 * dir.normalized()

	# IMPORTANT:
	# dir already includes accuracy/spread from WeaponBase.try_fire()
	var fire_dir: Vector2 = dir.normalized()

	var spawn_pos: Vector2 = _muzzle.global_position + fire_dir * spawn_offset_px
	proj.global_position = spawn_pos
	proj.rotation = fire_dir.angle()

	if proj.has_method("initialize_projectile"):
		proj.call(
			"initialize_projectile",
			fire_dir,
			data.muzzle_velocity,
			get_effective_damage(),
			get_parent().get_parent().get_parent().velocity,
			get_effective_knockback()
		)

	if data.flash_scene != null:
		var flash_instance: Node2D = data.flash_scene.instantiate() as Node2D
		_muzzle.add_child(flash_instance)
		flash_instance.position = Vector2.ZERO
		flash_instance.rotation = 0.0
		flash_instance.scale = Vector2(1.0, 1.0)
