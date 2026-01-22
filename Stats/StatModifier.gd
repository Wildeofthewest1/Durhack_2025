extends Resource
class_name StatModifier

enum Op {
	ADD_FLAT = 0,
	ADD_PERCENT = 1,
	MULTIPLY = 2,
	OVERRIDE = 3
}

@export var stat_id: StringName = &""
@export var op: int = Op.ADD_FLAT
@export var value: float = 0.0

# Used to remove modifiers cleanly (e.g. &"ITEM_BOOTS", &"BUFF_RAGE")
@export var source: StringName = &""

# duration_seconds <= 0 means infinite
@export var duration_seconds: float = -1.0

# optional: later you can use this for stacking rules
@export var stack_key: StringName = &""
