# WeaponBase.gd
extends Node2D
class_name WeaponBase

@export var data: WeaponData

var _cooldown: float = 0.0
var _current_mag: int = 0
var _is_reloading: bool = false
var _aim_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	if data == null:
		push_error("WeaponBase: data is not assigned!")
		return
	_current_mag = data.max_magazine

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func try_fire(dir: Vector2) -> void:
	if data == null:
		return
	if _is_reloading:
		return
	if _cooldown > 0.0:
		return
	if _current_mag <= 0:
		_start_reload()
		return

	_aim_dir = dir
	_current_mag -= 1
	_cooldown = data.fire_cooldown

	_fire_projectile(_aim_dir)

func _start_reload() -> void:
	if _is_reloading:
		return
	_is_reloading = true
	var reload_time: float = data.reload_time
	await get_tree().create_timer(reload_time).timeout
	_current_mag = data.max_magazine
	_is_reloading = false

func _fire_projectile(dir: Vector2) -> void:
	# overridden in child weapons
	pass
