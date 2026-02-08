extends Node2D
class_name DangerIndicator

## Individual danger indicator arrow - modulates child node and optional label

## The visual element to modulate (Polygon2D, Sprite2D, etc.)
@export var visual_node: Node2D

## Optional label (stays upright)
@export var label: Label

func _ready() -> void:
	if not visual_node:
		push_warning("DangerIndicator: visual_node not assigned! Assign the Polygon2D/Sprite2D child in the inspector.")
	else:
		# Initialize with white color
		visual_node.modulate = Color.WHITE
	
	if label:
		# Make label stay upright
		label.rotation = 0.0

func _process(delta: float) -> void:
	# Keep label facing upright regardless of indicator rotation
	if label:
		label.rotation = -rotation

## Set the indicator color (keeps current alpha)
func set_color(color: Color) -> void:
	if visual_node:
		visual_node.modulate = Color(color.r, color.g, color.b, visual_node.modulate.a)

## Set the indicator alpha (keeps current color)
func set_alpha(alpha: float) -> void:
	var clamped_alpha: float = clamp(alpha, 0.0, 1.0)
	
	if visual_node:
		visual_node.modulate.a = clamped_alpha
	
	# Also modulate self to control label alpha
	modulate.a = clamped_alpha

## Set label text
func set_label_text(text: String) -> void:
	if label:
		label.text = text
		label.visible = text != ""

## Hide/show label
func set_label_visible(is_visible: bool) -> void:
	if label:
		label.visible = is_visible
