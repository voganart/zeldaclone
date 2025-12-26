class_name EnemyHealthBar
extends Node3D

@export var fade_delay: float = 2.0
@export var fade_speed: float = 2.0

var health_mesh: MeshInstance3D
var target_health_pct: float = 1.0
var delayed_health_pct: float = 1.0
var current_opacity: float = 0.0
var visibility_timer: float = 0.0

func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			health_mesh = child
			break
	
	_update_shader_params(1.0, 1.0, 0.0)
	visible = false

func _process(delta: float) -> void:
	# ДОБАВЛЕНА ПРОВЕРКА is_instance_valid
	if not is_instance_valid(health_mesh) or not visible:
		return

	delayed_health_pct = move_toward(delayed_health_pct, target_health_pct, delta * 0.5)

	var target_opacity_val = 0.0
	
	if target_health_pct >= 0.999:
		target_opacity_val = 0.0
	else:
		if visibility_timer > 0:
			target_opacity_val = 1.0
			visibility_timer -= delta
		else:
			target_opacity_val = 0.5
			
	current_opacity = move_toward(current_opacity, target_opacity_val, delta * fade_speed)

	_update_shader_params(target_health_pct, delayed_health_pct, current_opacity)
	
	if current_opacity <= 0 and target_health_pct >= 0.999:
		visible = false

func update_health(current: float, max_hp: float) -> void:
	if max_hp <= 0: return
	
	target_health_pct = current / max_hp
	visibility_timer = fade_delay
	visible = true 

func _update_shader_params(hp: float, delayed: float, opacity: float) -> void:
	if is_instance_valid(health_mesh): # Дополнительная проверка перед обращением к серверу
		health_mesh.set_instance_shader_parameter(GameConstants.SHADER_PARAM_HEALTH, hp)
		health_mesh.set_instance_shader_parameter(GameConstants.SHADER_PARAM_DELAYED_HEALTH, delayed)
		health_mesh.set_instance_shader_parameter(GameConstants.SHADER_PARAM_OPACITY, opacity)
