# WeaponHUD.gd
extends Control
class_name WeaponHUD

@export var weapon_manager_path: NodePath
@export var rows_root: Control
@export var row_scene: PackedScene

@export var spacing: float = 6.0
@export var inactive_height: float = 26.0
@export var active_height: float = 44.0
@export var anim_time: float = 0.18

@export var inactive_scale: float = 1.0
@export var active_scale: float = 1.25
@export var bottom_padding: float = 0.0

var _wm: WeaponManager = null
var _slots: Array[WeaponData] = []
var _rows: Dictionary = {} # int -> WeaponRow
var _active_slot: int = -1
var _tween: Tween = null

func _ready() -> void:
	_wm = _find_weapon_manager()
	if _wm == null:
		push_error("WeaponHUD: could not find WeaponManager (group 'weapon_manager' or weapon_manager_path).")
		return

	var err0: int = _wm.loadout_changed.connect(_on_loadout_changed)
	print("HUD connect loadout_changed err=", err0)

	var err1: int = _wm.active_slot_changed.connect(_on_active_slot_changed)
	print("HUD connect active_slot_changed err=", err1)

	var err2: int = _wm.weapon_ammo_changed.connect(_on_weapon_ammo_changed)
	print("HUD connect weapon_ammo_changed err=", err2)

	_on_loadout_changed(_wm.get_slots())
	_on_active_slot_changed(_wm.get_active_slot())

func _find_weapon_manager() -> WeaponManager:
	var gm: Node = get_tree().get_first_node_in_group("weapon_manager")
	var wm_from_group: WeaponManager = gm as WeaponManager
	if wm_from_group != null:
		return wm_from_group

	if weapon_manager_path != NodePath():
		return get_node(weapon_manager_path) as WeaponManager

	return null

func _on_loadout_changed(slots: Array[WeaponData]) -> void:
	_slots = slots
	_rebuild_rows()
	_relayout(true)

func _rebuild_rows() -> void:
	for key: Variant in _rows.keys():
		var old_row: WeaponRow = _rows[key] as WeaponRow
		if old_row != null:
			old_row.queue_free()
	_rows.clear()

	if rows_root == null:
		push_error("WeaponHUD: rows_root not set.")
		return
	if row_scene == null:
		push_error("WeaponHUD: row_scene not set.")
		return

	var i: int = 0
	while i < _slots.size():
		var data: WeaponData = _slots[i]
		if data == null:
			i += 1
			continue

		var row: WeaponRow = row_scene.instantiate() as WeaponRow
		rows_root.add_child(row)
		row.setup(i, data)
		row.scale = Vector2(inactive_scale, inactive_scale)

		_rows[i] = row
		i += 1

func _on_active_slot_changed(active_slot: int) -> void:
	_active_slot = active_slot
	_relayout(false)

func _on_weapon_ammo_changed(
	slot_index: int,
	current_mag: int,
	max_mag: int,
	stored_mags: int,
	max_stored: int,
	is_reloading: bool,
	is_regenerating: bool,
	reload_progress: float,
	regen_progress: float
) -> void:
	var row: WeaponRow = _rows.get(slot_index, null) as WeaponRow
	if row == null:
		return
	row.set_ammo_state(current_mag, max_mag, stored_mags, max_stored, is_reloading, is_regenerating, reload_progress, regen_progress)

func _relayout(snap: bool) -> void:
	if rows_root == null:
		return
	var order: Array[int] = _compute_revolver_order()
	_apply_layout_bottom_up(order, snap)

func _compute_revolver_order() -> Array[int]:
	var filled: Array[int] = []
	var i: int = 0
	while i < _slots.size():
		if _slots[i] != null:
			filled.append(i)
		i += 1

	if filled.size() <= 0:
		return []

	if _active_slot < 0:
		return filled

	var active_pos: int = -1
	var j: int = 0
	while j < filled.size():
		if filled[j] == _active_slot:
			active_pos = j
			break
		j += 1

	if active_pos < 0:
		return filled

	var rotated: Array[int] = []

	j = active_pos + 1
	while j < filled.size():
		rotated.append(filled[j])
		j += 1

	j = 0
	while j <= active_pos:
		rotated.append(filled[j])
		j += 1

	return rotated

func _apply_layout_bottom_up(order: Array[int], snap: bool) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

	var count: int = order.size()
	if count <= 0:
		return

	var total_h: float = 0.0
	var i: int = 0
	while i < count:
		var slot_index: int = order[i]
		var is_active: bool = (slot_index == _active_slot)
		var h: float = active_height if is_active else inactive_height
		total_h += h
		i += 1

	if count > 1:
		total_h += spacing * float(count - 1)

	var root_h: float = rows_root.size.y
	var start_y: float = root_h - total_h - bottom_padding
	if start_y < 0.0:
		start_y = 0.0

	if snap:
		_place_rows_bottom_up(order, start_y)
		return

	_tween = create_tween()
	_tween.set_parallel(true)

	var y: float = start_y
	var k: int = 0
	while k < count:
		var slot_index2: int = order[k]
		var row: WeaponRow = _rows.get(slot_index2, null) as WeaponRow
		if row == null:
			k += 1
			continue

		var is_active2: bool = (slot_index2 == _active_slot)
		row.set_active(is_active2)

		var target_h: float = active_height if is_active2 else inactive_height
		var s: float = active_scale if is_active2 else inactive_scale
		var target_scale: Vector2 = Vector2(s, s)

		_tween.tween_property(row, "position:y", y, anim_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(row, "size:y", target_h, anim_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(row, "scale", target_scale, anim_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		y += target_h + spacing
		k += 1

func _place_rows_bottom_up(order: Array[int], start_y: float) -> void:
	var y: float = start_y
	var k: int = 0
	while k < order.size():
		var slot_index: int = order[k]
		var row: WeaponRow = _rows.get(slot_index, null) as WeaponRow
		if row == null:
			k += 1
			continue

		var is_active: bool = (slot_index == _active_slot)
		row.set_active(is_active)

		var target_h: float = active_height if is_active else inactive_height
		row.position.y = y
		row.size.y = target_h

		var s: float = active_scale if is_active else inactive_scale
		row.scale = Vector2(s, s)

		y += target_h + spacing
		k += 1
