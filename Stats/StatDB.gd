extends Resource
class_name StatDB

@export var definitions: Array[StatDefinition] = []

var _map: Dictionary = {} # StringName -> StatDefinition
var _built: bool = false

func build_index() -> void:
	_map.clear()

	for def in definitions:
		var sdef: StatDefinition = def
		if sdef == null:
			continue
		if sdef.id == &"":
			continue
		_map[sdef.id] = sdef

	_built = true

func get_def(stat_id: StringName) -> StatDefinition:
	if not _built:
		build_index()
	if _map.has(stat_id):
		return _map[stat_id] as StatDefinition
	return null

func get_all_ids() -> Array[StringName]:
	if not _built:
		build_index()

	var ids: Array[StringName] = []
	for k in _map.keys():
		ids.append(k as StringName)
	return ids
