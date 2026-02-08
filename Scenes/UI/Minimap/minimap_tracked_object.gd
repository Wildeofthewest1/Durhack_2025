extends Node
class_name MinimapTrackedObject

## The node this component is tracking (usually the parent)
@export var target_node: Node2D

## === MINIMAP SETTINGS ===
@export_group("Minimap")

## Visual settings
enum DotShape { CIRCLE, SQUARE, TRIANGLE, DIAMOND }
@export var dot_shape: DotShape = DotShape.CIRCLE
@export var dot_size: float = 3.0
@export var dot_color: Color = Color.WHITE
@export var brightness: float = 1.0

## Blinking effect
@export var blink_enabled: bool = false
@export var blink_speed: float = 1.0  # Blinks per second
@export var blink_min_alpha: float = 0.3  # Minimum alpha when blinking

## Outline
@export var outline_enabled: bool = false
@export var outline_color: Color = Color.BLACK
@export var outline_width: float = 1.0

## Visibility control
@export var visible_on_minimap: bool = true

## === DANGER INDICATOR SETTINGS ===
@export_group("Danger Indicator")

## Enable danger indicator
@export var indicator_enabled: bool = false

## Type of indicator
enum IndicatorType { THREAT, INTERACTABLE, PLANET, OBJECTIVE, CUSTOM }
@export var indicator_type: IndicatorType = IndicatorType.THREAT

## Indicator color (can be different from minimap dot)
@export var indicator_color: Color = Color.RED

## Priority (higher = shown first when at max limit)
@export var indicator_priority: int = 0

## Maximum distance to show indicator (0 = infinite)
@export var indicator_max_distance: float = 2000.0

## Only show when target is offscreen
@export var only_when_offscreen: bool = true

## Fade indicator based on distance
@export var fade_with_distance: bool = true

## Blink when this is an active threat (in combat + hostile)
@export var blink_when_active_threat: bool = false

## Is this object hostile/dangerous
@export var is_hostile: bool = false

## Threat level (used for combat tracking)
@export var threat_level: float = 1.0

## === REFERENCES ===
## Reference to minimap (automatically found)
var minimap: Minimap

## Reference to danger indicator manager (automatically found)
var danger_indicator_manager: DangerIndicatorManager

func _ready() -> void:
	# Auto-assign target_node to parent if not set
	if not target_node:
		target_node = get_parent() as Node2D
	
	# Find and register with systems
	call_deferred("_find_and_register_systems")

func _exit_tree() -> void:
	if minimap:
		minimap.unregister_object(self)
	
	if danger_indicator_manager:
		danger_indicator_manager.unregister_object(self)

func _find_and_register_systems() -> void:
	# Find minimap
	minimap = _find_node_of_type(get_tree().root, Minimap) as Minimap
	if minimap:
		minimap.register_object(self)
	else:
		push_warning("MinimapTrackedObject could not find a Minimap node in the scene tree")
	
	# Find danger indicator manager
	danger_indicator_manager = _find_node_of_type(get_tree().root, DangerIndicatorManager) as DangerIndicatorManager
	if danger_indicator_manager and indicator_enabled:
		danger_indicator_manager.register_object(self)
	elif indicator_enabled:
		push_warning("MinimapTrackedObject could not find a DangerIndicatorManager node in the scene tree")

func _find_node_of_type(node: Node, type) -> Node:
	if is_instance_of(node, type):
		return node
	
	for child in node.get_children():
		var result: Node = _find_node_of_type(child, type)
		if result:
			return result
	
	return null

## === MINIMAP METHODS ===

## Show this object on the minimap
func show_on_minimap() -> void:
	visible_on_minimap = true

## Hide this object from the minimap
func hide_from_minimap() -> void:
	visible_on_minimap = false

## Toggle visibility on the minimap
func toggle_minimap_visibility() -> void:
	visible_on_minimap = not visible_on_minimap

## Start blinking effect
func start_blinking(speed: float = 1.0, min_alpha: float = 0.3) -> void:
	blink_enabled = true
	blink_speed = speed
	blink_min_alpha = min_alpha

## Stop blinking effect
func stop_blinking() -> void:
	blink_enabled = false

## Change the dot color
func set_dot_color(new_color: Color) -> void:
	dot_color = new_color

## Change the dot shape
func set_dot_shape(new_shape: DotShape) -> void:
	dot_shape = new_shape

## Change the dot size
func set_dot_size(new_size: float) -> void:
	dot_size = new_size

## Set brightness (values > 1.0 make it glow-like)
func set_brightness(value: float) -> void:
	brightness = value

## === DANGER INDICATOR METHODS ===

## Enable the danger indicator
func enable_indicator() -> void:
	indicator_enabled = true
	if danger_indicator_manager and self not in danger_indicator_manager.registered_objects:
		danger_indicator_manager.register_object(self)

## Disable the danger indicator
func disable_indicator() -> void:
	indicator_enabled = false
	if danger_indicator_manager:
		danger_indicator_manager.unregister_object(self)

## Set indicator color
func set_indicator_color(color: Color) -> void:
	indicator_color = color

## Set indicator priority
func set_indicator_priority(priority: int) -> void:
	indicator_priority = priority

## Set if this is hostile
func set_hostile(hostile: bool) -> void:
	is_hostile = hostile

## Check if this is an active threat (hostile + combat active)
func is_active_threat() -> bool:
	if not is_hostile:
		return false
	
	# Check if combat tracker exists and combat is active
	var combat_tracker: CombatTracker = get_node_or_null("/root/CombatTracker") as CombatTracker
	if combat_tracker:
		return combat_tracker.is_in_combat
	
	return false

## Report this object caused a combat action
func report_combat_action() -> void:
	var combat_tracker: CombatTracker = get_node_or_null("/root/CombatTracker") as CombatTracker
	if combat_tracker:
		combat_tracker.report_combat_action()
