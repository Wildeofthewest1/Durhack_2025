extends CharacterBody2D

@export var faceplayer: bool = false
@export var speed: float = 100.0
@export var health: int = 100

@export var rotation_speed: float = 10.0
@export var detectionradius: float = 1000.0

# -----------------------------
# DEATH PARTICLES
# -----------------------------
@export var death_particles_scene: PackedScene
@export var death_particle_dir_jitter: float = 0.15

# -----------------------------
# SCRAP DROP
# -----------------------------
@export var scrap_pickup_scene: PackedScene = preload("res://Scenes/Bodies/Interactibles/money/scrap.tscn")

@export var scrap_drop_min: int = 2
@export var scrap_drop_max: int = 6

@export var scrap_spawn_radius: float = 24.0

@export var scrap_push_distance: float = 18.0
@export var scrap_push_jitter: float = 10.0
@export var scrap_side_spread: float = 18.0

# IMPULSE CONTROL (enemy-owned)
@export var scrap_impulse_min: float = 140.0
@export var scrap_impulse_max: float = 260.0
@export var scrap_impulse_side_bias: float = 0.6

@export var scrap_value_min: int = 1
@export var scrap_value_max: int = 3

# -----------------------------
# STATE
# -----------------------------
var behaviour_type: String = "default"
var behaviour: Node = null
var player: Node2D
var spawner: Node
var escorts: int = 0

# Last hit direction (away from attacker)
var _last_hit_dir: Vector2 = Vector2.RIGHT
var _has_last_hit_dir: bool = false
var _did_die: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	spawner = get_tree().get_first_node_in_group("EnemySpawner")

	assign_behaviour()
	attach_weapons()

# ----------------------------------------------------
# DAMAGE (direction optional)
# ----------------------------------------------------
func take_damage(amount: int, hit_from_world: Variant = null) -> void:
	health -= amount

	if hit_from_world is Vector2:
		var from_pos: Vector2 = hit_from_world as Vector2
		var dir: Vector2 = global_position - from_pos
		if dir.length_squared() > 0.0001:
			_last_hit_dir = dir.normalized()
			_has_last_hit_dir = true

	if has_node("Sprite2D"):
		_flash_red($Sprite2D)

	if health <= 0:
		die()

func _flash_red(sprite: Sprite2D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0), 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.1)

# ----------------------------------------------------
# DEATH
# ----------------------------------------------------
func die() -> void:
	if _did_die:
		return
	_did_die = true

	var push_dir: Vector2 = _get_death_dir()

	_spawn_death_particles(push_dir)
	_drop_scrap(push_dir)

	queue_free()

func _get_death_dir() -> Vector2:
	if _has_last_hit_dir:
		return _last_hit_dir

	if player != null:
		var fallback: Vector2 = global_position - player.global_position
		if fallback.length_squared() > 0.0001:
			return fallback.normalized()

	return Vector2.RIGHT

# ----------------------------------------------------
# DEATH PARTICLES (DIRECTION ONLY)
# ----------------------------------------------------
func _spawn_death_particles(push_dir: Vector2) -> void:
	if death_particles_scene == null:
		return

	var p: Node2D = death_particles_scene.instantiate() as Node2D

	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root

	parent_node.add_child(p)
	p.global_position = global_position

	# Enemy provides ONLY direction (particle handles speed)
	var dir: Vector2 = push_dir.normalized()

	# Optional jitter so it’s not laser-straight
	if death_particle_dir_jitter > 0.0:
		dir = dir.rotated(randf_range(
			-death_particle_dir_jitter,
			death_particle_dir_jitter
		))

	# Two safe ways to pass direction:
	# 1) rotation (most common)
	p.global_rotation = dir.angle()

	# 2) or explicit method if you want (optional)
	if p.has_method("set_direction"):
		p.call("set_direction", dir)

	if p is GPUParticles2D:
		(p as GPUParticles2D).emitting = true
	elif p is CPUParticles2D:
		(p as CPUParticles2D).emitting = true

# ----------------------------------------------------
# SCRAP DROP (SINGLE IMPULSE SOURCE)
# ----------------------------------------------------
func _drop_scrap(push_dir: Vector2) -> void:
	if scrap_pickup_scene == null:
		return

	var count: int = randi_range(scrap_drop_min, scrap_drop_max)
	if count <= 0:
		return

	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root

	var dir: Vector2 = push_dir.normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	for i in range(count):
		var pickup: Node2D = scrap_pickup_scene.instantiate() as Node2D
		parent_node.add_child(pickup)

		# Spawn position
		var u: float = randf()
		var theta: float = randf_range(0.0, TAU)
		var r: float = sqrt(u) * scrap_spawn_radius
		var radial_offset: Vector2 = Vector2(cos(theta), sin(theta)) * r

		var forward: float = scrap_push_distance + randf_range(-scrap_push_jitter, scrap_push_jitter)
		var side: float = randf_range(-scrap_side_spread, scrap_side_spread)
		var directional_offset: Vector2 = dir * forward + perp * side

		pickup.global_position = global_position + radial_offset + directional_offset

		pickup.set("scrap_amount", randi_range(scrap_value_min, scrap_value_max))

		# Single impulse (enemy-owned)
		if pickup.has_method("apply_impulse"):
			var impulse_dir: Vector2 = dir + perp * randf_range(
				-scrap_impulse_side_bias,
				scrap_impulse_side_bias
			)
			var impulse_strength: float = randf_range(scrap_impulse_min, scrap_impulse_max)
			pickup.call("apply_impulse", impulse_dir, impulse_strength)

# ----------------------------------------------------
# BEHAVIOUR SYSTEM
# ----------------------------------------------------
func assign_behaviour() -> void:
	var behaviour_paths: Dictionary = {
		"melee": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/melee_behaviour.gd",
		"ranged": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/ranged_behaviour.gd",
		"pursuer": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/pursuer_behaviour.gd",
		"charger": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/charger_behaviour.gd",
		"mothership": "res://Scenes/Enemy_Configurations/Enemy_Behaviour/mothership_behaviour.gd",
	}

	var script_path: String = behaviour_paths.get(
		behaviour_type,
		behaviour_paths["ranged"]
	)

	var behaviour_script: Script = load(script_path)
	if behaviour_script == null:
		return

	behaviour = behaviour_script.new()
	behaviour.enemy = self

func attach_weapons() -> void:
	var weapon_scenes: Array[PackedScene] = [
		preload("res://Scenes/Enemy_Weapons/Pistol.tscn"),
		preload("res://Scenes/Enemy_Weapons/Shotgun.tscn"),
		preload("res://Scenes/Enemy_Weapons/CircleGun.tscn")
	]

	if not has_node("WeaponSlots"):
		return

	var weapon_slots: Array = $WeaponSlots.get_children()

	if not has_node("Weapons"):
		var weapons_node: Node2D = Node2D.new()
		weapons_node.name = "Weapons"
		add_child(weapons_node)

	for i in range(weapon_slots.size()):
		var weapon: Node2D = weapon_scenes[i % weapon_scenes.size()].instantiate() as Node2D
		weapon.position = (weapon_slots[i] as Node2D).position
		$Weapons.add_child(weapon)

func _physics_process(delta: float) -> void:
	if player != null and faceplayer and velocity.length_squared() > 1.0:
		var desired_angle: float = velocity.angle() + deg_to_rad(-90.0)
		rotation = lerp_angle(rotation, desired_angle, delta * rotation_speed)

	if behaviour != null:
		behaviour.update(delta)
