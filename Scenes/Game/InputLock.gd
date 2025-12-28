extends Node

var _lock_count: int = 0

func lock_gameplay() -> void:
	_lock_count += 1

func unlock_gameplay() -> void:
	_lock_count = max(0, _lock_count - 1)

func is_gameplay_enabled() -> bool:
	return _lock_count == 0
