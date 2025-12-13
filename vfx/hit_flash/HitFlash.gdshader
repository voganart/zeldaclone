shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

// !!! ВОТ ЗДЕСЬ ИЗМЕНЕНИЯ !!!
instance uniform vec4 hit_flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float hit_flash_strength : hint_range(0.0, 1.0) = 0.0;
// !!!!!!!!!!!!!!!!!!!!!!!!!!!

void fragment() {
    vec4 albedo_tex = texture(texture_albedo, UV);
    vec3 base_color = albedo.rgb * albedo_tex.rgb;
    
    // Смешиваем базовый цвет с цветом вспышки
    ALBEDO = mix(base_color, hit_flash_color.rgb, hit_flash_strength);
    ALPHA = albedo.a * albedo_tex.a;
}