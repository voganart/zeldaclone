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
@export var hit_stop_lethal_time_scale: float = 0.15
## Длительность замедления при смерти
@export var hit_stop_lethal_duration: float = 0.5
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
func play_animation(anim_name: String, blend: float = -1.0, speed: float = 1.0) -> void:
	# Если эта анимация уже играет - ничего не делаем, чтобы не сбрасывать её каждый кадр
	if anim_player.current_animation == anim_name:
		return
	
	# Запускаем анимацию
	anim_player.play(anim_name, blend, speed)
	
	# --- ГЛОБАЛЬНАЯ РАНДОМИЗАЦИЯ ---
	if anim_player.has_animation(anim_name):
		var anim_resource = anim_player.get_animation(anim_name)
		# Не рандомизируем слишком короткие анимации (например, получение урона)
		if anim_resource.length > 0.2:
			var random_start = randf() * anim_resource.length
			anim_player.seek(random_start, true)
			
			# Микро-сдвиг скорости (от 0.95 до 1.05)
			# Чтобы даже зацикленные анимации со временем расходились по фазе
			anim_player.speed_scale = randf_range(0.95, 1.05)

func update_movement_animation(delta: float) -> void:
	var speed_length = velocity.length()
	
	# 1. Если почти стоим — играем Idle
	if speed_length < 0.1:
		play_animation(GameConstants.ANIM_ENEMY_IDLE, 0.2, 1.0)
		return

	# 2. Переводим глобальную скорость в локальное пространство врага
	# basis.inverse() * vector позволяет узнать скорость с точки зрения самого врага
	var local_velocity = global_transform.basis.inverse() * velocity
	
	# local_velocity.x -> (+) Вправо, (-) Влево
	# local_velocity.z -> (-) Вперед, (+) Назад (в Godot -Z это вперед)
	
	# 3. Определяем, какое движение доминирует: продольное (бег) или поперечное (стрейф)
	# Добавляем небольшой порог (bias), чтобы при легком повороте он не срывался в стрейф
	var is_strafing = abs(local_velocity.x) > abs(local_velocity.z)
	
	if is_strafing:
		# --- ЛОГИКА СТРЕЙФА ---
		# Нормализуем скорость анимации под скорость движения
		var strafe_anim_speed = clamp(speed_length / walk_speed, 0.8, 1.5)
		
		if local_velocity.x > 0:
			play_animation(GameConstants.ANIM_ENEMY_STRAFE_R, 0.2, strafe_anim_speed)
		else:
			play_animation(GameConstants.ANIM_ENEMY_STRAFE_L, 0.2, strafe_anim_speed)
			
	else:
		# --- ЛОГИКА ДВИЖЕНИЯ ВПЕРЕД (Бег/Ходьба) ---
		
		# Если вдруг он пятится назад (Z > 0)
		if local_velocity.z > 0.1: 
			# Если есть анимация ходьбы назад — вставь её сюда. Если нет — Walk с реверсом или просто Walk
			# play_animation("Monstr_walk_back", 0.2, 1.0)
			play_animation(GameConstants.ANIM_ENEMY_WALK, 0.2, 1.0) # Временная заглушка
		else:
			# Обычный бег вперед с блендингом
			var blend = inverse_lerp(walk_run_blend_start_speed, walk_run_blend_end_speed, speed_length)
			target_movement_blend = clamp(blend, 0.0, 1.0)
			current_movement_blend = lerp(current_movement_blend, target_movement_blend, walk_run_blend_smoothing * delta)

			if current_movement_blend < 0.5:
				var walk_scale = clamp(speed_length / walk_speed, 0.5, 1.5) if walk_speed > 0 else 1.0
				play_animation(GameConstants.ANIM_ENEMY_WALK, 0.2, walk_scale)
			else:
				var run_scale = clamp(speed_length / run_speed, 0.5, 1.5) if run_speed > 0 else 1.0
				play_animation(GameConstants.ANIM_ENEMY_RUN, 0.2, run_scale)
# ============================================================================
# COMBAT & DAMAGE
# ============================================================================
func take_damage(amount: float, knockback_force: Vector3, is_heavy_attack: bool = false) -> void:
	if state_machine.current_state.name.to_lower() == GameConstants.STATE_DEAD:
		return
	frustrated_cooldown = 0.0 
	# --- ЛОГИКА СМЕРТЕЛЬНОГО УДАРА ---
	# Проверяем, убьет ли этот удар врага
	var current_hp = health_component.get_health()
	var is_lethal = (current_hp - amount) <= 0
	
	# === ФИКС ПРОБЛЕМЫ 1: Точное определение нокдауна ===
	# Нокдаун если это Финишер/Слэм (Heavy) ИЛИ сила подбрасывания реальная (> 2.0)
	var is_knockdown = is_heavy_attack or (knockback_force.y > 2.0)
	var is_attacking = state_machine.current_state.name.to_lower() == "attack"
	if sfx_hurt_voice: sfx_hurt_voice.play_random()
	# --- 1. АНИМАЦИЯ ---
	if not is_lethal:
		if is_knockdown:
			anim_player.play(GameConstants.ANIM_ENEMY_KNOCKDOWN, 0.0, 1.0)
			hurt_lock_timer = 0.3
			anim_player.advance(0)
		elif is_attacking:
			# "Layered Hit": Если враг атакует, не сбиваем анимацию, но даем фриз (см. ниже)
			# Можно добавить короткий таймер, чтобы нельзя было спамить
			pass
		else:
			anim_player.play(GameConstants.ANIM_ENEMY_HIT, 0.1, 1.0)
			hurt_lock_timer = 0.15
			anim_player.advance(0)
	
	# --- 2. VFX и Камера ---
	if is_lethal:
		if sfx_death_impact: sfx_death_impact.play_random()
		get_tree().call_group("camera_shaker", "add_trauma", 0.8)
	elif is_heavy_attack:
		get_tree().call_group("camera_shaker", "add_trauma", 0.6)
	else:
		get_tree().call_group("camera_shaker", "add_trauma", 0.2)
		if sfx_flesh_hit: sfx_flesh_hit.play_random()
		if sfx_hurt_voice: sfx_hurt_voice.play_random()
	
	VfxPool.spawn_effect(0, global_position + Vector3(0, 1.5, 0))
	$HitFlash.flash()

	# --- 3. HIT STOP ---
	if is_lethal:
		GameManager.hit_stop_smooth(hit_stop_lethal_duration, hit_stop_lethal_time_scale, 0.0, 0.3)
	elif is_knockdown:
		# При нокдауне полагаемся на глобальный фриз игрока
		pass
	else:
		# Для обычных ударов и для "layered" ударов во время атаки
		GameManager.hit_stop_local([anim_player], hit_stop_local_duration)
	
	AIDirector.return_attack_token(self)
	
	if health_component:
		health_component.take_damage(amount)
		
	if state_machine and state_machine.current_state:
		state_machine.current_state.on_damage_taken()
		
	if knockback_force.length() > 0.5:
		velocity = knockback_force # Заменяем скорость, чтобы был резкий рывок
		if is_heavy_attack or knockback_force.y > 5.0:
			is_knocked_back = true
			knockback_timer = 0.1 # Чуть больше полсекунды на полет
			# NavAgent нужно сбросить, чтобы он не тянул к цели
			nav_agent.set_velocity(Vector3.ZERO)

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
	
	# Проверка конуса атаки
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
