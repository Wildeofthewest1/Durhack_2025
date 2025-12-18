extends Control
class_name HealthShieldUI

# -------------------------
# HEALTH (square blocks)
# -------------------------
@export var max_health: int = 100
@export var square_size: int = 25
@export var spacing: int = 50
@export var squares_per_row: int = 10
@export var health_per_square: int = 10
@export var health_color: Color = Color("99ff99")
@export var empty_color: Color = Color("333333")

# -------------------------
# SHIELD (Halo-style bar)
# -------------------------
@export var max_shield: int = 100
@export var shield_color: Color = Color("84dbf5")
@export var shield_empty_color: Color = Color("333333")

var shield_bar_gap: int = 5
var shield_bar_height: int = 5
var shield_bar_align_y: int = 0   # 0=center, -1=top, +1=bottom

# -------------------------
# Runtime data
# -------------------------
var current_health: int = 0
var current_shield: int = 0

var square_positions: Array[Vector2] = []
var square_count: int = 0

var player: Node = null
var _ph: Node = null

# Layout cache
var _grid_origin: Vector2 = Vector2.ZERO
var _grid_size: Vector2 = Vector2.ZERO

# Change tracking
var _last_max_health: int = 0
var _last_max_shield: int = 0

# =========================================================
# Lifecycle
# =========================================================
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player != null:
		_ph = player.get_child(1)
	shield_bar_gap = spacing
	shield_bar_height = spacing
	shield_bar_align_y = 0
	_pull_initial_values()
	_rebuild_health_layout()
	queue_redraw()

func _process(_delta: float) -> void:
	if player == null:
		return

	if _ph == null:
		_ph = player.get_child(1)
		if _ph == null:
			return

	var new_health := current_health
	var new_shield := current_shield
	var new_max_health := max_health
	var new_max_shield := max_shield

	if "health" in _ph:
		new_health = int(_ph.health)
	if "shield" in _ph:
		new_shield = int(_ph.shield)
	if "max_health" in _ph:
		new_max_health = int(_ph.max_health)
	if "max_shield" in _ph:
		new_max_shield = int(_ph.max_shield)

	var layout_changed := false

	if new_max_health != _last_max_health:
		max_health = new_max_health
		_last_max_health = new_max_health
		layout_changed = true

	if new_max_shield != _last_max_shield:
		max_shield = new_max_shield
		_last_max_shield = new_max_shield

	if layout_changed:
		_rebuild_health_layout()

	if new_health != current_health or new_shield != current_shield:
		current_health = new_health
		current_shield = new_shield
		queue_redraw()


# =========================================================
# Layout & state
# =========================================================
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
	var total := float(max_health) / float(health_per_square)
	square_count = int(ceil(total))
	_calculate_square_positions()

func _calculate_square_positions() -> void:
	square_positions.clear()

	var x_offset := 8
	var y_offset := 8
	_grid_origin = Vector2(x_offset, y_offset)

	for i in range(square_count):
		var row := i / squares_per_row
		var col := i - row * squares_per_row
		var x := x_offset + col * (square_size + spacing)
		var y := y_offset + row * (square_size + spacing)
		square_positions.append(Vector2(x, y))

	var rows := int(ceil(float(square_count) / squares_per_row))
	var cols = min(squares_per_row, square_count)

	_grid_size = Vector2(
		cols * square_size + (cols - 1) * spacing,
		rows * square_size + (rows - 1) * spacing
	)


# =========================================================
# Drawing
# =========================================================
func _draw() -> void:
	_draw_health_squares()
	_draw_shield_bar_halo()


func _draw_health_squares() -> void:
	for i in range(square_count):
		var pos := square_positions[i]
		var square_start := i * health_per_square
		var square_end := square_start + health_per_square

		draw_rect(Rect2(pos, Vector2(square_size, square_size)), empty_color)

		if current_health >= square_end:
			draw_rect(Rect2(pos, Vector2(square_size, square_size)), health_color)
		elif current_health > square_start:
			var frac := float(current_health - square_start) / health_per_square
			draw_rect(
				Rect2(pos, Vector2(square_size * frac, square_size)),
				health_color
			)


# Converts health/shield units into pixel width
func _amount_to_pixel_width(amount: int) -> float:
	var a = max(amount, 0)
	var full = a / health_per_square
	var rem = a - full * health_per_square

	var w := 0.0
	if full > 0:
		w += full * square_size
		w += max(full - 1, 0) * spacing

	if rem > 0:
		if full > 0:
			w += spacing
		w += square_size * (float(rem) / health_per_square)

	return w

# Converts shield amount into pixel width based on a fixed bar length
func _shield_amount_to_width(
	amount: int,
	max_amount: int,
	bar_length: float
) -> float:
	if max_amount <= 0 or bar_length <= 0.0:
		return 0.0

	var fraction = clamp(float(amount) / float(max_amount), 0.0, 1.0)
	return bar_length * fraction

# Converts shield amount into remaining path length
func _shield_amount_to_length(
	amount: int,
	max_amount: int,
	total_length: float
) -> float:
	if max_amount <= 0 or total_length <= 0.0:
		return 0.0

	var fraction = clamp(float(amount) / float(max_amount), 0.0, 1.0)
	return total_length * fraction


# =========================================================
# Halo-style shield drawing
# =========================================================
func _draw_shield_bar_halo() -> void:
	if max_shield <= 0:
		return

	# --- Horizontal alignment: under health squares ---
	var bar_x := _grid_origin.x

	# --- Vertical alignment: top of shield bar is gap below health ---
	var bar_y := _grid_origin.y + _grid_size.y + shield_bar_gap# + _grid_size.y
	var bar_h := shield_bar_height#_grid_size.y/5#float(shield_bar_height)
	var health_h := float(_grid_size.y + shield_bar_gap + bar_h)
	var cap_radius := health_h
	var bridge_len = _amount_to_pixel_width(max_shield - 100)
	var total_w = _grid_size.x + shield_bar_gap
	#var fill_w := _shield_amount_to_width(current_shield, max_shield, total_w)#_amount_to_pixel_width(clampi(current_shield, 0, max_shield))
	
	# --- Path lengths ---
	var thin_len = total_w
	#var bridge_len = _amount_to_pixel_width(max_shield-100)
	var arc_len = cap_radius# * (PI / 2)

	var total_len = thin_len + bridge_len + arc_len
	
	var remaining = _shield_amount_to_length(
		current_shield,
		max_shield,
		total_len
	)
	# --- Vertical transition up into the health silhouette ---
	var bridge_x = total_w + _grid_origin.x# + fill_w #- cap_radius
	var bridge_y := _grid_origin.y
	var bridge_height = health_h #+ bar_h
		# --- Rounded end cap (flush with health height) ---
	var cap_center := Vector2(
		bridge_x + bridge_len,
		bridge_y
	)
	# --- Empty thin bar ---
	draw_rect(
		Rect2(Vector2(bar_x, bar_y), Vector2(total_w, bar_h)),
		shield_empty_color
	)
	draw_rect(
		Rect2(Vector2(bridge_x,bridge_y),Vector2(bridge_len,bridge_height)),
		shield_empty_color
	)
	_draw_filled_quarter_circle(
		cap_center,
		cap_radius,
		0.0,
		PI/2,
		24,
		shield_empty_color
	)
	
	# -------------------------------------------------
	# Allocate visible length from LEFT → RIGHT
	# Depletion therefore happens RIGHT → LEFT
	# (arc first, then bridge, then thin bar)
	# -------------------------------------------------

	# 1) Thin bar (fills first, shrinks last)
	var bar_visible = clamp(remaining, 0.0, thin_len)
	if bar_visible > 0.0:
		draw_rect(
			Rect2(
				Vector2(bar_x, bar_y),
				Vector2(bar_visible, bar_h)
			),
			shield_color
		)

	remaining -= bar_visible

	# 2) Bridge (fills second)
	var bridge_visible = clamp(remaining, 0.0, bridge_len)
	if bridge_visible > 0.0:
		draw_rect(
			Rect2(
				Vector2(
					bridge_x,
					bridge_y
				),
				Vector2(bridge_visible, bridge_height)
			),
			shield_color
		)

	remaining -= bridge_visible

	# 3) Arc (fills last, so depletes first)
	var arc_visible = clamp(remaining, 0.0, arc_len)
	#var cutoff_x = bar_x + remaining

	#if arc_visible > 0.0:
	#	var arc_angle = arc_visible / arc_len * (PI / 2)      # 0..PI/2 (how much is visible)
	#	var start_angle = (PI / 2) - arc_angle                # moves 0 -> PI/2 as it empties
	#	var end_angle = PI / 2
	
		# cutoff_x should be the vertical line where the "mask" ends.
	# If your bar fills left->right and remaining is the visible length from the left:
	var cutoff_x = bar_x + thin_len + bridge_len + arc_visible  # if you're allocating visible length into arc
		# Maximum visible X of the entire shield shape
	#var max_cutoff_x = cap_center.x + cap_radius

	#cutoff_x = min(cutoff_x, max_cutoff_x)

	# OR (simpler, if you have a global visible length "visible_total" from the left):
	# var cutoff_x = bar_x + visible_total

	# Build the full sector in the correct quadrant first
	var sector = _build_filled_sector_polygon(cap_center, cap_radius, 0.0, PI / 2, 32)

	# Clip it to x >= cutoff_x (keep the right-hand side)
	var clipped = _clip_polygon_x_le(sector, cutoff_x)

	if clipped.size() >= 3:
		draw_polygon(clipped, PackedColorArray([shield_color]))

		#	_draw_filled_quarter_circle(
		#		cap_center,
			#	cap_radius,
			#	start_angle,
			#	end_angle,
			#	24,
			#	shield_color
			#)




func _draw_filled_quarter_circle(
	center: Vector2,
	radius: float,
	start_angle: float,
	end_angle: float,
	segments: int,
	color: Color
) -> void:
	var points := PackedVector2Array()
	points.append(center)

	for i in range(segments + 1):
		var t := float(i) / segments
		var angle = lerp(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	draw_polygon(points, PackedColorArray([color]))

func _build_filled_sector_polygon(center: Vector2, radius: float, start_angle: float, end_angle: float, segments: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	pts.append(center)

	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var a = lerp(start_angle, end_angle, t)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)

	return pts


# Clips a polygon to the half-plane x >= cutoff_x (vertical line).
# Clips a polygon to the half-plane x <= cutoff_x (keep left-hand side).
func _clip_polygon_x_le(poly: PackedVector2Array, cutoff_x: float) -> PackedVector2Array:
	var out = PackedVector2Array()
	if poly.size() < 3:
		return out

	var prev = poly[poly.size() - 1]
	var prev_in = prev.x <= cutoff_x

	for i in range(poly.size()):
		var curr = poly[i]
		var curr_in = curr.x <= cutoff_x

		# Edge crosses boundary -> add intersection
		if prev_in != curr_in:
			var dx = curr.x - prev.x
			if abs(dx) > 0.000001:
				var t = (cutoff_x - prev.x) / dx
				var inter = prev + (curr - prev) * t
				out.append(inter)

		# Keep points inside
		if curr_in:
			out.append(curr)

		prev = curr
		prev_in = curr_in

	return out



# =========================================================
# Optional setters
# =========================================================
func set_health(v: int) -> void:
	current_health = clampi(v, 0, max_health)
	queue_redraw()


func set_shield(v: int) -> void:
	current_shield = clampi(v, 0, max_shield)
	queue_redraw()


func get_current_health() -> int:
	return current_health


func get_current_shield() -> int:
	return current_shield
