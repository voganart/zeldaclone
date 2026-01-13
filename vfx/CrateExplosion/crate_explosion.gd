extends Node3D

@export_group("Explosion Settings")
@export var explosion_impulse: float = 5.0 ## Сила разлета (скорость)
@export var explosion_spin: float = 2.0    ## Сила вращения (кручение)
@export var lifetime: float = 4.0
@export var fade_duration: float = 1.0

@export_group("Physics")
@export_flags_3d_physics var debris_layer: int = 1 
@export_flags_3d_physics var debris_mask: int = 7 

func _ready() -> void:
	# Случайный поворот всего эффекта
	var angles = [0.0, 90.0, 180.0, 270.0]
	rotate_y(deg_to_rad(angles.pick_random()))

	_play_all_particles(self)
	call_deferred("_convert_to_physics")

func _play_all_particles(node: Node) -> void:
	if node is GPUParticles3D or node is CPUParticles3D:
		# Фикс направления частиц: сбрасываем поворот в ноль, чтобы Z всегда был Z, а Y всегда Y
		node.global_rotation = Vector3.ZERO
		node.emitting = false
		node.emitting = true
		node.restart()
	
	for child in node.get_children():
		_play_all_particles(child)

func _convert_to_physics() -> void:
	# 1. Если сам эффект уже удален (например, при смене сцены), выходим
	if not is_inside_tree(): return 
	
	var meshes = _get_all_meshes(self)
	if meshes.is_empty(): return
	
	var active_shards: Array[RigidBody3D] = []

	for mesh_node in meshes:
		if not is_instance_valid(mesh_node): continue
		
		# 2. Проверяем родителя перед добавлением нового узла
		var parent_node = mesh_node.get_parent()
		if not parent_node or not parent_node.is_inside_tree(): continue

		var original_transform = mesh_node.transform
		var original_scale = original_transform.basis.get_scale()
		
		# Лечим масштаб
		var safe_scale = original_scale
		if abs(safe_scale.x) < 0.01: safe_scale.x = 0.05
		if abs(safe_scale.y) < 0.01: safe_scale.y = 0.05
		if abs(safe_scale.z) < 0.01: safe_scale.z = 0.05

		var rb = RigidBody3D.new()
		rb.name = mesh_node.name + "_RB"
		parent_node.add_child(rb) # Добавляем к родителю меша
		
		rb.top_level = true 

		var clean_basis = Basis() 
		if not is_zero_approx(original_transform.basis.determinant()):
			clean_basis = original_transform.basis.orthonormalized()
		
		rb.global_transform = Transform3D(clean_basis, mesh_node.global_transform.origin)
		
		rb.collision_layer = debris_layer
		rb.collision_mask = debris_mask
		rb.mass = 2.0 
		if rb.physics_material_override == null:
			var phys_mat = PhysicsMaterial.new()
			phys_mat.friction = 0.6
			phys_mat.bounce = 0.3
			rb.physics_material_override = phys_mat
		
		var col = CollisionShape3D.new()
		if mesh_node.mesh:
			var aabb = mesh_node.mesh.get_aabb()
			if aabb.size.length_squared() > 0.0001:
				var box_shape = BoxShape3D.new()
				box_shape.size = aabb.size * safe_scale
				col.shape = box_shape
				col.position = aabb.get_center() * safe_scale
			else:
				# Если меш пустой/битый, удаляем RB и пропускаем
				rb.queue_free()
				continue
			
		rb.add_child(col)
		
		# 3. КРИТИЧЕСКАЯ ПРОВЕРКА перед reparent()
		if mesh_node.is_inside_tree() and rb.is_inside_tree():
			mesh_node.reparent(rb)
			mesh_node.transform = Transform3D.IDENTITY 
			mesh_node.scale = safe_scale 
			active_shards.append(rb)
		else:
			rb.queue_free()
			continue
		
		# Применение сил (как и было)
		var world_up_impulse = Vector3(
			randf_range(-0.8, 0.8),
			randf_range(1.0, 3.0),
			randf_range(-0.8, 0.8)
		).normalized()
		
		rb.apply_central_impulse(world_up_impulse * explosion_impulse)
		
		var random_torque_axis = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()
		
		rb.apply_torque_impulse(random_torque_axis * explosion_spin)

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
			tween.tween_property(shard, "scale", Vector3.ZERO, fade_duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tween.finished
	queue_free()
