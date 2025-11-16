extends Node
var enemy
var charge_timer = 0.0

func update(delta):
	if not enemy.player:
		return
	charge_timer -= delta
	if charge_timer <= 0.0:
		var dir = (enemy.player.global_position - enemy.global_position).normalized()
		enemy.velocity = dir * (enemy.speed * 3)
		charge_timer = 3.0
	enemy.move_and_slide()
