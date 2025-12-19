extends Node

const EnemyDefaults = preload("res://Scenes/Waves/EnemyDefaults.gd")

const DATA := {
	1: {
		"Enemy1": {
			"Enemy": EnemyDefaults.Enemies["Enemy1"],
			"Count": 2,
			"SpawnRate": 1 #per second
		},
		"Enemy2": {
			"Enemy": EnemyDefaults.Enemies["Enemy2"],
			"Count": 4,
			"SpawnRate": 1 #per second
		},
		"Enemy3": {
			"Enemy": EnemyDefaults.Enemies["Enemy3"],
			"Count": 2,
			"SpawnRate": 1 #per second
		}
	},
	2: {
		"Enemy1": {
			"Enemy": EnemyDefaults.Enemies["Mothership1"],
			"Count": 1,
			"SpawnRate": 1 #per second
		},
		"Enemy2": {
			"Enemy": EnemyDefaults.Enemies["Enemy4"],
			"Count": 2,
			"SpawnRate": 1 #per second
		},
		"Enemy3": {
			"Enemy": EnemyDefaults.Enemies["Enemy5"],
			"Count": 2,
			"SpawnRate": 1 #per second
		},
	}
}
