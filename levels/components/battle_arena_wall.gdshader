shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// --- ЦВЕТ ---
uniform vec4 barrier_color : source_color = vec4(1.0, 0.3, 0.1, 1.0);
uniform float emission_strength : hint_range(1.0, 10.0) = 2.0;

// --- ШУМ (World Space) ---
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
uniform float noise_scale : hint_range(0.01, 1.0) = 0.2;
uniform float speed : hint_range(0.0, 5.0) = 1.0;

// --- ГРАДИЕНТ (МАСКА) ---
uniform bool flip_vertical = false; // <-- НАЖМИ ЭТО, если градиент перевернут!
uniform float gradient_power : hint_range(0.1, 10.0) = 2.0; // Насколько резко исчезает к верху
uniform float top_cutoff : hint_range(0.0, 1.0) = 0.0; // Жестко обрезать самый верх

// --- ТВЕРДОЕ ОСНОВАНИЕ ---
uniform float base_solidity : hint_range(0.0, 1.0) = 0.5; // 0 = везде шум, 1 = у пола стена сплошная (без дыр)

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 1. Шум в мировых координатах
	vec2 noise_uv = vec2(world_pos.x + world_pos.z, world_pos.y);
	vec2 uv_anim = noise_uv * noise_scale;
	uv_anim.y -= TIME * speed * noise_scale;
	float noise = texture(noise_texture, uv_anim).r;
	
	// 2. Расчет вертикального градиента
	float y = UV.y;
	if (flip_vertical) {
		y = 1.0 - y;
	}
	
	// Мы хотим, чтобы y=0 (низ) было 1.0 (видимо), а y=1 (верх) было 0.0 (невидимо)
	// Если у тебя CSGPolygon нарисован стандартно, то UV.y растет снизу вверх.
	// Значит, нам нужно инвертировать значение для маски прозрачности.
	float fade_mask = 1.0 - y; 
	
	// 3. Жесткая обрезка верха (чтобы точно не было артефактов)
	if (y > (1.0 - top_cutoff)) {
		fade_mask = 0.0;
	}
	
	// Применяем кривую силы градиента
	fade_mask = pow(max(fade_mask, 0.0), gradient_power);
	
	// 4. Смешивание шума и сплошного цвета
	// У земли (где fade_mask близка к 1) мы делаем стену более плотной, игнорируя шум
	float final_alpha_map = mix(noise, 1.0, fade_mask * base_solidity);
	
	// 5. Итоговая маска: (Шум/Сплошное) * (Градиент затухания)
	final_alpha_map *= fade_mask;
	
	ALBEDO = barrier_color.rgb * emission_strength;
	ALPHA = final_alpha_map * barrier_color.a;
}