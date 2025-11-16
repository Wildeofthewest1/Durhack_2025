extends Node2D

@onready var enemies_container: Node = get_parent().get_node("Enemies")

@export var enemy_scenes: Dictionary = {
	"Enemy1": "res://Scenes/Enemy_Configurations/Enemy1.tscn",
	"Enemy2": "res://Scenes/Enemy_Configurations/Enemy2.tscn",
	"Enemy3": "res://Scenes/Enemy_Configurations/Enemy3.tscn",
	"Enemy4": "res://Scenes/Enemy_Configurations/Enemy4.tscn",
	"Mothership1": "res://Scenes/Enemy_Configurations/Mothership1.tscn",
	"Mothership2": "res://Scenes/Enemy_Configurations/Mothership2.tscn"
}

func spawn_enemy(
	enemy_type: String,
	position: Vector2,
	behaviour_type: String = "ranged",
	weapons: Array = [],
	speed: float = 100.0,
	health: int = 100,
	faceplayer: bool = true,
	detectionradius: float = 1000
) -> void:
	# Ensure the type exists
	if not enemy_scenes.has(enemy_type):
		push_error("Unknown enemy type: " + enemy_type)
		return

	# Load the enemy scene
	var enemy_scene: PackedScene = load(enemy_scenes[enemy_type])
	if enemy_scene == null:
		push_error("Could not load enemy scene for type: " + enemy_type)
		return

	# Instantiate
	var enemy: CharacterBody2D = enemy_scene.instantiate()
	enemy.position = position

	# Apply core properties
	if "behaviour_type" in enemy:
		enemy.behaviour_type = behaviour_type
	if "speed" in enemy:
		enemy.speed = speed
	if "health" in enemy:
		enemy.health = health
	if "faceplayer" in enemy:
		enemy.faceplayer = faceplayer
	if "detectionradius" in enemy:
		enemy.detectionradius = detectionradius

	# Add to world
	enemies_container.add_child(enemy)

	# Attach weapons if any
	if not weapons.is_empty():
		_attach_weapons(enemy, weapons)

	print("Spawned", enemy_type, "with behaviour", behaviour_type, "at", position)


func _attach_weapons(enemy: CharacterBody2D, weapon_paths: Array) -> void:
	if not enemy.has_node("WeaponSlots"):
		push_warning("Enemy scene has no WeaponSlots node: " + str(enemy.name))
		return

	var slots = enemy.get_node("WeaponSlots").get_children()

	# Ensure Weapons container exists
	var weapons_node: Node2D
	if enemy.has_node("Weapons"):
		weapons_node = enemy.get_node("Weapons")
	else:
		weapons_node = Node2D.new()
		weapons_node.name = "Weapons"
		enemy.add_child(weapons_node)

	# 🧹 Clear any old weapons before adding new ones
	for child in weapons_node.get_children():
		child.queue_free()

	for i in range(slots.size()):
		var weapon_path = weapon_paths[i % weapon_paths.size()]
		print("Attempting to attach weapon:", weapon_path)
		
		var weapon_scene = load(weapon_path)
		if weapon_scene == null:
			push_error("Could not load weapon: " + weapon_path)
			continue

		var weapon = weapon_scene.instantiate()
		print("Instantiated weapon:", weapon)

		weapon.position = slots[i].position
		if "owner_enemy" in weapon:
			weapon.owner_enemy = enemy

		var base_name = weapon_path.get_file().get_basename()
		weapon.name = "%s%d" % [base_name, i + 1]

		print("Adding weapon:", weapon.name, "to", enemy.name)
		weapons_node.add_child(weapon)
