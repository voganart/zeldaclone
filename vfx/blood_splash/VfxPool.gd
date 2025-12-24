extends Node

@export var effect_scenes: Array[PackedScene] = []
# Эти переменные больше не используются в новой логике, но могут быть полезны для других целей
# @export var pool_size: int = 10
# @export var auto_expand: bool = true 
@export var effect_lifetime: float = 2.5 

func _ready():
	add_to_group("vfx_pool")

# Эта функция вызывается извне. Она НЕ асинхронная.
func spawn_effect(effect_idx: int, position: Vector3, rotation: Vector3 = Vector3.ZERO):
	if effect_idx < 0 or effect_idx >= effect_scenes.size() or not effect_scenes[effect_idx]:
		printerr("VfxPool: Invalid effect index or scene not set: ", effect_idx)
		return
	
	# Запускаем асинхронный процесс спавна, не блокируя вызывающий код
	_spawn_effect_internal(effect_idx, position, rotation, null, Vector3.ZERO)

# Эта функция тоже не асинхронная
func spawn_attached_effect(effect_idx: int, parent: Node3D, local_offset: Vector3 = Vector3.ZERO):
	if effect_idx < 0 or effect_idx >= effect_scenes.size() or not effect_scenes[effect_idx]:
		printerr("VfxPool: Invalid effect index or scene not set: ", effect_idx)
		return
	
	_spawn_effect_internal(effect_idx, Vector3.ZERO, Vector3.ZERO, parent, local_offset)

# --- НОВАЯ ОСНОВНАЯ ЛОГИКА (БЕЗ КЛЮЧЕВОГО СЛОВА `async`) ---
func _spawn_effect_internal(effect_idx: int, g_pos: Vector3, g_rot: Vector3, parent: Node3D, l_pos: Vector3):
	
	# 1. Инстанцируем НОВЫЙ, чистый эффект КАЖДЫЙ РАЗ
	var effect = effect_scenes[effect_idx].instantiate()
	
	# 2. Добавляем его в сцену
	if parent:
		parent.add_child(effect)
		effect.position = l_pos
		effect.rotation = g_rot # Вращение обычно локальное
	else:
		get_tree().current_scene.add_child(effect)
		effect.global_position = g_pos
		effect.global_rotation = g_rot

	# 3. Даем движку кадр на применение трансформации
	await get_tree().process_frame
	
	if not is_instance_valid(effect):
		return
		
	# 4. Запускаем частицы и анимации
	_enable_particles(effect)
	_restart_animation(effect)
	
	# 5. Устанавливаем таймер на самоуничтожение
	await get_tree().create_timer(effect_lifetime).timeout
	
	if is_instance_valid(effect):
		effect.queue_free()

# --- Вспомогательные функции ---

func _enable_particles(node):
	if node is GPUParticles3D or node is CPUParticles3D:
		node.one_shot = true
		node.emitting = true
	
	for child in node.get_children():
		_enable_particles(child)

func _restart_animation(node):
	var anim = node.get_node_or_null("AnimationPlayer")
	if anim:
		anim.stop()
		var anim_name = ""
		if anim.has_animation("play"):
			anim_name = "play"
		elif anim.has_animation("default"):
			anim_name = "default"
		elif anim.get_animation_list().size() > 0:
			anim_name = anim.get_animation_list()[0]
			
		if anim_name != "":
			anim.play(anim_name)
