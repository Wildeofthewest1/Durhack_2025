extends Node2D

var emitting := false
@onready var particle1 := $Forward
@onready var particle2 := $Backward
@onready var particle3 := $explosion
@onready var particle4 := $Forward2


func _physics_process(_delta: float) -> void:
	if emitting == true:
		particle1.emitting = true
		particle2.emitting = true
		particle3.emitting = true
		particle4.emitting = true
		
		emitting = false
		var timer := Timer.new()
		add_child(timer)
		timer.wait_time = 10.0
		timer.one_shot = true
		timer.start()
		timer.connect("timeout", _on_timer_timeout)


func _on_timer_timeout() -> void:
	queue_free()
