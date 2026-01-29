extends Node

## Example usage of TagManager throughout the game
## This demonstrates common patterns for quests, dialogue, keys, upgrades, etc.

func _ready() -> void:
	# The TagManager is an autoload, so it's always available
	# Make sure to add it to Project Settings > Autoload
	pass

# ============================================================================
# QUEST EXAMPLES
# ============================================================================

func start_main_quest_chapter_1() -> void:
	"""When the player starts chapter 1 of the main quest"""
	TagManager.add_tag(GameTags.Quest.MAIN_CHAPTER_1_START, {
		"source": "quest_system",
		"location": "starting_station"
	})
	print("Chapter 1 quest started!")

func complete_main_quest_chapter_1() -> void:
	"""When the player completes chapter 1"""
	TagManager.remove_tag(GameTags.Quest.MAIN_CHAPTER_1_START)
	TagManager.add_tag(GameTags.Quest.MAIN_CHAPTER_1_COMPLETE)
	
	# Award player with key to next area
	TagManager.add_tag(GameTags.Key.STATION_BETA_CLEARANCE)
	print("Chapter 1 complete! Beta Station access granted.")

func check_quest_prerequisites() -> bool:
	"""Check if player has completed required quests"""
	# Need to complete prologue and tutorial before starting chapter 1
	return TagManager.has_all_tags([
		GameTags.Quest.MAIN_PROLOGUE_COMPLETE,
		GameTags.Quest.TUTORIAL_MOVEMENT,
		GameTags.Quest.TUTORIAL_COMBAT
	])

# ============================================================================
# KEY / DOOR EXAMPLES
# ============================================================================

func try_open_door(door_name: String) -> bool:
	"""Check if player has the key to open a door"""
	match door_name:
		"alpha_level_2":
			if TagManager.has_tag(GameTags.Key.STATION_ALPHA_LEVEL_2):
				print("Door opened!")
				return true
			else:
				print("Access denied: Level 2 clearance required")
				return false
		
		"mars_base":
			if TagManager.has_tag(GameTags.Key.MARS_BASE_ACCESS):
				# First time visiting?
				if not TagManager.has_tag(GameTags.Discovery.PLANET_MARS_VISITED):
					TagManager.add_tag(GameTags.Discovery.PLANET_MARS_VISITED)
					print("Achievement: First visit to Mars!")
				return true
			else:
				print("Mars base access denied")
				return false
	
	return false

# ============================================================================
# DIALOGUE EXAMPLES
# ============================================================================

func get_elder_dialogue() -> String:
	"""Return appropriate dialogue based on player's relationship with Elder"""
	
	# First meeting
	if not TagManager.has_tag(GameTags.Dialogue.ELDER_MET):
		TagManager.add_tag(GameTags.Dialogue.ELDER_MET)
		return "Greetings, traveler. I am the Elder of this station."
	
	# High trust dialogue
	if TagManager.has_tag(GameTags.Dialogue.ELDER_TRUST_HIGH):
		if TagManager.has_tag(GameTags.Story.CHOICE_SAVED_COLONISTS):
			return "Your heroism has not gone unnoticed. The colonists speak highly of you."
		else:
			return "It's good to see you again, friend."
	
	# Low trust dialogue
	elif TagManager.has_tag(GameTags.Dialogue.ELDER_TRUST_LOW):
		return "What do you want? Make it quick."
	
	# Neutral dialogue
	else:
		return "What brings you here?"

func handle_dialogue_choice(choice: String) -> void:
	"""Handle player's dialogue choice and update tags"""
	match choice:
		"ask_about_invasion":
			if not TagManager.has_tag(GameTags.Dialogue.KNOWS_INVASION):
				TagManager.add_tag(GameTags.Dialogue.KNOWS_INVASION)
				# This unlocks new dialogue options with other NPCs
				print("You learned about the coming invasion!")
		
		"be_rude_to_elder":
			TagManager.remove_tag(GameTags.Dialogue.ELDER_TRUST_HIGH)
			TagManager.add_tag(GameTags.Dialogue.ELDER_TRUST_LOW)
			print("The Elder will remember that...")

# ============================================================================
# UPGRADE EXAMPLES
# ============================================================================

func try_purchase_upgrade(upgrade_name: String) -> bool:
	"""Check if player can purchase an upgrade"""
	match upgrade_name:
		"twin_gun_mk2":
			# Check prerequisites
			if not TagManager.has_tag(GameTags.Upgrade.WEAPON_TWIN_GUN_MK2):
				# Could add credit check here
				TagManager.add_tag(GameTags.Upgrade.WEAPON_TWIN_GUN_MK2)
				print("Twin Gun MK2 installed!")
				return true
		
		"engine_mk3":
			# MK3 requires MK2 first
			if TagManager.has_tag(GameTags.Upgrade.SHIP_ENGINE_MK2):
				TagManager.add_tag(GameTags.Upgrade.SHIP_ENGINE_MK3)
				print("Engine upgraded to MK3!")
				return true
			else:
				print("You need Engine MK2 before upgrading to MK3")
				return false
	
	return false

# ============================================================================
# COMBAT / COUNTER EXAMPLES
# ============================================================================

func on_enemy_killed(enemy_type: String) -> void:
	"""Increment kill counter when enemy is defeated"""
	var tag: String = ""
	
	match enemy_type:
		"alien_scout":
			tag = GameTags.Combat.KILLS_ALIEN_SCOUT
		"alien_fighter":
			tag = GameTags.Combat.KILLS_ALIEN_FIGHTER
		"pirate":
			tag = GameTags.Combat.KILLS_PIRATE
	
	if tag != "":
		var new_count: int = TagManager.increment_tag(tag)
		print("Killed ", enemy_type, " (Total: ", new_count, ")")
		
		# Check for achievements
		if new_count == 1:
			TagManager.add_tag(GameTags.State.KILLED_FIRST_ENEMY)
		elif new_count >= 100:
			if not TagManager.has_tag(GameTags.State.ACE_PILOT):
				TagManager.add_tag(GameTags.State.ACE_PILOT)
				print("Achievement Unlocked: Ace Pilot!")

# ============================================================================
# DISCOVERY / EXPLORATION EXAMPLES
# ============================================================================

func on_location_discovered(location: String) -> void:
	"""Handle discovery of new locations"""
	match location:
		"mars":
			TagManager.add_tag(GameTags.Discovery.PLANET_MARS_VISITED)
			# Count total planets discovered
			TagManager.increment_tag("discovery:stats:planets_visited")
			
		"derelict_ship":
			TagManager.add_tag(GameTags.Discovery.DERELICT_CARGO_FOUND)
			# Give player a key item
			TagManager.add_tag(GameTags.Key.ANCIENT_ARTIFACT_KEY)
			print("Found ancient artifact on derelict ship!")

# ============================================================================
# WILDCARD / PATTERN EXAMPLES
# ============================================================================

func check_any_weapon_upgrades() -> bool:
	"""Check if player has ANY weapon upgrades"""
	return TagManager.has_any_matching("upgrade:weapon:*")

func count_discovered_planets() -> int:
	"""Count how many planets have been visited"""
	return TagManager.count_matching("discovery:planet:*:visited")

func reset_all_quests() -> void:
	"""Remove all active quests (for testing)"""
	var removed: int = TagManager.remove_matching("quest:*:*:active")
	print("Removed ", removed, " active quests")

# ============================================================================
# TAG GROUP EXAMPLES
# ============================================================================

func setup_endgame_requirements() -> void:
	"""Define what's needed to trigger the endgame"""
	TagManager.define_group("endgame_ready", [
		GameTags.Quest.MAIN_CHAPTER_1_COMPLETE,
		GameTags.Upgrade.SHIP_SHIELD_ADVANCED,
		GameTags.Upgrade.WEAPON_TWIN_GUN_MK3,
		GameTags.State.ACE_PILOT
	])

func check_endgame_progress() -> void:
	"""Show player their progress toward endgame"""
	var progress: Dictionary = TagManager.get_group_progress("endgame_ready")
	print("Endgame Progress: ", progress["completed"], "/", progress["total"])
	print("Missing: ", progress["missing"])

# ============================================================================
# TEMPORARY TAG EXAMPLES
# ============================================================================

func apply_speed_buff(duration: float) -> void:
	"""Apply a temporary speed buff to the player"""
	TagManager.add_tag_with_expiry("buff:speed:active", duration)
	print("Speed buff applied for ", duration, " seconds")
	# Ship controller can check has_tag("buff:speed:active") to increase speed

func check_has_active_buff(buff_type: String) -> bool:
	"""Check if player has an active buff"""
	return TagManager.has_tag("buff:" + buff_type + ":active")

# ============================================================================
# DEPENDENCY EXAMPLES
# ============================================================================

func setup_upgrade_dependencies() -> void:
	"""Define which upgrades require others"""
	# MK3 engine requires MK2 first
	TagManager.define_dependency(
		GameTags.Upgrade.SHIP_ENGINE_MK3,
		[GameTags.Upgrade.SHIP_ENGINE_MK2]
	)
	
	# Advanced shield requires basic shield
	TagManager.define_dependency(
		GameTags.Upgrade.SHIP_SHIELD_ADVANCED,
		[GameTags.Upgrade.SHIP_SHIELD_BASIC]
	)

# ============================================================================
# SAVE / LOAD EXAMPLES
# ============================================================================

func save_game() -> void:
	"""Save all tag data to file"""
	var save_data: Dictionary = {
		"tags": TagManager.get_save_data(),
		"player_position": Vector2.ZERO, # Your other save data
		# ... other game data
	}
	
	var file: FileAccess = FileAccess.open("user://savegame.dat", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Game saved!")

func load_game() -> void:
	"""Load tag data from file"""
	var file: FileAccess = FileAccess.open("user://savegame.dat", FileAccess.READ)
	if file:
		var json_string: String = file.get_as_text()
		file.close()
		
		var json: JSON = JSON.new()
		var parse_result: int = json.parse(json_string)
		
		if parse_result == OK:
			var save_data: Dictionary = json.data
			if save_data.has("tags"):
				TagManager.load_save_data(save_data["tags"])
			print("Game loaded!")

# ============================================================================
# DEBUG EXAMPLES
# ============================================================================

func debug_give_all_keys() -> void:
	"""Debug function: Give player all keys"""
	TagManager.add_tags_batch([
		GameTags.Key.STATION_ALPHA_LEVEL_1,
		GameTags.Key.STATION_ALPHA_LEVEL_2,
		GameTags.Key.STATION_BETA_CLEARANCE,
		GameTags.Key.MARS_BASE_ACCESS,
		GameTags.Key.MILITARY_CLEARANCE_HIGH
	])
	print("Debug: All keys granted")

func debug_complete_all_tutorials() -> void:
	"""Debug function: Complete all tutorials"""
	TagManager.add_tags_batch([
		GameTags.Quest.TUTORIAL_MOVEMENT,
		GameTags.Quest.TUTORIAL_COMBAT,
		GameTags.Quest.TUTORIAL_DOCKING
	])
	TagManager.add_tag(GameTags.State.TUTORIAL_COMPLETE)
	print("Debug: All tutorials completed")

func debug_print_player_state() -> void:
	"""Debug function: Print all player tags"""
	TagManager.print_all_tags()
	TagManager.print_tag_stats()
