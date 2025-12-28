extends Resource
class_name PortraitSet

@export var portraits: Dictionary[StringName, Texture2D] = {}

@export var default_key: StringName = &"neutral"

func get_portrait(key: StringName) -> Texture2D:
	if portraits.has(key):
		return portraits[key]
	if portraits.has(default_key):
		return portraits[default_key]
	return null
