shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

group_uniforms Rendering;
uniform int billboard_steps : hint_range(4, 16) = 8;

group_uniforms Shape;
uniform sampler3D noise_texture : source_color;
uniform float cloud_scale : hint_range(0.1, 4.0) = 1.0;
uniform float density_threshold : hint_range(0.0, 1.0) = 0.2;
uniform float density_multiplier : hint_range(0.0, 20.0) = 8.0;
uniform vec3 move_speed = vec3(0.05, 0.0, 0.05);
uniform float erosion_strength : hint_range(0.0, 1.0) = 0.5;
uniform float erosion_scale : hint_range(0.01, 2.0) = 0.3;
uniform float erosion_offset_speed : hint_range(0.0, 1.0) = 0.1;
uniform float sphere_radius : hint_range(0.1, 0.75) = 0.6;
uniform float softness : hint_range(0.01, 1.0) = 0.2;
instance uniform float shape_override_enabled : hint_range(0.0, 1.0) = 0.0;
instance uniform vec3 shape_override_scale = vec3(70.0, 40.0, 110.0);
instance uniform vec3 shape_override_offset = vec3(0.17, 0.33, 0.61);
instance uniform vec3 shape_offset = vec3(0.0);
instance uniform float lobe_spread : hint_range(0.0, 1.0) = 0.45;
instance uniform float lobe_variation : hint_range(0.0, 1.0) = 0.65;

group_uniforms Coloring;
uniform vec3 color_light : source_color = vec3(1.0);
uniform vec3 color_shadow : source_color = vec3(0.25, 0.35, 0.55);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_softness : hint_range(0.01, 1.0) = 0.2;
uniform float density_shadow_power : hint_range(0.0, 5.0) = 2.0;
uniform float top_highlight_strength : hint_range(0.0, 2.0) = 1.0;

group_uniforms LOD;
uniform float lod_noise_start : hint_range(0.0, 500.0) = 50.0;
uniform float lod_noise_end : hint_range(0.0, 1000.0) = 400.0;
uniform float lod_noise_factor : hint_range(0.1, 1.0) = 0.4;
instance uniform float lod_fade : hint_range(0.0, 1.0) = 1.0;
instance uniform bool lod_is_impostor = true;
instance uniform float pool_fade : hint_range(0.0, 1.0) = 1.0;

varying flat vec3 v_obj_scale;
varying flat vec3 v_world_center;
varying flat float v_world_dist;


void vertex() {
	vec3 camera_position_local =
		(inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 view_direction = normalize(camera_position_local);

	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	float scale_z = length(MODEL_MATRIX[2].xyz);
	float projected_horizontal = sqrt(
		scale_x * scale_x * view_direction.z * view_direction.z
		+ scale_z * scale_z * view_direction.x * view_direction.x
	);
	projected_horizontal = max(
		projected_horizontal,
		min(scale_x, scale_z) * 0.5
	);

	v_obj_scale = vec3(scale_x, scale_y, scale_z);
	v_world_center = MODEL_MATRIX[3].xyz;
	v_world_dist = distance(CAMERA_POSITION_WORLD, v_world_center);

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX *= mat4(
		vec4(projected_horizontal, 0.0, 0.0, 0.0),
		vec4(0.0, scale_y, 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}


vec2 ray_box_intersection(
	vec3 ray_origin,
	vec3 ray_dir,
	vec3 box_min,
	vec3 box_max
) {
	vec3 safe_dir = ray_dir;
	safe_dir.x = abs(safe_dir.x) < 0.0001 ? 0.0001 : safe_dir.x;
	safe_dir.y = abs(safe_dir.y) < 0.0001 ? 0.0001 : safe_dir.y;
	safe_dir.z = abs(safe_dir.z) < 0.0001 ? 0.0001 : safe_dir.z;
	vec3 t_min = (box_min - ray_origin) / safe_dir;
	vec3 t_max = (box_max - ray_origin) / safe_dir;
	vec3 t1 = min(t_min, t_max);
	vec3 t2 = max(t_min, t_max);
	return vec2(
		max(max(t1.x, t1.y), t1.z),
		min(min(t2.x, t2.y), t2.z)
	);
}

float lobe_hash(vec3 seed, float salt) {
	return fract(sin(dot(seed + vec3(salt), vec3(17.17, 31.73, 47.91))) * 43758.5453);
}

float lobe_sphere(vec3 p, vec3 center, float radius, float edge) {
	return 1.0 - smoothstep(radius - edge, radius, length(p - center));
}

float multi_lobe_mask(vec3 p, vec3 seed) {
	float variation = clamp(lobe_variation, 0.0, 1.0);
	float spread = 0.04 + clamp(lobe_spread, 0.0, 1.0) * 0.16;
	float edge = max(softness * 0.55, 0.015);
	float r0 = sphere_radius * mix(0.72, 0.92, lobe_hash(seed, 1.0));
	float mask = lobe_sphere(p, vec3(0.0), r0, edge);
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float angle = fi * 1.5707963 + lobe_hash(seed, 10.0 + fi) * variation;
		float distance_scale = mix(0.75, 1.2, lobe_hash(seed, 20.0 + fi));
		vec3 center = vec3(
			cos(angle) * spread * distance_scale,
			(lobe_hash(seed, 30.0 + fi) - 0.5) * spread * variation,
			sin(angle) * spread * distance_scale
		);
		float radius = sphere_radius * mix(
			0.46,
			0.72,
			mix(0.5, lobe_hash(seed, 40.0 + fi), variation)
		);
		mask = max(mask, lobe_sphere(p, center, radius, edge));
	}
	return mask;
}

vec3 reference_lighting(float local_height) {
	float height_factor = clamp(local_height + 0.5, 0.0, 1.0);
	float light_energy = 0.35 + height_factor * top_highlight_strength;
	float light_mix = smoothstep(
		shadow_threshold - shadow_softness,
		shadow_threshold + shadow_softness,
		light_energy
	);
	return mix(color_shadow, color_light, light_mix);
}


float get_density(vec3 p, float dist_to_cam) {
	float dist_to_edge = max(abs(p.x), max(abs(p.y), abs(p.z)));
	float edge_mask = 1.0 - smoothstep(0.35, 0.5, dist_to_edge);
	if (edge_mask <= 0.0) {
		return 0.0;
	}

	float sphere_mask = multi_lobe_mask(p, shape_offset);
	float use_override = clamp(shape_override_enabled, 0.0, 1.0);
	vec3 effective_scale = mix(
		v_obj_scale,
		shape_override_scale,
		use_override
	);
	vec3 runtime_erosion_offset =
		(v_world_center * 0.1)
		+ shape_offset
		+ (TIME * move_speed * erosion_offset_speed);
	vec3 erosion_offset = mix(
		runtime_erosion_offset,
		shape_override_offset,
		use_override
	);
	vec3 erosion_uv =
		(p * effective_scale * erosion_scale)
		+ erosion_offset;
	float erosion_val = texture(noise_texture, erosion_uv).r;
	float shape_mask = sphere_mask - erosion_val * erosion_strength;
	if (shape_mask <= 0.0) {
		return 0.0;
	}

	float lod_mix = smoothstep(lod_noise_start, lod_noise_end, dist_to_cam);
	float current_scale_mod = mix(1.0, lod_noise_factor, lod_mix);
	vec3 detail_offset = mix(
		TIME * move_speed + shape_offset * 1.7,
		shape_override_offset * 1.7,
		use_override
	);
	vec3 detail_uv =
		p * effective_scale * cloud_scale * current_scale_mod
		+ detail_offset;
	float detail_noise = texture(noise_texture, detail_uv).r;
	float final_density = detail_noise * shape_mask * edge_mask;
	return smoothstep(
		density_threshold,
		density_threshold + 0.1,
		final_density
	) * density_multiplier;
}


float lod_bayer4x4(vec2 pixel_position) {
	vec2 p = mod(floor(pixel_position), 4.0);
	float value = 0.0;
	if (p.y < 1.0) {
		if (p.x < 1.0) value = 0.0;
		else if (p.x < 2.0) value = 8.0;
		else if (p.x < 3.0) value = 2.0;
		else value = 10.0;
	} else if (p.y < 2.0) {
		if (p.x < 1.0) value = 12.0;
		else if (p.x < 2.0) value = 4.0;
		else if (p.x < 3.0) value = 14.0;
		else value = 6.0;
	} else if (p.y < 3.0) {
		if (p.x < 1.0) value = 3.0;
		else if (p.x < 2.0) value = 11.0;
		else if (p.x < 3.0) value = 1.0;
		else value = 9.0;
	} else {
		if (p.x < 1.0) value = 15.0;
		else if (p.x < 2.0) value = 7.0;
		else if (p.x < 3.0) value = 13.0;
		else value = 5.0;
	}
	return (value + 0.5) / 16.0;
}


void fragment() {
	float lod_threshold = lod_bayer4x4(FRAGCOORD.xy);
	if ((!lod_is_impostor && lod_threshold < lod_fade)
			|| (lod_is_impostor && lod_threshold >= lod_fade)) {
		discard;
	}

	vec2 plane_position = (UV - vec2(0.5)) * 1.4;
	vec3 ray_origin = vec3(plane_position, -0.75);
	vec3 ray_dir = vec3(0.0, 0.0, 1.0);
	vec2 t_hit = ray_box_intersection(
		ray_origin,
		ray_dir,
		vec3(-0.5),
		vec3(0.5)
	);
	float t_start = max(t_hit.x, 0.0);
	float t_end = t_hit.y;
	if (t_start >= t_end) {
		discard;
	}

	float active_step_size =
		(t_end - t_start) / max(float(billboard_steps), 1.0);
	float dist = t_start;
	float jitter =
		fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453)
		* active_step_size;
	dist += jitter;

	float transmittance = 1.0;
	for (int i = 0; i < 16; i++) {
		if (
			i >= billboard_steps
			|| dist >= t_end
			|| transmittance < 0.01
		) {
			break;
		}

		vec3 pos = ray_origin + ray_dir * dist;
		float density = get_density(pos, v_world_dist);
		if (density > 0.001) {
			float step_dens = density * active_step_size;
			float alpha = 1.0 - exp(-step_dens);
			transmittance *= 1.0 - alpha;
		}
		dist += active_step_size;
	}

	float raw_alpha = 1.0 - transmittance;
	if (raw_alpha < 0.01) {
		discard;
	}
	ALBEDO = reference_lighting(plane_position.y);
	ALPHA = raw_alpha * pool_fade;
}
