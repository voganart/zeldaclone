shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// Текстура трещин (Белые трещины, прозрачный фон)
uniform sampler2D crack_texture : source_color, filter_linear_mipmap;

// Цвета
uniform vec4 color_inner : source_color = vec4(1.0, 0.8, 0.0, 1.0); // Желтый центр
uniform vec4 color_outer : source_color = vec4(1.0, 0.3, 0.0, 1.0); // Оранжевые края

// Анимация
uniform float progress : hint_range(0.0, 1.0) = 0.0; // Расширение круга (0 -> 1)
uniform float dissolve : hint_range(0.0, 1.0) = 0.0; // Исчезновение (0 -> 1)
uniform float emission_strength : hint_range(1.0, 10.0) = 5.0; // Яркость свечения

void fragment() {
	// 1. Координаты и Дистанция
	vec2 uv_center = UV - 0.5;
	float dist = length(uv_center) * 2.0; // 0 в центре, 1 на краях
	
	// 2. Семплим текстуру
	vec4 tex_color = texture(crack_texture, UV);
	
	// Если текстура без альфы (черно-белая), используем красный канал как маску
	float crack_mask = tex_color.a * tex_color.r; 
	
	// 3. Анимация расширения (Круг открывается от центра)
	// smoothstep делает край мягким
	float growth_mask = 1.0 - smoothstep(progress, progress + 0.1, dist);
	
	// 4. Убираем жесткий центр (чтобы не было квадрата в середине, если текстура обрезана)
	// И делаем затухание к краям меша
	float circle_fade = 1.0 - smoothstep(0.8, 1.0, dist);
	
	// 5. Итоговая маска формы
	float final_shape = crack_mask * growth_mask * circle_fade;
	
	// 6. Цвет (Градиент от центра к краям)
	vec3 final_color = mix(color_inner.rgb, color_outer.rgb, dist);
	
	// 7. Выход
	ALBEDO = final_color * emission_strength; // Умножаем на силу для Glow эффекта
	ALPHA = final_shape * (1.0 - dissolve);
}