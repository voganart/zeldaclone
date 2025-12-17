class_name BreakableObject
extends RigidBody3D

@export var health_component: Node
@export var debris_vfx_index: int = 1
@export var vfx_offset: Vector3 = Vector3(0, 0.5, 0)
# Если есть звук
@export var break_sound: AudioStream 

func _ready() -> void:
	if health_component:
		health_component.died.connect(_on_broken)

# Никакого _physics_process. Физика Godot работает сама.

func take_damage(amount: float, knockback_force: Vector3, _is_heavy: bool = false) -> void:
	# Будим ящик при ударе
	sleeping = false 
	
	# Ограничиваем полет вверх
	var dampened_force = knockback_force 
	if dampened_force.y > 5.0: dampened_force.y = 5.0
	
	apply_central_impulse(dampened_force)
	
	if health_component:
		health_component.take_damage(amount)

func _on_broken() -> void:
	# 1. VFX
	VfxPool.spawn_effect(debris_vfx_index, global_position + Vector3(0, 1.5, 0))
	# 2. ЗВУК
	if break_sound:
		AudioManager.play_sfx_3d(break_sound, global_position, true, -10.0)

	# 3. ФИКС ЛЕВИТАЦИИ (Будим верхние ящики)
	_wake_up_objects_above()

	# 4. Удаление
	queue_free()

## Магия для пробуждения верхних ящиков
func _wake_up_objects_above() -> void:
	var space_state = get_world_3d().direct_space_state
	
	# Форма поиска чуть выше ящика
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.9, 0.5, 0.9) # Чуть уже, чтобы не цеплять боковых
	
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 1.0, 0))
	params.collision_mask = collision_layer # Ищем только другие ящики
	
	var results = space_state.intersect_shape(params)
	
	for res in results:
		var collider = res.collider
		if collider is RigidBody3D and collider != self:
			collider.sleeping = false
			# Легкий пинок вниз для гарантии падения
			collider.apply_central_impulse(Vector3.DOWN * 0.5)
