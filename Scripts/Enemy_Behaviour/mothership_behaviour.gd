extends Node
var enemy: CharacterBody2D

func update(delta: float) -> void:
	if not enemy or not enemy.player:
		return

	var player_pos = enemy.player.global_position
	var distance = enemy.global_position.distance_to(player_pos)

	# 🔹 Chase only if within detection radius
	if distance <= enemy.detectionradius:
		if distance > 150:
			var dir = (player_pos - enemy.global_position).normalized()
			enemy.velocity = dir * enemy.speed
		else:
			enemy.velocity = Vector2.ZERO
	else:
		enemy.velocity = Vector2.ZERO

	enemy.move_and_slide()
