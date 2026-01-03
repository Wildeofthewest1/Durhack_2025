extends Control
class_name InteractionUI

# =====================================================================
# ROOT ORCHESTRATOR (NO COMMS PAGE)
# - panel open/close
# - safe pause
# - optional fleet/shop pages
# - triggers bubble dialogue UI only if planet/interactible has dialogue
# - keeps old API: toggle_for_planet / open_for_planet
# =====================================================================

@export var panel: Control

# Optional pages (use or leave null)
@export var fleet_page: Control
@export var shop_page: Control

@export var fleet_tab_button: Button
@export var shop_tab_button: Button

@export var panel_hide_offset: float = 400.0
@export var tween_time: float = 0.18

# Controllers
@export var portrait_controller: Node
@export var bubble_dialogue_controller: Node # your BubbleDialogueController
@export var fleet_controller: Node
@export var shop_controller: Node

var _open: bool = false
var _panel_shown_x: float = 0.0
var _panel_hidden_x: float = 0.0

# close gating
var _pending_close_anims: int = 0
var _closing: bool = false

# data
var _current_planet: Node = null

# active page (fleet/shop only; bubbles are independent)
var _active_page: StringName = &"none" # "none" | "fleet" | "shop"


func _ready() -> void:
	if panel == null:
		return

	# UI ignores pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel_shown_x = panel.position.x
	_panel_hidden_x = _panel_shown_x + panel_hide_offset

	# Start panel hidden
	var ppos: Vector2 = panel.position
	ppos.x = _panel_hidden_x
	panel.position = ppos

	_open = false
	_set_ui_active(false)
	_show_page(&"none")

	# Optional tab hookups
	if fleet_tab_button != null and not fleet_tab_button.pressed.is_connected(show_fleet_page):
		fleet_tab_button.pressed.connect(show_fleet_page)
	if shop_tab_button != null and not shop_tab_button.pressed.is_connected(show_shop_page):
		shop_tab_button.pressed.connect(show_shop_page)


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

	if bubble_dialogue_controller != null and _has_method(bubble_dialogue_controller, &"handle_input"):
		bubble_dialogue_controller.call("handle_input", event)


func _has_method(obj: Object, method_name: StringName) -> bool:
	if obj == null:
		return false
	return obj.has_method(String(method_name))


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

	# Default page: none (unless you want fleet/shop open by default)
	_show_page(&"none")

	# Portrait (optional)
	if portrait_controller != null and planet != null and is_instance_valid(planet):
		if _has_method(portrait_controller, &"setup_for_planet"):
			portrait_controller.call("setup_for_planet", planet)
		elif _has_method(portrait_controller, &"setup_for_target"):
			portrait_controller.call("setup_for_target", planet)

		if _has_method(portrait_controller, &"fade_in"):
			portrait_controller.call("fade_in")

	# Bubble dialogue: ONLY start if this planet has dialogue
	if bubble_dialogue_controller != null and _planet_has_dialogue(planet):
		if _has_method(bubble_dialogue_controller, &"setup_for_planet"):
			bubble_dialogue_controller.call("setup_for_planet", planet)
		elif _has_method(bubble_dialogue_controller, &"start_for_target"):
			bubble_dialogue_controller.call("start_for_target", planet)

	# Optional other controllers
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

	# Stop controllers (cancels dialogue flow cleanly)
	if bubble_dialogue_controller != null and _has_method(bubble_dialogue_controller, &"stop"):
		bubble_dialogue_controller.call("stop")

	if fleet_controller != null and _has_method(fleet_controller, &"stop"):
		fleet_controller.call("stop")

	if shop_controller != null and _has_method(shop_controller, &"stop"):
		shop_controller.call("stop")

	# Resume game safely
	_set_game_paused(false)

	_slide_closed_and_count()

	if portrait_controller != null and _has_method(portrait_controller, &"fade_out"):
		_pending_close_anims += 1
		portrait_controller.call("fade_out")

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
# PANEL SLIDE ANIMATION
# =====================================================================

func _slide_open() -> void:
	if _open == true:
		return

	_open = true

	var tw: Tween = create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "position:x", _panel_shown_x, tween_time)


func _slide_closed_and_count() -> void:
	if _open == false:
		return

	_open = false
	_pending_close_anims += 1

	var tw: Tween = create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "position:x", _panel_hidden_x, tween_time)
	tw.finished.connect(_on_one_close_anim_done)


func _on_one_close_anim_done() -> void:
	_pending_close_anims -= 1
	if _pending_close_anims > 0:
		return

	_closing = false
	_set_ui_active(false)


# =====================================================================
# OPTIONAL PAGES (fleet/shop only)
# =====================================================================

func _show_page(page: StringName) -> void:
	_active_page = page

	var show_fleet: bool = page == &"fleet"
	var show_shop: bool = page == &"shop"

	if fleet_page != null:
		fleet_page.visible = show_fleet
	if shop_page != null:
		shop_page.visible = show_shop


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
# Dialogue detection (same convention you've been using)
# =====================================================================

func _planet_has_dialogue(planet: Node) -> bool:
	if planet == null or not is_instance_valid(planet):
		return false

	# direct properties
	var dr: Variant = _safe_get(planet, &"dialogue_resource")
	if dr is DialogueResource:
		return true

	# nested resource approach
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
