extends Button

@export var wave_set_name: String = "waves1"
@export var spawn_position: Vector2 = Vector2(1000,100)

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	WaveManager.start_wave_set(wave_set_name, spawn_position)
	print("pressed wave start")
