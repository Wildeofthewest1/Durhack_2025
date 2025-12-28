extends Control
class_name DialogueUIBridge

@export var interaction_ui: InteractionUI

@export var dialogue_richtext: RichTextLabel
@export var reply_holder: VBoxContainer
@export var portrait_rect: TextureRect
@export var continue_button: Button

@export var accept_action: StringName = &"ui_accept"
@export var option_next_action: StringName = &"ui_down"
@export var option_prev_action: StringName = &"ui_up"

@export var close_ui_on_end: bool = true

var _connected: bool = false
var _waiting_for_choice: bool = false
var _has_ended: bool = false

var _current_speaker: String = ""
var _option_buttons: Array[Button] = []
var _option_button_indices: Array[int] = []
var _selected_option: int = 0

func _ready() -> void:
	_connect_signals()

	if continue_button != null:
		continue_button.pressed.connect(_on_continue_pressed)

	set_process_unhandled_input(true)

func start_from_npc(npc: Node) -> void:
	_connect_signals()
	_reset_state()

	var tl: Resource = null
	if "dialogic_timeline" in npc:
		tl = npc.dialogic_timeline as Resource

	if tl == null:
		push_warning("NPC has no dialogic_timeline assigned.")
		return

	DialogueService.start_for_npc(npc, tl)

	# IMPORTANT: without Dialogic layout, you must kick the runner once
	call_deferred("next")

func stop_dialogue() -> void:
	DialogueService.end_dialogue()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() == false:
		return
	if _has_ended == true:
		return

	if event.is_action_pressed(accept_action) == true:
		next()
		get_viewport().set_input_as_handled()
		return

	if _waiting_for_choice == true:
		if event.is_action_pressed(option_next_action) == true:
			_select_option(_selected_option + 1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(option_prev_action) == true:
			_select_option(_selected_option - 1)
			get_viewport().set_input_as_handled()
			return

func next() -> void:
	# demo behavior:
	# - if ended -> close
	# - if waiting -> select current option
	# - else -> advance runner
	if _has_ended == true:
		if close_ui_on_end == true and interaction_ui != null:
			interaction_ui.close_ui()
		return

	if _waiting_for_choice == true:
		_choose_selected_option()
		return

	Dialogic.handle_next_event()

func _choose_selected_option() -> void:
	if _option_button_indices.size() == 0:
		return

	var idx: int = _selected_option
	if idx < 0:
		idx = 0
	if idx >= _option_button_indices.size():
		idx = _option_button_indices.size() - 1

	var button_index: int = int(_option_button_indices[idx])
	if button_index < 0:
		return

	_waiting_for_choice = false
	_clear_replies()

	_show_continue(true)
	Dialogic.Choices.select_choice(button_index)

func _on_continue_pressed() -> void:
	next()

# -------------------------
# Dialogic signals
# -------------------------
func _connect_signals() -> void:
	if _connected == true:
		return
	_connected = true

	if DialogueService.dialogue_ended.is_connected(_on_dialogue_ended) == false:
		DialogueService.dialogue_ended.connect(_on_dialogue_ended)

	if Dialogic.Text.about_to_show_text.is_connected(_on_about_to_show_text) == false:
		Dialogic.Text.about_to_show_text.connect(_on_about_to_show_text)

	if Dialogic.Text.speaker_updated.is_connected(_on_speaker_updated) == false:
		Dialogic.Text.speaker_updated.connect(_on_speaker_updated)

	if Dialogic.Portraits.character_portrait_changed.is_connected(_on_portrait_changed) == false:
		Dialogic.Portraits.character_portrait_changed.connect(_on_portrait_changed)

	if Dialogic.Choices.question_shown.is_connected(_on_question_shown) == false:
		Dialogic.Choices.question_shown.connect(_on_question_shown)

func _on_speaker_updated(character: Object) -> void:
	var name_value: String = ""
	if character != null:
		if character.has_method("get_display_name") == true:
			name_value = str(character.call("get_display_name"))
		elif character.has_method("get_name") == true:
			name_value = str(character.call("get_name"))
		elif "display_name" in character:
			name_value = str(character.display_name)
		elif "character_name" in character:
			name_value = str(character.character_name)

	_current_speaker = name_value

func _on_about_to_show_text(info: Dictionary) -> void:
	var text_value: String = ""
	if info.has("text") == true:
		text_value = str(info["text"])
	elif info.has("dialogue") == true:
		text_value = str(info["dialogue"])
	elif info.has("content") == true:
		text_value = str(info["content"])

	if text_value.length() == 0:
		return

	_append_line(_current_speaker, text_value)

	# if we were showing choices, clear them when dialogue continues
	if _waiting_for_choice == true:
		_waiting_for_choice = false
		_clear_replies()

	_show_continue(true)

func _on_question_shown(_info: Dictionary) -> void:
	# Pull the authoritative choices from Dialogic's current question state
	var choices: Array = []

	if Dialogic.Choices.has_method("get_current_question_info") == true:
		var q: Dictionary = Dialogic.Choices.get_current_question_info()
		if q.has("choices") == true:
			choices = q["choices"] as Array

	# fallback: sometimes the signal includes them
	if choices.size() == 0 and _info.has("choices") == true:
		choices = _info["choices"] as Array

	if choices.size() == 0:
		push_warning("question_shown fired but no choices were found.")
		return

	_waiting_for_choice = true
	_build_replies(choices)

	_show_continue(false)

func _on_portrait_changed(info: Dictionary) -> void:
	if portrait_rect == null:
		return

	var tex: Texture2D = null
	if info.has("texture") == true:
		tex = info["texture"] as Texture2D
	elif info.has("portrait_texture") == true:
		tex = info["portrait_texture"] as Texture2D

	if tex != null:
		portrait_rect.texture = tex

func _on_dialogue_ended() -> void:
	_has_ended = true
	_waiting_for_choice = false
	_clear_replies()
	_show_continue(false)

	if close_ui_on_end == true and interaction_ui != null:
		interaction_ui.close_ui()

# -------------------------
# UI building
# -------------------------
func _reset_state() -> void:
	_waiting_for_choice = false
	_has_ended = false
	_current_speaker = ""

	if dialogue_richtext != null:
		dialogue_richtext.clear()

	if portrait_rect != null:
		portrait_rect.texture = null

	_clear_replies()
	_show_continue(true)

func _append_line(speaker: String, text: String) -> void:
	if dialogue_richtext == null:
		return

	if dialogue_richtext.get_parsed_text().length() > 0:
		dialogue_richtext.append_text("\n\n")

	if speaker.length() > 0:
		dialogue_richtext.append_text("[b]" + _escape_bbcode(speaker) + ":[/b] " + text)
	else:
		dialogue_richtext.append_text(text)

func _build_replies(choices: Array) -> void:
	_clear_replies()

	var first_selectable: int = -1
	var local_index: int = 0

	for c_any: Variant in choices:
		var c: Dictionary = c_any as Dictionary

		var visible: bool = bool(c.get("visible", true))
		if visible == false:
			continue

		var disabled: bool = bool(c.get("disabled", false))
		var button_index: int = int(c.get("button_index", -1))
		var t: String = str(c.get("text", ""))

		var b: Button = Button.new()
		b.text = t
		b.disabled = disabled

		var captured_button_index: int = button_index
		b.pressed.connect(func():
			if captured_button_index < 0:
				return
			_waiting_for_choice = false
			_clear_replies()
			_show_continue(true)
			Dialogic.Choices.select_choice(captured_button_index)
		)

		reply_holder.add_child(b)
		_option_buttons.append(b)
		_option_button_indices.append(button_index)

		if first_selectable == -1 and disabled == false:
			first_selectable = local_index

		local_index += 1

	if first_selectable != -1:
		_select_option(first_selectable)

func _select_option(idx: int) -> void:
	var count: int = _option_buttons.size()
	if count <= 0:
		return

	if idx < 0:
		idx = 0
	if idx >= count:
		idx = count - 1

	_selected_option = idx

	# simple "selected" visual like the demo: adjust alpha
	for i: int in range(0, count):
		var btn: Button = _option_buttons[i]
		var c: Color = btn.modulate
		c.a = 1.0 if i == _selected_option else 0.7
		btn.modulate = c

func _clear_replies() -> void:
	if reply_holder != null:
		for n: Node in reply_holder.get_children():
			n.queue_free()

	_option_buttons = []
	_option_button_indices = []
	_selected_option = 0

func _show_continue(show: bool) -> void:
	if continue_button == null:
		return
	continue_button.disabled = show == false
	var c: Color = continue_button.modulate
	c.a = 1.0 if show == true else 0.0
	continue_button.modulate = c

func _escape_bbcode(s: String) -> String:
	var out: String = s
	out = out.replace("[", "\\[")
	out = out.replace("]", "\\]")
	return out
