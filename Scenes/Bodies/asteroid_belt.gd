extends Node2D
class_name AsteroidBelt

@export var damage_per_second: float = 10.0

# Must match the player's collision layer(s): 1, 2, 4, 8, ... or OR'ed.
@export var query_collision_mask: int = 1

# If true, only nodes in group "player" (or their parents) can be damaged.
# If false, we damage any collider we detect that has take_damage/damage on it or its parents.
@export var require_player_group: bool = true

@export var debug_print: bool = false

@onready var outer_shape_node: CollisionShape2D = $OuterArea/OuterCollision
@onready var inner_shape_node: CollisionShape2D = $InnerArea/InnerCollision

var _belt_fx: AsteroidBeltScreenFX = null
var _damage_accum: Dictionary = {} # Node2D -> float
var damaged_this_frame: Dictionary = {}


func _ready() -> void:
	_belt_fx = get_tree().get_first_node_in_group("asteroid_belt_fx") as AsteroidBeltScreenFX


func _physics_process(delta: float) -> void:
	_apply_damage_and_fx(delta)


func _apply_damage_and_fx(delta: float) -> void:
	var outer_hits: Dictionary = _query_circle_hits(outer_shape_node)
	var inner_hits: Dictionary = _query_circle_hits(inner_shape_node)

	var any_in_ring: bool = false

	for key in outer_hits.keys():
		var collider_node: Node2D = key as Node2D
		if collider_node == null or is_instance_valid(collider_node) == false:
			continue

		# Is collider also inside inner? (safe hole)
		if inner_hits.has(collider_node):
			continue

		# Find who should receive damage
		var target: Node2D = _resolve_damage_target(collider_node)
		if target == null:
			if debug_print:
				print("No damage target resolved for collider: ", collider_node.name)
			continue

		# Now check if THAT target is in inner (in case collider != target)
		if inner_hits.has(target):
			continue
		if damaged_this_frame.has(target):
			continue
		damaged_this_frame[target] = true

		any_in_ring = true
		_apply_damage_accumulated(target, delta)

		# Cleanup accum entries for targets that weren't seen in-ring this frame
		# (or you can use 'in_outer_targets' if you want to keep it while in outer)
		var to_erase: Array[Node2D] = []
		for k in _damage_accum.keys():
			var t: Node2D = k as Node2D
			if t == null or is_instance_valid(t) == false:
				to_erase.append(t)
				continue
			if damaged_this_frame.has(t) == false:
				# Not processed this frame -> reset/erase so it doesn't "carry" forever
				# Choose ONE behavior:
				# A) erase (recommended)
				to_erase.append(t)
				# B) or keep but don't erase:
				# _damage_accum[t] = 0.0

		for t2: Node2D in to_erase:
			_damage_accum.erase(t2)


func _query_circle_hits(shape_node: CollisionShape2D) -> Dictionary:
	var out: Dictionary = {}
	if shape_node == null:
		return out

	var circle: CircleShape2D = shape_node.shape as CircleShape2D
	if circle == null:
		return out

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state

	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = shape_node.global_transform
	params.collision_mask = query_collision_mask
	params.collide_with_bodies = true
	params.collide_with_areas = true

	var results: Array[Dictionary] = space_state.intersect_shape(params, 64)
	for hit in results:
		var collider: Object = hit.get("collider")
		if collider is Node2D:
			out[collider] = true

	return out


# ---------------------------------------------------------------------
# DAMAGE TARGET RESOLUTION
# ---------------------------------------------------------------------

func _resolve_damage_target(from_collider: Node2D) -> Node2D:
	# 1) If we require player group, first find a parent in group "player"
	if require_player_group:
		var player_root: Node2D = _find_parent_in_group(from_collider, "player")
		if player_root == null:
			return null

		# If player root has damage method, use it, otherwise keep searching upwards
		var dmg_node: Node2D = _find_parent_with_damage_method(player_root)
		return dmg_node

	# 2) Otherwise, just find the nearest parent (including self) with damage method
	return _find_parent_with_damage_method(from_collider)


func _find_parent_in_group(node: Node, group_name: String) -> Node2D:
	var cur: Node = node
	while cur != null:
		if cur is Node2D and cur.is_in_group(group_name):
			return cur as Node2D
		cur = cur.get_parent()
	return null


func _find_parent_with_damage_method(node: Node) -> Node2D:
	var cur: Node = node
	while cur != null:
		if cur is Node2D:
			var n2: Node2D = cur as Node2D
			if n2.has_method("take_damage") or n2.has_method("damage"):
				return n2
		cur = cur.get_parent()
	return null


# ---------------------------------------------------------------------
# DAMAGE APPLICATION
# ---------------------------------------------------------------------

func _apply_damage_accumulated(target: Node2D, delta: float) -> void:
	var accum: float = float(_damage_accum.get(target, 0.0))
	accum += damage_per_second * delta

	# Apply in configurable integer ticks
	var tick_f: float = float(max(1, damage_tick))
	while accum >= tick_f:
		accum -= tick_f
		_damage_body_int(target, int(tick_f))

	_damage_accum[target] = accum

func _damage_body_float(target: Node2D, amount: float) -> void:
	if amount <= 0.0:
		return

	if target.has_method("take_damage"):
		target.take_damage(amount)
	elif target.has_method("damage"):
		target.damage(amount)
