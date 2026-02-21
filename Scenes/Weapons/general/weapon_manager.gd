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

# NEW: so the shop can unlock by id.
# Populate with all weapons in your game.
@export var weapon_library: Array[WeaponData] = []

@export var socket_path: NodePath = NodePath("WeaponSocket")
@export var starting_loadout: Array[WeaponData] = []

@export var input_cycle_next: StringName = &"weapon_next"
@export var input_cycle_prev: StringName = &"weapon_prev"

@export var weapon_switch_cooldown: float = 0.3

var _socket: Node2D = null
var _slots: Array[WeaponData] = []
var _instances: Array[WeaponBase] = []

var _equipped_index: int = -1
var _equipped_instance: WeaponBase = null

var _cached_current_mag: Dictionary = {}     # int -> int
var _cached_stored_mags: Dictionary = {}     # int -> int
var _cached_is_reloading: Dictionary = {}    # int -> bool
var _cached_is_regenerating: Dictionary = {} # int -> bool
var _cached_ammo_model: Dictionary = {}      # int -> int (WeaponData.AmmoModel)

var _switch_cooldown: float = 0.0

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
	for w: WeaponData in weapon_library:
		if w != null and w.id == &"":
			push_error("WeaponData missing id: " + w.display_name)

func _physics_process(delta: float) -> void:
	# Tick down switch cooldown
	if _switch_cooldown > 0.0:
		_switch_cooldown -= delta
		if _switch_cooldown < 0.0:
			_switch_cooldown = 0.0
	
	if _equipped_instance != null:
		# Only allow firing if switch cooldown has expired
		if Input.is_action_pressed("fire") and _switch_cooldown <= 0.0:
			_equipped_instance.request_fire()
		else:
			if _equipped_instance.has_method("release_fire"):
				_equipped_instance.release_fire()

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
	if Input.is_action_just_pressed("weapon_6"):
		_equip_slot(5)

	if Input.is_action_just_pressed(input_cycle_next):
		_cycle(+1)
	if Input.is_action_just_pressed(input_cycle_prev):
		_cycle(-1)

func get_slots() -> Array[WeaponData]:
	return _slots

func get_active_slot() -> int:
	return _equipped_index

# ============================================================
# NEW PUBLIC API (Shop uses this)
# ============================================================

func unlock_weapon(weapon_id: StringName, auto_equip: bool = false) -> bool:
	var data: WeaponData = _find_weapon_in_library(weapon_id)
	if data == null:
		print("Data Null")
		push_warning("WeaponManager.unlock_weapon: unknown weapon_id: " + String(weapon_id))
		return false
	print("[WeaponManager] unlock_weapon called: ", weapon_id)
	return add_weapon_data(data, auto_equip)

func add_weapon_data(data: WeaponData, auto_equip: bool = false) -> bool:
	if data == null:
		return false

	# Already owned?
	var existing: int = _find_weapon_slot_by_data(data)
	if existing >= 0:
		if auto_equip:
			_equip_slot(existing)
		return false

	# Find first empty slot, else append a new slot.
	var slot_index: int = _find_first_empty_slot()
	if slot_index < 0:
		slot_index = _slots.size()
		_slots.append(null)
		_instances.append(null)

	_slots[slot_index] = data
	_spawn_weapon_for_slot(slot_index)

	emit_signal("loadout_changed", _slots)

	if auto_equip:
		_equip_slot(slot_index)

	return true

func has_weapon(weapon_id: StringName) -> bool:
	var data: WeaponData = _find_weapon_in_library(weapon_id)
	if data == null:
		return false
	return _find_weapon_slot_by_data(data) >= 0

# ============================================================
# Existing internals
# ============================================================

func _spawn_all() -> void:
	_instances.clear()

	var i: int = 0
	while i < _slots.size():
		var data: WeaponData = _slots[i]
		if data == null:
			_instances.append(null)
			i += 1
			continue

		_spawn_weapon_for_slot(i)
		i += 1

func _spawn_weapon_for_slot(slot_index: int) -> void:
	# Ensure arrays are big enough
	while _instances.size() <= slot_index:
		_instances.append(null)

	var data: WeaponData = _slots[slot_index]
	if data == null:
		_instances[slot_index] = null
		return

	if data.weapon_scene == null:
		push_error("WeaponManager: weapon_scene not set for " + data.display_name)
		_instances[slot_index] = null
		return

	var instance: WeaponBase = data.weapon_scene.instantiate() as WeaponBase
	if instance == null:
		push_error("WeaponManager: weapon_scene root must extend WeaponBase for " + data.display_name)
		_instances[slot_index] = null
		return

	instance.data = data
	_socket.add_child(instance)

	instance.visible = false
	instance.set_equipped(false)

	_instances[slot_index] = instance

	_cached_ammo_model[slot_index] = int(data.ammo_model)
	_cached_current_mag[slot_index] = data.max_magazine
	_cached_stored_mags[slot_index] = 0
	_cached_is_reloading[slot_index] = false
	_cached_is_regenerating[slot_index] = false

	# includes reload_progress + regen_progress
	instance.ammo_state_changed.connect(_on_weapon_ammo_state_changed.bind(slot_index))

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

	# Apply switch cooldown to prevent weapon spamming
	_switch_cooldown = weapon_switch_cooldown

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

# ============================================================
# NEW helpers
# ============================================================

func _find_weapon_in_library(weapon_id: StringName) -> WeaponData:
	var i: int = 0
	while i < weapon_library.size():
		var w: WeaponData = weapon_library[i]
		if w != null and w.id == weapon_id:
			return w
		i += 1
	return null

func _find_weapon_slot_by_data(data: WeaponData) -> int:
	var i: int = 0
	while i < _slots.size():
		if _slots[i] == data:
			return i
		i += 1
	return -1

func _find_first_empty_slot() -> int:
	var i: int = 0
	while i < _slots.size():
		if _slots[i] == null:
			return i
		i += 1
	return -1
