# trading_station.gd
extends Interactable

func _ready():
	super._ready()
	
	interaction_name = "Weapons Depot"
	#interaction_sprite = preload("res://Assets/weapons_depot.png")
	has_dialogue = true
	
	set_dialogue_data({
		"start": {
			"text": "Welcome to the Weapons Depot! Check the shop in the Player tab.",
			"speaker": "Arms Dealer",
			"options": [
				{"text": "Show me your weapons", "next": "weapons"},
				{"text": "Goodbye", "next": "end"}
			]
		},
		"weapons": {
			"text": "Press Tab and check the Shop section!",
			"speaker": "Arms Dealer",
			"options": [
				{"text": "Thanks!", "next": "end"}
			]
		}
	})

func on_interact(player: Node):
	super.on_interact(player)
	
	# Setup shop
	var ui: InteractionUI = get_node("/root/Main/InteractionUI")
	ui.player_ui.clear_shop()
	
	# Add weapons for sale
	ui.player_ui.add_shop_weapon({
		"id": "plasma_rifle",
		"name": "Plasma Rifle",
		"type": "ranged",
		"damage": 50,
		"fire_rate": 0.5,
		"description": "High-energy plasma weapon",
		"price": 500
	})
	
	ui.player_ui.add_shop_weapon({
		"id": "energy_blade",
		"name": "Energy Blade",
		"type": "melee",
		"damage": 60,
		"range": 75,
		"description": "Superheated cutting edge",
		"price": 350
	})
	
	# Add ships
	ui.player_ui.add_shop_ship({
		"id": "interceptor",
		"name": "Interceptor",
		"type": "Fighter",
		"stats": {"health": 150, "damage": 40, "speed": 500},
		"description": "Fast attack fighter",
		"price": 1500
	})
	
	# Add upgrades
	ui.player_ui.add_shop_upgrade({
		"id": "damage_boost",
		"name": "Weapon Amplifier",
		"description": "+25% weapon damage",
		"price": 750,
		"upgrade_type": "player"
	})
