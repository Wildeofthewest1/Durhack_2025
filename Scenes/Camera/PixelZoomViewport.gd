extends Node
class_name PixelViewportZoom

@export var viewport: SubViewport
@export var container: SubViewportContainer
@export var player_path: NodePath = NodePath("SubViewport/Game/PlayerContainer/Player")

# BASELINE (what "normal zoom" means)
@export var base_size: Vector2i = Vector2i(640, 360)
@export var base_scale: int = 3

# Manual zoom steps (snap)
@export var zoom_scales: Array[int] = [1, 2, 3, 4, 5]

# Input
@export var input_zoom_in: StringName = &"zoom_in_step"
@export var input_zoom_out: StringName = &"zoom_out_step"
@export var input_toggle_auto: StringName = &"toggle_auto_zoom"

@export var recenter: bool = true
@export var pixel_snap_position: bool = true

# --- AUTO ZOOM SETTINGS (CONTINUOUS / GRADIENT) ---
@export var auto_zoom_enabled: bool = false

# Low speed -> zoom IN (bigger scale), high speed -> zoom OUT (smaller scale)
@export var speed_for_zoom_in: float = 150.0
@export var speed_for_zoom_out: float = 900.0

# Continuous scale range (this is the SubViewportContainer scale in auto mode)
@export var auto_min_scale: float = 2.0   # zoomed out
@export var auto_max_scale: float = 5.0   # zoomed in

# How quickly auto zoom changes
@export var auto_zoom_lerp_speed: float = 6.0

var _index: int = 0
var _player: Node = null

# Continuous auto zoom state
var _auto_scale: float = 3.0


func _ready() -> void:
	_player = null
	if player_path != NodePath(""):
		_player = get_node_or_null(player_path)

	# Start at base_scale (default should be 3x and 640x360)
	_index = zoom_scales.find(base_scale)
	if _index == -1:
		_index = 0

	_auto_scale = float(base_scale)
	_apply_manual_scale(zoom_scales[_index])


func _process(delta: float) -> void:
	# Toggle auto zoom
	if Input.is_action_just_pressed(input_toggle_auto):
		auto_zoom_enabled = !auto_zoom_enabled
		# Sync state when toggling
		if auto_zoom_enabled:
			_auto_scale = float(zoom_scales[_index])
		else:
			_auto_scale = float(zoom_scales[_index])
			_apply_manual_scale(zoom_scales[_index])

	if auto_zoom_enabled:
		_auto_zoom_update(delta)
		return

	# Manual zoom (snap)
	if Input.is_action_just_pressed(input_zoom_in):
		_set_index(_index + 1)
	elif Input.is_action_just_pressed(input_zoom_out):
		_set_index(_index - 1)


# --------------------------
# AUTO (CONTINUOUS) MODE
# --------------------------
func _auto_zoom_update(delta: float) -> void:
	if viewport == null or container == null:
		return

	var speed: float = _get_player_speed()

	# Map speed -> [0..1]
	var t: float = 0.0
	if speed_for_zoom_out > speed_for_zoom_in:
		t = (speed - speed_for_zoom_in) / (speed_for_zoom_out - speed_for_zoom_in)
	t = clampf(t, 0.0, 1.0)

	# slow -> zoom IN (max), fast -> zoom OUT (min)
	var target_scale: float = lerpf(auto_max_scale, auto_min_scale, t)

	# Smoothly approach target
	var a: float = clampf(delta * auto_zoom_lerp_speed, 0.0, 1.0)
	_auto_scale = lerpf(_auto_scale, target_scale, a)

	# Apply BOTH viewport size and container scale
	var base_pixels_x: float = float(base_size.x * base_scale)
	var base_pixels_y: float = float(base_size.y * base_scale)

	var vp_w: int = int(roundf(base_pixels_x / _auto_scale))
	var vp_h: int = int(roundf(base_pixels_y / _auto_scale))

	if vp_w < 1:
		vp_w = 1
	if vp_h < 1:
		vp_h = 1

	viewport.size = Vector2i(vp_w, vp_h)
	container.size = Vector2(float(vp_w), float(vp_h))
	container.scale = Vector2(_auto_scale, _auto_scale)

	if recenter:
		_recenter_container()


func _get_player_speed() -> float:
	if _player == null:
		return 0.0

	if _player is CharacterBody2D:
		var cb: CharacterBody2D = _player as CharacterBody2D
		return cb.velocity.length()

	if "velocity" in _player:
		var v: Variant = _player.get("velocity")
		if v is Vector2:
			var vv: Vector2 = v as Vector2
			return vv.length()

	return 0.0


# --------------------------
# MANUAL (SNAP) MODE
# --------------------------
func _set_index(new_index: int) -> void:
	_index = clampi(new_index, 0, zoom_scales.size() - 1)
	var s: int = zoom_scales[_index]
	_auto_scale = float(s) # keep auto state in sync
	_apply_manual_scale(s)


func _apply_manual_scale(scale_factor: int) -> void:
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

	viewport.size = Vector2i(vp_w, vp_h)
	container.size = Vector2(float(vp_w), float(vp_h))
	container.scale = Vector2(float(f), float(f))

	if recenter:
		_recenter_container()


func _recenter_container() -> void:
	var win_size: Vector2 = container.get_viewport_rect().size
	var drawn_size: Vector2 = container.size * container.scale
	var pos: Vector2 = (win_size - drawn_size) * 0.5

	if pixel_snap_position:
		pos = pos.round()

	#container.position = pos
