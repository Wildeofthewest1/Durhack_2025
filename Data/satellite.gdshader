shader_type canvas_item;
render_mode blend_mix;
// Colors
uniform vec3 base_color: source_color = vec3(0.8, 0.85, 0.9);
uniform vec3 highlight_color: source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shadow_color: source_color = vec3(0.3, 0.35, 0.4);
// Metallic parameters
uniform float metallic_strength: hint_range(0.0, 1.0) = 0.9;
uniform float highlight_sharpness: hint_range(0.1, 8.0) = 3.0;
// Animation
uniform float time_scale: hint_range(0.0, 2.0) = 0.5;
void fragment() {
	// UV-based procedural highlight pattern (pixel-art friendly)
	vec2 uv = UV * 4.0;
	
	// Create a moving gradient effect for reflection
	float x_pattern = sin(uv.x * 3.14159 + TIME * time_scale) * 0.5 + 0.5;
	float y_pattern = cos(uv.y * 3.14159 + TIME * time_scale * 0.7) * 0.5 + 0.5;
	
	// Combine patterns for metallic reflection effect
	float metallic_factor = pow(x_pattern * y_pattern, highlight_sharpness);
	
	// Distance from center for rim-like effect
	vec2 center_dist = UV - vec2(0.5);
	float distance_from_center = length(center_dist) * 2.0;
	float edge_glow = 1.0 - clamp(distance_from_center, 0.0, 1.0);
	edge_glow = pow(edge_glow, 2.0) * 0.6;
	
	// Blend colors
	vec3 base = mix(shadow_color, base_color, 0.5 + sin(TIME * time_scale * 0.3) * 0.3);
	vec3 with_metallic = mix(base, highlight_color, metallic_factor * metallic_strength);
	vec3 final_color = with_metallic + edge_glow * highlight_color;
	
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = vec4(final_color, tex_color.a);
}
