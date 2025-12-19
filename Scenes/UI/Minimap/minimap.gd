extends Control
class_name Minimap

## Minimap display settings
@export var minimap_size: Vector2 = Vector2(200.0, 200.0)
@export var world_scale: float = 0.1
@export var background_color: Color = Color(0.1, 0.1, 0.15, 0.9)
@export var border_color: Color = Color(0.3, 0.3, 0.4, 1.0)
@export var border_width: float = 2.0

## Margins from the top-right corner of the screen
@export var margin_top: float = 10.0
@export var margin_right: float = 10.0

## Reference to the player/camera to center the minimap on
@export var follow_node: Node2D

## Internal tracking
var tracked_objects: Array[MinimapTrackedObject] = []

@onready var draw_area: MinimapDrawArea = $DrawArea as MinimapDrawArea

func _ready() -> void:
	_update_layout()

	if draw_area != null:
		# Fill the Minimap rect
		draw_area.anchor_left = 0.0
		draw_area.anchor_top = 0.0
		draw_area.anchor_right = 1.0
		draw_area.anchor_bottom = 1.0
		draw_area.offset_left = 0.0
		draw_area.offset_top = 0.0
		draw_area.offset_right = 0.0
		draw_area.offset_bottom = 0.0

func _physics_process(_delta: float) -> void:
	if draw_area != null:
		draw_area.queue_redraw()

func _update_layout() -> void:
	# Anchor to top-right
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0

	# Apply margins and size.
	# Right/top offsets are just the margins.
	offset_top = margin_top
	offset_right = -margin_right

	# Grow left and down from the top-right corner.
	offset_left = offset_right - minimap_size.x
	offset_bottom = offset_top + minimap_size.y

	custom_minimum_size = minimap_size
	size = minimap_size

## Call this from anywhere to resize the minimap in code
func set_minimap_size(new_size: Vector2) -> void:
	minimap_size = new_size
	_update_layout()

## Register an object to appear on the minimap
func register_object(obj: MinimapTrackedObject) -> void:
	if obj != null and not tracked_objects.has(obj):
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
	if follow_node == null:
		return Vector2.ZERO

	var offset: Vector2 = world_pos - follow_node.global_position
	var scaled: Vector2 = offset * world_scale
	var center: Vector2 = minimap_size * 0.5
	return center + scaled

## Check if a world position is visible on the minimap
func is_visible_on_minimap(world_pos: Vector2) -> bool:
	var minimap_pos: Vector2 = world_to_minimap(world_pos)
	return minimap_pos.x >= 0.0 and minimap_pos.x <= minimap_size.x \
		and minimap_pos.y >= 0.0 and minimap_pos.y <= minimap_size.y
