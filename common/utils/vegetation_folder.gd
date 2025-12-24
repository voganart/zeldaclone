@tool
extends Node3D

@export_category("Randomizer Settings")
@export var random_rotation_y: bool = true
@export var scale_min: float = 0.8
@export var scale_max: float = 1.2
@export var align_to_ground: bool = true ## Пытаться опустить на землю (RayCast)

@export_category("Actions")
@export var apply_randomize: bool = false:
	set(value):
		if value:
			_randomize_children()
		apply_randomize = false

@export var drop_to_ground: bool = false:
	set(value):
		if value:
			_drop_children()
		drop_to_ground = false

func _randomize_children():
	print("Randomizing ", get_child_count(), " vegetation items...")
	
	for child in get_children():
		if not (child is Node3D): continue
		
		# 1. Случайный поворот по Y
		if random_rotation_y:
			child.rotation.y = randf() * TAU
		
		# 2. Случайный скейл
		var s = randf_range(scale_min, scale_max)
		child.scale = Vector3(s, s, s)
		
		# 3. Небольшой наклон для живости (опционально)
		child.rotation.x = randf_range(-0.1, 0.1)
		child.rotation.z = randf_range(-0.1, 0.1)

func _drop_children():
	print("Dropping items to ground...")
	var space_state = get_world_3d().direct_space_state
	
	for child in get_children():
		if not (child is Node3D): continue
		
		# Пускаем луч сверху вниз с позиции объекта
		var from = child.global_position + Vector3(0, 5.0, 0)
		var to = child.global_position + Vector3(0, -10.0, 0)
		
		var query = PhysicsRayQueryParameters3D.create(from, to)
		# Исключаем сам объект (и его детей), чтобы не попасть в свою коллизию
		# Для этого нужно собрать RID всех коллизий ребенка, но для простоты
		# просто выключаем маску коллизии ребенка на секунду (сложно в туле).
		# Проще: Ищем коллизию только с World (слой 1)
		query.collision_mask = 1 # Убедись, что земля на 1 слое
		
		var result = space_state.intersect_ray(query)
		
		if result:
			child.global_position = result.position
			
			# Ориентация по нормали (если хочешь чтобы росли перпендикулярно склону)
			# var up = result.normal
			# var current_fwd = -child.global_transform.basis.z
			# child.look_at(child.global_position - result.normal, current_fwd)
