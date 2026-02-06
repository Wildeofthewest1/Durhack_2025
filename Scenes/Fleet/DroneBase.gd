extends CharacterBody2D
class_name DroneBase

## Base class for all drones
## Handles common functionality: stats, health, resource integration, slot positioning
## Extend this class to create specific drone behaviors

signal health_changed(current: int, max: int)
signal died()

## What this drone follows
@export var follow_body: Node2D = null

## The drone resource that defines this drone's type and stats
@export var drone_resource: DroneResource = null

## Assigned slot index (prevents stacking)
var slot_index: int = -1

## Current runtime stats (affected by player's drone stat modifiers)
var current_health: int = 200
var max_health: int = 200

## These are the actual values used in behavior, modified by player stats
var effective_damage: float = 10.0
var effective_speed: float = 300.0
var effective_fire_rate: float = 1.0
var effective_accuracy: float = 1.0
var effective_defence: float = 0.0

## Visual
var _sprite: Sprite2D = null
var _default_color: Color = Color.WHITE

## Stat system reference (PlayerVariables autoload)
var _player_stats: Node = null

## Fire rate tracking
var _fire_cooldown: float = 0.0

func _ready() -> void:
	# Reference PlayerVariables autoload directly
	_player_stats = PlayerVariables
	if _player_stats == null:
		push_warning("[DroneBase] PlayerVariables autoload not found! Drone stats will not be modified by player bonuses.")
	
	# Apply drone resource if assigned
	if drone_resource != null:
		_apply_drone_resource()
	
	# Get sprite reference
	if has_node("Sprite2D"):
		_sprite = $Sprite2D
		_default_color = _sprite.modulate
	
	# Assign slot to prevent stacking
	if follow_body != null:
		slot_index = DroneManager.assign_slot(self, follow_body)
	
	# Register with DroneManager
	if drone_resource != null:
		DroneManager.register_active_drone(self, drone_resource, slot_index)
	
	# Update stats from player modifiers
	_update_effective_stats()
	
	# Attach weapons
	_attach_weapons()

func _exit_tree() -> void:
	# Release slot
	if follow_body != null and slot_index != -1:
		DroneManager.release_slot(self, follow_body)
	
	# Unregister from DroneManager
	DroneManager.unregister_active_drone(self)

func _process(delta: float) -> void:
	# Update fire cooldown
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

## Apply stats from the assigned DroneResource
func _apply_drone_resource() -> void:
	if drone_resource == null:
		return
	
	max_health = drone_resource.max_health
	current_health = max_health
	
	# Apply visual properties
	if _sprite != null:
		if drone_resource.sprite_texture != null:
			_sprite.texture = drone_resource.sprite_texture
		_sprite.modulate = drone_resource.base_color
		_default_color = drone_resource.base_color
		_sprite.scale = Vector2.ONE * drone_resource.scale
	
	print("[Drone] Applied resource: %s (HP: %d)" % [drone_resource.drone_display_name, max_health])

## Update effective stats from player's drone stat modifiers
func _update_effective_stats() -> void:
	if drone_resource == null:
		return
	
	# Get base stats from resource
	var base_damage: float = drone_resource.base_damage
	var base_speed: float = drone_resource.base_speed
	var base_fire_rate: float = drone_resource.base_fire_rate
	var base_accuracy: float = drone_resource.base_accuracy
	var base_defence: float = drone_resource.base_defence
	
	# Apply player's drone stat modifiers if available
	if _player_stats != null and _player_stats.has_method("get_value"):
		# Drone damage multiplier
		var dmg_mult: float = _player_stats.get_value(&"drone_damage")
		if dmg_mult > 0.0:
			effective_damage = base_damage * dmg_mult
		else:
			effective_damage = base_damage
		
		# Drone speed multiplier
		var speed_mult: float = _player_stats.get_value(&"drone_speed")
		if speed_mult > 0.0:
			effective_speed = base_speed * speed_mult
		else:
			effective_speed = base_speed
		
		# Drone fire rate multiplier
		var fire_mult: float = _player_stats.get_value(&"drone_fire_rate")
		if fire_mult > 0.0:
			effective_fire_rate = base_fire_rate * fire_mult
		else:
			effective_fire_rate = base_fire_rate
		
		# Drone accuracy multiplier
		var acc_mult: float = _player_stats.get_value(&"drone_accuracy")
		if acc_mult > 0.0:
			effective_accuracy = base_accuracy * acc_mult
		else:
			effective_accuracy = base_accuracy
		
		# Drone defence (additive)
		var def_bonus: float = _player_stats.get_value(&"drone_defence")
		effective_defence = base_defence + def_bonus
	else:
		# No player stats available, use base values
		effective_damage = base_damage
		effective_speed = base_speed
		effective_fire_rate = base_fire_rate
		effective_accuracy = base_accuracy
		effective_defence = base_defence

## Can this drone fire? (respects fire rate)
func can_fire() -> bool:
	return _fire_cooldown <= 0.0

## Start fire cooldown
func start_fire_cooldown() -> void:
	if effective_fire_rate > 0.0:
		_fire_cooldown = 1.0 / effective_fire_rate

## Take damage
func take_damage(amount: float) -> void:
	# Apply defence reduction
	var actual_damage: float = max(amount - effective_defence, 0.0)
	current_health -= int(actual_damage)
	
	print("[Drone] %s took %.1f damage (%.1f after defence), HP: %d/%d" % [
		name, amount, actual_damage, current_health, max_health
	])
	
	health_changed.emit(current_health, max_health)
	
	if _sprite != null:
		_flash_red()
	
	if current_health <= 0:
		die()

## Flash sprite red when taking damage
func _flash_red() -> void:
	if _sprite == null:
		return
	
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate", Color(1, 0, 0), 0.05)
	tween.tween_property(_sprite, "modulate", _default_color, 0.1)

## Handle death
func die() -> void:
	var drone_name: String = drone_resource.drone_display_name if drone_resource != null else name
	print("[Drone] %s died" % drone_name)
	
	died.emit()
	
	# TODO: Spawn death effects, explosions, etc.
	
	queue_free()

## Attach weapons based on drone resource
func _attach_weapons() -> void:
	if drone_resource == null or drone_resource.weapon_scene == null:
		return
	
	if not has_node("WeaponSlots"):
		return
	
	var weapon_slots: Array = $WeaponSlots.get_children()
	if weapon_slots.is_empty():
		return
	
	# Create Weapons node if it doesn't exist
	if not has_node("Weapons"):
		var weapons_node: Node2D = Node2D.new()
		weapons_node.name = "Weapons"
		add_child(weapons_node)
	
	# Instantiate weapon at first slot
	var weapon: Node2D = drone_resource.weapon_scene.instantiate()
	weapon.position = weapon_slots[0].position
	$Weapons.add_child(weapon)

## Calculate slot position offset
## Distributes drones evenly around the follow body
func get_slot_offset() -> Vector2:
	if slot_index < 0:
		return Vector2.ZERO
	
	# Calculate angle for this slot
	var total_slots: int = 32  # Match max_slots in DroneManager
	var angle: float = (TAU / float(total_slots)) * float(slot_index)
	
	# Base radius (can be overridden in subclasses)
	var radius: float = 128.0
	
	return Vector2(cos(angle), sin(angle)) * radius

## Get info for UI display
func get_drone_info() -> Dictionary:
	return {
		"name": drone_resource.drone_display_name if drone_resource != null else name,
		"health": current_health,
		"max_health": max_health,
		"type": drone_resource.drone_id if drone_resource != null else "unknown",
		"slot": slot_index,
		"damage": effective_damage,
		"speed": effective_speed,
		"fire_rate": effective_fire_rate,
		"accuracy": effective_accuracy,
		"defence": effective_defence
	}

## Override in subclasses for specific behavior
func _physics_process(_delta: float) -> void:
	pass
