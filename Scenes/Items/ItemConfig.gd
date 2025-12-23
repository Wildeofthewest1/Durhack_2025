extends Node

const ITEMS := {
	"scrap": {
		"scene": preload("res://Scenes/Items/ItemScenes/scrap.tscn"),
		"value_per_pickup": 1
	},
	"rareItem": {
		"scene": preload("res://Scenes/Items/ItemScenes/rareItem.tscn"),
		"value_per_pickup": 1
	},
	"rareItem2": {
		"scene": preload("res://Scenes/Items/ItemScenes/rareItem2.tscn"),
		"value_per_pickup": 1
	},

	# Later:
	# "EnergyCell": { ... }
	# "RareItem": { ... }
}
