extends Node2D
class_name WeaponManager

@export var fire_action: StringName = "fire"
@export var weapon_scene: PackedScene
@export var socket_path: NodePath = NodePath("WeaponSocket")

var _socket: Node2D = null
var _equipped_weapon: WeaponBase = null

func _ready() -> void:
	_socket = get_node(socket_path) as Node2D

	if weapon_scene != null:
		var w: Node2D = weapon_scene.instantiate() as Node2D
		_socket.add_child(w)

		if w is WeaponBase:
			_equipped_weapon = w as WeaponBase
			# make sure weapon knows who is holding it
			_equipped_weapon.owner = get_parent()

func _process(delta: float) -> void:
	# let the equipped weapon run its own process
	if _equipped_weapon != null:
		_equipped_weapon._process(delta)

	# handle shooting input
	if Input.is_action_pressed(fire_action):
		if _equipped_weapon != null:
			# We assume this weapon implements request_fire()
			if _equipped_weapon.has_method("request_fire"):
				_equipped_weapon.call("request_fire")
