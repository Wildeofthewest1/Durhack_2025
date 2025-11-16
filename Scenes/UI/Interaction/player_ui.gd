extends Control
class_name PlayerUI

signal weapon_equipped(slot_index: int, weapon_id: String)
signal fleet_ship_equipped(slot_index: int, ship_id: String)
signal shop_item_purchased(item_id: String, item_type: String)
signal upgrade_purchased(upgrade_id: String)

# Player stats
var player_name: String = "Commander"
var player_level: int = 1
var player_credits: int = 10000

# Weapon system - 2 slots (melee + ranged)
var equipped_weapons: Array[Dictionary] = [{}, {}]  # [melee_slot, ranged_slot]
var available_weapons: Array[Dictionary] = []  # All weapons player owns

# Fleet system - Player's fleet slots
var player_fleet_slots: Array[Dictionary] = []  # Ships player can deploy
var max_fleet_size: int = 3

# NPC/Planet fleet (when interacting)
var npc_fleet_slots: Array[Dictionary] = []  # Shown when talking to someone

# Shop system (context-dependent)
var shop_weapons: Array[Dictionary] = []
var shop_ships: Array[Dictionary] = []
var shop_upgrades: Array[Dictionary] = []

# Upgrades (player and planet-based)
var player_upgrades: Array[Dictionary] = []
var planet_upgrades: Array[Dictionary] = []

# Inventory (simplified - mainly for resources/consumables)
var inventory_data: Array[Dictionary] = []

# UI Sections
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var main_vbox: VBoxContainer = $ScrollContainer/MainVBox

var stats_section: VBoxContainer
var weapons_section: VBoxContainer
var fleet_section: VBoxContainer
var npc_fleet_section: VBoxContainer  # Only shows when interacting
var shop_section: VBoxContainer
var upgrades_section: VBoxContainer
var inventory_section: VBoxContainer

func _ready() -> void:
	# Initialize weapon slots
	equipped_weapons.resize(2)
	player_fleet_slots.resize(max_fleet_size)
	
	_build_ui()
	_refresh_all()

func _build_ui() -> void:
	if not main_vbox:
		return
	
	# Clear existing
	for child in main_vbox.get_children():
		child.queue_free()
	
	# Build sections
	stats_section = _create_section("⚔️ PLAYER STATUS")
	main_vbox.add_child(stats_section)
	
	weapons_section = _create_section("🔫 WEAPONS (2 SLOTS)")
	main_vbox.add_child(weapons_section)
	
	fleet_section = _create_section("🚀 YOUR FLEET")
	main_vbox.add_child(fleet_section)
	
	npc_fleet_section = _create_section("🛸 THEIR FLEET")
	npc_fleet_section.visible = false  # Hidden by default
	main_vbox.add_child(npc_fleet_section)
	
	shop_section = _create_section("🛒 SHOP")
	main_vbox.add_child(shop_section)
	
	upgrades_section = _create_section("⬆️ UPGRADES")
	main_vbox.add_child(upgrades_section)
	
	inventory_section = _create_section("📦 INVENTORY")
	main_vbox.add_child(inventory_section)

func _create_section(title: String) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	section.add_child(title_label)
	
	var separator: HSeparator = HSeparator.new()
	section.add_child(separator)
	
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(content)
	
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 10
	section.add_child(spacer)
	
	return section

func _refresh_all() -> void:
	_refresh_stats()
	_refresh_weapons()
	_refresh_fleet()
	_refresh_npc_fleet()
	_refresh_shop()
	_refresh_upgrades()
	_refresh_inventory()

# === STATS ===
func _refresh_stats() -> void:
	var content: VBoxContainer = stats_section.get_node("Content")
	if not content:
		return
	
	for child in content.get_children():
		child.queue_free()
	
	var name_label: Label = Label.new()
	name_label.text = "👤 " + player_name
	content.add_child(name_label)
	
	var level_label: Label = Label.new()
	level_label.text = "⭐ Level: " + str(player_level)
	content.add_child(level_label)
	
	var credits_label: Label = Label.new()
	credits_label.text = "💰 Credits: " + str(player_credits)
	content.add_child(credits_label)

func set_player_stats(name: String, level: int, credits: int) -> void:
	player_name = name
	player_level = level
	player_credits = credits
	_refresh_stats()

# === WEAPONS ===
func _refresh_weapons() -> void:
	var content: VBoxContainer = weapons_section.get_node("Content")
	if not content:
		return
	
	for child in content.get_children():
		child.queue_free()
	
	# Show 2 equipment slots
	var slots_label: Label = Label.new()
	slots_label.text = "Equipment Slots:"
	slots_label.add_theme_font_size_override("font_size", 12)
	content.add_child(slots_label)
	
	# Melee slot
	var melee_slot: HBoxContainer = _create_weapon_slot(0, "⚔️ MELEE", equipped_weapons[0])
	content.add_child(melee_slot)
	
	# Ranged slot
	var ranged_slot: HBoxContainer = _create_weapon_slot(1, "🔫 RANGED", equipped_weapons[1])
	content.add_child(ranged_slot)
	
	# Available weapons list
	if not available_weapons.is_empty():
		var available_label: Label = Label.new()
		available_label.text = "\nAvailable Weapons:"
		available_label.add_theme_font_size_override("font_size", 12)
		content.add_child(available_label)
		
		for weapon in available_weapons:
			var weapon_panel: PanelContainer = _create_weapon_item(weapon)
			content.add_child(weapon_panel)
	else:
		var empty_label: Label = Label.new()
		empty_label.text = "\nNo weapons owned. Buy from shop!"
		empty_label.add_theme_font_size_override("font_size", 10)
		content.add_child(empty_label)

func _create_weapon_slot(slot_index: int, slot_name: String, equipped_weapon: Dictionary) -> HBoxContainer:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.custom_minimum_size.y = 50
	
	var slot_label: Label = Label.new()
	slot_label.text = slot_name + ": "
	slot_label.custom_minimum_size.x = 100
	hbox.add_child(slot_label)
	
	if equipped_weapon.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "[Empty Slot]"
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		hbox.add_child(empty_label)
	else:
		var weapon_name: Label = Label.new()
		weapon_name.text = equipped_weapon.get("name", "Unknown")
		weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(weapon_name)
		
		var unequip_btn: Button = Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.pressed.connect(_on_unequip_weapon.bind(slot_index))
		hbox.add_child(unequip_btn)
	
	return hbox

func _create_weapon_item(weapon: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var hbox: HBoxContainer = HBoxContainer.new()
	panel.add_child(hbox)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var name_label: Label = Label.new()
	name_label.text = weapon.get("name", "Unknown")
	vbox.add_child(name_label)
	
	var type_label: Label = Label.new()
	var weapon_type: String = weapon.get("type", "melee")
	type_label.text = "Type: " + weapon_type.capitalize() + " | DMG: " + str(weapon.get("damage", 0))
	type_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(type_label)
	
	# Equip button
	var slot_index: int = 0 if weapon_type == "melee" else 1
	var equip_btn: Button = Button.new()
	equip_btn.text = "Equip"
	equip_btn.pressed.connect(_on_equip_weapon.bind(slot_index, weapon.get("id", "")))
	hbox.add_child(equip_btn)
	
	return panel

func _on_equip_weapon(slot_index: int, weapon_id: String) -> void:
	# Find weapon
	for weapon in available_weapons:
		if weapon.get("id", "") == weapon_id:
			equipped_weapons[slot_index] = weapon.duplicate()
			weapon_equipped.emit(slot_index, weapon_id)
			_refresh_weapons()
			return

func _on_unequip_weapon(slot_index: int) -> void:
	equipped_weapons[slot_index] = {}
	_refresh_weapons()

func add_weapon(weapon: Dictionary) -> void:
	available_weapons.append(weapon)
	_refresh_weapons()

# === FLEET ===
func _refresh_fleet() -> void:
	var content: VBoxContainer = fleet_section.get_node("Content")
	if not content:
		return
	
	for child in content.get_children():
		child.queue_free()
	
	var slots_label: Label = Label.new()
	slots_label.text = "Fleet Deployment Slots (" + str(max_fleet_size) + " max):"
	slots_label.add_theme_font_size_override("font_size", 12)
	content.add_child(slots_label)
	
	# Show fleet slots
	for i in range(max_fleet_size):
		var slot_panel: PanelContainer = _create_fleet_slot(i, player_fleet_slots[i] if i < player_fleet_slots.size() else {})
		content.add_child(slot_panel)

func _create_fleet_slot(slot_index: int, ship: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var hbox: HBoxContainer = HBoxContainer.new()
	panel.add_child(hbox)
	
	var slot_label: Label = Label.new()
	slot_label.text = "Slot " + str(slot_index + 1) + ": "
	slot_label.custom_minimum_size.x = 80
	hbox.add_child(slot_label)
	
	if ship.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "[Empty - No ship assigned]"
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		hbox.add_child(empty_label)
	else:
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(vbox)
		
		var name_label: Label = Label.new()
		name_label.text = ship.get("name", "Unknown")
		vbox.add_child(name_label)
		
		var stats: Dictionary = ship.get("stats", {})
		var stats_label: Label = Label.new()
		stats_label.text = "HP:%d | DMG:%d | SPD:%d" % [stats.get("health", 0), stats.get("damage", 0), stats.get("speed", 0)]
		stats_label.add_theme_font_size_override("font_size", 9)
		vbox.add_child(stats_label)
		
		var remove_btn: Button = Button.new()
		remove_btn.text = "Remove"
		remove_btn.pressed.connect(_on_remove_fleet_ship.bind(slot_index))
		hbox.add_child(remove_btn)
	
	return panel

func _on_remove_fleet_ship(slot_index: int) -> void:
	if slot_index < player_fleet_slots.size():
		player_fleet_slots[slot_index] = {}
		_refresh_fleet()

func add_fleet_ship_to_slot(ship: Dictionary, slot_index: int) -> void:
	if slot_index >= 0 and slot_index < max_fleet_size:
		while player_fleet_slots.size() <= slot_index:
			player_fleet_slots.append({})
		player_fleet_slots[slot_index] = ship.duplicate()
		fleet_ship_equipped.emit(slot_index, ship.get("id", ""))
		_refresh_fleet()

# === NPC FLEET (shown during interactions) ===
func _refresh_npc_fleet() -> void:
	var content: VBoxContainer = npc_fleet_section.get_node("Content")
	if not content:
		return
	
	for child in content.get_children():
		child.queue_free()
	
	if npc_fleet_slots.is_empty():
		npc_fleet_section.visible = false
		return
	
	npc_fleet_section.visible = true
	
	for i in range(npc_fleet_slots.size()):
		var ship: Dictionary = npc_fleet_slots[i]
		if not ship.is_empty():
			var ship_panel: PanelContainer = _create_npc_fleet_display(ship)
			content.add_child(ship_panel)

func _create_npc_fleet_display(ship: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var vbox: VBoxContainer = VBoxContainer.new()
	panel.add_child(vbox)
	
	var name_label: Label = Label.new()
	name_label.text = ship.get("name", "Unknown Ship")
	vbox.add_child(name_label)
	
	var type_label: Label = Label.new()
	type_label.text = ship.get("type", "Unknown Type")
	type_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(type_label)
	
	var stats: Dictionary = ship.get("stats", {})
	var stats_label: Label = Label.new()
	stats_label.text = "HP:%d | DMG:%d | SPD:%d" % [stats.get("health", 0), stats.get("damage", 0), stats.get("speed", 0)]
	stats_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(stats_label)
	
	return panel

func set_npc_fleet(fleet: Array[Dictionary]) -> void:
	npc_fleet_slots = fleet.duplicate(true)
	_refresh_npc_fleet()

func clear_npc_fleet() -> void:
	npc_fleet_slots.clear()
	_refresh_npc_fleet()

# === SHOP ===
func _refresh_shop() -> void:
	var content: VBoxContainer = shop_section.get_node("Content")
	if not content:
		return
	
	for child in content.get_children():
		child.queue_free()
	
	var total_items: int = shop_weapons.size() + shop_ships.size() + shop_upgrades.size()
	
	if total_items == 0:
		var empty_label: Label = Label.new()
		empty_label.text = "No items for sale (interact with stations to shop)"
		content.add_child(empty_label)
		return
	
	# Weapons for sale
	if not shop_weapons.is_empty():
		var weapons_header: Label = Label.new()
		weapons_header.text = "🔫 WEAPONS:"
		weapons_header.add_theme_font_size_override("font_size", 12)
		content.add_child(weapons_header)
		
		for weapon in shop_weapons:
			var item_panel: PanelContainer = _create_shop_item(weapon, "weapon")
			content.add_child(item_panel)
	
	# Ships for sale
	if not shop_ships.is_empty():
		var ships_header: Label = Label.new()
		ships_header.text = "\n🚀 SHIPS:"
		ships_header.add_theme_font_size_override("font_size", 12)
		content.add_child(ships_header)
		
		for ship in shop_ships:
			var item_panel: PanelContainer = _create_shop_item(ship, "ship")
			content.add_child(item_panel)
	
	# Upgrades for sale
	if not shop_upgrades.is_empty():
		var upgrades_header: Label = Label.new()
		upgrades_header.text = "\n⬆️ UPGRADES:"
		upgrades_header.add_theme_font_size_override("font_size", 12)
		content.add_child(upgrades_header)
		
		for upgrade in shop_upgrades:
			var item_panel: PanelContainer = _create_shop_item(upgrade, "upgrade")
			content.add_child(item_panel)

func _create_shop_item(item: Dictionary, item_type: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var hbox: HBoxContainer = HBoxContainer.new()
	panel.add_child(hbox)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var name_label: Label = Label.new()
	name_label.text = item.get("name", "Unknown")
	vbox.add_child(name_label)
	
	var desc_label: Label = Label.new()
	desc_label.text = item.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(desc_label)
	
	var price: int = item.get("price", 0)
	var can_afford: bool = player_credits >= price
	
	var buy_btn: Button = Button.new()
	buy_btn.text = str(price) + " CR"
	buy_btn.disabled = not can_afford
	buy_btn.pressed.connect(_on_buy_shop_item.bind(item.get("id", ""), item_type))
	hbox.add_child(buy_btn)
	
	return panel

func _on_buy_shop_item(item_id: String, item_type: String) -> void:
	var item_array: Array[Dictionary] = []
	match item_type:
		"weapon": item_array = shop_weapons
		"ship": item_array = shop_ships
		"upgrade": item_array = shop_upgrades
	
	for item in item_array:
		if item.get("id", "") == item_id:
			var price: int = item.get("price", 0)
			if player_credits >= price:
				player_credits -= price
				
				# Add to player's inventory based on type
				match item_type:
					"weapon":
						add_weapon(item.duplicate())
					"ship":
						# Find empty slot and add
						for i in range(max_fleet_size):
							if i >= player_fleet_slots.size() or player_fleet_slots[i].is_empty():
								add_fleet_ship_to_slot(item.duplicate(), i)
								break
					"upgrade":
						player_upgrades.append(item.duplicate())
						_refresh_upgrades()
				
				shop_item_purchased.emit(item_id, item_type)
				_refresh_stats()
				_refresh_shop()
			return

func add_shop_weapon(weapon: Dictionary) -> void:
	shop_weapons.append(weapon)
	_refresh_shop()

func add_shop_ship(ship: Dictionary) -> void:
	shop_ships.append(ship)
	_refresh_shop()

func add_shop_upgrade(upgrade: Dictionary) -> void:
	shop_upgrades.append(upgrade)
	_refresh_shop()

func clear_shop() -> void:
	shop_weapons.clear()
	shop_ships.clear()
	shop_upgrades.clear()
	_refresh_shop()

# === UPGRADES ===
func _refresh_upgrades() -> void:
	var content: VBoxContainer = upgrades_section.get_node("Content")
	if not content:
		return
	
	for child in content.get_children():
		child.queue_free()
	
	if player_upgrades.is_empty() and planet_upgrades.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No upgrades installed"
		content.add_child(empty_label)
		return
	
	if not player_upgrades.is_empty():
		var player_header: Label = Label.new()
		player_header.text = "🧑 Player Upgrades:"
		player_header.add_theme_font_size_override("font_size", 12)
		content.add_child(player_header)
		
		for upgrade in player_upgrades:
			var upgrade_label: Label = Label.new()
			upgrade_label.text = "• " + upgrade.get("name", "Unknown")
			content.add_child(upgrade_label)
	
	if not planet_upgrades.is_empty():
		var planet_header: Label = Label.new()
		planet_header.text = "\n🌍 Planet Upgrades:"
		planet_header.add_theme_font_size_override("font_size", 12)
		content.add_child(planet_header)
		
		for upgrade in planet_upgrades:
			var upgrade_label: Label = Label.new()
			upgrade_label.text = "• " + upgrade.get("name", "Unknown")
			content.add_child(upgrade_label)

# === INVENTORY ===
func _refresh_inventory() -> void:
	var content: VBoxContainer = inventory_section.get_node("Content")
	if not content:
		return
	
	for child in content.get_children():
		child.queue_free()
	
	if inventory_data.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "Empty inventory"
		content.add_child(empty_label)
		return
	
	for item in inventory_data:
		var item_label: Label = Label.new()
		item_label.text = "• " + item.get("name", "Unknown") + " x" + str(item.get("quantity", 1))
		content.add_child(item_label)

func add_inventory_item(item: Dictionary) -> void:
	inventory_data.append(item)
	_refresh_inventory()
