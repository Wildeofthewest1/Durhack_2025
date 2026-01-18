extends Control
class_name InteractionUI

# =====================================================================
# ROOT ORCHESTRATOR (COMMS RESTORED)
# - panel open/close
# - safe pause
# - comms/fleet/shop pages (optional)
# - triggers bubble dialogue UI only if planet/interactible has dialogue
# - keeps old API: toggle_for_planet / open_for_planet
# =====================================================================

@export var panel: Control

# Portrait panel slide
@export var portrait_panel: Control
@export var portrait_hide_offset: float = 400.0

# Optional pages (use or leave null)
@export var comms_page: Control
@export var fleet_page: Control
@export var shop_page: Control

@export var comms_tab_button: Button
@export var fleet_tab_button: Button
@export var shop_tab_button: Button

@export var panel_hide_offset: float = 400.0
@export var tween_time: float = 0.18

# Controllers
@export var portrait_controller: Node
@export var bubble_dialogue_controller: Node # your BubbleDialogueController
@export var comms_controller: Node
@export var fleet_controller: Node
@export var shop_controller: Node

# =====================================================================
# DRAGGABLE HANDLES (NEW)
# - drag_handle_main moves ONLY "panel"
# - drag_handle_portrait moves ONLY "portrait_panel"
# =====================================================================

@export var drag_handle_main: Control
@export var drag_handle_portrait: Control

@export var drag_range_px_main: float = 60.0
@export var drag_range_px_portrait: float = 60.0

@export var drag_return_time: float = 0.12
@export var drag_require_left_button: bool = true

var _open: bool = false
var _panel_shown_x: float = 0.0
var _panel_hidden_x: float = 0.0

# Portrait slide cached positions
var _portrait_shown_x: float = 0.0
var _portrait_hidden_x: float = 0.0

# close gating
var _pending_close_anims: int = 0
var _closing: bool = false

# data
var _current_planet: Node = null

# active page
var _active_page: StringName = &"none" # "none" | "comms" | "fleet" | "shop"

# Drag state (main)
var _dragging_main: bool = false
var _drag_main_mouse_start_x: float = 0.0
var _drag_main_delta_current: float = 0.0

# Drag state (portrait)
var _dragging_portrait: bool = false
var _drag_portrait_mouse_start_x: float = 0.0
var _drag_portrait_delta_current: float = 0.0

# Tween guards
var _active_tween_panel: Tween = null
var _active_tween_portrait: Tween = null


func _ready() -> void:
	if panel == null:
		return

	# UI ignores pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel_shown_x = panel.position.x
	_panel_hidden_x = _panel_shown_x + panel_hide_offset

	# Start main panel hidden
	var ppos: Vector2 = panel.position
	ppos.x = _panel_hidden_x
	panel.position = ppos

	# Cache portrait positions + start hidden
	if portrait_panel != null:
		_portrait_shown_x = portrait_panel.position.x
		_portrait_hidden_x = _portrait_shown_x + portrait_hide_offset

		var ppos2: Vector2 = portrait_panel.position
		ppos2.x = _portrait_hidden_x
		portrait_panel.position = ppos2

	_open = false
	_set_ui_active(false)
	_show_page(&"none")

	# Optional tab hookups
	if comms_tab_button != null and not comms_tab_button.pressed.is_connected(show_comms_page):
		comms_tab_button.pressed.connect(show_comms_page)
	if fleet_tab_button != null and not fleet_tab_button.pressed.is_connected(show_fleet_page):
		fleet_tab_button.pressed.connect(show_fleet_page)
	if shop_tab_button != null and not shop_tab_button.pressed.is_connected(show_shop_page):
		shop_tab_button.pressed.connect(show_shop_page)

	# Drag handle hookups
	_setup_drag_handles()


func _setup_drag_handles() -> void:
	if drag_handle_main != null:
		drag_handle_main.mouse_filter = Control.MOUSE_FILTER_STOP
		if not drag_handle_main.gui_input.is_connected(_on_drag_handle_main_gui_input):
			drag_handle_main.gui_input.connect(_on_drag_handle_main_gui_input)

	if drag_handle_portrait != null:
		drag_handle_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
		if not drag_handle_portrait.gui_input.is_connected(_on_drag_handle_portrait_gui_input):
			drag_handle_portrait.gui_input.connect(_on_drag_handle_portrait_gui_input)


# =====================================================================
# SAFE PAUSE HELPER (fixes: get_tree() null instance)
# =====================================================================

func _set_game_paused(paused: bool) -> void:
	if is_inside_tree() == false:
		call_deferred("_set_game_paused", paused)
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return

	tree.paused = paused


# =====================================================================
# INPUT FORWARDING (bubble UI needs keys while paused)
# =====================================================================

func _unhandled_input(event: InputEvent) -> void:
	if _open == false:
		return
	if visible == false:
		return

	# While dragging, don't forward inputs (prevents accidental skip/choice)
	if _dragging_main == true or _dragging_portrait == true:
		return

	if bubble_dialogue_controller != null and _has_method(bubble_dialogue_controller, &"handle_input"):
		bubble_dialogue_controller.call("handle_input", event)


func _has_method(obj: Object, method_name: StringName) -> bool:
	if obj == null:
		return false
	return obj.has_method(String(method_name))


# =====================================================================
# DRAG LOGIC (MAIN)
# =====================================================================

func _on_drag_handle_main_gui_input(event: InputEvent) -> void:
	if _open == false:
		return
	if panel == null:
		return
	if _closing == true:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MouseButton.MOUSE_BUTTON_LEFT:
			return

		if mb.pressed == true:
			if drag_require_left_button == true and mb.button_index != MouseButton.MOUSE_BUTTON_LEFT:
				return
			_begin_drag_main(mb.position.x)
			accept_event()
			return
		else:
			if _dragging_main == true:
				_end_drag_main()
				accept_event()
				return

	if event is InputEventMouseMotion:
		if _dragging_main == false:
			return
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_update_drag_main(mm.position.x)
		accept_event()
		return


func _begin_drag_main(mouse_x: float) -> void:
	_dragging_main = true
	_drag_main_mouse_start_x = mouse_x
	_drag_main_delta_current = 0.0
	_kill_panel_tween()


func _update_drag_main(mouse_x: float) -> void:
	var dx: float = mouse_x - _drag_main_mouse_start_x
	var clamped_dx: float = clampf(dx, -drag_range_px_main, drag_range_px_main)
	_drag_main_delta_current = clamped_dx
	_apply_main_drag_delta(_drag_main_delta_current)


func _end_drag_main() -> void:
	_dragging_main = false
	_kill_panel_tween()

	var tw: Tween = create_tween()
	_active_tween_panel = tw
	tw.set_ignore_time_scale(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.tween_property(panel, "position:x", _panel_shown_x, drag_return_time)
	tw.finished.connect(_on_panel_tween_finished)


func _apply_main_drag_delta(delta_x: float) -> void:
	var target_x: float = _panel_shown_x + delta_x
	var ppos: Vector2 = panel.position
	ppos.x = target_x
	panel.position = ppos


func _kill_panel_tween() -> void:
	if _active_tween_panel == null:
		return
	if is_instance_valid(_active_tween_panel) == false:
		_active_tween_panel = null
		return
	_active_tween_panel.kill()
	_active_tween_panel = null


func _on_panel_tween_finished() -> void:
	_active_tween_panel = null


# =====================================================================
# DRAG LOGIC (PORTRAIT)
# =====================================================================

func _on_drag_handle_portrait_gui_input(event: InputEvent) -> void:
	if _open == false:
		return
	if portrait_panel == null:
		return
	if _closing == true:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index != MouseButton.MOUSE_BUTTON_LEFT:
			return

		if mb.pressed == true:
			if drag_require_left_button == true and mb.button_index != MouseButton.MOUSE_BUTTON_LEFT:
				return
			_begin_drag_portrait(mb.position.x)
			accept_event()
			return
		else:
			if _dragging_portrait == true:
				_end_drag_portrait()
				accept_event()
				return

	if event is InputEventMouseMotion:
		if _dragging_portrait == false:
			return
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_update_drag_portrait(mm.position.x)
		accept_event()
		return


func _begin_drag_portrait(mouse_x: float) -> void:
	_dragging_portrait = true
	_drag_portrait_mouse_start_x = mouse_x
	_drag_portrait_delta_current = 0.0
	_kill_portrait_tween()


func _update_drag_portrait(mouse_x: float) -> void:
	var dx: float = mouse_x - _drag_portrait_mouse_start_x
	var clamped_dx: float = clampf(dx, -drag_range_px_portrait, drag_range_px_portrait)
	_drag_portrait_delta_current = clamped_dx
	_apply_portrait_drag_delta(_drag_portrait_delta_current)


func _end_drag_portrait() -> void:
	_dragging_portrait = false
	_kill_portrait_tween()

	var tw: Tween = create_tween()
	_active_tween_portrait = tw
	tw.set_ignore_time_scale(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.tween_property(portrait_panel, "position:x", _portrait_shown_x, drag_return_time)
	tw.finished.connect(_on_portrait_tween_finished)


func _apply_portrait_drag_delta(delta_x: float) -> void:
	var target_x: float = _portrait_shown_x + delta_x
	var ppos: Vector2 = portrait_panel.position
	ppos.x = target_x
	portrait_panel.position = ppos


func _kill_portrait_tween() -> void:
	if _active_tween_portrait == null:
		return
	if is_instance_valid(_active_tween_portrait) == false:
		_active_tween_portrait = null
		return
	_active_tween_portrait.kill()
	_active_tween_portrait = null


func _on_portrait_tween_finished() -> void:
	_active_tween_portrait = null


# =====================================================================
# PUBLIC API (called from your PlayerInteraction)
# =====================================================================

func toggle_for_planet(planet: Node) -> void:
	if _open == true:
		close_ui()
		return
	open_for_planet(planet)


func open_for_planet(planet: Node) -> void:
	if panel == null:
		return

	_closing = false
	_current_planet = planet

	# Pause game safely
	_set_game_paused(true)

	# Enable UI + input
	_set_ui_active(true)

	# Default page: comms
	_show_page(&"comms")

	# Portrait setup (content)
	if portrait_controller != null and planet != null and is_instance_valid(planet):
		if _has_method(portrait_controller, &"setup_for_planet"):
			portrait_controller.call("setup_for_planet", planet)
		elif _has_method(portrait_controller, &"setup_for_target"):
			portrait_controller.call("setup_for_target", planet)

	# Bubble dialogue: ONLY start if this planet has dialogue
	if bubble_dialogue_controller != null and _planet_has_dialogue(planet):
		if _has_method(bubble_dialogue_controller, &"setup_for_planet"):
			bubble_dialogue_controller.call("setup_for_planet", planet)
		elif _has_method(bubble_dialogue_controller, &"start_for_target"):
			bubble_dialogue_controller.call("start_for_target", planet)

	# Optional other controllers
	if comms_controller != null:
		if _has_method(comms_controller, &"setup_for_planet"):
			comms_controller.call("setup_for_planet", planet)
		elif _has_method(comms_controller, &"setup_for_target"):
			comms_controller.call("setup_for_target", planet)

	if fleet_controller != null:
		if _has_method(fleet_controller, &"setup_for_planet"):
			fleet_controller.call("setup_for_planet", planet)
		elif _has_method(fleet_controller, &"setup_for_target"):
			fleet_controller.call("setup_for_target", planet)

	if shop_controller != null:
		if _has_method(shop_controller, &"setup_for_planet"):
			shop_controller.call("setup_for_planet", planet)
		elif _has_method(shop_controller, &"setup_for_target"):
			shop_controller.call("setup_for_target", planet)

	_slide_open()


func close_ui() -> void:
	if _open == false:
		_set_ui_active(false)
		_current_planet = null
		return

	if _closing == true:
		return

	_closing = true
	_pending_close_anims = 0

	# Stop dragging if active
	if _dragging_main == true:
		_dragging_main = false
	if _dragging_portrait == true:
		_dragging_portrait = false

	_kill_panel_tween()
	_kill_portrait_tween()

	# Stop controllers
	if bubble_dialogue_controller != null and _has_method(bubble_dialogue_controller, &"stop"):
		bubble_dialogue_controller.call("stop")

	if comms_controller != null and _has_method(comms_controller, &"stop"):
		comms_controller.call("stop")

	if fleet_controller != null and _has_method(fleet_controller, &"stop"):
		fleet_controller.call("stop")

	if shop_controller != null and _has_method(shop_controller, &"stop"):
		shop_controller.call("stop")

	# Resume game safely
	_set_game_paused(false)

	_slide_closed_and_count()

	_current_planet = null


func is_open() -> bool:
	return _open


func notify_close_anim_done() -> void:
	_on_one_close_anim_done()


# =====================================================================
# FULL UI ENABLE/DISABLE
# =====================================================================

func _set_ui_active(active: bool) -> void:
	visible = active

	if active == true:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(true)
		set_process_unhandled_input(true)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
		set_process_unhandled_input(false)


# =====================================================================
# PANEL SLIDE ANIMATION (includes portrait panel)
# =====================================================================

func _slide_open() -> void:
	if _open == true:
		return

	_open = true

	_kill_panel_tween()
	_kill_portrait_tween()

	var tw: Tween = create_tween()
	_active_tween_panel = tw
	tw.set_ignore_time_scale(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Main panel
	tw.tween_property(panel, "position:x", _panel_shown_x, tween_time)

	# Portrait panel
	if portrait_panel != null:
		var tw2: Tween = create_tween()
		_active_tween_portrait = tw2
		tw2.set_ignore_time_scale(true)
		tw2.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(portrait_panel, "position:x", _portrait_shown_x, tween_time)
		tw2.finished.connect(_on_portrait_tween_finished)

	tw.finished.connect(_on_panel_tween_finished)


func _slide_closed_and_count() -> void:
	if _open == false:
		return

	_open = false
	_pending_close_anims += 1

	_kill_panel_tween()
	_kill_portrait_tween()

	var tw: Tween = create_tween()
	_active_tween_panel = tw
	tw.set_ignore_time_scale(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	# Main panel
	tw.tween_property(panel, "position:x", _panel_hidden_x, tween_time)

	# Portrait panel
	if portrait_panel != null:
		var tw2: Tween = create_tween()
		_active_tween_portrait = tw2
		tw2.set_ignore_time_scale(true)
		tw2.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw2.tween_property(portrait_panel, "position:x", _portrait_hidden_x, tween_time)
		tw2.finished.connect(_on_portrait_tween_finished)

	tw.finished.connect(_on_one_close_anim_done)
	tw.finished.connect(_on_panel_tween_finished)


func _on_one_close_anim_done() -> void:
	_pending_close_anims -= 1
	if _pending_close_anims > 0:
		return

	_closing = false
	_set_ui_active(false)


# =====================================================================
# OPTIONAL PAGES (comms/fleet/shop)
# =====================================================================

func _show_page(page: StringName) -> void:
	_active_page = page

	var show_comms: bool = page == &"comms"
	var show_fleet: bool = page == &"fleet"
	var show_shop: bool = page == &"shop"

	if comms_page != null:
		comms_page.visible = show_comms
	if fleet_page != null:
		fleet_page.visible = show_fleet
	if shop_page != null:
		shop_page.visible = show_shop


func show_comms_page() -> void:
	if comms_controller != null and _has_method(comms_controller, &"refresh"):
		comms_controller.call("refresh")
	_show_page(&"comms")


func show_fleet_page() -> void:
	if fleet_controller != null and _has_method(fleet_controller, &"refresh"):
		fleet_controller.call("refresh")
	_show_page(&"fleet")


func show_shop_page() -> void:
	if shop_controller != null and _has_method(shop_controller, &"refresh"):
		shop_controller.call("refresh")
	_show_page(&"shop")


func show_none_page() -> void:
	_show_page(&"none")


func close_button_pressed() -> void:
	close_ui()


# =====================================================================
# Dialogue detection
# =====================================================================

func _planet_has_dialogue(planet: Node) -> bool:
	if planet == null or not is_instance_valid(planet):
		return false

	var dr: Variant = _safe_get(planet, &"dialogue_resource")
	if dr is DialogueResource:
		return true

	var data: Variant = _safe_get(planet, &"dialogue_data")
	if data is Object:
		var dr2: Variant = _safe_get(data as Object, &"dialogue_resource")
		if dr2 is DialogueResource:
			return true

	return false


func _has_property(obj: Object, prop: StringName) -> bool:
	if obj == null:
		return false
	var props: Array = obj.get_property_list()
	for p in props:
		var d: Dictionary = p as Dictionary
		if d.has("name") and StringName(d["name"]) == prop:
			return true
	return false


func _safe_get(obj: Object, prop: StringName) -> Variant:
	if _has_property(obj, prop):
		return obj.get(str(prop))
	return null
