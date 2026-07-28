shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap;
uniform float atlas_frames : hint_range(2.0, 16.0, 1.0) = 8.0;
uniform vec4 color_modulate : source_color = vec4(1.0);
instance uniform float lod_fade : hint_range(0.0, 1.0) = 1.0;
instance uniform bool lod_is_impostor = true;

varying flat vec2 v_grid_base;
varying flat vec2 v_grid_fract;


void vertex() {
	vec3 camera_position_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 view_direction = normalize(camera_position_local);
	view_direction.y = max(-view_direction.y, 0.001);
	view_direction = normalize(view_direction);
	vec3 octant = sign(view_direction);
	float octa_sum = max(dot(view_direction, octant), 0.001);
	vec3 octahedron = view_direction / octa_sum;
	vec2 hemi_coord = vec2(
		octahedron.x + octahedron.z,
		octahedron.z - octahedron.x
	);
	vec2 grid = clamp(
		(hemi_coord + 1.0) * 0.5,
		vec2(0.0),
		vec2(1.0)
	) * (atlas_frames - 1.0);
	v_grid_base = floor(grid);
	v_grid_fract = fract(grid);

	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	float scale_z = length(MODEL_MATRIX[2].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX *= mat4(
		vec4(scale_x, 0.0, 0.0, 0.0),
		vec4(0.0, scale_y, 0.0, 0.0),
		vec4(0.0, 0.0, scale_z, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
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


vec4 sample_atlas_frame(vec2 frame, vec2 local_uv) {
	vec2 safe_frame = clamp(frame, vec2(0.0), vec2(atlas_frames - 1.0));
	vec2 safe_uv = clamp(local_uv, vec2(0.002), vec2(0.998));
	return texture(albedo_atlas, (safe_frame + safe_uv) / atlas_frames);
}


void fragment() {
	float lod_threshold = lod_bayer4x4(FRAGCOORD.xy);
	if ((!lod_is_impostor && lod_threshold < lod_fade)
			|| (lod_is_impostor && lod_threshold >= lod_fade)) {
		discard;
	}

	vec4 frame_00 = sample_atlas_frame(v_grid_base, UV);
	vec4 frame_10 = sample_atlas_frame(v_grid_base + vec2(1.0, 0.0), UV);
	vec4 frame_01 = sample_atlas_frame(v_grid_base + vec2(0.0, 1.0), UV);
	vec4 frame_11 = sample_atlas_frame(v_grid_base + vec2(1.0, 1.0), UV);
	vec4 albedo_x0 = mix(frame_00, frame_10, v_grid_fract.x);
	vec4 albedo_x1 = mix(frame_01, frame_11, v_grid_fract.x);
	vec4 albedo = mix(albedo_x0, albedo_x1, v_grid_fract.y) * color_modulate;
	if (albedo.a < 0.01) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}
