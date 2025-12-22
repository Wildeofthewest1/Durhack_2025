extends Area2D
class_name ScrapPickup

@export var scrap_amount: int = 1
@export var pickup_sound: AudioStream = null

# Motion
@export var initial_speed_min: float = 80.0
@export var initial_speed_max: float = 220.0
@export var damping: float = 10.0
@export var stop_speed: float = 8.0

# Random frame variant
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _collected: bool = false
var _vel: Vector2 = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Pick one of 4 frames (default anim)
	sprite.play("default")
	var frame_count: int = sprite.sprite_frames.get_frame_count("default")
	if frame_count > 0:
		sprite.frame = randi_range(0, frame_count - 1)
	sprite.pause()

	# Random initial “pop” velocity
	var dir: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var spd: float = randf_range(initial_speed_min, initial_speed_max)
	_vel = dir * spd

func _physics_process(delta: float) -> void:
	if _collected:
		return

	# Move
	global_position += _vel * delta

	# Damping toward zero
	_vel = _vel.lerp(Vector2.ZERO, clampf(delta * damping, 0.0, 1.0))

	if _vel.length() < stop_speed:
		_vel = Vector2.ZERO

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return

	_collected = true
	ResourceManager.add("scrap", scrap_amount)
	_play_pickup_sound_global()
	queue_free()

func _play_pickup_sound_global() -> void:
	if pickup_sound == null:
		return

	var audio: AudioStreamPlayer = AudioStreamPlayer.new()
	audio.stream = pickup_sound
	audio.bus = &"SFX"
	audio.volume_db = -6.0 + randf_range(-1.5, 1.5)
	audio.pitch_scale = randf_range(0.95, 1.05)
	audio.process_mode = Node.PROCESS_MODE_ALWAYS

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root

	parent_node.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

# Call this from enemy when spawning to push directionally
func apply_impulse(dir: Vector2, speed: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	_vel += dir.normalized() * speed
