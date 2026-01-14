shader_type spatial;
render_mode unshaded, cull_front; // Вернули обычный режим

// --- КАЧЕСТВО ---
group_uniforms Rendering;
uniform int steps : hint_range(16, 128) = 64;
uniform float step_size : hint_range(0.01, 0.1) = 0.02;

// --- ФОРМА ---
group_uniforms Shape_Base;
uniform sampler3D noise_texture : source_color;
uniform float cloud_scale : hint_range(0.1, 4.0) = 1.0; 
uniform float density_threshold : hint_range(0.0, 1.0) = 0.2; 
uniform float density_multiplier : hint_range(0.0, 20.0) = 8.0;
uniform vec3 move_speed = vec3(0.05, 0.0, 0.05);

group_uniforms Shape_Erosion;
uniform float erosion_strength : hint_range(0.0, 1.0) = 0.5; 
uniform float erosion_scale : hint_range(0.1, 2.0) = 0.3; 
uniform float erosion_offset_speed : hint_range(0.0, 1.0) = 0.1;

uniform float sphere_radius : hint_range(0.1, 0.6) = 0.45; 
uniform float softness : hint_range(0.01, 1.0) = 0.2;

// --- ЦВЕТА ---
group_uniforms Coloring;
uniform vec3 color_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 color_shadow : source_color = vec3(0.3, 0.4, 0.6);

// --- СВЕТ ---
group_uniforms Stylized_Lighting;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.5; 
uniform float shadow_softness : hint_range(0.01, 1.0) = 0.2; 
uniform float density_shadow_power : hint_range(0.0, 5.0) = 2.0; 
uniform float top_highlight_strength : hint_range(0.0, 2.0) = 1.0;

// --- LOD ---
group_uniforms LOD;
uniform float fade_distance : hint_range(0.0, 1000.0) = 400.0;
uniform float fade_margin : hint_range(0.0, 500.0) = 50.0;
uniform float lod_noise_start : hint_range(0.0, 500.0) = 50.0;
uniform float lod_noise_end : hint_range(0.0, 1000.0) = 400.0;
uniform float lod_noise_factor : hint_range(0.1, 1.0) = 0.4;

// --- SOFT COLLISION ---
group_uniforms Soft_Collision;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform float soft_collision_dist : hint_range(0.0, 20.0) = 5.0;

varying vec3 v_local_pos;
varying vec3 v_camera_local;
varying vec3 v_obj_scale;
varying float v_world_dist;
varying vec3 v_local_up_dir;
varying vec3 v_world_pos_center;

void vertex() {
	v_local_pos = VERTEX;
	mat4 world_to_local = inverse(MODEL_MATRIX);
	v_camera_local = (world_to_local * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	v_obj_scale = vec3(length(MODEL_MATRIX[0]), length(MODEL_MATRIX[1]), length(MODEL_MATRIX[2]));
	v_world_dist = distance(CAMERA_POSITION_WORLD, (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	v_local_up_dir = normalize((world_to_local * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	v_world_pos_center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

vec2 ray_box_intersection(vec3 ray_origin, vec3 ray_dir, vec3 box_min, vec3 box_max) {
	vec3 t_min = (box_min - ray_origin) / ray_dir;
	vec3 t_max = (box_max - ray_origin) / ray_dir;
	vec3 t1 = min(t_min, t_max);
	vec3 t2 = max(t_min, t_max);
	return vec2(max(max(t1.x, t1.y), t1.z), min(min(t2.x, t2.y), t2.z));
}

float get_density(vec3 p, float dist_to_cam) {
	float dist_to_edge = max(abs(p.x), max(abs(p.y), abs(p.z)));
	float edge_mask = 1.0 - smoothstep(0.35, 0.5, dist_to_edge); // Мягкие края контейнера
	
	if (edge_mask <= 0.0) return 0.0;

	float sphere_mask = 1.0 - smoothstep(sphere_radius - softness, sphere_radius, length(p));
	
	vec3 erosion_uv = (p * v_obj_scale * erosion_scale) + (v_world_pos_center * 0.1) + (TIME * move_speed * erosion_offset_speed);
	float erosion_val = texture(noise_texture, erosion_uv).r;
	float shape_mask = sphere_mask - (erosion_val * erosion_strength);
	if (shape_mask <= 0.0) return 0.0;
	
	float lod_mix = smoothstep(lod_noise_start, lod_noise_end, dist_to_cam);
	float current_scale_mod = mix(1.0, lod_noise_factor, lod_mix);
	vec3 detail_uv = p * v_obj_scale * cloud_scale * current_scale_mod + (TIME * move_speed);
	float detail_noise = texture(noise_texture, detail_uv).r;
	
	float final_density = detail_noise * shape_mask * edge_mask;
	return smoothstep(density_threshold, density_threshold + 0.1, final_density) * density_multiplier;
}

void fragment() {
	if (v_world_dist > fade_distance + fade_margin + 5.0) discard;

	// Soft collision
	float depth_tex = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_tex);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_scene_depth = -view.z;
	float linear_surface_depth = -VERTEX.z;
	float depth_fade = clamp((linear_scene_depth - linear_surface_depth) / soft_collision_dist, 0.0, 1.0);

	vec3 ray_origin = v_camera_local;
	vec3 ray_dir = normalize(v_local_pos - v_camera_local);
	vec2 t_hit = ray_box_intersection(ray_origin, ray_dir, vec3(-0.5), vec3(0.5));
	
	float t_start = max(t_hit.x, 0.0);
	float t_end = t_hit.y;
	if (t_start >= t_end) discard;

	float dist = t_start;
	vec3 accum_color = vec3(0.0);
	float transmittance = 1.0;
	float dither = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) * step_size;
	dist += dither;

	for(int i = 0; i < steps; i++) {
		if(dist >= t_end || transmittance < 0.01) break;
		
		vec3 pos = ray_origin + ray_dir * dist;
		float density = get_density(pos, v_world_dist);
		
		if(density > 0.001) {
			float step_dens = density * step_size;
			float alpha = 1.0 - exp(-step_dens);
			
			float height_projection = dot(pos, v_local_up_dir);
			float height_factor = clamp(height_projection + 0.5, 0.0, 1.0);
			float density_factor = exp(-density * density_shadow_power);
			float light_energy = (density_factor * 0.5) + (height_factor * top_highlight_strength);
			float light_mix = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, light_energy);
			
			vec3 step_color = mix(color_shadow, color_light, light_mix);
			
			accum_color += step_color * alpha * transmittance;
			transmittance *= (1.0 - alpha);
		}
		dist += step_size;
	}
	
	float physical_alpha = 1.0 - transmittance;
	if (physical_alpha < 0.01) discard;
	
	vec3 final_rgb = accum_color / max(physical_alpha, 0.001);
	
	float fade_factor = 1.0 - smoothstep(fade_distance, fade_distance + fade_margin, v_world_dist);
	fade_factor = pow(fade_factor, 2.0);
	
	ALBEDO = final_rgb;
	ALPHA = physical_alpha * fade_factor * depth_fade;
}