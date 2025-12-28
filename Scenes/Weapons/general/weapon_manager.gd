# WeaponManager.gd
extends Node2D
class_name WeaponManager

signal weapon_equipped(weapon: WeaponBase)

signal loadout_changed(slots: Array[WeaponData])
signal active_slot_changed(active_slot: int)

signal weapon_ammo_changed(
	slot_index: int,
	current_mag: int,
	max_mag: int,
	stored_mags: int,
	max_stored: int,
	is_reloading: bool,
	is_regenerating: bool,
	reload_progress: float,
	regen_progress: float
)

@export var socket_path: NodePath = NodePath("WeaponSocket")
@export var starting_loadout: Array[WeaponData] = []

@export var input_cycle_next: StringName = &"weapon_next"
@export var input_cycle_prev: StringName = &"weapon_prev"

var _socket: Node2D = null
var _slots: Array[WeaponData] = []
var _instances: Array[WeaponBase] = []

var _equipped_index: int = -1
var _equipped_instance: WeaponBase = null

var _cached_current_mag: Dictionary = {}
var _cached_stored_mags: Dictionary = {}
var _cached_is_reloading: Dictionary = {}
var _cached_is_regenerating: Dictionary = {}
var _cached_ammo_model: Dictionary = {}

func _ready() -> void:
	_socket = get_node(socket_path) as Node2D
	_slots = starting_loadout.duplicate()

	_spawn_all()
	emit_signal("loadout_changed", _slots)

	var i: int = 0
	while i < _slots.size():
		if _slots[i] != null:
			_equip_slot(i)
			break
		i += 1

func _physics_process(delta: float) -> void:
	# --- GLOBAL GAMEPLAY LOCK (UI up, etc.) ---
	if not InputLock.is_gameplay_enabled():
		# If fire was held, make sure we "release" once so weapons don't get stuck charging
		if _equipped_instance != null:
			if _equipped_instance.has_method("release_fire"):
				_equipped_instance.release_fire()
		return

	# --- Fire input ---
	if _equipped_instance != null:
		if Input.is_action_pressed("fire"):
			_equipped_instance.request_fire()
		else:
			if _equipped_instance.has_method("release_fire"):
				_equipped_instance.release_fire()

	# --- Direct slot keys ---
	if Input.is_action_just_pressed("weapon_1"):
		_equip_slot(0)
	if Input.is_action_just_pressed("weapon_2"):
		_equip_slot(1)
	if Input.is_action_just_pressed("weapon_3"):
		_equip_slot(2)
	if Input.is_action_just_pressed("weapon_4"):
		_equip_slot(3)
	if Input.is_action_just_pressed("weapon_5"):
		_equip_slot(4)

	# --- Cycling ---
	if Input.is_action_just_pressed(input_cycle_next):
		_cycle(+1)
	if Input.is_action_just_pressed(input_cycle_prev):
		_cycle(-1)

func get_slots() -> Array[WeaponData]:
	return _slots

func get_active_slot() -> int:
	return _equipped_index

func _spawn_all() -> void:
	_instances.clear()

	var i: int = 0
	while i < _slots.size():
		var data: WeaponData = _slots[i]
		if data == null:
			_instances.append(null)
			i += 1
			continue

		if data.weapon_scene == null:
			push_error("WeaponManager: weapon_scene not set for " + data.display_name)
			_instances.append(null)
			i += 1
			continue

		var instance: WeaponBase = data.weapon_scene.instantiate() as WeaponBase
		instance.data = data
		_socket.add_child(instance)

		instance.visible = false
		instance.set_equipped(false)

		_instances.append(instance)

		_cached_ammo_model[i] = int(data.ammo_model)
		_cached_current_mag[i] = data.max_magazine
		_cached_stored_mags[i] = 0
		_cached_is_reloading[i] = false
		_cached_is_regenerating[i] = false

		instance.ammo_state_changed.connect(_on_weapon_ammo_state_changed.bind(i))

		i += 1

func _equip_slot(index: int) -> void:
	if index < 0:
		return
	if index >= _instances.size():
		return

	var target: WeaponBase = _instances[index]
	if target == null:
		return

	if _equipped_instance != null:
		_equipped_instance.visible = false
		_equipped_instance.set_equipped(false)

	_equipped_instance = target
	_equipped_index = index

	_equipped_instance.visible = true
	_equipped_instance.position = Vector2.ZERO
	_equipped_instance.rotation = 0.0
	_equipped_instance.set_equipped(true)

	emit_signal("weapon_equipped", _equipped_instance)
	emit_signal("active_slot_changed", _equipped_index)

func _cycle(dir: int) -> void:
	if _instances.size() <= 0:
		return

	if _equipped_index < 0:
		var k0: int = 0
		while k0 < _instances.size():
			if _is_selectable_for_cycle(k0):
				_equip_slot(k0)
				return
			k0 += 1
		return

	var start: int = _equipped_index
	var i: int = 0
	while i < _instances.size():
		var idx: int = start + dir

		# wrap manually (no %)
		if idx >= _instances.size():
			idx = 0
		if idx < 0:
			idx = _instances.size() - 1

		start = idx

		if _is_selectable_for_cycle(idx):
			_equip_slot(idx)
			return

		i += 1

func _is_selectable_for_cycle(index: int) -> bool:
	var inst: WeaponBase = _instances[index]
	if inst == null:
		return false

	var model: int = int(_cached_ammo_model.get(index, int(WeaponData.AmmoModel.STANDARD)))
	if model == int(WeaponData.AmmoModel.INFINITE_WITH_RELOAD):
		return true

	var current_mag: int = int(_cached_current_mag.get(index, 0))
	var stored_mags: int = int(_cached_stored_mags.get(index, 0))
	var is_reloading: bool = bool(_cached_is_reloading.get(index, false))
	var is_regenerating: bool = bool(_cached_is_regenerating.get(index, false))

	if current_mag > 0:
		return true
	if stored_mags > 0:
		return true
	if is_reloading:
		return true
	if is_regenerating:
		return true

	return false

func _on_weapon_ammo_state_changed(
	weapon: WeaponBase,
	current_mag: int,
	max_mag: int,
	stored_mags: int,
	max_stored: int,
	is_reloading: bool,
	is_regenerating: bool,
	reload_progress: float,
	regen_progress: float,
	slot_index: int
) -> void:
	_cached_current_mag[slot_index] = current_mag
	_cached_stored_mags[slot_index] = stored_mags
	_cached_is_reloading[slot_index] = is_reloading
	_cached_is_regenerating[slot_index] = is_regenerating

	var model_int: int = int(WeaponData.AmmoModel.STANDARD)
	if weapon != null and weapon.data != null:
		model_int = int(weapon.data.ammo_model)
	_cached_ammo_model[slot_index] = model_int

	emit_signal(
		"weapon_ammo_changed",
		slot_index,
		current_mag,
		max_mag,
		stored_mags,
		max_stored,
		is_reloading,
		is_regenerating,
		reload_progress,
		regen_progress
	)
