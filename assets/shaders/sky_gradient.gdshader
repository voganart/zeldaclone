shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.35, 0.6, 0.9);
uniform vec3 sky_horizon_color : source_color = vec3(0.5, 0.7, 0.95);
uniform vec3 sky_bottom_color : source_color = vec3(0.1, 0.25, 0.4);

uniform float horizon_curve : hint_range(0.01, 1.0) = 0.6; 
uniform float stars_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float stars_speed : hint_range(0.0, 10.0) = 2.0;

// --- ПАРАМЕТРЫ КОЛИЧЕСТВА ---
uniform float stars_density : hint_range(0.0, 1.0) = 0.5; // Вероятность появления звезды

// Хеш функции (стабильные)
float hash12(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * .1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float StarLayer(vec2 uv) {
	vec2 gv = fract(uv) - 0.5;
	vec2 id = floor(uv);
	
	// Контроль плотности: если хеш клетки больше порога, звезды нет
	if (hash12(id * 3.4) > stars_density) return 0.0;
	
	// Позиция со сдвигом
	vec2 p = (vec2(hash12(id), hash12(id + 15.32)) - 0.5) * 0.8;
	
	float d = length(gv - p);
	float star = (0.02 / d) * smoothstep(1.0, 0.1, d * 5.0);
	
	float random_phase = hash12(id * 5.12);
	float blink = sin(TIME * stars_speed + random_phase * 6.28) * 0.5 + 0.5;
	
	star *= hash12(id + 100.0); // Рандомная яркость
	
	return star * blink;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float horizon_mix = abs(dir.y); 
	
	vec3 final_sky;
	if (dir.y > 0.0) {
		final_sky = mix(sky_horizon_color, sky_top_color, pow(horizon_mix, horizon_curve));
		
		if (stars_intensity > 0.0) {
			// Сферическая UV проекция
			vec2 sky_uv = vec2(atan(dir.z, dir.x), acos(dir.y));
			
			// Слой 1
			float stars1 = StarLayer(sky_uv * 20.0); 
			
			// Слой 2 (с поворотом)
			vec2 uv2 = sky_uv * 40.0;
			float s = sin(1.0); float c = cos(1.0);
			uv2 = mat2(vec2(c, -s), vec2(s, c)) * uv2;
			float stars2 = StarLayer(uv2);
			
			float total_stars = stars1 + stars2;
			
			// --- МАСКИ ---
			// 1. Horizon mask: убираем у горизонта
			float horizon_mask = smoothstep(0.0, 0.3, dir.y);
			
			// 2. Pole mask: убираем в самом зените (где dir.y > 0.95), чтобы скрыть стягивание
			float pole_mask = 1.0 - smoothstep(0.95, 1.0, dir.y);
			
			final_sky += vec3(total_stars) * stars_intensity * horizon_mask * pole_mask;
		}
		
	} else {
		final_sky = mix(sky_horizon_color, sky_bottom_color, pow(horizon_mix, horizon_curve));
	}
	
	COLOR = final_sky;
}