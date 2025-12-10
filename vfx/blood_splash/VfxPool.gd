extends Node

@export var effect_scenes: Array[PackedScene] = []
@export var pool_size: int = 10
@export var auto_expand: bool = false
@export var effect_lifetime: float = 1.0

var pool: Array = []
var available: Array = []

func _ready():
	for scene in effect_scenes:
		for i in pool_size:
			var inst = scene.instantiate()
			inst.visible = false
			add_child(inst)
			pool.append(inst)
			available.append(inst)

func spawn_effect(effect_idx: int, position: Vector3, rotation: Vector3 = Vector3.ZERO):
	if available.size() == 0:
		if auto_expand:
			var inst = effect_scenes[effect_idx].instantiate()
			add_child(inst)
			pool.append(inst)
			available.append(inst)
		else:
			return null
	var effect = available.pop_front()
	effect.global_position = position
	effect.global_rotation = rotation
	effect.visible = true
	if effect.has_method("restart"):
		effect.restart()
	_enable_particles(effect)
	# Автоматическое возвращение в пул
	_return_to_pool_later(effect)
	
	return effect
func _enable_particles(node):
	for child in node.get_children():
		if child is GPUParticles3D or child is CPUParticles3D:
			child.one_shot = true
			child.emitting = true
		_enable_particles(child)
		
func _return_to_pool_later(effect):
	await get_tree().create_timer(effect_lifetime).timeout
	effect.visible = false
	available.append(effect)
