extends GPUParticles2D

@export var follower: Node2D

func _physics_process(_delta: float) -> void:
	if follower != null:
		global_position = follower.global_position
	if follower == null:
		emitting = false
