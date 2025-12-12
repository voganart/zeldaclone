class_name EnemyHealthBar
extends Node3D

@export var fade_delay: float = 2.0
@export var fade_speed: float = 2.0

var health_mesh: MeshInstance3D
var target_health_pct: float = 1.0
var delayed_health_pct: float = 1.0
var current_opacity: float = 0.0
var visibility_timer: float = 0.0

func _ready() -> void:
	# Ищем меш внутри (предполагаем, что он ребенок этого узла)
	for child in get_children():
		if child is MeshInstance3D:
			health_mesh = child
			break
	
	# Скрываем при старте
	_update_shader_params(1.0, 1.0, 0.0)
	visible = false

func _process(delta: float) -> void:
	if not health_mesh or not visible:
		return

	# 1. Плавное движение "белой полоски" (отложенный урон)
	delayed_health_pct = move_toward(delayed_health_pct, target_health_pct, delta * 0.5)

	# 2. Логика исчезновения
	if visibility_timer > 0:
		visibility_timer -= delta
		current_opacity = move_toward(current_opacity, 1.0, delta * 5.0) # Быстрое появление
	else:
		current_opacity = move_toward(current_opacity, 0.0, delta * fade_speed) # Плавное исчезновение

	# 3. Применение параметров
	_update_shader_params(target_health_pct, delayed_health_pct, current_opacity)
	
	# Отключаем видимость полностью для экономии ресурсов
	if current_opacity <= 0 and visibility_timer <= 0:
		visible = false

## Публичный метод для обновления (вызывается из Enemy)
func update_health(current: float, max_hp: float) -> void:
	if max_hp <= 0: return
	
	target_health_pct = current / max_hp
	visibility_timer = fade_delay # Сбрасываем таймер исчезновения
	visible = true # Включаем обработку

func _update_shader_params(hp: float, delayed: float, opacity: float) -> void:
	if health_mesh:
		health_mesh.set_instance_shader_parameter(GameConstants.SHADER_PARAM_HEALTH, hp)
		health_mesh.set_instance_shader_parameter(GameConstants.SHADER_PARAM_DELAYED_HEALTH, delayed)
		health_mesh.set_instance_shader_parameter(GameConstants.SHADER_PARAM_OPACITY, opacity)
