class_name BreakableObject
extends RigidBody3D

@export var health_component: Node
@export var debris_vfx_index: int = 0 # Какой эффект из VfxPool играть при поломке
@export var vfx_offset: Vector3 = Vector3(0, 0.5, 0)
func _ready() -> void:
	if health_component:
		health_component.died.connect(_on_broken)

# Интерфейс для получения урона (совместим с Player и Enemy)
func take_damage(amount: float, knockback_force: Vector3, _is_heavy: bool = false) -> void:
	# Уменьшаем силу отбрасывания для легких объектов, чтобы они не улетали в космос
	# Например, гасим вертикальную составляющую и делим общую силу
	var dampened_force = knockback_force * 0.5 
	dampened_force.y = min(dampened_force.y, 2.0) # Ограничиваем подброс вверх
	
	apply_central_impulse(dampened_force)
	
	if health_component:
		health_component.take_damage(amount)

func receive_push(push_vector: Vector3) -> void:
	apply_central_impulse(push_vector)

func _on_broken() -> void:
	# 1. Спавним эффект разрушения (щепки, пыль)
	var pool = get_tree().get_first_node_in_group("vfx_pool")
	if pool:
		pool.spawn_effect(debris_vfx_index, to_global(vfx_offset))
	
	# 2. (Опционально) Спавним лут
	# spawn_loot()
	
	# 3. Удаляем объект
	queue_free()
