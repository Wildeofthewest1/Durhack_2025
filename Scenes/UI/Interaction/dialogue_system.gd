extends Node
class_name DialogueSystem

signal dialogue_started()
signal dialogue_ended()
signal dialogue_option_selected(option_id: String)
signal node_changed(node_id: String)

# Dialogue data structure:
# {
#   "node_id": {
#     "text": "The dialogue text",
#     "speaker": "Character Name",
#     "options": [
#       {"text": "Option 1", "next": "next_node_id"},
#       {"text": "Option 2", "next": "other_node_id"}
#     ]
#   }
# }

var dialogue_data: Dictionary = {}
var current_node_id: String = ""
var is_active: bool = false

func load_dialogue(data: Dictionary) -> void:
	dialogue_data = data

func start_dialogue(start_node: String = "start") -> void:
	if dialogue_data.is_empty():
		push_error("DialogueSystem: No dialogue data loaded!")
		return
	
	if not dialogue_data.has(start_node):
		push_error("DialogueSystem: Start node '%s' not found!" % start_node)
		return
	
	current_node_id = start_node
	is_active = true
	dialogue_started.emit()
	node_changed.emit(current_node_id)

func end_dialogue() -> void:
	is_active = false
	current_node_id = ""
	dialogue_ended.emit()

func get_current_node() -> Dictionary:
	if current_node_id.is_empty() or not dialogue_data.has(current_node_id):
		return {}
	return dialogue_data[current_node_id]

func get_current_text() -> String:
	var node: Dictionary = get_current_node()
	return node.get("text", "")

func get_current_speaker() -> String:
	var node: Dictionary = get_current_node()
	return node.get("speaker", "")

func get_current_options() -> Array:
	var node: Dictionary = get_current_node()
	return node.get("options", [])

func select_option(option_index: int) -> void:
	var options: Array = get_current_options()
	
	if option_index < 0 or option_index >= options.size():
		push_error("DialogueSystem: Invalid option index %d" % option_index)
		return
	
	var option: Dictionary = options[option_index]
	var next_node: String = option.get("next", "")
	
	if next_node.is_empty() or next_node == "end":
		end_dialogue()
		return
	
	if not dialogue_data.has(next_node):
		push_error("DialogueSystem: Next node '%s' not found!" % next_node)
		end_dialogue()
		return
	
	current_node_id = next_node
	dialogue_option_selected.emit(option.get("id", str(option_index)))
	node_changed.emit(current_node_id)

func is_dialogue_active() -> bool:
	return is_active

# Helper to create dialogue data programmatically
static func create_dialogue_node(text: String, speaker: String = "", options: Array = []) -> Dictionary:
	return {
		"text": text,
		"speaker": speaker,
		"options": options
	}

static func create_dialogue_option(text: String, next_node: String, option_id: String = "") -> Dictionary:
	return {
		"text": text,
		"next": next_node,
		"id": option_id
	}

# Example dialogue creation
static func create_example_dialogue() -> Dictionary:
	return {
		"start": {
			"text": "Greetings, traveler. What brings you to this sector?",
			"speaker": "Station Commander",
			"options": [
				{"text": "I'm looking for supplies.", "next": "supplies", "id": "ask_supplies"},
				{"text": "Tell me about the alien threat.", "next": "aliens", "id": "ask_aliens"},
				{"text": "Goodbye.", "next": "end", "id": "goodbye"}
			]
		},
		"supplies": {
			"text": "We have a trading post on deck 3. You'll find everything you need there.",
			"speaker": "Station Commander",
			"options": [
				{"text": "Thanks. What about the aliens?", "next": "aliens", "id": "ask_aliens"},
				{"text": "That's all I needed. Goodbye.", "next": "end", "id": "goodbye"}
			]
		},
		"aliens": {
			"text": "The threat is real. They'll arrive in 400 years. We must prepare our defenses now.",
			"speaker": "Station Commander",
			"options": [
				{"text": "How can I help?", "next": "help", "id": "offer_help"},
				{"text": "I see. Goodbye.", "next": "end", "id": "goodbye"}
			]
		},
		"help": {
			"text": "We need resource collectors and defense stations. Every contribution matters.",
			"speaker": "Station Commander",
			"options": [
				{"text": "I'll do what I can.", "next": "end", "id": "accept"},
				{"text": "I need to think about it.", "next": "end", "id": "decline"}
			]
		}
	}
