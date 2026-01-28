extends Node

const ITEMS := {
	"scrap": {
		"scene": preload("res://Scenes/Items/Pickups/scrap.tscn"),
		"value_per_pickup": 1
	},
	"rareItem": {
		"scene": preload("res://Scenes/Items/Pickups/rareItem.tscn"),
		"value_per_pickup": 1
	},
	"rareItem2": {
		"scene": preload("res://Scenes/Items/Pickups/rareItem2.tscn"),
		"value_per_pickup": 1
	},

	# Later:
	# "EnergyCell": { ... }
	# "RareItem": { ... }
}
