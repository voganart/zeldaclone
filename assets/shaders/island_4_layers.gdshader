shader_type spatial;
// Включаем Vertex Color как данные для альбедо (нужно для некоторых плагинов)
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float uv_scale = 0.5;
uniform float blend_softness : hint_range(0.0, 1.0) = 0.2; // Мягкость кисти

// --- МАТЕРИАЛ 0 (БАЗА - Черный цвет) ---
group_uniforms Mat0_Base;
uniform sampler2D tex_0_albedo : source_color;
uniform sampler2D tex_0_normal : hint_normal;
uniform sampler2D tex_0_orm : hint_default_white;

// --- МАТЕРИАЛ 1 (КРАСНЫЙ КАНАЛ) ---
group_uniforms Mat1_Red;
uniform sampler2D tex_1_albedo : source_color;
uniform sampler2D tex_1_normal : hint_normal;
uniform sampler2D tex_1_orm : hint_default_white;

// --- МАТЕРИАЛ 2 (ЗЕЛЕНЫЙ КАНАЛ) ---
group_uniforms Mat2_Green;
uniform sampler2D tex_2_albedo : source_color;
uniform sampler2D tex_2_normal : hint_normal;
uniform sampler2D tex_2_orm : hint_default_white;

// --- МАТЕРИАЛ 3 (СИНИЙ КАНАЛ) ---
group_uniforms Mat3_Blue;
uniform sampler2D tex_3_albedo : source_color;
uniform sampler2D tex_3_normal : hint_normal;
uniform sampler2D tex_3_orm : hint_default_white;

varying vec4 v_color;

// Функция смешивания по высоте (Height Blend)
float blend_h(float h1, float h2, float mask) {
    float h_mix = mask;
    // Корректировка маски на основе высоты (из альфа-канала)
    // Чем больше blend_softness, тем мягче переход
    float hardness = 1.0 - blend_softness;
    float shift = h1 - h2;
    return smoothstep(0.5 - hardness * 0.5, 0.5 + hardness * 0.5, mask + shift);
}

void vertex() {
    v_color = COLOR; // Получаем цвет, который ты нарисовал кистью
}

void fragment() {
    vec2 uv = UV * uv_scale;

    // --- СЭМПЛИНГ БАЗЫ ---
    vec4 col0 = texture(tex_0_albedo, uv);
    vec3 nrm0 = texture(tex_0_normal, uv).rgb;
    vec3 orm0 = texture(tex_0_orm, uv).rgb;

    // --- СЭМПЛИНГ СЛОЯ 1 (Красный) ---
    vec4 col1 = texture(tex_1_albedo, uv);
    vec3 nrm1 = texture(tex_1_normal, uv).rgb;
    vec3 orm1 = texture(tex_1_orm, uv).rgb;
    
    // Смешиваем 0 и 1
    // Используем v_color.r как маску
    float weight1 = v_color.r; 
    // Если в альфе есть высота - используем height blend, иначе просто линейно
    // Упрощенный height blend для скорости:
    float mix1 = smoothstep(0.4, 0.6, weight1 + (col1.a - col0.a) * (1.0-blend_softness)); 
    
    vec3 final_col = mix(col0.rgb, col1.rgb, mix1);
    vec3 final_nrm = mix(nrm0, nrm1, mix1);
    vec3 final_orm = mix(orm0, orm1, mix1);
    float current_h = mix(col0.a, col1.a, mix1);

    // --- СЭМПЛИНГ СЛОЯ 2 (Зеленый) ---
    vec4 col2 = texture(tex_2_albedo, uv);
    vec3 nrm2 = texture(tex_2_normal, uv).rgb;
    vec3 orm2 = texture(tex_2_orm, uv).rgb;
    
    float weight2 = v_color.g;
    float mix2 = smoothstep(0.4, 0.6, weight2 + (col2.a - current_h) * (1.0-blend_softness));
    
    final_col = mix(final_col, col2.rgb, mix2);
    final_nrm = mix(final_nrm, nrm2, mix2);
    final_orm = mix(final_orm, orm2, mix2);
    current_h = mix(current_h, col2.a, mix2);
    
    // --- СЭМПЛИНГ СЛОЯ 3 (Синий) ---
    vec4 col3 = texture(tex_3_albedo, uv);
    vec3 nrm3 = texture(tex_3_normal, uv).rgb;
    vec3 orm3 = texture(tex_3_orm, uv).rgb;
    
    float weight3 = v_color.b;
    float mix3 = smoothstep(0.4, 0.6, weight3 + (col3.a - current_h) * (1.0-blend_softness));
    
    final_col = mix(final_col, col3.rgb, mix3);
    final_nrm = mix(final_nrm, nrm3, mix3);
    final_orm = mix(final_orm, orm3, mix3);

    // Вывод
    ALBEDO = final_col;
    NORMAL_MAP = final_nrm;
    AO = final_orm.r;
    ROUGHNESS = final_orm.g;
    METALLIC = final_orm.b;
}