extends CanvasLayer
# In your main scene or UI

func _ready() -> void:
	var minimap:= $"MinimapContainer/Minimap"
	minimap.follow_node = $"../SubViewportContainer/SubViewport/Game/PlayerContainer/Player"

# Set what the minimap follows (usually the player)
