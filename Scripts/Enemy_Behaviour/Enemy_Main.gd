extends CharacterBody2D

@export var speed: float = 100.0
@export var health: int = 100
var behaviour_type: String = "default"
var behaviour: Node = null
var player: Node2D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	assign_behaviour()

func assign_behaviour():
	var behaviour_paths = {
		"melee": "res://Scripts/EnemyBehaviours/melee_behaviour.gd",
		"ranged": "res://Scripts/EnemyBehaviours/ranged_behaviour.gd",
		"charger": "res://Scripts/EnemyBehaviours/charger_behaviour.gd",
		"default": "res://Scripts/EnemyBehaviours/default_behaviour.gd"
	}

	var script_path = behaviour_paths.get(behaviour_type, behaviour_paths["default"])
	behaviour = load(script_path).new()
	behaviour.enemy = self

func _physics_process(delta):
	if behaviour:
		behaviour.update(delta)
