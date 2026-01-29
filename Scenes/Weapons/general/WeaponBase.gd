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

@export var reload_complete_sound: AudioStream
@export var reload_complete_volume_db: float = -15.0
@export var reload_complete_pitch: float = 1.0

var _reload_audio: AudioStreamPlayer = null

@export var data: WeaponData

# Timers are kept in SECONDS
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

# ------------------------------------------------------------
# EFFECTIVE STATS (WeaponData + PlayerVariables)
# ------------------------------------------------------------

# Multipliers (dimensionless)
var _mult_damage: float = 1.0
var _mult_fire_rate: float = 1.0
var _mult_accuracy: float = 1.0
var _mult_knockback: float = 1.0
var _mult_mag_regen: float = 1.0

# Addons (weapon-specific; pistol-only for now)
var _addon_mag_count: int = 0
var _addon_mag_size: int = 0

# Effective results (SECONDS where appropriate)
var _eff_damage: float = 0.0
var _eff_fire_cooldown: float = 0.0          # seconds/shot
var _eff_knockback: float = 0.0
var _eff_mag_regen_time: float = 0.0         # seconds per stored-mag regen tick
var _eff_reload_time: float = 0.0            # seconds per reload

# Effective rates (1/SECOND) for UI / design readability
var _eff_fire_rate: float = 0.0              # shots/second
var _eff_mag_regen_rate: float = 0.0         # mags/second
var _eff_reload_rate: float = 0.0            # reloads/second (mostly for display)

var _eff_max_magazine: int = 0
var _eff_max_stored_mags: int = 0

# Accuracy-as-spread
var _base_spread_rad: float = 0.0
var _eff_spread_rad: float = 0.0


func _ready() -> void:
	if data == null:
		push_error("WeaponBase: data is not assigned!")
		return

	# Connect stat change listener (use Array, not Array[StringName])
	if PlayerVariables != null and PlayerVariables.has_signal("stats_changed"):
		var cb: Callable = Callable(self, "_on_stats_changed")
		if not PlayerVariables.stats_changed.is_connected(cb):
			PlayerVariables.stats_changed.connect(cb)

	# Audio init (keep simple + reliable)
	_reload_audio = AudioStreamPlayer.new()
	if reload_complete_sound != null:
		_reload_audio.stream = reload_complete_sound
	else:
		_reload_audio.stream = preload("res://Assets/reload.mp3")
	_reload_audio.volume_db = reload_complete_volume_db
	_reload_audio.pitch_scale = reload_complete_pitch
	add_child(_reload_audio)

	# Compute effective stats once at start
	_recompute_effective_stats(true)

	_current_mag = _eff_max_magazine
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


# ------------------------------------------------------------
# STAT UPDATES
# ------------------------------------------------------------

func _on_stats_changed(_stat_ids: Array) -> void:
	_recompute_effective_stats(false)


func _recompute_effective_stats(is_initial: bool) -> void:
	if data == null:
		return

	var old_max_mag: int = _eff_max_magazine
	var old_max_stored: int = _eff_max_stored_mags

	_mult_damage = _safe_stat_mult(&"damage")
	_mult_fire_rate = _safe_stat_mult(&"fire_rate")
	_mult_accuracy = _safe_stat_mult(&"accuracy")
	_mult_knockback = _safe_stat_mult(&"knockback")
	_mult_mag_regen = _safe_stat_mult(&"mag_regen")

	_addon_mag_count = 0
	_addon_mag_size = 0
	if _weapon_is_pistol():
		_addon_mag_count = _safe_stat_add_int(&"pistol_mag_count")
		_addon_mag_size = _safe_stat_add_int(&"pistol_mag_size")

	_base_spread_rad = _safe_get_data_float(&"spread_rad", 0.0)

	if _mult_accuracy <= 0.01:
		_eff_spread_rad = _base_spread_rad
	else:
		_eff_spread_rad = _base_spread_rad / _mult_accuracy
	if _eff_spread_rad < 0.0:
		_eff_spread_rad = 0.0

	_eff_damage = float(data.damage) * _mult_damage
	_eff_knockback = float(data.knockback) * _mult_knockback

	# Fire cooldown (seconds/shot)
	# Fire rate (shots/sec)
	var base_fire_rate: float = float(data.fire_rate)
	var eff_fire_rate: float = base_fire_rate * _mult_fire_rate
	if eff_fire_rate < 0.0:
		eff_fire_rate = 0.0

	_eff_fire_rate = eff_fire_rate
	_eff_fire_cooldown = _rate_to_seconds(eff_fire_rate) # seconds per shot

	# Mag regen time (seconds per stored-mag generated)
	var base_regen: float = float(data.mag_regen_time)
	if _mult_mag_regen <= 0.01:
		_eff_mag_regen_time = base_regen
	else:
		_eff_mag_regen_time = base_regen / _mult_mag_regen
	if _eff_mag_regen_time < 0.0:
		_eff_mag_regen_time = 0.0

	_eff_reload_time = float(data.reload_time)
	if _eff_reload_time < 0.0:
		_eff_reload_time = 0.0

	_eff_max_magazine = int(data.max_magazine) + _addon_mag_size
	if _eff_max_magazine < 0:
		_eff_max_magazine = 0

	_eff_max_stored_mags = int(data.max_stored_mags) + _addon_mag_count
	if _eff_max_stored_mags < 0:
		_eff_max_stored_mags = 0

	# ---- NEW: derive 1/second rates from second-based timers ----
	_eff_fire_rate = _seconds_to_rate(_eff_fire_cooldown)        # shots/sec
	_eff_mag_regen_rate = _seconds_to_rate(_eff_mag_regen_time)  # mags/sec
	_eff_reload_rate = _seconds_to_rate(_eff_reload_time)        # reloads/sec

	# Adjust current ammo if caps changed (only after init)
	if is_initial == false:
		var delta_mag: int = _eff_max_magazine - old_max_mag
		if delta_mag != 0:
			_current_mag += delta_mag

		if _current_mag > _eff_max_magazine:
			_current_mag = _eff_max_magazine
		if _current_mag < 0:
			_current_mag = 0

		if _stored_mags > _eff_max_stored_mags:
			_stored_mags = _eff_max_stored_mags
		if _stored_mags < 0:
			_stored_mags = 0

	# Keep regen timer sane if regen time changes while ticking
	if _is_regenerating:
		if _eff_mag_regen_time <= 0.01:
			_regen_time_remaining = 0.0
		else:
			if _regen_time_remaining > _eff_mag_regen_time:
				_regen_time_remaining = _eff_mag_regen_time

	_emit_ammo()


func _seconds_to_rate(seconds: float) -> float:
	# Converts seconds-per-event -> events-per-second
	if seconds <= 0.0001:
		return 0.0
	return 1.0 / seconds


func _safe_stat_mult(stat_id: StringName) -> float:
	var v: float = 1.0
	if PlayerVariables != null:
		v = float(PlayerVariables.get_value(stat_id))
	if v <= 0.0:
		v = 1.0
	return v


func _safe_stat_add_int(stat_id: StringName) -> int:
	var v: float = 0.0
	if PlayerVariables != null:
		v = float(PlayerVariables.get_value(stat_id))
	return int(floor(v))


func _weapon_is_pistol() -> bool:
	if data == null:
		return false
	return data.id == &"pistol"


func _safe_get_data_float(prop: StringName, fallback: float) -> float:
	if data == null:
		return fallback
	if not _has_property(data, prop):
		return fallback
	var v: Variant = data.get(String(prop))
	if v == null:
		return fallback
	return float(v)


func _has_property(obj: Object, prop: StringName) -> bool:
	if obj == null:
		return false
	var props: Array = obj.get_property_list()
	for p in props:
		var d: Dictionary = p as Dictionary
		if d.has("name") and StringName(d["name"]) == prop:
			return true
	return false


# ------------------------------------------------------------
# Public getters (use these in weapon variants)
# ------------------------------------------------------------

# Seconds-based (timers)
func get_effective_damage() -> float:
	return _eff_damage

func get_effective_fire_cooldown() -> float: # sec/shot
	return _eff_fire_cooldown

func get_effective_reload_time() -> float: # sec
	return _eff_reload_time

func get_effective_mag_regen_time() -> float: # sec
	return _eff_mag_regen_time

func get_effective_knockback() -> float:
	return _eff_knockback

func get_effective_max_magazine() -> int:
	return _eff_max_magazine

func get_effective_max_stored_mags() -> int:
	return _eff_max_stored_mags

func get_effective_spread_rad() -> float:
	return _eff_spread_rad

# Rate-based (1/sec) for UI/readability
func get_effective_fire_rate() -> float: # shots/sec
	return _eff_fire_rate

func get_effective_mag_regen_rate() -> float: # mags/sec
	return _eff_mag_regen_rate

func get_effective_reload_rate() -> float: # reloads/sec
	return _eff_reload_rate

# Optional: expose remaining seconds for UI if you want
func get_cooldown_remaining_sec() -> float:
	return _cooldown

func get_reload_remaining_sec() -> float:
	return _reload_time_remaining

func get_regen_remaining_sec() -> float:
	return _regen_time_remaining


# ------------------------------------------------------------
# Ticking (all seconds)
# ------------------------------------------------------------

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
	_current_mag = _eff_max_magazine
	_emit_ammo()


func _tick_passive_policy() -> void:
	if _is_reloading:
		return

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

	if data.ammo_model != WeaponData.AmmoModel.STANDARD:
		_stop_regen_if_needed()
		return

	if _stored_mags >= _eff_max_stored_mags:
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

	var total: float = _eff_mag_regen_time
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

	if _stored_mags <= 0 and (_current_mag <= 0 or _waiting_for_mag):
		if not _is_reloading:
			_waiting_for_mag = false
			_start_reload()
			_emit_ammo()
			return
	else:
		if _reload_audio != null:
			_reload_audio.pitch_scale = reload_complete_pitch * randf_range(0.95, 1.05)
			_reload_audio.play()
			_reload_audio.pitch_scale = reload_complete_pitch

		_stored_mags += 1
		if _stored_mags > _eff_max_stored_mags:
			_stored_mags = _eff_max_stored_mags

	if _stored_mags >= _eff_max_stored_mags:
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
	if _stored_mags >= _eff_max_stored_mags:
		_stop_regen_if_needed()
		return
	if _is_regenerating:
		return

	var t: float = _eff_mag_regen_time
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

	var spread: float = _eff_spread_rad
	if spread > 0.0:
		var angle_offset: float = randf_range(-spread, spread)
		aim_dir = aim_dir.rotated(angle_offset)

	_current_mag -= 1
	if _current_mag < 0:
		_current_mag = 0

	_cooldown = _eff_fire_cooldown # seconds
	_fire_projectile(aim_dir)
	_emit_ammo()


func _start_reload() -> void:
	if _is_reloading:
		return
	_is_reloading = true
	_reload_time_remaining = _eff_reload_time # seconds
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
	_reload_time_remaining = _eff_reload_time # seconds
	_emit_ammo()
	return true


func _emit_ammo() -> void:
	var max_stored: int = 0
	var stored: int = 0
	var is_regen: bool = false

	if data != null and data.ammo_model == WeaponData.AmmoModel.STANDARD:
		max_stored = _eff_max_stored_mags
		stored = _stored_mags
		is_regen = _is_regenerating

	var reload_progress: float = 0.0
	if _is_reloading and _eff_reload_time > 0.0:
		reload_progress = 1.0 - (_reload_time_remaining / _eff_reload_time)
		if reload_progress < 0.0:
			reload_progress = 0.0
		if reload_progress > 1.0:
			reload_progress = 1.0

	var regen_progress: float = 0.0
	if _is_regenerating and _eff_mag_regen_time > 0.0:
		regen_progress = 1.0 - (_regen_time_remaining / _eff_mag_regen_time)
		if regen_progress < 0.0:
			regen_progress = 0.0
		if regen_progress > 1.0:
			regen_progress = 1.0

	emit_signal(
		"ammo_state_changed",
		self,
		_current_mag,
		_eff_max_magazine,
		stored,
		max_stored,
		_is_reloading,
		is_regen,
		reload_progress,
		regen_progress
	)

func _rate_to_seconds(rate: float) -> float:
	if rate <= 0.0001:
		return 0.0
	return 1.0 / rate


# Override in weapon variants
func _fire_projectile(dir: Vector2) -> void:
	pass
