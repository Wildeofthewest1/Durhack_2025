extends Sprite2D

func _ready() -> void:
	if material and material is ShaderMaterial:
		material = material.duplicate()
		var mat: ShaderMaterial = material as ShaderMaterial
		mat.set_shader_parameter("object_scale", scale)
