extends CharacterBody2D

@export var speed: float = 300.0

func _physics_process(delta: float) -> void:
	# Get input direction
	var direction: Vector2 = Vector2.ZERO
	direction.x = Input.get_axis("left", "right")
	direction.y = Input.get_axis("up", "down")
	
	# Normalize diagonal movement
	if direction.length() > 0:
		direction = direction.normalized()
	
	# Apply movement
	velocity = direction * speed
	move_and_slide()
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			print("Player: E pressed!")
			var manager: InteractionManager = $"InteractionManager"
			if manager:
				print("Player: Found manager")
				var closest: Interactable = manager.get_closest_interactable()
				if closest:
					print("Player: Found interactable, triggering!")
					manager.trigger_interaction(closest)
				else:
					print("Player: No closest interactable")

# Weapon data
var melee_weapon: Dictionary = {}
var ranged_weapon: Dictionary = {}

# Combat stats
var damage_multiplier: float = 1.0
var max_shields: int = 100
var current_shields: int = 100
var max_speed: float = 300

# Fleet
var active_fleet: Array[Dictionary] = []

func _ready():
	active_fleet.resize(3)  # 3 fleet slots

func equip_melee_weapon(weapon_id: String):
	# Get weapon data from UI
	var ui: InteractionUI = get_node("/root/Main/InteractionUI")
	
	for weapon in ui.player_ui.available_weapons:
		if weapon.get("id", "") == weapon_id:
			melee_weapon = weapon.duplicate()
			print("Equipped melee: ", melee_weapon.get("name"))
			return

func equip_ranged_weapon(weapon_id: String):
	# Get weapon data from UI
	var ui: InteractionUI = get_node("/root/Main/InteractionUI")
	
	for weapon in ui.player_ui.available_weapons:
		if weapon.get("id", "") == weapon_id:
			ranged_weapon = weapon.duplicate()
			print("Equipped ranged: ", ranged_weapon.get("name"))
			return

func get_melee_damage() -> int:
	if melee_weapon.is_empty():
		return 5  # Base damage if no weapon
	return int(melee_weapon.get("damage", 5) * damage_multiplier)

func get_ranged_damage() -> int:
	if ranged_weapon.is_empty():
		return 10  # Base damage if no weapon
	return int(ranged_weapon.get("damage", 10) * damage_multiplier)

func update_fleet_slot(slot_index: int, ship_id: String):
	# Get ship data from UI
	var ui: InteractionUI = get_node("/root/Main/InteractionUI")
	
	if slot_index < active_fleet.size():
		for ship in ui.player_ui.player_fleet_slots:
			if not ship.is_empty() and ship.get("id", "") == ship_id:
				active_fleet[slot_index] = ship.duplicate()
				print("Fleet slot ", slot_index, ": ", ship.get("name"))
				return

func use_melee_attack(target: Node2D):
	if melee_weapon.is_empty():
		print("No melee weapon equipped!")
		return
	
	var damage: int = get_melee_damage()
	var weapon_range: float = melee_weapon.get("range", 50.0)
	
	var distance: float = global_position.distance_to(target.global_position)
	if distance <= weapon_range:
		if target.has_method("take_damage"):
			target.take_damage(damage)
			print("Melee hit for ", damage, " damage!")
	else:
		print("Target out of range!")

func use_ranged_attack(target: Node2D):
	if ranged_weapon.is_empty():
		print("No ranged weapon equipped!")
		return
	
	var damage: int = get_ranged_damage()
	
	# Spawn projectile
	spawn_projectile(target.global_position, damage)
	print("Fired ", ranged_weapon.get("name"), "!")

func spawn_projectile(target_pos: Vector2, damage: int):
	return
	# Your projectile spawning code here
	#var projectile = preload("res://Scenes/projectile.tscn").instantiate()
	#get_parent().add_child(projectile)
	#projectile.global_position = global_position
	#projectile.target = target_pos
	#projectile.damage = damage
