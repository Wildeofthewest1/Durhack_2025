extends Node
class_name InteractionShopController

@export var shop_list: ItemList
@export var buy_button: Button

var _planet: Node = null

func _ready() -> void:
	if buy_button != null:
		buy_button.pressed.connect(_on_buy_pressed)

func setup_for_planet(planet: Node) -> void:
	_planet = planet
	refresh()

func refresh() -> void:
	if shop_list == null:
		return

	shop_list.clear()

	if _planet == null or not is_instance_valid(_planet):
		return

	# Expected API on planet: get_shop_items(): Array[String], get_shop_prices(): Array[int]
	if _planet.has_method("get_shop_items") == false:
		return

	var items: Array = _planet.call("get_shop_items")
	var prices: Array = []
	if _planet.has_method("get_shop_prices"):
		prices = _planet.call("get_shop_prices")

	var len_items: int = items.size()
	var len_prices: int = prices.size()
	var max_len: int = len_items
	if len_prices < max_len:
		max_len = len_prices

	for i: int in range(0, max_len):
		var line_text: String = String(items[i]) + " - " + str(prices[i]) + " cr"
		shop_list.add_item(line_text)

func _on_buy_pressed() -> void:
	if shop_list == null:
		return

	var selected: PackedInt32Array = shop_list.get_selected_items()
	if selected.is_empty():
		return

	var idx: int = int(selected[0])
	print("[SHOP] Buy index ", idx, " from ", _planet)
