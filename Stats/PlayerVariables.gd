extends Node

signal stats_changed(stat_ids: Array[StringName])

var stat_db_path: String = "res://Stats/PlayerStats.tres"

var stat_db: StatDB = null

var _base: Dictionary = {}        # StringName -> float
var _final_cache: Dictionary = {} # StringName -> float
var _dirty: Dictionary = {}       # StringName -> bool
var _mods: Array[StatModifier] = []

@export var tick_timed_modifiers: bool = true

func _ready() -> void:
	if stat_db_path != "":
		print("PV ready")
		print("stat_db_path =", stat_db_path)
		stat_db = load(stat_db_path) as StatDB
		print("stat_db =", stat_db)
	_initialize_from_db()
	set_process(tick_timed_modifiers)
	

func _process(delta: float) -> void:
	if not tick_timed_modifiers:
		return

	var changed: Array[StringName] = []

	for idx in range(_mods.size() - 1, -1, -1):
		var m: StatModifier = _mods[idx]
		if m == null:
			_mods.remove_at(idx)
			continue

		if m.duration_seconds > 0.0:
			m.duration_seconds -= delta
			if m.duration_seconds <= 0.0:
				var sid: StringName = m.stat_id
				_mods.remove_at(idx)
				_mark_dirty(sid)
				_append_unique(changed, sid)

	if changed.size() > 0:
		stats_changed.emit(changed)

# -------------------------
# Initialization
# -------------------------

func _initialize_from_db() -> void:
	print("INIT FROM DB")

	if stat_db == null:
		print("DB IS NULL")
		return

	stat_db.build_index()
	var ids: Array[StringName] = stat_db.get_all_ids()
	print("STAT IDS:", ids)

	for sid in ids:
		var def: StatDefinition = stat_db.get_def(sid)
		print("DEF:", sid, " default=", def.default_value)

		if not _base.has(sid):
			_base[sid] = def.default_value
		_dirty[sid] = true

	print("BASE AFTER INIT:", _base)

# -------------------------
# Public API (Base)
# -------------------------

func has_stat(stat_id: StringName) -> bool:
	if _base.has(stat_id):
		return true
	if stat_db == null:
		return false
	return stat_db.get_def(stat_id) != null

func get_base(stat_id: StringName) -> float:
	if _base.has(stat_id):
		return float(_base[stat_id])

	var def: StatDefinition = _get_def(stat_id)
	if def != null:
		return def.default_value

	return 0.0

func set_base(stat_id: StringName, value: float) -> void:
	_base[stat_id] = value
	_mark_dirty(stat_id)
	stats_changed.emit([stat_id])

func add_to_base(stat_id: StringName, delta: float) -> void:
	var v: float = get_base(stat_id)
	set_base(stat_id, v + delta)

# -------------------------
# Public API (Final)
# -------------------------

func get_value(stat_id: StringName) -> float:
	if _is_dirty(stat_id) or not _final_cache.has(stat_id):
		var computed: float = _compute_final(stat_id)
		_final_cache[stat_id] = computed
		_dirty[stat_id] = false
	return float(_final_cache[stat_id])

# -------------------------
# Public API (Modifiers)
# -------------------------

func add_modifier(mod: StatModifier) -> void:
	if mod == null:
		return
	if mod.stat_id == &"":
		return

	_mods.append(mod)
	_mark_dirty(mod.stat_id)
	stats_changed.emit([mod.stat_id])

func remove_modifiers_by_source(source: StringName) -> void:
	if source == &"":
		return

	var changed: Array[StringName] = []

	for idx in range(_mods.size() - 1, -1, -1):
		var m: StatModifier = _mods[idx]
		if m == null:
			_mods.remove_at(idx)
			continue
		if m.source == source:
			var sid: StringName = m.stat_id
			_mods.remove_at(idx)
			_mark_dirty(sid)
			_append_unique(changed, sid)

	if changed.size() > 0:
		stats_changed.emit(changed)

func remove_modifiers_for_stat(stat_id: StringName) -> void:
	var changed: Array[StringName] = []

	for idx in range(_mods.size() - 1, -1, -1):
		var m: StatModifier = _mods[idx]
		if m == null:
			_mods.remove_at(idx)
			continue
		if m.stat_id == stat_id:
			_mods.remove_at(idx)
			_mark_dirty(stat_id)
			_append_unique(changed, stat_id)

	if changed.size() > 0:
		stats_changed.emit(changed)

# Convenience helpers (no need to create a .tres modifier for simple cases)
func add_flat(stat_id: StringName, value: float, source: StringName = &"", duration_seconds: float = -1.0) -> void:
	var m: StatModifier = StatModifier.new()
	m.stat_id = stat_id
	m.op = StatModifier.Op.ADD_FLAT
	m.value = value
	m.source = source
	m.duration_seconds = duration_seconds
	add_modifier(m)

func add_percent(stat_id: StringName, value: float, source: StringName = &"", duration_seconds: float = -1.0) -> void:
	var m: StatModifier = StatModifier.new()
	m.stat_id = stat_id
	m.op = StatModifier.Op.ADD_PERCENT
	m.value = value
	m.source = source
	m.duration_seconds = duration_seconds
	add_modifier(m)

func add_multiplier(stat_id: StringName, value: float, source: StringName = &"", duration_seconds: float = -1.0) -> void:
	var m: StatModifier = StatModifier.new()
	m.stat_id = stat_id
	m.op = StatModifier.Op.MULTIPLY
	m.value = value
	m.source = source
	m.duration_seconds = duration_seconds
	add_modifier(m)

func add_override(stat_id: StringName, value: float, source: StringName = &"", duration_seconds: float = -1.0) -> void:
	var m: StatModifier = StatModifier.new()
	m.stat_id = stat_id
	m.op = StatModifier.Op.OVERRIDE
	m.value = value
	m.source = source
	m.duration_seconds = duration_seconds
	add_modifier(m)

# -------------------------
# Core computation (stacking order you chose)
# 1) base
# 2) + flat adds
# 3) + percent adds (applied to base+flat)
# 4) * multipliers
# 5) override last (if any)
# 6) clamp (if enabled)
# -------------------------

func _compute_final(stat_id: StringName) -> float:
	var base_value: float = get_base(stat_id)

	var add_flat_sum: float = 0.0
	var add_percent_sum: float = 0.0
	var multiply_product: float = 1.0

	var has_override: bool = false
	var override_value: float = 0.0

	for m in _mods:
		var mod: StatModifier = m
		if mod == null:
			continue
		if mod.stat_id != stat_id:
			continue

		# Extra safety: if it hit 0 exactly, treat it as expired
		if mod.duration_seconds == 0.0:
			continue

		if mod.op == StatModifier.Op.ADD_FLAT:
			add_flat_sum += mod.value
		elif mod.op == StatModifier.Op.ADD_PERCENT:
			add_percent_sum += mod.value
		elif mod.op == StatModifier.Op.MULTIPLY:
			multiply_product *= mod.value
		elif mod.op == StatModifier.Op.OVERRIDE:
			has_override = true
			override_value = mod.value

	var v: float = base_value
	v += add_flat_sum
	v = v * (1.0 + add_percent_sum)
	v *= multiply_product

	if has_override:
		v = override_value

	var def: StatDefinition = _get_def(stat_id)
	if def != null and def.clamp_enabled:
		v = clamp(v, def.min_value, def.max_value)

	return v

# -------------------------
# Helpers
# -------------------------

func _get_def(stat_id: StringName) -> StatDefinition:
	if stat_db == null:
		return null
	return stat_db.get_def(stat_id)

func _mark_dirty(stat_id: StringName) -> void:
	_dirty[stat_id] = true

func _is_dirty(stat_id: StringName) -> bool:
	if _dirty.has(stat_id):
		return bool(_dirty[stat_id])
	return true

func _append_unique(arr: Array[StringName], value: StringName) -> void:
	for existing in arr:
		var ex: StringName = existing
		if ex == value:
			return
	arr.append(value)
