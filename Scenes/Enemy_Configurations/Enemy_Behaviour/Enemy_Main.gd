extends CharacterBody2D

@export var faceplayer: bool = false
@export var speed: float = 100.0
@export var health: int = 100

@export var rotation_speed: float = 3.0
@export var detectionradius: float = 1000

# Escort system (for motherships only)
@export var escort_type: String = "Enemy1"
@export var escort_count: int = 2
@export var escort_offset: float = 150.0
@export var escort_respawn_delay: float = 3.0

var behaviour_type: String = "default"
var behaviour: Node = null
var player: Node2D
var spawner: Node
var escorts: int = 0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
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
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0, 0), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)


func die() -> void:
	print("%s has died" % name)
	queue_free()

func assign_behaviour() -> void:
	var behaviour_paths = {
		"melee": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/melee_behaviour.gd",
		"ranged": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/ranged_behaviour.gd",
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
	var weapon_scenes = [
		preload("res://Scenes/Enemy_Weapons/Pistol.tscn"),
		preload("res://Scenes/Enemy_Weapons/Shotgun.tscn")
	]

	if not has_node("WeaponSlots"):
		push_warning("Enemy has no WeaponSlots node: " + str(name))
		return

	var weapon_slots = $WeaponSlots.get_children()

	if not has_node("Weapons"):
		var weapons_node = Node2D.new()
		weapons_node.name = "Weapons"
		add_child(weapons_node)

	for i in range(weapon_slots.size()):
		var weapon_scene = weapon_scenes[i % weapon_scenes.size()]
		var weapon = weapon_scene.instantiate()

		weapon.position = weapon_slots[i].position
		#weapon.owner_enemy = self
		$Weapons.add_child(weapon)


func _physics_process(delta: float) -> void:
	if player and faceplayer:
		var direction: Vector2 = player.global_position - global_position

		var desired_angle: float = direction.angle() + deg_to_rad(-90)
		rotation = lerp_angle(rotation, desired_angle, delta * rotation_speed)

	if behaviour:
		behaviour.update(delta)
	
	#if not faceplayer:
	#	_check_escort_status()


func _spawn_escort() -> void:
	if not spawner or health <= 0:
		return

	# Stop if we already have enough escorts
	if escorts >= escort_count:
		return

	var angle = TAU / escort_count
	var offset = Vector2(cos(angle), sin(angle)) * escort_offset
	var spawn_position = global_position + offset

	var escort = spawner.spawn_enemy(
		escort_type,                            # enemy_type
		spawn_position,                         # position
		"ranged",                               # behaviour_type
		["res://Scenes/Enemy_Weapons/Shotgun.tscn"], # weapons
		150.0,                                  # speed
		120,                                    # health
		true,                                   # rotate_toward_player
		500                                     # detectionradius
	)

		
func _check_escort_status() -> void:
	# Spawn replacements until we reach escort_count
	if escorts < escort_count:
		print(escorts)
		_spawn_escort()
		escorts += 1
		
