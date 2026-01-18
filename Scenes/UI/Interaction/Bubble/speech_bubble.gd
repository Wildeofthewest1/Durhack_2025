extends PanelContainer
class_name SpeechBubble

@export var speaker_label: RichTextLabel
@export var dialogue_label: DialogueLabel

@export var npc_speaker_color: String = "#5CBBFF"
@export var you_speaker_color: String = "#f3d38b"

@export var you_name: String = "YOU"

var _typing: bool = false
var _is_you: bool = false

func setup(speaker: String, line: DialogueLine, is_you: bool) -> void:
	_is_you = is_you

	if speaker_label != null:
		speaker_label.bbcode_enabled = true
		var color_hex: String = you_speaker_color if is_you else npc_speaker_color
		if speaker.strip_edges().is_empty():
			speaker_label.text = ""
		else:
			speaker_label.text = "[color=%s][b]%s[/b][/color]" % [color_hex, speaker]

	if dialogue_label != null:
		dialogue_label.process_mode = Node.PROCESS_MODE_ALWAYS
		dialogue_label.dialogue_line = line

func type_out() -> void:
	if dialogue_label == null:
		return

	_typing = true
	dialogue_label.type_out()
	await dialogue_label.finished_typing
	_typing = false

func is_typing() -> bool:
	return _typing

func finish_typing_instant() -> void:
	if dialogue_label == null:
		return
	dialogue_label.visible_characters = -1
	_typing = false
