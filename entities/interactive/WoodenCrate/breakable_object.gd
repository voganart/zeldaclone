class_name BreakableObject
extends RigidBody3D

@export var health_component: Node
@export var debris_vfx_index: int = 1
@export var vfx_offset: Vector3 = Vector3(0, 0.5, 0)
@export var break_sound: AudioStream 

func _ready() -> void:
	# --- НАСТРОЙКИ СТАБИЛЬНОСТИ ---
	
	# 1. Разрешаем спать.
	can_sleep = true 
	
	# 2. ПРИНУДИТЕЛЬНО УСЫПЛЯЕМ ПРИ СТАРТЕ!
	# Это заставит ящик замереть в той позе, как вы поставили его в редакторе.
	# Он не шелохнется, пока в него что-то не влетит или не сломается опора.
	sleeping = true
	freeze = false # Убеждаемся, что это не статика, а именно спящая физика
	
	# 3. Обнуляем скорости (на всякий случай)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# 4. Включаем CCD, чтобы при падении не пролетали сквозь пол
	continuous_cd = true 
	
	# 5. Масса и инерция
	mass = 20.0 # Тяжелые объекты стабильнее легких
	
	# 6. "Вязкость" воздуха.
	# angular_damp = 5.0 очень сильно мешает ящику начать вращаться самому по себе.
	# Это убирает микро-вращения, от которых рушатся пирамиды.
	angular_damp = 5.0 
	linear_damp = 1.0
	
	# 7. Материал физики (Максимальное трение)
	if physics_material_override == null:
		var mat = PhysicsMaterial.new()
		mat.friction = 1.0      # Шершавый как наждачка
		mat.rough = true        # Приоритет трения
		mat.bounce = 0.0        # Не пружинит
		mat.absorbent = true    # Гасит энергию
		physics_material_override = mat

	if health_component:
		health_component.died.connect(_on_broken)

func take_damage(amount: float, knockback_force: Vector3, _is_heavy: bool = false) -> void:
	# БУДИМ при получении урона
	sleeping = false 
	
	# Сбрасываем сопротивление вращению, чтобы при ударе он летел красиво, 
	# а не как в киселе.
	angular_damp = 1.0 
	
	var random_torque = Vector3(randf(), randf(), randf()) * 10.0
	apply_torque_impulse(random_torque)
	
	var dampened_force = knockback_force 
	if dampened_force.y > 6.0: dampened_force.y = 6.0
	
	apply_central_impulse(dampened_force)
	
	if health_component:
		health_component.take_damage(amount)

func _on_broken() -> void:
	VfxPool.spawn_effect(debris_vfx_index, global_position + vfx_offset)
	if break_sound:
		AudioManager.play_sfx_3d(break_sound, global_position, true, +5.0)

	_wake_up_objects_above()
	queue_free()

func _wake_up_objects_above() -> void:
	# Будим соседей сверху
	var space_state = get_world_3d().direct_space_state
	var shape = BoxShape3D.new()
	# Чуть меньше размера ящика
	shape.size = Vector3(0.8, 0.5, 0.8) 
	
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 1.0, 0))
	params.collision_mask = collision_layer 
	
	var results = space_state.intersect_shape(params)
	
	for res in results:
		var collider = res.collider
		if collider is RigidBody3D and collider != self:
			collider.sleeping = false
			# Возвращаем им нормальное вращение, чтобы падали естественно
			collider.angular_damp = 1.0 
			collider.apply_central_impulse(Vector3.DOWN * 2.0)
