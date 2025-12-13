extends Camera2D
class_name GameCamera

@export var lerp_speed: float = 5.0

# Screenshake settings
@export var shake_decay: float = 1.5
@export var shake_max_offset: float = 12.0
@export var shake_max_rotation: float = 0.04

var actual_cam_pos: Vector2 = Vector2.ZERO
@onready var player: CharacterBody2D = $"../PlayerContainer/Player"

var _trauma: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	actual_cam_pos = global_position

	Screenshake.register_camera(self)


func _physics_process(delta: float) -> void:
	# --- follow player smoothly ---
	var target_pos: Vector2 = player.global_position
	actual_cam_pos = actual_cam_pos.lerp(target_pos, delta * lerp_speed)

	# Subpixel offset for your shader correction
	var cam_subpixel_offset: Vector2 = actual_cam_pos.round() - actual_cam_pos

	# --- compute shake offset / rotation ---
	var shake_offset: Vector2 = Vector2.ZERO
	var shake_rot: float = 0.0

	if _trauma > 0.0:
		var t: float = _trauma * _trauma

		var off_x: float = shake_max_offset * t * (_rng.randf() * 2.0 - 1.0)
		var off_y: float = shake_max_offset * t * (_rng.randf() * 2.0 - 1.0)
		shake_offset = Vector2(off_x, off_y)

		shake_rot = shake_max_rotation * t * (_rng.randf() * 2.0 - 1.0)

		_trauma = max(_trauma - shake_decay * delta, 0.0)

	# --- apply position + shake (pixel snap) ---
	global_position = actual_cam_pos.round() + shake_offset
	rotation = shake_rot

	# --- push cam_offset to your shader owner (same logic you had) ---
	var root: Node = get_parent()
	if root != null and root.get_parent() != null and root.get_parent().get_parent() != null:
		var mat_owner: Node = root.get_parent().get_parent()
		if "material" in mat_owner:
			var mat: Material = mat_owner.material
			if mat != null:
				mat.set_shader_parameter("cam_offset", cam_subpixel_offset)
				# If you want shake to affect the shader too, use:
				# mat.set_shader_parameter("cam_offset", cam_subpixel_offset + shake_offset)


func add_trauma(amount: float) -> void:
	var new_trauma: float = _trauma + amount
	if new_trauma > 1.0:
		new_trauma = 1.0
	if new_trauma < 0.0:
		new_trauma = 0.0
	_trauma = new_trauma
