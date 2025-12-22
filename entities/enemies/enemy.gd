class_name Enemy
extends CharacterBody3D

## ============================================================================
## ENEMY CONTROLLER (FSM Refactor)
## ============================================================================

# ============================================================================
# EXPORTS
# ============================================================================
@export_group("Components")
@export var punch_hand_r: Area3D
@export var punch_hand_l: Area3D
@export var punch_area: Area3D # Основной конус атаки
@export var can_flee: bool = true # Может ли этот тип врага вообще убегать
@export_range(0.0, 1.0) var flee_health_threshold: float = 0.25 # Убегает при 25% здоровья или меньше
@export_range(0.0, 1.0) var flee_chance: float = 0.3 # Шанс (30%), что враг вообще захочет убегать

@export_group("Hit Stop Settings")
## Насколько замедляется время при смертельном ударе (0.0 - стоп, 1.0 - норма)
@export var hit_stop_lethal_time_scale: float = 0.5
## Длительность замедления при смерти
@export var hit_stop_lethal_duration: float = 0.2
## Длительность микро-фриза анимации при обычном ударе
@export var hit_stop_local_duration: float = 0.08

@export_group("Movement")
@export var walk_speed: float = 1.5
@export var run_speed: float = 3.5
@export var retreat_speed: float = 2.5
@export var rotation_speed: float = 6.0
@export var combat_rotation_speed: float = 30.0
@export_range(0, 180) var strafe_view_angle: float = 45.0
@export var gravity: float = 30.0
@export var knockback_strength: float = 2.0
@export var knockback_duration: float = 0.5

@export_group("Animation Blending")
@export var walk_run_blend_smoothing: float = 8.0
@export var walk_run_blend_start_speed: float = 1.8
@export var walk_run_blend_end_speed: float = 3.2

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var state_machine: StateMachine = $StateMachine
@onready var vision_component: VisionComponent = $VisionComponent
@onready var attack_component: EnemyAttackComponent = $EnemyAttackComponent
@onready var health_component: Node = $HealthComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = $Monstr/AnimationPlayer
@onready var anim_tree: AnimationTree = $Monstr/AnimationTree
var vfx_pull: Node3D
@onready var player: Node3D = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
@onready var patrol_zone: Area3D = get_parent() as Area3D
@onready var sfx_hurt_voice: RandomAudioPlayer3D = $SoundBank/SfxHurtVoice
@onready var sfx_flesh_hit: RandomAudioPlayer3D = $SoundBank/SfxFleshHit
@onready var sfx_death_impact: RandomAudioPlayer3D = $SoundBank/SfxDeathImpact

# UI References
@onready var health_bar: EnemyHealthBar = $HealthBar3D
# ============================================================================
# SHARED DATA (Accessible by States)
# ============================================================================
var vertical_velocity: float = 0.0
var external_push: Vector3 = Vector3.ZERO
var last_known_player_pos: Vector3 = Vector3.ZERO
var frustrated_cooldown: float = 0.0 # Кулдаун после фрустрации, чтобы сразу не агрился
var hurt_lock_timer: float = 0.0 # Таймер блокировки анимаций

# Animation Blending Vars
var current_movement_blend: float = 0.0
var target_movement_blend: float = 0.0
var is_knocked_back: bool = false
var pending_death: bool = false # Флаг отложенной смерти (чтобы доиграть нокдаун)
var knockback_timer: float = 0.0
# Signals
signal died

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	# Инициализация NavAgent
	nav_agent.max_speed = walk_speed
	state_machine.init(self)
	nav_agent.avoidance_enabled = true
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	# Ждем кадр для инициализации карты навигации
	await get_tree().process_frame
	nav_agent.set_navigation_map(get_world_3d().navigation_map)
	GameEvents.player_died.connect(_on_player_died)
	# Настройка HealthComponent
	if health_component:
		health_component.died.connect(_on_died)
		health_component.health_changed.connect(_on_health_changed)
		
	# Определяем "характер" врага: 30% трусов, 70% храбрецов
	if can_flee:
		can_flee = (randf() <= flee_chance)

func _physics_process(delta: float) -> void:
	# 1. Применяем гравитацию ВСЕГДА, если не на полу
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Если враг в нокбэке (полете от удара)
	if is_knocked_back:
		knockback_timer -= delta
		if knockback_timer <= 0:
			is_knocked_back = false
			# Сбрасываем горизонтальную инерцию при приземлении/окончании
			velocity.x = 0
			velocity.z = 0
			
			# === ОБРАБОТКА ОТЛОЖЕННОЙ СМЕРТИ ===
			if pending_death:
				pending_death = false
				state_machine.change_state(GameConstants.STATE_DEAD)
				if health_bar: health_bar.visible = false
				emit_signal("died")
		
		# В полете работает только гравитация и затухание горизонтальной скорости (трение воздуха)
		velocity.x = move_toward(velocity.x, 0, 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 2.0 * delta)
		
		# Двигаем тело вручную, игнорируя NavAgent
		move_and_slide()
		return # <--- ВАЖНО: Прерываем функцию, чтобы StateMachine не лезла в управление

	# 3. Обычное поведение (управляется через StateMachine -> NavAgent)
	
	if frustrated_cooldown > 0:
		frustrated_cooldown -= delta

	var state_name = state_machine.current_state.name.to_lower()
	if state_name != "chase" and state_name != "patrol":
		# Для Idle/Attack мы просто падаем (гравитация) и применяем остаточную инерцию
		move_and_slide()

# ============================================================================
# MOVEMENT HELPERS (Called by States)
# ============================================================================

## Рассчитывает скорость для движения по пути NavigationAgent
func move_toward_path() -> void:
	if nav_agent.is_navigation_finished():
		nav_agent.set_velocity(Vector3.ZERO)
		return
	
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0
	
	# Устанавливаем velocity агента, это вызовет сигнал velocity_computed
	nav_agent.set_velocity(direction * nav_agent.max_speed)

## Callback от NavigationAgent (RVO Avoidance)
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if is_knocked_back: return
	
	# Небольшая интерполяция, чтобы движение было менее дерганым при столкновениях
	# Но достаточно быстрая (weight 0.2-0.5), чтобы управление было отзывчивым
	var target_vel = safe_velocity
	target_vel.y = velocity.y # Сохраняем гравитацию
	
	velocity = velocity.move_toward(target_vel, 20.0 * get_physics_process_delta_time())
	
	move_and_slide()

## Поворот к цели движения или к игроку

func handle_rotation(delta: float, target_override: Vector3 = Vector3.ZERO, speed_override: float = -1.0) -> void:
	if target_override != Vector3.ZERO:
		if global_position.distance_squared_to(target_override) < 0.01:
			return
	var look_dir: Vector3
	
	if target_override != Vector3.ZERO:
		look_dir = (target_override - global_position).normalized()
	elif velocity.length_squared() > 0.1:
		look_dir = Vector3(velocity.x, 0, velocity.z).normalized()
	else:
		return

	look_dir.y = 0
	if look_dir.is_normalized():
		var current_forward = - global_transform.basis.z.normalized()
		var angle_to_target = current_forward.signed_angle_to(look_dir, Vector3.UP)
		
		# Выбираем, какую скорость использовать
		var current_rotation_speed = speed_override if speed_override > 0 else rotation_speed
		
		var max_rotation_angle = current_rotation_speed * delta
		var rotation_angle = clamp(angle_to_target, -max_rotation_angle, max_rotation_angle)
		
		rotate_y(rotation_angle)

func receive_push(push: Vector3) -> void:
	external_push += push

# ============================================================================
# ANIMATION HELPERS
# ============================================================================
func set_anim_param(param_path: String, value: Variant) -> void:
	anim_tree.set("parameters/" + param_path, value)

func play_animation(anim_name: String, _blend: float = -1.0, _speed: float = 1.0) -> void:
	# Управляем глобальным состоянием дерева
	match anim_name:
		GameConstants.ANIM_ENEMY_DEATH:
			set_anim_param("state/transition_request", "dead")
		GameConstants.ANIM_ENEMY_ANGRY:
			set_anim_param("state/transition_request", "angry")
		GameConstants.ANIM_ENEMY_IDLE, GameConstants.ANIM_ENEMY_WALK, GameConstants.ANIM_ENEMY_RUN:
			set_anim_param("state/transition_request", "alive")
	
	# Для ваншотов (если вдруг вызовут через play_animation)
	if anim_name == GameConstants.ANIM_ENEMY_HIT:
		set_anim_param("hit_oneshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	elif anim_name == GameConstants.ANIM_ENEMY_KNOCKDOWN:
		set_anim_param("knockdown_oneshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func update_movement_animation(delta: float) -> void:
	var local_velocity = global_transform.basis.inverse() * velocity
	var speed_length = velocity.length()
	var state_name = state_machine.current_state.name.to_lower()

	# 1. Рассчитываем целевой бленд
	# Если мы в Idle/Dead/Angry — скорость 0. 
	# (Attack и CombatStance теперь тут, потому что они могут двигаться: отступление или стрейф)
	if state_name not in ["chase", "patrol", "flee", "attack", "combatstance"]:
		target_movement_blend = 0.0
		# HARD SNAP для мгновенной остановки
		current_movement_blend = 0.0
	else:
		# Если патруль завершен — тоже 0
		if state_name == "patrol" and nav_agent.is_navigation_finished():
			target_movement_blend = 0.0
		else:
			# Иначе считаем от реальной скорости
			var h_speed = Vector2(velocity.x, velocity.z).length()
			
			# Нормализованная скорость (0..1)
			var blend_val = clamp(inverse_lerp(0.0, run_speed, h_speed), 0.0, 1.0)
			
			# Если движемся назад (в локальных координатах Z > 0), делаем бленд отрицательным.
			# В BlendSpace: положительные = вперед, отрицательные = назад.
			if local_velocity.z > 0.1:
				target_movement_blend = - blend_val
			else:
				target_movement_blend = blend_val
			
			# Если скорость совсем маленькая — ноль
			if h_speed < 0.1: target_movement_blend = 0.0

	# 2. Плавная интерполяция
	if target_movement_blend == 0.0:
		current_movement_blend = 0.0
	else:
		current_movement_blend = lerp(current_movement_blend, target_movement_blend, walk_run_blend_smoothing * delta)

	# 3. Применяем параметры в дерево
	# Locomotion Blend
	anim_tree.set("parameters/locomotion_blend/blend_position", current_movement_blend)

	# Определяем режим: Strafe или Normal
	# Стрейфим только в CombatStance (или если явно задано)
	var is_strafing = (state_name == "combatstance")
	
	if is_strafing:
		anim_tree.set("parameters/move_mode/transition_request", "strafe")
		
		# Считаем направление стрейфа
		# local.x > 0 (Right), < 0 (Left)
		# Нормализуем относительно скорости ходьбы
		var strafe_val = clamp(local_velocity.x / walk_speed, -1.0, 1.0)
		anim_tree.set("parameters/strafe_blend/blend_position", strafe_val)
	else:
		anim_tree.set("parameters/move_mode/transition_request", "normal")

# ============================================================================
# COMBAT & DAMAGE
# ============================================================================
func take_damage(amount: float, knockback_force: Vector3, is_heavy_attack: bool = false) -> void:
	if is_dead(): return
	
	# Сбрасываем кулдаун фрустрации
	frustrated_cooldown = 0.0
	
	var is_lethal = (health_component.current_health - amount) <= 0
	var is_attacking = state_machine.current_state.name.to_lower() == "attack"

	# --- ЛОГИКА СБИВАНИЯ АТАКИ ---
	if is_lethal:
		if hit_stop_lethal_time_scale < 1.0:
			GameManager.hit_stop_smooth(hit_stop_lethal_time_scale, hit_stop_lethal_duration)
	
	elif not is_lethal:
		if is_heavy_attack:
			# УДАР 3: Полностью сбиваем атаку (Knockdown)
			if is_attacking:
				AIDirector.return_attack_token(self)
				state_machine.change_state(GameConstants.STATE_CHASE)
			
			# !!! TRIGGER KNOCKDOWN ONESHOT
			set_anim_param("knockdown_oneshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			hurt_lock_timer = 0.5
		else:
			# УДАР 1 и 2: Hit Reaction
			if is_attacking:
				# Если атакуем — просто фризим (Stutter), чтобы не сбивать замах полностью
				GameManager.hit_stop_local([anim_player], 0.15)
			else:
				# !!! TRIGGER HIT ONESHOT
				set_anim_param("hit_oneshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
				hurt_lock_timer = 0.2

	# Остальной код (VFX, Health, Flash)
	VfxPool.spawn_effect(0, global_position + Vector3(0, 1.5, 0))
	$HitFlash.flash()
	if sfx_hurt_voice: sfx_hurt_voice.play_random()
	if sfx_flesh_hit: sfx_flesh_hit.play_random()
	
	if health_component:
		health_component.take_damage(amount)
	
	# Применяем отталкивание
	if knockback_force.length() > 0.5:
		velocity = knockback_force
		is_knocked_back = true
		knockback_timer = 0.2

func _on_died() -> void:
	# Если мы сейчас летим в нокдауне, откладываем смерть до приземления
	if is_knocked_back:
		pending_death = true
		return

	AIDirector.return_attack_token(self)
	emit_signal("died")
	# Скрываем бар через компонент
	if health_bar:
		health_bar.visible = false
	state_machine.change_state(GameConstants.STATE_DEAD)

# Animation Event Call
func _check_attack_hit() -> void:
	var hits_found = false
	if punch_hand_r and _check_single_hand_hit(punch_hand_r):
		hits_found = true
	if not hits_found and punch_hand_l:
		_check_single_hand_hit(punch_hand_l)

func _check_single_hand_hit(hand_area: Area3D) -> bool:
	if not hand_area.monitoring: return false
	
	# Проверка конуса атаки (чтобы не бить спиной)
	if punch_area:
		var valid_targets = punch_area.get_overlapping_bodies()
		if not valid_targets.has(player):
			return false

	var bodies = hand_area.get_overlapping_bodies()
	for body in bodies:
		if body == player:
			var knockback_dir = (player.global_position - global_position).normalized()
			knockback_dir.y = 0.5
			knockback_dir = knockback_dir.normalized() * knockback_strength
			
			if player.has_method("take_damage"):
				player.take_damage(1.0, knockback_dir)
				return true
	return false

# ============================================================================
# UI & MISC
# ============================================================================

func _on_health_changed(new_health: float) -> void:
	if health_bar and health_component:
		health_bar.update_health(new_health, health_component.get_max_health())
	
	# !!! НОВЫЙ ТРИГГЕР БЕГСТВА !!!
	if not can_flee: return
	
	var max_hp = health_component.get_max_health()
	if max_hp <= 0: return
	
	# Проверяем, не мертвы ли мы уже и не убегаем ли уже
	var current_state_name = state_machine.current_state.name.to_lower()
	if current_state_name == "dead" or current_state_name == "flee":
		return
	
	# Если здоровье упало ниже порога, переходим в состояние бегства
	if (new_health / max_hp) <= flee_health_threshold:
		state_machine.change_state("flee")
		
func _on_player_died() -> void:
	# 1. Если враг уже мертв, ему всё равно
	if state_machine.current_state.name.to_lower() == GameConstants.STATE_DEAD:
		return

	# 2. Сбрасываем ссылку на игрока, чтобы VisionComponent не триггерился
	# (Хотя удаление из группы уже помогает, это двойная защита)
	player = null
	
	# 3. Сбрасываем агрессию в компоненте атаки (если там есть логика)
	if attack_component.has_method("clear_retreat_state"):
		attack_component.clear_retreat_state()

	# 4. Принудительно меняем состояние на Патруль или Idle
	# Если мы сейчас в Chase или Attack - это прервет их.
	state_machine.change_state(GameConstants.STATE_PATROL)
	
	# Опционально: Можно проиграть анимацию "Победы" или просто постоять
	# state_machine.change_state(GameConstants.STATE_IDLE)
func is_dead() -> bool:
	if state_machine and state_machine.current_state:
		return state_machine.current_state.name.to_lower() == GameConstants.STATE_DEAD
	return false
