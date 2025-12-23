extends Node

const LOOT := {
	"Small": {
		"Scrap": [
			{ "weight": 1.0, "amount": Vector2i(1, 3) },
			{ "weight": 0.3, "amount": Vector2i(2, 3) },
			{ "weight": 0.1, "amount": Vector2i(5, 5) }
		]
	},
	"Medium": {
		"Scrap": [
			{ "weight": 1.0, "amount": Vector2i(5, 10) },
			{ "weight": 0.3, "amount": Vector2i(2, 3) },
			{ "weight": 0.1, "amount": Vector2i(5, 5) }
		]
	},
	"Large": {
		"Scrap": [
			{ "weight": 1.0, "amount": Vector2i(10, 15) },
			{ "weight": 0.3, "amount": Vector2i(2, 3) },
			{ "weight": 0.1, "amount": Vector2i(5, 5) }
		],
		"RareItem": [
			{ "weight": 1.0, "amount": Vector2i(1, 1) }
		]
	}
}

static func roll_scrap_amount(tier: String) -> int:
	if not LOOT.has(tier):
		push_warning("Loot: Unknown tier '%s'" % tier)
		return 0

	var table = LOOT[tier].get("Scrap", [])
	if table.is_empty():
		return 0

	var total_weight := 0.0
	for entry in table:
		total_weight += entry.weight

	var roll := randf() * total_weight
	var acc := 0.0

	for entry in table:
		acc += entry.weight
		if roll <= acc:
			return randi_range(entry.amount.x, entry.amount.y)

	return 0
