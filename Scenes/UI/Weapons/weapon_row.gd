# WeaponRow.gd
extends Control
class_name WeaponRow

@export var icon_rect: TextureRect     # <-- ADD THIS (drag your TextureRect here in inspector)
@export var name_label: Label
@export var ammo_bar: Range            # ProgressBar / TextureProgressBar
@export var regen_bar: Range           # ProgressBar / TextureProgressBar
@export var stored_label: Label

# Smoothing speeds (bigger = snappier)
@export var fill_up_speed: float = 10.0      # smooth when increasing
@export var fill_down_speed: float = 40.0    # fast when decreasing

@export var alpha_smooth_speed: float = 10.0

var _slot_index: int = -1
var _data: WeaponData = null

var _ammo_target: float = 0.0
var _ammo_max_target: float = 100.0

var _regen_target: float = 0.0
var _regen_alpha_target: float = 0.15

func _ready() -> void:
	set_process(true)

func setup(slot_index: int, data: WeaponData) -> void:
	_slot_index = slot_index
	_data = data

	# Icon
	if icon_rect != null and _data != null:
		icon_rect.texture = _data.icon
		# Optional: keep consistent sizing behavior
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Name
	if name_label != null and _data != null:
		name_label.text = _data.display_name.to_upper()

	# Bars init
	if ammo_bar != null:
		ammo_bar.min_value = 0.0
		ammo_bar.max_value = 100.0

	if regen_bar != null:
		regen_bar.visible = true
		regen_bar.min_value = 0.0
		regen_bar.max_value = 100.0

func set_active(active: bool) -> void:
	pass

func set_ammo_state(
	current_mag: int,
	max_mag: int,
	stored_mags: int,
	max_stored: int,
	is_reloading: bool,
	is_regenerating: bool,
	reload_progress: float,
	regen_progress: float
) -> void:
	# Ammo percent (0..1) -> 0..100
	var ammo_percent: float = 0.0
	if max_mag > 0:
		if is_reloading:
			ammo_percent = reload_progress
		else:
			ammo_percent = float(current_mag) / float(max_mag)

	if ammo_percent < 0.0:
		ammo_percent = 0.0
	if ammo_percent > 1.0:
		ammo_percent = 1.0

	_ammo_target = ammo_percent * 100.0
	_ammo_max_target = 100.0

	# Stored multiplier only
	if stored_label != null:
		if stored_mags > 0:
			stored_label.visible = true
			stored_label.text = "x " + str(stored_mags) 
		else:
			stored_label.visible = false

	# Regen percent (0..1) -> 0..100
	var rp: float = regen_progress
	if rp < 0.0:
		rp = 0.0
	if rp > 1.0:
		rp = 1.0
	_regen_target = rp * 100.0

	# Fade when idle (never hard-hide to avoid popping)
	_regen_alpha_target = 1.0 if is_regenerating else 0.15

func _process(delta: float) -> void:
	_smooth_bar(ammo_bar, _ammo_target, _ammo_max_target, delta)
	_smooth_regen(delta)

func _smooth_bar(bar: Range, target: float, maxv: float, delta: float) -> void:
	if bar == null:
		return

	bar.min_value = 0.0
	bar.max_value = maxv

	var current: float = float(bar.value)

	var speed: float = fill_up_speed
	if target < current:
		speed = fill_down_speed

	var t: float = speed * delta
	if t > 1.0:
		t = 1.0

	bar.value = lerp(current, target, t)

func _smooth_regen(delta: float) -> void:
	if regen_bar != null:
		regen_bar.visible = true
		regen_bar.min_value = 0.0
		regen_bar.max_value = 100.0

		var current: float = float(regen_bar.value)
		var speed: float = fill_up_speed
		if _regen_target < current:
			speed = fill_down_speed

		var t: float = speed * delta
		if t > 1.0:
			t = 1.0

		regen_bar.value = lerp(current, _regen_target, t)

		if regen_bar is CanvasItem:
			var ci: CanvasItem = regen_bar as CanvasItem
			var a: float = ci.modulate.a

			var ta: float = alpha_smooth_speed * delta
			if ta > 1.0:
				ta = 1.0

			ci.modulate.a = lerp(a, _regen_alpha_target, ta)
