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
		dir = Vector2.RIGHT   # fallback

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
		# target lost: clear and try to reacquire
		_current_target = null
		_acquire_initial_target()
		if _current_target == null:
			_accelerate_forward(delta, slow_seek_speed)
			return

		# re-evaluate new target
		in_cone = _is_in_cone(_current_target)
		in_circle = _is_in_circle(_current_target)

	# Choose speed based on where the (sticky) target is
	if in_cone:
		_home_towards_target(delta, _current_target, fast_seek_speed)
	elif in_circle:
		_home_towards_target(delta, _current_target, slow_seek_speed)
	else:
		# safety fallback
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
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() == 0.0:
		return

	var desired_dir: Vector2 = to_target.normalized()

	# Smoothly rotate _forward towards desired_dir
	var current_angle: float = _forward.angle()
	var desired_angle: float = desired_dir.angle()

	var max_step: float = deg_to_rad(turn_speed_deg) * delta
	var t: float = max_step
	if t > 1.0:
		t = 1.0
	if t < 0.0:
		t = 0.0

	var new_angle: float = lerp_angle(current_angle, desired_angle, t)

	_forward = Vector2.RIGHT.rotated(new_angle)
	rotation = new_angle

	_accelerate_forward(delta, target_speed)


func _accelerate_forward(delta: float, target_speed: float) -> void:
	var forward_vec: Vector2 = _forward.normalized()
	var desired_velocity: Vector2 = forward_vec * target_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


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

	# Stop emitting new particles, keep existing ones
	_trail.emitting = false

	# Reparent trail to the world so it survives after missile is freed
	var world_root: Node = get_parent()

	var parent: Node = _trail.get_parent()
	if parent != null:
		parent.remove_child(_trail)
	world_root.add_child(_trail)
	_trail.global_position = global_position

	# Create a timer to free the trail after 10 seconds
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
