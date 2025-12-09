shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;

// ======================================================
// Original uniforms
// ======================================================
uniform bool use_hit_flash = false;
uniform float hit_flash_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 hit_flash_color : source_color = vec4(1.0, 0.1, 0.1, 1.0);

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color;
uniform bool clamp_diffuse_to_max = false;

uniform int cuts : hint_range(1, 8) = 3;
uniform float wrap : hint_range(-2.0, 2.0) = 0.0;
uniform float steepness : hint_range(1.0, 8.0) = 1.0;

uniform bool use_attenuation = true;

uniform bool use_specular = true;
uniform float specular_strength : hint_range(0.0, 1.0) = 1.0;
uniform float specular_shininess : hint_range(0.0, 32.0) = 16.0;
uniform sampler2D specular_map : source_color;

uniform bool use_rim = true;
uniform float rim_width : hint_range(0.0, 16.0) = 8.0;
uniform vec4 rim_color : source_color = vec4(1.0);

uniform bool use_ramp = false;
uniform sampler2D ramp : source_color;

uniform bool use_borders = false;
uniform float border_width = 0.01;


// ======================================================
// Gradient settings
// ======================================================
uniform bool use_gradient = false;
uniform sampler2D gradient_texture : source_color;

// Blend modes: 0=Multiply,1=Overlay,2=Add,3=Replace
uniform int gradient_blend_mode : hint_range(0, 3) = 0;
uniform float gradient_strength : hint_range(0.0, 1.0) = 1.0;

// LOCAL coordinate bounds (should be set once from GDScript or adjusted manually)
uniform float mesh_min_y = 0.0;
uniform float mesh_max_y = 1.0;

// Choose UV set for gradient sampling: 0 = UV, 1 = UV2
uniform int gradient_uv_set : hint_range(0, 1) = 0;


// ======================================================
varying float v_y;
varying vec3 v_normal;

// Multiply
vec3 blend_multiply(vec3 base, vec3 blend) {
	return base * blend;
}

// Add (Linear Dodge)
vec3 blend_add(vec3 base, vec3 blend) {
	return min(base + blend, 1.0);
}

// Screen
vec3 blend_screen(vec3 base, vec3 blend) {
	return 1.0 - (1.0 - base) * (1.0 - blend);
}

// Overlay (правильная, как в Photoshop)
vec3 blend_overlay(vec3 base, vec3 blend) {
	return mix(
		2.0 * base * blend,                        // base < 0.5
		1.0 - 2.0 * (1.0 - base) * (1.0 - blend),  // base >= 0.5
		step(0.5, base)
	);
}

// Soft Light (намного мягче)
vec3 blend_softlight(vec3 base, vec3 blend) {
	return mix(
		base - (1.0 - 2.0 * blend) * base * (1.0 - base),                // blend <= 0.5
		base + (2.0 * blend - 1.0) * (sqrt(base) - base),                // blend > 0.5
		step(0.5, blend)
	);
}

// Linear Light (жёсткий контраст)
vec3 blend_linear_light(vec3 base, vec3 blend) {
	return clamp(base + 2.0 * blend - 1.0, 0.0, 1.0);
}
// ======================================================
float split_specular(float specular) {
	return step(0.5, specular);
}


// ======================================================
void vertex() {
	// VERTEX is local-space position *before* skinning result in many cases;
	// using VERTEX.y fixes the gradient to model space (won't follow animation transforms).
	v_y = VERTEX.y;
	v_normal = NORMAL;
}


// ======================================================
void fragment() {
	// Base albedo
	vec3 base_color = albedo.rgb * texture(albedo_texture, UV).rgb;

	// Hit flash
	if (use_hit_flash) {
		vec3 flash_color = hit_flash_color.rgb;
		base_color = mix(base_color, flash_color, hit_flash_strength);
	}

	// ---------------------
	// Local-space Gradient (sample from chosen UV set)
	// ---------------------
	if (use_gradient) {
		// safe range
		float range = max(mesh_max_y - mesh_min_y, 0.0001);
		float t = clamp((v_y - mesh_min_y) / range, 0.0, 1.0);

		// choose UV set: UV or UV2
		vec2 uv_for_grad = (gradient_uv_set == 1) ? UV2 : UV;

		// replace x with t so gradient follows model-local vertical position
		uv_for_grad.x = t;

		// sample gradient texture
		vec3 grad = texture(gradient_texture, uv_for_grad).rgb;

		if (gradient_blend_mode == 0) {
			// Multiply
			base_color = mix(base_color, blend_multiply(base_color, grad), gradient_strength);

		} else if (gradient_blend_mode == 1) {
			// Overlay
			base_color = mix(base_color, blend_overlay(base_color, grad), gradient_strength);

		} else if (gradient_blend_mode == 2) {
			// Add
			base_color = mix(base_color, blend_add(base_color, grad), gradient_strength);

		} else if (gradient_blend_mode == 3) {
			// Screen
			base_color = mix(base_color, blend_screen(base_color, grad), gradient_strength);

		} else if (gradient_blend_mode == 4) {
			// Soft Light
			base_color = mix(base_color, blend_softlight(base_color, grad), gradient_strength);

		} else if (gradient_blend_mode == 5) {
			// Linear Light
			base_color = mix(base_color, blend_linear_light(base_color, grad), gradient_strength);

		} else {
			// Replace
			base_color = mix(base_color, grad, gradient_strength);
		}

	}

	ALBEDO = base_color;
	ALPHA *= (1.0 - dissolve_amount);
}


// ======================================================
void light() {
	float attenuation = use_attenuation ? ATTENUATION : 1.0;

	float NdotL = dot(NORMAL, LIGHT);
	float diffuse_amount = NdotL + (attenuation - 1.0) + wrap;
	diffuse_amount *= steepness;

	float cuts_inv = 1.0 / float(cuts);
	float diffuse_stepped = clamp(
		diffuse_amount + mod(1.0 - diffuse_amount, cuts_inv),
		0.0, 1.0
	);

	float border = 0.0;
	if (use_borders) {
		float corr_border_width = length(cross(NORMAL, LIGHT)) * border_width * steepness;
		border = step(diffuse_stepped - corr_border_width, diffuse_amount)
				- step(1.0 - corr_border_width, diffuse_amount);
	}

	vec3 diffuse = ALBEDO.rgb * LIGHT_COLOR / PI;
	if (use_ramp)
		diffuse *= texture(ramp, vec2(diffuse_stepped * (1.0 - border), 0.0)).rgb;
	else
		diffuse *= diffuse_stepped * (1.0 - border);

	if (clamp_diffuse_to_max)
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, diffuse);
	else
		DIFFUSE_LIGHT += diffuse;

	if (use_specular) {
		vec3 H = normalize(LIGHT + VIEW);
		float NdotH = dot(NORMAL, H);
		float specular_amount =
			max(pow(NdotH, specular_shininess * specular_shininess), 0.0)
			* texture(specular_map, UV).r
			* attenuation;

		specular_amount = split_specular(specular_amount);
		SPECULAR_LIGHT += specular_strength * specular_amount * LIGHT_COLOR;
	}

	if (use_rim) {
		float NdotV = dot(NORMAL, VIEW);
		float rim_light = pow(1.0 - NdotV, rim_width);
		SPECULAR_LIGHT += rim_light * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI;
	}
}
