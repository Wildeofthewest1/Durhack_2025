extends Node

const EnemyDefaults_ = preload("res://Scenes/Waves/EnemyDefaults.gd")

const DATA := {
	1: {
		"Enemy1" = {
			"Enemy": EnemyDefaults_.Enemies["Enemy1"],
			"Count": 10,
			"SpawnRate": 1 #per second
		}
	},
	2: {
		"Enemy2" = {
			"Enemy": EnemyDefaults_.Enemies["Enemy2"],
			"Count": 10,
			"SpawnRate": 1 #per second
		}
	}
}
