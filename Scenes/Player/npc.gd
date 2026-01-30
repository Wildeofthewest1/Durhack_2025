extends Node2D
class_name PlanetNPC

@export var dialogue_data: DialogueData
@export var shop_data: DialogueData

@export var interact_indicator_path: NodePath = NodePath("InteractBubble")
var _interact_indicator: InteractIndicator = null

func _ready() -> void:
	_interact_indicator = get_node_or_null(interact_indicator_path) as InteractIndicator

func show_interact_indicator() -> void:
	if _interact_indicator != null:
		_interact_indicator.show_bounce()

func hide_interact_indicator() -> void:
	if _interact_indicator != null:
		_interact_indicator.hide_bounce()

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

func get_shop_offers() -> Array[ShopOffer]:
	if dialogue_data == null:
		return []
	return dialogue_data.shop_offers

func get_shop_prices() -> Array[int]:
	if shop_data != null:
		return shop_data.prices
	var arr: Array[int] = []
	return arr
