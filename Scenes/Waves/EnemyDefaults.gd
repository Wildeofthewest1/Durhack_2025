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
	},
	"Enemy3": {
		"type": "Enemy3",
		"position": Vector2( 0, 0),
		"behaviour": "pursuer",
		"weapons": ["res://Scenes/Enemy_Weapons/Pistol.tscn"],
		"speed": 700,
		"health": 500,
		"rotate_toward_player": true,
		"detectionradius": 1000
	},
	"Enemy4": {
		"type": "Enemy4",
		"position": Vector2( 0, 0),
		"behaviour": "ranged",
		"weapons": ["res://Scenes/Enemy_Weapons/Pistol.tscn"],
		"speed": 180,
		"health": 750,
		"rotate_toward_player": true,
		"detectionradius": 500
	},
	"Enemy5": {
		"type": "Enemy5",
		"position": Vector2( 0, 0),
		"behaviour": "pursuer",
		"weapons": ["res://Scenes/Enemy_Weapons/CircleGun.tscn"],
		"speed": 300,
		"health": 750,
		"rotate_toward_player": true,
		"detectionradius": 500
	},
	"Mothership1": {
		"type": "Mothership1",
		"position": Vector2( 0, 0),
		"behaviour": "mothership",
		"weapons": ["res://Scenes/Enemy_Weapons/Pistol.tscn"],
		"speed": 10,
		"health": 2000,
		"rotate_toward_player": false,
		"detectionradius": 1000
	},
	"Mothership2": {
		"type": "Mothership2",
		"position": Vector2( 0, 0),
		"behaviour": "mothership",
		"weapons": ["res://Scenes/Enemy_Weapons/Shotgun.tscn"],
		"speed": 20,
		"health": 1000,
		"rotate_toward_player": false,
		"detectionradius": 1000
	}
}
