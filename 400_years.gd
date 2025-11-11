extends Label


var timevalue = 400.0
@export var timescale = 0.2 #in seconds
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Timer.wait_time = timescale
	text = str(snapped(timevalue,0.1)) + " Years Until the Invasion" 
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	text = str(snapped(timevalue,0.1)) + " Years Until the Invasion" 
	

func _on_timer_timeout() -> void:
	timevalue -= 0.1
