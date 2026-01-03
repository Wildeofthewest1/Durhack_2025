extends PanelContainer
class_name ChoicesBubble

signal choice_selected(index: int)
signal continue_selected()

@export var choices_label: RichTextLabel

@export var choice_color: String = "#e8e1c9"
@export var continue_color: String = "#8ee6c7"
@export var continue_text: String = "→ Continue"

const META_CONTINUE: String = "dm_continue"
const META_CHOICE_IDX_PREFIX: String = "dm_choice_idx:"

func _ready() -> void:
	if choices_label == null:
		return

	choices_label.bbcode_enabled = true
	choices_label.fit_content = true
	choices_label.scroll_active = false
	choices_label.mouse_filter = Control.MOUSE_FILTER_STOP
	choices_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Remove underline on links (preferred)
	# If your Godot version doesn't have meta_underlined, do it via Theme Override in inspector.
	if "meta_underlined" in choices_label:
		choices_label.meta_underlined = false

	if not choices_label.meta_clicked.is_connected(_on_meta_clicked):
		choices_label.meta_clicked.connect(_on_meta_clicked)

func set_continue() -> void:
	if choices_label == null:
		return

	var bb: String = ""
	bb += "[color=%s][url=%s]%s[/url][/color]" % [continue_color, META_CONTINUE, continue_text]
	choices_label.text = bb

func set_choices(responses: Array[DialogueResponse]) -> void:
	if choices_label == null:
		return

	var bb: String = ""
	var index: int = 0
	var display_num: int = 1

	for r in responses:
		var meta: String = META_CHOICE_IDX_PREFIX + str(index)
		bb += "[color=%s][url=%s]%d. %s[/url][/color]\n" % [choice_color, meta, display_num, r.text]
		index += 1
		display_num += 1

	choices_label.text = bb

func _on_meta_clicked(meta: Variant) -> void:
	var m: String = str(meta)

	if m == META_CONTINUE:
		continue_selected.emit()
		return

	if m.begins_with(META_CHOICE_IDX_PREFIX):
		var idx_str: String = m.substr(META_CHOICE_IDX_PREFIX.length())
		var idx: int = idx_str.to_int()
		choice_selected.emit(idx)
		return
