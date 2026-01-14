shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;

// --- ТЕКСТУРА ---
uniform sampler2D noise_texture : source_color, filter_linear_mipmap;
uniform float softness : hint_range(0.0, 1.0) = 0.5;

// --- ЦВЕТА (Должны совпадать с Volumetric!) ---
uniform vec3 color_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 color_shadow : source_color = vec3(0.2, 0.3, 0.5);
uniform float absorption : hint_range(0.0, 10.0) = 3.0; // Сила затемнения в центре
uniform float density_multiplier : hint_range(0.0, 10.0) = 2.0;

// --- ДИСТАНЦИЯ ---
uniform float fade_distance : hint_range(0.0, 1000.0) = 150.0;
uniform float fade_margin : hint_range(0.0, 500.0) = 50.0;

varying float v_distance;

void vertex() {
	// Билбординг (поворот к камере)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	
	// Сохраняем скейл
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	float sz = length(MODEL_MATRIX[2].xyz);
	
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(sx, 0.0, 0.0, 0.0),
		vec4(0.0, sy, 0.0, 0.0),
		vec4(0.0, 0.0, sz, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
		
	v_distance = distance(CAMERA_POSITION_WORLD, (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
}

void fragment() {
	vec2 uv_centered = UV - 0.5;
	float dist_center = length(uv_centered) * 2.0;
	
	// Маска круга
	float circle = 1.0 - smoothstep(1.0 - softness, 1.0, dist_center);
	float noise = texture(noise_texture, UV).r;
	
	// Считаем плотность как в 3D (примерно)
	float density = circle * noise * density_multiplier;
	
	if (density < 0.05) discard;
	
	// --- ФЕЙКОВОЕ ОСВЕЩЕНИЕ ---
	// Используем ту же формулу Beer's Law, что и в 3D шейдере.
	// Чем плотнее пиксель, тем темнее он становится.
	float light_transmission = exp(-density * absorption);
	vec3 final_color = mix(color_shadow, color_light, light_transmission);
	
	// --- ФЕЙД ДИСТАНЦИИ ---
	// Билборд прозрачный вблизи, появляется вдали.
	float dist_alpha = smoothstep(fade_distance, fade_distance + fade_margin, v_distance);
	
	ALBEDO = final_color;
	ALPHA = clamp(density, 0.0, 1.0) * dist_alpha;
}