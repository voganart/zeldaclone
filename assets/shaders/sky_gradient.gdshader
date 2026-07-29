shader_type sky;
render_mode use_half_res_pass;

uniform vec3 sky_top_color : source_color = vec3(0.35, 0.6, 0.9);
uniform vec3 sky_horizon_color : source_color = vec3(0.5, 0.7, 0.95);
uniform vec3 sky_bottom_color : source_color = vec3(0.1, 0.25, 0.4);
uniform float horizon_curve : hint_range(0.01, 1.0) = 0.6;

uniform float stars_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float stars_speed : hint_range(0.0, 10.0) = 2.0;
uniform float stars_density : hint_range(0.0, 1.0) = 0.5;

group_uniforms Far_Clouds;
uniform sampler2D far_cloud_noise_base : repeat_enable, filter_linear_mipmap;
uniform sampler2D far_cloud_noise_detail : repeat_enable, filter_linear_mipmap;
uniform vec3 far_cloud_light_color : source_color = vec3(1.0);
uniform vec3 far_cloud_shadow_color : source_color = vec3(0.3, 0.4, 0.55);
uniform float far_cloud_horizon_coverage : hint_range(0.0, 1.0) = 0.62;
uniform float far_cloud_upper_coverage : hint_range(0.0, 1.0) = 0.18;
uniform float far_cloud_lower_coverage : hint_range(0.0, 1.0) = 0.34;
uniform float far_cloud_opacity : hint_range(0.0, 1.0) = 0.72;
uniform float far_cloud_scale : hint_range(0.25, 8.0) = 1.35;
uniform float far_cloud_softness : hint_range(0.01, 0.4) = 0.11;

global uniform vec3 weather_cloud_offset;
global uniform float weather_cloud_evolution;

const float TAU = 6.28318530718;


float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


float star_layer(vec2 uv) {
	vec2 grid_uv = fract(uv) - 0.5;
	vec2 cell_id = floor(uv);
	if (hash12(cell_id * 3.4) > stars_density) {
		return 0.0;
	}
	vec2 point_offset = (
		vec2(hash12(cell_id), hash12(cell_id + 15.32)) - 0.5
	) * 0.8;
	float distance_to_star = length(grid_uv - point_offset);
	float star = (0.02 / max(distance_to_star, 0.0001))
		* smoothstep(1.0, 0.1, distance_to_star * 5.0);
	float random_phase = hash12(cell_id * 5.12);
	float blink = sin(TIME * stars_speed + random_phase * TAU) * 0.5 + 0.5;
	return star * hash12(cell_id + 100.0) * blink;
}


vec3 base_sky(vec3 direction, bool include_stars) {
	float horizon_mix = abs(direction.y);
	vec3 result;
	if (direction.y > 0.0) {
		result = mix(
			sky_horizon_color,
			sky_top_color,
			pow(horizon_mix, horizon_curve)
		);
		if (include_stars && stars_intensity > 0.0) {
			vec2 sky_uv = vec2(
				atan(direction.z, direction.x),
				acos(direction.y)
			);
			float stars_first = star_layer(sky_uv * 20.0);
			vec2 second_uv = sky_uv * 40.0;
			float sine = sin(1.0);
			float cosine = cos(1.0);
			second_uv = mat2(
				vec2(cosine, -sine),
				vec2(sine, cosine)
			) * second_uv;
			float horizon_mask = smoothstep(0.0, 0.3, direction.y);
			float pole_mask = 1.0 - smoothstep(0.95, 1.0, direction.y);
			result += vec3(stars_first + star_layer(second_uv))
				* stars_intensity * horizon_mask * pole_mask;
		}
	} else {
		result = mix(
			sky_horizon_color,
			sky_bottom_color,
			pow(horizon_mix, horizon_curve)
		);
	}
	return result;
}


vec4 sample_far_clouds(vec3 direction) {
	float longitude = atan(direction.z, direction.x) / TAU + 0.5;
	float latitude = asin(clamp(direction.y, -1.0, 1.0)) / 3.14159265 + 0.5;
	vec2 drift = weather_cloud_offset.xz * vec2(0.000035, 0.00002);
	vec2 base_uv = vec2(longitude, latitude) * far_cloud_scale + drift;
	vec2 detail_uv = base_uv * 3.7
		- drift * 1.8
		+ vec2(weather_cloud_evolution * 0.003, weather_cloud_evolution * 0.002);

	float base_density = texture(far_cloud_noise_base, base_uv).r;
	float detail_density = texture(far_cloud_noise_detail, detail_uv).r;
	float density = base_density * 0.74 + detail_density * 0.26;

	float vertical_mix = smoothstep(0.0, 0.72, abs(direction.y));
	float regional_coverage = direction.y >= 0.0
		? mix(far_cloud_horizon_coverage, far_cloud_upper_coverage, vertical_mix)
		: mix(far_cloud_horizon_coverage, far_cloud_lower_coverage, vertical_mix);
	float threshold = 1.0 - regional_coverage;
	float alpha = smoothstep(
		threshold - far_cloud_softness,
		threshold + far_cloud_softness,
		density
	) * far_cloud_opacity;

	float light_mix = clamp(
		base_density * 0.8 + detail_density * 0.2 + direction.y * 0.18,
		0.0,
		1.0
	);
	vec3 cloud_color = mix(
		far_cloud_shadow_color,
		far_cloud_light_color,
		light_mix
	);
	return vec4(cloud_color, alpha);
}


void sky() {
	vec3 direction = normalize(EYEDIR);
	vec3 background = base_sky(direction, !AT_CUBEMAP_PASS);

	if (AT_CUBEMAP_PASS) {
		COLOR = background;
		ALPHA = 1.0;
	} else if (AT_HALF_RES_PASS) {
		vec4 cloud = sample_far_clouds(direction);
		COLOR = cloud.rgb;
		ALPHA = cloud.a;
	} else {
		vec4 cloud = HALF_RES_COLOR;
		COLOR = mix(background, cloud.rgb, cloud.a);
		ALPHA = 1.0;
	}
}
