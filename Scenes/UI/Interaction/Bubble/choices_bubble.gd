extends PanelContainer
class_name ChoicesBubble

signal choice_selected(index: int)
signal continue_selected()

@export var choices_label: RichTextLabel

@export var choice_color: String = "#e8e1c9"
@export var continue_color: String = "#8ee6c7"
@export var continue_text: String = "→ Continue"

# Font sizes (separate)
@export var choice_font_size: int = 18
@export var continue_font_size: int = 18

# Hover colors (optional overrides). Leave empty to auto-mute.
@export var choice_hover_color: String = ""
@export var continue_hover_color: String = ""

# If hover colors are empty, we auto-mute using this factor (lower = more muted)
@export var hover_mute_factor: float = 0.75

const META_CONTINUE: String = "dm_continue"
const META_CHOICE_IDX_PREFIX: String = "dm_choice_idx:"

var _showing_continue: bool = false
var _responses: Array[DialogueResponse] = []
var _hovered_meta: String = ""

func _ready() -> void:
	if choices_label == null:
		return

	choices_label.bbcode_enabled = true
	choices_label.fit_content = true
	choices_label.scroll_active = false
	choices_label.mouse_filter = Control.MOUSE_FILTER_STOP
	choices_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Remove underline on links (preferred)
	if "meta_underlined" in choices_label:
		choices_label.meta_underlined = false

	if not choices_label.meta_clicked.is_connected(_on_meta_clicked):
		choices_label.meta_clicked.connect(_on_meta_clicked)

	# Hover signals (Godot 4)
	if "meta_hover_started" in choices_label:
		if not choices_label.meta_hover_started.is_connected(_on_meta_hover_started):
			choices_label.meta_hover_started.connect(_on_meta_hover_started)

	if "meta_hover_ended" in choices_label:
		if not choices_label.meta_hover_ended.is_connected(_on_meta_hover_ended):
			choices_label.meta_hover_ended.connect(_on_meta_hover_ended)

func set_continue() -> void:
	_showing_continue = true
	_responses.clear()
	_rebuild_bbcode()

func set_choices(responses: Array[DialogueResponse]) -> void:
	_showing_continue = false
	_responses = responses
	_rebuild_bbcode()

func _rebuild_bbcode() -> void:
	if choices_label == null:
		return

	var bb: String = ""

	if _showing_continue:
		var meta: String = META_CONTINUE
		var base_hex: String = continue_color
		var hover_hex: String = _get_hover_hex(true)

		var use_hex: String = base_hex
		if _hovered_meta == meta:
			use_hex = hover_hex

		bb += "[font_size=%d][color=%s][url=%s]%s[/url][/color][/font_size]" % [
			continue_font_size, use_hex, meta, continue_text
		]
	else:
		var index: int = 0
		var display_num: int = 1

		for r in _responses:
			var meta: String = META_CHOICE_IDX_PREFIX + str(index)
			var base_hex: String = choice_color
			var hover_hex: String = _get_hover_hex(false)

			var use_hex: String = base_hex
			if _hovered_meta == meta:
				use_hex = hover_hex

			bb += "[font_size=%d][color=%s][url=%s]%d. %s[/url][/color][/font_size]\n" % [
				choice_font_size, use_hex, meta, display_num, r.text
			]

			index += 1
			display_num += 1

	choices_label.text = bb

func _get_hover_hex(is_continue: bool) -> String:
	if is_continue:
		if continue_hover_color != "":
			return continue_hover_color
		return _muted_hex(continue_color, hover_mute_factor)

	if choice_hover_color != "":
		return choice_hover_color
	return _muted_hex(choice_color, hover_mute_factor)

func _muted_hex(hex: String, factor: float) -> String:
	var f: float = clampf(factor, 0.0, 1.0)
	var c: Color = Color.from_string(hex, Color.WHITE)

	# Simple "mute": reduce intensity and slightly desaturate toward a mid-gray
	var gray: Color = Color(0.7, 0.7, 0.7, c.a)
	var muted: Color = c.lerp(gray, 1.0 - f)

	# Return "#RRGGBB" (ignore alpha here; RichTextLabel color tag uses hex fine)
	return muted.to_html(false)

func _on_meta_hover_started(meta: Variant) -> void:
	_hovered_meta = str(meta)
	_rebuild_bbcode()

func _on_meta_hover_ended(meta: Variant) -> void:
	var m: String = str(meta)
	if _hovered_meta == m:
		_hovered_meta = ""
		_rebuild_bbcode()

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
