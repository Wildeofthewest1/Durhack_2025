extends Control

@export var player_group_name: String = "Player"
@export var thrust_bar_fill: ColorRect

var player: CharacterBody2D
var max_bar_width: float
var bar_center_x: float

func _ready() -> void:
	if thrust_bar_fill == null:
		thrust_bar_fill = $ThrustBarBackground/ThrustBarFill if has_node("ThrustBarBackground/ThrustBarFill") else $ThrustBarFill

	if thrust_bar_fill == null:
		push_warning("Thrust bar fill not found; fuel bar will not update.")
		return

	max_bar_width = thrust_bar_fill.size.x
	bar_center_x = thrust_bar_fill.position.x + max_bar_width * 0.5

	_find_player()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
		return

	var ratio: float = 0.0
	if player.has_method("get_fuel_ratio"):
		ratio = player.get_fuel_ratio()
	else:
		var fuel = player.fuel if "fuel" in player else 0.0
		var fuel_max = player.fuel_max if "fuel_max" in player else 1.0
		if fuel_max > 0.0:
			ratio = fuel / fuel_max

	ratio = clamp(ratio, 0.0, 1.0)

	var target_width = max_bar_width * ratio
	thrust_bar_fill.size.x = lerp(thrust_bar_fill.size.x, target_width, delta * 10.0)
	thrust_bar_fill.position.x = bar_center_x - thrust_bar_fill.size.x * 0.5


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group(player_group_name)
	if players.size() > 0:
		var candidate = players[0]
		if candidate is CharacterBody2D:
			player = candidate
			set_process(true)
	else:
		set_process(false)
