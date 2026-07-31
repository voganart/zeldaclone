extends Node3D

@export_group("Explosion Settings")
@export var explosion_impulse: float = 5.0 ## Сила разлета (скорость)
@export var explosion_spin: float = 2.0    ## Сила вращения (кручение)
@export var lifetime: float = 4.0
@export var fade_duration: float = 1.0

@export_group("Physics")
@export_flags_3d_physics var debris_layer: int = 1 
@export_flags_3d_physics var debris_mask: int = 7 
@export_range(0, 120, 1) var max_active_physics_shards: int = 60

@export_group("Fallback Motion")
@export var fallback_gravity: float = 18.0
@export var fallback_floor_ray_length: float = 10.0
@export var fallback_spin_multiplier: float = 4.0

static var _active_physics_shards: int = 0

var _owned_physics_shards: int = 0
var _animated_shards: Array[Dictionary] = []
var _fallback_floor_y: float = 0.0

func _ready() -> void:
	set_process(false)

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
	if not is_inside_tree(): return 
	
	var meshes = _get_all_meshes(self)
	if meshes.is_empty(): return
	
	var active_shards: Array[RigidBody3D] = []
	var fallback_floor_found := false

	for mesh_node in meshes:
		if not is_instance_valid(mesh_node): continue
		if _active_physics_shards >= max_active_physics_shards:
			if not fallback_floor_found:
				_fallback_floor_y = _find_floor_y()
				fallback_floor_found = true
			_prepare_animated_shard(mesh_node)
			continue
		
		var parent_node = mesh_node.get_parent()
		if not parent_node or not parent_node.is_inside_tree(): continue

		# 1. Берем глобальную трансформацию
		var global_t = mesh_node.global_transform
		var original_scale = global_t.basis.get_scale()
		
		# 2. Лечим масштаб (Fix Singular Basis)
		# Jolt ненавидит масштаб 0. Если осколок плоский или нулевой - даем ему объем.
		var safe_scale = original_scale
		if safe_scale.x < 0.05: safe_scale.x = 0.1
		if safe_scale.y < 0.05: safe_scale.y = 0.1
		if safe_scale.z < 0.05: safe_scale.z = 0.1

		var rb = RigidBody3D.new()
		rb.name = mesh_node.name + "_RB"
		parent_node.add_child(rb)
		rb.top_level = true 

		# 3. Создаем "Чистый" Базис (Только вращение, масштаб строго 1,1,1)
		var clean_basis = Basis() # Identity по умолчанию
		
		# Пытаемся сохранить вращение, только если объект не был сплющен в ноль
		# (determinant == 0 означает, что базис сломан)
		if abs(global_t.basis.determinant()) > 0.001:
			clean_basis = global_t.basis.orthonormalized()
		
		# Присваиваем RB чистый базис и позицию
		rb.global_transform = Transform3D(clean_basis, global_t.origin)
		
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
			# Если меш сам по себе нулевой, пропускаем
			if aabb.size.length_squared() < 0.001:
				rb.queue_free()
				continue
				
			var box_shape = BoxShape3D.new()
			# Используем safe_scale для коллизии
			box_shape.size = aabb.size * safe_scale
			col.shape = box_shape
			# Центр тоже скейлим
			col.position = aabb.get_center() * safe_scale
			
		rb.add_child(col)
		
		if mesh_node.is_inside_tree() and rb.is_inside_tree():
			mesh_node.reparent(rb)
			# Сбрасываем трансформ меша в 0 относительно RB
			mesh_node.transform = Transform3D.IDENTITY 
			# И применяем к мешу исправленный масштаб
			mesh_node.scale = safe_scale 
			active_shards.append(rb)
			_active_physics_shards += 1
			_owned_physics_shards += 1
		else:
			rb.queue_free()
			continue
		
		# Применение сил
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

func _process(delta: float) -> void:
	for shard_state in _animated_shards:
		var shard := shard_state["node"] as MeshInstance3D
		if not is_instance_valid(shard):
			continue

		var velocity: Vector3 = shard_state["velocity"]
		var position := shard.global_position

		if shard_state["grounded"]:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
			position += Vector3(velocity.x, 0.0, velocity.z) * delta
		else:
			velocity.y -= fallback_gravity * delta
			position += velocity * delta

			var landing_y: float = _fallback_floor_y + shard_state["floor_offset"]
			if position.y <= landing_y:
				position.y = landing_y
				velocity.y = 0.0
				velocity.x *= 0.35
				velocity.z *= 0.35
				shard_state["grounded"] = true

		shard.global_position = position
		shard.rotation += shard_state["angular_velocity"] * delta
		shard_state["velocity"] = velocity

func _prepare_animated_shard(mesh_node: MeshInstance3D) -> void:
	var global_t := mesh_node.global_transform
	var mesh_scale := global_t.basis.get_scale()
	var floor_offset := 0.02
	if mesh_node.mesh:
		floor_offset = maxf(0.02, mesh_node.mesh.get_aabb().size.y * mesh_scale.y * 0.5)

	mesh_node.top_level = true
	mesh_node.global_transform = global_t

	var launch_direction := Vector3(
		randf_range(-0.8, 0.8),
		randf_range(1.0, 3.0),
		randf_range(-0.8, 0.8)
	).normalized()
	var angular_axis := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()

	_animated_shards.append({
		"node": mesh_node,
		"velocity": launch_direction * explosion_impulse,
		"angular_velocity": angular_axis * explosion_spin * fallback_spin_multiplier,
		"floor_offset": floor_offset,
		"grounded": false,
	})
	set_process(true)

func _find_floor_y() -> float:
	var ray_start := global_position + Vector3.UP * 1.0
	var ray_end := global_position + Vector3.DOWN * fallback_floor_ray_length
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, debris_mask)
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		return result.position.y
	return global_position.y - 0.5

func _get_all_meshes(node: Node, result: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_get_all_meshes(child, result)
	return result

func _fade_out(shards: Array[RigidBody3D]) -> void:
	if not is_inside_tree(): return
	set_process(false)
	var tween = create_tween()
	tween.set_parallel(true)
	
	for shard in shards:
		if is_instance_valid(shard):
			# 1. Полностью выключаем физику, чтобы Jolt не ругался
			shard.collision_layer = 0
			shard.collision_mask = 0
			shard.freeze = true # Замораживаем (превращаем в статику)
			
			# 2. Ищем меш внутри и скейлим ЕГО, а не сам RigidBody
			for child in shard.get_children():
				if child is MeshInstance3D:
					tween.tween_property(child, "scale", Vector3.ZERO, fade_duration)\
						.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	for shard_state in _animated_shards:
		var shard := shard_state["node"] as MeshInstance3D
		if is_instance_valid(shard):
			tween.tween_property(shard, "scale", Vector3.ZERO, fade_duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tween.finished
	
	# 3. Гарантированно удаляем осколки из памяти
	for shard in shards:
		if is_instance_valid(shard):
			shard.queue_free()
	_release_physics_shards()
			
	# 4. Удаляем сам объект взрыва
	queue_free()

func _exit_tree() -> void:
	_release_physics_shards()

func _release_physics_shards() -> void:
	if _owned_physics_shards == 0:
		return
	_active_physics_shards = maxi(0, _active_physics_shards - _owned_physics_shards)
	_owned_physics_shards = 0
