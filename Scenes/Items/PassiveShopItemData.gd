# res://Data/Shop/PassiveShopItemData.gd
extends ShopItemData
class_name PassiveShopItemData

@export var modifier: StatModifier

func apply_purchase(qty: int, context: Object) -> bool:
	if super.apply_purchase(qty, context) == false:
		return false

	if modifier == null:
		push_warning("PassiveShopItemData: modifier is null for " + display_name)
		return false

	print("adding mod")
	var i: int = 0
	while i < qty:
		print("adding mod frfr")
		PlayerVariables.add_modifier(modifier)
		i += 1

	return true
