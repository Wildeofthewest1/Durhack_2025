extends Node
class_name MinimapTrackedObject

## The node this component is tracking (usually the parent)
@export var target_node: Node2D

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

## Reference to minimap (automatically found)
var minimap: Minimap

func _ready() -> void:
	# Auto-assign target_node to parent if not set
	if not target_node:
		target_node = get_parent() as Node2D
	
	# Find the minimap in the scene
	call_deferred("_find_and_register_minimap")

func _exit_tree() -> void:
	if minimap:
		minimap.unregister_object(self)

func _find_and_register_minimap() -> void:
	minimap = _find_minimap_recursive(get_tree().root)
	if minimap:
		minimap.register_object(self)
	else:
		push_warning("MinimapTrackedObject could not find a Minimap node in the scene tree")

func _find_minimap_recursive(node: Node) -> Minimap:
	if node is Minimap:
		return node as Minimap
	
	for child in node.get_children():
		var result: Minimap = _find_minimap_recursive(child)
		if result:
			return result
	
	return null

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
