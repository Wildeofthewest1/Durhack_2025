extends Node
class_name DialoguePresenter

signal dialogue_finished

@export var dialogue_label: RichTextLabel
@export var speaker_name_label: Label
@export var portrait_texture_rect: TextureRect

# Styling
@export var continue_text: String = "▶ CONTINUE"
@export var continue_color: String = "a8d7ff"
@export var speaker_color: String = "ffd78a"
@export var option_color: String = "ffffff"
@export var player_color: String = "b7ffb7"

@export var option_gap_lines: int = 1
@export var option_indent_spaces: int = 4

# State
var _running: bool = false
var _awaiting_continue: bool = false
var _awaiting_choice: bool = false

# Transcript BBCode lines
var _log_bb: Array[String] = []

# Current options (UI-indexed 0..n-1)
var _option_texts: Array[String] = []

# Track speaker to avoid redundant portrait updates
var _last_speaker: String = ""

func _ready() -> void:
	if dialogue_label != null:
		dialogue_label.bbcode_enabled = true
		dialogue_label.mouse_filter = Control.MOUSE_FILTER_STOP
		dialogue_label.meta_clicked.connect(_on_meta_clicked)

	# Dialogic hooks
	if Dialogic.Text != null:
		Dialogic.Text.about_to_show_text.connect(_on_about_to_show_text)

		# Optional: if available in your Dialogic build, update speaker/portrait when speaker changes
		if Dialogic.Text.has_signal("speaker_updated") == true:
			Dialogic.Text.connect("speaker_updated", Callable(self, "_on_speaker_updated"))

	if Dialogic.Choices != null:
		Dialogic.Choices.question_shown.connect(_on_question_shown)

	Dialogic.timeline_ended.connect(_on_timeline_ended)

func start_timeline(timeline: StringName) -> void:
	_running = true
	_awaiting_continue = false
	_awaiting_choice = false
	_last_speaker = ""
	_log_bb.clear()
	_option_texts.clear()
	_render()

	Dialogic.start_timeline(timeline)

func _on_timeline_ended() -> void:
	_running = false
	_awaiting_continue = false
	_awaiting_choice = false
	_option_texts.clear()
	_render()
	dialogue_finished.emit()

# ------------------------------------------------------------
# Dialogic -> UI
# ------------------------------------------------------------
func _on_about_to_show_text(info: Dictionary) -> void:
	_option_texts.clear()
	_awaiting_choice = false
	_awaiting_continue = true

	var speaker: String = _extract_speaker(info)
	var text_line: String = _extract_text(info)

	# Speaker label (separate UI, like Disco)
	_apply_speaker(speaker)

	# Portrait (separate TextureRect)
	_update_portrait_from_info(info)

	# Append to transcript (speaker header + line)
	if speaker != "":
		_log_bb.append("[color=#" + speaker_color + "][b]" + _bbcode_escape(speaker.to_upper()) + "[/b][/color]")
	_log_bb.append(_bbcode_escape(text_line))
	_log_bb.append("") # blank line

	_render()

func _on_question_shown(info: Dictionary) -> void:
	_option_texts.clear()

	if info.has("choices") == false:
		return

	var arr_v: Variant = info["choices"]
	if typeof(arr_v) != TYPE_ARRAY:
		return

	var choices: Array = arr_v as Array
	for i in range(0, choices.size()):
		var entry_v: Variant = choices[i]
		var choice_text: String = "Choice"

		if typeof(entry_v) == TYPE_DICTIONARY:
			var d: Dictionary = entry_v as Dictionary
			if d.has("text") == true:
				var t: Variant = d["text"]
				if typeof(t) == TYPE_STRING:
					choice_text = t as String

		_option_texts.append(choice_text)

	_awaiting_choice = _option_texts.size() > 0
	_awaiting_continue = false
	_render()

# Optional: speaker updates that happen without a text event
func _on_speaker_updated(speaker_info: Variant) -> void:
	var speaker: String = ""

	if typeof(speaker_info) == TYPE_STRING:
		speaker = speaker_info as String
	else:
		speaker = str(speaker_info)

	_apply_speaker(speaker)

func _apply_speaker(speaker: String) -> void:
	if speaker == "":
		return
	if speaker == _last_speaker:
		return

	_last_speaker = speaker

	if speaker_name_label != null:
		speaker_name_label.text = speaker

# ------------------------------------------------------------
# Rendering
# ------------------------------------------------------------
func _render() -> void:
	if dialogue_label == null:
		return

	dialogue_label.clear()

	# Transcript
	for s in _log_bb:
		if s == "":
			dialogue_label.append_text("\n")
		else:
			dialogue_label.append_text(s + "\n")

	# Choices
	if _awaiting_choice == true:
		dialogue_label.append_text("\n")

		var indent: String = ""
		for j in range(0, option_indent_spaces):
			indent += " "

		for i in range(0, _option_texts.size()):
			if i > 0:
				for g in range(0, option_gap_lines):
					dialogue_label.append_text("\n")

			var shown: String = indent + str(i + 1) + ". " + _option_texts[i]
			var meta: String = "choice:" + str(i)

			var bb: String = "[color=#" + option_color + "][url=" + meta + "]" + _bbcode_escape(shown) + "[/url][/color]\n"
			dialogue_label.append_text(bb)

		dialogue_label.append_text("\n")
		dialogue_label.scroll_to_line(dialogue_label.get_line_count())
		return

	# Continue (distinct clickable option)
	if _awaiting_continue == true:
		var cont: String = "[color=#" + continue_color + "][url=continue]" + _bbcode_escape(continue_text) + "[/url][/color]\n"
		dialogue_label.append_text(cont)

	dialogue_label.scroll_to_line(dialogue_label.get_line_count())

# ------------------------------------------------------------
# Click handling (only inside RichTextLabel)
# ------------------------------------------------------------
func _on_meta_clicked(meta: Variant) -> void:
	if _running == false:
		return

	var m: String = ""
	if typeof(meta) == TYPE_STRING:
		m = meta as String
	else:
		m = str(meta)

	if m == "continue":
		_do_continue()
		return

	if m.begins_with("choice:") == true:
		var idx_str: String = m.substr(7, m.length() - 7)
		var ui_idx: int = int(idx_str)
		_pick_choice(ui_idx)
		return

func _do_continue() -> void:
	if _awaiting_continue == false:
		return
	if _awaiting_choice == true:
		return

	_awaiting_continue = false
	_render()
	Dialogic.handle_next_event()

func _pick_choice(ui_index: int) -> void:
	if _awaiting_choice == false:
		return
	if ui_index < 0 or ui_index >= _option_texts.size():
		return
	if Dialogic.Choices == null:
		return

	# Log player selection (Disco feel)
	var chosen: String = _option_texts[ui_index]
	_log_bb.append("[color=#" + player_color + "][i]YOU: " + _bbcode_escape(chosen) + "[/i][/color]")
	_log_bb.append("")

	# Clear options and refresh
	_option_texts.clear()
	_awaiting_choice = false
	_awaiting_continue = false
	_render()

	# IMPORTANT:
	# Select by UI index (0..n-1). This is the most reliable across Dialogic builds.
	Dialogic.Choices.select_choice(ui_index)

	# ALSO IMPORTANT:
	# With custom UI, you often need to advance once after selection.
	call_deferred("_advance_until_blocked")

func _advance_until_blocked() -> void:
	# Advance a few times until Dialogic emits text/choices or ends.
	# Prevents "stuck after first choice".
	var steps: int = 0
	while steps < 6:
		if _running == false:
			return
		if _awaiting_choice == true:
			return
		if _awaiting_continue == true:
			return
		Dialogic.handle_next_event()
		steps += 1

# ------------------------------------------------------------
# Portrait handling (separate TextureRect)
# ------------------------------------------------------------
func _update_portrait_from_info(info: Dictionary) -> void:
	if portrait_texture_rect == null:
		return

	var tex: Texture2D = null

	# Some versions may provide a Texture2D directly
	if info.has("portrait_texture") == true:
		var v: Variant = info["portrait_texture"]
		if typeof(v) == TYPE_OBJECT:
			var o: Object = v as Object
			if o is Texture2D:
				tex = o as Texture2D

	# Some versions may provide a resource path
	if tex == null and info.has("portrait") == true:
		var p: Variant = info["portrait"]
		if typeof(p) == TYPE_STRING:
			var path: String = p as String
			if ResourceLoader.exists(path) == true:
				var r: Resource = load(path)
				if r is Texture2D:
					tex = r as Texture2D

	portrait_texture_rect.texture = tex

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
func _extract_text(info: Dictionary) -> String:
	if info.has("text") == false:
		return ""
	var v: Variant = info["text"]
	if typeof(v) == TYPE_STRING:
		return v as String
	return ""

func _extract_speaker(info: Dictionary) -> String:
	# Different Dialogic builds can use different keys; keep it safe.
	if info.has("character") == true:
		var c: Variant = info["character"]
		if typeof(c) == TYPE_STRING:
			return c as String
	if info.has("speaker") == true:
		var s: Variant = info["speaker"]
		if typeof(s) == TYPE_STRING:
			return s as String
	return ""

func _bbcode_escape(s: String) -> String:
	var out: String = s
	out = out.replace("[", "\\[")
	out = out.replace("]", "\\]")
	return out
