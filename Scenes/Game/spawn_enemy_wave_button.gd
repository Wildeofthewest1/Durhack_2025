extends Button

@export var wave_set_name: String = "waves1"

func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var game_viewport := get_tree().get_first_node_in_group("GameViewport") as SubViewport
	if game_viewport == null:
		push_error("Button: GameViewport not found")
		return

	var size := game_viewport.size

	WaveManager.start_wave_set(
		"Waves2",
		Vector2(size.x * 0.5, size.y * 0.5), # offscreen right (SubViewport space)
		true,
		1000.0,
		true
	)

	print("pressed wave start")
