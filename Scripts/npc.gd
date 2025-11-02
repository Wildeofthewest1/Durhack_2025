extends Node2D
class_name PlanetNPC

@export var dialogue_data: DialogueData
@export var shop_data: ShopData

# This just makes it easy to show the planet name without digging.
func get_planet_name() -> String:
	if dialogue_data != null:
		return dialogue_data.planet_name
	return name  # fallback to node name

func get_dialogue_lines() -> Array[String]:
	if dialogue_data != null:
		return dialogue_data.lines
	var arr: Array[String] = []
	return arr

func get_dialogue_replies() -> Array[String]:
	if dialogue_data != null:
		return dialogue_data.replies
	var arr: Array[String] = []
	return arr

func get_shop_items() -> Array[String]:
	if shop_data != null:
		return shop_data.items
	var arr: Array[String] = []
	return arr

func get_shop_prices() -> Array[int]:
	if shop_data != null:
		return shop_data.prices
	var arr: Array[int] = []
	return arr
