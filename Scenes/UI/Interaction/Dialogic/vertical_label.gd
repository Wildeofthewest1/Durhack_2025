extends Control

func _ready() -> void:
	_update_pivot()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_pivot()

func _update_pivot() -> void:
	pivot_offset = size
