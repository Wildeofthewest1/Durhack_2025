extends Camera2D

var camera_speed = 20
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("scroll_up"):
		zoom += Vector2(0.02, 0.02)
	if Input.is_action_pressed("scroll_down"):
		if zoom.x > 0.02:
			zoom -= Vector2(0.02, 0.02)
	if Input.is_action_pressed("w"):
		position += camera_speed * Vector2.UP	
	if Input.is_action_pressed("a"):
		position += camera_speed * Vector2.LEFT	
	if Input.is_action_pressed("s"):
		position += camera_speed * Vector2.DOWN	
	if Input.is_action_pressed("d"):
		position += camera_speed * Vector2.RIGHT	
	
