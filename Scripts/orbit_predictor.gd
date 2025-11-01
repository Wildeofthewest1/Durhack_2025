# res://sim/visuals/PredictiveTrajectory2D.gd
extends Node2D
class_name PredictiveTrajectory2D

# --- Target body to predict (your Player)
@export var body_path: NodePath

# --- Gravity (match your GravitySensor)
@export var G: float = 1000.0
@export var base_softening: float = 8.0
@export var max_contributors: int = 0  # 0 = all
@export var include_thrust: bool = false

# --- Player-like params (set these to match your Player.gd)
@export var gravity_multiplier: float = 1.0   # will use Player.get_gravity_multiplier() if present
@export var thrust_accel: float = 1800.0
@export var max_speed: float = 1200.0
@export var thrust_deadzone_px: float = 6.0
@export var thrust_action: StringName = &"thrust_mouse"  # RMB action

# --- Simulation controls
@export var horizon_time: float = 4.0
@export var step: float = 1.0 / 120.0
@export var resample_every: float = 0.05

# --- Drawing (dotted)
@export var color: Color = Color(1, 1, 1, 0.9)
@export var width: float = 1.6
@export var dash_len: float = 10.0
@export var gap_len: float = 6.0
@export var fade_tail: bool = true
@export var dash_scroll_speed: float = 80.0   # pixels per second; negative phase makes dashes slide backward
var _dash_phase: float = 0.0                  # [0, period) phase used to offset the pattern each frame


var _body: CharacterBody2D
var _pts: PackedVector2Array = PackedVector2Array()
var _timer: float = 0.0

func _ready() -> void:
	_body = get_node_or_null(body_path) as CharacterBody2D
	set_process(true)

func _process(dt: float) -> void:
	if _body == null:
		return
	_timer += dt

	# period = dash + gap; decrease phase so dashes move "backward" along the path with time
	var period: float = dash_len + gap_len
	if period > 0.0:
		_dash_phase = fposmod(_dash_phase - dash_scroll_speed * dt, period)

	if _timer >= resample_every:
		_timer = 0.0
		_recompute()
	queue_redraw()



func _recompute() -> void:
	_pts.clear()
	if _body == null:
		return

	# Copy current state
	var p: Vector2 = _body.global_position
	var v: Vector2 = _body.velocity

	# Read player's gravity multiplier if the helper exists
	var gmult: float = gravity_multiplier
	if _body.has_method("get_gravity_multiplier"):
		gmult = float(_body.get_gravity_multiplier())

	_pts.append(p)

	var h: float = step
	var steps: int = int(ceil(horizon_time / h))

	var thrust_on: bool = false
	var mouse_target: Vector2 = Vector2.ZERO
	if include_thrust:
		thrust_on = Input.is_action_pressed(thrust_action)
		mouse_target = get_global_mouse_position()

	for i: int in range(steps):
		# Gravity at p
		var a: Vector2 = _accel_at(p) * gmult

		# Thrust toward mouse (only if enabled)
		if thrust_on:
			var to_mouse: Vector2 = mouse_target - p
			var d: float = to_mouse.length()
			if d > thrust_deadzone_px:
				a += (to_mouse / d) * thrust_accel

		# Velocity-Verlet
		var x_next: Vector2 = p + v * h + 0.5 * a * h * h
		var a_next: Vector2 = _accel_at(x_next) * gmult
		v += 0.5 * (a + a_next) * h

		# Clamp like player
		if v.length() > max_speed:
			v = v.normalized() * max_speed

		p = x_next
		_pts.append(p)

func _draw() -> void:
	if _pts.size() < 2:
		return

	var total: float = _polyline_length_world(_pts)
	if total <= 0.0:
		return

	# Start the dash pattern at a negative offset so it appears to slide backward with time.
	# Convert that offset into the current position within the [0, period) cycle.
	var period: float = dash_len + gap_len
	var start_offset: float = -_dash_phase   # negative offset pushes dashes backward with time

	var cur_dist: float = start_offset
	var draw_dash: bool = true
	var remaining: float = dash_len

	if period > 0.0:
		# Where inside the pattern are we, at s = 0?
		var offset_in_cycle: float = fposmod(-start_offset, period)   # [0, period)
		# Are we currently inside a dash or a gap?
		draw_dash = (offset_in_cycle < dash_len)
		# How much of the current dash/gap is left before switching?
		if draw_dash:
			remaining = dash_len - offset_in_cycle
		else:
			remaining = period - offset_in_cycle  # same as gap_len - (offset_in_cycle - dash_len)

	var from: Vector2 = _pts[0]
	var i: int = 1

	while cur_dist < total and i < _pts.size():
		var to: Vector2 = _pts[i]
		var seg_vec: Vector2 = to - from
		var seg_len: float = seg_vec.length()
		if seg_len <= 0.0:
			i += 1
			from = to
			continue

		var dir: Vector2 = seg_vec / seg_len
		var left: float = seg_len

		while left > 0.0:
			var take: float = min(remaining, left)
			# Only draw the dash portion; skip the gap
			if draw_dash and cur_dist + take > 0.0:
				var a: Vector2 = to_local(from)
				var b: Vector2 = to_local(from + dir * take)
				var c: Color = color
				if fade_tail:
					var head_dist: float = max(0.0, cur_dist)
					var tail_dist: float = max(0.0, cur_dist + take)
					var t_mid: float = (head_dist + tail_dist) / total
					c.a = lerp(1.0, 0.0, t_mid)
				draw_line(a, b, c, width)

			from += dir * take
			left -= take
			cur_dist += take

			# Switch between dash and gap when the current segment is consumed
			if take >= remaining - 1e-6:
				draw_dash = not draw_dash
				remaining = dash_len if draw_dash else gap_len
			else:
				remaining -= take

		if left <= 0.0:
			i += 1
			if i < _pts.size():
				from = _pts[i - 1]



func _polyline_length_world(pts: PackedVector2Array) -> float:
	var L: float = 0.0
	for i: int in range(1, pts.size()):
		L += pts[i].distance_to(pts[i - 1])
	return L

# --- Gravity helpers (same softened gravity you use elsewhere)
func _accel_at(pos: Vector2) -> Vector2:
	var acc: Vector2 = Vector2.ZERO
	if max_contributors <= 0:
		for n: Node2D in GravityWorld.bodies:
			var src: CelestialBody = n as CelestialBody
			if src == null: continue
			if n == _body: continue
			acc += _softened_accel_from(src, pos)
	else:
		var picks: Array[Dictionary] = []
		for n: Node2D in GravityWorld.bodies:
			var src: CelestialBody = n as CelestialBody
			if src == null: continue
			if n == _body: continue
			var a_vec: Vector2 = _softened_accel_from(src, pos)
			picks.append({ "mag": a_vec.length(), "vec": a_vec })
		picks.sort_custom(func(a, b): return (a["mag"] as float) > (b["mag"] as float))
		var take: int = min(max_contributors, picks.size())  # <-- int, not float
		for j: int in range(take):
			acc += picks[j]["vec"] as Vector2
	return acc

func _softened_accel_from(src: CelestialBody, at_pos: Vector2) -> Vector2:
	var rvec: Vector2 = src.global_position - at_pos
	var r2: float = rvec.length_squared()
	if r2 <= 0.0: 
		return Vector2.ZERO
	var eps: float = max(base_softening, 0.5 * src.radius)
	var denom: float = pow(r2 + eps * eps, 1.5)
	return (G * src.mass) * rvec / denom
