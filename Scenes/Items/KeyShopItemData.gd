# res://Data/Shop/KeyShopItemData.gd
extends ShopItemData
class_name KeyShopItemData

@export var key_id: StringName = &""

func apply_purchase(qty: int, context: Object) -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	var inv: ShopInventory = tree.root.get_node_or_null("ShopInventory") as ShopInventory
	if inv == null:
		return false

	if inv.has_key(key_id):
		return false

	inv.add_key(key_id)

	if unique:
		inv.add_unique(id)

	return true
