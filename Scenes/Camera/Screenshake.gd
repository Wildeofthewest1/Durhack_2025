extends Node

var _camera: GameCamera = null


func register_camera(cam: GameCamera) -> void:
	_camera = cam


func shake(amount: float) -> void:
	if _camera != null:
		_camera.add_trauma(amount)
