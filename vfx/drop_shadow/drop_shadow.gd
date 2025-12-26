extends RayCast3D

@onready var decal: Decal = $Decal

@export_group("Settings")
@export var min_scale: float = 0.8
@export var max_scale: float = 1.2
@export var max_distance: float = 10.0
@export var shadow_color: Color = Color(0, 0, 0, 0.6)

@export_group("Fade Settings")
# Дистанция луча, которую считаем "полом".
# Если RayCast висит на высоте 0.5м, ставь сюда 0.6.
@export var ground_cutoff: float = 0.6 

# На сколько метров растянуть плавное появление после отрыва от пола.
@export var fade_in_range: float = 1.0 

func _ready():
	if get_parent() is CollisionObject3D:
		add_exception(get_parent())
	
	decal.top_level = true
	# Применяем цвет сразу, чтобы в редакторе не путаться
	if shadow_color == null: shadow_color = Color(0,0,0,0.6)
	decal.modulate = shadow_color

func _process(_delta):
	force_raycast_update()
	
	if is_colliding():
		var hit_point = get_collision_point()
		var dist = global_position.distance_to(hit_point)
		
		# 1. ЛОГИКА ПОЛА (Ground Cutoff)
		# Если дистанция меньше пороговой — мы на полу, скрываем тень.
		if dist <= ground_cutoff:
			decal.visible = false
			return
		
		# Если мы выше порога — включаем
		decal.visible = true
		decal.global_position = hit_point
		
		# 2. ПЛАВНОЕ ПОЯВЛЕНИЕ (Fade In)
		# Считаем, насколько мы выше "пола"
		var height_above_ground = dist - ground_cutoff
		
		# 0.0 -> мы только оторвались (прозрачно)
		# 1.0 -> мы поднялись на fade_in_range метров (полная яркость)
		var fade_in_alpha = clamp(height_above_ground / fade_in_range, 0.0, 1.0)
		
		# 3. ПЛАВНОЕ ИСЧЕЗНОВЕНИЕ НА ВЫСОТЕ (Fade Out)
		# Стандартная логика: чем выше, тем прозрачнее
		var height_ratio = clamp(dist / max_distance, 0.0, 1.0)
		var fade_out_alpha = lerp(1.0, 0.0, height_ratio)
		
		# 4. ИТОГОВАЯ ПРОЗРАЧНОСТЬ
		# Комбинируем: (Настройки) * (Появление) * (Исчезновение)
		var final_alpha = shadow_color.a * fade_in_alpha * fade_out_alpha
		
		# Применяем
		decal.modulate = Color(shadow_color.r, shadow_color.g, shadow_color.b, final_alpha)
		
		# Масштаб (опционально)
		var target_scale = lerp(max_scale, min_scale, height_ratio)
		decal.scale = Vector3(target_scale, 2.0, target_scale)
		
	else:
		decal.visible = false
