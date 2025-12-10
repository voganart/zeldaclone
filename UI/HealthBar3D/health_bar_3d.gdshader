shader_type spatial;
render_mode unshaded, blend_mix;

uniform bool use_billboard = true;

uniform vec4 fg_color : source_color = vec4(0.0, 1.0, 0.0, 1.0); // текущее HP
uniform vec4 dmg_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // задержанная часть
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0); // пустая зона

instance uniform float health : hint_range(0.0, 1.0) = 1.0;
instance uniform float delayed_health : hint_range(0.0, 1.0) = 1.0; // новая переменная

instance uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	if (use_billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0],
			INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]
		);
	}
}

void fragment() {
	vec4 color;

	if (UV.x < health) {
		color = fg_color; // зелёная часть
	}
	else if (UV.x < delayed_health) {
		color = dmg_color; // красная задержка
	}
	else {
		color = bg_color; // пустая область
	}

	ALBEDO = color.rgb;
	ALPHA = color.a * opacity;
}
