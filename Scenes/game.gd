extends Node2D

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
	spawner.spawn_enemy(spawn_position)
