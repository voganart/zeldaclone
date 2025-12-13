extends Node

@export var effect_scenes: Array[PackedScene] = []
@export var pool_size: int = 10
@export var auto_expand: bool = false
@export var effect_lifetime: float = 1.0

var pool: Array = []
var available: Array = []

func _ready():
	add_to_group("vfx_pool")
	
	for scene in effect_scenes:
		for i in pool_size:
			var inst = scene.instantiate()
			inst.visible = false
			add_child(inst)
			pool.append(inst)
			available.append(inst)

func spawn_effect(effect_idx: int, position: Vector3, rotation: Vector3 = Vector3.ZERO):
	if available.size() == 0:
		if auto_expand and effect_scenes.size() > effect_idx:
			var inst = effect_scenes[effect_idx].instantiate()
			add_child(inst)
			pool.append(inst)
			available.append(inst)
		else:
			return null
			
	var effect = available.pop_front()
	
	# 1. Сначала ставим позицию и видимость
	effect.global_position = position
	effect.global_rotation = rotation
	effect.scale = Vector3.ONE # На всякий случай сбрасываем масштаб
	effect.visible = true
	
	# 2. !!! КРИТИЧЕСКИ ВАЖНО !!!
	# Ждем 1 кадр, чтобы движок применил новую позицию и видимость
	await get_tree().process_frame
	
	# 3. Теперь включаем частицы. Если эффект уже вернулся в пул (маловероятно), не включаем.
	if effect.visible: 
		_enable_particles(effect)
		_return_to_pool_later(effect)
	
	return effect

func _enable_particles(node):
	if node is GPUParticles3D or node is CPUParticles3D:
		node.emitting = false # Сброс
		node.one_shot = true
		node.restart()        # Полный перезапуск
		node.emitting = true  # Старт
	
	for child in node.get_children():
		_enable_particles(child)

func _return_to_pool_later(effect):
	var tween = effect.create_tween()
	tween.tween_interval(effect_lifetime)
	tween.tween_callback(func():
		effect.visible = false
		effect.global_position = Vector3(0, -1000, 0)
		_stop_particles(effect)
		available.append(effect)
	)

func _stop_particles(node):
	if node is GPUParticles3D or node is CPUParticles3D:
		node.emitting = false
	for child in node.get_children():
		_stop_particles(child)
