extends CharacterBody2D
class_name Player

@export var initial_velocity: Vector2 = Vector2.ZERO

@onready var movement_component: PlayerMovement = $Movement
@onready var health_component: PlayerHealth = $Health

func _ready() -> void:
	print("[Player] ready")
	velocity = initial_velocity
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	up_direction = Vector2.RIGHT

func take_damage(amount: int) -> void:
	if health_component != null:
		health_component.take_damage(amount)

func get_fuel_ratio() -> float:
	if movement_component == null:
		return 0.0
	return movement_component.get_fuel_ratio()
