extends Resource
class_name ShopItemData

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var unique: bool = false

func apply_purchase(qty: int, context: Object) -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	var inv: ShopInventory = tree.root.get_node_or_null("ShopInventory") as ShopInventory
	if inv == null:
		return false

	if unique and inv.has_unique(id):
		return false

	inv.add_stack(id, qty)

	if unique:
		inv.add_unique(id)

	return true
