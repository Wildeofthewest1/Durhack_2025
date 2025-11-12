extends Line2D
class_name ProjectileTrail2D

@export var max_points: int = 12
@export var min_step_distance: float = 2.0

var _parent_node: Node2D = null
var _points: Array[Vector2] = []


func _ready() -> void:
	_parent_node = get_parent() as Node2D

	# Make this Line2D exist in world space, not in the bullet's local space
	set_as_top_level(true)
	global_position = Vector2.ZERO
	global_rotation = 0.0

	_points.clear()
	points = _points


func _physics_process(delta: float) -> void:
	if _parent_node == null:
		queue_free()
		return
	if not is_instance_valid(_parent_node):
		queue_free()
		return

	var pos: Vector2 = _parent_node.global_position

	if _points.size() == 0:
		# Seed with two identical points so there is no long segment on first frame
		_points.append(pos)
		_points.append(pos)
	else:
		var last_pos: Vector2 = _points[0]
		if pos.distance_to(last_pos) >= min_step_distance:
			_points.insert(0, pos)
			if _points.size() > max_points:
				_points.resize(max_points)

	points = _points
