extends Node2D
class_name LimbLagIndependentRot

@export var centre_path: NodePath = NodePath("../")

@export var spring: float = 35.0
@export var damping: float = 18.0
@export var max_lag_rad: float = 0.8

var _centre: Node2D

var _rest_local_pos: Vector2 = Vector2.ZERO
var _rest_local_rot: float = 0.0
var _rest_local_scale: Vector2 = Vector2.ONE

var _rot_vel: float = 0.0

func _ready() -> void:
	_centre = get_node(centre_path) as Node2D

	# Cache attachment in centre-local space
	_rest_local_pos = _centre.to_local(global_position)
	_rest_local_rot = global_rotation - _centre.global_rotation

	# Cache this limb's own local scale (so you can still scale limbs individually)
	_rest_local_scale = scale

	# Stop inheriting transforms
	set_as_top_level(true)

	# Snap once
	global_position = _centre.to_global(_rest_local_pos)
	global_scale = Vector2(_centre.global_scale.x * _rest_local_scale.x, _centre.global_scale.y * _rest_local_scale.y)


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	# 1) Pivot stays locked to centre position
	global_position = _centre.to_global(_rest_local_pos)

	# 2) Scale follows centre scale
	global_scale = Vector2(_centre.global_scale.x * _rest_local_scale.x, _centre.global_scale.y * _rest_local_scale.y)

	# 3) Rotation lags toward where it "would be"
	var target_rot: float = _centre.global_rotation + _rest_local_rot
	var err: float = wrapf(target_rot - global_rotation, -PI, PI)

	if absf(err) > max_lag_rad:
		err = signf(err) * max_lag_rad

	_rot_vel += err * spring * delta
	_rot_vel -= _rot_vel * damping * delta
	global_rotation += _rot_vel * delta
