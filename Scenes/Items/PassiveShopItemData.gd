# res://Data/Shop/PassiveShopItemData.gd
extends ShopItemData
class_name PassiveShopItemData

@export var passive_id: StringName = &""
@export var stacks: int = 1

func apply_purchase(qty: int, context: Object) -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	var inv: ShopInventory = tree.root.get_node_or_null("ShopInventory") as ShopInventory
	if inv == null:
		return false

	if unique and inv.has_unique(id):
		return false

	var total: int = stacks * qty
	inv.add_passive(passive_id, total)

	# Optional runtime notification
	var pm: PassiveManager = tree.root.get_node_or_null("PassiveManager") as PassiveManager
	if pm != null:
		pm.passive_changed.emit(passive_id, inv.get_passive_stacks(passive_id))

	if unique:
		inv.add_unique(id)

	return true
