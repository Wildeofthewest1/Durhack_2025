extends Control
class_name InteractionPanel

signal tab_changed(tab_name: String)
signal panel_opened()
signal panel_closed()

enum PanelTab {
	PLAYER,
	TALK,
	INFO
}

@export var expand_speed: float = 10.0
@export var collapsed_width: float = 40.0
@export var expanded_width: float = 450.0
@export var tab_key: Key = KEY_TAB

@onready var panel_container: PanelContainer = $PanelContainer
@onready var tab_buttons_container: VBoxContainer = $TabButtons
@onready var content_container: Control = $PanelContainer/MarginContainer/ContentContainer

# Tab content nodes
@onready var player_content: Control = $PanelContainer/MarginContainer/ContentContainer/PlayerContent
@onready var talk_content: Control = $PanelContainer/MarginContainer/ContentContainer/TalkContent
@onready var info_content: Control = $PanelContainer/MarginContainer/ContentContainer/InfoContent

# Tab buttons
@onready var player_tab_button: Button = $TabButtons/PlayerTab
@onready var talk_tab_button: Button = $TabButtons/TalkTab
@onready var info_tab_button: Button = $TabButtons/InfoTab

var is_expanded: bool = false
var target_width: float = 0.0
var current_tab: PanelTab = PanelTab.PLAYER

func _ready() -> void:
	custom_minimum_size.x = collapsed_width
	target_width = collapsed_width
	
	# Connect tab buttons
	if player_tab_button:
		player_tab_button.pressed.connect(_on_player_tab_pressed)
	if talk_tab_button:
		talk_tab_button.pressed.connect(_on_talk_tab_pressed)
	if info_tab_button:
		info_tab_button.pressed.connect(_on_info_tab_pressed)
	
	# Hide panel content initially
	if panel_container:
		panel_container.visible = false
	
	_update_tab_visibility()

func _process(delta: float) -> void:
	# Smooth expansion/collapse
	if abs(custom_minimum_size.x - target_width) > 1.0:
		custom_minimum_size.x = lerp(custom_minimum_size.x, target_width, expand_speed * delta)
	else:
		custom_minimum_size.x = target_width

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == tab_key:
			toggle_panel()

func toggle_panel() -> void:
	if is_expanded:
		collapse_panel()
	else:
		expand_panel()

func expand_panel() -> void:
	is_expanded = true
	target_width = expanded_width
	if panel_container:
		panel_container.visible = true
	panel_opened.emit()

func collapse_panel() -> void:
	is_expanded = false
	target_width = collapsed_width
	if panel_container:
		panel_container.visible = false
	panel_closed.emit()
	
	# Notify parent that panel was closed (for cleanup)
	var parent_ui: Node = get_parent()
	if parent_ui and parent_ui.has_method("_on_panel_closed"):
		parent_ui._on_panel_closed()

func switch_to_tab(tab: PanelTab) -> void:
	print("InteractionPanel: Switching to tab ", tab)
	current_tab = tab
	_update_tab_visibility()
	
	var tab_name: String = ""
	match tab:
		PanelTab.PLAYER:
			tab_name = "player"
		PanelTab.TALK:
			tab_name = "talk"
		PanelTab.INFO:
			tab_name = "info"
	
	print("  Tab name: ", tab_name)
	tab_changed.emit(tab_name)
	
	# Auto-expand when switching tabs
	if not is_expanded:
		expand_panel()

func _update_tab_visibility() -> void:
	print("InteractionPanel: Updating tab visibility for tab ", current_tab)
	if player_content:
		player_content.visible = current_tab == PanelTab.PLAYER
		print("  player_content.visible = ", player_content.visible)
	if talk_content:
		talk_content.visible = current_tab == PanelTab.TALK
		print("  talk_content.visible = ", talk_content.visible)
	if info_content:
		info_content.visible = current_tab == PanelTab.INFO
		print("  info_content.visible = ", info_content.visible)

func _on_player_tab_pressed() -> void:
	switch_to_tab(PanelTab.PLAYER)

func _on_talk_tab_pressed() -> void:
	switch_to_tab(PanelTab.TALK)

func _on_info_tab_pressed() -> void:
	switch_to_tab(PanelTab.INFO)

# Public API
func get_player_content() -> Control:
	return player_content

func get_talk_content() -> Control:
	return talk_content

func get_info_content() -> Control:
	return info_content
