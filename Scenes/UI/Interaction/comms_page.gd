extends Node
class_name InteractionCommsController

@export var planet_name_label: Label

# --- CURRENT (speaker + typed text) ---
@export var current_speaker_label: RichTextLabel
@export var current_dialogue_label: DialogueLabel

# --- HISTORY (transcript) ---
@export var history_scroll: ScrollContainer
@export var history_label: RichTextLabel

# --- Choices / Continue (clickable URLs) ---
@export var choices_label: RichTextLabel

# kept for compatibility (unused)
@export var reply_holder: VBoxContainer

@export var next_action: StringName = &"ui_accept"

@export var show_continue_link: bool = true
@export var continue_text: String = "→ Continue"

# Speaker styling
@export var npc_speaker_color: String = "#d9d4ff"
@export var you_speaker_color: String = "#f3d38b"
@export var you_name: String = "YOU"

# Choice styling
@export var choice_color: String = "#e8e1c9"
@export var continue_color: String = "#8ee6c7"

# optional click sound
@export var click_sfx: AudioStreamPlayer

var _planet: Node = null
var _dialogue_resource: DialogueResource = null
var _start_title: String = ""

var _dialogue_line: DialogueLine = null
var _is_waiting_for_input: bool = false
var _is_running: bool = false

var _current_responses: Array[DialogueResponse] = []
var _extra_game_states: Array = []

# staged current line (what will be committed to history)
var _staged_speaker: String = ""
var _staged_text_bbcode: String = ""
var _staged_has_line: bool = false

# typing tracking
var _typing: bool = false

const META_CONTINUE: String = "dm_continue"
const META_CHOICE_IDX_PREFIX: String = "dm_choice_idx:"

func _ready() -> void:
	_setup_rich_text(history_label, Control.MOUSE_FILTER_IGNORE, false)
	_setup_rich_text(choices_label, Control.MOUSE_FILTER_STOP, true)
	_setup_rich_text(current_speaker_label, Control.MOUSE_FILTER_IGNORE, false)

	if current_dialogue_label != null:
		current_dialogue_label.process_mode = Node.PROCESS_MODE_ALWAYS

	if history_scroll != null:
		history_scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	if choices_label != null:
		if not choices_label.meta_clicked.is_connected(_on_choices_meta_clicked):
			choices_label.meta_clicked.connect(_on_choices_meta_clicked)

	_clear_current()
	_clear_history()
	_clear_choices()
	_clear_stage()

func setup_for_planet(planet: Node) -> void:
	_planet = planet
	_refresh_planet_header()

	_clear_current()
	_clear_history()
	_clear_choices()
	_clear_replies()

	_current_responses.clear()
	_clear_stage()

	_dialogue_resource = _extract_dialogue_resource_from_planet(_planet)
	_start_title = _extract_start_title_from_planet(_planet)

	_extra_game_states.clear()
	_extra_game_states.append(self)
	if _planet != null and is_instance_valid(_planet):
		_extra_game_states.append(_planet)

	if _dialogue_resource == null:
		_append_history("[i]No dialogue resource found on this NPC.[/i]")
		return

	if _start_title.is_empty():
		_append_history("[i]No start title found (dialogue_start_title / dialogue_data.start_title).[/i]")
		return

	_start_async()

func stop() -> void:
	_is_running = false
	_is_waiting_for_input = false
	_dialogue_line = null
	_current_responses.clear()
	_clear_choices()
	_clear_replies()
	_clear_current()
	_clear_stage()

func handle_input(event: InputEvent) -> void:
	if not _is_running:
		return
	if not _is_waiting_for_input:
		return

	if event.is_action_pressed(next_action):
		# keyboard-continue only when there are no responses
		if _dialogue_line == null:
			return
		if _dialogue_line.responses.size() > 0:
			return
		_on_continue_activated()

func _start_async() -> void:
	call_deferred("_start_async_deferred")

func _start_async_deferred() -> void:
	_is_running = true
	_dialogue_line = await DialogueManager.get_next_dialogue_line(
		_dialogue_resource,
		_start_title,
		_extra_game_states
	)
	await _present_line()

func _advance_async(next_id: String) -> void:
	call_deferred("_advance_async_deferred", next_id)

func _advance_async_deferred(next_id: String) -> void:
	await _goto_next(next_id)

func _goto_next(next_id: String) -> void:
	if not _is_running:
		return
	if _dialogue_resource == null:
		_is_running = false
		return

	_dialogue_line = await DialogueManager.get_next_dialogue_line(
		_dialogue_resource,
		next_id,
		_extra_game_states
	)
	await _present_line()

# ============================================================
# Present line:
# - show speaker label now
# - type using DialogueLabel (keeps pause behavior)
# - do NOT append to history yet
# ============================================================

func _present_line() -> void:
	_clear_choices()
	_is_waiting_for_input = false
	_current_responses.clear()
	_clear_stage()

	if _dialogue_line == null:
		_clear_current()
		_append_history("[i]End of dialogue.[/i]")
		_is_running = false
		return

	var speaker: String = _get_line_speaker(_dialogue_line)
	var raw_text: String = _dialogue_line.text
	var stripped_text: String = raw_text.strip_edges()

	# mutation-only line
	if stripped_text.is_empty() and _dialogue_line.responses.size() == 0:
		await get_tree().process_frame
		_advance_async(_dialogue_line.next_id)
		return

	_staged_speaker = speaker
	_staged_text_bbcode = raw_text
	_staged_has_line = true

	_set_current_speaker(speaker)
	await _type_current_dialogue(_dialogue_line)

	if _dialogue_line.responses.size() > 0:
		_current_responses = _dialogue_line.responses.duplicate()
		_render_choice_urls(_current_responses)
		_is_waiting_for_input = true
		return

	if _dialogue_line.time != "":
		var seconds: float = 0.0
		if _dialogue_line.time == "auto":
			seconds = float(_dialogue_line.text.length()) * 0.02
		else:
			seconds = _dialogue_line.time.to_float()

		await get_tree().create_timer(seconds, true).timeout
		_on_continue_activated(true)
		return

	if show_continue_link:
		_render_continue_url()

	_is_waiting_for_input = true

func _type_current_dialogue(line_for_ui: DialogueLine) -> void:
	_typing = false

	if current_dialogue_label == null:
		return

	current_dialogue_label.hide()
	current_dialogue_label.dialogue_line = line_for_ui
	current_dialogue_label.show()

	if line_for_ui == null:
		return
	if line_for_ui.text.strip_edges().is_empty():
		return

	_typing = true
	current_dialogue_label.type_out()
	await current_dialogue_label.finished_typing
	_typing = false

# ============================================================
# Continue / choice
# ============================================================

func _on_continue_activated(from_timer: bool = false) -> void:
	if _dialogue_line == null:
		return

	# if typing, finish instantly
	if _typing and current_dialogue_label != null:
		current_dialogue_label.visible_characters = -1
		_typing = false
		return

	_commit_staged_line_to_history()

	_is_waiting_for_input = false
	_clear_choices()
	_clear_current()

	_advance_async(_dialogue_line.next_id)

func _commit_staged_line_to_history() -> void:
	if not _staged_has_line:
		return

	var speaker: String = _staged_speaker.strip_edges()
	if speaker.is_empty():
		_append_history(_staged_text_bbcode)
	else:
		_append_history(_format_spoken_line(speaker, _staged_text_bbcode))

	_clear_stage()

func _clear_stage() -> void:
	_staged_speaker = ""
	_staged_text_bbcode = ""
	_staged_has_line = false

# ============================================================
# Choices
# ============================================================

func _render_continue_url() -> void:
	if choices_label == null:
		return
	var bb: String = "\n"
	bb += "[color=%s][url=%s]%s[/url][/color]" % [continue_color, META_CONTINUE, continue_text]
	choices_label.text = bb

func _render_choice_urls(responses: Array[DialogueResponse]) -> void:
	if choices_label == null:
		return

	var bb: String = "\n"
	var index: int = 0
	var display_num: int = 1

	for r in responses:
		var meta: String = META_CHOICE_IDX_PREFIX + str(index)
		bb += "[color=%s][url=%s]%d. %s[/url][/color]\n" % [choice_color, meta, display_num, r.text]
		index += 1
		display_num += 1

	choices_label.text = bb

func _on_choices_meta_clicked(meta: Variant) -> void:
	if not _is_running:
		return
	if not _is_waiting_for_input:
		return

	if click_sfx != null:
		click_sfx.play()

	var m: String = str(meta)

	if m == META_CONTINUE:
		_on_continue_activated()
		return

	if m.begins_with(META_CHOICE_IDX_PREFIX):
		var idx_str: String = m.substr(META_CHOICE_IDX_PREFIX.length())
		var idx: int = idx_str.to_int()

		if idx < 0 or idx >= _current_responses.size():
			return

		# commit current NPC line first
		_commit_staged_line_to_history()

		var r: DialogueResponse = _current_responses[idx]

		# append YOU choice line to history
		_append_history(_format_spoken_line(you_name, r.text))

		_is_waiting_for_input = false
		_current_responses.clear()
		_clear_choices()
		_clear_current()
		_clear_stage()

		_advance_async(r.next_id)
		return

# ============================================================
# Current display helpers
# ============================================================

func _set_current_speaker(speaker: String) -> void:
	if current_speaker_label == null:
		return

	var s: String = speaker.strip_edges()
	if s.is_empty():
		current_speaker_label.text = ""
		return

	var color_hex: String = you_speaker_color if _is_you_speaker(s) else npc_speaker_color
	current_speaker_label.text = "[color=%s][b]%s:[/b][/color]" % [color_hex, s]

func _clear_current() -> void:
	if current_speaker_label != null:
		current_speaker_label.text = ""
	if current_dialogue_label != null:
		current_dialogue_label.text = ""
		current_dialogue_label.visible_characters = -1
	_typing = false

# ============================================================
# Formatting helpers
# ============================================================

func _get_line_speaker(line: DialogueLine) -> String:
	if line.character != "":
		return line.character
	if line.speaker != "":
		return line.speaker
	return ""

func _format_spoken_line(speaker: String, text_bbcode: String) -> String:
	var s: String = speaker.strip_edges()
	if s.is_empty():
		return text_bbcode

	var is_you: bool = _is_you_speaker(s)
	var color_hex: String = you_speaker_color if is_you else npc_speaker_color
	return "[color=%s][b]%s:[/b][/color] %s" % [color_hex, s, text_bbcode]

func _is_you_speaker(speaker: String) -> bool:
	var a: String = speaker.strip_edges().to_lower()
	var b: String = you_name.strip_edges().to_lower()
	return a == b or a == "you"

# ============================================================
# UI helpers
# ============================================================

func _setup_rich_text(rtl: RichTextLabel, mouse_filter_value: int, show_hand_cursor: bool) -> void:
	if rtl == null:
		return
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = mouse_filter_value
	if show_hand_cursor:
		rtl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _clear_history() -> void:
	if history_label == null:
		return
	history_label.text = ""
	if history_scroll != null:
		history_scroll.scroll_vertical = 0

func _append_history(bbcode_line: String) -> void:
	if history_label == null:
		return

	if history_label.text.is_empty():
		history_label.text = bbcode_line
	else:
		history_label.text += "\n" + bbcode_line

	if history_scroll != null:
		call_deferred("_scroll_history_to_bottom_next_frame")

func _scroll_history_to_bottom_next_frame() -> void:
	if history_scroll == null:
		return
	await get_tree().process_frame
	var bar: VScrollBar = history_scroll.get_v_scroll_bar()
	if bar == null:
		return
	history_scroll.scroll_vertical = int(bar.max_value)

func _clear_choices() -> void:
	if choices_label == null:
		return
	choices_label.text = ""

func _clear_replies() -> void:
	if reply_holder == null:
		return
	for c in reply_holder.get_children():
		var n: Node = c as Node
		n.queue_free()

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

# ============================================================
# Dialogue extraction helpers
# ============================================================

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
