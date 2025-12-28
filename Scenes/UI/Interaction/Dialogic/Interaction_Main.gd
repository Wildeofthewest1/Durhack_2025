extends Control
class_name InteractionUI

# --- Scene refs (your layout) ---
@export var panel: Control

@export var tab_container: TabContainer

@export var comms_page: Control
@export var fleet_page: Control
@export var shop_page: Control

@export var comms_tab_button: Button
@export var fleet_tab_button: Button
@export var shop_tab_button: Button
@export var close_button: Button

# NEW: dialogue bridge (separate Control node in the scene)
@export var dialogue_bridge: DialogueUIBridge

# --- Animation settings ---
@export var panel_hide_offset: float = 400.0
@export var tween_time: float = 0.18

# --- Time scale settings ---
@export var fast_scale: float = 1.0
@export var slow_scale: float = 0.01

# --- Internal state ---
var _open: bool = false
var _closing: bool = false
var _pending_close_anims: int = 0

var _current_planet: PlanetNPC = null

var _panel_shown_x: float = 0.0
var _panel_hidden_x: float = 0.0

var _current_time_scale: float = 1.0

# Tracks whether THIS UI currently holds the gameplay lock
var _holds_gameplay_lock: bool = false

enum TabId { COMMS, FLEET, SHOP }

func _ready() -> void:
	if panel == null:
		return

	_panel_shown_x = panel.position.x
	_panel_hidden_x = _panel_shown_x + panel_hide_offset

	# start hidden
	var p: Vector2 = panel.position
	p.x = _panel_hidden_x
	panel.position = p

	# TabContainer: we use it like a page stack (hide its own tabs)
	if tab_container != null:
		tab_container.tabs_visible = false
		tab_container.current_tab = int(TabId.COMMS)

	# connect buttons
	if comms_tab_button != null:
		comms_tab_button.pressed.connect(show_comms_tab)
	if fleet_tab_button != null:
		fleet_tab_button.pressed.connect(show_fleet_tab)
	if shop_tab_button != null:
		shop_tab_button.pressed.connect(show_shop_tab)
	if close_button != null:
		close_button.pressed.connect(close_ui)

	# Start inactive so it can't clash
	_set_ui_active(false)

func toggle_for_planet(planet: PlanetNPC) -> void:
	if _open == true:
		close_ui()
		return
	open_for_planet(planet)

func open_for_planet(planet: PlanetNPC) -> void:
	if panel == null:
		return

	_closing = false
	_current_planet = planet

	_set_ui_active(true)

	# Pass planet down to pages if they implement set_planet()
	_call_set_planet_on_page(comms_page, planet)
	_call_set_planet_on_page(fleet_page, planet)
	_call_set_planet_on_page(shop_page, planet)

	show_comms_tab()
	_slide_open()

	# NEW: start dialogue for this NPC when UI opens
	if dialogue_bridge != null:
		if "dialogic_timeline" in planet:
			var tl: Resource = planet.dialogic_timeline as Resource
			dialogue_bridge.start_from_npc(planet)

func close_ui() -> void:
	# Stop dialogic first (recommended)
	if dialogue_bridge != null:
		dialogue_bridge.stop_dialogue()

	# If already closed, just ensure inactive + unlocked
	if _open == false:
		_set_ui_active(false)
		_current_planet = null
		return

	if _closing == true:
		return

	_closing = true
	_pending_close_anims = 0
	_open = false

	_slide_closed_and_count()
	_current_planet = null

func is_open() -> bool:
	return _open

func _process(delta: float) -> void:
	# Only runs while active (we disable process when closed)
	var target_scale: float = fast_scale
	if _open == true:
		target_scale = slow_scale

	_current_time_scale = lerp(_current_time_scale, target_scale, 0.1)
	Engine.time_scale = _current_time_scale

# -------------------------
# Enable/Disable whole UI
# -------------------------
func _set_ui_active(active: bool) -> void:
	visible = active

	if active == true:
		# Lock gameplay once
		if _holds_gameplay_lock == false:
			InputLock.lock_gameplay()
			_holds_gameplay_lock = true

		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(true)
	else:
		# Unlock gameplay once
		if _holds_gameplay_lock == true:
			InputLock.unlock_gameplay()
			_holds_gameplay_lock = false

		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

		_current_time_scale = 1.0
		Engine.time_scale = 1.0

# -------------------------
# Tabs
# -------------------------
func show_comms_tab() -> void:
	_set_tab(TabId.COMMS)

func show_fleet_tab() -> void:
	_call_refresh_on_page(fleet_page)
	_set_tab(TabId.FLEET)

func show_shop_tab() -> void:
	_call_refresh_on_page(shop_page)
	_set_tab(TabId.SHOP)

func _set_tab(tab: TabId) -> void:
	if tab_container != null:
		tab_container.current_tab = int(tab)

	_set_tab_button_alpha(comms_tab_button, tab == TabId.COMMS)
	_set_tab_button_alpha(fleet_tab_button, tab == TabId.FLEET)
	_set_tab_button_alpha(shop_tab_button, tab == TabId.SHOP)

func _set_tab_button_alpha(btn: Button, active: bool) -> void:
	if btn == null:
		return

	var a: float = 0.6
	if active == true:
		a = 1.0

	var c: Color = btn.modulate
	c.a = a
	btn.modulate = c

# -------------------------
# Slide Animations
# -------------------------
func _slide_open() -> void:
	if _open == true:
		return

	_open = true

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_ignore_time_scale(true)
	tw.tween_property(panel, "position:x", _panel_shown_x, tween_time)

func _slide_closed_and_count() -> void:
	_pending_close_anims += 1

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_IN)
	tw.set_ignore_time_scale(true)
	tw.tween_property(panel, "position:x", _panel_hidden_x, tween_time)

	tw.finished.connect(_on_one_close_anim_done)

func _on_one_close_anim_done() -> void:
	_pending_close_anims -= 1
	if _pending_close_anims > 0:
		return

	_closing = false
	_set_ui_active(false)

# -------------------------
# Helpers to call page APIs
# -------------------------
func _call_set_planet_on_page(page: Control, planet: PlanetNPC) -> void:
	if page == null:
		return
	if page.has_method("set_planet") == true:
		page.call("set_planet", planet)

func _call_refresh_on_page(page: Control) -> void:
	if page == null:
		return
	if page.has_method("refresh") == true:
		page.call("refresh")
