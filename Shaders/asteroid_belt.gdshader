shader_type canvas_item;

// Asteroid data
uniform int asteroid_count: hint_range(1, 256) = 0;
uniform float inner_radius: hint_range(0.0, 1000.0) = 100.0;
uniform float outer_radius: hint_range(0.0, 1000.0) = 200.0;
uniform float base_transparency: hint_range(0.0, 1.0) = 0.3;

// Arrays passed from script (max 64 asteroids for performance)
uniform vec2 asteroid_positions[64];
uniform vec4 asteroid_sizes[64];
uniform vec4 asteroid_colors[64];

// Pseudo-random function
float pseudo_rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec4 final_color = vec4(0.0);
	
	// Check each asteroid
	for (int i = 0; i < 64; i++) {
		if (i >= asteroid_count) {
			break;
		}
		
		vec2 asteroid_pos = asteroid_positions[i];
		float asteroid_size = asteroid_sizes[i].x;
		float asteroid_rot = asteroid_sizes[i].y;
		vec4 asteroid_color = asteroid_colors[i];
		
		// Distance from this fragment to asteroid center
		vec2 delta = uv - asteroid_pos;
		float dist = length(delta);
		
		// If close enough to asteroid, draw it
		if (dist < asteroid_size * 2.0) {
			// Create a rough rock shape using sin waves
			float angle = atan(delta.y, delta.x);
			float wobble = sin(angle * 6.0 + asteroid_rot) * 0.3 + 0.7;
			float rock_radius = asteroid_size * wobble;
			
			// Soft edge falloff
			float edge = 1.0 - smoothstep(rock_radius * 0.8, rock_radius, dist);
			
			// Add some detail with pseudo-random noise
			float detail = pseudo_rand(asteroid_pos + vec2(angle, asteroid_rot));
			
			vec4 rock_color = asteroid_color;
			rock_color.rgb *= (0.7 + detail * 0.5);
			rock_color.a = base_transparency * edge;
			
			// Blend with existing color
			final_color = mix(final_color, rock_color, rock_color.a);
		}
	}
	
	COLOR = final_color;
}
