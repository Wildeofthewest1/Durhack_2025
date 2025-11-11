extends Area2D
class_name PlayerInteraction

signal interaction_target_changed(new_target: PlanetNPC)

@export var interact_key: StringName = "interact"

@onready var interaction_ui: InteractionUI = get_tree().get_first_node_in_group("InteractUI")

var _current_target: PlanetNPC = null
var _last_target: PlanetNPC = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(interact_key):
		if interaction_ui == null:
			return

		if interaction_ui.is_open() == true:
			interaction_ui.close_ui()
			return

		if _current_target != null:
			interaction_ui.toggle_for_planet(_current_target)
		
func _on_area_entered(area: Area2D) -> void:
	var candidate: Node = area
	var planet: PlanetNPC = null

	if candidate is PlanetNPC:
		planet = candidate
	else:
		var parent_node: Node = area.get_parent()
		if parent_node is PlanetNPC:
			planet = parent_node

	if planet != null:
		_current_target = planet
		emit_signal("interaction_target_changed", _current_target)
		_last_target = _current_target

func _on_area_exited(area: Area2D) -> void:
	if _current_target == null:
		return

	if area == _current_target:
		_current_target = null
		emit_signal("interaction_target_changed", _current_target)
		interaction_ui.close_ui()
	elif area.get_parent() == _current_target:
		_current_target = null
		emit_signal("interaction_target_changed", _current_target)
		interaction_ui.close_ui()
