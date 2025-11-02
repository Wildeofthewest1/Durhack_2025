# weapon_ui_bridge.gd
# Bridges between WeaponManager (uses WeaponData Resources) and PlayerUI (uses Dictionaries)
extends Node
class_name WeaponUIBridge

@export var weapon_manager: WeaponManager
@export var interaction_ui: InteractionUI

# Cache of WeaponData resources by ID
var weapon_data_cache: Dictionary = {}  # id -> WeaponData

func _ready():
	# Use call_deferred to ensure everything is initialized
	call_deferred("_initialize")

func _initialize():
	if not weapon_manager:
		weapon_manager = get_parent().get_node_or_null("WeaponManager")
	
	if not interaction_ui:
		interaction_ui = get_node_or_null("/root/Main/InteractionUI")
		if not interaction_ui:
			# Try alternative paths
			interaction_ui = get_tree().get_first_node_in_group("interaction_ui")
	
	if not weapon_manager:
		push_error("WeaponUIBridge: weapon_manager not found! Check export or path.")
		return
	
	if not interaction_ui:
		push_error("WeaponUIBridge: interaction_ui not found! Make sure InteractionUI exists.")
		return
	
	# Make sure player_ui exists
	if not interaction_ui.player_ui:
		push_error("WeaponUIBridge: interaction_ui.player_ui is null!")
		return
	
	# Connect UI signals
	interaction_ui.player_ui.weapon_equipped.connect(_on_ui_weapon_equipped)
	
	# Connect WeaponManager signals
	weapon_manager.slot_changed.connect(_on_weapon_manager_slot_changed)
	weapon_manager.inventory_changed.connect(_on_weapon_manager_inventory_changed)
	
	print("WeaponUIBridge: Successfully connected!")
	print("  WeaponManager: ", weapon_manager)
	print("  InteractionUI: ", interaction_ui)
	print("  PlayerUI: ", interaction_ui.player_ui)

# ========================================
# FROM UI TO WEAPONMANAGER
# ========================================

func _on_ui_weapon_equipped(slot_index: int, weapon_id: String):
	"""Called when player equips a weapon in the UI"""
	print("WeaponUIBridge: UI equipped weapon ", weapon_id, " in slot ", slot_index)
	
	# Get the WeaponData from cache
	if not weapon_data_cache.has(weapon_id):
		push_error("WeaponUIBridge: No WeaponData found for ID: ", weapon_id)
		return
	
	var weapon_data: WeaponData = weapon_data_cache[weapon_id]
	
	# Set it in the weapon manager
	weapon_manager.set_slot(slot_index, weapon_data)
	
	# Auto-equip if it's the first weapon or matching the UI slot
	if weapon_manager.get_equipped_index() == -1 or weapon_manager.get_equipped_index() == slot_index:
		weapon_manager._equip_slot(slot_index)

# ========================================
# FROM WEAPONMANAGER TO UI
# ========================================

func _on_weapon_manager_slot_changed(index: int):
	"""Called when WeaponManager changes equipped slot"""
	print("WeaponUIBridge: WeaponManager equipped slot ", index)
	# Could update UI to show which weapon is active
	# This is optional - depends on your UI design

func _on_weapon_manager_inventory_changed():
	"""Called when WeaponManager inventory changes"""
	print("WeaponUIBridge: WeaponManager inventory changed")
	# Could sync back to UI if needed

# ========================================
# WEAPON MANAGEMENT
# ========================================

func add_weapon_to_ui(weapon_data: WeaponData, weapon_id: String = ""):
	"""Add a weapon to the UI's available weapons list"""
	
	if not interaction_ui or not interaction_ui.player_ui:
		push_error("WeaponUIBridge: Cannot add weapon - UI not initialized!")
		return
	
	# Generate ID if not provided
	if weapon_id.is_empty():
		weapon_id = weapon_data.display_name.to_lower().replace(" ", "_")
	
	# Cache the WeaponData
	weapon_data_cache[weapon_id] = weapon_data
	
	# Create dictionary for UI
	var weapon_dict: Dictionary = {
		"id": weapon_id,
		"name": weapon_data.display_name,
		"type": "ranged" if weapon_data.slot_hint == 1 else "melee",  # Adjust based on your needs
		"damage": 0,  # WeaponData doesn't store damage, add if needed
		"icon": weapon_data.icon,
		"fire_rate": 1.0 / weapon_data.fire_cooldown if weapon_data.fire_cooldown > 0 else 0,
		"magazine": weapon_data.max_magazine,
		"reserve": weapon_data.max_reserve
	}
	
	# Add to UI
	interaction_ui.player_ui.add_weapon(weapon_dict)
	
	print("WeaponUIBridge: Added weapon to UI: ", weapon_data.display_name)

func add_weapon_to_shop(weapon_data: WeaponData, price: int, weapon_id: String = ""):
	"""Add a weapon to the shop"""
	
	if not interaction_ui or not interaction_ui.player_ui:
		push_error("WeaponUIBridge: Cannot add to shop - UI not initialized!")
		return
	
	if weapon_id.is_empty():
		weapon_id = weapon_data.display_name.to_lower().replace(" ", "_")
	
	# Cache it
	weapon_data_cache[weapon_id] = weapon_data
	
	# Create shop item dictionary
	var shop_item: Dictionary = {
		"id": weapon_id,
		"name": weapon_data.display_name,
		"type": "ranged" if weapon_data.slot_hint == 1 else "melee",
		"damage": 0,  # Add if you extend WeaponData
		"icon": weapon_data.icon,
		"description": "Magazine: %d | Reserve: %d" % [weapon_data.max_magazine, weapon_data.max_reserve],
		"price": price,
		"fire_rate": 1.0 / weapon_data.fire_cooldown if weapon_data.fire_cooldown > 0 else 0,
		"magazine": weapon_data.max_magazine,
		"reserve": weapon_data.max_reserve
	}
	
	# Add to shop in UI
	interaction_ui.player_ui.add_shop_weapon(shop_item)
	
	print("WeaponUIBridge: Added weapon to shop: ", weapon_data.display_name, " for ", price, " credits")

func give_starting_weapons():
	"""Give player their starting weapons - call this in _ready or game start"""
	
	# Example: Load your weapon data resources
	var pistol_data: WeaponData = load("res://weapons/data/pistol_data.tres")
	var rifle_data: WeaponData = load("res://weapons/data/rifle_data.tres")
	
	if pistol_data:
		add_weapon_to_ui(pistol_data, "pistol")
	
	if rifle_data:
		add_weapon_to_ui(rifle_data, "rifle")

# ========================================
# HELPER FUNCTIONS
# ========================================

func get_weapon_data(weapon_id: String) -> WeaponData:
	"""Get cached WeaponData by ID"""
	return weapon_data_cache.get(weapon_id, null)

func equip_weapon_in_manager(slot_index: int):
	"""Directly equip a slot in the weapon manager"""
	if weapon_manager:
		weapon_manager._equip_slot(slot_index)

func get_current_weapon_name() -> String:
	"""Get currently equipped weapon's name"""
	if weapon_manager and weapon_manager.get_equipped_instance():
		return weapon_manager.get_equipped_instance().get_display_name()
	return "None"

func get_current_ammo() -> String:
	"""Get current weapon's ammo count"""
	if weapon_manager and weapon_manager.get_equipped_instance():
		return weapon_manager.get_equipped_instance().get_ammo_text()
	return "0 / 0"
