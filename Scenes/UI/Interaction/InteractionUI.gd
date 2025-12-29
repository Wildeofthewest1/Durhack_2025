extends Control
class_name InteractionUI

# =====================================================================
# ROOT ORCHESTRATOR
# - owns open/close animation + time scale
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

@export var fast_scale: float = 1.0
@export var slow_scale: float = 0.1

# Child controllers (drag from scene tree)
@export var portrait_controller: Node
@export var comms_controller: Node
@export var fleet_controller: Node
@export var shop_controller: Node

var _open: bool = false
var _active_tab: String = "COMMS"
var _panel_shown_x: float = 0.0
var _panel_hidden_x: float = 0.0
var _current_time_scale: float = 1.0

# close gating
var _pending_close_anims: int = 0
var _closing: bool = false

# data
var _current_planet: Node = null

func _ready() -> void:
	if panel == null:
		return

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
	if comms_tab_button != null and comms_tab_button.pressed.is_connected(show_comms_tab) == false:
		comms_tab_button.pressed.connect(show_comms_tab)
	if fleet_tab_button != null and fleet_tab_button.pressed.is_connected(show_fleet_tab) == false:
		fleet_tab_button.pressed.connect(show_fleet_tab)
	if shop_tab_button != null and shop_tab_button.pressed.is_connected(show_shop_tab) == false:
		shop_tab_button.pressed.connect(show_shop_tab)

func _process(_delta: float) -> void:
	# Only runs while UI active (we disable processing when closed)
	var target_scale: float = fast_scale
	if _open == true:
		target_scale = slow_scale

	_current_time_scale = lerp(_current_time_scale, target_scale, 0.1)
	Engine.time_scale = _current_time_scale

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

	_slide_closed_and_count()

	if portrait_controller != null:
		# portrait controller will call back into _on_one_close_anim_done via signal OR we just count a tween here
		_pending_close_anims += 1
		portrait_controller.call("fade_out")
		# portrait controller will emit "fade_out_finished" when done

	_current_planet = null

func is_open() -> bool:
	return _open

# Called by portrait controller when its fade finishes
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

		_current_time_scale = 1.0
		Engine.time_scale = 1.0

# =====================================================================
# PANEL SLIDE ANIMATION
# =====================================================================

func _slide_open() -> void:
	if _open == true:
		return

	_open = true

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_ignore_time_scale(true)
	tw.tween_property(panel, "position:x", _panel_shown_x, tween_time)

func _slide_closed_and_count() -> void:
	if _open == false:
		return

	_open = false
	_pending_close_anims += 1

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.set_ignore_time_scale(true)
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

	var comms_alpha: float = 0.6
	var fleet_alpha: float = 0.6
	var shop_alpha: float = 0.6

	if show_comms == true:
		comms_alpha = 1.0
	if show_fleet == true:
		fleet_alpha = 1.0
	if show_shop == true:
		shop_alpha = 1.0

	if comms_tab_button != null:
		var c_mod: Color = comms_tab_button.modulate
		c_mod.a = comms_alpha
		comms_tab_button.modulate = c_mod

	if fleet_tab_button != null:
		var f_mod: Color = fleet_tab_button.modulate
		f_mod.a = fleet_alpha
		fleet_tab_button.modulate = f_mod

	if shop_tab_button != null:
		var s_mod: Color = shop_tab_button.modulate
		s_mod.a = shop_alpha
		shop_tab_button.modulate = s_mod

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
