extends Node

@export var item_scenes: Array[PackedScene] = []
@export var pool_size_per_item: int = 10
@export var auto_expand: bool = true

var queues: Array = []

func _ready():
	add_to_group("item_pool")
	for scene in item_scenes:
		var queue = []
		if scene:
			for i in range(pool_size_per_item):
				queue.append(_create_instance(scene))
		queues.append(queue)

func _create_instance(scene: PackedScene):
	var inst = scene.instantiate()
	inst.visible = false
	inst.process_mode = Node.PROCESS_MODE_DISABLED 
	
	# === ИСПРАВЛЕНИЕ ===
	# Мы НЕ должны обнулять слои здесь, потому что это происходит ДО того,
	# как BasePickup успеет сохранить свои дефолтные слои в _ready().
	# Достаточно просто "заморозить" объект.
	if inst is RigidBody3D:
		inst.freeze = true
	# ===================
			
	add_child(inst)
	return inst

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
	
	item.get_parent().remove_child(item)
	get_tree().current_scene.add_child(item) 
	
	item.global_position = pos
	item.rotation = Vector3.ZERO
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	item.visible = true
	item.process_mode = Node.PROCESS_MODE_INHERIT
	
	if item.has_method("reset_state"):
		item.reset_state()
	
	return item

func return_item(item: RigidBody3D, index: int):
	call_deferred("_return_item_deferred", item, index)

func _return_item_deferred(item: RigidBody3D, index: int):
	if not is_instance_valid(item): return

	var tween = item.create_tween()
	if tween: tween.kill()
	
	item.visible = false
	item.process_mode = Node.PROCESS_MODE_DISABLED
	
	# А вот здесь обнуление слоев и заморозка ОБЯЗАТЕЛЬНЫ,
	# чтобы "очистить" предмет перед возвращением в пул.
	item.freeze = true 
	item.collision_layer = 0 
	item.collision_mask = 0
	item.global_position = Vector3(0, -500, 0) 
	
	if item.get_parent():
		item.get_parent().remove_child(item)
	add_child(item) 
	
	if index >= 0 and index < queues.size():
		queues[index].append(item)
	else:
		item.queue_free()
