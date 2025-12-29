extends Control
class_name InteractionUI

# =====================================================================
# ROOT ORCHESTRATOR
# - owns open/close animation
# - switches tabs
# - delegates page logic to child controllers
# =====================================================================

@export var panel: Control
@export var comms_page: Control
@export var fleet_page: Control
@export var shop_page: Control

@export var comms_tab_button: Button
@export var fleet_tab_button: Button
@export var shop_tab_button: Button

@export var panel_hide_offset: float = 400.0
@export var tween_time: float = 0.18

# Child controllers (drag from scene tree)
@export var portrait_controller: Node
@export var comms_controller: Node
@export var fleet_controller: Node
@export var shop_controller: Node

var _open: bool = false
var _active_tab: String = "COMMS"
var _panel_shown_x: float = 0.0
var _panel_hidden_x: float = 0.0

# close gating
var _pending_close_anims: int = 0
var _closing: bool = false

# data
var _current_planet: Node = null

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
	_show_tab("COMMS")
	_set_ui_active(false)

	# Hook up tab buttons (scene already has connections, but this makes it resilient)
	if comms_tab_button != null and not comms_tab_button.pressed.is_connected(show_comms_tab):
		comms_tab_button.pressed.connect(show_comms_tab)
	if fleet_tab_button != null and not fleet_tab_button.pressed.is_connected(show_fleet_tab):
		fleet_tab_button.pressed.connect(show_fleet_tab)
	if shop_tab_button != null and not shop_tab_button.pressed.is_connected(show_shop_tab):
		shop_tab_button.pressed.connect(show_shop_tab)

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

	# Pause the game
	get_tree().paused = true

	# Reactivate BEFORE populating / animating
	_set_ui_active(true)

	# Delegate population
	if portrait_controller != null:
		portrait_controller.call("setup_for_planet", planet)
		portrait_controller.call("fade_in")

	if comms_controller != null:
		comms_controller.call("setup_for_planet", planet)

	if fleet_controller != null:
		fleet_controller.call("setup_for_planet", planet)

	if shop_controller != null:
		shop_controller.call("setup_for_planet", planet)

	_show_tab("COMMS")
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

	# Resume the game immediately
	get_tree().paused = false

	_slide_closed_and_count()

	if portrait_controller != null:
		_pending_close_anims += 1
		portrait_controller.call("fade_out")

	_current_planet = null

func is_open() -> bool:
	return _open

func notify_close_anim_done() -> void:
	_on_one_close_anim_done()

# =====================================================================
# FULL UI ENABLE/DISABLE (prevents clashing with other UI)
# =====================================================================

func _set_ui_active(active: bool) -> void:
	visible = active
	if active == true:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(true)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

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
# TAB / PAGE HANDLING
# =====================================================================

func _show_tab(tab_name: String) -> void:
	_active_tab = tab_name

	var show_comms: bool = tab_name == "COMMS"
	var show_fleet: bool = tab_name == "FLEET"
	var show_shop: bool = tab_name == "SHOP"

	if comms_page != null:
		comms_page.visible = show_comms
	if fleet_page != null:
		fleet_page.visible = show_fleet
	if shop_page != null:
		shop_page.visible = show_shop

	_update_tab_button_alpha("COMMS", show_comms, comms_tab_button)
	_update_tab_button_alpha("FLEET", show_fleet, fleet_tab_button)
	_update_tab_button_alpha("SHOP", show_shop, shop_tab_button)

func _update_tab_button_alpha(tab_name: String, is_active: bool, button: Button) -> void:
	if button == null:
		return

	var target_alpha: float = 1.0 if is_active else 0.6
	var c_mod: Color = button.modulate
	c_mod.a = target_alpha
	button.modulate = c_mod

# =====================================================================
# TAB SWITCH HELPERS (hook these to the top bar tab buttons)
# =====================================================================

func show_comms_tab() -> void:
	_show_tab("COMMS")

func show_fleet_tab() -> void:
	if fleet_controller != null:
		fleet_controller.call("refresh")
	_show_tab("FLEET")

func show_shop_tab() -> void:
	if shop_controller != null:
		shop_controller.call("refresh")
	_show_tab("SHOP")

func close_button_pressed() -> void:
	close_ui()
