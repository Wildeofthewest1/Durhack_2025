extends CharacterBody2D

@export var initial_speed: float = 300.0
@export var lifetime: float = 3.0
@export var deceleration: float = 0.0
@export var damage: int = 10
@export var gravity_multiplier: float = 1.0
@export var gravitational_constant: float = 100000.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox

@export var explosion: PackedScene = preload("res://Scenes/particles/explosion.tscn")

@export var health: float = 1.0

var direction: Vector2 = Vector2.UP
@export var team: String = ""   # "Enemy", "Fleet", or "player"

func _ready() -> void:
	velocity = direction.normalized() * initial_speed
	if hitbox:
		hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func take_damage(amount: int) -> void:
	health -= amount
	#print("%s took %d damage, remaining health: %d" % [name, amount, health])
	if health <= 0:
		die()

func die() -> void:
	#print("%s has died" % name)
	#_spawn_explosion()
	queue_free()

func _physics_process(delta: float) -> void:
	"""
	# --- Apply gravitational pull from all planets ---
	for planet in get_tree().get_nodes_in_group("Planets"):
		if not ("mass" in planet and "radius" in planet):
			continue

		var to_planet = planet.global_position - global_position
		var distance = to_planet.length()
		if distance == 0 or distance < planet.radius:
			continue

		var g_dir = to_planet / distance
		var force = gravitational_constant * gravity_multiplier * planet.mass / pow(distance, 2)
		velocity += g_dir * force * delta
	# -------------------------------------------------
	"""
	# --- Optional deceleration ---
	if deceleration > 0.0:
		var s = velocity.length()
		s = max(s - deceleration * delta, 0.0)
		if s > 0.0:
			velocity = velocity.normalized() * s
	# -------------------------------------------------

	# --- Move bullet ---
	move_and_slide()

	# --- Rotate bullet to face its travel direction ---
	if velocity.length() > 0.01:
		rotation = velocity.angle() + deg_to_rad(-90)

	# --- Fade out based on speed ---
	if sprite and initial_speed > 0.0:
		sprite.modulate.a = clamp(velocity.length() / initial_speed, 0.0, 1.0)


func _on_hitbox_body_entered(body: Node) -> void:
	if not is_instance_valid(body):
		return

	# --- Friendly fire filtering ---
	if team == "Enemy" and body.is_in_group("Enemy"):
		return
	if team == "Fleet" and (body.is_in_group("Fleet") or body.is_in_group("player")):
		return
	if team == "player" and body.is_in_group("Fleet"):
		return
	# -------------------------------

	if body.has_method("take_damage"):
		body.take_damage(damage)
		_spawn_explosion()
	queue_free()
	
func _spawn_explosion() -> void:
	if explosion == null:
		return

	var explo: GPUParticles2D = explosion.instantiate() as GPUParticles2D
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.add_child(explo)
		explo.global_position = global_position
		explo.emitting = true
