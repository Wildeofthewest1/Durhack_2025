extends Node
class_name PixelViewportZoom

@export var viewport: SubViewport
@export var container: SubViewportContainer

# BASELINE (what "normal zoom" means)
@export var base_size: Vector2i = Vector2i(640, 360)
@export var base_scale: int = 3

# Allowed zoom scales (container scales)
@export var zoom_scales: Array[int] = [1, 2, 3, 4, 5]

@export var input_zoom_in: StringName = &"zoom_in_step"
@export var input_zoom_out: StringName = &"zoom_out_step"

@export var recenter: bool = true
@export var pixel_snap_position: bool = true

var _index: int = 0


func _ready() -> void:
	# Start at base_scale
	_index = zoom_scales.find(base_scale)
	if _index == -1:
		_index = 0

	_apply_scale(zoom_scales[_index])


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(input_zoom_in):
		_set_index(_index + 1)
	elif Input.is_action_just_pressed(input_zoom_out):
		_set_index(_index - 1)


func _set_index(new_index: int) -> void:
	_index = clampi(new_index, 0, zoom_scales.size() - 1)
	_apply_scale(zoom_scales[_index])


func _apply_scale(scale_factor: int) -> void:
	if viewport == null or container == null:
		return

	var f: int = max(1, scale_factor)

	# viewport_size = base_size * base_scale / f
	var vp_w: int = int(base_size.x * base_scale / f)
	var vp_h: int = int(base_size.y * base_scale / f)

	if vp_w < 1:
		vp_w = 1
	if vp_h < 1:
		vp_h = 1

	var vp_size: Vector2i = Vector2i(vp_w, vp_h)

	# 1) Change SubViewport render resolution
	viewport.size = vp_size

	# 2) Match container size to viewport
	container.size = Vector2(float(vp_size.x), float(vp_size.y))

	# 3) Integer scale (pixel-perfect)
	container.scale = Vector2(float(f), float(f))

	# 4) Center on screen
	if recenter:
		_recenter_container()


func _recenter_container() -> void:
	var win_size: Vector2 = container.get_viewport_rect().size
	var drawn_size: Vector2 = container.size * container.scale
	var pos: Vector2 = (win_size - drawn_size) * 0.5

	if pixel_snap_position:
		pos = pos.round()

	container.position = pos
