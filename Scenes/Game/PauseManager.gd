extends Node

# Autoload (add to Project > Project Settings > Autoload as "PauseManager")

var _is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_paused(paused: bool) -> void:
	_is_paused = paused
	Engine.time_scale = 0.0 if paused else 1.0

func is_paused() -> bool:
	return _is_paused

func toggle_pause() -> void:
	set_paused(not _is_paused)
