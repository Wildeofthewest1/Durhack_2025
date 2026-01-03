extends Node2D
class_name RockingRotation

@export var amplitude_deg: float = 4.0      # max angle left/right
@export var frequency_hz: float = 0.2        # oscillations per second

var _time: float = 0.0
var _base_rotation: float = 0.0
var _phase_offset: float = 0.0

func _ready() -> void:
	_base_rotation = rotation
	_phase_offset = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	_time += delta

	var angle_offset_deg: float = amplitude_deg * sin(
		_time * TAU * frequency_hz + _phase_offset
	)

	rotation = _base_rotation + deg_to_rad(angle_offset_deg)
