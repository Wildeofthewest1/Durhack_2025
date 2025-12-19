extends Node

const EnemyDefaults = preload("res://Scenes/Waves/EnemyDefaults.gd")

const DATA := {
	1: {
		"Enemy1" = {
			"Enemy": EnemyDefaults.Enemies["Enemy1"],
			"Count": 3,
			"SpawnRate": 1 #per second
		}
	},
	2: {
		"Enemy2" = {
			"Enemy": EnemyDefaults.Enemies["Enemy2"],
			"Count": 3,
			"SpawnRate": 1 #per second
		}
	}
}
