extends Control
class_name HealthShieldUI

@export var max_health: int = 200
@export var square_size: int = 8
@export var spacing: int = 2
@export var squares_per_row: int = 10
@export var health_per_square: int = 10
@export var health_color: Color = Color.GREEN
@export var empty_color: Color = Color(0.2, 0.2, 0.2, 1.0)

# --- SHIELD (horizontal bar) ---
@export var max_shield: int = 100
@export var shield_color: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var shield_empty_color: Color = Color(0.12, 0.12, 0.18, 1.0)
@export var shield_bar_height: int = 6
@export var shield_bar_gap: int = 6          # distance from health block (to the right)
@export var shield_bar_align_y: int = 0      # 0=center, -1=top, +1=bottom

# Data
var current_health: int = 0
var current_shield: int = 0

var square_positions: Array[Vector2] = []
var square_count: int = 0

var player: Node = null
var _ph: Node = null

# Layout cache
var _grid_origin: Vector2 = Vector2.ZERO
var _grid_size: Vector2 = Vector2.ZERO

# Track max updates
var _last_max_health: int = 0
var _last_max_shield: int = 0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	_ph = null
	if player != null:
		# Your setup: PlayerHealth is child(1)
		_ph = player.get_child(1)

	_pull_initial_values()
	_rebuild_health_layout()
	queue_redraw()

func _process(delta: float) -> void:
	if player == null:
		return
	if _ph == null:
		_ph = player.get_child(1)
		if _ph == null:
			return

	var new_health: int = current_health
	var new_shield: int = current_shield
	var new_max_health: int = max_health
	var new_max_shield: int = max_shield

	if "health" in _ph:
		new_health = int(_ph.health)
	if "shield" in _ph:
		new_shield = int(_ph.shield)
	if "max_health" in _ph:
		new_max_health = int(_ph.max_health)
	if "max_shield" in _ph:
		new_max_shield = int(_ph.max_shield)

	var layout_changed: bool = false

	if new_max_health != _last_max_health:
		max_health = new_max_health
		_last_max_health = new_max_health
		layout_changed = true

	if new_max_shield != _last_max_shield:
		max_shield = new_max_shield
		_last_max_shield = new_max_shield
		# shield bar width is computed in _draw(), so no layout recompute needed
		# unless you want to reposition it based on its own width (we don't)
		# layout_changed = true

	if layout_changed:
		_rebuild_health_layout()

	var changed: bool = false
	if new_health != current_health:
		current_health = new_health
		changed = true
	if new_shield != current_shield:
		current_shield = new_shield
		changed = true

	if layout_changed or changed:
		queue_redraw()

func _pull_initial_values() -> void:
	if _ph != null:
		if "max_health" in _ph:
			max_health = int(_ph.max_health)
		if "max_shield" in _ph:
			max_shield = int(_ph.max_shield)

		if "health" in _ph:
			current_health = int(_ph.health)
		else:
			current_health = max_health

		if "shield" in _ph:
			current_shield = int(_ph.shield)
		else:
			current_shield = max_shield
	else:
		current_health = max_health
		current_shield = max_shield

	_last_max_health = max_health
	_last_max_shield = max_shield

func _rebuild_health_layout() -> void:
	var total: float = float(max_health) / float(health_per_square)
	square_count = int(ceil(total))
	_calculate_square_positions()

func _calculate_square_positions() -> void:
	square_positions.clear()

	var x_offset: int = 8
	var y_offset: int = 8

	_grid_origin = Vector2(float(x_offset), float(y_offset))

	for i: int in range(square_count):
		var row: int = i / squares_per_row
		var col: int = i - row * squares_per_row
		var x: float = float(x_offset + col * (square_size + spacing))
		var y: float = float(y_offset + row * (square_size + spacing))
		square_positions.append(Vector2(x, y))

	var rows: int = int(ceil(float(square_count) / float(squares_per_row)))
	var cols: int = min(squares_per_row, square_count)

	var w: float = float(cols * square_size + (cols - 1) * spacing)
	var h: float = float(rows * square_size + (rows - 1) * spacing)
	_grid_size = Vector2(w, h)

func _draw() -> void:
	_draw_health_squares()
	_draw_shield_bar_horizontal()

func _draw_health_squares() -> void:
	for i: int in range(square_count):
		var pos: Vector2 = square_positions[i]

		var square_start_hp: int = i * health_per_square
		var square_end_hp: int = square_start_hp + health_per_square

		draw_rect(Rect2(pos, Vector2(float(square_size), float(square_size))), empty_color)

		if current_health >= square_end_hp:
			draw_rect(Rect2(pos, Vector2(float(square_size), float(square_size))), health_color)
		elif current_health > square_start_hp:
			var filled_hp: float = float(current_health - square_start_hp)
			var fraction: float = filled_hp / float(health_per_square)
			if fraction > 1.0:
				fraction = 1.0
			if fraction > 0.0:
				var fill_width: float = float(square_size) * fraction
				draw_rect(Rect2(pos, Vector2(fill_width, float(square_size))), health_color)

func _amount_to_pixel_width(amount: int) -> float:
	var a: int = max(amount, 0)

	var full_chunks: int = a / health_per_square
	var rem: int = a - full_chunks * health_per_square

	var w: float = 0.0

	# Full squares
	if full_chunks > 0:
		w += float(full_chunks) * float(square_size)
		w += float(max(full_chunks - 1, 0)) * float(spacing)

	# Partial square (needs a gap before it if there were full squares)
	if rem > 0:
		if full_chunks > 0:
			w += float(spacing)
		var frac: float = float(rem) / float(health_per_square)
		w += float(square_size) * frac

	return w

func _draw_shield_bar_horizontal() -> void:
	var bar_x: float = _grid_origin.x + _grid_size.x + float(shield_bar_gap)

	var bar_y: float = _grid_origin.y
	if shield_bar_align_y == 0:
		bar_y = _grid_origin.y + (_grid_size.y - float(shield_bar_height)) * 0.5
	elif shield_bar_align_y > 0:
		bar_y = _grid_origin.y + (_grid_size.y - float(shield_bar_height))
	else:
		bar_y = _grid_origin.y

	var bar_h: float = float(shield_bar_height)

	# Total width equals "max_shield" converted to the same square+gap pixel units
	var total_w: float = _amount_to_pixel_width(max_shield)
	if total_w < 1.0:
		total_w = 1.0

	draw_rect(Rect2(Vector2(bar_x, bar_y), Vector2(total_w, bar_h)), shield_empty_color)

	var clamped_shield: int = clampi(current_shield, 0, max_shield)
	var fill_w: float = _amount_to_pixel_width(clamped_shield)
	if fill_w <= 0.0:
		return

	draw_rect(Rect2(Vector2(bar_x, bar_y), Vector2(fill_w, bar_h)), shield_color)

# Optional setters (if you want to drive this UI by signals later)
func set_health(new_health: int) -> void:
	current_health = clampi(new_health, 0, max_health)
	queue_redraw()

func set_shield(new_shield: int) -> void:
	current_shield = clampi(new_shield, 0, max_shield)
	queue_redraw()

func get_current_health() -> int:
	return current_health

func get_current_shield() -> int:
	return current_shield
