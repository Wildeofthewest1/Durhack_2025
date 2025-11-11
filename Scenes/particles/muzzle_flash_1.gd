extends Node2D

@export var random_strength: float = 1
@onready var Particle_1: GPUParticles2D = $"Horizontal flash"
@onready var Particle_2: GPUParticles2D = $"VF1"
@onready var Particle_3: GPUParticles2D = $"VF2"
@onready var Particle_4: GPUParticles2D = $"Horizontal flash_2"

func _ready() -> void:
	#rotation = get_parent().global_rotation
	#Particle_1.global_rotation += randf_range(-random_strength/2,random_strength/2)
	Particle_2.global_rotation += randf_range(-random_strength/2,random_strength/2)
	Particle_3.global_rotation += randf_range(-random_strength/2,random_strength/2)
	Particle_1.emitting = true
	Particle_2.emitting = true
	Particle_3.emitting = true
	Particle_4.emitting = true
	
