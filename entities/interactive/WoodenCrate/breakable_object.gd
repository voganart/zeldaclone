class_name BreakableObject
extends RigidBody3D

@export var health_component: Node
@export var debris_scene: PackedScene
@export var break_sound: AudioStream 

# --- НАСТРОЙКИ ЛУТА (НОВОЕ) ---
@export_group("Loot Settings")
@export_range(0.0, 1.0) var drop_chance: float = 0.4 ## Общий шанс выпадения чего-либо (40%)
@export_range(0.0, 1.0) var heart_drop_rate: float = 0.2 ## Шанс, что это будет Сердце, а не Вабо (20%)

# Индексы в ItemPool (проверь в Autoload/ItemPool.tscn)
# Обычно: 0 = Вабо (Монеты), 1 = Сердце
@export var item_index_vabo: int = 0
@export var item_index_heart: int = 1

# --- НАСТРОЙКИ НАВИГАЦИИ ---
@export var obstacle_radius: float = 0.8
@export var obstacle_height: float = 1.0

var nav_obstacle: NavigationObstacle3D

func _ready() -> void:
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

	if health_component:
		health_component.died.connect(_on_broken)

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
	# 1. Спавн обломков
	if debris_scene:
		var debris = debris_scene.instantiate()
		get_parent().add_child(debris)
		debris.global_position = global_position
		debris.global_rotation = global_rotation
		
		if break_sound: 
			AudioManager.play_sfx_3d(break_sound, global_position, true, +5.0)
	
	# 2. Спавн ЛУТА (НОВОЕ)
	_try_spawn_loot()
	
	# 3. Будим физику
	_wake_up_objects_above()
	
	queue_free()

func _try_spawn_loot() -> void:
	# Проверка общего шанса
	if randf() > drop_chance:
		return
	
	# Выбор предмета
	var index_to_spawn = item_index_vabo # По умолчанию Вабо
	
	# Если повезло на сердце
	if randf() <= heart_drop_rate:
		index_to_spawn = item_index_heart
		
	# Спавним через пул
	if ItemPool.has_method("spawn_item"):
		# Поднимаем спавн чуть выше (0.5), чтобы не провалился
		var item = ItemPool.spawn_item(index_to_spawn, global_position + Vector3(0, 0.5, 0))
		
		if item:
			# Даем небольшой пинок вверх, чтобы красиво вылетел
			var pop_force = Vector3(randf_range(-1, 1), 4.0, randf_range(-1, 1)).normalized() * 3.0
			item.apply_impulse(pop_force)

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
