extends Node

var _data: Dictionary = {}

func _get(property: StringName) -> Variant:
	var key: String = str(property)
	if not _data.has(key):
		_data[key] = null
	return _data[key]

func _set(property: StringName, value: Variant) -> bool:
	var key: String = str(property)
	_data[key] = value
	return true

func clear() -> void:
	_data.clear()

func set_initial(dict: Dictionary) -> void:
	_data.clear()
	for key in dict.keys():
		_data[str(key)] = dict[key]

func get_data() -> Dictionary:
	return _data
