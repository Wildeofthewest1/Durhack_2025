extends Node
class_name BubbleDialogueController

@export var planet_name_label: Label

@export var bubble_scroll: ScrollContainer
@export var bubble_list: VBoxContainer

@export var speech_bubble_scene: PackedScene
@export var choices_bubble_scene: PackedScene

@export var next_action: StringName = &"ui_accept"

@export var npc_speaker_color: String = "#d9d4ff"
@export var you_speaker_color: String = "#f3d38b"
@export var you_name: String = "YOU"

@export var choice_color: String = "#e8e1c9"
@export var continue_color: String = "#8ee6c7"
@export var continue_text: String = "→ Continue"

@export var click_sfx: AudioStreamPlayer

var _planet: Node = null
var _dialogue_resource: DialogueResource = null
var _start_title: String = ""

var _dialogue_line: DialogueLine = null
var _is_running: bool = false
var _is_waiting_for_input: bool = false

var _extra_game_states: Array = []
var _current_responses: Array[DialogueResponse] = []

var _current_bubble: SpeechBubble = null

# the active choices bubble (spawned into the list)
var _choices_row: HBoxContainer = null
var _choices_bubble: ChoicesBubble = null

# Cancellation token for async dialogue flow
var _session_id: int = 0

# Local variables for dialogue - using a custom class for auto-creation
var locals: LocalsProxy = null


func _ready() -> void:
	if locals == null:
		locals = LocalsProxy.new()


func setup_for_planet(planet: Node) -> void:
	# New session cancels any pending awaits from previous run
	_session_id += 1

	_planet = planet
	_refresh_planet_header()

	_clear_bubbles()
	_clear_choices_bubble()

	_dialogue_resource = _extract_dialogue_resource_from_planet(_planet)
	_start_title = _extract_start_title_from_planet(_planet)

	# Reset locals for new conversation
	if locals == null:
		locals = LocalsProxy.new()
	else:
		locals.clear()

	_extra_game_states.clear()
	
	# IMPORTANT: Add locals FIRST so it's prioritized
	_extra_game_states.append(locals)
	_extra_game_states.append(self)
	
	if _planet != null and is_instance_valid(_planet):
		_extra_game_states.append(_planet)

	if _dialogue_resource == null:
		_spawn_system_bubble("[i]No dialogue resource found on this NPC.[/i]")
		return

	if _start_title.is_empty():
		_spawn_system_bubble("[i]No start title found (dialogue_start_title / dialogue_data.start_title).[/i]")
		return

	_start_async(_session_id)


func stop() -> void:
	# Cancels any pending awaits immediately
	_session_id += 1

	_is_running = false
	_is_waiting_for_input = false
	_dialogue_line = null
	_current_responses.clear()
	_clear_choices_bubble()
	_current_bubble = null


func handle_input(event: InputEvent) -> void:
	if not _is_running:
		return
	if not _is_waiting_for_input:
		return

	if event.is_action_pressed(next_action):
		# finish typing first
		if _current_bubble != null and is_instance_valid(_current_bubble) and _current_bubble.is_typing():
			_current_bubble.finish_typing_instant()
			return

		# keyboard continue only when there are no responses
		if _dialogue_line == null:
			return
		if _current_responses.size() > 0:
			return

		_on_continue()


func _start_async(session: int) -> void:
	call_deferred("_start_async_deferred", session)


func _start_async_deferred(session: int) -> void:
	if session != _session_id:
		return
	if not is_inside_tree():
		return

	_is_running = true
	_dialogue_line = await DialogueManager.get_next_dialogue_line(_dialogue_resource, _start_title, _extra_game_states)

	if session != _session_id:
		return
	await _present_line(session)


func _advance_async(next_id: String, session: int) -> void:
	call_deferred("_advance_async_deferred", next_id, session)


func _advance_async_deferred(next_id: String, session: int) -> void:
	if session != _session_id:
		return
	if not is_inside_tree():
		return

	_dialogue_line = await DialogueManager.get_next_dialogue_line(_dialogue_resource, next_id, _extra_game_states)

	if session != _session_id:
		return
	await _present_line(session)


func _present_line(session: int) -> void:
	if session != _session_id:
		return
	if not is_inside_tree():
		return

	_clear_choices_bubble()
	_is_waiting_for_input = false
	_current_responses.clear()
	_current_bubble = null

	if _dialogue_line == null:
		_spawn_system_bubble("[i]End of dialogue.[/i]")
		_is_running = false
		return

	var raw_text: String = _dialogue_line.text
	var stripped_text: String = raw_text.strip_edges()

	# mutation-only: empty + no responses => auto-advance (NO BUBBLE)
	if stripped_text.is_empty() and _dialogue_line.responses.size() == 0:
		await get_tree().process_frame
		if session != _session_id:
			return
		_advance_async(_dialogue_line.next_id, session)
		return

	# NOW spawn bubble only if we have actual content
	var speaker: String = _get_line_speaker(_dialogue_line)
	var is_you: bool = _is_you_speaker(speaker)

	_current_bubble = _spawn_bubble(speaker, _dialogue_line, is_you)
	if _current_bubble != null:
		await _current_bubble.type_out()
		if session != _session_id:
			return

	# Responses -> filter only allowed responses
	if _dialogue_line.responses.size() > 0:
		# Filter only allowed responses
		var allowed_responses: Array[DialogueResponse] = []
		for response in _dialogue_line.responses:
			if response.is_allowed:
				allowed_responses.append(response)
		
		# DEBUG: Uncomment to see what's happening
		# print("=== RESPONSES DEBUG ===")
		# print("Total responses: ", _dialogue_line.responses.size())
		# print("Allowed responses: ", allowed_responses.size())
		# print("locals data: ", locals.get_data())
		# print("======================")
		
		# If no valid choices, auto-continue
		if allowed_responses.size() == 0:
			await get_tree().process_frame
			if session != _session_id:
				return
			_advance_async(_dialogue_line.next_id, session)
			return
		
		_current_responses = allowed_responses
		_spawn_choices_bubble(allowed_responses)
		_is_waiting_for_input = true
		return

	# Timed
	if _dialogue_line.time != "":
		var seconds: float = 0.0
		if _dialogue_line.time == "auto":
			seconds = float(raw_text.length()) * 0.02
		else:
			seconds = _dialogue_line.time.to_float()

		await get_tree().create_timer(seconds, true).timeout
		if session != _session_id:
			return
		_on_continue()
		return

	# Continue -> spawn continue bubble (RIGHT, same side as YOU)
	_spawn_continue_bubble()
	_is_waiting_for_input = true


func _on_continue() -> void:
	if _dialogue_line == null:
		return
	_is_waiting_for_input = false
	_clear_choices_bubble()
	_advance_async(_dialogue_line.next_id, _session_id)


# -----------------------
# Bubble spawning
# -----------------------

func _spawn_bubble(speaker: String, line: DialogueLine, is_you: bool) -> SpeechBubble:
	if speech_bubble_scene == null:
		return null
	if bubble_list == null or not is_instance_valid(bubble_list):
		return null

	var node: Node = speech_bubble_scene.instantiate()
	var bubble: SpeechBubble = node as SpeechBubble
	if bubble == null:
		return null

	bubble.npc_speaker_color = npc_speaker_color
	bubble.you_speaker_color = you_speaker_color
	bubble.you_name = you_name

	bubble.setup(speaker, line, is_you)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if is_you:
		row.add_child(spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(spacer)

	bubble_list.add_child(row)
	_scroll_to_bottom_deferred()
	return bubble


func _spawn_system_bubble(bbcode: String) -> void:
	if speech_bubble_scene == null:
		return
	if bubble_list == null or not is_instance_valid(bubble_list):
		return

	var node: Node = speech_bubble_scene.instantiate()
	var bubble: SpeechBubble = node as SpeechBubble
	if bubble == null:
		return

	if bubble.speaker_label != null:
		bubble.speaker_label.text = ""
	if bubble.dialogue_label != null:
		bubble.dialogue_label.text = bbcode
		bubble.dialogue_label.visible_characters = -1

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(bubble)
	row.add_child(spacer)

	bubble_list.add_child(row)
	_scroll_to_bottom_deferred()


func _spawn_continue_bubble() -> void:
	if choices_bubble_scene == null:
		return
	if bubble_list == null or not is_instance_valid(bubble_list):
		return

	_clear_choices_bubble()

	var node: Node = choices_bubble_scene.instantiate()
	var bubble: ChoicesBubble = node as ChoicesBubble
	if bubble == null:
		return

	bubble.choice_color = choice_color
	bubble.continue_color = continue_color
	bubble.continue_text = continue_text

	if not bubble.continue_selected.is_connected(_on_choices_continue):
		bubble.continue_selected.connect(_on_choices_continue)

	bubble.set_continue()
	_attach_choices_bubble_right(bubble)


func _spawn_choices_bubble(responses: Array[DialogueResponse]) -> void:
	if choices_bubble_scene == null:
		return
	if bubble_list == null or not is_instance_valid(bubble_list):
		return

	_clear_choices_bubble()

	var node: Node = choices_bubble_scene.instantiate()
	var bubble: ChoicesBubble = node as ChoicesBubble
	if bubble == null:
		return

	bubble.choice_color = choice_color
	bubble.continue_color = continue_color
	bubble.continue_text = continue_text

	if not bubble.choice_selected.is_connected(_on_choices_choice):
		bubble.choice_selected.connect(_on_choices_choice)

	bubble.set_choices(responses)
	_attach_choices_bubble_right(bubble)


func _attach_choices_bubble_right(bubble: ChoicesBubble) -> void:
	if bubble_list == null or not is_instance_valid(bubble_list):
		return

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# choices bubble on RIGHT: spacer first
	row.add_child(spacer)
	row.add_child(bubble)

	bubble_list.add_child(row)

	_choices_row = row
	_choices_bubble = bubble

	_scroll_to_bottom_deferred()


func _clear_choices_bubble() -> void:
	if _choices_row != null and is_instance_valid(_choices_row):
		_choices_row.queue_free()
	_choices_row = null
	_choices_bubble = null


func _scroll_to_bottom_deferred() -> void:
	if bubble_scroll == null or not is_instance_valid(bubble_scroll):
		return
	call_deferred("_scroll_to_bottom_next_frame", _session_id)


func _scroll_to_bottom_next_frame(session: int) -> void:
	if session != _session_id:
		return
	if bubble_scroll == null or not is_instance_valid(bubble_scroll):
		return
	if not is_inside_tree():
		return

	await get_tree().process_frame
	if session != _session_id:
		return

	var bar: VScrollBar = bubble_scroll.get_v_scroll_bar()
	if bar == null:
		return
	bubble_scroll.scroll_vertical = int(bar.max_value)


func _clear_bubbles() -> void:
	if bubble_list == null:
		return
	for c in bubble_list.get_children():
		var n: Node = c as Node
		n.queue_free()


# -----------------------
# Choices bubble callbacks
# -----------------------

func _on_choices_continue() -> void:
	if click_sfx != null:
		click_sfx.play()
	_on_continue()


func _on_choices_choice(index: int) -> void:
	if not _is_running:
		return
	if not _is_waiting_for_input:
		return

	if click_sfx != null:
		click_sfx.play()

	if index < 0 or index >= _current_responses.size():
		return

	var r: DialogueResponse = _current_responses[index]

	# Spawn player's choice as a right-side bubble (instant)
	_spawn_player_choice_bubble(r.text)

	_is_waiting_for_input = false
	_current_responses.clear()
	_clear_choices_bubble()

	_advance_async(r.next_id, _session_id)


func _spawn_player_choice_bubble(text_bbcode: String) -> void:
	if speech_bubble_scene == null:
		return
	if bubble_list == null or not is_instance_valid(bubble_list):
		return

	var node: Node = speech_bubble_scene.instantiate()
	var bubble: SpeechBubble = node as SpeechBubble
	if bubble == null:
		return

	if bubble.speaker_label != null:
		bubble.speaker_label.bbcode_enabled = true
		bubble.speaker_label.text = "[color=%s][b]%s[/b][/color]" % [you_speaker_color, you_name]
	if bubble.dialogue_label != null:
		bubble.dialogue_label.text = text_bbcode
		bubble.dialogue_label.visible_characters = -1

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(spacer)
	row.add_child(bubble)

	bubble_list.add_child(row)
	_scroll_to_bottom_deferred()


# -----------------------
# Speaker helpers
# -----------------------

func _get_line_speaker(line: DialogueLine) -> String:
	if line.character != "":
		return line.character
	return ""


func _is_you_speaker(speaker: String) -> bool:
	var a: String = speaker.strip_edges().to_lower()
	var b: String = you_name.strip_edges().to_lower()
	return a == b or a == "you"


# -----------------------
# Planet header + extraction
# -----------------------

func _refresh_planet_header() -> void:
	if planet_name_label == null:
		return
	if _planet == null or not is_instance_valid(_planet):
		planet_name_label.text = ""
		return

	var n1: Variant = _safe_get(_planet, &"planet_name")
	if n1 != null:
		planet_name_label.text = str(n1)
		return

	var n2: Variant = _safe_get(_planet, &"display_name")
	if n2 != null:
		planet_name_label.text = str(n2)
		return

	planet_name_label.text = _planet.name


func _has_property(obj: Object, prop: StringName) -> bool:
	if obj == null:
		return false
	var props: Array = obj.get_property_list()
	for p in props:
		var d: Dictionary = p as Dictionary
		if d.has("name") and StringName(d["name"]) == prop:
			return true
	return false


func _safe_get(obj: Object, prop: StringName) -> Variant:
	if _has_property(obj, prop):
		return obj.get(str(prop))
	return null


func _extract_dialogue_resource_from_planet(planet: Node) -> DialogueResource:
	if planet == null or not is_instance_valid(planet):
		return null

	var dr: Variant = _safe_get(planet, &"dialogue_resource")
	if dr is DialogueResource:
		return dr as DialogueResource

	var data: Variant = _safe_get(planet, &"dialogue_data")
	if data is Object:
		var dr2: Variant = _safe_get(data as Object, &"dialogue_resource")
		if dr2 is DialogueResource:
			return dr2 as DialogueResource

	return null


func _extract_start_title_from_planet(planet: Node) -> String:
	if planet == null or not is_instance_valid(planet):
		return ""

	var st: Variant = _safe_get(planet, &"dialogue_start_title")
	if st != null:
		return str(st)

	var data: Variant = _safe_get(planet, &"dialogue_data")
	if data is Object:
		var st2: Variant = _safe_get(data as Object, &"start_title")
		if st2 != null:
			return str(st2)

		var st3: Variant = _safe_get(data as Object, &"dialogue_start_title")
		if st3 != null:
			return str(st3)

	return ""


func _clear_replies() -> void:
	# kept for compatibility (unused)
	pass


# -----------------------
# LocalsProxy - Auto-creates variables on first access
# -----------------------

class LocalsProxy extends RefCounted:
	var _data: Dictionary = {}
	
	func _get(property: StringName) -> Variant:
		var key: String = str(property)
		if not _data.has(key):
			_data[key] = null
		return _data[key]
	
	func _set(property: StringName, value: Variant) -> bool:
		var key: String = str(property)
		_data[key] = value
		return true
	
	func clear() -> void:
		_data.clear()
	
	func has(key: String) -> bool:
		return _data.has(key)
	
	func get_data() -> Dictionary:
		return _data
