# res://Data/Shop/WeaponShopItemData.gd
extends ShopItemData
class_name WeaponShopItemData

@export var weapon_id: StringName = &""
@export var auto_equip: bool = true

func apply_purchase(qty: int, context: Object) -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	var inv: ShopInventory = tree.root.get_node_or_null("ShopInventory") as ShopInventory
	if inv == null:
		return false

	if unique and inv.has_unique(id):
		return false

	var wm: WeaponManager = tree.get_first_node_in_group("weapon_manager") as WeaponManager
	if wm == null:
		push_warning("WeaponShopItemData: no WeaponManager found")
		return false

	if wm.has_method("unlock_weapon") == false:
		push_warning("WeaponShopItemData: WeaponManager missing unlock_weapon()")
		return false

	var ok: bool = bool(wm.call("unlock_weapon", weapon_id, auto_equip))
	if ok == false:
		return false

	if unique:
		inv.add_unique(id)

	return true
