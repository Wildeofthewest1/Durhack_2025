extends Node2D
class_name Trail2D

@export var body_path: NodePath
@export var max_points: int = 300
@export var sample_every: float = 0.0
@export var width: float = 1.5
@export var color: Color = Color(0.443, 0.282, 0.396)
@export var fade: bool = true
@export var head_is_opaque: bool = true  # <— choose fade direction

var _body: Node2D
var _pts: PackedVector2Array = []
var _accum := 0.0

func _ready() -> void:
	_body = get_node_or_null(body_path)
	set_process(true)

func _process(dt: float) -> void:
	if _body == null: return
	_accum += dt
	if sample_every <= 0.0 or _accum >= sample_every:
		_pts.append(_body.global_position)     # store WORLD positions
		if _pts.size() > max_points:
			_pts.remove_at(0)
		_accum = 0.0
		queue_redraw()

func _draw() -> void:
	var n := _pts.size()
	if n < 2: return

	for i in range(1, n):
		var a := to_local(_pts[i - 1])
		var b := to_local(_pts[i])

		# t=0 -> oldest (tail), t=1 -> newest (head)
		var t := float(i) / float(n - 1)

		var c := color
		if fade:
			if head_is_opaque:
				# tail transparent → head opaque
				c.a = lerp(0.0, 1.0, t)
			else:
				# head transparent → tail opaque
				c.a = lerp(1.0, 0.0, t)

		draw_line(a, b, c, width)
