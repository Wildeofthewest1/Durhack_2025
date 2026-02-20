extends Node2D

@export var LeftPos: Vector2 = Vector2(-26.0, 0.0)
@export var RightPos: Vector2 = Vector2(26.0, 0.0)
@export var Size: float = 1.0

# Debug: auto-separate after ready
@export var debug_auto_separate: bool = false
@export var debug_auto_separate_delay: float = 1.0

# Separation animation
@export var separate_distance: float = 18.0
@export var move_time: float = 0.18
@export var fade_time: float = 0.22
@export var fade_delay: float = 0.06

# Inherited drift (world-space) after detaching
@export var inherit_velocity_multiplier: float = 1.0
@export var damping: float = 2.5 # exponential damping rate (higher = slows faster)

# Continuous rotation for each booster (degrees/sec)
@export var min_spin_deg_per_sec: float = 90.0
@export var max_spin_deg_per_sec: float = 360.0

# Optional: after detaching, move this node to parent-of-parent (if exists).
@export var reparent_to_parent_parent: bool = true

@onready var LeftNode: Node2D = $left
@onready var RightNode: Node2D = $right

var _separating: bool = false

var _last_source_global_pos: Vector2 = Vector2.ZERO
var _have_source_sample: bool = false

var _drift_velocity: Vector2 = Vector2.ZERO
var _left_spin_rad_per_sec: float = 0.0
var _right_spin_rad_per_sec: float = 0.0

func _ready() -> void:
	LeftNode.position = LeftPos
	RightNode.position = RightPos
	scale *= Size

	# Prime velocity sampling source
	var src: Node2D = _find_velocity_source()
	if src != null:
		_last_source_global_pos = src.global_position
		_have_source_sample = true

	if debug_auto_separate:
		var d: float = max(debug_auto_separate_delay, 0.0)
		await get_tree().create_timer(d).timeout
		_seperate()

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	if not _separating:
		_update_source_velocity(delta)
		return

	# Drift in world space
	global_position += _drift_velocity * delta

	# Exponential damping
	_drift_velocity *= exp(-damping * delta)

	# Keep rotating each side independently
	LeftNode.rotation += _left_spin_rad_per_sec * delta
	RightNode.rotation += _right_spin_rad_per_sec * delta

func _seperate() -> void:
	if _separating:
		return

	_update_source_velocity(get_physics_process_delta_time())
	_drift_velocity *= inherit_velocity_multiplier

	# Random per-booster spin
	_left_spin_rad_per_sec = _random_spin_rad_per_sec()
	_right_spin_rad_per_sec = _random_spin_rad_per_sec()

	_separating = true

	# Detach from parent transform inheritance immediately (stop following)
	var gt: Transform2D = global_transform
	top_level = true
	global_transform = gt

	# Optionally move to parent-of-parent for hierarchy cleanliness
	if reparent_to_parent_parent:
		_detach_to_parent_parent_keep_global()

	# Separate left/right locally
	var mt: float = max(move_time, 0.01)

	var l_dir: Vector2 = LeftNode.position.normalized()
	if l_dir.length() == 0.0:
		l_dir = Vector2.LEFT

	var r_dir: Vector2 = RightNode.position.normalized()
	if r_dir.length() == 0.0:
		r_dir = Vector2.RIGHT

	var l_target: Vector2 = LeftNode.position + l_dir * separate_distance
	var r_target: Vector2 = RightNode.position + r_dir * separate_distance

	# Ensure visible before fading
	var lc: Color = LeftNode.modulate
	lc.a = 1.0
	LeftNode.modulate = lc

	var rc: Color = RightNode.modulate
	rc.a = 1.0
	RightNode.modulate = rc

	var tw: Tween = create_tween()

	# Phase 1: move (spin continues via _physics_process)
	tw.set_parallel(true)
	tw.tween_property(LeftNode, "position", l_target, mt).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(RightNode, "position", r_target, mt).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Phase 2: fade
	tw = tw.chain()
	if fade_delay > 0.0:
		tw.tween_interval(fade_delay)

	var ft: float = max(fade_time, 0.01)
	tw.set_parallel(true)
	tw.tween_property(LeftNode, "modulate:a", 0.0, ft).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(RightNode, "modulate:a", 0.0, ft).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tw.finished.connect(_on_separate_finished)

func _random_spin_rad_per_sec() -> float:
	var spin_deg: float = randf_range(min_spin_deg_per_sec, max_spin_deg_per_sec)
	if randf() < 0.5:
		spin_deg = -spin_deg
	return deg_to_rad(spin_deg)

func _update_source_velocity(delta: float) -> void:
	var src: Node2D = _find_velocity_source()
	if src == null:
		_have_source_sample = false
		_drift_velocity = Vector2.ZERO
		return

	# Prefer CharacterBody2D.velocity if available
	if src is CharacterBody2D:
		var cb: CharacterBody2D = src as CharacterBody2D
		_drift_velocity = cb.velocity
		_last_source_global_pos = cb.global_position
		_have_source_sample = true
		return

	var cur: Vector2 = src.global_position
	if _have_source_sample and delta > 0.0:
		_drift_velocity = (cur - _last_source_global_pos) / delta

	_last_source_global_pos = cur
	_have_source_sample = true

func _find_velocity_source() -> Node2D:
	# Walk up ancestors: prefer the first CharacterBody2D; otherwise remember highest Node2D.
	var n: Node = get_parent()
	var best_node2d: Node2D = null

	while n != null:
		if n is CharacterBody2D:
			return n as Node2D
		if n is Node2D:
			best_node2d = n as Node2D
		n = n.get_parent()

	return best_node2d

func _detach_to_parent_parent_keep_global() -> void:
	var p: Node = get_parent()
	if p == null:
		return

	var pp: Node = p.get_parent()
	if pp == null:
		return

	var gt: Transform2D = global_transform
	p.remove_child(self)
	pp.add_child(self)
	global_transform = gt

func _on_separate_finished() -> void:
	queue_free()
