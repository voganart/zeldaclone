shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 color_tint : source_color = vec4(1.0);

// Настройки ветра
group_uniforms Wind;
uniform float wind_speed = 1.0;
uniform float wind_strength = 2.0;
uniform float wind_detail = 1.0; // Размер шума
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.5);

// Глобальный параметр (можно менять из скрипта погоды)
global uniform float global_wind_power;

void vertex() {
    // Попробуй читать напрямую, без условий
    float influence = COLOR.r; 
    
    // ЖЕСТКИЙ ФИКС: Если цвет хоть немного черный (< 0.1), считаем его нулем.
    // Это уберет шум, если ты случайно закрасил ствол не идеально черным (0.01).
    if (influence < 0.1) {
        influence = 0.0;
    }
	
	if (influence > 0.0) {
		// Создаем синусоиду на основе времени и позиции
		float time = TIME * wind_speed;
		
		// Сдвиг вершин
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		
		// Простая волна
		float wind_wave = sin(time + world_pos.x * wind_detail + world_pos.z * wind_detail);
		
		// Дополнительная мелкая дрожь для листвы
		float flutter = sin(time * 3.0 + world_pos.y * 10.0) * 0.2;
		
		// Итоговое смещение
		vec3 displacement = wind_direction * (wind_wave + flutter) * influence * wind_strength;
		
		// Применяем (можно умножить на global_wind_power если есть система погоды)
		VERTEX += displacement;
	}
}

void fragment() {
	vec4 albedo_tex = texture(albedo_texture, UV);
	ALBEDO = albedo_tex.rgb * color_tint.rgb;
	
	// Если у текстуры есть прозрачность (для иголок)
	// ALPHA = albedo_tex.a;
	// ALPHA_SCISSOR_THRESHOLD = 0.5;
}