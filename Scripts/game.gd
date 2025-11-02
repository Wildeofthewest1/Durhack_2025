extends Node2D

# Track which enemy to spawn next
var enemy_types = ["Enemy1", "Enemy2", "Enemy3", "Enemy4"]
var current_enemy_index: int = 0

func _ready() -> void:
	print("Game script ready")
	var spawner = $PlanetSpawner
	spawner.spawn_planet(
		Vector2(0, 30),     # position
		Vector2(0, 0),      # velocity
		10000,                # mass
		10                   # radius
	)
	spawner.spawn_planet(
		Vector2(0, -30),     # position
		Vector2(0, 0),      # velocity
		10000,                # mass
		10                   # radius
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
		120
	)

	# Move to the next enemy type, wrapping around
	current_enemy_index = (current_enemy_index + 1) % enemy_types.size()
