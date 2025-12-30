class_name BreakableObject
extends RigidBody3D

@export var health_component: Node
@export var debris_vfx_index: int = 1
@export var vfx_offset: Vector3 = Vector3(0, 0.5, 0)
@export var break_sound: AudioStream 

# --- НАСТРОЙКИ НАВИГАЦИИ ---
@export var obstacle_radius: float = 0.8 ## Радиус зоны, которую враги будут обходить
@export var obstacle_height: float = 1.0

var nav_obstacle: NavigationObstacle3D

func _ready() -> void:
	# ... (Тут твой код физики из прошлого ответа: mass = 20.0, sleeping = true и т.д.) ...
	# ПОВТОРИМ ВАЖНЫЕ НАСТРОЙКИ ФИЗИКИ:
	mass = 20.0
	can_sleep = true 
	sleeping = true
	continuous_cd = true 
	angular_damp = 2.0 
	linear_damp = 1.0
	if physics_material_override == null:
		var mat = PhysicsMaterial.new()
		mat.friction = 0.5      
		mat.bounce = 0.0
		mat.absorbent = true 
		physics_material_override = mat
	# -----------------------------------------------------

	if health_component:
		health_component.died.connect(_on_broken)
		
	#_setup_navigation_obstacle()

func _setup_navigation_obstacle() -> void:
	# Создаем препятствие программно
	nav_obstacle = NavigationObstacle3D.new()
	nav_obstacle.name = "NavObstacle"
	add_child(nav_obstacle)
	
	# Настраиваем размеры
	nav_obstacle.radius = obstacle_radius
	nav_obstacle.height = obstacle_height
	
	# ВАЖНО: Привязываем к родителю, чтобы зона двигалась вместе с ящиком
	# В Godot 4.x obstacle сам понимает позицию родителя
	
	# Включаем влияние на избегание
	nav_obstacle.avoidance_enabled = true
	
	# (Опционально) Сдвигаем на слой, который видят враги (обычно слой 1)
	# nav_obstacle.set_avoidance_layer_value(1, true)

# ... (Остальной код take_damage, _on_broken и т.д. оставляем без изменений)
func take_damage(amount: float, knockback_force: Vector3, _is_heavy: bool = false) -> void:
	sleeping = false 
	angular_damp = 1.0 
	var random_torque = Vector3(randf(), randf(), randf()) * 5.0
	apply_torque_impulse(random_torque)
	var dampened_force = knockback_force 
	if dampened_force.y > 6.0: dampened_force.y = 6.0
	apply_central_impulse(dampened_force)
	if health_component: health_component.take_damage(amount)

func _on_broken() -> void:
	VfxPool.spawn_effect(debris_vfx_index, global_position + vfx_offset)
	if break_sound: AudioManager.play_sfx_3d(break_sound, global_position, true, +5.0)
	_wake_up_objects_above()
	queue_free()

func _wake_up_objects_above() -> void:
	var space_state = get_world_3d().direct_space_state
	var shape = BoxShape3D.new()
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
			collider.angular_damp = 1.0 
			collider.apply_central_impulse(Vector3.DOWN * 2.0)
