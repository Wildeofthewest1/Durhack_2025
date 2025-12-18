extends Node
class_name PlayerHealth

signal health_changed(new_health: int, max_health: int)
signal shield_changed(new_shield: int, max_shield: int)
signal died()

@export var max_health: int = 200

@export var max_shield: int = 100
@export var shield_regen_per_second: float = 30.0
@export var shield_regen_delay: float = 3.0

@export var hit_pause_duration: float = 0.5
@export var hit_effect_duration: float = 0.4
@export var hit_effect_scale: float = 1.0
@export var invincibility_time: float = 1.0

@export var body_sprite: Sprite2D
@export var trail_line: Line2D
@export var hit_effect_sprite: GPUParticles2D

var player: CharacterBody2D = null
var health: int = 0
var shield: int = 0

var _is_hit_stopping: bool = false
var _invincible_timer: float = 0.0
var _out_of_combat_timer: float = 0.0
var _shield_regen_accum: float = 0.0

var hit_rot: float = 0.0

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if player == null:
		push_error("PlayerHealth must be a child of a CharacterBody2D.")
		return

	health = max_health
	shield = max_shield
	_shield_regen_accum = 0.0
	health_changed.emit(health, max_health)
	shield_changed.emit(shield, max_shield)

func _physics_process(delta: float) -> void:
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		if _invincible_timer < 0.0:
			_invincible_timer = 0.0

	if _out_of_combat_timer > 0.0:
		_out_of_combat_timer -= delta
		if _out_of_combat_timer < 0.0:
			_out_of_combat_timer = 0.0
	else:
		_regen_shield(delta)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	if _invincible_timer > 0.0:
		return

	_out_of_combat_timer = shield_regen_delay
	_shield_regen_accum = 0.0 # optional: makes regen “clean” after delay

	_invincible_timer = invincibility_time

	var remaining: int = amount

	if shield > 0:
		var shield_before: int = shield
		shield -= remaining
		if shield < 0:
			remaining = -shield
			shield = 0
		else:
			remaining = 0

		if shield != shield_before:
			shield_changed.emit(shield, max_shield)

	if remaining > 0:
		health -= remaining
		health_changed.emit(health, max_health)

	print(str(player.name) + " took " + str(amount) + " damage, shield: " + str(shield) + ", health: " + str(health))

	hit_rot = randf()

	if body_sprite != null:
		_flash_red(body_sprite)
	_play_hit_effect()
	_start_hit_stop(hit_pause_duration)

	if health <= 0:
		_die()

func _regen_shield(delta: float) -> void:
	if shield >= max_shield:
		_shield_regen_accum = 0.0
		return
	if shield_regen_per_second <= 0.0:
		return

	_shield_regen_accum += shield_regen_per_second * delta

	var add_i: int = int(floor(_shield_regen_accum))
	if add_i <= 0:
		return

	_shield_regen_accum -= float(add_i)

	var before: int = shield
	shield = min(shield + add_i, max_shield)
	if shield != before:
		shield_changed.emit(shield, max_shield)

# --- rest of your functions unchanged ---
func _flash_red(sprite: Sprite2D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0), 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.1)

func _die() -> void:
	print(str(player.name) + " has died")
	died.emit()

	body_sprite.visible = false
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	Screenshake.shake(2)

	await get_tree().create_timer(1.0).timeout

	health = max_health
	shield = max_shield
	_out_of_combat_timer = 0.0
	_invincible_timer = 0.0
	_shield_regen_accum = 0.0

	health_changed.emit(health, max_health)
	shield_changed.emit(shield, max_shield)

	body_sprite.visible = true
	trail_line.visible = true
	player.set_physics_process(true)

	if player != null:
		player.get_child(0).fuel = player.get_child(0).fuel_max
		player.global_position = Vector2(500.0, 0.0)
		player.velocity = Vector2(0.0, 200.0)
		trail_line._pts = []
		trail_line.clear_points()

func _play_hit_effect() -> void:
	if hit_effect_sprite == null:
		return
	Screenshake.shake(1)
	hit_effect_sprite.visible = true
	hit_effect_sprite.emitting = true

func _start_hit_stop(duration: float) -> void:
	if _is_hit_stopping:
		return
	_is_hit_stopping = true
	_do_hit_stop(duration)

func _do_hit_stop(duration: float) -> void:
	var min_scale: float = 0.01
	var ramp_down_time: float = 0.01
	var ramp_up_time: float = 0.01

	var tween_down: Tween = create_tween()
	tween_down.tween_property(Engine, "time_scale", min_scale, ramp_down_time)

	var timer: SceneTreeTimer = get_tree().create_timer(duration, false, true)
	await timer.timeout

	var tween_up: Tween = create_tween()
	tween_up.tween_property(Engine, "time_scale", 1.0, ramp_up_time)
	await tween_up.finished

	_is_hit_stopping = false
