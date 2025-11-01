extends Node2D

@export var base_enemy_scene: PackedScene = preload("res://Scenes/basic_enemy.tscn")
@onready var enemies_container: Node = get_parent().get_node("Enemies")

@export var enemy_behaviours: Dictionary = {
	"melee": {"speed": 120.0, "health": 100},
	"ranged": {"speed": 80.0, "health": 70},
	"charger": {"speed": 200.0, "health": 120}
}

func spawn_enemy(position: Vector2) -> void:
	if base_enemy_scene == null:
		push_error("No base enemy scene assigned!")
		return

	var behaviour_keys: Array = enemy_behaviours.keys()
	var random_behaviour: String = behaviour_keys[randi() % behaviour_keys.size()]
	var behaviour_data: Dictionary = enemy_behaviours[random_behaviour]

	var enemy: CharacterBody2D = base_enemy_scene.instantiate()
	enemy.position = position

	if "behaviour_type" in enemy:
		enemy.behaviour_type = random_behaviour

	for key in behaviour_data.keys():
		if key in enemy:
			enemy.set(key, behaviour_data[key])

	enemies_container.add_child(enemy)
	print("Spawned", random_behaviour, "enemy at", position)
