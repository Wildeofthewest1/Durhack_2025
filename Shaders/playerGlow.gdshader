shader_type canvas_item;
render_mode blend_mix;

uniform vec4 base_color : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform float intensity : hint_range(0.0, 5.0) = 1.5;
uniform float spread    : hint_range(0.1, 2.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec4 mod_col = COLOR; // per-instance modulate from the node

    // Respect both texture coverage and external opacity modulation
    float coverage = tex.a * mod_col.a;
    if (coverage <= 0.0) { discard; }

    // Radial falloff & pulse
    vec2 centered_uv = UV - vec2(0.5);
    float dist  = length(centered_uv) * spread;
    float glow  = max(0.0, 1.0 - dist);
    glow *= (1.0 + 0.2 * sin(TIME * pulse_speed));
    glow  = clamp(glow * intensity, 0.0, 1.0);

    // Slight body shaping so it's not flat
    float body_brightness = 0.6 + 0.4 * glow;

    // Base color (RGB ignores modulate so your script sets opacity only)
    vec4 out_col = vec4(base_color.rgb * body_brightness,
                        coverage * base_color.a);

    // Add glow to RGB only; alpha stays solid by coverage
    out_col.rgb += base_color.rgb * glow * 0.3;

    COLOR = out_col;

    // If you also want modulate to tint the color, uncomment this line:
    // COLOR.rgb *= mod_col.rgb;
}
