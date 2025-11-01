extends Camera2D

var actual_cam_pos : Vector2
@onready var player : CharacterBody2D = $"../PlayerContainer/Player"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	actual_cam_pos = actual_cam_pos.lerp(player.position,delta*1)
	var cam_subpixel_offset = actual_cam_pos.round() - actual_cam_pos
	get_parent().get_parent().get_parent().material.set_shader_parameter("cam_offset",cam_subpixel_offset)
	global_position = actual_cam_pos.round()
