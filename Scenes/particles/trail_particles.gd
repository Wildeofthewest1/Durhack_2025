extends GPUParticles2D

@export var follower: Node2D

func _ready():
		var timer := Timer.new()
		add_child(timer)
		timer.wait_time = 5.0
		timer.one_shot = true
		timer.start()
		timer.connect("timeout", _on_timer_timeout)

func _on_timer_timeout() -> void:
	queue_free()

func _physics_process(_delta: float) -> void:
	if follower != null:
		global_position = follower.global_position
	if follower == null:
		emitting = false
