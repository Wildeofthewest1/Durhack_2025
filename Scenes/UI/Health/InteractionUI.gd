extends Control
class_name InteractionUI

@onready var _panel: Control = $Panel
@onready var _comms_page: Control = $Panel/MainVBox/ContentMarginContainer/TabContainer/CommsPage
@onready var _fleet_page: Control = $Panel/MainVBox/ContentMarginContainer/TabContainer/FleetPage
@onready var _shop_page: Control = $Panel/MainVBox/ContentMarginContainer/TabContainer/ShopPage

# --- PORTRAIT refs
@onready var _portrait_panel: Control = $PortraitPanel
@onready var _portrait_frame: Panel = $PortraitPanel/PortraitFrame
@onready var _portrait_texture_rect: TextureRect = $PortraitPanel/PortraitFrame/PortraitTexture

# --- COMMS refs
@onready var _planet_name_label: Label = $Panel/MainVBox/ContentMarginContainer/TabContainer/CommsPage/CommsVBox/PlanetNameLabel
@onready var _dialogue_text: RichTextLabel = $Panel/MainVBox/ContentMarginContainer/TabContainer/CommsPage/CommsVBox/DialogueText
@onready var _reply_holder: VBoxContainer = $Panel/MainVBox/ContentMarginContainer/TabContainer/CommsPage/CommsVBox/ReplyButtonsHolder

# --- FLEET refs
@onready var _fleet_list: ItemList = $Panel/MainVBox/ContentMarginContainer/TabContainer/FleetPage/FleetVBox/FleetList
@onready var _assign_button: Button = $Panel/MainVBox/ContentMarginContainer/TabContainer/FleetPage/FleetVBox/AssignSelectedButton

# --- SHOP refs
@onready var _shop_list: ItemList = $Panel/MainVBox/ContentMarginContainer/TabContainer/ShopPage/ShopVBox/ShopList
@onready var _buy_button: Button = $Panel/MainVBox/ContentMarginContainer/TabContainer/ShopPage/ShopVBox/BuyButton

# --- TAB BUTTONS
@onready var _comms_tab_button: Button = $Panel/MainVBox/MarginContainer/TopBar/CommsTabButton
@onready var _fleet_tab_button: Button = $Panel/MainVBox/MarginContainer/TopBar/FleetTabButton
@onready var _shop_tab_button: Button = $Panel/MainVBox/MarginContainer/TopBar/ShopTabButton

# Animation settings
@export var hidden_x: float = 400.0
@export var shown_x: float = 0.0
@export var tween_time: float = 0.18

@export var fast_scale: =1.0
@export var slow_scale: =0.0
var _target:float = 0.2

# portrait anim settings
@export var portrait_fade_time: float = 0.15

# Styling
@export var panel_bg_color: Color = Color(0.15, 0.15, 0.15, 0.95)

var _open: bool = false
var _active_tab: String = "COMMS"
var _current_planet: PlanetNPC = null


func _ready() -> void:
	# Start panel hidden (slide off to the right)
	var pos: Vector2 = _panel.position
	pos.x = hidden_x
	_panel.position = pos

	_open = false
	_show_tab("COMMS")

	# connect buttons
	_assign_button.pressed.connect(_on_assign_pressed)
	_buy_button.pressed.connect(_on_buy_pressed)

	# Portrait starts invisible
	_portrait_panel.visible = false
	var start_col: Color = _portrait_panel.modulate
	start_col.a = 0.0
	_portrait_panel.modulate = start_col

	# Style background panel
	var theme: Theme = Theme.new()
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = panel_bg_color
	stylebox.set_content_margin_all(0)
	theme.set_stylebox("panel", "PanelContainer", stylebox)
	_panel.theme = theme


# =====================================================================
# PUBLIC API (called from PlayerInteraction)
# =====================================================================

func toggle_for_planet(planet: PlanetNPC) -> void:
	# If open, close. If closed, open for this planet.
	if _open == true:
		close_ui()
		return

	open_for_planet(planet)


func open_for_planet(planet: PlanetNPC) -> void:
	_current_planet = planet

	_refresh_comms()
	_refresh_fleet()
	_refresh_shop()
	_show_tab("COMMS")

	_update_portrait()
	_fade_portrait_in()

	_slide_open()


func close_ui() -> void:
	_slide_closed()
	_fade_portrait_out()
	_current_planet = null


func is_open() -> bool:
	return _open

func _physics_process(delta: float) -> void:
	if _open:
		_target = slow_scale
	else:
		_target = fast_scale
	Engine.time_scale = lerp(Engine.time_scale, _target, 1.0 - pow(0.001, delta))

# =====================================================================
# PORTRAIT HANDLING
# =====================================================================

func _update_portrait() -> void:
	var tex: Texture2D = null
	if _current_planet != null:
		if _current_planet.dialogue_data != null:
			tex = _current_planet.dialogue_data.portrait_texture
	_portrait_texture_rect.texture = tex


func _fade_portrait_in() -> void:
	_portrait_panel.visible = true

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
	var tw: Tween = create_tween()
	tw.tween_property(
		_portrait_panel,
		"modulate:a",
		0.0,
		portrait_fade_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(_on_portrait_fade_done)


func _on_portrait_fade_done() -> void:
	_portrait_panel.visible = false


# =====================================================================
# PANEL SLIDE ANIMATION
# =====================================================================

func _slide_open() -> void:
	if _open == true:
		return

	_open = true

	var tw: Tween = create_tween()
	tw.tween_property(
		_panel,
		"position:x",
		shown_x,
		tween_time
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _slide_closed() -> void:
	if _open == false:
		return

	_open = false

	var tw: Tween = create_tween()
	tw.tween_property(
		_panel,
		"position:x",
		hidden_x,
		tween_time
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


# =====================================================================
# TAB / PAGE HANDLING
# =====================================================================

func _show_tab(tab_name: String) -> void:
	_active_tab = tab_name

	var show_comms: bool = tab_name == "COMMS"
	var show_fleet: bool = tab_name == "FLEET"
	var show_shop: bool = tab_name == "SHOP"

	_comms_page.visible = show_comms
	_fleet_page.visible = show_fleet
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

	var c_mod: Color = _comms_tab_button.modulate
	c_mod.a = comms_alpha
	_comms_tab_button.modulate = c_mod

	var f_mod: Color = _fleet_tab_button.modulate
	f_mod.a = fleet_alpha
	_fleet_tab_button.modulate = f_mod

	var s_mod: Color = _shop_tab_button.modulate
	s_mod.a = shop_alpha
	_shop_tab_button.modulate = s_mod


# =====================================================================
# DATA POPULATION (COMMS / FLEET / SHOP)
# =====================================================================

func _refresh_comms() -> void:
	if _current_planet == null:
		return

	# name
	_planet_name_label.text = _current_planet.get_planet_name()

	# dialogue text block
	var lines: Array[String] = _current_planet.get_dialogue_lines()
	var full_text: String = ""
	for line in lines:
		full_text += line + "\n\n"
	_dialogue_text.text = full_text

	# replies
	for child in _reply_holder.get_children():
		child.queue_free()

	var replies: Array[String] = _current_planet.get_dialogue_replies()
	for reply in replies:
		var btn: Button = Button.new()
		btn.text = reply
		btn.pressed.connect(_on_reply_pressed.bind(reply))
		_reply_holder.add_child(btn)


func _refresh_fleet() -> void:
	_fleet_list.clear()

	var drones: Array[DroneFollower] = FleetManager.get_drones()

	for dr in drones:
		# -------------------------------------------------------
		# 1. DEAD or FREED DRONE?
		# -------------------------------------------------------
		if dr == null or not is_instance_valid(dr):
			_fleet_list.add_item("Respawning drone...")
			continue

		# -------------------------------------------------------
		# 2. LIVE DRONE — SAFE TO ACCESS PROPERTIES
		# -------------------------------------------------------
		var follow_name := "None"
		if dr.follow_body != null and is_instance_valid(dr.follow_body):
			follow_name = dr.follow_body.name

		var label := dr.drone_name + " (guarding: " + follow_name + ")"
		_fleet_list.add_item(label)



func _refresh_shop() -> void:
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
	var new_text: String = _dialogue_text.text
	new_text += "\nPLAYER: " + reply_text + "\n"
	_dialogue_text.text = new_text
	_dialogue_text.scroll_to_line(_dialogue_text.get_line_count())


func _on_assign_pressed() -> void:
	if _current_planet == null:
		return

	var selected_items = _fleet_list.get_selected_items()
	if selected_items.is_empty():
		return

	var idx: int = selected_items[0]
	var drones: Array[DroneFollower] = FleetManager.get_drones()

	if idx < 0 or idx >= drones.size():
		return

	var drone: DroneFollower = drones[idx]

	# =====================================================
	# TOGGLE BEHAVIOUR:
	# If drone is already guarding THIS planet → return to player
	# If drone is guarding anything else → assign to this planet
	# =====================================================

	if drone.follow_body == _current_planet:
		# Return to player
		drone.follow_body = FleetManager.player
		print("🔄 Drone returned to player:", drone.name)
	else:
		# Assign to this planet/station
		drone.follow_body = _current_planet
		print("📡 Drone assigned to station:", _current_planet.name)

	_refresh_fleet()



func _on_buy_pressed() -> void:
	var sel_arr: Array[int] = _shop_list.get_selected_items()
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
