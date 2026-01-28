extends Node
class_name PlayerHealth

signal health_changed(new_health: int, max_health: int)
signal shield_changed(new_shield: int, max_shield: int)
signal died()

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

var max_health: float = 0.0
var max_shield: float = 0.0

var health: float = 0.0
var shield: float = 0.0

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

	# Initialize from PlayerVariables once
	max_health = PlayerVariables.get_value(&"max_hp")
	max_shield = PlayerVariables.get_value(&"max_shield")

	health = max_health
	shield = max_shield
	_shield_regen_accum = 0.0

	health_changed.emit(int(health), int(max_health))
	shield_changed.emit(int(shield), int(max_shield))

	# React to changes in max stats
	if PlayerVariables != null and PlayerVariables.has_signal("stats_changed"):
		var cb: Callable = Callable(self, "_on_stats_changed")
		if not PlayerVariables.stats_changed.is_connected(cb):
			PlayerVariables.stats_changed.connect(cb)
			print("connecting stats to player")


func _on_stats_changed(stat_ids: Array) -> void:
	print("stat change detected on player side: ", stat_ids)

	var hp_changed: bool = false
	var sh_changed: bool = false

	for sid in stat_ids:
		var s: StringName = StringName(sid)
		if s == &"max_hp":
			hp_changed = true
		elif s == &"max_shield":
			sh_changed = true

	if hp_changed:
		_apply_new_max_health(PlayerVariables.get_value(&"max_hp"))

	if sh_changed:
		_apply_new_max_shield(PlayerVariables.get_value(&"max_shield"))


func _apply_new_max_health(new_max: float) -> void:
	var old_max: float = max_health
	if new_max == old_max:
		return

	max_health = new_max

	var delta: float = new_max - old_max
	health += delta

	if health > max_health:
		health = max_health
	if health < 0.0:
		health = 0.0

	health_changed.emit(int(health), int(max_health))


func _apply_new_max_shield(new_max: float) -> void:
	var old_max: float = max_shield
	if new_max == old_max:
		return

	max_shield = new_max

	var delta: float = new_max - old_max
	shield += delta

	if shield > max_shield:
		shield = max_shield
	if shield < 0.0:
		shield = 0.0

	shield_changed.emit(int(shield), int(max_shield))


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
	_shield_regen_accum = 0.0
	_invincible_timer = invincibility_time

	var remaining: float = float(amount)

	if shield > 0.0:
		var shield_before: float = shield
		shield -= remaining
		if shield < 0.0:
			remaining = -shield
			shield = 0.0
		else:
			remaining = 0.0

		if shield != shield_before:
			shield_changed.emit(int(shield), int(max_shield))

	if remaining > 0.0:
		health -= remaining
		if health < 0.0:
			health = 0.0
		health_changed.emit(int(health), int(max_health))

	print(str(player.name) + " took " + str(amount) + " damage, shield: " + str(int(shield)) + ", health: " + str(int(health)))

	hit_rot = randf()

	if body_sprite != null:
		_flash_red(body_sprite)
	_play_hit_effect()
	_start_hit_stop(hit_pause_duration)

	if health <= 0.0:
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

	var before: float = shield
	shield = min(shield + float(add_i), max_shield)
	if shield != before:
		shield_changed.emit(int(shield), int(max_shield))


func _flash_red(sprite: Sprite2D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0), 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.1)


func _die() -> void:
	print(str(player.name) + " has died")
	died.emit()

	if body_sprite != null:
		body_sprite.visible = false
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	Screenshake.shake(2)

	await get_tree().create_timer(1.0).timeout

	# Re-read max values (in case stats changed while dead)
	max_health = PlayerVariables.get_value(&"max_hp")
	max_shield = PlayerVariables.get_value(&"max_shield")

	health = max_health
	shield = max_shield
	_out_of_combat_timer = 0.0
	_invincible_timer = 0.0
	_shield_regen_accum = 0.0

	health_changed.emit(int(health), int(max_health))
	shield_changed.emit(int(shield), int(max_shield))

	if body_sprite != null:
		body_sprite.visible = true
	if trail_line != null:
		trail_line.visible = true

	player.set_physics_process(true)

	if player != null:
		# Restore fuel safely (no has_variable in Godot 4)
		if player.get_child_count() > 0:
			var child0: Node = player.get_child(0)
			if child0 != null and is_instance_valid(child0):
				var fuel_max_v: Variant = _safe_get(child0, &"fuel_max")
				if fuel_max_v != null:
					_safe_set(child0, &"fuel", fuel_max_v)

		player.global_position = Vector2(500.0, 0.0)
		player.velocity = Vector2(0.0, 200.0)

		if trail_line != null:
			# Clear points safely
			var pts_v: Variant = _safe_get(trail_line, &"_pts")
			if pts_v != null:
				_safe_set(trail_line, &"_pts", [])
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


# -------------------------------------------------------------------
# Safe property helpers (Godot 4 compatible)
# -------------------------------------------------------------------

func _has_property(obj: Object, prop: StringName) -> bool:
	if obj == null:
		return false
	var props: Array = obj.get_property_list()
	for p in props:
		var d: Dictionary = p as Dictionary
		if d.has("name") and StringName(d["name"]) == prop:
			return true
	return false

func _safe_get(obj: Object, prop: StringName) -> Variant:
	if _has_property(obj, prop):
		return obj.get(String(prop))
	return null

func _safe_set(obj: Object, prop: StringName, value: Variant) -> bool:
	if _has_property(obj, prop):
		obj.set(String(prop), value)
		return true
	return false
