extends Node2D

# Star generation parameters
@export var star_colors: Array[Color] = [
	Color(1.0, 1.0, 1.0, 0.8),      # White
	Color(0.7, 0.9, 1.0, 0.8),      # Blue-white
	Color(1.0, 0.9, 0.7, 0.8),      # Yellow-white
	Color(1.0, 0.7, 0.7, 0.8)       # Red-white
]

# Parallax parameters
@export var trackObject: Node2D
var playerPath: NodePath = "../PlayerContainer/Player"
@export var num_layers: int = 3
@export var layer_1_speed: float = 0.0   # Farthest - stationary
@export var layer_2_speed: float = 0.05  # Middle - moves slightly
@export var layer_3_speed: float = 0.1   # Closest - moves slightly faster
@export var stars_per_layer: int = 150
@export var spawn_radius: float = 1000.0

var particle_layers: Array[CPUParticles2D] = []
var layer_speeds: Array[float] = []
var last_camera_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	trackObject = get_node(playerPath)
	generate_particle_layers()

func generate_particle_layers() -> void:
	for layer_index in range(num_layers):
		var particles: CPUParticles2D = CPUParticles2D.new()
		add_child(particles)
		if trackObject: particles.global_position = trackObject.global_position
		particle_layers.append(particles)
		
		# Calculate depth factor (0 = far, 1 = close)
		var depth_factor: float = 1.0 - (float(layer_index) / float(num_layers))
		
		# Store parallax speed for this layer using custom speeds
		var speed: float = 0.0
		if layer_index == 0:
			speed = layer_1_speed
		elif layer_index == 1:
			speed = layer_2_speed
		else:
			speed = layer_3_speed
		layer_speeds.append(speed)
		
		# Particle settings
		particles.amount = stars_per_layer
		particles.lifetime = randf_range(5.0, 20.0)  # Stars fade in/out
		particles.preprocess = 2.0  # Start with some stars already visible
		particles.explosiveness = 0.0  # Continuous spawning
		particles.randomness = 1.0
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = spawn_radius
		
		# Make particles stay in place relative to this node
		particles.local_coords = true
		
		# Disable all movement
		particles.gravity = Vector2.ZERO
		particles.initial_velocity_min = 0.0
		particles.initial_velocity_max = 0.0
		particles.angular_velocity_min = 0.0
		particles.angular_velocity_max = 0.0
		particles.linear_accel_min = 0.0
		particles.linear_accel_max = 0.0
		particles.radial_accel_min = 0.0
		particles.radial_accel_max = 0.0
		particles.tangential_accel_min = 0.0
		particles.tangential_accel_max = 0.0
		particles.damping_min = 0.0
		particles.damping_max = 0.0
		
		# Scale based on depth - keep it at 1.0 for pixel-perfect rendering
		particles.scale_amount_min = 1.0
		particles.scale_amount_max = 1.0
		
		# Twinkle effect using scale curve (subtle)
		var scale_curve: Curve = Curve.new()
		scale_curve.add_point(Vector2(0.0, 0.0))  # Start invisible
		scale_curve.add_point(Vector2(0.2, 1.0))  # Fade in
		scale_curve.add_point(Vector2(0.8, 1.0))  # Stay visible
		scale_curve.add_point(Vector2(1.0, 0.0))  # Fade out
		particles.scale_amount_curve = scale_curve
		
		# Color variation with twinkling
		var gradient: Gradient = Gradient.new()
		var color_index: int = randi() % star_colors.size()
		var base_color: Color = star_colors[color_index]
		gradient.add_point(0.0, Color(base_color.r, base_color.g, base_color.b, 0.0))
		gradient.add_point(0.3, base_color)
		gradient.add_point(0.7, base_color)
		gradient.add_point(1.0, Color(base_color.r, base_color.g, base_color.b, 0.0))
		particles.color_ramp = gradient
		
		# Hue variation for more color variety
		particles.hue_variation_min = -0.1
		particles.hue_variation_max = 0.1
		
		# Create star texture
		create_star_texture(particles)
		
		# Start emitting
		particles.emitting = true

func create_star_texture(particles: CPUParticles2D) -> void:
	# Create textures for different star types
	var star_type: int = randi() % 3
	var img: Image
	
	if star_type == 0:
		# 1x1 pixel
		img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.set_pixel(0, 0, Color(1.0, 1.0, 1.0, 1.0))
	elif star_type == 1:
		# 2x2 pixel
		img = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.set_pixel(0, 0, Color(1.0, 1.0, 1.0, 1.0))
		img.set_pixel(1, 0, Color(1.0, 1.0, 1.0, 1.0))
		img.set_pixel(0, 1, Color(1.0, 1.0, 1.0, 1.0))
		img.set_pixel(1, 1, Color(1.0, 1.0, 1.0, 1.0))
	else:
		# 3x3 cross
		img = Image.create(3, 3, false, Image.FORMAT_RGBA8)
		# Transparent corners
		img.set_pixel(0, 0, Color(0.0, 0.0, 0.0, 0.0))
		img.set_pixel(2, 0, Color(0.0, 0.0, 0.0, 0.0))
		img.set_pixel(0, 2, Color(0.0, 0.0, 0.0, 0.0))
		img.set_pixel(2, 2, Color(0.0, 0.0, 0.0, 0.0))
		# Cross shape
		img.set_pixel(1, 0, Color(1.0, 1.0, 1.0, 1.0))  # Top
		img.set_pixel(0, 1, Color(1.0, 1.0, 1.0, 1.0))  # Left
		img.set_pixel(1, 1, Color(1.0, 1.0, 1.0, 1.0))  # Center
		img.set_pixel(2, 1, Color(1.0, 1.0, 1.0, 1.0))  # Right
		img.set_pixel(1, 2, Color(1.0, 1.0, 1.0, 1.0))  # Bottom
	
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	texture.set_size_override(img.get_size())
	particles.texture = texture

func _process(delta: float) -> void:
	# Get camera position
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		var camera_position: Vector2 = camera.get_screen_center_position()
		var camera_delta: Vector2 = camera_position - last_camera_position
		
		# Apply parallax offset to each layer
		for i in range(particle_layers.size()):
			var layer: CPUParticles2D = particle_layers[i]
			var speed: float = layer_speeds[i]
			
			# Only move layer if speed is greater than 0
			if speed > 0.0:
				# Move layer opposite to camera movement, scaled by speed
				# Since we're a child of camera, we need to offset from center
				layer.position -= camera_delta * speed
		
		last_camera_position = camera_position
