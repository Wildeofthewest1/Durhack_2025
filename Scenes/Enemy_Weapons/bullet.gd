extends Area2D

@export var initial_speed: float = 300
@export var speed: float = initial_speed
@export var lifetime: float = 3
@export var deceleration: float = 0.0

@onready var sprite = $Sprite2D

var direction: Vector2 = Vector2.RIGHT   # <- ensures the property exists

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	speed = initial_speed
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if deceleration > 0.0:
		speed = max(speed - deceleration * delta, 0.0)
		
	if initial_speed > 0.0 and sprite:
		var alpha = clamp(speed / initial_speed, 0, 1.0)
		sprite.modulate.a = alpha

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		queue_free()
