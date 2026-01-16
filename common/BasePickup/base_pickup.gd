class_name BasePickup
extends RigidBody3D

@export var pool_index: int = 0
@export var immunity_time: float = 0.5
@export var collect_vfx_index: int = 2 

@export_group("Attraction")
@export var attraction_start_speed: float = 5.0 
@export var attraction_acceleration: float = 35.0 
@export var attraction_radius: float = 4.0

var target_player: Player = null
var is_collectable: bool = false
var is_being_collected: bool = false 
var timer: float = 0.0
var current_speed: float = 0.0

# !!! НОВОЕ: Запоминаем настройки физики !!!
var default_layer: int = 1
var default_mask: int = 1

func _ready():
	$InteractionArea.body_entered.connect(_on_pickup)
	is_collectable = true
	
	# Запоминаем слои, которые были настроены в инспекторе
	default_layer = collision_layer
	default_mask = collision_mask

func _process(delta):
	if timer > 0:
		timer -= delta
		if timer <= 0:
			is_collectable = true
			
	if is_collectable and not is_being_collected:
		if target_player == null:
			var p = get_tree().get_first_node_in_group("player")
			if p and global_position.distance_to(p.global_position) < attraction_radius:
				target_player = p
				current_speed = attraction_start_speed
		else:
			freeze = true 
			current_speed += attraction_acceleration * delta
			
			var target_pos = target_player.global_position + Vector3(0, 1.0, 0)
			var dist = global_position.distance_to(target_pos)
			var move_step = current_speed * delta
			var dir = (target_pos - global_position).normalized()
			
			global_position += dir * move_step
			
			if dist < 0.5 or dist < move_step:
				_on_pickup(target_player)
				
func _on_pickup(body):
	if not is_collectable or is_being_collected: return
	
	if body.is_in_group("player"):
		is_being_collected = true 
		
		# Сразу отключаем коллизию, чтобы не мешался пока играет анимация
		collision_layer = 0
		collision_mask = 0
		
		_apply_effect(body)
		
		if has_node("/root/VfxPool"):
			VfxPool.spawn_effect(collect_vfx_index, global_position)
		
		$AnimationPlayer.play("Collect")
		
		await $AnimationPlayer.animation_finished
		
		if ItemPool.has_method("return_item"):
			ItemPool.return_item(self, pool_index)
		else:
			queue_free()

func _apply_effect(_player):
	pass

func reset_state():
	is_collectable = false
	is_being_collected = false 
	timer = immunity_time
	target_player = null
	current_speed = 0.0 
	
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	
	$Visuals.scale = Vector3.ONE 
	
	# !!! ВОССТАНАВЛИВАЕМ ФИЗИКУ !!!
	freeze = false # Размораживаем
	collision_layer = default_layer
	collision_mask = default_mask
	# ------------------------------
	
	$AnimationPlayer.play("Spawn")
	$AnimationPlayer.queue("Idle")
