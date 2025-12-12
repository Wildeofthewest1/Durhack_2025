shader_type canvas_item;

// ----------- UNIFORMS -----------

// Screen texture
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec2 SCREEN_TEXTURE_PIXEL_SIZE;

// Uniform for belt color tint
uniform vec3 intensity_color : source_color = vec3(1.0, 0.0, 0.0);

// Controls how strong / opaque the tint color appears
uniform float intensity_color_opacity : hint_range(0.0, 2.0) = 1.0;

// Vignette strength (0 = off, 1 = strong)
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;

// Radius (in normalized screen space) where the centre should stay clear
uniform float clear_center_radius : hint_range(0.0, 1.0) = 0.25;

// how many of the 4 craters are active
uniform int active_craters;

// crater data
uniform vec2 crater_center0;
uniform float crater_radius0;
uniform float crater_strength0;

uniform vec2 crater_center1;
uniform float crater_radius1;
uniform float crater_strength1;

uniform vec2 crater_center2;
uniform float crater_radius2;
uniform float crater_strength2;

uniform vec2 crater_center3;
uniform float crater_radius3;
uniform float crater_strength3;

// global 0 → 1… screen tint level
uniform float global_intensity : hint_range(0.0, 1.0) = 0.0;


// ----------- HELPERS -----------

// Fix UV aspect so craters stay circular
vec2 fix_uv(vec2 uv) {
	float aspect = SCREEN_TEXTURE_PIXEL_SIZE.x / SCREEN_TEXTURE_PIXEL_SIZE.y;
	return vec2(uv.x * aspect, uv.y);
}

// Compute a circular vignette factor (0 center → 1 edges)
float compute_vignette(vec2 uv) {
	vec2 center_uv = vec2(0.5, 0.5);
	vec2 uv_fixed = fix_uv(uv);
	vec2 center_fixed = fix_uv(center_uv);

	float dist = length(uv_fixed - center_fixed);
	// Tuned so center is mostly clear, edges darken
	float vignette = smoothstep(0.4, 0.9, dist);
	return vignette; // 0 near center, 1 near edges
}

// 1.0 at centre, smoothly fading to ~0.0 as you approach clear_center_radius
float compute_center_clear(vec2 uv) {
	vec2 center_uv = vec2(0.5, 0.5);
	vec2 uv_fixed = fix_uv(uv);
	vec2 center_fixed = fix_uv(center_uv);

	float dist = length(uv_fixed - center_fixed);

	// Normalise distance so r = 1 at clear_center_radius
	float r = dist / clear_center_radius;

	// Gaussian profile: 1 at r=0, smoothly falls off towards r=1 and beyond
	// '2.0' controls how quickly it decays (smaller = wider / smoother)
	float clear = exp(-r * r * 0.1);

	// Optional clamp if you really don't want any effect far away
	// clear = (r > 2.0) ? 0.0 : clear; // <- only if you want a hard cutoff far out

	return clear;
}


// Crater: bowl distortion + clear center mask
void add_crater(
	inout vec2 displacement_accum,
	vec2 uv,
	vec2 center,
	float radius,
	float strength,
	inout float clear_mask_accum
) {
	if (radius <= 0.0 || strength <= 0.0) {
		return;
	}

	vec2 uv_fixed = fix_uv(uv);
	vec2 center_fixed = fix_uv(center);

	vec2 to_center = uv_fixed - center_fixed;
	float dist = length(to_center);

	if (dist <= 0.0001 || dist >= radius) {
		return;
	}

	float d = dist / radius;

	// Distortion (Gaussian bowl, strongest at center)
	float sigma_d = 0.4;
	float distort_shape = exp(- (d * d) / (2.0 * sigma_d * sigma_d));

	vec2 dir = to_center / dist;
	float distort_scale = 0.05;

	// Convert distortion back to UV space
	float aspect = SCREEN_TEXTURE_PIXEL_SIZE.x / SCREEN_TEXTURE_PIXEL_SIZE.y;
	vec2 disp_fixed = -dir * distort_shape * strength * distort_scale;
	vec2 disp_uv = vec2(disp_fixed.x / aspect, disp_fixed.y);
	displacement_accum += disp_uv;

	// Clear color mask (crater center should show original screen)
	float sigma_c = 0.1;
	float clear_shape = exp(- (d * d) / (2.0 * sigma_c * sigma_c));
	float local_clear = clear_shape * strength;

	if (local_clear > clear_mask_accum) {
		clear_mask_accum = local_clear;
	}
}


// ----------- FRAGMENT -----------

void fragment() {
	vec2 uv = SCREEN_UV;
	float intensity = global_intensity;

	vec2 total_displacement = vec2(0.0, 0.0);
	float clear_mask = 0.0;

	// 1) Add crater distortion + crater clear mask
	if (intensity > 0.0) {
		if (active_craters > 0) {
			add_crater(total_displacement, uv, crater_center0, crater_radius0, crater_strength0 * intensity, clear_mask);
		}
		if (active_craters > 1) {
			add_crater(total_displacement, uv, crater_center1, crater_radius1, crater_strength1 * intensity, clear_mask);
		}
		if (active_craters > 2) {
			add_crater(total_displacement, uv, crater_center2, crater_radius2, crater_strength2 * intensity, clear_mask);
		}
		if (active_craters > 3) {
			add_crater(total_displacement, uv, crater_center3, crater_radius3, crater_strength3 * intensity, clear_mask);
		}
	}

	// Sample distorted screen
	vec2 displaced_uv = uv + total_displacement;
	vec4 src = texture(SCREEN_TEXTURE, displaced_uv);

	// 2) GLOBAL COLOR BOOST (user-tintable + opacity adjustable)

	// How much tint color influences the final color
	float tint_amt = intensity * intensity_color_opacity;
	tint_amt = clamp(tint_amt, 0.0, 1.0);

	// Target boosted color:
	//   - slightly brighter base
	//   - plus user-selected tint color
	vec3 boosted_target = src.rgb * 1.3 + intensity_color;

	// Blend with adjustable tint strength
	vec3 boosted = mix(src.rgb, boosted_target, tint_amt);

	// 3) CRATERS CLEAR THAT TINT AT THE CRATER CENTRES
	if (clear_mask > 0.0 && intensity > 0.0) {
		float amt = clear_mask * intensity;
		if (amt > 1.0) {
			amt = 1.0;
		}
		// Mix back toward original screen where crater center is
		boosted = mix(boosted, src.rgb, amt);
	}

	// 4) VIGNETTE LAYER (edges darken with intensity)
	if (vignette_strength > 0.0 && intensity > 0.0) {
		float vignette = compute_vignette(uv); // 0 center, 1 edges
		float vig_amount = vignette * vignette_strength * intensity;
		boosted *= 1.0 - vig_amount;
	}

	// 5) FORCE CLEAR CENTRE (always original screen color there, smoothly)
	float center_clear = compute_center_clear(uv);
	if (center_clear > 0.0) {
		boosted = mix(boosted, src.rgb, center_clear);
	}

	COLOR = vec4(boosted, src.a);
}
