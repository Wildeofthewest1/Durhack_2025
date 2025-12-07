shader_type canvas_item;
render_mode blend_mix;

// Asteroid appearance
uniform float asteroid_density: hint_range(0.0, 1.0) = 0.3;
uniform float asteroid_scale: hint_range(0.0, 5.0) = 0.221;

// Colors
uniform vec3 asteroid_color1: source_color = vec3(0.8375, 0.0, 0.0);
uniform vec3 asteroid_color2: source_color = vec3(0.4510, 0.0745, 0.0745);
uniform vec3 asteroid_color3: source_color = vec3(0.8196, 0.3216, 0.3216);

// Animation - multiple layers with different speeds (vectors)
uniform vec2 scroll_speed_1 = vec2(0.003, 0.01);
uniform vec2 scroll_speed_2 = vec2(0.001, -0.002);
uniform vec2 scroll_speed_3 = vec2(-0.003, -0.003);

// Ring shape
uniform float enable_ring: hint_range(0.0, 1.0) = 1.0;
uniform float ring_inner_radius: hint_range(0.0, 1.0) = 0.3;
uniform float ring_outer_radius: hint_range(0.0, 1.0) = 0.6;
uniform float ring_edge_softness: hint_range(0.0, 0.2) = 0.05;

// Texture detail
uniform float texture_scale: hint_range(0.0, 1.0) = 0.926;

// Hash function
float hash(vec2 p) {
	float h = dot(p, vec2(127.1, 311.7));
	return fract(sin(h) * 43758.5453123);
}

// Noise for texture
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	float n00 = hash(i);
	float n10 = hash(i + vec2(1.0, 0.0));
	float n01 = hash(i + vec2(0.0, 1.0));
	float n11 = hash(i + vec2(1.0, 1.0));
	
	float nx0 = mix(n00, n10, u.x);
	float nx1 = mix(n01, n11, u.x);
	return mix(nx0, nx1, u.y);
}

vec4 render_layer(vec2 uv, float density_mult) {
	vec3 final_color = vec3(0.0);
	float final_alpha = 0.0;
	
	// Grid
	float cell_size = 0.2 * asteroid_scale;
	vec2 grid_uv = uv / cell_size;
	vec2 grid_cell = floor(grid_uv);
	
	// Check all surrounding cells
	for (int gx = -2; gx <= 2; gx++) {
		for (int gy = -2; gy <= 2; gy++) {
			vec2 check_cell = grid_cell + vec2(float(gx), float(gy));
			float cell_hash = hash(check_cell);
			
			if (cell_hash < asteroid_density * density_mult) {
				// Asteroid position in this cell
				vec2 seed = check_cell + vec2(2.1, 3.7);
				vec2 ast_local = vec2(
					hash(seed),
					hash(seed + vec2(5.0, 0.0))
				);
				
				// Asteroid world position
				vec2 ast_world = (check_cell + ast_local) * cell_size;
				
				// Current pixel world position
				vec2 pixel_world = uv;
				
				// Distance between them
				vec2 diff = pixel_world - ast_world;
				float dist = length(diff);
				
				// Vary size based on hash
				float size_hash = hash(check_cell + vec2(7.7, 8.8));
				float radius = 0.04 * asteroid_scale;
				if (size_hash < 0.4) {
					radius *= 0.6;
				} else if (size_hash < 0.8) {
					radius *= 1.2;
				}
				
				// Add bumpy surface using noise
				float angle = atan(diff.y, diff.x);
				float bumps = noise(vec2(angle * 3.0 / 6.28, hash(check_cell) * 10.0)) * 0.3;
				float bumpy_radius = radius * (1.0 + bumps);
				
				// Sharp but bumpy blob
				float blob = step(dist, bumpy_radius);
				
				if (blob > 0.0) {
					// Flat color
					float color_hash = hash(check_cell + vec2(11.1, 22.2));
					vec3 color = asteroid_color1;
					if (color_hash < 0.33) {
						color = asteroid_color2;
					} else if (color_hash < 0.66) {
						color = asteroid_color3;
					}
					
					// Add texture variation with multiple noise layers
					float tex1 = noise(diff * 30.0 + check_cell * 10.0);
					float tex2 = noise(diff * 60.0 + check_cell * 20.0);
					float tex = mix(step(0.5, tex1), step(0.5, tex2), 0.5);
					color = mix(color, color * 0.7, tex * texture_scale);
					
					final_color = mix(final_color, color, blob * (1.0 - final_alpha));
					final_alpha = max(final_alpha, blob);
				}
			}
		}
	}
	
	return vec4(final_color, final_alpha);
}

void fragment() {
	vec2 uv = UV;
	
	// Layer 1
	vec2 uv1 = uv + TIME * scroll_speed_1;
	vec4 layer1 = render_layer(uv1, 1.0);
	
	// Layer 2 (less dense)
	vec2 uv2 = uv + TIME * scroll_speed_2;
	vec4 layer2 = render_layer(uv2, 0.7);
	
	// Layer 3 (even less dense)
	vec2 uv3 = uv + TIME * scroll_speed_3;
	vec4 layer3 = render_layer(uv3, 0.5);
	
	// Composite layers
	vec3 final_color = vec3(0.0);
	float final_alpha = 0.0;
	
	// Blend layers
	final_color = mix(final_color, layer1.rgb, layer1.a * (1.0 - final_alpha));
	final_alpha = max(final_alpha, layer1.a);
	
	final_color = mix(final_color, layer2.rgb, layer2.a * (1.0 - final_alpha));
	final_alpha = max(final_alpha, layer2.a);
	
	final_color = mix(final_color, layer3.rgb, layer3.a * (1.0 - final_alpha));
	final_alpha = max(final_alpha, layer3.a);
	
	// Apply ring mask with smooth feathered edges
	if (enable_ring > 0.5) {
		float dist_from_center = length(uv - 0.5);
		
		// Smooth inner edge
		float inner_edge = smoothstep(ring_inner_radius + ring_edge_softness, ring_inner_radius - ring_edge_softness, dist_from_center);
		
		// Smooth outer edge
		float outer_edge = smoothstep(ring_outer_radius - ring_edge_softness, ring_outer_radius + ring_edge_softness, dist_from_center);
		
		// Combine both edges for ring mask
		float ring_mask = inner_edge * outer_edge;
		final_alpha *= ring_mask;
	}
	
	COLOR = vec4(final_color, final_alpha);
}