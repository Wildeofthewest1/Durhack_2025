# main.gd or game.gd
extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var interaction_ui: InteractionUI = $InteractionUI
@onready var weapon_bridge: WeaponUIBridge = $Player/WeaponUIBridge


	# Player can now see these in the UI and equip them!
func _ready():
	# Connect weapon system signals
	interaction_ui.player_ui.weapon_equipped.connect(_on_weapon_equipped)
	interaction_ui.player_ui.fleet_ship_equipped.connect(_on_fleet_equipped)
	interaction_ui.player_ui.shop_item_purchased.connect(_on_item_purchased)
	   
	# Load your weapon data resources
	var pistol_data: WeaponData = load("res://Data/pistol.tres")
	var rifle_data: WeaponData = load("res://Data/twin_gun.tres")
	
	# Add them to the UI
	weapon_bridge.add_weapon_to_ui(pistol_data, "pistol")
	weapon_bridge.add_weapon_to_ui(rifle_data, "rifle")
	
	# Give player starting weapons
	_setup_starting_gear()

func _on_weapon_equipped(slot_index: int, weapon_id: String):
	# Called when player equips a weapon in the UI
	print("Weapon equipped in slot ", slot_index, ": ", weapon_id)
	
	# Update player's active weapon
	match slot_index:
		0:  # Melee slot
			player.equip_melee_weapon(weapon_id)
		1:  # Ranged slot
			player.equip_ranged_weapon(weapon_id)

func _on_fleet_equipped(slot_index: int, ship_id: String):
	# Called when player assigns ship to fleet slot
	print("Fleet slot ", slot_index, " assigned: ", ship_id)
	player.update_fleet_slot(slot_index, ship_id)

func _on_item_purchased(item_id: String, item_type: String):
	# Called when player buys something
	print("Purchased: ", item_id, " (", item_type, ")")
	
	# Apply special effects for certain items
	if item_type == "upgrade":
		_apply_upgrade(item_id)

func _setup_starting_gear():
	# Give player starting weapons
	interaction_ui.player_ui.add_weapon({
		"id": "basic_laser",
		"name": "Basic Laser Pistol",
		"type": "ranged",
		"damage": 20,
		"fire_rate": 1.0
	})
	
	interaction_ui.player_ui.add_weapon({
		"id": "combat_knife",
		"name": "Combat Knife",
		"type": "melee",
		"damage": 15,
		"range": 50
	})

func _apply_upgrade(upgrade_id: String):
	match upgrade_id:
		"shield_boost":
			player.max_shields += 50
		"engine_upgrade":
			player.max_speed += 100
		"damage_boost":
			player.damage_multiplier += 0.25
