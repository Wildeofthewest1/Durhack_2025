extends Node

signal inventory_changed()

# Stack items (consumables etc.)
var _stacks: Dictionary = {} # StringName -> int

# Unique purchases (weapons/passives/key items, etc.)
var _unique: Dictionary = {} # StringName -> bool

# Key items
var _keys: Dictionary = {} # StringName -> bool

# Passive stacks (optional central store)
var _passives: Dictionary = {} # StringName -> int

func add_stack(item_id: StringName, qty: int) -> void:
	if qty <= 0:
		return
	if not _stacks.has(item_id):
		_stacks[item_id] = 0
	_stacks[item_id] = int(_stacks[item_id]) + qty
	inventory_changed.emit()

func get_stack(item_id: StringName) -> int:
	if not _stacks.has(item_id):
		return 0
	return int(_stacks[item_id])

func add_unique(item_id: StringName) -> void:
	_unique[item_id] = true
	inventory_changed.emit()

func has_unique(item_id: StringName) -> bool:
	return _unique.has(item_id) and bool(_unique[item_id]) == true

func add_key(key_id: StringName) -> void:
	_keys[key_id] = true
	inventory_changed.emit()

func has_key(key_id: StringName) -> bool:
	return _keys.has(key_id) and bool(_keys[key_id]) == true

func add_passive(passive_id: StringName, stacks: int) -> void:
	if stacks <= 0:
		return
	if not _passives.has(passive_id):
		_passives[passive_id] = 0
	_passives[passive_id] = int(_passives[passive_id]) + stacks
	inventory_changed.emit()

func get_passive_stacks(passive_id: StringName) -> int:
	if not _passives.has(passive_id):
		return 0
	return int(_passives[passive_id])

func has_passive(passive_id: StringName) -> bool:
	return get_passive_stacks(passive_id) > 0
