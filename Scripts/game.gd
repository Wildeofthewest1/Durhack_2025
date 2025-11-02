extends Node2D

func _ready():
	print("Game script ready")
<<<<<<< HEAD
	var spawner = $PlanetSpawner
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
=======
>>>>>>> parent of 8500381 (f)


func _on_spawn_enemy_button_pressed() -> void:
	var player = $PlayerContainer/Player
	var spawner = $EnemySpawner

	var min_distance: float = 200.0
	var max_distance: float = 400.0

	var angle: float = randf() * TAU
	var distance: float = randf_range(min_distance, max_distance)

	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * distance
	var spawn_position: Vector2 = player.global_position + offset  # <-- typed
	
	
	print("button pressed")
	spawner.spawn_enemy(
	"Enemy1",
	spawn_position,
	"ranged",
	["res://Scenes/Enemy_Weapons/pistol.tscn"],
	150.0,
	120
)
