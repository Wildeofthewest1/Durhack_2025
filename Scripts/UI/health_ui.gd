extends Control

@export var max_health: int = 20
@export var square_size: int = 8
@export var spacing: int = 2
@export var squares_per_row: int = 10
@export var health_color: Color = Color.GREEN
@export var empty_color: Color = Color(0.2, 0.2, 0.2, 1.0)

var current_health: int = 20
var square_positions: Array[Vector2] = []

func _ready() -> void:
	current_health = max_health
	_calculate_square_positions()

func _calculate_square_positions() -> void:
	square_positions.clear()
	var x_offset: int = 8
	var y_offset: int = 8
	
	for i: int in range(max_health):
		var row: int = i / squares_per_row
		var col: int = i % squares_per_row
		var x: float = float(x_offset + col * (square_size + spacing))
		var y: float = float(y_offset + row * (square_size + spacing))
		square_positions.append(Vector2(x, y))

func _draw() -> void:
	for i: int in range(max_health):
		var pos: Vector2 = square_positions[i]
		var color: Color = health_color if i < current_health else empty_color
		draw_rect(Rect2(pos, Vector2(square_size, square_size)), color)

func set_health(new_health: int) -> void:
	current_health = clampi(new_health, 0, max_health)
	queue_redraw()

func take_damage(damage: int) -> void:
	set_health(current_health - damage)

func heal(amount: int) -> void:
	set_health(current_health + amount)

func get_current_health() -> int:
	return current_health
