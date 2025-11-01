extends Control
class_name Minimap

## Minimap display settings
@export var minimap_size: Vector2 = Vector2(200, 200)
@export var world_scale: float = 0.1  # How much world space = 1 pixel
@export var background_color: Color = Color(0.1, 0.1, 0.15, 0.9)
@export var border_color: Color = Color(0.3, 0.3, 0.4, 1.0)
@export var border_width: float = 2.0

## Reference to the player/camera to center the minimap on
@export var follow_node: Node2D

## Internal tracking
var tracked_objects: Array[MinimapTrackedObject] = []

@onready var draw_area: Control = $DrawArea

func _ready() -> void:
	custom_minimum_size = minimap_size
	size = minimap_size
	
	if draw_area:
		draw_area.custom_minimum_size = minimap_size
		draw_area.size = minimap_size

func _process(delta: float) -> void:
	if draw_area:
		draw_area.queue_redraw()

## Register an object to appear on the minimap
func register_object(obj: MinimapTrackedObject) -> void:
	if obj and not tracked_objects.has(obj):
		tracked_objects.append(obj)

## Unregister an object from the minimap
func unregister_object(obj: MinimapTrackedObject) -> void:
	var idx: int = tracked_objects.find(obj)
	if idx >= 0:
		tracked_objects.remove_at(idx)

## Get all currently tracked objects
func get_tracked_objects() -> Array[MinimapTrackedObject]:
	return tracked_objects

## Convert world position to minimap local position
func world_to_minimap(world_pos: Vector2) -> Vector2:
	if not follow_node:
		return Vector2.ZERO
	
	var offset: Vector2 = world_pos - follow_node.global_position
	var scaled: Vector2 = offset * world_scale
	var center: Vector2 = minimap_size * 0.5
	
	return center + scaled

## Check if a world position is visible on the minimap
func is_visible_on_minimap(world_pos: Vector2) -> bool:
	var minimap_pos: Vector2 = world_to_minimap(world_pos)
	return minimap_pos.x >= 0 and minimap_pos.x <= minimap_size.x and minimap_pos.y >= 0 and minimap_pos.y <= minimap_size.y
