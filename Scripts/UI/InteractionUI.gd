extends Control
class_name InteractionUI

@onready var _panel: Control = $Panel
@onready var _comms_page: Control = $Panel/MainVBox/ContentMarginContainer/TabContainer/CommsPage
@onready var _fleet_page: Control = $Panel/MainVBox/ContentMarginContainer/TabContainer/FleetPage
@onready var _shop_page: Control = $Panel/MainVBox/ContentMarginContainer/TabContainer/ShopPage

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
@export var hidden_x: float = 400.0   # offscreen offset
@export var shown_x: float = 0.0      # on-screen x
@export var tween_time: float = 0.18

# Styling
@export var panel_bg_color: Color = Color(0.15, 0.15, 0.15, 0.95)

var _open: bool = false
var _active_tab: String = "COMMS"
var _current_planet: PlanetNPC = null

func _ready() -> void:
	# start hidden to the right
	var pos: Vector2 = _panel.position
	pos.x = hidden_x
	_panel.position = pos
	_open = false
	_show_tab("COMMS")

	_assign_button.connect("pressed", Callable(self, "_on_assign_pressed"))
	_buy_button.connect("pressed", Callable(self, "_on_buy_pressed"))
	
	# Apply background color
	var theme = Theme.new()
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = panel_bg_color
	stylebox.set_content_margin_all(0)  # Remove padding from stylebox
	theme.set_stylebox("panel", "PanelContainer", stylebox)
	_panel.theme = theme

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next"):  # E key
		if _open:
			close_button_pressed()
			get_tree().root.set_input_as_handled()
		elif _current_planet != null:
			open_for_planet(_current_planet)
			get_tree().root.set_input_as_handled()

func open_for_planet(planet: PlanetNPC) -> void:
	_current_planet = planet
	_refresh_comms()
	_refresh_fleet()
	_refresh_shop()
	_show_tab("COMMS")
	_slide_open()

func close_ui() -> void:
	_slide_closed()
	_current_planet = null

func _slide_open() -> void:
	if _open == true:
		return

	_open = true
	var tw: Tween = create_tween()
	tw.tween_property(_panel, "position:x", shown_x, tween_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _slide_closed() -> void:
	if _open == false:
		return

	_open = false
	var tw: Tween = create_tween()
	tw.tween_property(_panel, "position:x", hidden_x, tween_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func _show_tab(tab_name: String) -> void:
	_active_tab = tab_name

	var show_comms: bool = tab_name == "COMMS"
	var show_fleet: bool = tab_name == "FLEET"
	var show_shop: bool = tab_name == "SHOP"

	_comms_page.visible = show_comms
	_fleet_page.visible = show_fleet
	_shop_page.visible = show_shop
	
	# Update tab button states (optional visual feedback)
	_comms_tab_button.modulate.a = 1.0 if show_comms else 0.6
	_fleet_tab_button.modulate.a = 1.0 if show_fleet else 0.6
	_shop_tab_button.modulate.a = 1.0 if show_shop else 0.6

func _refresh_comms() -> void:
	if _current_planet == null:
		return

	# planet name
	_planet_name_label.text = _current_planet.get_planet_name()

	# Combine all lines into one chat block
	var lines: Array[String] = _current_planet.get_dialogue_lines()
	var full_text: String = ""
	for line in lines:
		full_text += line + "\n\n"
	_dialogue_text.text = full_text

	# Clear old reply buttons
	for child in _reply_holder.get_children():
		child.queue_free()

	# Add new reply buttons
	var replies: Array[String] = _current_planet.get_dialogue_replies()
	for reply in replies:
		var btn: Button = Button.new()
		btn.text = reply
		btn.pressed.connect(Callable(self, "_on_reply_pressed").bind(reply))
		_reply_holder.add_child(btn)

func _refresh_fleet() -> void:
	_fleet_list.clear()

	var drones: Array[DroneFollower] = FleetManager.get_drones()
	for dr in drones:
		var follow_name: String = "None"
		if dr.follow_body != null:
			follow_name = dr.follow_body.name
		var label_text: String = dr.drone_name + " (guarding: " + follow_name + ")"
		_fleet_list.add_item(label_text)

func _refresh_shop() -> void:
	_shop_list.clear()

	if _current_planet == null:
		return

	var items: Array[String] = _current_planet.get_shop_items()
	var prices: Array[int] = _current_planet.get_shop_prices()

	var max_len: int = mini(items.size(), prices.size())

	for i in range(max_len):
		var line_text: String = items[i] + " - " + str(prices[i]) + " cr"
		_shop_list.add_item(line_text)

# --- BUTTON CALLBACKS ---

func _on_reply_pressed(reply_text: String) -> void:
	# Add the reply to the chat box
	var new_text: String = _dialogue_text.text
	new_text += "\nPLAYER: " + reply_text + "\n"
	_dialogue_text.text = new_text
	# Scroll to bottom
	_dialogue_text.scroll_to_line(_dialogue_text.get_line_count())

func _on_assign_pressed() -> void:
	if _current_planet == null:
		return

	var selected_items = _fleet_list.get_selected_items()
	if selected_items.is_empty():
		return

	var first_idx: int = selected_items[0]

	var drones: Array[DroneFollower] = FleetManager.get_drones()
	if first_idx < 0 or first_idx >= drones.size():
		return

	var chosen_drone: DroneFollower = drones[first_idx]
	chosen_drone.follow_body = _current_planet

	_refresh_fleet()

func _on_buy_pressed() -> void:
	# Implement your currency here. For now just print.
	var sel_arr: Array[int] = _shop_list.get_selected_items()
	if sel_arr.is_empty():
		return
	var idx: int = sel_arr[0]
	print("[SHOP] Buy index ", str(idx), " from ", str(_current_planet))

# --- PUBLIC tab switch helpers for the top bar buttons ---

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
