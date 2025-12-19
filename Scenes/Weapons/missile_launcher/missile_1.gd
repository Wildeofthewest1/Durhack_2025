extends CharacterBody2D
class_name MissileProjectile

# --- GENERAL SETTINGS ---
@export var life_time: float = 5.0
@export var damage: float = 20.0

# --- STARTUP PHASE ---
@export var startup_time: float = 0.4
@export var startup_speed: float = 350.0

# --- HOMING SPEEDS ---
@export var fast_seek_speed: float = 700.0   # when target in cone
@export var slow_seek_speed: float = 350.0   # when only target in circle
@export var acceleration: float = 900.0      # how quickly velocity approaches target speed

# --- TURNING ---
@export var turn_speed_deg: float = 360.0    # degrees per second

# --- PREDICTIVE AIMING ---
@export var predictive_aim: bool = true
@export var max_lead_time: float = 1.25      # seconds (clamps how far ahead we lead)
@export var lead_blend: float = 1.0          # 0 = no lead, 1 = full lead

# --- DETECTION (CONE + CIRCLE) ---
@export var cone_angle_deg: float = 30.0     # half-angle of cone
@export var cone_radius: float = 600.0
@export var circle_radius: float = 900.0

# --- GROUP NAME FOR ENEMIES ---
@export var enemy_group: StringName = "Enemy"

# --- STATE ENUM ---
const STATE_STARTUP: int = 0
const STATE_SEEK: int = 1

# --- INTERNAL ---
var _state: int = STATE_STARTUP
var _life_timer: float = 0.0
var _startup_timer: float = 0.0
var _forward: Vector2 = Vector2.RIGHT
var _current_target: Node2D = null
var _cached_cone_cos: float = 0.0

# For velocity estimation when target isn't a physics body
var _target_last_pos: Dictionary = {}   # ObjectID -> Vector2
var _target_last_vel: Dictionary = {}   # ObjectID -> Vector2

# --- EXPLOSION SCENE (OPTIONAL) ---
@export var explosion_scene: PackedScene
@onready var _trail: GPUParticles2D = $smoke

func _ready() -> void:
	_life_timer = life_time
	_startup_timer = startup_time
	_cached_cone_cos = cos(deg_to_rad(cone_angle_deg))
	# wait for initialize() to set direction/velocity

func initialize(initial_direction: Vector2) -> void:
	var dir: Vector2 = initial_direction
	if dir.length() == 0.0:
		dir = Vector2.RIGHT

	_forward = dir.normalized()
	velocity = _forward * startup_speed
	rotation = _forward.angle()

func _physics_process(delta: float) -> void:
	# Lifetime
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()
		return

	match _state:
		STATE_STARTUP:
			_process_startup(delta)
		STATE_SEEK:
			_process_seek(delta)

	# Collision (like twin bullet)
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision != null:
		_handle_collision(collision)
		return

# --- STATE LOGIC ---

func _process_startup(delta: float) -> void:
	_startup_timer -= delta
	velocity = _forward * startup_speed

	if _startup_timer <= 0.0:
		_acquire_initial_target()
		_state = STATE_SEEK

func _process_seek(delta: float) -> void:
	# If current target is invalid, clear it
	if _current_target != null:
		if not is_instance_valid(_current_target):
			_current_target = null

	# If we do not currently have a target, try to acquire one
	if _current_target == null:
		_acquire_initial_target()
		if _current_target == null:
			# no target: just keep cruising forward at slow speed
			_accelerate_forward(delta, slow_seek_speed)
			return

	# At this point, we have a target (sticky until it leaves range/angle)
	var in_cone: bool = _is_in_cone(_current_target)
	var in_circle: bool = _is_in_circle(_current_target)

	if not in_cone and not in_circle:
		_current_target = null
		_acquire_initial_target()
		if _current_target == null:
			_accelerate_forward(delta, slow_seek_speed)
			return

		in_cone = _is_in_cone(_current_target)
		in_circle = _is_in_circle(_current_target)

	# Choose speed based on where the (sticky) target is
	if in_cone:
		_home_towards_target(delta, _current_target, fast_seek_speed)
	elif in_circle:
		_home_towards_target(delta, _current_target, slow_seek_speed)
	else:
		_accelerate_forward(delta, slow_seek_speed)

func _acquire_initial_target() -> void:
	# Prefer a cone target; otherwise use circle
	var cone_target: Node2D = _find_target_in_cone()
	if cone_target != null:
		_current_target = cone_target
		return

	var circle_target: Node2D = _find_target_in_circle()
	if circle_target != null:
		_current_target = circle_target
	else:
		_current_target = null

# --- TARGET SEARCH HELPERS ---

func _find_target_in_cone() -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group(enemy_group)
	var best_target: Node2D = null
	var best_dist_sq: float = INF

	var forward: Vector2 = _forward.normalized()

	for enemy_obj in enemies:
		var enemy: Node2D = enemy_obj as Node2D
		if enemy == null:
			continue

		var to_enemy: Vector2 = enemy.global_position - global_position
		var dist_sq: float = to_enemy.length_squared()
		if dist_sq > cone_radius * cone_radius:
			continue

		var dir_to_enemy: Vector2 = to_enemy.normalized()
		var dot_val: float = forward.dot(dir_to_enemy)
		if dot_val < _cached_cone_cos:
			continue

		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_target = enemy

	return best_target

func _find_target_in_circle() -> Node2D:
	var enemies: Array = get_tree().get_nodes_in_group(enemy_group)
	var best_target: Node2D = null
	var best_dist_sq: float = INF

	for enemy_obj in enemies:
		var enemy: Node2D = enemy_obj as Node2D
		if enemy == null:
			continue

		var to_enemy: Vector2 = enemy.global_position - global_position
		var dist_sq: float = to_enemy.length_squared()
		if dist_sq > circle_radius * circle_radius:
			continue

		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_target = enemy

	return best_target

func _is_in_cone(target: Node2D) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false

	var to_enemy: Vector2 = target.global_position - global_position
	var dist_sq: float = to_enemy.length_squared()
	if dist_sq > cone_radius * cone_radius:
		return false

	var forward: Vector2 = _forward.normalized()
	var dir_to_enemy: Vector2 = to_enemy.normalized()
	var dot_val: float = forward.dot(dir_to_enemy)

	return dot_val >= _cached_cone_cos

func _is_in_circle(target: Node2D) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false

	var to_enemy: Vector2 = target.global_position - global_position
	var dist_sq: float = to_enemy.length_squared()
	return dist_sq <= circle_radius * circle_radius

# --- MOVEMENT HELPERS ---

func _home_towards_target(delta: float, target: Node2D, target_speed: float) -> void:
	if target == null:
		return
	if not is_instance_valid(target):
		return

	#var aim_point: Vector2 = target.global_position
	var aim_point: Vector2 = _get_target_aim_position(target)


	if predictive_aim:
		var target_vel: Vector2 = _get_target_velocity(target, delta)
		#var predicted: Vector2 = _predict_intercept_point(global_position, target.global_position, target_vel, target_speed)
		var aim_origin := _get_target_aim_position(target)
		var predicted: Vector2 = _predict_intercept_point(
			global_position,
			aim_origin,
			target_vel,
			target_speed
		)
		aim_point = aim_point.lerp(predicted, clampf(lead_blend, 0.0, 1.0))

	var to_point: Vector2 = aim_point - global_position
	if to_point.length() == 0.0:
		return

	var desired_dir: Vector2 = to_point.normalized()

	# Smoothly rotate _forward towards desired_dir with a true angular step limit
	var current_angle: float = _forward.angle()
	var desired_angle: float = desired_dir.angle()

	var max_step: float = deg_to_rad(turn_speed_deg) * delta
	var delta_angle: float = wrapf(desired_angle - current_angle, -PI, PI)
	delta_angle = clampf(delta_angle, -max_step, max_step)
	var new_angle: float = current_angle + delta_angle
	_forward = Vector2.RIGHT.rotated(new_angle)
	rotation = new_angle
	_accelerate_forward(delta, target_speed)

func _get_all_hitboxes(target: Node2D) -> Array[CollisionShape2D]:
	var result: Array[CollisionShape2D] = []
	if target == null or not is_instance_valid(target):
		return result
	# Fast path: direct children
	for child in target.get_children():
		if child is CollisionShape2D and child.name.begins_with("HitBox"):
			result.append(child)
	# Fallback: recursive search (only if none found directly)
	if result.is_empty():
		for node in target.find_children("*", "CollisionShape2D", true, false):
			if node.name.begins_with("HitBox"):
				result.append(node)
	return result

func _select_best_hitbox(target: Node2D, missile_pos: Vector2) -> CollisionShape2D:
	var hitboxes := _get_all_hitboxes(target)
	if hitboxes.is_empty():
		return null
	var best: CollisionShape2D = null
	var best_dist_sq := INF
	for hb in hitboxes:
		if not is_instance_valid(hb):
			continue
		var d := hb.global_position.distance_squared_to(missile_pos)
		if d < best_dist_sq:
			best_dist_sq = d
			best = hb
	return best

func _get_target_aim_position(target: Node2D) -> Vector2:
	if target == null or not is_instance_valid(target):
		return global_position

	var hb := _select_best_hitbox(target, global_position)
	if hb != null:
		return hb.global_position

	return target.global_position

func _accelerate_forward(delta: float, target_speed: float) -> void:
	var forward_vec: Vector2 = _forward.normalized()
	var desired_velocity: Vector2 = forward_vec * target_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)

# --- PREDICTION HELPERS ---

func _get_target_velocity(target: Node2D, delta: float) -> Vector2:
	# Prefer real physics velocities if available
	var cb: CharacterBody2D = target as CharacterBody2D
	if cb != null:
		return cb.velocity

	var rb: RigidBody2D = target as RigidBody2D
	if rb != null:
		return rb.linear_velocity

	# Otherwise estimate from position history
	var id: int = target.get_instance_id()
	var pos_now: Vector2 = target.global_position

	var had_prev: bool = _target_last_pos.has(id)
	var pos_prev: Vector2 = pos_now
	if had_prev:
		pos_prev = _target_last_pos[id] as Vector2

	_target_last_pos[id] = pos_now

	var vel: Vector2 = Vector2.ZERO
	if had_prev and delta > 0.0:
		vel = (pos_now - pos_prev) / delta

	_target_last_vel[id] = vel
	return vel

func _predict_intercept_point(missile_pos: Vector2, target_pos: Vector2, target_vel: Vector2, missile_speed: float) -> Vector2:
	# Solve |p + v*t| = s*t
	var p: Vector2 = target_pos - missile_pos
	var v: Vector2 = target_vel
	var s: float = maxf(missile_speed, 0.001)

	var a: float = v.dot(v) - s * s
	var b: float = 2.0 * p.dot(v)
	var c: float = p.dot(p)

	var t: float = 0.0

	if absf(a) < 0.0001:
		# Linear fallback
		if absf(b) > 0.0001:
			t = -c / b
		else:
			t = 0.0
	else:
		var disc: float = b * b - 4.0 * a * c
		if disc >= 0.0:
			var sqrt_disc: float = sqrt(disc)
			var t1: float = (-b - sqrt_disc) / (2.0 * a)
			var t2: float = (-b + sqrt_disc) / (2.0 * a)

			# Smallest positive time
			t = INF
			if t1 > 0.0:
				t = t1
			if t2 > 0.0 and t2 < t:
				t = t2

			if t == INF:
				t = 0.0
		else:
			t = 0.0

	if t < 0.0:
		t = 0.0
	t = minf(t, max_lead_time)

	return target_pos + target_vel * t

# --- COLLISION / EXPLOSION ---

func _handle_collision(collision: KinematicCollision2D) -> void:
	var target: Object = collision.get_collider()
	if target != null:
		if target.is_in_group(enemy_group):
			if target.has_method("take_damage"):
				target.call("take_damage", damage)
		elif "team" in target:
			var team_string: String = String(target.team)
			if team_string == String(enemy_group) and target.has_method("take_damage"):
				target.call("take_damage", damage)

	_spawn_explosion()
	_die()

func _die() -> void:
	_detach_trail()
	queue_free()

func _detach_trail() -> void:
	if _trail == null:
		return

	_trail.emitting = false

	var world_root: Node = get_parent()

	var parent: Node = _trail.get_parent()
	if parent != null:
		parent.remove_child(_trail)
	world_root.add_child(_trail)
	_trail.global_position = global_position

	var timer: Timer = Timer.new()
	timer.wait_time = 10.0
	timer.one_shot = true
	world_root.add_child(timer)

	var trail_ref: GPUParticles2D = _trail

	timer.timeout.connect(func() -> void:
		if is_instance_valid(trail_ref):
			trail_ref.queue_free()
		timer.queue_free()
	)

func _spawn_explosion() -> void:
	if explosion_scene == null:
		return
	var explosion_instance: Node2D = explosion_scene.instantiate() as Node2D
	explosion_instance.global_position = global_position
	get_parent().add_child(explosion_instance)
	explosion_instance.emitting = true
