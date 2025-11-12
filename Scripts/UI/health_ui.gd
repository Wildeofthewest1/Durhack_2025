extends Control

@export var max_health: int = 200
@export var square_size: int = 8
@export var spacing: int = 2
@export var squares_per_row: int = 10
@export var health_per_square: int = 10
@export var health_color: Color = Color.GREEN
@export var empty_color: Color = Color(0.2, 0.2, 0.2, 1.0)

var current_health: int = 0
var square_positions: Array[Vector2] = []
var square_count: int = 0
var player: Node = null

func _ready() -> void:
	# Cache player and initial health
	player = get_tree().get_first_node_in_group("player")
	if player != null:
		# If you have player.max_health, use that instead:
		max_health = int(player.get_child(1).health)
	current_health = max_health

	# How many squares total (ceil in case max_health is not multiple of health_per_square)
	var total: float = float(max_health) / float(health_per_square)
	square_count = int(ceil(total))

	_calculate_square_positions()
	queue_redraw()

func _process(delta: float) -> void:
	if player != null:
		var new_health: int = int(player.get_child(1).health)
		if new_health != current_health:
			current_health = new_health
			queue_redraw()

func _calculate_square_positions() -> void:
	square_positions.clear()
	var x_offset: int = 8
	var y_offset: int = 8

	for i: int in range(square_count):
		var row: int = i / squares_per_row
		var col: int = i - row * squares_per_row
		var x: float = float(x_offset + col * (square_size + spacing))
		var y: float = float(y_offset + row * (square_size + spacing))
		square_positions.append(Vector2(x, y))

func _draw() -> void:
	for i: int in range(square_count):
		var pos: Vector2 = square_positions[i]

		var square_start_hp: int = i * health_per_square
		var square_end_hp: int = square_start_hp + health_per_square

		# Always draw the empty square background
		draw_rect(Rect2(pos, Vector2(square_size, square_size)), empty_color)

		# Decide how much of this square is filled
		if current_health >= square_end_hp:
			# Full square
			draw_rect(Rect2(pos, Vector2(square_size, square_size)), health_color)
		elif current_health > square_start_hp:
			# Partial fill for this square
			var filled_hp: float = float(current_health - square_start_hp)
			var fraction: float = filled_hp / float(health_per_square)
			if fraction > 0.0:
				if fraction > 1.0:
					fraction = 1.0
				var fill_width: float = float(square_size) * fraction
				var fill_size: Vector2 = Vector2(fill_width, float(square_size))
				draw_rect(Rect2(pos, fill_size), health_color)
		# else: square is completely empty (only empty_color background)

func set_health(new_health: int) -> void:
	current_health = clampi(new_health, 0, max_health)
	queue_redraw()

func take_damage(damage: int) -> void:
	set_health(current_health - damage)

func heal(amount: int) -> void:
	set_health(current_health + amount)

func get_current_health() -> int:
	return current_health
