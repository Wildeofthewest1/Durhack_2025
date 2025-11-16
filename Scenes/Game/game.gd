extends Node2D

# Track which enemy to spawn next
var enemy_types = ["Enemy1", "Enemy2", "Enemy3", "Enemy4", "Mothership1", "Mothership2"]
var current_enemy_index: int = 0

# Store reusable data
var enemies = {}

@onready var spawn_timer: Timer = Timer.new()
var enemy_count := 0
const MAX_ENEMIES := 50

func _ready() -> void:
	print("Game script ready")
	var spawner = $PlanetSpawner
	var spawner2 = $EnemySpawner

	# --- Planets setup ---
	var planets = {
		"Star": {
			"position": Vector2(883, 540),
			"velocity": Vector2(1, 0),
			"mass": 100,
			"radius": 120,
			"colour": Color(0.9, 0.795, 0, 1)
		},
		"Planet1": {
			"position": Vector2(1250, 565),
			"velocity": Vector2(0, -1),
			"mass": 100,
			"radius": 40,
			"colour": Color(0, 0.622, 0.723, 1)
		},
		"Planet2": {
			"position": Vector2(3013, -1201),
			"velocity": Vector2(1, 0) * 300,
			"mass": 100,
			"radius": 30,
			"colour": Color(0.741, 0.47, 0.007, 1)
		},
		"Planet3": {
			"position": Vector2(3013, -1201),
			"velocity": Vector2(1, 0),
			"mass": 100,
			"radius": 20,
			"colour": Color(0.82, 0.325, 0, 1)
		},
		"Planet4": {
			"position": Vector2(2205, 1030),
			"velocity": Vector2(0, 1),
			"mass": 50,
			"radius": 20,
			"colour": Color(0, 0.691, 0.306, 1)
		},
		"Planet5": {
			"position": Vector2(851, 751),
			"velocity": Vector2(0, 1),
			"mass": 50,
			"radius": 20,
			"colour": Color(0.573, 0.2, 1, 1)
		},
		"Planet6": {
			"position": Vector2(-133, -694),
			"velocity": Vector2(1, 0),
			"mass": 10,
			"radius": 20,
			"colour": Color(0.813, 0.407, 0.273, 1)
		},
	}

	for name in planets.keys():
		var p = planets[name]
		spawner.spawn_planet(
			p["position"],
			p["velocity"],
			p["mass"],
			p["radius"],
			p["colour"]
		)

	# --- Enemies setup ---
	enemies = {
		"Enemy1": {
			"type": "Enemy1",
			"position": Vector2(-800, 400),
			"behaviour": "ranged",
			"weapons": ["res://Scenes/Enemy_Weapons/Shotgun.tscn"],
			"speed": 150,
			"health": 80,
			"rotate_toward_player": true,
			"detectionradius": 500
		},
		"Enemy2": {
			"type": "Enemy2",
			"position": Vector2(0, 0),
			"behaviour": "ranged",
			"weapons": ["res://Scenes/Enemy_Weapons/Pistol.tscn"],
			"speed": 120,
			"health": 100,
			"rotate_toward_player": true,
			"detectionradius": 500
		},
		"Enemy3": {
			"type": "Enemy3",
			"position": Vector2(-1000, 200),
			"behaviour": "ranged",
			"weapons": ["res://Scenes/Enemy_Weapons/Shotgun.tscn"],
			"speed": 100,
			"health": 500,
			"rotate_toward_player": true,
			"detectionradius": 500
		},
		"Enemy4": {
			"type": "Enemy4",
			"position": Vector2(-100, 2000),
			"behaviour": "ranged",
			"weapons": ["res://Scenes/Enemy_Weapons/Shotgun.tscn"],
			"speed": 100,
			"health": 750,
			"rotate_toward_player": true,
			"detectionradius": 500
		},
		"Mothership1": {
			"type": "Mothership1",
			"position": Vector2(-1000, 1000),
			"behaviour": "mothership",
			"weapons": ["res://Scenes/Enemy_Weapons/Shotgun.tscn"],
			"speed": 10,
			"health": 2000,
			"rotate_toward_player": false,
			"detectionradius": 1000
		},
		"Mothership2": {
			"type": "Mothership2",
			"position": Vector2(500, 300),
			"behaviour": "mothership",
			"weapons": ["res://Scenes/Enemy_Weapons/Pistol.tscn"],
			"speed": 20,
			"health": 1000,
			"rotate_toward_player": false,
			"detectionradius": 1000
		}
	}

	for name2 in enemies.keys():
		var e = enemies[name2]
		spawner2.spawn_enemy(
			e["type"],
			e["position"],
			e["behaviour"],
			e["weapons"],
			e["speed"],
			e["health"],
			e["rotate_toward_player"],
			e["detectionradius"]
		)
		
	spawn_timer.wait_time = 3.0
	spawn_timer.one_shot = false
	spawn_timer.autostart = false
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_auto_spawn_enemy)

func _on_years_invasion_started_signal() -> void:
	enemy_count = 0
	_on_spawn_enemy_button_pressed()  # spawn one immediately
	spawn_timer.start()

func _auto_spawn_enemy() -> void:
	if enemy_count >= MAX_ENEMIES:
		spawn_timer.stop()
		print("Reached 50 enemies — invasion stopped.")
		return

	_on_spawn_enemy_button_pressed()
	enemy_count += 1

# --- Button spawn function ---
func _on_spawn_enemy_button_pressed() -> void:
	var player = $PlayerContainer/Player
	var spawner = $EnemySpawner

	# Cycle through defined enemy types
	var enemy_type = enemy_types[current_enemy_index]
	current_enemy_index = (current_enemy_index + 1) % enemy_types.size()

	if not enemies.has(enemy_type):
		push_warning("Enemy type %s not found in dictionary" % enemy_type)
		return

	var e = enemies[enemy_type]

	# Random offset around player
	var min_distance: float = 200.0
	var max_distance: float = 400.0
	var angle: float = randf() * TAU
	var distance: float = randf_range(min_distance, max_distance)
	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * distance
	var spawn_position: Vector2 = player.global_position + offset

	print("Spawning enemy:", enemy_type)

	# Call spawner with same parameters as dictionary
	spawner.spawn_enemy(
		e["type"],
		spawn_position,
		e["behaviour"],
		e["weapons"],
		e["speed"],
		e["health"],
		e["rotate_toward_player"],
		e["detectionradius"]
	)
