extends Node

var enemy_spawner: Node

var current_wave_set := ""
var current_wave_index := 0
var spawn_position := Vector2.ZERO
var active_wave_enemies := 0

signal wave_started(wave_set: String, wave_number: int)
signal wave_completed(wave_set: String, wave_number: int)
signal wave_set_completed(wave_set: String)

var lock_spawn_to_screen := false
var spawn_radius := 0.0
var spawn_on_edge := false

var camera: Camera2D

func _ready() -> void:
	await get_tree().process_frame

	enemy_spawner = get_tree().get_first_node_in_group("EnemySpawner")
	if enemy_spawner == null:
		push_error("WaveManager: EnemySpawner not found")
		return

	#camera = get_viewport().get_camera_2d()
	#if camera == null:
	#	push_error("WaveManager: Camera2D not found")

	enemy_spawner.wave_enemy_died.connect(_on_wave_enemy_died)

func start_wave_set(
	wave_set_name: String,
	position: Vector2,
	lock_to_screen := false,
	radius := 0.0,
	on_edge := false
) -> void:
	if not WaveData.WAVES.has(wave_set_name):
		push_error("Wave set not found: %s" % wave_set_name)
		return

	current_wave_set = wave_set_name
	current_wave_index = 1

	spawn_position = position
	lock_spawn_to_screen = lock_to_screen
	spawn_radius = radius
	spawn_on_edge = on_edge

	active_wave_enemies = 0
	_run_current_wave()

func _run_current_wave() -> void:
	var wave_set = WaveData.WAVES[current_wave_set]

	if not wave_set.has(current_wave_index):
		emit_signal("wave_set_completed", current_wave_set)
		return

	emit_signal("wave_started", current_wave_set, current_wave_index)

	var wave_data = wave_set[current_wave_index]
	await _spawn_wave(wave_data)

	while active_wave_enemies > 0:
		await get_tree().process_frame

	emit_signal("wave_completed", current_wave_set, current_wave_index)

	current_wave_index += 1
	await get_tree().create_timer(3.0).timeout
	_run_current_wave()


func _spawn_wave(wave_data: Dictionary) -> void:
	var keys := wave_data.keys()
	keys.sort()

	for enemy_key in keys:
		var entry = wave_data[enemy_key]

		var count: int = entry["Count"]
		var rate: float = entry["SpawnRate"]
		var enemy_template: Dictionary = entry["Enemy"]

		for i in count:
			_spawn_enemy(enemy_template)
			if rate > 0.0:
				await get_tree().create_timer(rate).timeout


func _spawn_enemy(enemy_template: Dictionary) -> void:
	var data := enemy_template.duplicate(true)

	var base_position := _get_base_spawn_position()
	var final_position := _apply_spawn_area(base_position)

	enemy_spawner.spawn_enemy(
		data["type"],
		final_position,
		data.get("behaviour", "ranged"),
		data.get("weapons", []),
		data.get("speed", 100.0),
		data.get("health", 100),
		data.get("rotate_toward_player", true),
		data.get("detectionradius", 1000.0),
		true,
		data.get("LootTable","")
	)

	active_wave_enemies += 1

func _get_base_spawn_position() -> Vector2:
	# World-space behaviour (unchanged)
	if not lock_spawn_to_screen:
		return spawn_position

	# Screen-space behaviour: spawn_position is in SubViewport pixel coordinates
	var game_viewport := get_tree().get_first_node_in_group("GameViewport") as SubViewport
	if game_viewport == null:
		push_warning("WaveManager: GameViewport (SubViewport) not found; falling back to world spawn_position")
		return spawn_position

	# Convert from SubViewport screen-space -> world-space
	# In Godot 4, Viewport's canvas transform includes the active Camera2D.
	return game_viewport.get_canvas_transform().affine_inverse() * spawn_position


func _apply_spawn_area(base_position: Vector2) -> Vector2:
	if spawn_radius <= 0.0:
		return base_position

	var angle := randf() * TAU
	var distance := spawn_radius if spawn_on_edge else sqrt(randf()) * spawn_radius
	var offset := Vector2(cos(angle), sin(angle)) * distance

	return base_position + offset

func _on_wave_enemy_died() -> void:
	active_wave_enemies -= 1
