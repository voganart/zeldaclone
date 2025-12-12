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

@export_group("Movement")
@export var walk_speed: float = 1.5
@export var run_speed: float = 3.5
@export var rotation_speed: float = 6.0
@export var gravity: float = 100.0
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
@onready var vfx_pull: Node3D = $"../../../VfxPull" # Adjust path as needed
@onready var player: Node3D = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
@onready var patrol_zone: Area3D = get_parent() as Area3D

# UI References
@onready var health_bar: EnemyHealthBar = $HealthBar3D

# ============================================================================
# SHARED DATA (Accessible by States)
# ============================================================================
var vertical_velocity: float = 0.0
var external_push: Vector3 = Vector3.ZERO
var last_known_player_pos: Vector3 = Vector3.ZERO
var frustrated_cooldown: float = 0.0 # Кулдаун после фрустрации, чтобы сразу не агрился

# Animation Blending Vars
var current_movement_blend: float = 0.0
var target_movement_blend: float = 0.0

# Signals
signal died

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	# Инициализация NavAgent
	nav_agent.max_speed = walk_speed
	nav_agent.avoidance_enabled = true
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	
	# Ждем кадр для инициализации карты навигации
	await get_tree().process_frame
	nav_agent.set_navigation_map(get_world_3d().navigation_map)

	# Настройка HealthComponent
	if health_component:
		health_component.died.connect(_on_died)
		health_component.health_changed.connect(_on_health_changed)

func _physics_process(delta: float) -> void:
	# Гравитация применяется всегда
	if not is_on_floor():
		velocity.y -= gravity * delta
	vertical_velocity = velocity.y
	
	if frustrated_cooldown > 0:
		frustrated_cooldown = max(frustrated_cooldown - delta, 0.0)
		
	var state_name = state_machine.current_state.name.to_lower()
	if state_name != "chase" and state_name != "patrol":
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
	# Если мертв или в нокдауне, управление физикой может отличаться
	# (Логика нокбэка может быть вынесена в состояние KnockbackState)
	velocity.x = safe_velocity.x + external_push.x
	velocity.z = safe_velocity.z + external_push.z
	velocity.y = vertical_velocity # Сохраняем гравитацию
	
	move_and_slide()
	
	vertical_velocity = velocity.y
	# Затухание внешнего толчка
	external_push = external_push.lerp(Vector3.ZERO, 0.1)

## Поворот к цели движения или к игроку
func handle_rotation(delta: float, target_override: Vector3 = Vector3.ZERO) -> void:
	var look_dir = Vector3.ZERO
	
	if target_override != Vector3.ZERO:
		look_dir = (target_override - global_position).normalized()
	elif velocity.length_squared() > 0.1:
		look_dir = velocity.normalized()
	
	look_dir.y = 0
	if look_dir.length() > 0.001:
		var target_angle = atan2(look_dir.x, look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, delta * rotation_speed)

func receive_push(push: Vector3) -> void:
	external_push += push

# ============================================================================
# ANIMATION HELPERS
# ============================================================================
func play_animation(anim_name: String, blend: float = -1.0, speed: float = 1.0) -> void:
	if anim_player.current_animation == anim_name:
		# Если уже играет, можно обновить параметры, но не перезапускать
		# anim_player.play(anim_name, blend, speed) 
		return
	anim_player.play(anim_name, blend, speed)

func update_movement_animation(delta: float) -> void:
	var speed_2d := Vector2(velocity.x, velocity.z).length()
	var blend = inverse_lerp(walk_run_blend_start_speed, walk_run_blend_end_speed, speed_2d)
	target_movement_blend = clamp(blend, 0.0, 1.0)
	current_movement_blend = lerp(current_movement_blend, target_movement_blend, walk_run_blend_smoothing * delta)

	if speed_2d > 0.1:
		if current_movement_blend < 0.5:
			var walk_scale = clamp(speed_2d / walk_speed, 0.5, 1.5) if walk_speed > 0 else 1.0
			play_animation(GameConstants.ANIM_ENEMY_WALK, 0.2, walk_scale)
		else:
			var run_scale = clamp(speed_2d / run_speed, 0.5, 1.5) if run_speed > 0 else 1.0
			play_animation(GameConstants.ANIM_ENEMY_RUN, 0.2, run_scale)
	else:
		play_animation(GameConstants.ANIM_ENEMY_IDLE, 0.2, 1.0)

# ============================================================================
# COMBAT & DAMAGE
# ============================================================================
func take_damage(amount: float, knockback_force: Vector3) -> void:
	# Если уже мертв, игнорируем
	if state_machine.current_state.name.to_lower() == GameConstants.STATE_DEAD:
		return

	if vfx_pull:
		vfx_pull.spawn_effect(0, global_position + Vector3(0, 1.5, 0))
	
	$HitFlash.flash()
	
	if health_component:
		health_component.take_damage(amount)
	
	# Обработка нокбэка через смену состояния
	if knockback_force.length() > 0.1:
		velocity += knockback_force
		# Переход в состояние Knockback (если оно есть)
		# state_machine.change_state("knockback") 
		# Пока что просто применяем импульс, состояние Chase/Patrol обработает это

func _on_died() -> void:
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
