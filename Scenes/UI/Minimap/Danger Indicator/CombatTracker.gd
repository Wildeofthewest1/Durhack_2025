extends Node

## Singleton that tracks global combat state

## How long after last combat action before exiting combat
@export var combat_timeout: float = 10.0

## Current combat state
var is_in_combat: bool = false

## Time since last combat action
var time_since_last_action: float = 0.0

## Signals
signal combat_started()
signal combat_ended()
signal combat_state_changed(in_combat: bool)

func _ready() -> void:
	# Reset state on ready
	is_in_combat = false
	time_since_last_action = 0.0

func _process(delta: float) -> void:
	if is_in_combat:
		time_since_last_action += delta
		
		# Check if we should exit combat
		if time_since_last_action >= combat_timeout:
			_exit_combat()

## Report a combat action (damage dealt, damage taken, weapon fired at enemy, etc.)
func report_combat_action() -> void:
	time_since_last_action = 0.0
	
	if not is_in_combat:
		_enter_combat()

## Enter combat state
func _enter_combat() -> void:
	is_in_combat = true
	time_since_last_action = 0.0
	combat_started.emit()
	combat_state_changed.emit(true)

## Exit combat state
func _exit_combat() -> void:
	is_in_combat = false
	time_since_last_action = 0.0
	combat_ended.emit()
	combat_state_changed.emit(false)

## Force enter combat (useful for scripted events)
func force_enter_combat() -> void:
	_enter_combat()

## Force exit combat
func force_exit_combat() -> void:
	_exit_combat()

## Get time remaining until combat ends
func get_time_until_combat_ends() -> float:
	if not is_in_combat:
		return 0.0
	return max(0.0, combat_timeout - time_since_last_action)

## Get combat progress (0.0 = just started, 1.0 = about to end)
func get_combat_decay_progress() -> float:
	if not is_in_combat:
		return 0.0
	return clamp(time_since_last_action / combat_timeout, 0.0, 1.0)
