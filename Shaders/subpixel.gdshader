shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec2 cam_offset = vec2(0.0, 0.0);

void vertex() {
	VERTEX += cam_offset;
}

void fragment() {
	// Same as default CanvasItem: texture * modulate

}
