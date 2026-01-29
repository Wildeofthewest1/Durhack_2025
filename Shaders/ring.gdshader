shader_type canvas_item;

uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.3;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.5;
uniform float smoothness : hint_range(0.0, 0.1) = 0.01;
uniform float arc_angle : hint_range(0.0, 360.0) = 360.0;
uniform float arc_offset : hint_range(0.0, 360.0) = 0.0;
uniform float arc_smoothness : hint_range(0.0, 45.0) = 2.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);

void fragment() {
	// Get UV coordinates centered at 0.5, 0.5
	vec2 uv = UV - vec2(0.5);
	
	// Calculate distance from center
	float dist = length(uv) * 2.0;
	
	// Calculate angle (0 to 360 degrees, 0 = right, 90 = up)
	float angle = degrees(atan(uv.y, uv.x)) + 180.0;
	
	// Apply offset
	angle = mod(angle - arc_offset + 360.0, 360.0);
	
	// Create arc mask
	float half_arc = arc_angle * 0.5;
	float angle_dist = abs(angle - 180.0);
	float arc_mask = 1.0 - smoothstep(half_arc - arc_smoothness, half_arc + arc_smoothness, angle_dist);
	
	// Create ring with smooth edges
	float ring = smoothstep(inner_radius - smoothness, inner_radius + smoothness, dist) * 
	             (1.0 - smoothstep(outer_radius - smoothness, outer_radius + smoothness, dist));
	
	// Apply arc mask to ring
	ring *= arc_mask;
	
	// Optional glow effect
	float glow = 0.0;
	if (glow_intensity > 0.0) {
		float glow_outer = outer_radius + 0.1;
		glow = smoothstep(glow_outer, outer_radius, dist) * glow_intensity * arc_mask;
	}
	
	// Combine ring and glow, preserving the alpha from ring_color
	vec4 final_color = mix(ring_color, glow_color, glow * (1.0 - ring));
	COLOR = vec4(final_color.rgb, (ring + glow * glow_color.a) * ring_color.a);
}