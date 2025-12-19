# WeaponBase.gd
extends Node2D
class_name WeaponBase

signal ammo_state_changed(
	weapon: WeaponBase,
	current_mag: int,
	max_mag: int,
	stored_mags: int,
	max_stored: int,
	is_reloading: bool,
	is_regenerating: bool,
	reload_progress: float,
	regen_progress: float
)

@export var data: WeaponData

var _cooldown: float = 0.0
var _current_mag: int = 0

var _is_reloading: bool = false
var _reload_time_remaining: float = 0.0

var _stored_mags: int = 0
var _is_regenerating: bool = false
var _regen_time_remaining: float = 0.0

var _waiting_for_mag: bool = false
var _is_equipped: bool = false

var _aim_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	if data == null:
		push_error("WeaponBase: data is not assigned!")
		return

	_current_mag = data.max_magazine
	_stored_mags = 0
	_waiting_for_mag = false
	_is_reloading = false
	_is_regenerating = false
	_reload_time_remaining = 0.0
	_regen_time_remaining = 0.0
	_emit_ammo()

func set_equipped(value: bool) -> void:
	_is_equipped = value
	_emit_ammo()

func _physics_process(delta: float) -> void:
	if data == null:
		return

	_tick_cooldown(delta)
	_tick_reload(delta)
	_tick_passive_policy()
	_tick_regen(delta)

func _tick_cooldown(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown < 0.0:
			_cooldown = 0.0

func _tick_reload(delta: float) -> void:
	if not _is_reloading:
		return

	_reload_time_remaining -= delta
	if _reload_time_remaining < 0.0:
		_reload_time_remaining = 0.0

	_emit_ammo()

	if _reload_time_remaining > 0.0:
		return

	_is_reloading = false
	_reload_time_remaining = 0.0
	_current_mag = data.max_magazine
	_emit_ammo()

func _tick_passive_policy() -> void:
	# Rules:
	# - No top-up reload while partially empty.
	# - Only reload when EMPTY.
	# - STANDARD: if empty and no reserve -> wait for regen first (no reload timer)
	# - STANDARD: regen stored mags in background up to cap

	if _is_reloading:
		return

	# If empty, handle depending on ammo model
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
			return

		return

	# Not empty: do NOT auto-reload.
	# Regen stored mags only for STANDARD.
	if data.ammo_model != WeaponData.AmmoModel.STANDARD:
		_stop_regen_if_needed()
		return

	if _stored_mags >= data.max_stored_mags:
		_stop_regen_if_needed()
		return

	_start_regen_if_needed()

func _tick_regen(delta: float) -> void:
	if not _is_regenerating:
		return
	if data == null:
		return
	if data.ammo_model != WeaponData.AmmoModel.STANDARD:
		_is_regenerating = false
		_regen_time_remaining = 0.0
		_emit_ammo()
		return

	var total: float = data.mag_regen_time
	if total <= 0.01:
		_is_regenerating = false
		_regen_time_remaining = 0.0
		_emit_ammo()
		return

	_regen_time_remaining -= delta
	if _regen_time_remaining < 0.0:
		_regen_time_remaining = 0.0

	_emit_ammo()

	if _regen_time_remaining > 0.0:
		return

	# Regen finished: apply your new rule.
	#
	# If reserve is zero, the generated mag goes straight into a reload
	# (and reserve stays zero).
	#
	# Otherwise, it adds to reserve normally.
	if _stored_mags <= 0 and (_current_mag <= 0 or _waiting_for_mag):
		# Only meaningful when we were waiting/empty; this avoids surprise reloads mid-mag.
		if not _is_reloading:
			if _current_mag <= 0 or _waiting_for_mag:
				_waiting_for_mag = false
				_start_reload()
				_emit_ammo()
				return
	else:
		# Normal reserve growth
		_stored_mags += 1
		if _stored_mags > data.max_stored_mags:
			_stored_mags = data.max_stored_mags

	# Continue regen or stop if capped
	if _stored_mags >= data.max_stored_mags:
		_is_regenerating = false
		_regen_time_remaining = 0.0
	else:
		_regen_time_remaining = total

	_emit_ammo()

func _start_regen_if_needed() -> void:
	if data == null:
		return
	if data.ammo_model != WeaponData.AmmoModel.STANDARD:
		return
	if _stored_mags >= data.max_stored_mags:
		_stop_regen_if_needed()
		return
	if _is_regenerating:
		return

	var t: float = data.mag_regen_time
	if t <= 0.01:
		return

	_is_regenerating = true
	_regen_time_remaining = t
	_emit_ammo()

func _stop_regen_if_needed() -> void:
	if _is_regenerating:
		_is_regenerating = false
		_regen_time_remaining = 0.0
		_emit_ammo()

func try_fire(dir: Vector2) -> void:
	if data == null:
		return
	if _is_reloading:
		return
	if _cooldown > 0.0:
		return

	var aim_dir: Vector2 = dir
	if aim_dir.length_squared() > 0.0:
		aim_dir = aim_dir.normalized()
	_aim_dir = aim_dir

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

	_cooldown = data.fire_cooldown
	_fire_projectile(aim_dir)
	_emit_ammo()

func _start_reload() -> void:
	if _is_reloading:
		return
	_is_reloading = true
	_reload_time_remaining = data.reload_time
	_emit_ammo()

func _consume_stored_and_start_reload() -> bool:
	if data == null:
		return false
	if data.ammo_model != WeaponData.AmmoModel.STANDARD:
		return false
	if _is_reloading:
		return false
	if _stored_mags <= 0:
		return false

	_stored_mags -= 1
	if _stored_mags < 0:
		_stored_mags = 0

	_is_reloading = true
	_reload_time_remaining = data.reload_time
	_emit_ammo()
	return true

func _emit_ammo() -> void:
	var max_stored: int = 0
	var stored: int = 0
	var is_regen: bool = false

	if data != null and data.ammo_model == WeaponData.AmmoModel.STANDARD:
		max_stored = data.max_stored_mags
		stored = _stored_mags
		is_regen = _is_regenerating

	var reload_progress: float = 0.0
	if _is_reloading and data != null and data.reload_time > 0.0:
		reload_progress = 1.0 - (_reload_time_remaining / data.reload_time)
		if reload_progress < 0.0:
			reload_progress = 0.0
		if reload_progress > 1.0:
			reload_progress = 1.0

	var regen_progress: float = 0.0
	if _is_regenerating and data != null and data.mag_regen_time > 0.0:
		regen_progress = 1.0 - (_regen_time_remaining / data.mag_regen_time)
		if regen_progress < 0.0:
			regen_progress = 0.0
		if regen_progress > 1.0:
			regen_progress = 1.0

	emit_signal(
		"ammo_state_changed",
		self,
		_current_mag,
		data.max_magazine,
		stored,
		max_stored,
		_is_reloading,
		is_regen,
		reload_progress,
		regen_progress
	)

func _fire_projectile(dir: Vector2) -> void:
	pass
