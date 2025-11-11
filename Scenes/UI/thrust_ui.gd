extends Control

@export var player_group_name: String = "Player"
@export var thrust_bar_fill: ColorRect

var player: CharacterBody2D
var max_bar_width: float = 0.0
var bar_center_x: float = 0.0

func _ready() -> void:
	if thrust_bar_fill == null:
		thrust_bar_fill = $ThrustBarBackground/ThrustBarFill if has_node("ThrustBarBackground/ThrustBarFill") else $ThrustBarFill

	# Cache initial width and centre so we can shrink towards the middle
	max_bar_width = thrust_bar_fill.size.x
	bar_center_x = thrust_bar_fill.position.x + max_bar_width * 0.5

	_find_player()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
		return

	# Read fuel ratio from the player
	var ratio: float = 0.0

	if player.has_method("get_fuel_ratio"):
		ratio = player.get_fuel_ratio()
	else:
		# fallback if you did not add get_fuel_ratio()
		var fuel_value: float = 0.0
		var fuel_max_value: float = 1.0

		if "fuel" in player:
			fuel_value = player.fuel
		if "fuel_max" in player:
			fuel_max_value = player.fuel_max

		if fuel_max_value > 0.0:
			ratio = fuel_value / fuel_max_value

	# Clamp 0–1
	if ratio < 0.0:
		ratio = 0.0
	if ratio > 1.0:
		ratio = 1.0

	# Update the bar: shrink towards centre
	var current_width: float = max_bar_width * ratio
	thrust_bar_fill.size.x = current_width
	thrust_bar_fill.position.x = bar_center_x - current_width * 0.5


func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group(player_group_name)
	if players.size() > 0:
		var candidate: Node = players[0]
		if candidate is CharacterBody2D:
			player = candidate
