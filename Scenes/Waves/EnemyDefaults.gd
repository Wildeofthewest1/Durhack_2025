extends Node
class_name EnemyDefaults

const Enemies := {
	"Enemy1": {
		"type": "Enemy1",
		"position": Vector2( 0, 0),
		"behaviour": "ranged",
		"weapons": ["res://Scenes/Enemy_Weapons/Shotgun.tscn"],
		"speed": 200,
		"health": 80,
		"rotate_toward_player": true,
		"detectionradius": 500,
	},
	"Enemy2": {
		"type": "Enemy2",
		"position": Vector2( 0, 0),
		"behaviour": "ranged",
		"weapons": ["res://Scenes/Enemy_Weapons/Pistol.tscn"],
		"speed": 200,
		"health": 80,
		"rotate_toward_player": true,
		"detectionradius": 500,
	}
}
