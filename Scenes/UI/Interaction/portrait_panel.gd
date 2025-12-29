extends Node
class_name InteractionPortraitController

@export var portrait_panel: Control
@export var portrait_texture_rect: TextureRect

@export var tween_time: float = 0.18
@export var hide_offset: float = 400.0

var _tween: Tween = null
var _base_pos: Vector2 = Vector2.ZERO
var _has_base_pos: bool = false

func _ready() -> void:
	if portrait_panel != null:
		_base_pos = portrait_panel.position
		_has_base_pos = true

func setup_for_planet(planet: Node) -> void:
	var tex: Texture2D = _extract_portrait_texture(planet)
	if portrait_texture_rect != null:
		portrait_texture_rect.texture = tex

func fade_in() -> void:
	if portrait_panel == null:
		return
	_kill_tween()

	if not _has_base_pos:
		_base_pos = portrait_panel.position
		_has_base_pos = true

	portrait_panel.visible = true
	portrait_panel.modulate.a = 0.0
	portrait_panel.position = _base_pos + Vector2(hide_offset, 0.0)

	_tween = create_tween()
	_tween.tween_property(portrait_panel, "position", _base_pos, tween_time)
	_tween.parallel().tween_property(portrait_panel, "modulate:a", 1.0, tween_time)

func fade_out() -> void:
	if portrait_panel == null:
		return
	_kill_tween()

	if not _has_base_pos:
		_base_pos = portrait_panel.position
		_has_base_pos = true

	_tween = create_tween()
	_tween.tween_property(portrait_panel, "position", _base_pos + Vector2(hide_offset, 0.0), tween_time)
	_tween.parallel().tween_property(portrait_panel, "modulate:a", 0.0, tween_time)
	_tween.finished.connect(_on_fade_out_finished)

func _on_fade_out_finished() -> void:
	if portrait_panel != null:
		portrait_panel.visible = false

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

# -----------------------
# Safe property access
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

func _extract_portrait_texture(planet: Node) -> Texture2D:
	if planet == null or not is_instance_valid(planet):
		return null

	# Nested: planet.dialogue_data.portrait_texture
	var data: Variant = _safe_get(planet, &"dialogue_data")
	if data is Object:
		var t1: Variant = _safe_get(data as Object, &"portrait_texture")
		if t1 is Texture2D:
			return t1 as Texture2D

	# Direct: planet.portrait_texture
	var t2: Variant = _safe_get(planet, &"portrait_texture")
	if t2 is Texture2D:
		return t2 as Texture2D

	return null
