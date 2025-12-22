# ResourceManager.gd
extends Node

signal resource_changed(resource_id: String, new_amount: int)

var _resources: Dictionary = {}

func _ready() -> void:
	_resources.clear()

func add(resource_id: String, amount: int) -> void:
	if not _resources.has(resource_id):
		_resources[resource_id] = 0
	_resources[resource_id] += amount
	resource_changed.emit(resource_id, _resources[resource_id])

func spend(resource_id: String, amount: int) -> bool:
	if get_amount(resource_id) < amount:
		return false
	_resources[resource_id] -= amount
	resource_changed.emit(resource_id, _resources[resource_id])
	return true

func get_amount(resource_id: String) -> int:
	if not _resources.has(resource_id):
		return 0
	return _resources[resource_id]
