extends Node

## TagManager - Centralized tag system for game state, dialogue, quests, keys, upgrades
## Handles thousands of tags efficiently with namespacing, wildcards, and advanced features

signal tag_added(tag_name: String)
signal tag_removed(tag_name: String)
signal tag_counter_changed(tag_name: String, new_value: int)

# Core tag storage: { "tag:name": { metadata } }
var _tags: Dictionary = {}

# Tag counters for repeatable events: { "tag:name": count }
var _tag_counters: Dictionary = {}

# Temporary tags with expiry times: { "tag:name": expiry_time }
var _temp_tags: Dictionary = {}

# Tag groups/sets for logical collections
var _tag_groups: Dictionary = {}

# Tag dependencies: { "tag:name": { "requires": [], "blocks": [] } }
var _tag_dependencies: Dictionary = {}

# Performance: cache for frequently checked tags
var _check_cache: Dictionary = {}
var _cache_max_size: int = 100

# Debug tracking
var _tag_checks: Dictionary = {} # Track how often tags are checked
var _debug_mode: bool = false

# ============================================================================
# CORE TAG FUNCTIONS
# ============================================================================

func add_tag(tag_name: String, metadata: Dictionary = {}) -> void:
	"""Add a tag to the system. Metadata can include source, timestamp, etc."""
	if _tags.has(tag_name):
		return # Already exists
	
	var tag_data: Dictionary = {
		"added_at": Time.get_unix_time_from_system(),
		"game_time": _get_game_time(),
	}
	
	# Merge any custom metadata
	for key in metadata:
		tag_data[key] = metadata[key]
	
	_tags[tag_name] = tag_data
	_invalidate_cache()
	
	if _debug_mode:
		print("[TagManager] Added tag: ", tag_name)
	
	tag_added.emit(tag_name)
	
	# Check if this completes any groups
	_check_group_completion(tag_name)

func remove_tag(tag_name: String) -> void:
	"""Remove a tag from the system."""
	if not _tags.has(tag_name):
		return
	
	_tags.erase(tag_name)
	_invalidate_cache()
	
	if _debug_mode:
		print("[TagManager] Removed tag: ", tag_name)
	
	tag_removed.emit(tag_name)

func has_tag(tag_name: String) -> bool:
	"""Check if a specific tag exists."""
	if _debug_mode:
		_track_check(tag_name)
	
	# Check cache first
	if _check_cache.has(tag_name):
		return _check_cache[tag_name]
	
	var result: bool = _tags.has(tag_name)
	_cache_result(tag_name, result)
	return result

func has_all_tags(tag_names: Array) -> bool:
	"""Check if ALL specified tags exist (AND logic)."""
	for tag in tag_names:
		if not has_tag(tag):
			return false
	return true

func has_any_tag(tag_names: Array) -> bool:
	"""Check if ANY of the specified tags exist (OR logic)."""
	for tag in tag_names:
		if has_tag(tag):
			return true
	return false

func get_tag_metadata(tag_name: String) -> Dictionary:
	"""Get the metadata for a specific tag."""
	if _tags.has(tag_name):
		return _tags[tag_name]
	return {}

func get_all_tags() -> Array:
	"""Get all active tags as an array."""
	return _tags.keys()

func clear_all_tags() -> void:
	"""Remove all tags. Use for new game."""
	_tags.clear()
	_tag_counters.clear()
	_temp_tags.clear()
	_invalidate_cache()
	
	if _debug_mode:
		print("[TagManager] Cleared all tags")

# ============================================================================
# WILDCARD & PATTERN MATCHING
# ============================================================================

func has_any_matching(pattern: String) -> bool:
	"""Check if any tags match the wildcard pattern. Use * as wildcard.
	Example: has_any_matching('quest:main:*') checks if any main quest tags exist."""
	var matching: Array = get_tags_matching(pattern)
	return matching.size() > 0

func get_tags_matching(pattern: String) -> Array:
	"""Get all tags matching a wildcard pattern.
	Example: get_tags_matching('upgrade:weapons:*') returns all weapon upgrade tags."""
	var results: Array = []
	var regex_pattern: String = pattern.replace("*", ".*").replace(":", "\\:")
	var regex: RegEx = RegEx.new()
	regex.compile("^" + regex_pattern + "$")
	
	for tag in _tags.keys():
		if regex.search(tag):
			results.append(tag)
	
	return results

func count_matching(pattern: String) -> int:
	"""Count how many tags match a pattern."""
	return get_tags_matching(pattern).size()

func remove_matching(pattern: String) -> int:
	"""Remove all tags matching a pattern. Returns count of removed tags."""
	var matching: Array = get_tags_matching(pattern)
	for tag in matching:
		remove_tag(tag)
	return matching.size()

# ============================================================================
# TAG COUNTERS (for repeatable events)
# ============================================================================

func increment_tag(tag_name: String, amount: int = 1) -> int:
	"""Increment a tag counter. Returns new value.
	Example: increment_tag('combat:kills:alien_scout')"""
	if not _tag_counters.has(tag_name):
		_tag_counters[tag_name] = 0
	
	_tag_counters[tag_name] += amount
	var new_value: int = _tag_counters[tag_name]
	
	if _debug_mode:
		print("[TagManager] Counter ", tag_name, " = ", new_value)
	
	tag_counter_changed.emit(tag_name, new_value)
	return new_value

func decrement_tag(tag_name: String, amount: int = 1) -> int:
	"""Decrement a tag counter. Returns new value."""
	return increment_tag(tag_name, -amount)

func get_tag_count(tag_name: String) -> int:
	"""Get the current value of a tag counter."""
	if _tag_counters.has(tag_name):
		return _tag_counters[tag_name]
	return 0

func set_tag_count(tag_name: String, value: int) -> void:
	"""Set a tag counter to a specific value."""
	_tag_counters[tag_name] = value
	tag_counter_changed.emit(tag_name, value)

# ============================================================================
# TEMPORARY TAGS WITH EXPIRY
# ============================================================================

func add_tag_with_expiry(tag_name: String, duration_seconds: float, metadata: Dictionary = {}) -> void:
	"""Add a temporary tag that auto-removes after duration.
	Example: add_tag_with_expiry('buff:speed_boost', 30.0)"""
	add_tag(tag_name, metadata)
	_temp_tags[tag_name] = Time.get_unix_time_from_system() + duration_seconds
	
	if _debug_mode:
		print("[TagManager] Added temporary tag: ", tag_name, " (expires in ", duration_seconds, "s)")

func _process(delta: float) -> void:
	"""Update temporary tags and remove expired ones."""
	var current_time: float = Time.get_unix_time_from_system()
	var to_remove: Array = []
	
	for tag in _temp_tags.keys():
		if current_time >= _temp_tags[tag]:
			to_remove.append(tag)
	
	for tag in to_remove:
		remove_tag(tag)
		_temp_tags.erase(tag)
		if _debug_mode:
			print("[TagManager] Expired temporary tag: ", tag)

# ============================================================================
# TAG GROUPS (logical collections)
# ============================================================================

func define_group(group_name: String, required_tags: Array) -> void:
	"""Define a logical group of tags.
	Example: define_group('endgame_ready', ['upgrade:max', 'quest:main:complete'])"""
	_tag_groups[group_name] = required_tags

func has_group(group_name: String) -> bool:
	"""Check if all tags in a group are present."""
	if not _tag_groups.has(group_name):
		push_warning("[TagManager] Group not defined: " + group_name)
		return false
	
	return has_all_tags(_tag_groups[group_name])

func get_group_progress(group_name: String) -> Dictionary:
	"""Get completion status for a group.
	Returns: { 'total': 5, 'completed': 3, 'missing': ['tag1', 'tag2'] }"""
	if not _tag_groups.has(group_name):
		return {}
	
	var required: Array = _tag_groups[group_name]
	var completed: int = 0
	var missing: Array = []
	
	for tag in required:
		if has_tag(tag):
			completed += 1
		else:
			missing.append(tag)
	
	return {
		"total": required.size(),
		"completed": completed,
		"missing": missing,
		"percentage": (float(completed) / float(required.size())) * 100.0
	}

func _check_group_completion(newly_added_tag: String) -> void:
	"""Internal: Check if adding this tag completed any groups."""
	for group_name in _tag_groups.keys():
		if has_group(group_name):
			# Group is now complete, could trigger events here
			if _debug_mode:
				print("[TagManager] Group completed: ", group_name)

# ============================================================================
# TAG DEPENDENCIES
# ============================================================================

func define_dependency(tag_name: String, requires: Array = [], blocks: Array = []) -> void:
	"""Define dependencies for a tag.
	'requires': tags that must exist before this can be added
	'blocks': tags that prevent this from being added"""
	_tag_dependencies[tag_name] = {
		"requires": requires,
		"blocks": blocks
	}

func can_add_tag(tag_name: String) -> bool:
	"""Check if a tag can be added based on dependencies."""
	if not _tag_dependencies.has(tag_name):
		return true # No dependencies defined
	
	var deps: Dictionary = _tag_dependencies[tag_name]
	
	# Check required tags
	if deps.has("requires"):
		if not has_all_tags(deps["requires"]):
			return false
	
	# Check blocking tags
	if deps.has("blocks"):
		if has_any_tag(deps["blocks"]):
			return false
	
	return true

func add_tag_with_deps(tag_name: String, metadata: Dictionary = {}) -> bool:
	"""Add a tag only if dependencies are met. Returns true if added."""
	if can_add_tag(tag_name):
		add_tag(tag_name, metadata)
		return true
	
	if _debug_mode:
		print("[TagManager] Cannot add tag (dependencies not met): ", tag_name)
	return false

# ============================================================================
# SAVE / LOAD
# ============================================================================

func get_save_data() -> Dictionary:
	"""Get all tag data for saving."""
	return {
		"tags": _tags,
		"counters": _tag_counters,
		"temp_tags": _temp_tags,
		"groups": _tag_groups,
		"dependencies": _tag_dependencies,
		"version": 1 # For future compatibility
	}

func load_save_data(data: Dictionary) -> void:
	"""Load tag data from save."""
	if data.has("tags"):
		_tags = data["tags"]
	if data.has("counters"):
		_tag_counters = data["counters"]
	if data.has("temp_tags"):
		_temp_tags = data["temp_tags"]
	if data.has("groups"):
		_tag_groups = data["groups"]
	if data.has("dependencies"):
		_tag_dependencies = data["dependencies"]
	
	_invalidate_cache()
	
	if _debug_mode:
		print("[TagManager] Loaded ", _tags.size(), " tags from save")

# ============================================================================
# DEBUG & UTILITIES
# ============================================================================

func set_debug_mode(enabled: bool) -> void:
	"""Enable/disable debug logging."""
	_debug_mode = enabled

func print_all_tags() -> void:
	"""Print all active tags to console."""
	print("=== Active Tags (", _tags.size(), ") ===")
	var sorted_tags: Array = _tags.keys()
	sorted_tags.sort()
	for tag in sorted_tags:
		print("  - ", tag, " | ", _tags[tag])

func print_tag_stats() -> void:
	"""Print statistics about tag usage."""
	print("=== Tag System Stats ===")
	print("Total tags: ", _tags.size())
	print("Tag counters: ", _tag_counters.size())
	print("Temporary tags: ", _temp_tags.size())
	print("Defined groups: ", _tag_groups.size())
	print("Tag dependencies: ", _tag_dependencies.size())
	print("Cache size: ", _check_cache.size())
	
	if _tag_checks.size() > 0:
		print("\n=== Most Checked Tags ===")
		var sorted_checks: Array = _tag_checks.keys()
		sorted_checks.sort_custom(func(a, b): return _tag_checks[a] > _tag_checks[b])
		for i in range(min(10, sorted_checks.size())):
			var tag: String = sorted_checks[i]
			print("  ", tag, ": ", _tag_checks[tag], " checks")

func get_tags_by_category(category: String) -> Array:
	"""Get all tags starting with a category prefix.
	Example: get_tags_by_category('quest:') returns all quest tags."""
	return get_tags_matching(category + "*")

func _track_check(tag_name: String) -> void:
	"""Internal: Track how often tags are checked for performance analysis."""
	if not _tag_checks.has(tag_name):
		_tag_checks[tag_name] = 0
	_tag_checks[tag_name] += 1

func _cache_result(tag_name: String, result: bool) -> void:
	"""Internal: Cache a tag check result."""
	if _check_cache.size() >= _cache_max_size:
		# Simple cache eviction: remove first item
		var first_key: String = _check_cache.keys()[0]
		_check_cache.erase(first_key)
	_check_cache[tag_name] = result

func _invalidate_cache() -> void:
	"""Internal: Clear the cache when tags change."""
	_check_cache.clear()

func _get_game_time() -> float:
	"""Internal: Get current game time. Override this to use your game's time system."""
	# This is a placeholder - integrate with your actual game time system
	return Time.get_ticks_msec() / 1000.0

# ============================================================================
# BATCH OPERATIONS (for performance with many tags)
# ============================================================================

func add_tags_batch(tag_names: Array, metadata: Dictionary = {}) -> void:
	"""Add multiple tags at once (more efficient than individual adds)."""
	for tag in tag_names:
		add_tag(tag, metadata)

func remove_tags_batch(tag_names: Array) -> void:
	"""Remove multiple tags at once."""
	for tag in tag_names:
		remove_tag(tag)

func has_tags_count(tag_names: Array) -> int:
	"""Count how many of the specified tags exist."""
	var count: int = 0
	for tag in tag_names:
		if has_tag(tag):
			count += 1
	return count
