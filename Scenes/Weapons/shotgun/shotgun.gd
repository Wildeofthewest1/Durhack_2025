extends WeaponBase
class_name WeaponShotgun

@export var muzzle_path: NodePath = NodePath("Muzzle")
@export var spawn_offset_px: float = 20.0

@export var pellets_per_shot: int = 8

# Optional EXTRA spread on top of WeaponData.spread_deg (leave 0 if you don't want extra)
@export var extra_pellet_spread_deg: float = 0.0

@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer

var _muzzle: Node2D = null

func _ready() -> void:
	super._ready()
	_muzzle = get_node(muzzle_path) as Node2D
	_update_aim()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_aim()

func _update_aim() -> void:
	var mouse_world: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_world - global_position
	var dist: float = to_mouse.length()
	if dist > 0.0:
		_aim_dir = to_mouse / dist

# Shotgun special:
# - DO NOT call try_fire() because WeaponBase applies random spread to dir.
# - We want accuracy to tighten the pellet cone, not rotate the whole shot randomly.
func request_fire() -> void:
	if data == null:
		return
	if _is_reloading:
		return
	if _cooldown > 0.0:
		return

	var aim_dir: Vector2 = _aim_dir
	if aim_dir.length_squared() > 0.0:
		aim_dir = aim_dir.normalized()

	# Handle empty-mag logic (copied from WeaponBase.try_fire, unchanged behavior)
	if _current_mag <= 0:
		if data.ammo_model == WeaponData.AmmoModel.INFINITE_WITH_RELOAD:
			_waiting_for_mag = false
			_start_reload()
			return

		if data.ammo_model == WeaponData.AmmoModel.STANDARD:
			if _stored_mags > 0:
				_waiting_for_mag = false
				_consume_stored_and_start_reload()
				return

			_waiting_for_mag = true
			_start_regen_if_needed()
			_emit_ammo()
			return

		return

	_current_mag -= 1
	if _current_mag < 0:
		_current_mag = 0

	_cooldown = get_effective_fire_cooldown()
	_fire_projectile(aim_dir)
	_emit_ammo()

func _fire_projectile(dir: Vector2) -> void:
	if data == null:
		return
	if _muzzle == null:
		push_error("WeaponShotgun: muzzle is missing")
		return
	if data.bullet_scene == null:
		push_error("WeaponShotgun: bullet_scene not set in WeaponData")
		return

	# Player recoil (unchanged)
	get_parent().get_parent().get_parent().global_position += -3.0 * dir.normalized()

	var base_dir: Vector2 = dir.normalized()

	# Accuracy tightens the spray pattern:
	# Use WeaponData.spread_deg as the BASE cone for the shotgun
	var acc: float = float(PlayerVariables.get_value(&"accuracy"))
	if acc <= 0.0:
		acc = 1.0

	var base_half: float = (data.spread_deg + extra_pellet_spread_deg) * 0.5
	var effective_half: float = base_half / acc
	effective_half = clampf(effective_half, 0.0, 60.0)

	var i: int = 0
	while i < pellets_per_shot:
		_spawn_pellet(base_dir, effective_half)
		i += 1

	if data.flash_scene != null:
		var flash_instance: Node2D = data.flash_scene.instantiate() as Node2D
		_muzzle.add_child(flash_instance)
		flash_instance.position = Vector2.ZERO
		flash_instance.rotation = 0.0
		flash_instance.scale = Vector2(1.0, 1.0)

	_audio.pitch_scale = 0.9 + randf_range(-0.01, 0.01)
	_audio.play()

func _spawn_pellet(base_dir: Vector2, pellet_half_spread: float) -> void:
	var world_root: Node = get_parent().get_parent().get_parent().get_parent()

	var proj: Node2D = data.bullet_scene.instantiate() as Node2D
	world_root.add_child(proj)

	var spread_deg_total: float = randf_range(-pellet_half_spread, pellet_half_spread)
	var spread_rad: float = deg_to_rad(spread_deg_total)
	var fire_dir: Vector2 = base_dir.rotated(spread_rad).normalized()

	var spawn_pos: Vector2 = _muzzle.global_position + fire_dir * spawn_offset_px
	proj.global_position = spawn_pos
	proj.rotation = fire_dir.angle()

	if proj.has_method("initialize_projectile"):
		proj.call(
			"initialize_projectile",
			fire_dir,
			data.muzzle_velocity * randf_range(0.95, 1.05),
			get_effective_damage(),
			get_parent().get_parent().get_parent().velocity,
			get_effective_knockback()
		)
