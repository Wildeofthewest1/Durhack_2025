extends Label


var timevalue = 400
@export var timescale = 2 #in seconds
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Timer.wait_time = timescale
	text = "Years Until Invasion: " + str(timevalue)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	text = "Years Until Invasion: " + str(timevalue)
	

func _on_timer_timeout() -> void:
	timevalue -= 1
