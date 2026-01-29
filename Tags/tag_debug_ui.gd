extends CanvasLayer

## Debug UI for TagManager - View and manipulate tags at runtime
## Press F3 to toggle this panel during development

@onready var panel: Panel = $Panel
@onready var tag_list: ItemList = $Panel/VBoxContainer/TagList
@onready var search_box: LineEdit = $Panel/VBoxContainer/HBoxContainer/SearchBox
@onready var add_tag_field: LineEdit = $Panel/VBoxContainer/HBoxContainer2/AddTagField
@onready var stats_label: Label = $Panel/VBoxContainer/StatsLabel
@onready var category_filter: OptionButton = $Panel/VBoxContainer/HBoxContainer/CategoryFilter

var visible_state: bool = false
var selected_tag: String = ""
var update_timer: float = 0.0
var update_interval: float = 0.5 # Update every 0.5 seconds

func _ready() -> void:
	panel.visible = false
	setup_ui()
	populate_category_filter()
	refresh_tag_list()

func _process(delta: float) -> void:
	# Toggle visibility with F3
	if Input.is_action_just_pressed("ui_cancel") and Input.is_key_pressed(KEY_F3):
		toggle_visibility()
	
	# Auto-refresh if visible
	if visible_state:
		update_timer += delta
		if update_timer >= update_interval:
			update_timer = 0.0
			refresh_tag_list()
			update_stats()

func toggle_visibility() -> void:
	visible_state = not visible_state
	panel.visible = visible_state
	
	if visible_state:
		refresh_tag_list()
		update_stats()

func setup_ui() -> void:
	# Set up search box
	search_box.placeholder_text = "Search tags..."
	search_box.text_changed.connect(_on_search_changed)
	
	# Set up add tag field
	add_tag_field.placeholder_text = "Enter tag name..."
	
	# Set up tag list
	tag_list.item_selected.connect(_on_tag_selected)

func populate_category_filter() -> void:
	"""Add common tag categories to filter dropdown"""
	category_filter.add_item("All Categories", 0)
	category_filter.add_item("quest:*", 1)
	category_filter.add_item("key:*", 2)
	category_filter.add_item("dialogue:*", 3)
	category_filter.add_item("upgrade:*", 4)
	category_filter.add_item("discovery:*", 5)
	category_filter.add_item("state:*", 6)
	category_filter.add_item("achievement:*", 7)
	category_filter.add_item("faction:*", 8)
	category_filter.add_item("combat:*", 9)
	category_filter.item_selected.connect(_on_category_changed)

func refresh_tag_list() -> void:
	"""Refresh the list of tags based on current filter"""
	tag_list.clear()
	
	var all_tags: Array = TagManager.get_all_tags()
	var search_text: String = search_box.text.to_lower()
	var category_idx: int = category_filter.selected
	var category_pattern: String = ""
	
	# Get category filter pattern
	if category_idx > 0:
		category_pattern = category_filter.get_item_text(category_idx)
	
	# Sort tags alphabetically
	all_tags.sort()
	
	for tag in all_tags:
		# Apply search filter
		if search_text != "" and not tag.to_lower().contains(search_text):
			continue
		
		# Apply category filter
		if category_pattern != "":
			var matching: Array = TagManager.get_tags_matching(category_pattern)
			if not tag in matching:
				continue
		
		# Add to list
		var display_text: String = tag
		
		# Show counter value if it exists
		var counter_value: int = TagManager.get_tag_count(tag)
		if counter_value > 0:
			display_text += " [" + str(counter_value) + "]"
		
		tag_list.add_item(display_text)

func update_stats() -> void:
	"""Update the statistics display"""
	var total_tags: int = TagManager.get_all_tags().size()
	var total_counters: int = 0
	
	# Count active counters
	for tag in TagManager.get_all_tags():
		if TagManager.get_tag_count(tag) > 0:
			total_counters += 1
	
	stats_label.text = "Total Tags: %d | Counters: %d" % [total_tags, total_counters]

func _on_search_changed(new_text: String) -> void:
	refresh_tag_list()

func _on_category_changed(index: int) -> void:
	refresh_tag_list()

func _on_tag_selected(index: int) -> void:
	"""When a tag is selected in the list"""
	var tag_text: String = tag_list.get_item_text(index)
	# Remove counter suffix if present
	if "[" in tag_text:
		tag_text = tag_text.split("[")[0].strip_edges()
	
	selected_tag = tag_text
	print("[TagDebugUI] Selected: ", selected_tag)

func _on_add_button_pressed() -> void:
	"""Add a new tag"""
	var new_tag: String = add_tag_field.text.strip_edges()
	
	if new_tag == "":
		print("[TagDebugUI] Error: Tag name cannot be empty")
		return
	
	if not GameTags.is_valid_tag_format(new_tag):
		print("[TagDebugUI] Warning: Tag doesn't follow naming convention (category:name)")
	
	TagManager.add_tag(new_tag, {"source": "debug_ui"})
	add_tag_field.text = ""
	refresh_tag_list()
	print("[TagDebugUI] Added tag: ", new_tag)

func _on_remove_button_pressed() -> void:
	"""Remove the selected tag"""
	if selected_tag == "":
		print("[TagDebugUI] Error: No tag selected")
		return
	
	TagManager.remove_tag(selected_tag)
	refresh_tag_list()
	print("[TagDebugUI] Removed tag: ", selected_tag)
	selected_tag = ""

func _on_clear_all_button_pressed() -> void:
	"""Clear all tags (with confirmation)"""
	# In a real implementation, you'd want a confirmation dialog
	print("[TagDebugUI] Clearing all tags...")
	TagManager.clear_all_tags()
	refresh_tag_list()

func _on_print_stats_button_pressed() -> void:
	"""Print detailed stats to console"""
	TagManager.print_tag_stats()

func _on_export_button_pressed() -> void:
	"""Export all tags to a file for documentation"""
	var all_tags: Array = TagManager.get_all_tags()
	all_tags.sort()
	
	var export_text: String = "# Tag Export - " + Time.get_datetime_string_from_system() + "\n\n"
	
	# Group by category
	var categories: Dictionary = {}
	for tag in all_tags:
		var parts: Array = tag.split(":")
		if parts.size() > 0:
			var category: String = parts[0]
			if not categories.has(category):
				categories[category] = []
			categories[category].append(tag)
	
	# Write organized output
	for category in categories.keys():
		export_text += "## " + category.to_upper() + "\n"
		for tag in categories[category]:
			var metadata: Dictionary = TagManager.get_tag_metadata(tag)
			export_text += "- " + tag
			if metadata.has("added_at"):
				var time: String = Time.get_datetime_string_from_unix_time(metadata["added_at"])
				export_text += " (added: " + time + ")"
			export_text += "\n"
		export_text += "\n"
	
	# Save to file
	var file: FileAccess = FileAccess.open("user://tag_export.txt", FileAccess.WRITE)
	if file:
		file.store_string(export_text)
		file.close()
		print("[TagDebugUI] Tags exported to: ", OS.get_user_data_dir(), "/tag_export.txt")
	else:
		print("[TagDebugUI] Error: Could not export tags")

func _on_increment_button_pressed() -> void:
	"""Increment counter for selected tag"""
	if selected_tag == "":
		print("[TagDebugUI] Error: No tag selected")
		return
	
	var new_value: int = TagManager.increment_tag(selected_tag)
	print("[TagDebugUI] Incremented ", selected_tag, " to ", new_value)
	refresh_tag_list()

func _on_decrement_button_pressed() -> void:
	"""Decrement counter for selected tag"""
	if selected_tag == "":
		print("[TagDebugUI] Error: No tag selected")
		return
	
	var new_value: int = TagManager.decrement_tag(selected_tag)
	print("[TagDebugUI] Decremented ", selected_tag, " to ", new_value)
	refresh_tag_list()
