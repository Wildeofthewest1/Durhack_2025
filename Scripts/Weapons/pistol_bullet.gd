extends CharacterBody2D

@export var muzzle_speed: float = 1400.0
@export var lifetime: float = 2.5
@export var damage: int = 10
@export var gravity_multiplier: float = 1.0
@export var inherit_shooter_velocity: bool = true
@export var rotate_with_motion: bool = true

@export var gravity_sensor_path: NodePath
var gread: Node
var _accel_func: String = ""   # which method we're using

var _dir: Vector2 = Vector2.RIGHT
var _start_pos: Vector2

func _ready() -> void:
	if gravity_sensor_path != NodePath():
		gread = get_node_or_null(gravity_sensor_path)
	if gread == null:
		gread = get_tree().get_first_node_in_group("gravity_sensor")
	
	# Pick the best gravity API available on your sensor
	if gread != null:
		if "compute_accel_at" in gread:
			_accel_func = "compute_accel_at"
		elif "compute_accel_for" in gread:
			_accel_func = "compute_accel_for"
		elif "compute_accel_now" in gread:
			_accel_func = "compute_accel_now"
		else:
			push_warning("[Bullet] Gravity sensor has no known methods; no gravity will apply.")
	else:
		push_warning("[Bullet] No gravity sensor found (group 'gravity_sensor'); no gravity will apply.")

	# Log once so we know what’s happening
	var test_accel := _get_accel()
	print("[Bullet] gravity via=", _accel_func, " accel=", test_accel, " mag=", test_accel.length())

	_start_pos = global_position
	await get_tree().create_timer(lifetime).timeout
	queue_free()

# Call right after instancing
func setup(dir: Vector2, shooter_velocity: Vector2 = Vector2.ZERO) -> void:
	_dir = dir.normalized()
	velocity = _dir * muzzle_speed + (shooter_velocity if inherit_shooter_velocity else Vector2.ZERO)
	if rotate_with_motion and velocity != Vector2.ZERO:
		rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	# Apply gravity each frame
	var a := _get_accel()
	if a != Vector2.ZERO:
		velocity += a * gravity_multiplier * delta
	
	# Move; detect a hit this frame
	var collision := move_and_collide(velocity * delta)
	if collision:
		var hit := collision.get_collider()
		if hit and "apply_damage" in hit:
			hit.apply_damage(damage)
		queue_free()
		return

	if rotate_with_motion and velocity != Vector2.ZERO:
		rotation = velocity.angle()

func _get_accel() -> Vector2:
	if gread == null or _accel_func == "":
		return Vector2.ZERO
	match _accel_func:
		"compute_accel_at":
			return gread.compute_accel_at(global_position)
		"compute_accel_for":
			return gread.compute_accel_for(global_position)
		"compute_accel_now":
			# Falls back to sensor’s own reading (uniform fields still work)
			return gread.compute_accel_now()
		_:
			return Vector2.ZERO
