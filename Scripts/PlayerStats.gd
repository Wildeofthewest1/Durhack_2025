extends Resource
class_name PlayerStats

# --- CORE ATTRIBUTES ---
@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export var max_fuel: float = 100.0
@export var current_fuel: float = 100.0
@export var fuel_recharge_rate: float = 15.0

@export var move_speed: float = 400.0

# --- COMBAT ATTRIBUTES ---
@export var base_damage: float = 10.0
@export var fire_rate: float = 3.0   # shots per second
@export var crit_chance: float = 0.05

# --- UPGRADE MULTIPLIERS ---
@export var dmg_mult: float = 1.0
@export var fire_rate_mult: float = 1.0
@export var health_mult: float = 1.0
@export var fuel_mult: float = 1.0

signal stat_changed(stat_name: String, new_value: float)

# --- FUNCTIONS ---
func apply_damage(amount: float) -> void:
	current_health -= amount
	if current_health < 0.0:
		current_health = 0.0
	emit_signal("stat_changed", "current_health", current_health)

func heal(amount: float) -> void:
	current_health += amount
	if current_health > get_max_health():
		current_health = get_max_health()
	emit_signal("stat_changed", "current_health", current_health)

func use_fuel(amount: float) -> bool:
	if current_fuel >= amount:
		current_fuel -= amount
		emit_signal("stat_changed", "current_fuel", current_fuel)
		return true
	return false

func recharge_fuel(delta: float) -> void:
	current_fuel += fuel_recharge_rate * delta
	if current_fuel > get_max_fuel():
		current_fuel = get_max_fuel()
	emit_signal("stat_changed", "current_fuel", current_fuel)

# --- Getters with multipliers applied ---
func get_damage() -> float:
	return base_damage * dmg_mult

func get_fire_rate() -> float:
	return fire_rate * fire_rate_mult

func get_max_health() -> float:
	return max_health * health_mult

func get_max_fuel() -> float:
	return max_fuel * fuel_mult
