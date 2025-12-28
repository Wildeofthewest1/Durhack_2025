extends Node

signal dialogue_started(npc: Node)
signal dialogue_ended()

var current_npc: Node = null
var _running: bool = false

func is_running() -> bool:
	return _running

func start_for_npc(npc: Node, timeline: Resource) -> void:
	# stop any previous timeline
	if _running == true:
		end_dialogue()

	current_npc = npc
	_running = true
	dialogue_started.emit(npc)

	if timeline == null:
		push_warning("DialogueService: timeline is null.")
		return

	var path: String = timeline.resource_path
	if path.length() == 0:
		push_warning("DialogueService: timeline has empty resource_path.")
		return

	# CRITICAL: start_timeline (no Dialogic layout/UI)
	Dialogic.start_timeline(path)

func end_dialogue() -> void:
	if _running == false:
		return

	# End immediately; do not show dialogic UI
	Dialogic.end_timeline(true)

func _ready() -> void:
	# Dialogic emits when timeline ends
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended) == false:
		Dialogic.timeline_ended.connect(_on_timeline_ended)

func _on_timeline_ended() -> void:
	_running = false
	current_npc = null
	dialogue_ended.emit()
