extends Node

@export var effect_scenes: Array[PackedScene] = []
@export var pool_size: int = 10
@export var auto_expand: bool = false
@export var effect_lifetime: float = 2.0 # Чуть увеличим время жизни на всякий случай

# Теперь это массив массивов! 
# Структура: [ [СписокКрови...], [СписокЩепок...] ]
var available_queues: Array = []

func _ready():
	add_to_group("vfx_pool")
	
	# Инициализируем очереди под каждый эффект отдельно
	for i in range(effect_scenes.size()):
		var queue = []
		var scene = effect_scenes[i]
		
		for j in pool_size:
			var inst = _create_instance(scene)
			queue.append(inst)
		
		# Добавляем очередь этого типа в главный список
		available_queues.append(queue)

func _create_instance(scene: PackedScene):
	var inst = scene.instantiate()
	inst.visible = false
	add_child(inst)
	return inst

func spawn_effect(effect_idx: int, position: Vector3, rotation: Vector3 = Vector3.ZERO):
	if effect_idx < 0 or effect_idx >= available_queues.size():
		return null
		
	var queue = available_queues[effect_idx]
	var effect
	
	if queue.is_empty():
		if auto_expand:
			effect = _create_instance(effect_scenes[effect_idx])
		else:
			return null
	else:
		effect = queue.pop_front()
		
	effect.global_position = position
	effect.global_rotation = rotation
	effect.scale = Vector3.ONE
	effect.visible = true
	
	if effect is Node3D:
		effect.force_update_transform()
		
	_enable_particles(effect)
	
	# !!! ДОБАВЛЕНО: Перезапуск анимации !!!
	_restart_animation(effect)
	# --------------------------------------
	
	_return_to_pool_later(effect, effect_idx)
	
	return effect

func _enable_particles(node):
	if node is GPUParticles3D or node is CPUParticles3D:
		node.emitting = false
		node.one_shot = true
		node.restart()
		node.emitting = true
	
	for child in node.get_children():
		_enable_particles(child)

func _stop_particles(node):
	if node is GPUParticles3D or node is CPUParticles3D:
		node.emitting = false
	for child in node.get_children():
		_stop_particles(child)

# Спавнит эффект и прикрепляет его к родителю (например, к игроку)
func spawn_attached_effect(effect_idx: int, parent: Node3D, local_offset: Vector3 = Vector3.ZERO):
	if effect_idx < 0 or effect_idx >= available_queues.size(): return null
	
	# ... (код получения effect из очереди такой же, как в spawn_effect) ...
	# Копипаст получения effect из очереди, или вынеси это в отд. функцию _get_from_queue
	var queue = available_queues[effect_idx]
	var effect
	if queue.is_empty():
		if auto_expand: effect = _create_instance(effect_scenes[effect_idx])
		else: return null
	else: effect = queue.pop_front()
	
	# --- ОТЛИЧИЕ ТУТ ---
	# Меняем родителя на игрока!
	if effect.get_parent():
		effect.get_parent().remove_child(effect)
	parent.add_child(effect)
	
	effect.position = local_offset # Локальная позиция относительно игрока
	effect.rotation = Vector3.ZERO
	effect.visible = true
	
	_enable_particles(effect)
	_restart_animation(effect)
	
	# Возвращаем в пул (но сначала отцепляем от игрока!)
	_return_to_pool_later(effect, effect_idx, true) # true = нужно отцепить
	
	return effect

# Обнови функцию возврата
func _return_to_pool_later(effect, effect_idx: int, attached: bool = false):
	var tween = create_tween()
	tween.tween_interval(effect_lifetime)
	tween.tween_callback(func():
		effect.visible = false
		_stop_particles(effect)
		
		# Если был прикреплен - возвращаем обратно в VfxPool как ребенка
		if attached:
			effect.get_parent().remove_child(effect)
			add_child(effect)
		
		effect.global_position = Vector3(0, -1000, 0)
		
		if effect_idx < available_queues.size():
			available_queues[effect_idx].append(effect)
		else:
			effect.queue_free()
	)
func _restart_animation(node):
	# Ищем AnimationPlayer прямо в корне эффекта
	var anim = node.get_node_or_null("AnimationPlayer")
	if anim:
		anim.stop()
		
		# Пытаемся найти анимацию по умолчанию
		var anim_name = ""
		if anim.has_animation("play"): # Обычно называют "play"
			anim_name = "play"
		elif anim.has_animation("default"):
			anim_name = "default"
		elif anim.get_animation_list().size() > 0:
			# Если не нашли стандартных имен, берем первую попавшуюся
			anim_name = anim.get_animation_list()[0]
			
		if anim_name != "":
			anim.play(anim_name)
			# ВАЖНО: seek(0, true) заставляет шейдер обновиться МГНОВЕННО, 
			# иначе 1 кадр будет виден старый результат
			anim.seek(0.0, true)
