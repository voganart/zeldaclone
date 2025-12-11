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
var cooldown_timer: float = 0.0
var _windup_timer: float = 0.0
var _fall_time: float = 0.0
var _animation_phase: String = "" # "start", "mid", "end"
var _impact_processed: bool = false
var _playing_end_anim: bool = false

@onready var actor: CharacterBody3D = get_parent()
@onready var anim_player: AnimationPlayer = actor.get_node("character/AnimationPlayer")

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

func can_slam() -> bool:
	if is_slamming: return false
	if actor.is_on_floor(): return false
	if cooldown_timer > 0: return false
	
	# Проверка высоты рейкастом
	var space_state = actor.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(actor.global_position, actor.global_position + Vector3(0, -100, 0))
	query.exclude = [actor]
	var result = space_state.intersect_ray(query)
	
	if result:
		var dist = actor.global_position.distance_to(result.position)
		if dist < slam_min_height:
			print("Too low for slam: ", dist)
			return false
	
	# Требование: только после 2-го прыжка (из оригинала)
	if "current_jump_count" in actor and actor.current_jump_count < 2:
		return false
		
	return true

func start_slam() -> void:
	if not can_slam(): return
	
	is_slamming = true
	cooldown_timer = slam_cooldown
	_windup_timer = slam_windup_delay
	_fall_time = 0.0
	_animation_phase = "start"
	_impact_processed = false
	_playing_end_anim = false
	
	# Отключаем коллизию с врагами (слой 3 - пример из оригинала)
	actor.set_collision_mask_value(3, false)
	
	# Фриз в воздухе
	actor.velocity = Vector3.ZERO
	
	anim_player.play("Boy_attack_air_naked_start", 0.1, 0.5)
	print("Slam Ability: Windup")

## Основной метод обновления физики, вызывается из player._physics_process
## Возвращает true, если способность управляет движением (нужно пропустить гравитацию)
func update_physics(delta: float) -> bool:
	if not is_slamming:
		return false
	
	# Если мы уже на земле — обрабатываем удар
	if actor.is_on_floor() and not _impact_processed:
		_perform_impact()
		return true # Все еще управляем, пока не завершим
		
	# Фаза 1: Зависание (Windup)
	if _windup_timer > 0:
		_windup_timer -= delta
		actor.velocity = Vector3.ZERO
		
		if _windup_timer <= 0:
			_animation_phase = "mid"
			anim_player.play("Boy_attack_air_naked_mid", 0.2, 1.0)
		return true
	
	# Фаза 2: Падение (Descent)
	_fall_time += delta
	var current_speed = 5.0 * exp(slam_acceleration * _fall_time)
	current_speed = min(current_speed, slam_descent_speed)
	
	actor.velocity.x = 0
	actor.velocity.z = 0
	actor.velocity.y = -current_speed
	
	# Проверка близости земли для анимации приземления
	_check_ground_proximity()
	
	return true

func _check_ground_proximity() -> void:
	if _animation_phase != "mid": return
	
	var space_state = actor.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(actor.global_position, actor.global_position + Vector3(0, 0.5, 0)) # Чуть ниже ног
	query.exclude = [actor]
	var result = space_state.intersect_ray(query)
	
	if result:
		_animation_phase = "end"
		_playing_end_anim = true
		anim_player.play("Boy_attack_air_naked_end", 0.5, slam_end_anim_speed)

func _perform_impact() -> void:
	if _impact_processed: return
	_impact_processed = true
	
	is_slamming = false # Снимаем флаг физики, но можем доигрывать анимацию
	actor.set_collision_mask_value(3, true) # Возвращаем коллизии
	
	print("Slam Ability: Impact!")
	
	# Урон по площади
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		
		var dist = actor.global_position.distance_to(enemy.global_position)
		if dist <= slam_radius:
			var push_dir = (enemy.global_position - actor.global_position).normalized()
			push_dir.y = 0.5
			
			if enemy.has_method("receive_push"):
				enemy.receive_push(push_dir * 3.0)
			
			if enemy.has_method("take_damage"):
				enemy.take_damage(slam_damage, push_dir * slam_knockback)
