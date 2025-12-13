class_name GroundSlamAbility
extends Node

@export_group("Ground Slam")
@export var slam_damage: float = 1.0
@export var slam_radius: float = 2.0
@export var slam_descent_speed: float = 20.0
@export var slam_knockback: float = 0.3
@export var slam_cooldown: float = 2.0
@export var slam_windup_delay: float = 0.5
@export var slam_acceleration: float = 50.0
@export var slam_min_height: float = 3.0
@export var slam_end_anim_speed: float = 1.5

# State
var is_slamming: bool = false
var is_recovering: bool = false # <--- НОВЫЙ ФЛАГ

var cooldown_timer: float = 0.0
var _windup_timer: float = 0.0
var _fall_time: float = 0.0
var _animation_phase: String = ""
var _impact_processed: bool = false
var _playing_end_anim: bool = false

@onready var actor: CharacterBody3D = get_parent()
# Получаем плеер чуть безопаснее
@onready var anim_player: AnimationPlayer = actor.get_node("character/AnimationPlayer")

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

func can_slam() -> bool:
	if is_slamming or is_recovering: return false # Проверка recovery
	if actor.is_on_floor(): return false
	if cooldown_timer > 0: return false
	
	var space_state = actor.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(actor.global_position, actor.global_position + Vector3(0, -100, 0))
	query.exclude = [actor]
	var result = space_state.intersect_ray(query)
	
	if result:
		var dist = actor.global_position.distance_to(result.position)
		if dist < slam_min_height:
			return false
	
	if "current_jump_count" in actor and actor.current_jump_count < 2:
		return false
		
	return true

func start_slam() -> void:
	if not can_slam(): return
	
	is_slamming = true
	is_recovering = false
	cooldown_timer = slam_cooldown
	_windup_timer = slam_windup_delay
	_fall_time = 0.0
	_animation_phase = "start"
	_impact_processed = false
	_playing_end_anim = false
	
	actor.set_collision_mask_value(3, false)
	actor.velocity = Vector3.ZERO
	
	anim_player.play(GameConstants.ANIM_PLAYER_SLAM_START, 0.1, 0.5)

func update_physics(delta: float) -> bool:
	# 1. Если мы в фазе восстановления (анимация приземления), блокируем физику игрока
	if is_recovering:
		# Можно добавить небольшое трение, чтобы игрок не скользил
		actor.velocity.x = move_toward(actor.velocity.x, 0, 1.0)
		actor.velocity.z = move_toward(actor.velocity.z, 0, 1.0)
		return true

	if not is_slamming:
		return false
	
	# Если коснулись пола — удар
	if actor.is_on_floor() and not _impact_processed:
		_perform_impact()
		return true
		
	# Фаза Windup
	if _windup_timer > 0:
		_windup_timer -= delta
		actor.velocity = Vector3.ZERO
		if _windup_timer <= 0:
			_animation_phase = "mid"
			anim_player.play(GameConstants.ANIM_PLAYER_SLAM_MID, 0.2, 1.0)
		return true
	
	# Фаза падения
	_fall_time += delta
	var current_speed = 5.0 * exp(slam_acceleration * _fall_time)
	current_speed = min(current_speed, slam_descent_speed)
	
	actor.velocity.x = 0
	actor.velocity.z = 0
	actor.velocity.y = - current_speed
	
	_check_ground_proximity()
	
	return true

func _check_ground_proximity() -> void:
	# Если мы уже играем концовку, не перезапускаем
	if _playing_end_anim: return
	if _animation_phase != "mid": return
	
	var space_state = actor.get_world_3d().direct_space_state
	# Увеличил длину луча, чтобы анимация точно успевала начаться при высокой скорости
	var query = PhysicsRayQueryParameters3D.create(actor.global_position, actor.global_position + Vector3(0, 1.5, 0))
	query.exclude = [actor]
	var result = space_state.intersect_ray(query)
	
	if result:
		_animation_phase = "end"
		_playing_end_anim = true
		anim_player.play(GameConstants.ANIM_PLAYER_SLAM_END, 0.1, slam_end_anim_speed)

func _perform_impact() -> void:
	if _impact_processed: return
	_impact_processed = true
	
	# Включаем фазу восстановления. 
	# Теперь update_physics будет возвращать true, блокируя Player.gd
	is_slamming = false
	is_recovering = true
	get_tree().call_group("camera_shaker", "add_trauma", 5.8)
	# Гарантируем запуск анимации, если Raycast промахнулся
	if not _playing_end_anim or anim_player.current_animation != GameConstants.ANIM_PLAYER_SLAM_END:
		anim_player.play(GameConstants.ANIM_PLAYER_SLAM_END, 0.025, slam_end_anim_speed)
	
	# Ждем окончания анимации
	var anim_len = anim_player.get_animation(GameConstants.ANIM_PLAYER_SLAM_END).length
	# Делим на скорость воспроизведения
	var wait_time = anim_len / slam_end_anim_speed
	
	# Логика урона
	_deal_damage()
	
	actor.set_collision_mask_value(3, true)
	print("Slam Impact! Waiting for animation: ", wait_time)
	
	# Ждем, пока проиграется анимация
	await get_tree().create_timer(wait_time).timeout
	if not is_instance_valid(actor):
		return
	# Возвращаем управление игроку
	is_recovering = false
	_playing_end_anim = false

func _deal_damage() -> void:
	var enemies = get_tree().get_nodes_in_group(GameConstants.GROUP_ENEMIES)
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		var dist = actor.global_position.distance_to(enemy.global_position)
		if dist <= slam_radius:
			var push_dir = (enemy.global_position - actor.global_position).normalized()
			push_dir.y = 0.5
			
			if enemy.has_method("receive_push"):
				enemy.receive_push(push_dir * 3.0)
			
			if enemy.has_method("take_damage"):
				enemy.take_damage(slam_damage, push_dir * slam_knockback, true)
