class_name Enemy
extends CharacterBody3D

## ============================================================================
## ENEMY CONTROLLER (REFACTORED)
## ============================================================================

# ============================================================================
# EXPORTS
# ============================================================================
@export_group("Debug")
@export var show_debug_label: bool = true

@export_group("Components")
@export var punch_hand_r: Area3D
@export var punch_hand_l: Area3D
@export var punch_area: Area3D # Конус атаки (опционально)

@export_group("AI Settings")
@export var can_flee: bool = true
@export_range(0.0, 1.0) var flee_health_threshold: float = 0.25
@export_range(0.0, 1.0) var flee_chance: float = 0.3
@export var help_radius: float = 15.0 ## Радиус призыва помощи

@export_group("Hit Stop Settings")
@export var hit_stop_lethal_time_scale: float = 0.5
@export var hit_stop_lethal_duration: float = 0.2
@export var hit_stop_local_duration: float = 0.08

# Настройки движения теперь проксируются или используются компонентом, 
# но для удобства настройки в инспекторе врага оставляем их здесь, 
# а в _ready передадим их компоненту или будем использовать напрямую.
@export_group("Movement Stats")
@export var walk_speed: float = 1.5
@export var run_speed: float = 3.5
@export var retreat_speed: float = 2.5
# rotation_speed берется из MovementComponent, но можно переопределить
@export var combat_rotation_speed: float = 20.0
@export var attack_rotation_speed: float = 2.0 
@export_range(0, 180) var strafe_view_angle: float = 45.0

@export var knockback_strength: float = 2.0
@export var knockback_duration: float = 0.5

@export_group("Animation Blending")
@export var walk_run_blend_smoothing: float = 8.0

# ============================================================================
# NODE REFERENCES
# ============================================================================
# --- НОВЫЕ КОМПОНЕНТЫ ---
@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var anim_controller: AnimationController = $Components/AnimationController
# ------------------------

@onready var debug_label: Label3D = $DebugLabel
@onready var state_machine: StateMachine = $StateMachine
@onready var vision_component: VisionComponent = $VisionComponent
@onready var attack_component: EnemyAttackComponent = $EnemyAttackComponent
@onready var health_component: Node = $Components/HealthComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

@onready var anim_player: AnimationPlayer = $Monstr/AnimationPlayer
# AnimationTree теперь управляется через anim_controller, прямая ссылка не нужна, 
# но оставим для старых проверок если они есть (лучше удалить позже)
@onready var anim_tree: AnimationTree = $Monstr/AnimationTree 

var vfx_pull: Node3D
@onready var player: Node3D = get_tree().get_first_node_in_group(GameConstants.GROUP_PLAYER)
@onready var patrol_zone: Area3D = get_parent() as Area3D
@onready var sfx_hurt_voice: RandomAudioPlayer3D = $SoundBank/SfxHurtVoice
@onready var sfx_flesh_hit: RandomAudioPlayer3D = $SoundBank/SfxFleshHit
@onready var sfx_death_impact: RandomAudioPlayer3D = $SoundBank/SfxDeathImpact
@onready var health_bar: EnemyHealthBar = $HealthBar3D

# ============================================================================
# SHARED DATA
# ============================================================================
var last_known_player_pos: Vector3 = Vector3.ZERO
var frustrated_cooldown: float = 0.0
var hurt_lock_timer: float = 0.0

var current_movement_blend: float = 0.0
var is_knocked_back: bool = false
var pending_death: bool = false
var knockback_timer: float = 0.0

# Используется для навигации
var _desired_velocity: Vector3 = Vector3.ZERO

signal died

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	# Инициализация компонента движения
	movement_component.init(self)
	# Настраиваем базовую скорость вращения из компонента
	movement_component.rotation_speed = 6.0 
	
	nav_agent.max_speed = walk_speed
	nav_agent.avoidance_enabled = true
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	
	if not is_in_group(GameConstants.GROUP_ENEMIES):
		add_to_group(GameConstants.GROUP_ENEMIES)
	
	state_machine.init(self)
	
	await get_tree().process_frame
	nav_agent.set_navigation_map(get_world_3d().navigation_map)
	GameEvents.player_died.connect(_on_player_died)
	
	if health_component:
		health_component.died.connect(_on_died)
		health_component.health_changed.connect(_on_health_changed)
		
	if can_flee:
		can_flee = (randf() <= flee_chance)

	# Инициализация анимации через контроллер
	if anim_tree: anim_tree.active = true # На всякий случай
	set_tree_state("alive")
	set_move_mode("normal")

func _physics_process(delta: float) -> void:
	if show_debug_label and debug_label:
		debug_label.visible = true
		_update_debug_info()
	elif debug_label:
		debug_label.visible = false
		
	# Гравитация через компонент
	movement_component.apply_gravity(delta)

	# Обработка нокбэка
	if is_knocked_back:
		if knockback_timer > 0:
			knockback_timer -= delta
		
		# Затухание инерции
		velocity.x = move_toward(velocity.x, 0, 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 2.0 * delta)
		
		move_and_slide()
		
		if knockback_timer <= 0 and is_on_floor():
			is_knocked_back = false
			velocity = Vector3.ZERO
			if pending_death:
				_finalize_death()
		return

	if frustrated_cooldown > 0:
		frustrated_cooldown -= delta

	# Движение управляется стейтами через NavigationAgent
	# NavigationAgent вызывает _on_velocity_computed, где мы применяем скорость
	var state_name = state_machine.current_state.name.to_lower()
	if state_name != "dead":
		move_and_slide()
		
	# Толкание других объектов (если нужно)
	movement_component.handle_pushing(false)

# ============================================================================
# MOVEMENT HELPERS
# ============================================================================
func move_toward_path() -> void:
	if nav_agent.is_navigation_finished():
		nav_agent.set_velocity(Vector3.ZERO)
		return
	
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0
	
	# Мы просто устанавливаем желаемую скорость для агента навигации.
	# Реальное движение произойдет в callback _on_velocity_computed
	nav_agent.set_velocity(direction * nav_agent.max_speed)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if is_knocked_back: return
	
	# Сохраняем вертикальную скорость (гравитацию)
	var target_vel = safe_velocity
	target_vel.y = velocity.y
	
	# Плавное движение
	velocity = velocity.move_toward(target_vel, 20.0 * get_physics_process_delta_time())

func handle_rotation(delta: float, target_override: Vector3 = Vector3.ZERO, speed_override: float = -1.0) -> void:
	var look_dir: Vector2 = Vector2.ZERO
	
	if target_override != Vector3.ZERO:
		var dir_3d = (target_override - global_position).normalized()
		look_dir = Vector2(dir_3d.x, dir_3d.z)
	elif velocity.length_squared() > 0.1:
		look_dir = Vector2(velocity.x, velocity.z).normalized()
	else:
		return

	var current_speed = speed_override if speed_override > 0 else movement_component.rotation_speed
	
	# Используем компонент для поворота
	if look_dir.length_squared() > 0.001:
		var target_angle = atan2(look_dir.x, look_dir.y)
		rotation.y = lerp_angle(rotation.y, target_angle, current_speed * delta)

func receive_push(push: Vector3) -> void:
	velocity += push

# ============================================================================
# ANIMATION CONTROLLER WRAPPERS
# ============================================================================
func set_tree_state(state_name: String):
	anim_controller.set_state(state_name)

func set_move_mode(mode_name: String):
	anim_controller.set_move_mode(mode_name)

func set_locomotion_blend(value: float):
	anim_controller.set_locomotion_blend(value)
	# Враг использует один параметр для blend_position и в Locomotion, и в Chase
	# AnimationController имеет метод set_locomotion_blend который ставит "parameters/locomotion_blend/blend_position"
	# Если у тебя в дереве есть "parameters/chase_blend/blend_position", нужно добавить это в контроллер или оставить ручной set здесь
	# Пока оставим как было, через anim_tree, если параметр нестандартный, 
	# ИЛИ лучше добавить метод в AnimationController.
	# Для совместимости используем anim_tree напрямую для нестандартных параметров:
	anim_tree.set("parameters/chase_blend/blend_position", value)

func set_strafe_blend(value: float):
	# То же самое, если strafe_blend нет в контроллере
	anim_tree.set("parameters/strafe_blend/blend_position", value)

func trigger_attack_oneshot(attack_name: String):
	# Преобразуем имя анимации в индекс (Attack1, Attack2)
	var idx = 0
	if "2" in attack_name: idx = 1
	if "3" in attack_name: idx = 2
	anim_controller.trigger_attack(idx)

func trigger_hit_oneshot():
	anim_controller.trigger_hit()

func trigger_knockdown_oneshot():
	# Этого метода нет в AnimationController, добавим вызов напрямую или расширим контроллер.
	# Для скорости используем прямой вызов:
	anim_tree.set(GameConstants.TREE_ONE_SHOT_KNOCKDOWN, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	# Но лучше потом добавить func trigger_knockdown() в AnimationController

func trigger_angry_seek(time: float):
	anim_tree.set(GameConstants.TREE_ANGRY_SEEK, time)

func update_movement_animation(delta: float) -> void:
	var current_state_name = state_machine.current_state.name.to_lower()
	var speed_length = velocity.length()

	var should_force_idle = is_knocked_back or current_state_name == "hit"
	if current_state_name == "attack" and speed_length < 0.5:
		should_force_idle = true

	if should_force_idle:
		current_movement_blend = move_toward(current_movement_blend, 0.0, delta * 5.0)
		set_locomotion_blend(current_movement_blend)
		return

	var local_velocity = global_transform.basis.inverse() * velocity
	
	if current_state_name == "combatstance":
		var strafe_val = clamp(local_velocity.x / walk_speed, -1.0, 1.0)
		set_strafe_blend(-strafe_val) 
	else:
		var target_val = 0.0
		var is_moving_backwards = local_velocity.z < -0.1
		
		if speed_length < 0.1:
			target_val = 0.0
		else:
			if is_moving_backwards:
				var back_intensity = clamp(speed_length / walk_speed, 0.0, 1.0)
				target_val = -back_intensity 
			else:
				if speed_length <= walk_speed * 1.2:
					target_val = clamp(speed_length / walk_speed, 0.0, 1.0)
				else:
					target_val = 1.0 + clamp((speed_length - walk_speed) / (run_speed - walk_speed), 0.0, 1.0)

		current_movement_blend = lerp(current_movement_blend, target_val, walk_run_blend_smoothing * delta)
		set_locomotion_blend(current_movement_blend)

# ============================================================================
# COMBAT & DAMAGE
# ============================================================================
func take_damage(amount: float, knockback_force: Vector3, is_heavy_attack: bool = false) -> void:
	if is_dead(): return
	frustrated_cooldown = 0.0
	
	_cry_for_help()
	
	var is_lethal = (health_component.current_health - amount) <= 0
	var is_attacking = state_machine.current_state.name.to_lower() == "attack"

	if is_lethal:
		if hit_stop_lethal_time_scale < 1.0:
			GameManager.hit_stop_smooth(hit_stop_lethal_time_scale, hit_stop_lethal_duration)
	else:
		if is_attacking:
			GameManager.hit_stop_local([anim_player], 0.15)
	
	if is_lethal:
		# Прямой доступ к параметру дерева для нокдауна, так как в контроллере его пока нет
		anim_tree.set("parameters/knockdown_oneshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		hurt_lock_timer = 0.5
	elif not is_lethal:
		if is_heavy_attack:
			if is_attacking:
				AIDirector.return_attack_token(self)
				state_machine.change_state(GameConstants.STATE_CHASE)
			anim_tree.set("parameters/knockdown_oneshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			hurt_lock_timer = 0.5
		else:
			if not is_attacking:
				trigger_hit_oneshot()
				hurt_lock_timer = 0.2

	VfxPool.spawn_effect(0, global_position + Vector3(0, 1.5, 0))
	$HitFlash.flash()
	if sfx_hurt_voice: sfx_hurt_voice.play_random()
	if sfx_flesh_hit: sfx_flesh_hit.play_random()
	
	if health_component:
		health_component.take_damage(amount)
		
	state_machine.current_state.on_damage_taken(is_heavy_attack)
	
	var final_force = knockback_force
	
	if is_lethal:
		if final_force.length() < 1.0:
			final_force = -global_transform.basis.z * 5.0
		final_force.y = max(final_force.y, 6.0) 
		
		var horiz = Vector2(final_force.x, final_force.z)
		if horiz.length() < 3.0:
			horiz = horiz.normalized() * 5.0
			final_force.x = horiz.x
			final_force.z = horiz.y

	if final_force.length() > 0.5:
		velocity = final_force
		is_knocked_back = true
		knockback_timer = 0.2 

func _cry_for_help() -> void:
	var enemies = get_tree().get_nodes_in_group(GameConstants.GROUP_ENEMIES)
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead():
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= help_radius:
			enemy.hear_alert(player)

func hear_alert(target: Node3D) -> void:
	if is_dead(): return
	var current_state = state_machine.current_state.name.to_lower()
	if current_state in ["attack", "chase", "combatstance", "hit", "dead"]:
		return
	print(name, " heard call for help!")
	state_machine.change_state(GameConstants.STATE_CHASE)

func _on_died() -> void:
	if is_knocked_back:
		pending_death = true
		return
	_finalize_death()

func _finalize_death() -> void:
	pending_death = false
	AIDirector.return_attack_token(self)
	emit_signal("died")
	if health_bar: health_bar.visible = false
	state_machine.change_state(GameConstants.STATE_DEAD)

# --- ПРОВЕРКА АТАКИ ---
# Враг использует старую систему Area3D для атаки (punch_hand_r),
# пока не перешли на CombatComponent полностью.
func _check_attack_hit() -> void:
	var hits_found = false
	if punch_hand_r and _check_single_hand_hit(punch_hand_r): hits_found = true
	if not hits_found and punch_hand_l: _check_single_hand_hit(punch_hand_l)

func _check_single_hand_hit(hand_area: Area3D) -> bool:
	if not hand_area.monitoring: return false
	
	# Проверка конуса атаки
	if punch_area:
		var valid_targets = punch_area.get_overlapping_bodies()
		if not valid_targets.has(player): return false

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
func _on_health_changed(new_health: float, _max_hp: float) -> void:
	if health_bar and health_component:
		health_bar.update_health(new_health, health_component.get_max_health())
	
	if not can_flee: return
	var max_hp = health_component.get_max_health()
	if max_hp <= 0: return
	
	var current_state_name = state_machine.current_state.name.to_lower()
	if current_state_name == "dead" or current_state_name == "flee": return
	
	if (new_health / max_hp) <= flee_health_threshold:
		state_machine.change_state("flee")
		
func _on_player_died() -> void:
	if state_machine.current_state.name.to_lower() == GameConstants.STATE_DEAD: return
	player = null
	if attack_component.has_method("clear_retreat_state"):
		attack_component.clear_retreat_state()
	state_machine.change_state(GameConstants.STATE_PATROL)

func is_dead() -> bool:
	if state_machine and state_machine.current_state:
		return state_machine.current_state.name.to_lower() == GameConstants.STATE_DEAD
	return false

func _update_debug_info() -> void:
	var state_name = "None"
	if state_machine.current_state:
		state_name = state_machine.current_state.name
	
	# Получаем напрямую из дерева, так как контроллер не хранит состояние
	var raw_move_mode = anim_tree.get("parameters/move_mode/transition_request")
	var move_mode_idx = 0
	if typeof(raw_move_mode) == TYPE_INT:
		move_mode_idx = raw_move_mode
	
	var move_mode_str = "Normal"
	if move_mode_idx == 1: move_mode_str = "Strafe"
	elif move_mode_idx == 2: move_mode_str = "Chase"
	
	var hp = 0
	if health_component: hp = ceil(health_component.current_health)
	
	debug_label.text = "State: %s\nMode: %s\nHP: %d" % [state_name, move_mode_str, hp]
	
	if state_name.to_lower() == "attack": debug_label.modulate = Color.RED
	elif state_name.to_lower() == "chase": debug_label.modulate = Color.ORANGE
	elif state_name.to_lower() == "patrol": debug_label.modulate = Color.GREEN
	else: debug_label.modulate = Color.WHITE
