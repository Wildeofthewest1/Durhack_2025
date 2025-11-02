extends CharacterBody2D

@export var speed: float = 100.0
@export var health: int = 100
var behaviour_type: String = "default"
var behaviour: Node = null
var player: Node2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	assign_behaviour()
	attach_weapons()

func assign_behaviour() -> void:
	var behaviour_paths = {
		"melee": "res://Scripts/Enemy_Behaviour/melee_behaviour.gd",
		"ranged": "res://Scripts/Enemy_Behaviour/ranged_behaviour.gd",
		"charger": "res://Scripts/Enemy_Behaviour/charger_behaviour.gd"
	}

	var script_path: String = behaviour_paths.get(behaviour_type, behaviour_paths["ranged"])
	var behaviour_script: Script = load(script_path)

	if behaviour_script == null:
		push_error("Failed to load behaviour script: " + script_path)
		return

	behaviour = behaviour_script.new()
	behaviour.enemy = self


func attach_weapons() -> void:
	# ⚠️ Weapon scenes must be .tscn files, not .gd
	var weapon_scenes = [
		preload("res://Scenes/Enemy_Weapons/pistol.tscn"),
		preload("res://Scenes/Enemy_Weapons/shotgun.tscn")
	]

	if not has_node("WeaponSlots"):
		push_warning("Enemy has no WeaponSlots node: " + str(name))
		return

	var weapon_slots = $WeaponSlots.get_children()

	# Create a container if missing
	if not has_node("Weapons"):
		var weapons_node = Node2D.new()
		weapons_node.name = "Weapons"
		add_child(weapons_node)

	for i in range(weapon_slots.size()):
		var weapon_scene = weapon_scenes[i % weapon_scenes.size()]
		var weapon = weapon_scene.instantiate()

		weapon.global_position = weapon_slots[i].global_position
		#weapon.owner_enemy = self
		$Weapons.add_child(weapon)


func _physics_process(delta: float) -> void:
	if player:
		var direction: Vector2 = player.global_position - global_position
		rotation = direction.angle() + deg_to_rad(-90)

	if behaviour:
		behaviour.update(delta)
