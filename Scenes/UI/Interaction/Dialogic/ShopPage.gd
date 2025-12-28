extends Control
class_name ShopPage

@export var shop_list: ItemList
@export var buy_button: Button

var _planet: PlanetNPC = null

func _ready() -> void:
	if buy_button != null:
		buy_button.pressed.connect(_on_buy_pressed)

func set_planet(planet: PlanetNPC) -> void:
	_planet = planet
	refresh()

func refresh() -> void:
	if shop_list == null:
		return

	shop_list.clear()

	if _planet == null:
		return

	var items: Array[String] = _planet.get_shop_items()
	var prices: Array[int] = _planet.get_shop_prices()

	var max_len: int = items.size()
	if prices.size() < max_len:
		max_len = prices.size()

	for i in range(0, max_len):
		var line_text: String = items[i] + " - " + str(prices[i]) + " cr"
		shop_list.add_item(line_text)

func _on_buy_pressed() -> void:
	if shop_list == null:
		return
	if _planet == null:
		return

	var selected: PackedInt32Array = shop_list.get_selected_items()
	if selected.size() == 0:
		return

	var idx: int = selected[0]
	print("[SHOP] Buy index " + str(idx) + " from " + _planet.name)
