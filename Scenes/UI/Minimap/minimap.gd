extends Control
class_name Minimap

## Minimap display settings
@export var minimap_size: Vector2 = Vector2(250.0, 250.0)
@export var world_scale: float = 0.1
@export var background_color: Color = Color(0.1, 0.1, 0.15, 0.9)
@export var border_color: Color = Color(0.3, 0.3, 0.4, 1.0)
@export var border_width: float = 2.0

## Margins from the top-right corner of the screen (minimized)
@export var margin_top: float = 0.0
@export var margin_right: float = 0.0

## Expanded mode (DO NOT change anchors; we only override offsets)
@export var expanded_enabled: bool = true
@export var expanded_margin: Vector2 = Vector2(32.0, 32.0)
@export var toggle_action: StringName = &"toggle_map"

## Optional overlay button/control on top of minimap for clicking to toggle
@export var toggle_button_path: NodePath = NodePath("")

## Pan/Zoom (expanded only)
@export var drag_button: MouseButton = MOUSE_BUTTON_LEFT
@export var min_zoom: float = 0.4
@export var max_zoom: float = 6.0
@export var zoom_step: float = 1.12

## Optional world bounds clamping
@export var world_bounds_enabled: bool = false
@export var world_bounds: Rect2 = Rect2(Vector2(-5000.0, -5000.0), Vector2(10000.0, 10000.0))

## Reference to the player/camera to center the minimap on
@export var follow_node: Node2D

## --- Slow time while expanded ---
@export var fast_scale: float = 1.0
@export var slow_scale: float = 0.05
@export var time_lerp_speed: float = 0.12

## Internal tracking
var tracked_objects: Array[MinimapTrackedObject] = []

@onready var draw_area: MinimapDrawArea = $DrawArea as MinimapDrawArea

# Cached minimized layout (EXACT editor offsets)
var _min_offset_left: float = 0.0
var _min_offset_right: float = 0.0
var _min_offset_top: float = 0.0
var _min_offset_bottom: float = 0.0
var _min_size: Vector2 = Vector2.ZERO

# View state
var _expanded: bool = false
var _zoom: float = 1.0
var _view_center_world: Vector2 = Vector2.ZERO

# Drag state
var _dragging: bool = false
var _drag_start_mouse_global: Vector2 = Vector2.ZERO
var _drag_start_center_world: Vector2 = Vector2.ZERO

# Optional overlay
var _toggle_button: Control = null

# Time scale state
var _current_time_scale: float = 1.0

# Tracks whether THIS minimap currently holds the gameplay lock
var _holds_gameplay_lock: bool = false

func _ready() -> void:
	# Cache EXACT minimized offsets from the editor.
	_min_offset_left = offset_left
	_min_offset_right = offset_right
	_min_offset_top = offset_top
	_min_offset_bottom = offset_bottom
	_min_size = size

	# Optional: find and auto-connect your toggle button
	if toggle_button_path != NodePath("") and has_node(toggle_button_path):
		_toggle_button = get_node(toggle_button_path) as Control
		_auto_connect_toggle_button()

	_sync_center_to_follow()

	# Make DrawArea fill this Control
	if draw_area != null:
		draw_area.anchor_left = 0.0
		draw_area.anchor_top = 0.0
		draw_area.anchor_right = 1.0
		draw_area.anchor_bottom = 1.0
		draw_area.offset_left = 0.0
		draw_area.offset_top = 0.0
		draw_area.offset_right = 0.0
		draw_area.offset_bottom = 0.0

	# Ensure minimap can intercept inputs when expanded
	mouse_filter = Control.MOUSE_FILTER_STOP

	set_process(true)
	set_process_unhandled_input(true)

func _process(_delta: float) -> void:
	# Only slow time while expanded
	var target_scale: float = fast_scale
	if _expanded == true:
		target_scale = slow_scale

	_current_time_scale = lerp(_current_time_scale, target_scale, time_lerp_speed)
	Engine.time_scale = _current_time_scale

func _physics_process(_delta: float) -> void:
	# Minimized mode follows player.
	if not _expanded:
		_sync_center_to_follow()

	if draw_area != null:
		draw_area.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if expanded_enabled and event.is_action_pressed(toggle_action):
		toggle_expanded()
		return

	if not _expanded:
		return

	# Expanded pan/zoom
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event

		# Zoom (wheel)
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var factor: float = zoom_step
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				factor = 1.0 / zoom_step
			_zoom_at_mouse(factor)
			get_viewport().set_input_as_handled()
			return

		# Pan start/stop
		if mb.button_index == drag_button:
			if mb.pressed and _is_mouse_over_me():
				_dragging = true
				_drag_start_mouse_global = get_global_mouse_position()
				_drag_start_center_world = _view_center_world
				get_viewport().set_input_as_handled()
			else:
				_dragging = false
				get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and _dragging:
		var mouse_now: Vector2 = get_global_mouse_position()
		var delta_px: Vector2 = mouse_now - _drag_start_mouse_global

		var denom: float = world_scale * _zoom
		if denom > 0.000001:
			var delta_world: Vector2 = delta_px / denom
			_view_center_world = _drag_start_center_world - delta_world
			_clamp_view_center_world()

		if draw_area != null:
			draw_area.queue_redraw()

		get_viewport().set_input_as_handled()
		return

# =========================================================
# Toggle expand/collapse (NO ANCHOR CHANGES)
# =========================================================
func toggle_expanded() -> void:
	_expanded = not _expanded

	if _expanded:
		# Lock gameplay + slow time
		_acquire_gameplay_lock()

		_disable_toggle_overlay_for_pan(true)
		_zoom = 1.0
		_sync_center_to_follow()
		_apply_expanded_layout_top_right()
	else:
		# Unlock gameplay + restore time
		_release_gameplay_lock()

		_disable_toggle_overlay_for_pan(false)
		_zoom = 1.0
		_sync_center_to_follow()
		_apply_minimized_layout_exact()

	_clamp_view_center_world()

	if draw_area != null:
		draw_area.queue_redraw()

# =========================================================
# Lock / Unlock helpers
# =========================================================
func _acquire_gameplay_lock() -> void:
	if _holds_gameplay_lock == false:
		InputLock.lock_gameplay()
		_holds_gameplay_lock = true

func _release_gameplay_lock() -> void:
	if _holds_gameplay_lock == true:
		InputLock.unlock_gameplay()
		_holds_gameplay_lock = false

	_current_time_scale = 1.0
	Engine.time_scale = 1.0

func _exit_tree() -> void:
	# Safety: if this node is removed while expanded, don't leave the game locked/slow.
	_release_gameplay_lock()

# =========================================================
# Layout
# =========================================================
func _apply_minimized_layout_exact() -> void:
	offset_left = _min_offset_left
	offset_right = _min_offset_right
	offset_top = _min_offset_top
	offset_bottom = _min_offset_bottom
	size = _min_size

func _apply_expanded_layout_top_right() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var m: Vector2 = expanded_margin

	var expanded_size: Vector2 = vp - m * 2.0
	if expanded_size.x < 64.0:
		expanded_size.x = 64.0
	if expanded_size.y < 64.0:
		expanded_size.y = 64.0

	var right_margin: float = m.x
	var top_margin: float = m.y

	offset_right = -right_margin
	offset_left = offset_right - expanded_size.x

	offset_top = top_margin
	offset_bottom = offset_top + expanded_size.y

	size = expanded_size

func set_minimap_size(new_size: Vector2) -> void:
	minimap_size = new_size

	_min_size = new_size
	_min_offset_right = _min_offset_right
	_min_offset_left = _min_offset_right - new_size.x
	_min_offset_top = _min_offset_top
	_min_offset_bottom = _min_offset_top + new_size.y

	if not _expanded:
		_apply_minimized_layout_exact()

# =========================================================
# Button wiring / disabling
# =========================================================
func _auto_connect_toggle_button() -> void:
	if _toggle_button == null:
		return
	if _toggle_button is BaseButton:
		var bb: BaseButton = _toggle_button as BaseButton
		if not bb.pressed.is_connected(toggle_expanded):
			bb.pressed.connect(toggle_expanded)

func _disable_toggle_overlay_for_pan(disable: bool) -> void:
	if _toggle_button == null:
		return

	if disable:
		_toggle_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _toggle_button is BaseButton:
			var bb: BaseButton = _toggle_button as BaseButton
			bb.disabled = true
	else:
		_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
		if _toggle_button is BaseButton:
			var bb2: BaseButton = _toggle_button as BaseButton
			bb2.disabled = false

# =========================================================
# Tracking API
# =========================================================
func register_object(obj: MinimapTrackedObject) -> void:
	if obj != null and not tracked_objects.has(obj):
		tracked_objects.append(obj)

func unregister_object(obj: MinimapTrackedObject) -> void:
	var idx: int = tracked_objects.find(obj)
	if idx >= 0:
		tracked_objects.remove_at(idx)

func get_tracked_objects() -> Array[MinimapTrackedObject]:
	return tracked_objects

# =========================================================
# Mapping (pan/zoom aware)
# =========================================================
func world_to_minimap(world_pos: Vector2) -> Vector2:
	var center_world: Vector2 = _view_center_world
	if follow_node != null and not _expanded:
		center_world = follow_node.global_position

	var offset: Vector2 = world_pos - center_world
	var scaled: Vector2 = offset * (world_scale * _zoom)
	var center_px: Vector2 = size * 0.5
	return center_px + scaled

func is_visible_on_minimap(world_pos: Vector2) -> bool:
	var minimap_pos: Vector2 = world_to_minimap(world_pos)
	return minimap_pos.x >= 0.0 and minimap_pos.x <= size.x and minimap_pos.y >= 0.0 and minimap_pos.y <= size.y

func _sync_center_to_follow() -> void:
	if follow_node != null:
		_view_center_world = follow_node.global_position

func _is_mouse_over_me() -> bool:
	var local: Vector2 = get_local_mouse_position()
	return local.x >= 0.0 and local.y >= 0.0 and local.x <= size.x and local.y <= size.y

func _zoom_at_mouse(factor: float) -> void:
	var old_zoom: float = _zoom
	var new_zoom: float = clamp(old_zoom * factor, min_zoom, max_zoom)
	if abs(new_zoom - old_zoom) < 0.00001:
		return

	var mouse_local: Vector2 = get_local_mouse_position()
	var center_px: Vector2 = size * 0.5
	var from_center_px: Vector2 = mouse_local - center_px

	var denom_old: float = world_scale * old_zoom
	var denom_new: float = world_scale * new_zoom
	if denom_old <= 0.000001 or denom_new <= 0.000001:
		return

	var world_offset_before: Vector2 = from_center_px / denom_old
	var world_point_under_mouse: Vector2 = _view_center_world + world_offset_before

	_zoom = new_zoom

	var world_offset_after: Vector2 = from_center_px / denom_new
	_view_center_world = world_point_under_mouse - world_offset_after

	_clamp_view_center_world()

	if draw_area != null:
		draw_area.queue_redraw()

func _clamp_view_center_world() -> void:
	if not world_bounds_enabled:
		return

	var denom: float = world_scale * _zoom
	if denom <= 0.000001:
		return

	var half_w: float = (size.x * 0.5) / denom
	var half_h: float = (size.y * 0.5) / denom

	var min_x: float = world_bounds.position.x + half_w
	var max_x: float = world_bounds.position.x + world_bounds.size.x - half_w
	var min_y: float = world_bounds.position.y + half_h
	var max_y: float = world_bounds.position.y + world_bounds.size.y - half_h

	if min_x > max_x:
		_view_center_world.x = world_bounds.position.x + world_bounds.size.x * 0.5
	else:
		_view_center_world.x = clamp(_view_center_world.x, min_x, max_x)

	if min_y > max_y:
		_view_center_world.y = world_bounds.position.y + world_bounds.size.y * 0.5
	else:
		_view_center_world.y = clamp(_view_center_world.y, min_y, max_y)
