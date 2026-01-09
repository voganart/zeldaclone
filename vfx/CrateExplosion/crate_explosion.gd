extends Node3D

@export_group("Explosion Settings")
@export var explosion_force: float = 5.0
@export var lifetime: float = 4.0
@export var fade_duration: float = 1.0

@export_group("Physics")
@export_flags_3d_physics var debris_layer: int = 1 
@export_flags_3d_physics var debris_mask: int = 7 

func _ready() -> void:
	var angles = [0.0, 90.0, 180.0, 270.0]
	rotate_y(deg_to_rad(angles.pick_random()))

	_play_all_particles(self)
	call_deferred("_convert_to_physics")

func _play_all_particles(node: Node) -> void:
	if node is GPUParticles3D or node is CPUParticles3D:
		node.emitting = true
		node.restart()
	for child in node.get_children():
		_play_all_particles(child)

func _convert_to_physics() -> void:
	var meshes = _get_all_meshes(self)
	if meshes.is_empty(): return
	
	var active_shards: Array[RigidBody3D] = []

	for mesh_node in meshes:
		# Сохраняем оригинальные данные трансформации
		var original_transform = mesh_node.transform
		var original_scale = original_transform.basis.get_scale()
		
		# --- ЛЕЧЕНИЕ МАСШТАБА ДЛЯ ВИЗУАЛА ---
		# Если масштаб где-то 0, делаем его минимальным, чтобы было видно и можно было посчитать коллизию
		if abs(original_scale.x) < 0.01: original_scale.x = 0.05
		if abs(original_scale.y) < 0.01: original_scale.y = 0.05
		if abs(original_scale.z) < 0.01: original_scale.z = 0.05
		# ------------------------------------

		# 1. Создаем RigidBody
		var rb = RigidBody3D.new()
		rb.name = mesh_node.name + "_RB"
		mesh_node.get_parent().add_child(rb)
		
		# --- ФИКС ОШИБКИ JOLT (БЕТОННЫЙ МЕТОД) ---
		# Мы НЕ копируем transform напрямую. Мы строим его заново.
		# RigidBody всегда будет иметь Scale (1, 1, 1).
		
		var clean_basis = Basis() # По умолчанию Identity (без вращения, масштаб 1)
		
		# Пытаемся сохранить вращение, только если матрица не вырождена
		if not is_zero_approx(original_transform.basis.determinant()):
			# orthonormalized() убирает масштаб, оставляя чистое вращение
			clean_basis = original_transform.basis.orthonormalized()
		
		# Присваиваем чистый трансформ (вращение + позиция, масштаб строго 1)
		rb.transform = Transform3D(clean_basis, original_transform.origin)
		# -----------------------------------------
		
		# 2. Настройки физики
		rb.collision_layer = debris_layer
		rb.collision_mask = debris_mask
		rb.mass = 2.0 
		if rb.physics_material_override == null:
			var phys_mat = PhysicsMaterial.new()
			phys_mat.friction = 0.6
			phys_mat.bounce = 0.3
			rb.physics_material_override = phys_mat
		
		# 3. Создаем Коллизию (BoxShape) с учетом реального масштаба
		var col = CollisionShape3D.new()
		if mesh_node.mesh:
			var aabb = mesh_node.mesh.get_aabb()
			
			# Еще одна защита от нулевого AABB
			if aabb.size.length_squared() < 0.0001:
				rb.queue_free()
				continue
				
			var box_shape = BoxShape3D.new()
			# Применяем масштаб осколка к размеру коробки
			box_shape.size = aabb.size * original_scale
			col.shape = box_shape
			# Смещение тоже нужно масштабировать и вращать (если оно было), 
			# но для AABB center обычно достаточно просто умножить на scale, если pivot в центре.
			# Для простоты умножаем смещение центра на масштаб.
			col.position = aabb.get_center() * original_scale
			
		rb.add_child(col)
		
		# 4. Перенос меша
		mesh_node.reparent(rb)
		# Меш внутри RB должен иметь тот масштаб, который мы "вылечили", 
		# так как у самого RB масштаб (1,1,1).
		mesh_node.transform = Transform3D.IDENTITY
		mesh_node.scale = original_scale 
		
		active_shards.append(rb)
		
		# 5. Импульс
		var random_dir = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.2, 1.5), 
			randf_range(-1.0, 1.0)
		).normalized()
		
		var torque_offset = Vector3(randf(), randf(), randf()) * 0.2
		rb.apply_impulse(random_dir * explosion_force, torque_offset)

	await get_tree().create_timer(lifetime).timeout
	_fade_out(active_shards)

func _get_all_meshes(node: Node, result: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_get_all_meshes(child, result)
	return result

func _fade_out(shards: Array[RigidBody3D]) -> void:
	if not is_inside_tree(): return
	var tween = create_tween()
	tween.set_parallel(true)
	
	for shard in shards:
		if is_instance_valid(shard):
			shard.collision_layer = 0
			shard.collision_mask = 0
			# Уменьшаем меш внутри, так красивее
			var mesh = shard.get_child(1) if shard.get_child_count() > 1 else null
			var target = shard
			if mesh is MeshInstance3D: target = mesh
			
			tween.tween_property(target, "scale", Vector3.ZERO, fade_duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tween.finished
	queue_free()
