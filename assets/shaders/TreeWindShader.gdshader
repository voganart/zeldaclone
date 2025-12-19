shader_type spatial;
// alpha_to_coverage для мягких краев листвы (нужен MSAA)
render_mode depth_draw_opaque, cull_disabled, alpha_to_coverage;

// --- Текстуры ---
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 color_tint : source_color = vec4(1.0);

// --- Листва ---
group_uniforms Foliage;
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap;
uniform vec3 leaf_shadow_color : source_color = vec3(0.1, 0.2, 0.1); 
instance uniform bool use_alpha_scissor = true;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

// --- Прозрачность при перекрытии (Dither) ---
instance uniform float dither_opacity : hint_range(0.0, 1.0) = 1.0;

// --- Стилизация ---
group_uniforms Stylized;
uniform float normal_merge_strength : hint_range(0.0, 1.0) = 0.8;
uniform float transmission_strength : hint_range(0.0, 5.0) = 0.5; 
uniform float shadow_softness : hint_range(0.0, 1.0) = 0.5; 

// --- Градиент Высоты ---
group_uniforms Color_Gradient;
uniform float gradient_height_min = 0.0;
uniform float gradient_height_max = 5.0;

// --- Ветер ---
group_uniforms Wind;
uniform float wind_speed = 1.0;
uniform float wind_strength = 0.3;
uniform float wind_detail = 1.0; 
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.5);

varying float v_leaf_mask;
varying float v_vertical_gradient;

// Матрица Байера 4x4 для красивого дизеринга
const float dither_matrix[16] = float[](
	0.0625, 0.5625, 0.1875, 0.6875,
	0.8125, 0.3125, 0.9375, 0.4375,
	0.2500, 0.7500, 0.1250, 0.6250,
	1.0000, 0.5000, 0.8750, 0.3750
);

void vertex() {
	float influence = COLOR.r;
	v_leaf_mask = influence;
	
	// --- ФИКС НОРМАЛЕЙ И ГРАДИЕНТ ---
	if (influence > 0.5) {
		float height_factor = (VERTEX.y - gradient_height_min) / (gradient_height_max - gradient_height_min);
		v_vertical_gradient = clamp(height_factor, 0.0, 1.0);
		
		vec3 world_up_local = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
		world_up_local = normalize(world_up_local);
		NORMAL = normalize(mix(NORMAL, world_up_local, normal_merge_strength));
	}
	
	// --- ВЕТЕР ---
	if (influence > 0.1) {
		float time = TIME * wind_speed;
		vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float wind_wave = sin(time + world_pos.x * wind_detail + world_pos.z * wind_detail);
		float flutter = sin(time * 8.0 + world_pos.y * 10.0) * 0.05 * influence;
		
		vec3 displacement = wind_direction * (wind_wave + flutter) * influence * wind_strength;
		VERTEX += displacement;
	}
}

void fragment() {
	// --- DITHER FADE (Прозрачность "сеткой") ---
	if (dither_opacity < 0.99) {
		// Получаем индекс пикселя на экране (0..3)
		int x = int(FRAGCOORD.x) % 4;
		int y = int(FRAGCOORD.y) % 4;
		int index = x + y * 4;
		
		// Если прозрачность меньше порогового значения из матрицы - выбрасываем пиксель
		if (dither_opacity < dither_matrix[index]) {
			discard;
		}
	}

	if (v_leaf_mask > 0.5) {
		// === ЛИСТВА ===
		vec4 leaf_tex = texture(leaf_texture, UV);
		
		if (use_alpha_scissor) {
			if (leaf_tex.a < alpha_scissor) {
				discard;
			}
		}
		
		vec3 base_color = texture(albedo_texture, UV).rgb;
		vec3 final_color = mix(leaf_shadow_color, base_color, v_vertical_gradient);
		
		ALBEDO = final_color * color_tint.rgb;
		ROUGHNESS = 1.0; 
		SPECULAR = 0.0;
		BACKLIGHT = final_color * transmission_strength;
		
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
		
	} else {
		// === СТВОЛ ===
		vec4 trunk_col = texture(albedo_texture, UV);
		ALBEDO = trunk_col.rgb * color_tint.rgb;
		ROUGHNESS = 0.8;
	}
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float diffuse = clamp(NdotL, 0.0, 1.0);
	float shadow = clamp(ATTENUATION, shadow_softness, 1.0);
	DIFFUSE_LIGHT += clamp((diffuse * shadow) * LIGHT_COLOR * ALBEDO, 0.0, 1.0);
}