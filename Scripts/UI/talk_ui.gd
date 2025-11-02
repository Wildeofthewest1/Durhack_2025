extends Control
class_name TalkUI

signal option_selected(option_index: int)

@export var typing_speed: float = 0.05  # Time between characters

@onready var speaker_name_label: Label = $MarginContainer/DialogueContainer/SpeakerName
@onready var dialogue_label: RichTextLabel = $MarginContainer/DialogueContainer/DialogueText
@onready var options_container: VBoxContainer = $MarginContainer/DialogueContainer/OptionsContainer

var dialogue_system: DialogueSystem
var is_typing: bool = false
var current_text: String = ""
var visible_characters: int = 0
var typing_timer: float = 0.0

func _ready() -> void:
	# Allow mouse interaction with this control
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	if not dialogue_system:
		dialogue_system = DialogueSystem.new()
		add_child(dialogue_system)
	
	dialogue_system.dialogue_started.connect(_on_dialogue_started)
	dialogue_system.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_system.node_changed.connect(_on_node_changed)

func _process(delta: float) -> void:
	if is_typing:
		_process_typing(delta)

func _process_typing(delta: float) -> void:
	typing_timer += delta
	
	if typing_timer >= typing_speed:
		typing_timer = 0.0
		visible_characters += 1
		
		if dialogue_label:
			dialogue_label.visible_characters = visible_characters
		
		# Check if finished typing
		if visible_characters >= current_text.length():
			is_typing = false
			if dialogue_label:
				dialogue_label.visible_characters = -1  # Show all

func start_dialogue(dialogue_data: Dictionary, start_node: String = "start", _speaker_texture: Texture2D = null) -> void:
	dialogue_system.load_dialogue(dialogue_data)
	dialogue_system.start_dialogue(start_node)
	
	# Make sure we're visible
	if speaker_name_label:
		speaker_name_label.visible = true
	if dialogue_label:
		dialogue_label.visible = true
	if options_container:
		options_container.visible = true

func end_dialogue() -> void:
	dialogue_system.end_dialogue()
	# Don't hide the whole UI, just clear the dialogue content
	_clear_dialogue_display()
	
	# Notify parent UI to hide speaker portrait
	var interaction_ui: Node = get_tree().get_first_node_in_group("interaction_ui")
	if interaction_ui and "speaker_portrait" in interaction_ui:
		interaction_ui.speaker_portrait.visible = false

func _clear_dialogue_display() -> void:
	if dialogue_label:
		dialogue_label.text = ""
	if speaker_name_label:
		speaker_name_label.text = ""
	_clear_options()

func skip_typing() -> void:
	if is_typing and dialogue_label:
		is_typing = false
		dialogue_label.visible_characters = -1

func _display_current_node() -> void:
	var speaker: String = dialogue_system.get_current_speaker()
	var text: String = dialogue_system.get_current_text()
	var options: Array = dialogue_system.get_current_options()
	
	# Update speaker name
	if speaker_name_label:
		speaker_name_label.text = speaker
		speaker_name_label.visible = not speaker.is_empty()
	
	# Start typing effect
	current_text = text
	visible_characters = 0
	is_typing = true
	typing_timer = 0.0
	
	if dialogue_label:
		dialogue_label.text = text
		dialogue_label.visible_characters = 0
		dialogue_label.visible = true
	
	# Clear and create option buttons IMMEDIATELY (not after typing)
	_clear_options()
	_create_option_buttons(options)
	
	# Make options visible and interactable right away
	if options_container:
		options_container.visible = true
		options_container.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Ensure all buttons are enabled and can receive mouse input
		for child in options_container.get_children():
			if child is Button:
				var btn: Button = child as Button
				btn.disabled = false
				btn.mouse_filter = Control.MOUSE_FILTER_STOP  # Capture clicks

func _clear_options() -> void:
	if not options_container:
		return
	
	for child: Node in options_container.get_children():
		child.queue_free()

func _create_option_buttons(options: Array) -> void:
	if not options_container:
		return
	
	for i: int in range(options.size()):
		var option: Dictionary = options[i]
		var button: Button = Button.new()
		button.text = option.get("text", "Option " + str(i + 1))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_option_pressed.bind(i))
		options_container.add_child(button)

func _on_option_pressed(option_index: int) -> void:
	skip_typing()  # Finish any typing animation
	option_selected.emit(option_index)
	dialogue_system.select_option(option_index)

func _on_dialogue_started() -> void:
	_display_current_node()

func _on_dialogue_ended() -> void:
	# Don't hide the UI, just clear the content
	_clear_dialogue_display()
	
	# Notify parent UI to hide speaker portrait
	var interaction_ui: Node = get_tree().get_first_node_in_group("interaction_ui")
	if interaction_ui and "speaker_portrait" in interaction_ui:
		interaction_ui.speaker_portrait.visible = false

func _on_node_changed(_node_id: String) -> void:
	_display_current_node()

func _input(event: InputEvent) -> void:
	# Only process input if dialogue is actually active
	if not dialogue_system or not dialogue_system.is_dialogue_active():
		return
	
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed:
			# Space or Enter to skip typing
			if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER:
				if is_typing:
					skip_typing()
			# Number keys for quick option selection
			elif key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
				var option_num: int = key_event.keycode - KEY_1
				var options: Array = dialogue_system.get_current_options()
				if option_num < options.size():
					_on_option_pressed(option_num)

# Public API
func load_dialogue(data: Dictionary) -> void:
	dialogue_system.load_dialogue(data)

func get_dialogue_system() -> DialogueSystem:
	return dialogue_system

func is_dialogue_active() -> bool:
	return dialogue_system.is_dialogue_active() if dialogue_system else false
