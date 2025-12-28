extends Node
class_name DiscoDialogueRunner

signal line_shown(speaker: String, text: String)
signal choices_shown(choices: Array[Dictionary]) # [{ "id": int, "text": String, "goto": StringName }]
signal ended()

var _lines: Array[String] = []
var _labels: Dictionary = {}            # StringName -> int line index
var _ip: int = 0                        # instruction pointer
var _in_choice: bool = false
var _current_choices: Array[Dictionary] = []

func load_timeline(path: String) -> void:
	_lines = _read_lines(path)
	_labels = _index_labels(_lines)
	_ip = 0
	_in_choice = false
	_current_choices = []

func start(at_label: StringName) -> void:
	if _labels.has(at_label) == true:
		_ip = int(_labels[at_label])
	else:
		_ip = 0
	_step_until_output()

func advance() -> void:
	if _in_choice == true:
		return
	_step_until_output()

func choose(choice_id: int) -> void:
	if _in_choice == false:
		return
	for c: Dictionary in _current_choices:
		if int(c["id"]) == choice_id:
			var goto_label: StringName = c["goto"] as StringName
			_in_choice = false
			_current_choices = []
			_jump_to(goto_label)
			_step_until_output()
			return

func _step_until_output() -> void:
	while _ip < _lines.size():
		var raw: String = _lines[_ip].strip_edges()
		_ip += 1

		if raw.length() == 0:
			continue
		if raw.begins_with("#") == true:
			continue

		# label
		if raw.begins_with(":") == true:
			continue

		# jump
		if raw.begins_with("->") == true:
			var target: StringName = StringName(raw.substr(2).strip_edges().trim_prefix(":"))
			_jump_to(target)
			continue

		# choice header
		if raw.begins_with("?") == true:
			_read_choices_block()
			if _current_choices.size() > 0:
				_in_choice = true
				emit_signal("choices_shown", _current_choices)
				return
			continue

		# dialogue line: SPEAKER: text
		var colon_i: int = raw.find(":")
		if colon_i > 0:
			var speaker: String = raw.substr(0, colon_i).strip_edges()
			var text: String = raw.substr(colon_i + 1).strip_edges()
			emit_signal("line_shown", speaker, text)
			return

		# fallback line (no speaker)
		emit_signal("line_shown", "", raw)
		return

	emit_signal("ended")

func _read_choices_block() -> void:
	_current_choices = []
	var next_id: int = 0

	while _ip < _lines.size():
		var raw: String = _lines[_ip].strip_edges()

		if raw.length() == 0:
			_ip += 1
			continue

		# stop choices if we hit anything that's not "- "
		if raw.begins_with("-") == false:
			return

		_ip += 1

		# Parse: - text -> :label
		var line: String = raw.trim_prefix("-").strip_edges()
		var arrow_i: int = line.rfind("->")
		if arrow_i < 0:
			continue

		var choice_text: String = line.substr(0, arrow_i).strip_edges()
		var goto_part: String = line.substr(arrow_i + 2).strip_edges()
		goto_part = goto_part.trim_prefix(":")
		var goto_label: StringName = StringName(goto_part)

		var entry: Dictionary = {
			"id": next_id,
			"text": choice_text,
			"goto": goto_label
		}
		_current_choices.append(entry)
		next_id += 1

func _jump_to(label: StringName) -> void:
	if _labels.has(label) == true:
		_ip = int(_labels[label])

func _index_labels(lines: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for i: int in range(0, lines.size()):
		var raw: String = lines[i].strip_edges()
		if raw.begins_with(":") == true:
			var label: StringName = StringName(raw.substr(1).strip_edges())
			out[label] = i
	return out

func _read_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	if FileAccess.file_exists(path) == false:
		return out
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while f.eof_reached() == false:
		out.append(f.get_line())
	return out
