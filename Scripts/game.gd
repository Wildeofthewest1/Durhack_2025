extends Node2D

# Track which enemy to spawn next
var enemy_types = ["Enemy1", "Enemy2", "Enemy3", "Enemy4", "Mothership1", "Mothership2"]
var current_enemy_index: int = 0

func _ready() -> void:
	print("Game script ready")
	var spawner = $PlanetSpawner
	var spawner2 = $EnemySpawner
	var planets = {
		"Star": {
			"position": Vector2(883, 540),
			"velocity": Vector2(1, 0),
			"mass": 100,
			"radius": 120,
			"colour": Color(0.9, 0.79499996, 0, 1)
		},
		"Planet1": {
			"position": Vector2(1250, 565),
			"velocity": Vector2(0, -1),
			"mass": 10,
			"radius": 40,
			"colour": Color(0, 0.6222091, 0.7230942, 1)
		},
		"Planet2": {
			"position": Vector2(3013, -1200.9998),
			"velocity": Vector2(1, 0) * 300,
			"mass": 10,
			"radius": 30,
			"colour": Color(0.74110955, 0.46996802, 0.0071272017, 1)
		},
		"Planet3": {
			"position": Vector2(3013, -1200.9998),
			"velocity": Vector2(1, 0),
			"mass": 10,
			"radius": 20,
			"colour": Color(0.8195138, 0.32531074, 0, 1)
		},
		"Planet4": {
			"position": Vector2(2205, 1030),
			"velocity": Vector2(0, 1),
			"mass": 10,
			"radius": 20,
			"colour": Color(7.2196127e-07, 0.6905073, 0.30647963, 1)
		},
		"Planet5": {
			"position": Vector2(851, 751),
			"velocity": Vector2(0, 1),
			"mass": 10,
			"radius": 20,
			"colour": Color(0.5733334, 0.19999999, 1, 1)
		},
		"Planet6": {
			"position": Vector2(-133, -694),
			"velocity": Vector2(1, 0),
			"mass": 10,
			"radius": 20,
			"colour": Color(0.81310487, 0.4070109, 0.27311918, 1)
		},
	}
# Loop through and spawn each one
	for name in planets.keys():
		var p = planets[name]
		spawner.spawn_planet(
			p["position"],
			p["velocity"],
			p["mass"],
			p["radius"],
			p["colour"]
		)
	# Example: inside your spawner or game controller
	var enemies = {
		"Mothership2": {
			"type": "Mothership2",
			"position": Vector2(500, 300),
			"behaviour": "mothership",
			"weapons": ["res://Scenes/Enemy_Weapons/shotgun.tscn"],
			"speed": 20,
			"health": 1000,
			"rotate_toward_player": false,
			"detectionradius": 1000
		},
		"Enemy1": {
			"type": "Enemy1",
			"position": Vector2(-800, 400),
			"behaviour": "ranged",
			"weapons": ["res://Scenes/Enemy_Weapons/pistol.tscn"],
			"speed": 150,
			"health": 80,
			"rotate_toward_player": true,
			"detectionradius": 500
		},
		"Enemy2": {
			"type": "Enemy2",
			"position": Vector2(-1000, 200),
			"behaviour": "ranged",
			"weapons": ["res://Scenes/Enemy_Weapons/shotgun.tscn"],
			"speed": 120,
			"health": 100,
			"rotate_toward_player": true,
			"detectionradius": 500
		},
		"Enemy3": {
			"type": "Enemy3",
			"position": Vector2(-1000, 200),
			"behaviour": "ranged",
			"weapons": ["res://Scenes/Enemy_Weapons/pistol.tscn"],
			"speed": 100,
			"health": 200,
			"rotate_toward_player": true,
			"detectionradius": 500
		}
	}
	for name2 in enemies.keys():
		var e = enemies[name2]
		spawner2.spawn_enemy(
			e["type"],
			e["position"],
			e["behaviour"],
			e["weapons"],
			e["speed"],
			e["health"],
			e["rotate_toward_player"],
			e["detectionradius"]
		)

	
func _on_spawn_enemy_button_pressed() -> void:
	var player = $PlayerContainer/Player
	var spawner = $EnemySpawner

	var min_distance: float = 200.0
	var max_distance: float = 400.0

	var angle: float = randf() * TAU
	var distance: float = randf_range(min_distance, max_distance)
	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * distance
	var spawn_position: Vector2 = player.global_position + offset

	# Pick the next enemy type in the cycle
	var enemy_type = enemy_types[current_enemy_index]
	print("Spawning:", enemy_type)

	# Call your spawner
	spawner.spawn_enemy(
		enemy_type,
		spawn_position,
		"ranged",
		["res://Scenes/Enemy_Weapons/shotgun.tscn"],
		150.0,
		120,
		false,
		100
	)

	# Move to the next enemy type, wrapping around
	current_enemy_index = (current_enemy_index + 1) % enemy_types.size()
