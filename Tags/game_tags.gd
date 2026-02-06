class_name GameTags

## Centralized tag definitions for the entire game
## Using namespaced convention: category:subcategory:name:state
## This prevents typos and provides IDE autocomplete

# ============================================================================
# QUEST TAGS
# ============================================================================

class Quest:
	# Add your quest tags here
	# Example: const MAIN_CHAPTER_1_START = "quest:main:chapter_1:start"
	pass

# ============================================================================
# KEY / ACCESS TAGS
# ============================================================================

class Key:
	# Add your key/access tags here
	# Example: const STATION_ALPHA_KEY = "key:station:alpha:main"
	pass

# ============================================================================
# DIALOGUE STATE TAGS
# ============================================================================

class Dialogue:
	# Add your dialogue state tags here
	# Example: const NPC_ELDER_MET = "dialogue:npc:elder:met"
	const NPC_ARCHIVIST_MET = "dialogue:npc:archivist:met"
	
	const NPC_DRONEWORKS_MET = "dialogue:npc:droneworks:met"
	const NPC_DRONEWORKS_TALKED = "dialogue:npc:droneworks:talked"
	const NPC_DRONEWORKS_LISTENED = "dialogue:npc:droneworks:listened"
	const NPC_DRONEWORKS_QUEST_ACCEPTED = "dialogue:npc:droneworks:questaccepted"
	pass

# ============================================================================
# UPGRADE TAGS
# ============================================================================

class Upgrade:
	# Add your upgrade tags here
	# Example: const SHIP_ENGINE_MK2 = "upgrade:ship:engine:mk2"
	pass

# ============================================================================
# DISCOVERY TAGS
# ============================================================================

class Discovery:
	# Add your discovery tags here
	# Example: const PLANET_MARS_VISITED = "discovery:planet:mars:visited"
	pass

# ============================================================================
# GAME STATE TAGS
# ============================================================================

class State:
	# Add your game state tags here
	# Example: const TUTORIAL_COMPLETE = "state:tutorial:complete"
	pass

# ============================================================================
# ACHIEVEMENT TAGS
# ============================================================================

class Achievement:
	# Add your achievement tags here
	# Example: const FIRST_FLIGHT = "achievement:basic:first_flight"
	pass

# ============================================================================
# FACTION TAGS
# ============================================================================

class Faction:
	# Add your faction tags here
	# Example: const ALLIANCE_FRIENDLY = "faction:alliance:friendly"
	pass

# ============================================================================
# RELATIONSHIP TAGS (for NPC opinion of player)
# ============================================================================

class Relationship:
	# Add your relationship tags here
	# Example: const NPC_ELDER_LEVEL_1 = "relationship:npc:elder:level_1"
	pass

# ============================================================================
# COMBAT TAGS
# ============================================================================

class Combat:
	# Add your combat tags here (use TagManager.increment_tag for counters)
	# Example: const KILLS_ALIEN_SCOUT = "combat:kills:alien_scout"
	pass

# ============================================================================
# ECONOMY TAGS
# ============================================================================

class Economy:
	# Add your economy tags here
	# Example: const WEALTH_RICH = "economy:wealth:rich"
	pass

# ============================================================================
# STORY BRANCH TAGS (player choices)
# ============================================================================

class Story:
	# Add your story/choice tags here
	# Example: const CHOICE_SAVED_COLONISTS = "story:choice:saved_colonists"
	pass

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Get all tags from a specific class
static func get_category_tags(category: String) -> Array:
	"""Get all constant tag names from a category.
	Example: GameTags.get_category_tags('Quest')"""
	var result: Array = []
	var script: Script = GameTags
	
	# This is a helper for documentation purposes
	# In practice, you'll use the constants directly
	push_warning("get_category_tags is for documentation only")
	return result

## Validate a tag follows naming convention
static func is_valid_tag_format(tag: String) -> bool:
	"""Check if a tag follows the namespace:category:name:state format."""
	var parts: Array = tag.split(":")
	return parts.size() >= 2 # At minimum category:name
