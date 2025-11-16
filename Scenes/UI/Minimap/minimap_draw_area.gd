extends Control
class_name MinimapDrawArea

func _draw() -> void:
	var minimap: Minimap = get_parent() as Minimap
	if not minimap:
		return
	
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, minimap.minimap_size), minimap.background_color)
	
	# Draw border
	draw_rect(Rect2(Vector2.ZERO, minimap.minimap_size), minimap.border_color, false, minimap.border_width)
	
	# Draw tracked objects
	var objects: Array[MinimapTrackedObject] = minimap.get_tracked_objects()
	for obj in objects:
		if not is_instance_valid(obj) or not obj.visible_on_minimap:
			continue
		
		if not is_instance_valid(obj.target_node):
			continue
		
		var world_pos: Vector2 = obj.target_node.global_position
		var minimap_pos: Vector2 = minimap.world_to_minimap(world_pos)
		
		# Only draw if within minimap bounds
		if not minimap.is_visible_on_minimap(world_pos):
			continue
		
		_draw_minimap_dot(minimap_pos, obj)

func _draw_minimap_dot(pos: Vector2, obj: MinimapTrackedObject) -> void:
	var current_color: Color = obj.dot_color
	
	# Apply blinking effect
	if obj.blink_enabled:
		var time: float = Time.get_ticks_msec() / 1000.0
		var blink_factor: float = (sin(time * obj.blink_speed * TAU) + 1.0) * 0.5
		blink_factor = lerp(obj.blink_min_alpha, 1.0, blink_factor)
		current_color.a *= blink_factor
	
	# Apply brightness
	var brightened: Color = Color(
		current_color.r * obj.brightness,
		current_color.g * obj.brightness,
		current_color.b * obj.brightness,
		current_color.a
	)
	
	# Draw the dot based on shape
	match obj.dot_shape:
		MinimapTrackedObject.DotShape.CIRCLE:
			draw_circle(pos, obj.dot_size, brightened)
		MinimapTrackedObject.DotShape.SQUARE:
			var half_size: float = obj.dot_size
			draw_rect(Rect2(pos - Vector2(half_size, half_size), Vector2(half_size * 2, half_size * 2)), brightened)
		MinimapTrackedObject.DotShape.TRIANGLE:
			_draw_triangle(pos, obj.dot_size, brightened)
		MinimapTrackedObject.DotShape.DIAMOND:
			_draw_diamond(pos, obj.dot_size, brightened)
	
	# Draw outline if enabled
	if obj.outline_enabled:
		match obj.dot_shape:
			MinimapTrackedObject.DotShape.CIRCLE:
				draw_arc(pos, obj.dot_size, 0, TAU, 16, obj.outline_color, obj.outline_width)
			MinimapTrackedObject.DotShape.SQUARE:
				var half_size: float = obj.dot_size
				draw_rect(Rect2(pos - Vector2(half_size, half_size), Vector2(half_size * 2, half_size * 2)), obj.outline_color, false, obj.outline_width)
			MinimapTrackedObject.DotShape.TRIANGLE:
				_draw_triangle_outline(pos, obj.dot_size, obj.outline_color, obj.outline_width)
			MinimapTrackedObject.DotShape.DIAMOND:
				_draw_diamond_outline(pos, obj.dot_size, obj.outline_color, obj.outline_width)

func _draw_triangle(center: Vector2, size: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var height: float = size * 1.5
	points.append(center + Vector2(0, -height))
	points.append(center + Vector2(-size, height * 0.5))
	points.append(center + Vector2(size, height * 0.5))
	draw_colored_polygon(points, color)

func _draw_triangle_outline(center: Vector2, size: float, color: Color, width: float) -> void:
	var height: float = size * 1.5
	var p1: Vector2 = center + Vector2(0, -height)
	var p2: Vector2 = center + Vector2(-size, height * 0.5)
	var p3: Vector2 = center + Vector2(size, height * 0.5)
	draw_line(p1, p2, color, width)
	draw_line(p2, p3, color, width)
	draw_line(p3, p1, color, width)

func _draw_diamond(center: Vector2, size: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(center + Vector2(0, -size))
	points.append(center + Vector2(size, 0))
	points.append(center + Vector2(0, size))
	points.append(center + Vector2(-size, 0))
	draw_colored_polygon(points, color)

func _draw_diamond_outline(center: Vector2, size: float, color: Color, width: float) -> void:
	var p1: Vector2 = center + Vector2(0, -size)
	var p2: Vector2 = center + Vector2(size, 0)
	var p3: Vector2 = center + Vector2(0, size)
	var p4: Vector2 = center + Vector2(-size, 0)
	draw_line(p1, p2, color, width)
	draw_line(p2, p3, color, width)
	draw_line(p3, p4, color, width)
	draw_line(p4, p1, color, width)
