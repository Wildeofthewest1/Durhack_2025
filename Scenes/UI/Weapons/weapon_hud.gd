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

# --- OPACITY ---
@export var active_alpha: float = 1.0
@export var inactive_alpha: float = 0.35
@export var ghost_alpha: float = 0.15

# --- GHOST "ATTACH" GAP (between active row and the ghost row) ---
@export var ghost_gap: float = 0.0

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

		# default visuals
		row.scale = Vector2(inactive_scale, inactive_scale)
		row.modulate.a = inactive_alpha

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
	# Filled slots in normal index order...
	var filled: Array[int] = []
	var i: int = 0
	while i < _slots.size():
		if _slots[i] != null:
			filled.append(i)
		i += 1

	# ...but you want slot 0 at the bottom, higher slots toward the top.
	filled.reverse()

	if filled.size() <= 0:
		return []

	# Special case: if exactly 2 weapons, no rotation needed
	# Active at bottom, inactive at top (no ghost wrapping)
	if filled.size() == 2:
		if _active_slot < 0:
			return filled
		
		# Find active weapon and put it at the end (bottom position)
		var active_pos: int = -1
		var j: int = 0
		while j < filled.size():
			if filled[j] == _active_slot:
				active_pos = j
				break
			j += 1
		
		if active_pos < 0:
			return filled
		
		# Simple swap: active at bottom, other at top
		var result: Array[int] = []
		if active_pos == 0:
			result.append(filled[1])  # inactive on top
			result.append(filled[0])  # active on bottom
		else:
			result.append(filled[0])  # inactive on top
			result.append(filled[1])  # active on bottom
		return result

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

	# Keep your existing "revolver" behavior for 3+ weapons
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

	# --- "ghost wrap": only apply for 3+ weapons ---
	var display_order: Array[int] = order.duplicate()
	var ghost_slot: int = -1
	var has_ghost: bool = (display_order.size() > 2)  # Changed from > 1 to > 2
	if has_ghost:
		ghost_slot = display_order[0]
		display_order.remove_at(0)
		display_order.append(ghost_slot)

	var display_count: int = display_order.size()

	# --- compute total "visual" height (size * scale) so scaled active row doesn't overlap ---
	var total_h: float = 0.0
	var i: int = 0
	while i < display_count:
		var slot_index: int = display_order[i]
		var is_ghost: bool = (has_ghost and i == display_count - 1 and slot_index == ghost_slot)
		var is_active: bool = (slot_index == _active_slot) and (not is_ghost)

		var base_h: float = active_height if is_active else inactive_height
		var s_vis: float = active_scale if is_active else inactive_scale
		if is_ghost:
			s_vis = inactive_scale

		total_h += base_h * s_vis
		i += 1

	if display_count > 1:
		total_h += spacing * float(display_count - 1)

	# If we're attaching ghost to active, remove the normal spacing for that single seam
	if has_ghost:
		total_h -= spacing
		total_h += ghost_gap

	var root_h: float = rows_root.size.y
	var start_y: float = root_h - total_h - bottom_padding
	if start_y < 0.0:
		start_y = 0.0

	if snap:
		_place_rows_bottom_up(display_order, start_y, ghost_slot, has_ghost)
		return

	_tween = create_tween()
	_tween.set_parallel(true)

	var y: float = start_y
	var k: int = 0
	while k < display_count:
		var slot_index2: int = display_order[k]
		var row: WeaponRow = _rows.get(slot_index2, null) as WeaponRow
		if row == null:
			k += 1
			continue

		var is_ghost2: bool = (has_ghost and k == display_count - 1 and slot_index2 == ghost_slot)
		var is_active2: bool = (slot_index2 == _active_slot) and (not is_ghost2)

		# ghost is always inactive visually
		row.set_active(is_active2)

		var target_h: float = active_height if is_active2 else inactive_height
		var s: float = active_scale if is_active2 else inactive_scale
		if is_ghost2:
			s = inactive_scale
		var target_scale: Vector2 = Vector2(s, s)

		var target_a: float = active_alpha if is_active2 else inactive_alpha
		if is_ghost2:
			target_a = ghost_alpha

		_tween.tween_property(row, "position:y", y, anim_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(row, "size:y", target_h, anim_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(row, "scale", target_scale, anim_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(row, "modulate:a", target_a, anim_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Advance by VISUAL height.
		# For the seam between last real row and the ghost row, use ghost_gap.
		var gap: float = spacing
		if has_ghost and k == display_count - 2:
			gap = ghost_gap

		y += (target_h * s) + gap
		k += 1
func _place_rows_bottom_up(order: Array[int], start_y: float, ghost_slot: int, has_ghost: bool) -> void:
	var y: float = start_y
	var k: int = 0
	var count: int = order.size()

	while k < count:
		var slot_index: int = order[k]
		var row: WeaponRow = _rows.get(slot_index, null) as WeaponRow
		if row == null:
			k += 1
			continue

		var is_ghost: bool = (has_ghost and k == count - 1 and slot_index == ghost_slot)
		var is_active: bool = (slot_index == _active_slot) and (not is_ghost)

		row.set_active(is_active)

		var target_h: float = active_height if is_active else inactive_height
		row.position.y = y
		row.size.y = target_h

		var s: float = active_scale if is_active else inactive_scale
		if is_ghost:
			s = inactive_scale
		row.scale = Vector2(s, s)

		var a: float = active_alpha if is_active else inactive_alpha
		if is_ghost:
			a = ghost_alpha
		row.modulate.a = a

		var gap: float = spacing
		if has_ghost and k == count - 2:
			gap = ghost_gap

		y += (target_h * s) + gap
		k += 1
