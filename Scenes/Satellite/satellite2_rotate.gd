extends Sprite2D

@export var rot: float = 0.03

func _physics_process(delta: float) -> void:
	global_rotation += rot*delta
