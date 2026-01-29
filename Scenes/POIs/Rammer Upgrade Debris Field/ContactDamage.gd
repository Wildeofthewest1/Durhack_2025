extends Area2D

@export var damage: int = 10
@export var team: String = ""  # Leave empty to damage everyone, or set to "Enemy"/"Fleet"/"player"
@export var damage_interval: float = 0.0  # 0 = one-time damage, >0 = continuous damage every X seconds
@export var explosion: PackedScene = preload("res://Scenes/particles/explosion.tscn")

var bodies_in_contact: Dictionary = {}  # Track bodies for continuous damage

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	if damage_interval > 0.0:
		connect("body_exited", Callable(self, "_on_body_exited"))

func _process(delta: float) -> void:
	if damage_interval <= 0.0:
		return
	
	# Apply continuous damage to all bodies in contact
	for body: Node in bodies_in_contact.keys():
		if not is_instance_valid(body):
			bodies_in_contact.erase(body)
			continue
		
		bodies_in_contact[body] += delta
		if bodies_in_contact[body] >= damage_interval:
			bodies_in_contact[body] = 0.0
			_apply_damage(body)

func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return
	
	# Friendly fire filtering
	if team == "Enemy" and body.is_in_group("Enemy"):
		return
	if team == "Fleet" and (body.is_in_group("Fleet") or body.is_in_group("player")):
		return
	if team == "player" and body.is_in_group("Fleet"):
		return
	
	if damage_interval > 0.0:
		# Continuous damage: track the body
		bodies_in_contact[body] = damage_interval  # Trigger immediately on first contact
		_apply_damage(body)
	else:
		# One-time damage
		_apply_damage(body)

func _on_body_exited(body: Node) -> void:
	if bodies_in_contact.has(body):
		bodies_in_contact.erase(body)

func _apply_damage(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		_spawn_explosion()

func _spawn_explosion() -> void:
	if explosion == null:
		return
	
	var explo: GPUParticles2D = explosion.instantiate() as GPUParticles2D
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.add_child(explo)
		explo.global_position = global_position
		explo.emitting = true
