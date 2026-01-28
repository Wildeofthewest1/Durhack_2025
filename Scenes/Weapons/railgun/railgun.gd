extends WeaponBase
class_name WeaponRailgun

@export var muzzle_path: NodePath = NodePath("Muzzle")
@export var spawn_offset_px: float = 0.0
@export var max_range: float = 900.0

@export var charge_time: float = 0.4
@export var charge_particles_path: NodePath = NodePath("ChargeParticles")

@export var knockback_distance: float = 4.0
@export var knockback_duration: float = 0.08

var _muzzle: Node2D = null
@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer2D
var _charge_particles: GPUParticles2D = null

var _is_charging: bool = false
var _charge_timer: float = 0.0
var _wants_to_fire: bool = false

var _knockback_owner: Node2D = null
var _knockback_timer: float = 0.0
var _knockback_dir: Vector2 = Vector2.ZERO
var _knockback_applied_fraction: float = 0.0

func _ready() -> void:
	super._ready()
	_muzzle = get_node(muzzle_path) as Node2D
	if charge_particles_path != NodePath(""):
		_charge_particles = get_node(charge_particles_path) as GPUParticles2D

	_knockback_owner = _find_knockback_owner()
	_update_aim()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_aim()
	_update_charge(delta)
	_update_knockback(delta)

func _update_aim() -> void:
	var mouse_world: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_world - global_position
	var dist: float = to_mouse.length()
	if dist > 0.0:
		_aim_dir = to_mouse / dist

func request_fire() -> void:
	_wants_to_fire = true
	if _is_charging:
		return
	_start_charge()

func release_fire() -> void:
	_wants_to_fire = false
	if _is_charging:
		_is_charging = false
		_charge_timer = 0.0
		if _charge_particles != null:
			_charge_particles.emitting = false

func _start_charge() -> void:
	_is_charging = true
	_charge_timer = charge_time
	if _charge_particles != null:
		_charge_particles.emitting = true

func _update_charge(delta: float) -> void:
	if not _is_charging:
		return

	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_is_charging = false
		if _charge_particles != null:
			_charge_particles.emitting = false

		if _wants_to_fire:
			try_fire(_aim_dir)
			if _current_mag <= 0 or _is_reloading:
				_wants_to_fire = false

func _fire_projectile(dir: Vector2) -> void:
	if data == null:
		return
	if _muzzle == null:
		push_error("WeaponRailgun: muzzle is missing")
		return

	var fire_dir: Vector2 = dir
	if fire_dir.length() == 0.0:
		fire_dir = Vector2.RIGHT
	fire_dir = fire_dir.normalized()

	_start_knockback(-fire_dir)

	var origin: Vector2 = _muzzle.global_position + fire_dir * spawn_offset_px
	var target: Vector2 = origin + fire_dir * max_range

	var end_point: Vector2 = _piercing_hitscan(origin, target, fire_dir)
	_spawn_beam(origin, end_point)

	if _audio != null:
		_audio.play()

	if data.flash_scene != null:
		var flash_instance: Node2D = data.flash_scene.instantiate() as Node2D
		_muzzle.add_child(flash_instance)
		flash_instance.position = Vector2.ZERO
		flash_instance.rotation = 0.0
		flash_instance.scale = Vector2(1.0, 1.0)

func _piercing_hitscan(origin: Vector2, target: Vector2, fire_dir: Vector2) -> Vector2:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var exclude_rids: Array[RID] = []

	var parent_node: Node = get_parent()
	if parent_node is CollisionObject2D:
		var parent_body: CollisionObject2D = parent_node as CollisionObject2D
		exclude_rids.append(parent_body.get_rid())

	var from_point: Vector2 = origin
	var last_hit_pos: Vector2 = target

	var max_iterations: int = 32
	for i in range(max_iterations):
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_point, target)
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.exclude = exclude_rids

		var result: Dictionary = space.intersect_ray(query)
		if result.is_empty():
			break

		var collider: Object = result["collider"]
		var hit_pos: Vector2 = result["position"]
		var rid: RID = result["rid"]
		exclude_rids.append(rid)

		if collider != null and _is_damageable(collider):
			_apply_hit_damage(collider)
			last_hit_pos = hit_pos

		from_point = hit_pos + fire_dir * 1.0

		var remaining: Vector2 = target - from_point
		if remaining.length() <= 0.5:
			break

	return last_hit_pos

func _is_damageable(collider: Object) -> bool:
	return collider.is_in_group("Enemy")

func _apply_hit_damage(collider: Object) -> void:
	var damage: float = get_effective_damage()
	var kb: float = get_effective_knockback()

	if collider.has_method("take_damage"):
		collider.call("take_damage", damage, global_position, kb)
	elif collider.has_method("apply_damage"):
		collider.call("apply_damage", damage)
	elif collider.has_method("damage"):
		collider.call("damage", damage)

func _spawn_beam(origin: Vector2, end_point: Vector2) -> void:
	if data.bullet_scene == null:
		return

	var beam: RailgunBeam = data.bullet_scene.instantiate() as RailgunBeam

	var parent_node: Node = get_parent().get_parent().get_parent().get_parent()
	if parent_node == null:
		parent_node = get_parent()
	if parent_node == null:
		return

	parent_node.add_child(beam)
	beam.setup(origin, end_point)

func _find_knockback_owner() -> Node2D:
	var node: Node = get_parent()
	node = node.get_parent().get_parent()
	if node is Node2D:
		return node as Node2D
	return null

func _start_knockback(direction: Vector2) -> void:
	if _knockback_owner == null:
		_knockback_owner = _find_knockback_owner()
	if _knockback_owner == null:
		return
	if direction.length() == 0.0:
		return

	_knockback_dir = direction.normalized()
	_knockback_timer = knockback_duration
	_knockback_applied_fraction = 0.0

func _update_knockback(delta: float) -> void:
	if _knockback_owner == null:
		return
	if _knockback_timer <= 0.0:
		return

	_knockback_timer -= delta
	if _knockback_timer < 0.0:
		_knockback_timer = 0.0

	var total_time: float = knockback_duration
	if total_time <= 0.0:
		total_time = 0.0001

	var life_ratio: float = _knockback_timer / total_time
	if life_ratio < 0.0:
		life_ratio = 0.0
	if life_ratio > 1.0:
		life_ratio = 1.0

	var progressed_fraction: float = 1.0 - life_ratio
	if progressed_fraction < 0.0:
		progressed_fraction = 0.0
	if progressed_fraction > 1.0:
		progressed_fraction = 1.0

	var delta_fraction: float = progressed_fraction - _knockback_applied_fraction
	_knockback_applied_fraction = progressed_fraction

	var offset: Vector2 = _knockback_dir * knockback_distance * delta_fraction
	_knockback_owner.global_position += offset

	if _knockback_timer <= 0.0:
		_knockback_timer = 0.0
