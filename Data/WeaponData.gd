# Godot 4.x
@tool
class_name WeaponData
extends Resource


@export var display_name: String = "Pistol"
@export var icon: Texture2D
@export var weapon_scene: PackedScene
@export var max_magazine: int = 12
@export var max_reserve: int = 120
@export var fire_cooldown: float = 0.2
@export var reload_time: float = 1.2
@export var slot_hint: int = -1 # if >= 0, suggests a default slot index
