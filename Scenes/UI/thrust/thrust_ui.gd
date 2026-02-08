extends Control

@export var player_group_name: String = "Player"
@export var thrust_bar_front: ColorRect
@export var thrust_bar_back: ColorRect

# Front bar (true value)
@export var front_smooth_speed: float = 14.0

# Back bar (afterimage)
@export var back_delay: float = 0.3  # Delay before starting to drop
@export var back_drop_speed: float = 12.0  # Speed of the chunky drop
@export var back_color_start: Color = Color(1.0, 0.8, 0.0)  # Yellow/orange at start
@export var back_color_held: Color = Color(1.0, 0.0, 0.0)   # Red after holding
@export var color_shift_time: float = 1.0  # Time to reach full red (seconds)
@export var color_fade_speed: float = 2.0  # Speed to fade back to start color after drop

var player: CharacterBody2D
var max_bar_width: float
var bar_center_x: float

# Afterimage tracking
var _back_ratio: float = 1.0
var _back_delay_timer: float = 0.0
var _prev_ratio: float = 1.0

# Color tracking
var _thrust_hold_time: float = 0.0
var _current_color_progress: float = 0.0

func _ready() -> void:
	if thrust_bar_front == null and has_node("ThrustBarBackground/ThrustBarFillFront"):
		thrust_bar_front = get_node("ThrustBarBackground/ThrustBarFillFront") as ColorRect
	if thrust_bar_back == null and has_node("ThrustBarBackground/ThrustBarFillBack"):
		thrust_bar_back = get_node("ThrustBarBackground/ThrustBarFillBack") as ColorRect
	
	if thrust_bar_front == null or thrust_bar_back == null:
		push_warning("Thrust bar front/back nodes not found")
		return
	
	max_bar_width = thrust_bar_front.size.x
	bar_center_x = thrust_bar_front.position.x + max_bar_width * 0.5
	_back_ratio = 1.0
	_prev_ratio = 1.0
	_thrust_hold_time = 0.0
	_current_color_progress = 0.0
	_find_player()

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
		return
	
	var ratio: float = clamp(_get_fuel_ratio(), 0.0, 1.0)
	
	# ── TRACK THRUST HOLD TIME FOR COLOR
	if ratio < _prev_ratio:
		# Fuel is being consumed → increment hold time
		_thrust_hold_time += delta
		_current_color_progress = clamp(_thrust_hold_time / color_shift_time, 0.0, 1.0)
	else:
		# Not consuming → reset hold time but keep color during delay/drop
		_thrust_hold_time = 0.0
	
	# ── FRONT BAR (always smooth, true value)
	var front_target_width: float = max_bar_width * ratio
	thrust_bar_front.size.x = lerp(
		thrust_bar_front.size.x,
		front_target_width,
		delta * front_smooth_speed
	)
	thrust_bar_front.position.x = bar_center_x - thrust_bar_front.size.x * 0.5
	
	# ── BACK BAR (afterimage logic)
	if ratio < _prev_ratio:
		# Fuel is being consumed → reset delay timer, keep back bar at max
		_back_delay_timer = back_delay
		_back_ratio = max(_back_ratio, _prev_ratio)  # Keep at highest point
	elif ratio > _back_ratio:
		# Fuel is refilling → back bar stays at current position (doesn't jump ahead)
		# It will only move when dropping or when it needs to catch up after a drop
		_back_delay_timer = 0.0
	else:
		# Fuel stable or back bar is above current ratio
		if _back_delay_timer > 0.0:
			# Still in delay period, hold position and color
			_back_delay_timer -= delta
		else:
			# Delay expired, drop down smoothly
			if _back_ratio > ratio:
				_back_ratio = lerp(_back_ratio, ratio, delta * back_drop_speed)
			
			# Only fade color back after bar has caught up
			if abs(_back_ratio - ratio) < 0.01:
				_current_color_progress = lerp(_current_color_progress, 0.0, delta * color_fade_speed)
	
	_back_ratio = clamp(_back_ratio, 0.0, 1.0)
	_prev_ratio = ratio
	
	# ── UPDATE BACK BAR SIZE & COLOR
	thrust_bar_back.size.x = max_bar_width * _back_ratio
	thrust_bar_back.position.x = bar_center_x - thrust_bar_back.size.x * 0.5
	
	# Color based on stored progress
	thrust_bar_back.color = back_color_start.lerp(back_color_held, _current_color_progress)

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
