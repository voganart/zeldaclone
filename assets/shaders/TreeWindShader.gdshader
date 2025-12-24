shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, alpha_to_coverage;

// --- Текстуры ---
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 color_tint : source_color = vec4(1.0);

// --- Листва ---
group_uniforms Foliage;
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap;
uniform vec3 leaf_shadow_color : source_color = vec3(0.05, 0.1, 0.05); // Сделай потемнее по умолчанию
instance uniform bool use_alpha_scissor = true;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

// --- Прозрачность ---
instance uniform float dither_opacity : hint_range(0.0, 1.0) = 1.0;

// --- Стилизация ---
group_uniforms Stylized;
uniform float normal_merge_strength : hint_range(0.0, 1.0) = 0.8;
uniform float transmission_strength : hint_range(0.0, 5.0) = 0.5;
uniform float shadow_softness : hint_range(0.0, 1.0) = 0.5;

// --- Градиент Высоты и Объема ---
group_uniforms Color_Gradient;
uniform float gradient_height_min : hint_range(0.0, 1.0) = 0.0;
uniform float gradient_height_max : hint_range(0.0, 1.0) = 1.0;

// --- Сферический Градиент ---
group_uniforms Spherical_Gradient;
uniform vec3 spherical_center_color : source_color = vec3(0.05, 0.2, 0.05); // Темный центр
uniform vec3 spherical_outer_color : source_color = vec3(0.2, 0.8, 0.2); // Светлые края
uniform float spherical_radius : hint_range(0.0, 20.0) = 5.0; // Радиус сферы
uniform vec3 spherical_center_offset = vec3(0.0, 3.0, 0.0); // Смещение центра сферы (вверх по Y)
uniform float spherical_gradient_strength : hint_range(0.0, 1.0) = 0.0; // Сила эффекта

// --- Ветер ---
group_uniforms Wind;
uniform float wind_speed = 1.0;
uniform float wind_strength = 0.3;
uniform float wind_detail = 1.0;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.5);

varying float v_leaf_mask;
varying float v_gradient_mix; // Итоговый коэффициент смешивания для вертикального градиента
varying float v_spherical_ratio; // Коэффициент для сферического градиента

const float dither_matrix[16] = float[](
	0.0625, 0.5625, 0.1875, 0.6875,
	0.8125, 0.3125, 0.9375, 0.4375,
	0.2500, 0.7500, 0.1250, 0.6250,
	1.0000, 0.5000, 0.8750, 0.3750
);

void vertex() {
	// 1. Ветер (старый код)
	float influence = 1.0 - UV.y;
	influence = pow(clamp(influence, 0.0, 1.0), 2.0);
	v_leaf_mask = 1.0;

	// 2. Читаем запеченные данные
	// COLOR.a = Высота (0=Низ, 1=Верх)
	// COLOR.r = Рандомная "Глубина" (0.3=Темный, 1.0=Светлый)
	float height_data = COLOR.a;
	float random_depth = COLOR.r;

	// Если это старый меш без Vertex Color, то COLOR будет (1,1,1,1),
	// значит random_depth=1 (светлый), height=1 (верх). Все ок.

	// 3. Вычисляем градиент высоты с учетом настроек
	float height_factor = smoothstep(gradient_height_min, gradient_height_max, height_data);

	// 4. Комбинируем высоту и рандомную глубину
	// Умножаем одно на другое.
	// Если листик "глубоко" (random_depth низкий), он будет темным даже наверху.
	v_gradient_mix = clamp(height_factor * random_depth, 0.0, 1.0);

	// 5. Расчет сферического градиента (до применения ветра, чтобы градиент был стабилен)
	float dist_to_center = distance(VERTEX, spherical_center_offset);
	v_spherical_ratio = clamp(dist_to_center / max(spherical_radius, 0.001), 0.0, 1.0);

	// Нормали
	vec3 world_up_local = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	world_up_local = normalize(world_up_local);
	NORMAL = normalize(mix(NORMAL, world_up_local, normal_merge_strength));

	// Применяем ветер
	if (influence > 0.01) {
		float time = TIME * wind_speed;
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float wind_wave = sin(time + world_pos.x * wind_detail + world_pos.z * wind_detail);
		float flutter = sin(time * 8.0 + world_pos.y * 10.0) * 0.05;
		vec3 displacement = wind_direction * (wind_wave + flutter) * influence * wind_strength;
		VERTEX += displacement;
	}
}

void fragment() {
	if (dither_opacity < 0.99) {
		int x = int(FRAGCOORD.x) % 4;
		int y = int(FRAGCOORD.y) % 4;
		int index = x + y * 4;
		if (dither_opacity < dither_matrix[index]) discard;
	}

	if (v_leaf_mask > 0.5) {
		vec4 leaf_tex = texture(leaf_texture, UV);
		if (use_alpha_scissor && leaf_tex.a < alpha_scissor) discard;

		vec3 base_color = texture(albedo_texture, UV).rgb;

		// 1. Смешиваем цвет тени и базовый цвет на основе вертикального градиента
		vec3 vertical_grad_color = mix(leaf_shadow_color, base_color, v_gradient_mix);

		// 2. Вычисляем цвет сферического градиента
		vec3 sphere_gradient_color = mix(spherical_center_color, spherical_outer_color, v_spherical_ratio);
		// Чтобы сферический градиент не затирал текстуру листьев полностью, умножаем его на базу
		vec3 sphere_applied_color = sphere_gradient_color * base_color;

		// 3. Итоговое смешивание двух градиентов
		vec3 final_color = mix(vertical_grad_color, sphere_applied_color, spherical_gradient_strength);

		ALBEDO = final_color * color_tint.rgb;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		BACKLIGHT = final_color * transmission_strength;

		if (!FRONT_FACING) NORMAL = -NORMAL;
	} else {
		vec4 trunk_col = texture(albedo_texture, UV);
		ALBEDO = trunk_col.rgb * color_tint.rgb;
		ROUGHNESS = 0.8;
	}
}

void light() {
	// 1. Диффузное освещение (Lambert)
	// Используем max(0.0, ...), чтобы свет не уходил в минус на обратной стороне
	float NdotL = max(0.0, dot(NORMAL, LIGHT));

	// 2. Затухание и Тени
	// ATTENUATION уже содержит информацию о том, закрыт ли пиксель тенью,
	// и как далеко он от источника света.
	float light_intensity = NdotL * ATTENUATION;

	// 3. Стилизация теней (Shadow Softness)
	// Если мы хотим, чтобы тени были не черными, а цветными/светлыми,
	// нам нужно хитро смешать это. Но для точечных источников (сундук)
	// лучше использовать честный ATTENUATION, иначе свет будет просвечивать сквозь стены.

	// Если очень хочется подсветить тени (stylized look), раскомментируйте строку ниже,
	// но это может вернуть проблему "света сквозь стены":
	// light_intensity = mix(light_intensity, NdotL, shadow_softness * 0.5);

	// 4. Итоговый цвет
	vec3 light_contribution = light_intensity * LIGHT_COLOR * ALBEDO;

	DIFFUSE_LIGHT += light_contribution;
}