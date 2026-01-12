class_name BasePickup
extends RigidBody3D

@export var pool_index: int = 0
@export var immunity_time: float = 0.5
@export var collect_vfx_index: int = 2 

@export_group("Attraction")
@export var attraction_start_speed: float = 5.0 ## Начальная скорость полета
@export var attraction_acceleration: float = 35.0 ## Насколько быстро разгоняется (метров в сек^2)
@export var attraction_radius: float = 4.0

var target_player: Player = null
var is_collectable: bool = false
var is_being_collected: bool = false 
var timer: float = 0.0

# Текущая скорость полета (накапливается)
var current_speed: float = 0.0

func _ready():
	$InteractionArea.body_entered.connect(_on_pickup)
	
	# Предметы, расставленные на уровне вручную, собираются сразу
	is_collectable = true

func _process(delta):
	# Таймер иммунитета (для спавна из ящиков)
	if timer > 0:
		timer -= delta
		if timer <= 0:
			is_collectable = true
			
	if is_collectable and not is_being_collected:
		if target_player == null:
			# 1. Поиск игрока
			var p = get_tree().get_first_node_in_group("player")
			if p and global_position.distance_to(p.global_position) < attraction_radius:
				target_player = p
				current_speed = attraction_start_speed # Сброс скорости на стартовую
		else:
			# 2. Полет к игроку
			freeze = true 
			
			# Увеличиваем скорость каждый кадр (разгон)
			current_speed += attraction_acceleration * delta
			
			var target_pos = target_player.global_position + Vector3(0, 1.0, 0)
			var dist = global_position.distance_to(target_pos)
			var move_step = current_speed * delta
			
			# Двигаем
			var dir = (target_pos - global_position).normalized()
			global_position += dir * move_step
			
			# Если мы перелетели цель или очень близко — засчитываем подбор
			# (Проверка dist < move_step гарантирует, что мы не пролетим сквозь игрока на огромной скорости)
			if dist < 0.5 or dist < move_step:
				_on_pickup(target_player)
				
func _on_pickup(body):
	if not is_collectable or is_being_collected: return
	
	if body.is_in_group("player"):
		is_being_collected = true 
		
		_apply_effect(body)
		
		if has_node("/root/VfxPool"):
			VfxPool.spawn_effect(collect_vfx_index, global_position)
		
		$AnimationPlayer.play("Collect")
		
		await $AnimationPlayer.animation_finished
		
		if ItemPool.has_method("return_item"):
			ItemPool.return_item(self, pool_index)
		else:
			queue_free()

# Виртуальная функция
func _apply_effect(_player):
	pass

func reset_state():
	is_collectable = false
	is_being_collected = false 
	timer = immunity_time
	target_player = null
	current_speed = 0.0 # Сброс скорости
	
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	
	$Visuals.scale = Vector3.ONE 
	
	$AnimationPlayer.play("Spawn")
	$AnimationPlayer.queue("Idle")
	freeze = false
