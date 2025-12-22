# ResourceRow.gd
extends Control

@export var resource_id: String
@export var icon: TextureRect
@export var label: Label

func _ready() -> void:
	ResourceManager.resource_changed.connect(_on_resource_changed)
	_update()

func _on_resource_changed(id: String, amount: int) -> void:
	if id == resource_id:
		label.text = str(amount)

func _update() -> void:
	label.text = str(ResourceManager.get_amount(resource_id))
