extends Resource
class_name ShopOffer

@export var item: ShopItemData
@export var price: int = 0
@export var stock: int = -1 # -1 infinite, 0 sold out, >0 left

func is_available() -> bool:
	return stock != 0
