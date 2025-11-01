extends Node
var enemy
var cooldown = 0.0

func update(delta):
	if not enemy.player:
		return
	var distance = enemy.global_position.distance_to(enemy.player.global_position)
	if distance > 200:
		var dir = (enemy.player.global_position - enemy.global_position).normalized()
		enemy.velocity = dir * enemy.speed
	else:
		enemy.velocity = Vector2.ZERO
		cooldown -= delta
		if cooldown <= 0.0:
			shoot()
			cooldown = 2.0
	enemy.move_and_slide()

func shoot():
	print("Ranged enemy shooting at player")
