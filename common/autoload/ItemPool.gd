extends Node

@export var item_scenes: Array[PackedScene] = []
@export var pool_size_per_item: int = 10
@export var auto_expand: bool = true

# Массив очередей для каждого типа предмета
var queues: Array = []

func _ready():
	add_to_group("item_pool")
	
	# Инициализируем пулы
	for scene in item_scenes:
		var queue = []
		if scene:
			for i in range(pool_size_per_item):
				queue.append(_create_instance(scene))
		queues.append(queue)

func _create_instance(scene: PackedScene):
	var inst = scene.instantiate()
	inst.visible = false
	# Отключаем физику, чтобы объекты не падали в бездну пока они в пуле
	inst.process_mode = Node.PROCESS_MODE_DISABLED 
	add_child(inst)
	return inst

## Спавнит предмет по ИНДЕКСУ из массива item_scenes
func spawn_item(index: int, pos: Vector3) -> RigidBody3D:
	if index < 0 or index >= queues.size():
		push_warning("ItemPool: Invalid index %d" % index)
		return null
		
	var queue = queues[index]
	var item: RigidBody3D
	
	if queue.is_empty():
		if auto_expand:
			item = _create_instance(item_scenes[index])
		else:
			return null
	else:
		item = queue.pop_front()
	
	# Активация
	item.get_parent().remove_child(item)
	get_tree().current_scene.add_child(item) # Переносим в мир
	
	item.global_position = pos
	item.rotation = Vector3.ZERO
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	item.visible = true
	item.process_mode = Node.PROCESS_MODE_INHERIT
	if item.has_method("reset_state"):
		item.reset_state()
	# Сброс физики (важно для RigidBody!)
	# Мы просто надеемся, что позиция применится, но для гарантии можно использовать PhysicsServer
	# item.global_transform.origin = pos (сделано выше)
	
	return item

## Возвращает предмет обратно в пул
func return_item(item: RigidBody3D, index: int):
	# Вызываем внутреннюю логику отложенно, чтобы выйти из физического шага
	call_deferred("_return_item_deferred", item, index)

# Внутренняя функция, которая выполнится в безопасное время (в конце кадра)
func _return_item_deferred(item: RigidBody3D, index: int):
	# Проверка на случай, если предмет удалили до вызова
	if not is_instance_valid(item): return

	# 1. Останавливаем твины
	var tween = item.create_tween()
	if tween: tween.kill()
	
	# 2. Скрываем и отключаем
	item.visible = false
	item.process_mode = Node.PROCESS_MODE_DISABLED
	
	# 3. Переносим в дерево пула (Безопасно, так как мы в deferred вызове)
	if item.get_parent():
		item.get_parent().remove_child(item)
	add_child(item) 
	
	# 4. Возвращаем в очередь
	if index >= 0 and index < queues.size():
		queues[index].append(item)
	else:
		item.queue_free()
