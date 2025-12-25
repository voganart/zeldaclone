shader_type sky;

// --- Цвета неба ---
group_uniforms sky_colors;
uniform vec3 sky_top_color : source_color = vec3(0.35, 0.6, 0.9);
uniform vec3 sky_horizon_color : source_color = vec3(0.5, 0.7, 0.95);
uniform vec3 sky_bottom_color : source_color = vec3(0.1, 0.25, 0.4);

// --- Настройки ОСНОВНЫХ облаков ---
group_uniforms clouds;
// ВАЖНО: Я переименовал cloud_color в cloud_edge_color для ясности.
// Старое свойство исчезнет, нужно будет заново назначить цвет в инспекторе.
uniform vec3 cloud_edge_color : source_color = vec3(1.0, 1.0, 1.0); // Цвет краев
uniform vec3 cloud_core_color : source_color = vec3(0.8, 0.85, 0.9); // НОВОЕ: Цвет ядра/центра
uniform float core_softness : hint_range(0.0, 1.0) = 0.2; // НОВОЕ: Плавность градиента в облаке

uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform float cloud_scale : hint_range(0.0, 5.0) = 1.5; 
uniform float cloud_speed : hint_range(0.0, 0.2) = 0.02;
uniform float cloud_cutoff : hint_range(0.0, 1.0) = 0.4;
uniform float cloud_fuzziness : hint_range(0.0, 0.5) = 0.1;

// --- Настройки ДЕТАЛЬНЫХ облаков ---
group_uniforms Cloud_Detail;
uniform sampler2D detail_noise_texture : filter_linear_mipmap, repeat_enable;
uniform float detail_scale : hint_range(0.0, 20.0) = 5.0;
uniform float detail_speed : hint_range(0.0, 0.5) = 0.1;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.5;

void sky() {
	vec3 dir = normalize(EYEDIR);
	
	// 1. Градиент фона (Сфера)
	float horizon_mix = abs(dir.y); 
	vec3 final_sky;
	if (dir.y > 0.0) {
		final_sky = mix(sky_horizon_color, sky_top_color, pow(horizon_mix, 0.6));
	} else {
		final_sky = mix(sky_horizon_color, sky_bottom_color, pow(horizon_mix, 0.6));
	}

	vec3 weights = pow(abs(dir), vec3(4.0));
	weights = weights / (weights.x + weights.y + weights.z);
	
	// --- 2. Расчет ОСНОВНОГО слоя шума ---
	float time_base = TIME * cloud_speed;
	vec2 uv_top_base    = dir.xz * cloud_scale + time_base;
	vec2 uv_front_base  = dir.xy * cloud_scale + time_base;
	vec2 uv_side_base   = dir.zy * cloud_scale + time_base;
	
	float noise_top_base   = texture(noise_texture, uv_top_base).r;
	float noise_front_base = texture(noise_texture, uv_front_base).r;
	float noise_side_base  = texture(noise_texture, uv_side_base).r;
	float combined_noise_base = (noise_top_base * weights.y) + (noise_front_base * weights.z) + (noise_side_base * weights.x);
	
	// --- 3. Расчет ДЕТАЛЬНОГО слоя шума ---
	float time_detail = TIME * detail_speed;
	vec2 uv_top_detail    = dir.xz * detail_scale + time_detail;
	vec2 uv_front_detail  = dir.xy * detail_scale + time_detail;
	vec2 uv_side_detail   = dir.zy * detail_scale + time_detail;

	float noise_top_detail   = texture(detail_noise_texture, uv_top_detail).r;
	float noise_front_detail = texture(detail_noise_texture, uv_front_detail).r;
	float noise_side_detail  = texture(detail_noise_texture, uv_side_detail).r;
	float combined_noise_detail = (noise_top_detail * weights.y) + (noise_front_detail * weights.z) + (noise_side_detail * weights.x);
	
	// --- 4. Смешиваем два слоя шума ---
	float final_noise = mix(combined_noise_base, combined_noise_base * combined_noise_detail, detail_strength);
	
	// --- 5. НОВАЯ ЛОГИКА: Расчет цвета облака ---
	// Мы используем *только основной шум* для градиента, чтобы он был плавным,
	// а не "рябил" от мелких деталей.
	float gradient_factor = smoothstep(cloud_cutoff, cloud_cutoff + core_softness, combined_noise_base);
	vec3 final_cloud_color = mix(cloud_edge_color, cloud_core_color, gradient_factor);

	// 6. Вырезаем альфа-канал облака из ИТОГОВОГО шума (с деталями)
	float cloud_alpha = smoothstep(cloud_cutoff, cloud_cutoff + cloud_fuzziness, final_noise);
	
	// 7. Итоговый цвет
	COLOR = mix(final_sky, final_cloud_color, cloud_alpha);
}