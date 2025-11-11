# WeaponManager.gd
extends Node2D
class_name WeaponManager

signal weapon_equipped(weapon: WeaponBase)

@export var socket_path: NodePath = NodePath("WeaponSocket")
@export var starting_loadout: Array[WeaponData] = []

var _socket: Node2D
var _slots: Array[WeaponData] = []
var _equipped_index: int = -1
var _equipped_instance: WeaponBase = null

func _ready() -> void:
	_socket = get_node(socket_path) as Node2D
	_slots = starting_loadout.duplicate()
	if _slots.size() > 0:
		_equip_slot(0)

func _process(delta: float) -> void:
	if _equipped_instance == null:
		return

	if Input.is_action_pressed("fire"):
		_equipped_instance.request_fire()

	# weapon switching example (1–3)
	if Input.is_action_just_pressed("weapon_1"):
		_equip_slot(0)
	if Input.is_action_just_pressed("weapon_2"):
		_equip_slot(1)
	if Input.is_action_just_pressed("weapon_3"):
		_equip_slot(2)

func _equip_slot(index: int) -> void:
	if index < 0:
		return
	if index >= _slots.size():
		return

	var data: WeaponData = _slots[index]
	if data == null:
		return

	if _equipped_instance != null:
		_equipped_instance.queue_free()
		_equipped_instance = null

	var scene: PackedScene = data.weapon_scene
	if scene == null:
		push_error("WeaponManager: weapon_scene not set for " + data.display_name)
		return

	var instance: WeaponBase = scene.instantiate() as WeaponBase
	instance.data = data
	_socket.add_child(instance)

	_equipped_instance = instance
	_equipped_index = index

	emit_signal("weapon_equipped", instance)
