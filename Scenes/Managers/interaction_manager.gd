extends Node
class_name InteractionManager

signal interactable_in_range(interactable: Interactable)
signal interactable_out_of_range(interactable: Interactable)
signal interaction_triggered(interactable: Interactable)

@export var player: CharacterBody2D
@export var detection_radius: float = 200.0
@export var interaction_key: Key = KEY_E

var current_interactables: Array[Interactable] = []
var closest_interactable: Interactable = null
var is_interacting: bool = false

func _ready() -> void:
	if not player:
		push_error("InteractionManager: No player assigned!")
		return
	
	set_process(true)

func _process(_delta: float) -> void:
	if not player:
		return
	
	_update_nearby_interactables()
	_update_closest_interactable()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == interaction_key:
			if closest_interactable and closest_interactable.can_be_interacted():
				trigger_interaction(closest_interactable)

func _update_nearby_interactables() -> void:
	var all_interactables: Array[Node] = get_tree().get_nodes_in_group("interactables")
	var previous_interactables: Array[Interactable] = current_interactables.duplicate()
	current_interactables.clear()
	
	for node: Node in all_interactables:
		if node is Interactable:
			var interactable: Interactable = node as Interactable
			var distance: float = player.global_position.distance_to(interactable.global_position)
			
			if distance <= detection_radius and interactable.can_be_interacted():
				current_interactables.append(interactable)
				
				# Check if this is newly in range
				if not previous_interactables.has(interactable):
					interactable_in_range.emit(interactable)
	
	# Check for interactables that left range
	for interactable: Interactable in previous_interactables:
		if not current_interactables.has(interactable):
			interactable_out_of_range.emit(interactable)

func _update_closest_interactable() -> void:
	var previous_closest: Interactable = closest_interactable
	closest_interactable = null
	var closest_distance: float = INF
	
	for interactable: Interactable in current_interactables:
		var distance: float = player.global_position.distance_to(interactable.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_interactable = interactable
	
	# Notify if closest changed
	if closest_interactable != previous_closest:
		if previous_closest:
			pass  # Could add visual feedback removal here
		if closest_interactable:
			pass  # Could add visual feedback here

func trigger_interaction(interactable: Interactable) -> void:
	if is_interacting:
		return
		
	is_interacting = true
	interactable.on_interact(player)
	interaction_triggered.emit(interactable)

func end_interaction(interactable: Interactable) -> void:
	is_interacting = false
	if interactable:
		interactable.on_interaction_end(player)

func get_closest_interactable() -> Interactable:
	return closest_interactable

func get_all_nearby_interactables() -> Array[Interactable]:
	return current_interactables.duplicate()
