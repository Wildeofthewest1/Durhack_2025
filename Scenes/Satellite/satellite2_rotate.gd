extends Node2D

@export var rot: float = 0.03

func _ready() -> void:
	global_rotation += randf()

func _physics_process(delta: float) -> void:
	global_rotation += rot*delta
