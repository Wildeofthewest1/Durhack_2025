extends Node2D
class_name InteractIndicator

@export var show_scale: Vector2 = Vector2(1.0, 1.0)
@export var hidden_scale: Vector2 = Vector2(0.0, 0.0)

@export var show_time: float = 0.22
@export var hide_time: float = 0.12

@export var fade: bool = true
@export var hidden_alpha: float = 0.0
@export var shown_alpha: float = 1.0

var _tween: Tween = null

func _ready() -> void:
	show_scale = scale
	scale = hidden_scale
	visible = false
	if fade:
		modulate.a = hidden_alpha

func show_bounce() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

	visible = true

	_tween = create_tween()
	_tween.set_parallel(true)

	_tween.tween_property(self, "scale", show_scale, show_time) \
		.set_trans(Tween.TRANS_BOUNCE) \
		.set_ease(Tween.EASE_OUT)

	if fade:
		_tween.tween_property(self, "modulate:a", shown_alpha, show_time * 0.8)

func hide_bounce() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

	_tween = create_tween()
	_tween.set_parallel(true)

	_tween.tween_property(self, "scale", hidden_scale, hide_time) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_IN)

	if fade:
		_tween.tween_property(self, "modulate:a", hidden_alpha, hide_time)

	_tween.set_parallel(false)
	_tween.tween_callback(_finish_hide)

func _finish_hide() -> void:
	visible = false
