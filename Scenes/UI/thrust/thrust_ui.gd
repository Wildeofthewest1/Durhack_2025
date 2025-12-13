extends Control

@export var player_group_name: String = "Player"

@export var thrust_bar_front: ColorRect
@export var thrust_bar_back: ColorRect

# Front bar (true value)
@export var front_smooth_speed: float = 14.0

# Back bar (afterimage)
@export var back_refill_speed: float = 6.0
@export var back_steps: int = 10   # lower = chunkier drops

var player: CharacterBody2D
var max_bar_width: float
var bar_center_x: float

# This is the stored afterimage value
var _back_ratio: float = 1.0

func _ready() -> void:
	if thrust_bar_front == null and has_node("ThrustBarBackground/ThrustBarFillFront"):
		thrust_bar_front = $ThrustBarBackground/ThrustBarFillFront as ColorRect

	if thrust_bar_back == null and has_node("ThrustBarBackground/ThrustBarFillBack"):
		thrust_bar_back = $ThrustBarBackground/ThrustBarFillBack as ColorRect

	if thrust_bar_front == null or thrust_bar_back == null:
		push_warning("Thrust bar front/back nodes not found")
		return

	max_bar_width = thrust_bar_front.size.x
	bar_center_x = thrust_bar_front.position.x + max_bar_width * 0.5

	_back_ratio = 1.0
	_find_player()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
		return

	var ratio: float = clamp(_get_fuel_ratio(), 0.0, 1.0)

	# ── FRONT BAR (always smooth, true value)
	var front_target_width: float = max_bar_width * ratio
	thrust_bar_front.size.x = lerp(
		thrust_bar_front.size.x,
		front_target_width,
		delta * front_smooth_speed
	)
	thrust_bar_front.position.x = bar_center_x - thrust_bar_front.size.x * 0.5

	# ── BACK BAR (afterimage logic)
	if ratio < _back_ratio:
		# Fuel is being consumed → hard stepped drop
		var steps_f: float = float(max(back_steps, 1))
		var stepped: float = ceil(ratio * steps_f) / steps_f
		_back_ratio = min(_back_ratio, stepped)
	else:
		# Fuel is refilling / idle → smooth catch-up
		_back_ratio = lerp(_back_ratio, ratio, delta * back_refill_speed)

	_back_ratio = clamp(_back_ratio, 0.0, 1.0)

	thrust_bar_back.size.x = max_bar_width * _back_ratio
	thrust_bar_back.position.x = bar_center_x - thrust_bar_back.size.x * 0.5


func _get_fuel_ratio() -> float:
	if player.has_method("get_fuel_ratio"):
		return float(player.get_fuel_ratio())

	var fuel: float = 0.0
	var fuel_max: float = 1.0

	if "fuel" in player:
		fuel = float(player.fuel)
	if "fuel_max" in player:
		fuel_max = float(player.fuel_max)

	if fuel_max > 0.0:
		return fuel / fuel_max

	return 0.0


func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group(player_group_name)
	if players.size() > 0 and players[0] is CharacterBody2D:
		player = players[0] as CharacterBody2D
		set_process(true)
	else:
		set_process(false)
