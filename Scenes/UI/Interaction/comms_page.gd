extends Node
class_name InteractionCommsController

@export var planet_name_label: Label

# History is the main (only) display
@export var history_scroll: ScrollContainer
@export var history_label: RichTextLabel

# Disco-style choices/continue rendered as URLs
@export var choices_label: RichTextLabel

# Kept for compatibility with your scene, not used by comms now
@export var reply_holder: VBoxContainer

@export var next_action: StringName = &"ui_accept"

@export var show_continue_link: bool = true
@export var continue_text: String = "→ Continue"

# Speaker styling
@export var npc_name_color: String = "#d9d4ff"
@export var player_name_color: String = "#f3d38b"
@export var player_name: String = "YOU"

@export var continue_color: String = "#8ee6c7"
@export var choice_color: String = "#e8e1c9"

var _planet: Node = null
var _dialogue_resource: DialogueResource = null
var _start_title: String = ""

var _dialogue_line: DialogueLine = null
var _is_waiting_for_input: bool = false
var _is_running: bool = false

# Dialogue Manager expects an Array here (extra game states)
var _extra_game_states: Array = []

const META_CONTINUE: String = "dm_continue"
const META_CHOICE_PREFIX: String = "dm_choice:" # dm_choice:<next_id>

# Keep current responses so we can log the chosen one
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

	# Keyboard continue only when there are no responses
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

	var speaker: String = ""
	if _dialogue_line.character != "":
		speaker = _dialogue_line.character
	elif _dialogue_line.speaker != "":
		speaker = _dialogue_line.speaker

	var text_bbcode: String = _dialogue_line.text
	var stripped_text: String = text_bbcode.strip_edges()

	# Mutation-only line: empty + no responses => auto-advance (DM3-safe)
	if stripped_text.is_empty() and _dialogue_line.responses.size() == 0:
		await get_tree().process_frame
		_advance_async(_dialogue_line.next_id)
		return

	# Append the line ONLY to history (main display)
	if speaker.is_empty():
		# Narration/system text
		_append_history(text_bbcode)
	else:
		_append_history(
			"[color=%s][b]%s[/b][/color]  %s"
			% [npc_name_color, speaker, text_bbcode]
		)

	# Responses -> URL list
	if _dialogue_line.responses.size() > 0:
		_current_responses = _dialogue_line.responses.duplicate()
		_render_choice_urls(_current_responses)
		_is_waiting_for_input = true
		return

	# Timed lines -> auto advance
	if _dialogue_line.time != "":
		var seconds: float = 0.0
		if _dialogue_line.time == "auto":
			seconds = float(_dialogue_line.text.length()) * 0.02
		else:
			seconds = _dialogue_line.time.to_float()
		await get_tree().create_timer(seconds).timeout
		_advance_async(_dialogue_line.next_id)
		return

	# No responses -> show Continue URL
	if show_continue_link:
		_render_continue_url()

	_is_waiting_for_input = true

# -----------------------
# URL rendering + logging choice
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
	var i: int = 1
	for r in responses:
		var meta: String = META_CHOICE_PREFIX + r.next_id
		bb += "[color=%s][url=%s]%d. %s[/url][/color]\n" % [choice_color, meta, i, r.text]
		i += 1
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

	if m.begins_with(META_CHOICE_PREFIX):
		var next_id: String = m.substr(META_CHOICE_PREFIX.length())

		# Log chosen response into history (player colored)
		var chosen_text: String = _find_response_text_by_next_id(next_id)
		if not chosen_text.is_empty():
			_append_history(
				"[color=%s][b]%s[/b][/color]  %s"
				% [player_name_color, player_name, chosen_text]
			)

		_is_waiting_for_input = false
		_current_responses.clear()
		_clear_choices()
		_advance_async(next_id)
		return

func _find_response_text_by_next_id(next_id: String) -> String:
	for r in _current_responses:
		if r.next_id == next_id:
			return r.text
	return ""

# -----------------------
# History helpers (scroll + input)
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
