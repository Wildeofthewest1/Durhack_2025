# res://Autoload/PassiveManager.gd
extends Node

signal passive_changed(passive_id: StringName, new_stacks: int)

func add_passive(passive_id: StringName, stacks: int) -> void:
	if stacks <= 0:
		return

	var inv: ShopInventory = _get_inventory()
	if inv == null:
		return

	inv.add_passive(passive_id, stacks)
	passive_changed.emit(passive_id, inv.get_passive_stacks(passive_id))


func get_stacks(passive_id: StringName) -> int:
	var inv: ShopInventory = _get_inventory()
	if inv == null:
		return 0
	return inv.get_passive_stacks(passive_id)


func has_passive(passive_id: StringName) -> bool:
	return get_stacks(passive_id) > 0


# ------------------------------------------------
# Internal helper (Resource-safe access pattern)
# ------------------------------------------------
func _get_inventory() -> ShopInventory:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ShopInventory") as ShopInventory
