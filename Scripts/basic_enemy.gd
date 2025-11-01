extends CharacterBody2D

@export var speed: float = 100.0
@export var detection_radius: float = 300.0

var player: Node2D

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if not player:
		return

	var direction = player.global_position - global_position
	var distance = direction.length()

	if distance < detection_radius:
		look_at(player.global_position)
		rotation_degrees += 90  # rotate sprite so it faces the player correctly
		velocity = direction.normalized() * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
