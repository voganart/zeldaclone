shader_type sky;

// --- Цвета неба ---
group_uniforms sky_colors;
uniform vec3 sky_top_color : source_color = vec3(0.35, 0.6, 0.9);
uniform vec3 sky_horizon_color : source_color = vec3(0.5, 0.7, 0.95);
uniform vec3 sky_bottom_color : source_color = vec3(0.1, 0.25, 0.4);

// --- Настройки облаков ---
group_uniforms clouds;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cloud_scale : hint_range(0.0, 5.0) = 1.5; 
uniform float cloud_speed : hint_range(0.0, 0.2) = 0.02;
uniform float cloud_cutoff : hint_range(0.0, 1.0) = 0.4;
uniform float cloud_fuzziness : hint_range(0.0, 0.5) = 0.1;

// Важно: Поставь галочку Seamless в настройках самой NoiseTexture2D!
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;

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

	// 2. ТРИПЛАНАРНАЯ ПРОЕКЦИЯ (Triplanar Mapping)
	// Это магия, которая убирает швы. Мы берем координаты с 3-х сторон.
	
	float time = TIME * cloud_speed;
	
	// Координаты для трех плоскостей
	// Добавляем time, чтобы облака плыли
	vec2 uv_top    = dir.xz * cloud_scale + time;
	vec2 uv_front  = dir.xy * cloud_scale + time;
	vec2 uv_side   = dir.zy * cloud_scale + time;
	
	// Веса смешивания (смягчаем переходы)
	// pow(..., 4.0) делает переходы между сторонами мягче
	vec3 weights = pow(abs(dir), vec3(4.0));
	weights = weights / (weights.x + weights.y + weights.z); // Нормализация
	
	// 3. Семплим шум три раза
	float noise_top   = texture(noise_texture, uv_top).r;
	float noise_front = texture(noise_texture, uv_front).r;
	float noise_side  = texture(noise_texture, uv_side).r;
	
	// Смешиваем результаты
	// Мы используем weights.y для top (потому что Y - это вертикаль), и т.д.
	float combined_noise = (noise_top * weights.y) + (noise_front * weights.z) + (noise_side * weights.x);
	
	// 4. Вырезаем облака
	float cloud_alpha = smoothstep(cloud_cutoff, cloud_cutoff + cloud_fuzziness, combined_noise);
	
	// Опционально: немного затемняем облака в самой нижней точке (бездне), чтобы не отвлекали
	// cloud_alpha *= smoothstep(1.0, 0.2, abs(dir.y));

	// 5. Итоговый цвет
	COLOR = mix(final_sky, cloud_color, cloud_alpha);
}