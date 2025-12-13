extends Node

@export var mesh_path: NodePath
@export var flash_color: Color = Color(1, 1, 1) # Белая вспышка обычно выглядит сочнее
@export var flash_time := 0.15

var mesh_instance: MeshInstance3D

func _ready():
	mesh_instance = get_node(mesh_path)
	
	# Нам не нужно искать материал или назначать его.
	# Мы предполагаем, что на меше УЖЕ висит твой крутой шейдер.

func flash():
	if not mesh_instance:
		return

	# Сбрасываем предыдущий твин, если спамим ударами
	var tween = create_tween()
	
	# 1. Устанавливаем цвет вспышки для ЭТОГО конкретного монстра
	# Используем set_instance_shader_parameter
	mesh_instance.set_instance_shader_parameter("hit_flash_color", flash_color)
	
	# 2. Анимируем силу вспышки от 1.0 до 0.0
	# В шейдере мы поставили дефолт 0.0, поэтому вспышка исчезнет сама.
	tween.tween_method(
		func(val): mesh_instance.set_instance_shader_parameter("hit_flash_strength", val),
		1.0, # Начинаем с полной яркости
		0.0, # Уходим в ноль
		flash_time
	)
