extends Node
class_name InteractionCommsController

@export var planet_name_label: Label

@export var history_scroll: ScrollContainer
@export var history_label: RichTextLabel

@export var choices_label: RichTextLabel

@export var reply_holder: VBoxContainer

@export var next_action: StringName = &"ui_accept"

@export var show_continue_link: bool = true
@export var continue_text: String = "→ Continue"

# Speaker styling (only affects the "SPEAKER:" part)
@export var npc_speaker_color: String = "#d9d4ff"
@export var you_speaker_color: String = "#f3d38b"
@export var you_name: String = "YOU"

# Choice list styling (the numbered options)
@export var choice_color: String = "#e8e1c9"
@export var continue_color: String = "#8ee6c7"

var _planet: Node = null
var _dialogue_resource: DialogueResource = null
var _start_title: String = ""

var _dialogue_line: DialogueLine = null
var _is_waiting_for_input: bool = false
var _is_running: bool = false

var _extra_game_states: Array = []

const META_CONTINUE: String = "dm_continue"
const META_CHOICE_IDX_PREFIX: String = "dm_choice_idx:"

var _current_responses: Array[DialogueResponse] = []

func _ready() -> void:
	_setup_rich_text(history_label, Control.MOUSE_FILTER_IGNORE)
	_setup_rich_text(choices_label, Control.MOUSE_FILTER_STOP)

	if history_scroll != null:
		history_scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	if choices_label != null:
		choices_label.meta_clicked.connect(_on_choices_meta_clicked)

func setup_for_planet(planet: Node) -> void:
	_planet = planet
	_refresh_planet_header()
	_clear_history()
	_clear_choices()
	_clear_replies()

	_current_responses.clear()

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

func handle_input(event: InputEvent) -> void:
	if not _is_running:
		return
	if not _is_waiting_for_input:
		return

	if event.is_action_pressed(next_action):
		if _dialogue_line == null:
			return
		if _dialogue_line.responses.size() > 0:
			return
		_is_waiting_for_input = false
		_clear_choices()
		_advance_async(_dialogue_line.next_id)

func _start_async() -> void:
	call_deferred("_start_async_deferred")

func _start_async_deferred() -> void:
	_is_running = true
	_dialogue_line = await DialogueManager.get_next_dialogue_line(_dialogue_resource, _start_title, _extra_game_states)
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

	_dialogue_line = await DialogueManager.get_next_dialogue_line(_dialogue_resource, next_id, _extra_game_states)
	await _present_line()

func _present_line() -> void:
	_clear_choices()
	_is_waiting_for_input = false
	_current_responses.clear()

	if _dialogue_line == null:
		_append_history("[i]End of dialogue.[/i]")
		_is_running = false
		return

	var speaker: String = _get_line_speaker(_dialogue_line)
	var text_bbcode: String = _dialogue_line.text
	var stripped_text: String = text_bbcode.strip_edges()

	# Mutation-only line: empty + no responses => auto-advance
	if stripped_text.is_empty() and _dialogue_line.responses.size() == 0:
		await get_tree().process_frame
		_advance_async(_dialogue_line.next_id)
		return

	# Log to history (single label)
	if speaker.is_empty():
		_append_history(text_bbcode)
	else:
		_append_history(_format_spoken_line(speaker, text_bbcode))

	# Show responses (clickable)
	if _dialogue_line.responses.size() > 0:
		_current_responses = _dialogue_line.responses.duplicate()
		_render_choice_urls(_current_responses)
		_is_waiting_for_input = true
		return

	# Timed lines
	if _dialogue_line.time != "":
		var seconds: float = 0.0
		if _dialogue_line.time == "auto":
			seconds = float(_dialogue_line.text.length()) * 0.02
		else:
			seconds = _dialogue_line.time.to_float()
		await get_tree().create_timer(seconds).timeout
		_advance_async(_dialogue_line.next_id)
		return

	# Continue
	if show_continue_link:
		_render_continue_url()

	_is_waiting_for_input = true

# -----------------------
# Choice rendering / clicking
# -----------------------

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
		var meta: String = META_CHOICE_IDX_PREFIX + String.num_int64(index)
		# We color the choice line; the response text itself stays plain (unless your DM text already has bbcode)
		bb += "[color=%s][url=%s]%d. %s[/url][/color]\n" % [choice_color, meta, display_num, r.text]
		index += 1
		display_num += 1

	choices_label.text = bb

func _on_choices_meta_clicked(meta: Variant) -> void:
	if not _is_running:
		return
	if not _is_waiting_for_input:
		return

	var m: String = String(meta)

	if m == META_CONTINUE:
		if _dialogue_line == null:
			return
		if _dialogue_line.responses.size() > 0:
			return
		_is_waiting_for_input = false
		_clear_choices()
		_advance_async(_dialogue_line.next_id)
		return

	if m.begins_with(META_CHOICE_IDX_PREFIX):
		var idx_str: String = m.substr(META_CHOICE_IDX_PREFIX.length())
		var idx: int = idx_str.to_int()

		if idx < 0 or idx >= _current_responses.size():
			return

		var r: DialogueResponse = _current_responses[idx]

		# Log player choice as "YOU: ..." with colored YOU
		_append_history(_format_spoken_line(you_name, r.text))

		_is_waiting_for_input = false
		_current_responses.clear()
		_clear_choices()
		_advance_async(r.next_id)
		return

# -----------------------
# Formatting helpers
# -----------------------

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
	var prefix: String = "[color=%s][b]%s:[/b][/color] " % [color_hex, s]
	return prefix + text_bbcode

func _is_you_speaker(speaker: String) -> bool:
	var a: String = speaker.strip_edges().to_lower()
	var b: String = you_name.strip_edges().to_lower()
	return a == b or a == "you"

# -----------------------
# UI helpers
# -----------------------

func _setup_rich_text(rtl: RichTextLabel, mouse_filter_value: int) -> void:
	if rtl == null:
		return
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = mouse_filter_value

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
		planet_name_label.text = String(n1)
		return

	var n2: Variant = _safe_get(_planet, &"display_name")
	if n2 != null:
		planet_name_label.text = String(n2)
		return

	planet_name_label.text = _planet.name

# -----------------------
# Dialogue extraction helpers
# -----------------------

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
		return obj.get(String(prop))
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
		return String(st)

	var data: Variant = _safe_get(planet, &"dialogue_data")
	if data is Object:
		var st2: Variant = _safe_get(data as Object, &"start_title")
		if st2 != null:
			return String(st2)

		var st3: Variant = _safe_get(data as Object, &"dialogue_start_title")
		if st3 != null:
			return String(st3)

	return ""
