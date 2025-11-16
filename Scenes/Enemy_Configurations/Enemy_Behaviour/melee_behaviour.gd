extends Node
var enemy

func update(delta):
	if not enemy.player:
		return
	var dir = (enemy.player.global_position - enemy.global_position).normalized()
	enemy.velocity = dir * enemy.speed
	enemy.move_and_slide()
