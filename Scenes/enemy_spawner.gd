extends Node2D

@export var base_enemy_scene: PackedScene = preload("res://Scenes/basic_enemy.tscn")
@onready var enemies_container = get_parent().get_node("Enemies")

@export var enemy_behaviours := {
	"melee": {"speed": 120.0, "health": 100},
	"ranged": {"speed": 80.0, "health": 70},
	"charger": {"speed": 200.0, "health": 120}
}

func spawn_enemy(position: Vector2):
	var behaviour_keys = enemy_behaviours.keys()
	var random_behaviour = behaviour_keys[randi() % behaviour_keys.size()]
	var behaviour_data = enemy_behaviours[random_behaviour]

	var enemy = base_enemy_scene.instantiate()
	enemy.position = position
	enemy.behaviour_type = random_behaviour

	for key in behaviour_data.keys():
		if enemy.has_variable(key):
			enemy.set(key, behaviour_data[key])

	enemies_container.add_child(enemy)
	print("Spawned enemy:", random_behaviour, "at", position)
