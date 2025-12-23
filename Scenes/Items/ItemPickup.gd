extends Area2D
class_name ItemPickup

# ====================================================
# ITEM DATA (SET PER SCENE)
# ====================================================
@export var item_id: String = ""           # e.g. "scrap", "energy_cell"
@export var item_amount: int = 1
@export var pickup_sound: AudioStream = null

# ====================================================
# MOTION / SCATTER
# ====================================================
@export var initial_speed_min: float = 80.0
@export var initial_speed_max: float = 220.0
@export var damping: float = 10.0
@export var stop_speed: float = 8.0

# ====================================================
# MAGNET ATTRACTION
# ====================================================
@export var attract_radius: float = 240.0
@export var attract_strength: float = 1200.0
@export var max_attract_speed: float = 700.0
@export var magnet_delay: float = 0.25

# ====================================================
# STATE
# ====================================================
var _vel: Vector2 = Vector2.ZERO
var _collected: bool = false
var _player: Node2D = null
var _magnet_timer: float = 0.0

# ====================================================
# LIFECYCLE
# ====================================================
func _ready() -> void:
	body_entered.connect(_on_body_entered)

	_player = get_tree().get_first_node_in_group("player") as Node2D
	_magnet_timer = magnet_delay

	_apply_initial_impulse()
	_init_visuals()


@onready var sprite := $AnimatedSprite2D

func _init_visuals() -> void:
	sprite.play("default")
	sprite.frame = randi_range(0, sprite.sprite_frames.get_frame_count("default") - 1)
	sprite.pause()

# ====================================================
# INITIAL SCATTER
# ====================================================
func _apply_initial_impulse() -> void:
	var dir := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var spd := randf_range(initial_speed_min, initial_speed_max)
	_vel = dir * spd

# ====================================================
# PHYSICS
# ====================================================
func _physics_process(delta: float) -> void:
	if _collected:
		return

	if _magnet_timer > 0.0:
		_magnet_timer -= delta
	else:
		_apply_magnet(delta)

	global_position += _vel * delta

	_vel = _vel.lerp(Vector2.ZERO, clampf(delta * damping, 0.0, 1.0))
	if _vel.length() < stop_speed:
		_vel = Vector2.ZERO

# ====================================================
# MAGNET
# ====================================================
func _apply_magnet(delta: float) -> void:
	if _player == null:
		return

	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if dist <= 0.001 or dist > attract_radius:
		return

	var dir := to_player / dist
	var pull := attract_strength * (1.0 - dist / attract_radius)

	_vel += dir * pull * delta
	_vel = _vel.limit_length(max_attract_speed)

# ====================================================
# PICKUP
# ====================================================
func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return

	_collected = true
	_on_collected(body)
	_play_pickup_sound()
	queue_free()

# Override THIS for special item behaviour
func _on_collected(_player: Node) -> void:
	if item_id != "":
		ResourceManager.add(item_id, item_amount)

# ====================================================
# SOUND
# ====================================================
func _play_pickup_sound() -> void:
	if pickup_sound == null:
		return

	var audio := AudioStreamPlayer.new()
	audio.stream = pickup_sound
	audio.bus = &"SFX"
	audio.volume_db = -6.0 + randf_range(-1.5, 1.5)
	audio.pitch_scale = randf_range(0.95, 1.05)
	audio.process_mode = Node.PROCESS_MODE_ALWAYS

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	parent.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

# ====================================================
# EXTERNAL IMPULSE (ENEMY PUSH)
# ====================================================
func apply_impulse(dir: Vector2, speed: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	_vel += dir.normalized() * speed
