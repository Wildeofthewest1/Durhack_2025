extends CharacterBody2D
class_name SwordBlade

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _glow_sprite: AnimatedSprite2D = $GlowSprite2D
@onready var _hitbox: Area2D = $Hitbox
@onready var _trail: Node = $Trail
@onready var _trail_line: Line2D = $Trail as Line2D

@onready var _slash_sound: AudioStreamPlayer2D = $SlashSound
@onready var _impact_sound: AudioStreamPlayer2D = $ImpactSound
@onready var _crackle_sound: AudioStreamPlayer2D = $CrackleSound

@export var life_time: float = 0.39
@export var explosion: PackedScene = preload("res://Scenes/particles/explosion.tscn")
@export var trail_particles: PackedScene = preload("res://Scenes/particles/trail_particles.tscn")
@export var trail_enabled: bool = true

@export var visual_rotation_offset_deg: float = 0.0
@export var face_aim_instead_of_velocity: bool = true

@export var enable_spawn_pulse: bool = true
@export var enable_fade_out: bool = true
@export var fade_out_time: float = 0.08
@export var glow_colour: Color = Color("d848a5")
@export var glow_alpha: float = 0.75
@export var glow_scale_boost: float = 1.2
@export var sprite_stretch_scale: Vector2 = Vector2(1.2, 0.85)

@export var play_spawn_sound: bool = true
@export var play_impact_sound: bool = true
@export var play_crackle_sound: bool = true
@export var crackle_on_spawn: bool = true

var _velocity_vec: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _life_timer: float = 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _knockback: float = 100.0
var _spawned_particles: GPUParticles2D = null
var _hit_bodies := {}

func _ready() -> void:
	_life_timer = life_time

	if _hitbox != null:
		_hitbox.body_entered.connect(_on_hitbox_body_entered)

	if _trail_line != null:
		_trail_line.visible = trail_enabled

	if trail_particles != null:
		var trailer: GPUParticles2D = trail_particles.instantiate() as GPUParticles2D
		get_parent().add_child(trailer)
		trailer.follower = self
		_spawned_particles = trailer

	if _sprite != null:
		_sprite.visible = true

	if _glow_sprite != null and _sprite != null:
		_glow_sprite.sprite_frames = _sprite.sprite_frames
		_glow_sprite.animation = _sprite.animation
		_glow_sprite.frame = _sprite.frame
		_glow_sprite.flip_h = _sprite.flip_h
		_glow_sprite.flip_v = _sprite.flip_v
		_glow_sprite.modulate = Color(glow_colour.r, glow_colour.g, glow_colour.b, glow_alpha)
		_glow_sprite.scale = Vector2.ONE
		_glow_sprite.z_index = _sprite.z_index - 1

func _process(_delta: float) -> void:
	if _glow_sprite != null and _sprite != null:
		_glow_sprite.animation = _sprite.animation
		_glow_sprite.frame = _sprite.frame
		_glow_sprite.flip_h = _sprite.flip_h
		_glow_sprite.flip_v = _sprite.flip_v

	if enable_fade_out and life_time > 0.0 and _life_timer <= fade_out_time:
		var t = clamp(_life_timer / max(fade_out_time, 0.001), 0.0, 1.0)

		if _sprite != null:
			_sprite.modulate.a = t

		if _glow_sprite != null:
			_glow_sprite.modulate.a = t * glow_alpha

		if _trail_line != null:
			_trail_line.modulate.a = t

func _on_hitbox_body_entered(body: Node) -> void:
	if body == null:
		return

	var is_enemy := false

	if body.is_in_group("Enemy"):
		is_enemy = true
	elif "team" in body:
		if String(body.team) == "Enemy":
			is_enemy = true

	if not is_enemy:
		return

	if _hit_bodies.has(body):
		return

	_hit_bodies[body] = true

	if body.has_method("take_damage"):
		body.take_damage(_damage, _aim_dir, _knockback)

	if play_impact_sound:
		_play_sound_2d(_impact_sound, 0.1,-3,0,1)

	_spawn_explosion()

func initialize_projectile(dir: Vector2, speed: float, dmg: float, carrier_vel: Vector2, knockback: float) -> void:
	_aim_dir = dir.normalized()
	_velocity_vec = carrier_vel + _aim_dir * speed
	_damage = dmg
	_life_timer = life_time
	_knockback = knockback

	if _trail != null and _trail.has_method("reset_to_world_pos"):
		_trail.call("reset_to_world_pos", global_position)

	_update_facing()

	if enable_spawn_pulse:
		_play_spawn_pulse()

	if play_spawn_sound:
		_play_sound_2d(_slash_sound, 0.1, 0, 0, 1)

	if play_crackle_sound and crackle_on_spawn:
		_play_sound_2d(_crackle_sound, 0.1, 0, 0, 1)

func _update_facing() -> void:
	var offset_rad: float = deg_to_rad(visual_rotation_offset_deg)

	var facing_dir: Vector2 = _velocity_vec
	if face_aim_instead_of_velocity:
		facing_dir = _aim_dir

	if facing_dir.length() <= 0.001:
		return

	rotation = facing_dir.angle() + offset_rad

func _physics_process(delta: float) -> void:
	move_and_collide(_velocity_vec * delta)

	_update_facing()

	_life_timer -= delta
	if _life_timer <= 0.0:
		_die()

func _play_spawn_pulse() -> void:
	if _sprite != null:
		_sprite.scale = sprite_stretch_scale
		_sprite.modulate = Color(1.35, 1.35, 1.35, 1.0)

		var tw1 := create_tween()
		tw1.set_parallel(true)
		tw1.tween_property(_sprite, "scale", Vector2.ONE, 0.10)
		tw1.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.12)

	if _glow_sprite != null:
		_glow_sprite.scale = Vector2.ONE * glow_scale_boost
		_glow_sprite.modulate = Color(glow_colour.r, glow_colour.g, glow_colour.b, 1.0)

		var tw2 := create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(_glow_sprite, "scale", Vector2.ONE, 0.12)
		tw2.tween_property(_glow_sprite, "modulate", Color(glow_colour.r, glow_colour.g, glow_colour.b, glow_alpha), 0.12)

func _play_sound_2d(
	template: AudioStreamPlayer2D,
	pitch_random_amount: float = 0.0,
	volume_db_offset: float = 0.0,
	start_time: float = 0.0,
	duration: float = -1.0
) -> void:
	if template == null or template.stream == null:
		return

	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = template.stream
	sfx.bus = template.bus
	sfx.volume_db = template.volume_db + volume_db_offset
	sfx.pitch_scale = template.pitch_scale + randf_range(-pitch_random_amount, pitch_random_amount)
	sfx.max_distance = max(template.max_distance, 4000.0)
	sfx.attenuation = template.attenuation
	sfx.area_mask = template.area_mask

	get_tree().current_scene.add_child(sfx)
	sfx.global_position = global_position
	sfx.play(start_time)

	if duration > 0.0:
		var stop_timer := get_tree().create_timer(duration)
		stop_timer.timeout.connect(func():
			if is_instance_valid(sfx):
				sfx.stop()
				sfx.queue_free()
		)
	else:
		sfx.finished.connect(sfx.queue_free)

func _spawn_explosion() -> void:
	if explosion == null:
		return

	var explo: GPUParticles2D = explosion.instantiate() as GPUParticles2D
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.add_child(explo)
		explo.global_position = global_position
		explo.global_rotation = global_rotation
		explo.scale = Vector2.ONE * 5.0
		explo.emitting = true

func _die() -> void:
	queue_free()
