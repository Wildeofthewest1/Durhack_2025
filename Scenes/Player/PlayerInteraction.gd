extends Area2D
class_name PlayerInteraction

signal interaction_target_changed(new_target: PlanetNPC)

@export var interact_key: StringName = &"interact"
@onready var interaction_ui: InteractionUI = get_tree().get_first_node_in_group("InteractUI") as InteractionUI

var _current_target: PlanetNPC = null
var _last_target: PlanetNPC = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(interact_key):
		if interaction_ui == null:
			return
		if interaction_ui.is_open() == true:
			get_tree().paused = false
			interaction_ui.close_ui()
			return
		if _current_target != null:
			interaction_ui.toggle_for_planet(_current_target)

func _set_current_target(new_target: PlanetNPC) -> void:
	if new_target == _current_target:
		return

	# Hide old indicator
	if _current_target != null:
		_current_target.hide_interact_indicator()

	_current_target = new_target
	emit_signal("interaction_target_changed", _current_target)

	# Show new indicator
	if _current_target != null:
		_current_target.show_interact_indicator()

	_last_target = _current_target

func _on_area_entered(area: Area2D) -> void:
	var planet: PlanetNPC = null

	# Keep your original behavior
	var candidate: Node = area
	if candidate is PlanetNPC:
		planet = candidate as PlanetNPC
	else:
		var parent_node: Node = area.get_parent()
		if parent_node is PlanetNPC:
			planet = parent_node as PlanetNPC

	if planet != null:
		_set_current_target(planet)

func _on_area_exited(area: Area2D) -> void:
	if _current_target == null:
		return

	# Keep your original behavior (works with your scene structure)
	if area.get_parent() == _current_target:
		_set_current_target(null)
		if interaction_ui != null:
			interaction_ui.close_ui()
