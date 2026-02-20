extends CharacterBody2D

@export var faceplayer: bool = false
@export var speed: float = 100.0
@export var health: int = 100

@export var rotation_speed: float = 10.0
@export var detectionradius: float = 1000.0

# -----------------------------
# ATTACHMENT SEPARATION TRIGGER
# -----------------------------
@export var separate_when_close_to_player: bool = true
@export var separate_trigger_distance: float = 200.0
@export var speed_match_distance: float = 300.0  # Start matching speed at this distance
@export var speed_match_rate: float = 2.0  # How quickly to match player speed (higher = faster)
@export var separation_slowmo_scale: float = 0.9  # Time scale during separation (0.3 = 30% speed)
@export var separation_slowmo_duration: float = 0.5  # How long the slow-mo lasts

var _did_separate_attachment: bool = false
var _is_matching_speed: bool = false
var _slowmo_timer: float = 0.0

# -----------------------------
# KNOCKBACK (instant pop + fast non-linear decay; no float-away)
# -----------------------------
@export var knockback_max_speed: float = 900.0
@export var knockback_rate_start: float = 6.0
@export var knockback_rate_end: float = 40.0
@export var knockback_ramp_time: float = 0.12
var _kb_velocity: Vector2 = Vector2.ZERO
var _kb_age: float = 999.0

# -----------------------------
# DEATH PARTICLES
# -----------------------------
@export var death_particles_scene: PackedScene
@export var death_particle_dir_jitter: float = 0.15

# -----------------------------
# ITEM DROP
# -----------------------------
const ITEM_CONFIG := {
	"spawn_radius": 24.0,
	"push_distance": 18.0,
	"push_jitter": 10.0,
	"side_spread": 18.0,
	"impulse_min": 140.0,
	"impulse_max": 260.0,
	"impulse_side_bias": 0.6
}

@export var lootTablesFile: GDScript = preload("res://Scenes/Enemy_Configurations/EnemyLootTables.gd")
@export var lootTable: String = ""
@export var item_db: GDScript = preload("res://Scenes/Items/ItemConfig.gd")

# -----------------------------
# STATE
# -----------------------------
var behaviour_type: String = "default"
var behaviour: Node = null
var player: Node2D
var spawner: Node
var escorts: int = 0

var _last_hit_dir: Vector2 = Vector2.RIGHT
var _has_last_hit_dir: bool = false
var _did_die: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	spawner = get_tree().get_first_node_in_group("EnemySpawner")

	assign_behaviour()
	attach_weapons()

func take_damage(amount: int, hit_from_world: Variant = null, knockback_strength: Variant = null) -> void:
	health -= amount

	var hit_dir: Vector2 = Vector2.ZERO

	if hit_from_world is Vector2:
		var from_pos: Vector2 = hit_from_world as Vector2
		var dir: Vector2 = from_pos
		if dir.length_squared() > 0.0001:
			hit_dir = dir.normalized()
			_last_hit_dir = hit_dir
			_has_last_hit_dir = true

	if hit_dir != Vector2.ZERO and knockback_strength != null:
		var kb: float = 0.0
		if knockback_strength is int:
			kb = float(knockback_strength)
		elif knockback_strength is float:
			kb = knockback_strength as float
		elif knockback_strength is Vector2:
			kb = (knockback_strength as Vector2).length()

		if kb != 0.0:
			var desired: Vector2 = hit_dir * kb
			_kb_age = 0.0
			_kb_velocity += desired

			var len: float = _kb_velocity.length()
			if len > knockback_max_speed and len > 0.0001:
				_kb_velocity = _kb_velocity / len * knockback_max_speed

			if has_node("Sprite2D"):
				_flash_red($Sprite2D)

			if health <= 0:
				die()

func _flash_red(sprite: Sprite2D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0), 0.05)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.1)

func die() -> void:
	if _did_die:
		return
	_did_die = true

	_try_separate_attachment()

	var push_dir: Vector2 = _get_death_dir()

	_spawn_death_particles(push_dir)
	_drop_items(push_dir)

	queue_free()

func _get_death_dir() -> Vector2:
	if _has_last_hit_dir:
		return _last_hit_dir

	if player != null:
		var fallback: Vector2 = global_position - player.global_position
		if fallback.length_squared() > 0.0001:
			return fallback.normalized()

	return Vector2.RIGHT

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

	var dir: Vector2 = push_dir.normalized()

	if death_particle_dir_jitter > 0.0:
		dir = dir.rotated(randf_range(-death_particle_dir_jitter, death_particle_dir_jitter))

	p.global_rotation = dir.angle()

	if p.has_method("set_direction"):
		p.call("set_direction", dir)

	if p is GPUParticles2D:
		(p as GPUParticles2D).emitting = true
	elif p is CPUParticles2D:
		(p as CPUParticles2D).emitting = true

func _drop_items(push_dir: Vector2) -> void:
	if lootTablesFile == null or lootTable == "" or item_db == null:
		return

	var parent_node: Node = get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root

	var dir: Vector2 = push_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	for item_key in lootTablesFile.LOOT[lootTable].keys():
		if not item_db.ITEMS.has(item_key):
			continue

		var count: int = lootTablesFile.roll_item_amount(lootTable, item_key)
		if count <= 0:
			continue

		var item_def = item_db.ITEMS[item_key]
		var scene: PackedScene = item_def.scene
		var value_per_pickup: int = item_def.value_per_pickup

		print("🎁 Loot tier:", lootTable)
		print("📦 Item:", item_key, "x", count)

		for i in range(count):
			var pickup: Node2D = scene.instantiate() as Node2D
			parent_node.call_deferred("add_child", pickup)

			var u: float = randf()
			var theta: float = randf_range(0.0, TAU)
			var r: float = sqrt(u) * ITEM_CONFIG.spawn_radius
			var radial_offset: Vector2 = Vector2(cos(theta), sin(theta)) * r

			var forward: float = ITEM_CONFIG.push_distance + randf_range(
				-ITEM_CONFIG.push_jitter,
				ITEM_CONFIG.push_jitter
			)
			var side: float = randf_range(
				-ITEM_CONFIG.side_spread,
				ITEM_CONFIG.side_spread
			)
			var directional_offset: Vector2 = dir * forward + perp * side

			pickup.global_position = global_position + radial_offset + directional_offset

			if pickup is ItemPickup:
				var item: ItemPickup = pickup as ItemPickup
				item.item_id = item_key
				item.item_amount = value_per_pickup

			if pickup.has_method("apply_impulse"):
				var impulse_dir: Vector2 = dir + perp * randf_range(
					-ITEM_CONFIG.impulse_side_bias,
					ITEM_CONFIG.impulse_side_bias
				)
				var impulse_strength: float = randf_range(
					ITEM_CONFIG.impulse_min,
					ITEM_CONFIG.impulse_max
				)
				pickup.call("apply_impulse", impulse_dir, impulse_strength)

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

func _try_separate_attachment() -> void:
	if _did_separate_attachment:
		return
	_did_separate_attachment = true

	# Start slow-motion effect
	Engine.time_scale = separation_slowmo_scale
	_slowmo_timer = separation_slowmo_duration

	_call_separate_recursive(self)

func _call_separate_recursive(n: Node) -> void:
	for c in n.get_children():
		var child: Node = c as Node
		if child == null:
			continue

		if child.has_method("_seperate"):
			child.call_deferred("_seperate")

		_call_separate_recursive(child)

func _physics_process(delta: float) -> void:
	# Update slow-motion timer
	if _slowmo_timer > 0.0:
		_slowmo_timer -= delta
		if _slowmo_timer <= 0.0:
			Engine.time_scale = 1.0
			_slowmo_timer = 0.0

	# Let behaviour run first
	if behaviour != null:
		behaviour.update(delta)

	# Check distance to player for speed matching and separation
	if player != null:
		var dist_sq: float = global_position.distance_squared_to(player.global_position)
		var speed_match_sq: float = speed_match_distance * speed_match_distance
		var separate_sq: float = separate_trigger_distance * separate_trigger_distance

		# Start matching player speed when within speed_match_distance
		if dist_sq <= speed_match_sq:
			_is_matching_speed = true

			# Get player velocity
			var player_vel: Vector2 = Vector2.ZERO
			if "velocity" in player:
				player_vel = player.velocity

			# Gradually match player's speed
			var current_speed: float = velocity.length()
			var target_speed: float = player_vel.length()
			
			if current_speed > 0.1:
				var speed_blend: float = clamp(speed_match_rate * delta, 0.0, 1.0)
				var new_speed: float = lerp(current_speed, target_speed, speed_blend)
				velocity = velocity.normalized() * new_speed

		# Trigger separation when close enough
		if separate_when_close_to_player and (not _did_separate_attachment) and dist_sq <= separate_sq:
			_try_separate_attachment()

	# Face based on behaviour velocity
	if player != null and faceplayer and velocity.length_squared() > 1.0:
		var desired_angle: float = velocity.angle() + deg_to_rad(-90.0)
		rotation = lerp_angle(rotation, desired_angle, delta * rotation_speed)

	# Knockback decay
	_kb_age += delta
	if _kb_velocity.length_squared() > 0.000001:
		var t: float = 1.0
		if knockback_ramp_time > 0.0:
			t = clamp(_kb_age / knockback_ramp_time, 0.0, 1.0)

		var rate: float = lerp(knockback_rate_start, knockback_rate_end, t)
		var alpha: float = 1.0 - exp(-rate * delta)
		_kb_velocity = _kb_velocity.lerp(Vector2.ZERO, alpha)

		if _kb_velocity.length_squared() < 1.0:
			_kb_velocity = Vector2.ZERO

	# Apply knockback
	if _kb_velocity != Vector2.ZERO:
		move_and_collide(_kb_velocity * delta)
