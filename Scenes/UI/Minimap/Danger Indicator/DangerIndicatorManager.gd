extends CanvasLayer
class_name DangerIndicatorManager

## Manages radial danger/proximity indicators around the screen center

## Visual settings
@export var indicator_distance_from_center: float = 100.0  # Radius of indicator circle
@export var max_indicators: int = 5  # Maximum number of indicators to show
@export var show_radius: float = 800.0  # Show indicators when objects are beyond this radius from player

## Distance fade settings
@export var fade_start_distance: float = 500.0  # Distance where fade begins
@export var fade_end_distance: float = 1500.0   # Distance where fully faded

## Indicator arrow scene
@export var indicator_scene: PackedScene

## Registered objects that want to show indicators
var registered_objects: Array[MinimapTrackedObject] = []

## Active indicator instances (pooled)
var indicator_pool: Array[DangerIndicator] = []

## Container for indicators
var indicator_container: Control

func _ready() -> void:
	# Create container for indicators
	indicator_container = Control.new()
	indicator_container.name = "IndicatorContainer"
	indicator_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(indicator_container)
	
	# Pre-create indicator pool
	for i in range(max_indicators):
		var indicator: DangerIndicator = _create_indicator()
		indicator.visible = false
		indicator_pool.append(indicator)

func _process(delta: float) -> void:
	_update_indicators()

## Register an object to show on danger indicator
func register_object(obj: MinimapTrackedObject) -> void:
	if obj not in registered_objects:
		registered_objects.append(obj)

## Unregister an object
func unregister_object(obj: MinimapTrackedObject) -> void:
	registered_objects.erase(obj)

## Update all indicators
func _update_indicators() -> void:
	# Get camera for screen center calculations
	var cam: Camera2D = get_viewport().get_camera_2d()
	
	# Fallback: search for Camera2D in the scene
	if not cam:
		var cameras: Array[Node] = get_tree().get_nodes_in_group("GameCamera")
		if cameras.size() > 0:
			cam = cameras[0] as Camera2D
	
	# Last resort: find any Camera2D
	if not cam:
		cam = _find_camera_recursive(get_tree().root)
	
	if not cam:
		if Engine.get_physics_frames() % 60 == 0:  # Print once per second
			print("ERROR: DangerIndicatorManager - No Camera2D found in scene!")
		return
	
	var screen_center_world: Vector2 = cam.get_screen_center_position()
	
	# Get valid objects that should show indicators
	var valid_sources: Array[Dictionary] = []
	
	if Engine.get_physics_frames() % 60 == 0:  # Debug every second
		print("--- Checking ", registered_objects.size(), " registered objects ---")
	
	for obj in registered_objects:
		if not is_instance_valid(obj.target_node):
			continue
		
		var distance: float = screen_center_world.distance_to(obj.target_node.global_position)
		
		if Engine.get_physics_frames() % 60 == 0:
			print("  Object: ", obj.target_node.name, " Distance: ", distance, " ShowRadius: ", show_radius, " IndicatorEnabled: ", obj.indicator_enabled)
		
		# Check if should show based on radius
		if obj.only_when_offscreen and distance <= show_radius:
			if Engine.get_physics_frames() % 60 == 0:
				print("    SKIP: Too close (only_when_offscreen=true, distance <= show_radius)")
			continue
		
		if not obj.indicator_enabled:
			if Engine.get_physics_frames() % 60 == 0:
				print("    SKIP: indicator_enabled=false")
			continue
		
		# Skip if too far
		if obj.indicator_max_distance > 0.0 and distance > obj.indicator_max_distance:
			if Engine.get_physics_frames() % 60 == 0:
				print("    SKIP: Too far (distance > indicator_max_distance)")
			continue
		
		if Engine.get_physics_frames() % 60 == 0:
			print("    VALID! Adding to valid_sources")
		valid_sources.append({
			"object": obj,
			"distance": distance,
			"priority": obj.indicator_priority
		})
	
	if Engine.get_physics_frames() % 60 == 0:
		print("Valid sources found: ", valid_sources.size())
	
	# Sort by priority (higher first), then by distance (closer first)
	valid_sources.sort_custom(func(a, b):
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.distance < b.distance
	)
	
	# Limit to max_indicators
	var sources_to_show: Array[Dictionary] = valid_sources.slice(0, max_indicators)
	
	if Engine.get_physics_frames() % 60 == 0:
		print("Sources to show (after limit): ", sources_to_show.size())
	
	# Update indicators
	for i in range(indicator_pool.size()):
		var indicator: DangerIndicator = indicator_pool[i]
		
		if i < sources_to_show.size():
			var source_data: Dictionary = sources_to_show[i]
			var obj: MinimapTrackedObject = source_data.object
			_update_indicator(indicator, obj, source_data.distance, screen_center_world)
		else:
			indicator.visible = false

## Recursively find Camera2D in scene tree
func _find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node as Camera2D
	
	for child in node.get_children():
		var result: Camera2D = _find_camera_recursive(child)
		if result:
			return result
	
	return null

## Check if object should show indicator
func _should_show_indicator(obj: MinimapTrackedObject) -> bool:
	if not obj.indicator_enabled:
		return false
	
	if not is_instance_valid(obj.target_node):
		return false
	
	return true

## Update a single indicator
func _update_indicator(indicator: DangerIndicator, obj: MinimapTrackedObject, distance: float, screen_center_world: Vector2) -> void:
	indicator.visible = true
	
	# Get direction from screen center to object
	var direction: Vector2 = (obj.target_node.global_position - screen_center_world).normalized()
	
	# Calculate screen center
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var screen_center: Vector2 = viewport_size / 2.0
	
	# Position indicator at fixed radius from center
	var indicator_pos: Vector2 = screen_center + direction * indicator_distance_from_center
	indicator.position = indicator_pos
	
	# Rotate to point toward target
	indicator.rotation = direction.angle()
	
	# Calculate alpha based on distance fade
	var alpha: float = 1.0
	if obj.fade_with_distance:
		# Fade: 1.0 at fade_start_distance, 0.0 at fade_end_distance
		if distance >= fade_end_distance:
			alpha = 0.0
		elif distance >= fade_start_distance:
			# Linear interpolation between fade_start and fade_end
			var fade_range: float = fade_end_distance - fade_start_distance
			var distance_in_range: float = distance - fade_start_distance
			alpha = 1.0 - (distance_in_range / fade_range)
	
	# Apply blinking if enabled and active threat
	if obj.blink_when_active_threat and obj.is_active_threat():
		var blink_alpha: float = _calculate_blink_alpha(obj.blink_speed, obj.blink_min_alpha)
		alpha *= blink_alpha
	
	# Update indicator visual (color + alpha for fade)
	indicator.set_color(obj.indicator_color)
	indicator.set_alpha(alpha)

## Calculate blink alpha
func _calculate_blink_alpha(speed: float, min_alpha: float) -> float:
	var time: float = Time.get_ticks_msec() / 1000.0
	var wave: float = (sin(time * speed * PI * 2.0) + 1.0) / 2.0  # 0.0 to 1.0
	return lerp(min_alpha, 1.0, wave)

## Create a new indicator
func _create_indicator() -> DangerIndicator:
	if indicator_scene:
		var indicator: DangerIndicator = indicator_scene.instantiate()
		indicator_container.add_child(indicator)
		return indicator
	else:
		# Create default indicator
		var indicator: DangerIndicator = DangerIndicator.new()
		indicator_container.add_child(indicator)
		return indicator
