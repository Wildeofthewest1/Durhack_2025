extends Sprite2D
class_name CameraBackgroundSprite

@export var camera_path: NodePath
@export var extra_scale: float = 1.02
@export var max_shake_pixels: float = 64.0 # set to your worst-case shake in SCREEN pixels

var _cam: Camera2D = null
var _tex_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	_cam = get_node(camera_path) as Camera2D
	if texture != null:
		_tex_size = texture.get_size()
	centered = true
	top_level = true

func _process(delta: float) -> void:
	if _cam == null or texture == null:
		return

	# Follow the actual rendered view (includes shake)
	global_position = _cam.get_screen_center_position()

	var vp_size: Vector2 = _cam.get_viewport_rect().size

	# Visible size in WORLD units (camera zoom affects world-space visible area)
	var visible_world: Vector2 = Vector2(vp_size.x * _cam.zoom.x, vp_size.y * _cam.zoom.y)

	# Overscan for shake: shake is in screen pixels -> convert to world units via zoom
	var shake_world_x: float = max_shake_pixels * _cam.zoom.x
	var shake_world_y: float = max_shake_pixels * _cam.zoom.y
	visible_world.x += shake_world_x * 2.0
	visible_world.y += shake_world_y * 2.0

	if _tex_size.x > 0.0 and _tex_size.y > 0.0:
		var sx: float = (visible_world.x / _tex_size.x) * extra_scale
		var sy: float = (visible_world.y / _tex_size.y) * extra_scale
		scale = Vector2(sx, sy)
