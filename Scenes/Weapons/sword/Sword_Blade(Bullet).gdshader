shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.4, 0.9, 1.0, 0.8);
uniform float glow_size = 2.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	
	vec2 ps = TEXTURE_PIXEL_SIZE * glow_size;

	float a = 0.0;
	a += texture(TEXTURE, UV + vec2( ps.x, 0.0)).a;
	a += texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a;
	a += texture(TEXTURE, UV + vec2(0.0,  ps.y)).a;
	a += texture(TEXTURE, UV + vec2(0.0, -ps.y)).a;
	a += texture(TEXTURE, UV + vec2( ps.x,  ps.y)).a;
	a += texture(TEXTURE, UV + vec2(-ps.x,  ps.y)).a;
	a += texture(TEXTURE, UV + vec2( ps.x, -ps.y)).a;
	a += texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a;

	a = clamp(a, 0.0, 1.0);

	vec4 glow = vec4(glow_color.rgb, a * glow_color.a);
	COLOR = glow;
}
