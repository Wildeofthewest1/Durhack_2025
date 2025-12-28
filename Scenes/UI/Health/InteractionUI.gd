extends Control
#class_name InteractionUI

@export var _panel: Control
@export var _comms_page: Control
@export var _fleet_page: Control
@export var _shop_page: Control
@export var _portrait_panel: Control
@export var _portrait_texture_rect: TextureRect
@export var _planet_name_label: Label
@export var _dialogue_text: RichTextLabel
@export var _reply_holder: VBoxContainer
@export var _fleet_list: ItemList
@export var _assign_button: Button
@export var _shop_list: ItemList
@export var _buy_button: Button
@export var _comms_tab_button: Button
@export var _fleet_tab_button: Button
@export var _shop_tab_button: Button

# Animation settings
@export var panel_hide_offset: float = 400.0
@export var portrait_hide_offset: float = 400.0
@export var tween_time: float = 0.18

@export var fast_scale: float = 1.0
@export var slow_scale: float = 0.01

# portrait anim settings
@export var portrait_fade_time: float = 0.15

# Styling
@export var panel_bg_color: Color = Color(0.15, 0.15, 0.15, 0.95)

var _open: bool = false
var _active_tab: String = "COMMS"
var _current_planet: PlanetNPC = null
var _panel_shown_x: float = 0.0
var _panel_hidden_x: float = 0.0
var _portrait_shown_x: float = 0.0
var _portrait_hidden_x: float = 0.0
var _current_time_scale: float = 1.0

# close gating
var _pending_close_anims: int = 0
var _closing: bool = false

func _ready() -> void:
	if _panel == null:
		return

	# Store original shown positions
	_panel_shown_x = _panel.position.x
	_panel_hidden_x = _panel_shown_x + panel_hide_offset

	if _portrait_panel != null:
		_portrait_shown_x = _portrait_panel.position.x
		_portrait_hidden_x = _portrait_shown_x - portrait_hide_offset

	# Start panel hidden (slide right)
	var panel_pos: Vector2 = _panel.position
	panel_pos.x = _panel_hidden_x
	_panel.position = panel_pos

	# Start portrait hidden (slide left)
	if _portrait_panel != null:
		var portrait_pos: Vector2 = _portrait_panel.position
		portrait_pos.x = _portrait_hidden_x
		_portrait_panel.position = portrait_pos
		_portrait_panel.visible = false
		var start_col: Color = _portrait_panel.modulate
		start_col.a = 0.0
		_portrait_panel.modulate = start_col

	_open = false
	_show_tab("COMMS")

	# connect buttons
	if _assign_button != null:
		_assign_button.pressed.connect(_on_assign_pressed)
	if _buy_button != null:
		_buy_button.pressed.connect(_on_buy_pressed)

	# Style background panel
	var theme: Theme = Theme.new()
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = panel_bg_color
	stylebox.set_content_margin_all(0)
	theme.set_stylebox("panel", "PanelContainer", stylebox)
	_panel.theme = theme

	# IMPORTANT: start fully inactive so it cannot clash with other UI
	_set_ui_active(false)


# =====================================================================
# PUBLIC API (called from PlayerInteraction)
# =====================================================================

func toggle_for_planet(planet: PlanetNPC) -> void:
	if _open == true:
		close_ui()
		return
	open_for_planet(planet)

func open_for_planet(planet: PlanetNPC) -> void:
	if _panel == null:
		return

	_closing = false
	_current_planet = planet

	# Reactivate the UI BEFORE populating / animating
	_set_ui_active(true)

	_refresh_comms()
	_refresh_fleet()
	_refresh_shop()
	_show_tab("COMMS")

	_update_portrait()
	_fade_portrait_in()

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

	# We want animations to play, then fully disable UI.
	_slide_closed_and_count()
	_fade_portrait_out_and_count()

	_current_planet = null

func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	# Only runs while UI active (we disable processing when closed)
	var target_scale: float = fast_scale
	if _open == true:
		target_scale = slow_scale

	_current_time_scale = lerp(_current_time_scale, target_scale, 0.1)
	Engine.time_scale = _current_time_scale


# =====================================================================
# FULL UI ENABLE/DISABLE (prevents clashing with other UI)
# =====================================================================

func _set_ui_active(active: bool) -> void:
	# When inactive, hide entire Control and ignore inputs
	visible = active

	if active == true:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(true)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

		# Always restore time when closed
		_current_time_scale = 1.0
		Engine.time_scale = 1.0


# =====================================================================
# PORTRAIT HANDLING
# =====================================================================

func _update_portrait() -> void:
	var tex: Texture2D = null
	if _current_planet != null:
		if _current_planet.dialogue_data != null:
			tex = _current_planet.dialogue_data.portrait_texture
	if _portrait_texture_rect != null:
		_portrait_texture_rect.texture = tex

func _fade_portrait_in() -> void:
	if _portrait_panel == null:
		return

	_portrait_panel.visible = true
	_portrait_panel.position.x = _portrait_shown_x

	var start_col: Color = _portrait_panel.modulate
	start_col.a = 0.0
	_portrait_panel.modulate = start_col

	var tw: Tween = create_tween()
	tw.tween_property(
		_portrait_panel,
		"modulate:a",
		1.0,
		portrait_fade_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fade_portrait_out() -> void:
	if _portrait_panel == null:
		return

	var tw: Tween = create_tween()
	tw.tween_property(
		_portrait_panel,
		"modulate:a",
		0.0,
		portrait_fade_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(_on_portrait_fade_done)

func _on_portrait_fade_done() -> void:
	if _portrait_panel == null:
		return
	_portrait_panel.visible = false


# Close-counted version
func _fade_portrait_out_and_count() -> void:
	if _portrait_panel == null:
		return

	_pending_close_anims += 1

	var tw: Tween = create_tween()
	tw.tween_property(
		_portrait_panel,
		"modulate:a",
		0.0,
		portrait_fade_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tw.finished.connect(_on_one_close_anim_done)


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
	tw.tween_property(
		_panel,
		"position:x",
		_panel_shown_x,
		tween_time
	)

func _slide_closed() -> void:
	if _open == false:
		return

	_open = false

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.set_ignore_time_scale(true)
	tw.tween_property(
		_panel,
		"position:x",
		_panel_hidden_x,
		tween_time
	)

# Close-counted version
func _slide_closed_and_count() -> void:
	if _open == false:
		return

	_open = false
	_pending_close_anims += 1

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.set_ignore_time_scale(true)
	tw.tween_property(
		_panel,
		"position:x",
		_panel_hidden_x,
		tween_time
	)

	tw.finished.connect(_on_one_close_anim_done)


func _on_one_close_anim_done() -> void:
	_pending_close_anims -= 1
	if _pending_close_anims > 0:
		return

	# All close animations done -> fully disable so it can't clash
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

	if _comms_page != null:
		_comms_page.visible = show_comms
	if _fleet_page != null:
		_fleet_page.visible = show_fleet
	if _shop_page != null:
		_shop_page.visible = show_shop

	# Calculate alphas manually (no ternary)
	var comms_alpha: float = 0.6
	var fleet_alpha: float = 0.6
	var shop_alpha: float = 0.6

	if show_comms == true:
		comms_alpha = 1.0
	if show_fleet == true:
		fleet_alpha = 1.0
	if show_shop == true:
		shop_alpha = 1.0

	if _comms_tab_button != null:
		var c_mod: Color = _comms_tab_button.modulate
		c_mod.a = comms_alpha
		_comms_tab_button.modulate = c_mod

	if _fleet_tab_button != null:
		var f_mod: Color = _fleet_tab_button.modulate
		f_mod.a = fleet_alpha
		_fleet_tab_button.modulate = f_mod

	if _shop_tab_button != null:
		var s_mod: Color = _shop_tab_button.modulate
		s_mod.a = shop_alpha
		_shop_tab_button.modulate = s_mod


# =====================================================================
# DATA POPULATION (COMMS / FLEET / SHOP)
# =====================================================================

func _refresh_comms() -> void:
	if _current_planet == null:
		return

	if _planet_name_label != null:
		_planet_name_label.text = _current_planet.get_planet_name()

	if _dialogue_text != null:
		var lines: Array[String] = _current_planet.get_dialogue_lines()
		var full_text: String = ""
		for line in lines:
			full_text += line + "\n\n"
		_dialogue_text.text = full_text

	if _reply_holder != null:
		for child in _reply_holder.get_children():
			child.queue_free()

		var replies: Array[String] = _current_planet.get_dialogue_replies()
		for reply in replies:
			var btn: Button = Button.new()
			btn.text = reply
			btn.pressed.connect(_on_reply_pressed.bind(reply))
			_reply_holder.add_child(btn)

func _refresh_fleet() -> void:
	if _fleet_list == null:
		return

	_fleet_list.clear()

	var drones: Array[DroneFollower] = FleetManager.get_drones()

	for dr in drones:
		if dr == null or not is_instance_valid(dr):
			_fleet_list.add_item("Respawning drone...")
			continue

		var follow_name: String = "None"
		if dr.follow_body != null and is_instance_valid(dr.follow_body):
			follow_name = dr.follow_body.name

		var label: String = dr.drone_name + " (guarding: " + follow_name + ")"
		_fleet_list.add_item(label)

func _refresh_shop() -> void:
	if _shop_list == null:
		return

	_shop_list.clear()

	if _current_planet == null:
		return

	var items: Array[String] = _current_planet.get_shop_items()
	var prices: Array[int] = _current_planet.get_shop_prices()

	var len_items: int = items.size()
	var len_prices: int = prices.size()
	var max_len: int = len_items
	if len_prices < max_len:
		max_len = len_prices

	for i in range(max_len):
		var line_text: String = items[i] + " - " + str(prices[i]) + " cr"
		_shop_list.add_item(line_text)


# =====================================================================
# BUTTON CALLBACKS
# =====================================================================

func _on_reply_pressed(reply_text: String) -> void:
	if _dialogue_text == null:
		return

	var new_text: String = _dialogue_text.text
	new_text += "\nPLAYER: " + reply_text + "\n"
	_dialogue_text.text = new_text
	_dialogue_text.scroll_to_line(_dialogue_text.get_line_count())

func _on_assign_pressed() -> void:
	if _current_planet == null:
		return
	if _fleet_list == null:
		return

	var selected_items: = _fleet_list.get_selected_items()
	if selected_items.is_empty():
		return

	var idx: int = selected_items[0]
	var drones: Array[DroneFollower] = FleetManager.get_drones()

	if idx < 0 or idx >= drones.size():
		return

	var drone: DroneFollower = drones[idx]

	if drone.follow_body == _current_planet:
		drone.follow_body = FleetManager.player
		print("🔄 Drone returned to player:", drone.name)
	else:
		drone.follow_body = _current_planet
		print("📡 Drone assigned to station:", _current_planet.name)

	_refresh_fleet()

func _on_buy_pressed() -> void:
	if _shop_list == null:
		return

	var sel_arr:  = _shop_list.get_selected_items()
	if sel_arr.is_empty():
		return

	var idx: int = sel_arr[0]
	print("[SHOP] Buy index " + str(idx) + " from " + str(_current_planet))


# =====================================================================
# TAB SWITCH HELPERS (hook these to the top bar tab buttons in the editor)
# =====================================================================

func show_comms_tab() -> void:
	_show_tab("COMMS")

func show_fleet_tab() -> void:
	_refresh_fleet()
	_show_tab("FLEET")

func show_shop_tab() -> void:
	_refresh_shop()
	_show_tab("SHOP")

func close_button_pressed() -> void:
	close_ui()
