extends Node
class_name PlayerHealth

@export var max_health: int = 200

@export var hit_pause_duration: float = 0.5
@export var hit_effect_duration: float = 0.4
@export var hit_effect_scale: float = 1.0
@export var invincibility_time: float = 1.0

@export var body_sprite: Sprite2D
@export var hit_effect_sprite: Sprite2D

var player: CharacterBody2D = null
var health: int = 0
var _is_hit_stopping: bool = false
var _invincible_timer: float = 0.0
var hit_rot: float = 0.0

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if player == null:
		push_error("PlayerHealth must be a child of a CharacterBody2D.")
		return

	health = max_health
	if hit_effect_sprite != null:
		hit_effect_sprite.visible = false

func _physics_process(delta: float) -> void:
	if hit_effect_sprite != null:
		hit_effect_sprite.global_rotation = hit_rot

	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		if _invincible_timer < 0.0:
			_invincible_timer = 0.0

func take_damage(amount: int) -> void:
	if _invincible_timer > 0.0:
		return

	_invincible_timer = invincibility_time

	health -= amount
	print(str(player.name) + " took " + str(amount) + " damage, remaining health: " + str(health))

	hit_rot = randf()

	if body_sprite != null:
		_flash_red(body_sprite)
	_play_hit_effect()
	_start_hit_stop(hit_pause_duration)

	if health <= 0:
		_die()

func _flash_red(sprite: Sprite2D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0), 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.1)

func _die() -> void:
	print(str(player.name) + " has died")
	health = max_health
	if player != null:
		player.global_position = Vector2(0.0, 0.0)
		player.velocity = Vector2.ZERO

func _play_hit_effect() -> void:
	if hit_effect_sprite == null:
		return

	hit_effect_sprite.visible = true
	hit_effect_sprite.scale = Vector2.ONE * hit_effect_scale
	hit_effect_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween: Tween = create_tween()

	var in_time: float = hit_effect_duration * 0.01
	var out_time: float = hit_effect_duration 

	tween.tween_property(hit_effect_sprite, "modulate:a", 1.0, in_time)
	tween.tween_property(hit_effect_sprite, "modulate:a", 1.0, out_time)
	tween.tween_property(hit_effect_sprite, "modulate:a", 0.0, 0.01)
	tween.finished.connect(Callable(self, "_on_hit_effect_tween_finished"))

func _on_hit_effect_tween_finished() -> void:
	if hit_effect_sprite == null:
		return
	hit_effect_sprite.visible = false

func _start_hit_stop(duration: float) -> void:
	if _is_hit_stopping:
		return

	_is_hit_stopping = true
	_do_hit_stop(duration)

func _do_hit_stop(duration: float) -> void:
	# Start in deep slow motion (not full freeze, so particles/tweens still move a bit)
	var min_scale: float = 0.01       # how slow it gets (0.05 = 20x slowdown)
	var ramp_down_time: float = 0.01  # how fast to enter slow motion
	var ramp_up_time: float = 0.01    # how long to return to normal speed

	# --- Ramp into slow motion ---
	var tween_down: Tween = create_tween()
	tween_down.tween_property(Engine, "time_scale", min_scale, ramp_down_time)

	# --- Stay slowed ---
	var timer: SceneTreeTimer = get_tree().create_timer(duration, false, true)
	await timer.timeout

	# --- Ramp back up ---
	var tween_up: Tween = create_tween()
	tween_up.tween_property(Engine, "time_scale", 1.0, ramp_up_time)
	await tween_up.finished

	_is_hit_stopping = false
