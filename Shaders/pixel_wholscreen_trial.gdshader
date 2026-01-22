shader_type canvas_item;

// Godot 4 requires explicit screen texture declaration
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// Size of the pixel block in SCREEN pixels
uniform float pixel_size : hint_range(1.0, 64.0) = 6.0;

// Whether to sample from the center of each block
uniform bool center_sample = true;

void fragment() {
	vec2 uv = SCREEN_UV;

	// SCREEN_PIXEL_SIZE = (1/width, 1/height)
	vec2 viewport_size_px = vec2(1.0) / SCREEN_PIXEL_SIZE;

	// UV → screen pixel coordinates
	vec2 screen_px = uv * viewport_size_px;

	// Snap to pixel grid
	vec2 snapped_px = floor(screen_px / pixel_size) * pixel_size;
	if (center_sample) {
		snapped_px += pixel_size * 0.5;
	}

	// Back to UV
	vec2 snapped_uv = snapped_px / viewport_size_px;

	COLOR = texture(screen_tex, snapped_uv);
}
