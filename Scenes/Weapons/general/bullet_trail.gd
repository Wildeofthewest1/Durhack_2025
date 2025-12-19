extends Line2D
class_name ProjectileTrail2D

@export var max_points: int = 12
@export var min_step_distance: float = 2.0

var _parent_node: Node2D = null
var _world_points: Array[Vector2] = []
var _is_seeded: bool = false

func _enter_tree() -> void:
	# Hide + clear BEFORE the first possible render
	visible = false
	points = PackedVector2Array()

func _ready() -> void:
	_parent_node = get_parent() as Node2D
	set_as_top_level(true)
	global_rotation = 0.0

func reset_to_world_pos(p: Vector2) -> void:
	_world_points.clear()
	_world_points.append(p)
	_world_points.append(p)
	_is_seeded = true
	_rebuild_points()
	visible = true

func _physics_process(_delta: float) -> void:
	if not _is_seeded:
		return

	if _parent_node == null or not is_instance_valid(_parent_node):
		queue_free()
		return

	var p: Vector2 = _parent_node.global_position
	var last_p: Vector2 = _world_points[0]

	if p.distance_to(last_p) >= min_step_distance:
		_world_points.insert(0, p)
		if _world_points.size() > max_points:
			_world_points.resize(max_points)
		_rebuild_points()

func _rebuild_points() -> void:
	# Anchor at oldest point (stable, no jumping)
	var anchor: Vector2 = _world_points[_world_points.size() - 1]
	global_position = anchor
	global_rotation = 0.0

	var local_pts: PackedVector2Array = PackedVector2Array()
	var count: int = _world_points.size()
	for i in range(0, count):
		local_pts.append(_world_points[i] - anchor)

	points = local_pts
