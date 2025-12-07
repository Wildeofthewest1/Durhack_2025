extends CharacterBody2D

@export var faceplayer: bool = false
@export var speed: float = 100.0
@export var health: int = 100

@export var rotation_speed: float = 3.0
@export var detectionradius: float = 1000.0

# Death particles
@export var death_particles_scene: PackedScene

var behaviour_type: String = "default"
var behaviour: Node = null
var player: Node2D
var spawner: Node
var escorts: int = 0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	spawner = get_tree().get_first_node_in_group("EnemySpawner")
	
	assign_behaviour()
	attach_weapons()

func take_damage(amount: int) -> void:
	health -= amount
	print("%s took %d damage, remaining health: %d" % [name, amount, health])

	if has_node("Sprite2D"):
		var sprite: Sprite2D = $Sprite2D
		_flash_red(sprite)

	if health <= 0:
		die()

func _flash_red(sprite: Sprite2D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0), 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.1)

func die() -> void:
	print("%s has died" % name)
	_spawn_death_particles()
	queue_free()

func _spawn_death_particles() -> void:
	if death_particles_scene == null:
		return

	var particles_node: Node2D = death_particles_scene.instantiate() as Node2D

	# Prefer spawning in the same parent so it stays in the same layer/space
	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene

	parent_node.add_child(particles_node)
	particles_node.emitting = true
	particles_node.global_position = global_position

func assign_behaviour() -> void:
	var behaviour_paths: Dictionary = {
		"melee": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/melee_behaviour.gd",
		"ranged": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/ranged_behaviour.gd",
		"pursuer": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/pursuer_behaviour.gd",
		"charger": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/charger_behaviour.gd",
		"mothership": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/mothership_behaviour.gd",
	}

	var script_path: String = behaviour_paths.get(behaviour_type, behaviour_paths["ranged"])
	var behaviour_script: Script = load(script_path)

	if behaviour_script == null:
		push_error("Failed to load behaviour script: " + script_path)
		return

	behaviour = behaviour_script.new()
	behaviour.enemy = self


func attach_weapons() -> void:
	var weapon_scenes: Array = [
		preload("res://Scenes/Enemy_Weapons/Pistol.tscn"),
		preload("res://Scenes/Enemy_Weapons/Shotgun.tscn")
	]

	if not has_node("WeaponSlots"):
		push_warning("Enemy has no WeaponSlots node: " + str(name))
		return

	var weapon_slots: Array = $WeaponSlots.get_children()

	if not has_node("Weapons"):
		var weapons_node: Node2D = Node2D.new()
		weapons_node.name = "Weapons"
		add_child(weapons_node)

	for i in range(weapon_slots.size()):
		var weapon_scene: PackedScene = weapon_scenes[i % weapon_scenes.size()]
		var weapon: Node2D = weapon_scene.instantiate() as Node2D

		weapon.position = (weapon_slots[i] as Node2D).position
		$Weapons.add_child(weapon)


func _physics_process(delta: float) -> void:
	if player != null and faceplayer:
		var direction: Vector2 = player.global_position - global_position

		var desired_angle: float = direction.angle() + deg_to_rad(-90.0)
		rotation = lerp_angle(rotation, desired_angle, delta * rotation_speed)

	if behaviour != null:
		behaviour.update(delta)
