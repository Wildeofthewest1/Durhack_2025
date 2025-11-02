extends CanvasLayer
class_name InteractionUI

@export var interaction_manager: InteractionManager
@export var show_interaction_prompt: bool = true

@onready var interaction_panel: InteractionPanel = $InteractionPanel
@onready var player_ui: PlayerUI = $InteractionPanel/PanelContainer/MarginContainer/ContentContainer/PlayerContent/PlayerUI
@onready var talk_ui: TalkUI = $InteractionPanel/PanelContainer/MarginContainer/ContentContainer/TalkContent/TalkUI
@onready var info_label: RichTextLabel = $InteractionPanel/PanelContainer/MarginContainer/ContentContainer/InfoContent/InfoLabel

@onready var interaction_prompt: Label = $InteractionPrompt
@onready var minimap_container: Control = $MinimapContainer
@onready var speaker_portrait: TextureRect = $SpeakerPortrait

var current_interactable: Interactable = null
var stored_dialogue_data: Dictionary = {}  # Store dialogue for persistence
var stored_speaker_texture: Texture2D = null

func _ready() -> void:
	# Add to group so other nodes can find us
	add_to_group("interaction_ui")
	
	# Connect interaction manager signals
	if interaction_manager:
		interaction_manager.interaction_triggered.connect(_on_interaction_triggered)
		interaction_manager.interactable_in_range.connect(_on_interactable_in_range)
		interaction_manager.interactable_out_of_range.connect(_on_interactable_out_of_range)
	
	# Connect panel signals
	if interaction_panel:
		interaction_panel.tab_changed.connect(_on_tab_changed)
		interaction_panel.panel_closed.connect(_on_panel_manually_closed)
	
	# Connect talk UI signals
	if talk_ui:
		talk_ui.option_selected.connect(_on_dialogue_option_selected)
	
	# Hide interaction prompt initially
	if interaction_prompt:
		interaction_prompt.visible = false

func _process(delta: float) -> void:
	_update_interaction_prompt()

func _update_interaction_prompt() -> void:
	if not show_interaction_prompt or not interaction_prompt:
		return
	
	if not interaction_manager:
		interaction_prompt.visible = false
		return
	
	var closest: Interactable = interaction_manager.get_closest_interactable()
	
	if closest and closest.can_be_interacted():
		interaction_prompt.visible = true
		interaction_prompt.text = "[E] " + closest.get_interaction_name()
		
		# Position prompt above the interactable
		var screen_pos: Vector2 = _world_to_screen(closest.global_position)
		screen_pos.y -= 50  # Offset above the object
		interaction_prompt.global_position = screen_pos
	else:
		interaction_prompt.visible = false

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return Vector2.ZERO
	
	var camera: Camera2D = viewport.get_camera_2d()
	if not camera:
		return world_pos  # Return world pos if no camera
	
	return world_pos  # Simple fallback - in 2D with camera, this works

func _on_interaction_triggered(interactable: Interactable) -> void:
	print("InteractionUI: Interaction triggered with ", interactable.interaction_name)
	current_interactable = interactable
	
	# Update info panel with interactable information
	_update_info_panel(interactable)
	
	# Switch to appropriate tab based on interactable type
	var interactable_type: String = interactable.get_interactable_type()
	print("  Interactable type: ", interactable_type)
	print("  Has dialogue: ", interactable.has_dialogue)
	
	if interactable.has_dialogue:
		# Switch to talk tab and start dialogue
		if interaction_panel:
			print("  Switching to TALK tab")
			interaction_panel.switch_to_tab(InteractionPanel.PanelTab.TALK)
		_start_dialogue(interactable)
	else:
		# Just show info
		if interaction_panel:
			interaction_panel.switch_to_tab(InteractionPanel.PanelTab.INFO)
			interaction_panel.expand_panel()

func _on_interactable_in_range(_interactable: Interactable) -> void:
	pass  # Could add visual feedback here

func _on_interactable_out_of_range(_interactable: Interactable) -> void:
	# Don't end interaction if we're actively interacting
	# Let the player manually close with Tab or finish dialogue
	pass  # Removed auto-close behavior

func _on_panel_manually_closed() -> void:
	# When player closes panel with Tab, clean up
	if talk_ui and talk_ui.is_dialogue_active():
		talk_ui.end_dialogue()
	
	if speaker_portrait:
		speaker_portrait.visible = false
	
	# Clear stored dialogue data
	stored_dialogue_data.clear()
	stored_speaker_texture = null
	
	# Allow interaction manager to reset
	if interaction_manager:
		interaction_manager.is_interacting = false
	
	current_interactable = null

func _update_info_panel(interactable: Interactable) -> void:
	if not info_label:
		return
	
	var info_text: String = "[b]" + interactable.get_interaction_name() + "[/b]\n\n"
	info_text += "Type: " + interactable.get_interactable_type() + "\n"
	
	# Add custom data if available
	if not interactable.custom_data.is_empty():
		info_text += "\n[b]Additional Information:[/b]\n"
		for key: String in interactable.custom_data.keys():
			if key != "dialogue":
				info_text += key + ": " + str(interactable.custom_data[key]) + "\n"
	
	info_label.text = info_text

func _start_dialogue(interactable: Interactable) -> void:
	print("InteractionUI: Starting dialogue with ", interactable.interaction_name)
	
	if not talk_ui:
		print("  ERROR: talk_ui is null!")
		return
	
	var dialogue_data: Dictionary = interactable.get_dialogue_data()
	
	if dialogue_data.is_empty():
		print("  Creating default dialogue")
		# Create a default dialogue
		dialogue_data = {
			"start": {
				"text": "Hello there!",
				"speaker": interactable.get_interaction_name(),
				"options": [
					{"text": "Goodbye", "next": "end"}
				]
			}
		}
	else:
		print("  Using interactable dialogue data with ", dialogue_data.size(), " nodes")
	
	# Store dialogue data so it persists
	stored_dialogue_data = dialogue_data.duplicate(true)
	stored_speaker_texture = interactable.get_interaction_sprite()
	
	var speaker_sprite: Texture2D = interactable.get_interaction_sprite()
	
	# Show speaker portrait on left side of screen
	if speaker_portrait and speaker_sprite:
		speaker_portrait.texture = speaker_sprite
		speaker_portrait.visible = true
		print("  Speaker portrait shown")
	elif speaker_portrait:
		speaker_portrait.visible = false
		print("  No speaker sprite")
	
	print("  Calling talk_ui.start_dialogue()")
	talk_ui.start_dialogue(dialogue_data, interactable.dialogue_start_node, null)  # Don't pass sprite to talk_ui anymore

func _on_dialogue_option_selected(_option_index: int) -> void:
	# Handle dialogue option selection
	# Could trigger events, give items, etc.
	pass

func _on_tab_changed(_tab_name: String) -> void:
	# Handle tab changes
	if _tab_name == "talk":
		# If switching to talk tab, restore dialogue if we have stored data
		if not talk_ui.is_dialogue_active() and not stored_dialogue_data.is_empty():
			# Restore the dialogue
			if speaker_portrait and stored_speaker_texture:
				speaker_portrait.texture = stored_speaker_texture
				speaker_portrait.visible = true
			talk_ui.start_dialogue(stored_dialogue_data, "start", null)

# Public API

func add_inventory_item(item: Dictionary) -> bool:
	if player_ui:
		return player_ui.add_item(item)
	return false

func remove_inventory_item(slot_index: int, quantity: int = 1) -> bool:
	if player_ui:
		return player_ui.remove_item(slot_index, quantity)
	return false

func get_inventory_item(slot_index: int) -> Dictionary:
	if player_ui:
		if slot_index >= 0 and slot_index < player_ui.inventory_data.size():
			return player_ui.inventory_data[slot_index].duplicate()
	return {}

func add_upgrade(upgrade: Dictionary) -> void:
	if player_ui:
		player_ui.add_upgrade(upgrade)

func add_fleet_ship(ship: Dictionary) -> void:
	if player_ui:
		player_ui.add_fleet_ship(ship)

func add_planet(planet: Dictionary) -> void:
	if player_ui:
		player_ui.add_planet(planet)

func remove_planet(index: int) -> void:
	if player_ui:
		player_ui.remove_planet(index)

func add_shop_item(item: Dictionary) -> void:
	if player_ui:
		player_ui.add_shop_item(item)

func remove_shop_item(item_id: String) -> void:
	if player_ui:
		player_ui.remove_shop_item(item_id)

func clear_shop() -> void:
	if player_ui:
		player_ui.clear_shop()

func set_player_stats(name: String, level: int, credits: int) -> void:
	if player_ui:
		player_ui.set_player_stats(name, level, credits)

func open_panel() -> void:
	if interaction_panel:
		interaction_panel.expand_panel()

func close_panel() -> void:
	if interaction_panel:
		interaction_panel.collapse_panel()

func switch_to_player() -> void:
	if interaction_panel:
		interaction_panel.switch_to_tab(InteractionPanel.PanelTab.PLAYER)

func switch_to_talk() -> void:
	if interaction_panel:
		interaction_panel.switch_to_tab(InteractionPanel.PanelTab.TALK)

func switch_to_info() -> void:
	if interaction_panel:
		interaction_panel.switch_to_tab(InteractionPanel.PanelTab.INFO)
