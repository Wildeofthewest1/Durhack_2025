extends CanvasLayer
# In your main scene or UI
var minimap_scene: PackedScene = preload("res://scenes/UI/minimap.tscn")
var minimap: Minimap = minimap_scene.instantiate()
func _ready() -> void:
	self.add_child(minimap)
	minimap.follow_node = $"../"

# Set what the minimap follows (usually the player)
