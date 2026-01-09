shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// --- ЦВЕТ ---
uniform vec4 barrier_color : source_color = vec4(1.0, 0.3, 0.1, 1.0);
uniform float emission_strength : hint_range(1.0, 10.0) = 2.0;

// --- ШУМ (World Space) ---
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform float noise_scale : hint_range(0.01, 1.0) = 0.2;
uniform float speed : hint_range(0.0, 5.0) = 1.0;

// --- ГРАДИЕНТЫ ---
uniform bool flip_vertical = false; // Перевернуть, если верх с низом перепутаны

// 1. Общий градиент (влияет на всю высоту стены)
uniform float gradient_power : hint_range(0.1, 10.0) = 1.0; 

// 2. Мягкое исчезновение верха (влияет только на верхушку)
uniform float top_softness : hint_range(0.0, 1.0) = 0.2; // 0.2 = последние 20% стены плавно исчезают

// 3. Твердость основания
uniform float base_solidity : hint_range(0.0, 1.0) = 0.5; // Скрывает шум у самого пола

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// --- ШУМ ---
	vec2 noise_uv = vec2(world_pos.x + world_pos.z, world_pos.y);
	vec2 uv_anim = noise_uv * noise_scale;
	uv_anim.y -= TIME * speed * noise_scale;
	float noise = texture(noise_texture, uv_anim).r;
	
	// --- ВЕРТИКАЛЬНАЯ ОСЬ ---
	float y = UV.y;
	if (flip_vertical) {
		y = 1.0 - y;
	}
	
	// --- ГРАДИЕНТЫ ---
	
	// 1. Основной градиент (Снизу вверх)
	// (1.0 - y) означает: внизу 1, вверху 0.
	float main_gradient = pow(max(1.0 - y, 0.0), gradient_power);
	
	// 2. Дополнительное мягкое затухание у самого края (Top Softness)
	// smoothstep(край, начало_затухания, y)
	// Это гарантирует, что в самом верху (y=1.0) альфа будет точно 0.0
	float top_fade = 1.0 - smoothstep(1.0 - top_softness, 1.0, y);
	
	// Комбинируем градиенты
	float final_mask = main_gradient * top_fade;
	
	// --- СМЕШИВАНИЕ С ШУМОМ ---
	// Чем ниже (ближе к полу), тем меньше шума (больше сплошного цвета)
	// Чем выше, тем больше "дырок" от шума
	float solidity_mask = final_mask * base_solidity;
	float final_alpha = mix(noise, 1.0, solidity_mask);
	
	// Применяем маску прозрачности к результату
	final_alpha *= final_mask;
	
	// --- ВЫВОД ---
	ALBEDO = barrier_color.rgb * emission_strength;
	ALPHA = clamp(final_alpha * barrier_color.a, 0.0, 1.0);
}