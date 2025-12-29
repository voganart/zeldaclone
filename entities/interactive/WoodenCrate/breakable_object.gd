class_name BreakableObject
extends RigidBody3D

@export var health_component: Node
@export var debris_vfx_index: int = 1
@export var vfx_offset: Vector3 = Vector3(0, 0.5, 0)
@export var break_sound: AudioStream 

func _ready() -> void:
	# Настройка физики:
	mass = 5.0
	# Снизили damping (было 5.0), чтобы ящик легче сдвигался
	linear_damp = 2.0 
	angular_damp = 2.0
	
	if health_component:
		health_component.died.connect(_on_broken)

func take_damage(amount: float, knockback_force: Vector3, _is_heavy: bool = false) -> void:
	sleeping = false 
	var random_torque = Vector3(randf(), randf(), randf()) * 10.0
	apply_torque_impulse(random_torque)
	
	var dampened_force = knockback_force 
	if dampened_force.y > 5.0: dampened_force.y = 5.0
	
	apply_central_impulse(dampened_force)
	
	if health_component:
		health_component.take_damage(amount)

func _on_broken() -> void:
	VfxPool.spawn_effect(debris_vfx_index, global_position + Vector3(0, 0, 0))
	if break_sound:
		AudioManager.play_sfx_3d(break_sound, global_position, true, +5.0)

	_wake_up_objects_above()
	queue_free()

func _wake_up_objects_above() -> void:
	var space_state = get_world_3d().direct_space_state
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.9, 0.5, 0.9) 
	
	var params = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), global_position + Vector3(0, 1.0, 0))
	params.collision_mask = collision_layer 
	
	var results = space_state.intersect_shape(params)
	
	for res in results:
		var collider = res.collider
		if collider is RigidBody3D and collider != self:
			collider.sleeping = false
			collider.apply_central_impulse(Vector3.DOWN * 0.5)
