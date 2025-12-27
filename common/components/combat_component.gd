class_name CombatComponent
extends Node

# --- НАСТРОЙКИ КОМБО И ТАЙМИНГОВ ---
@export_group("Combat Timing")
@export var primary_attack_speed: float = 0.8
@export var attack_cooldown: float = 0.15
@export var combo_window_time: float = 2.0
@export var combo_cooldown_after_combo: float = 0.5

# --- НАСТРОЙКИ ОТТАЛКИВАНИЯ (KNOCKBACK) ---
@export_group("Knockback Settings")
@export_subgroup("Normal Hit (1 & 2)")
@export var kb_strength_normal: float = 4.0 
@export var kb_height_normal: float = 2.0   

@export_subgroup("Finisher (3)")
@export var kb_strength_finisher: float = 10.0 
@export var kb_height_finisher: float = 6.0    

# --- НАСТРОЙКИ HIT STOP (JUICE) ---
@export_group("Hit Stop Settings")
@export_subgroup("Props")
@export var hs_prop_time_scale: float = 0.1 
@export var hs_prop_duration: float = 0.02 

@export_subgroup("Enemy: Normal")
@export var hs_normal_time_scale: float = 0.1
@export var hs_normal_duration: float = 0.04

@export_subgroup("Enemy: Finisher")
@export var hs_finisher_time_scale: float = 0.1
@export var hs_finisher_duration: float = 0.08

@export_subgroup("Enemy: Kill")
@export var hs_lethal_time_scale: float = 0.05
@export var hs_lethal_duration: float = 0.15

# --- ССЫЛКИ НА ХИТБОКСЫ (Назначь в инспекторе!) ---
@export_group("Hitboxes")
@export var punch_hand_r: Area3D
@export var punch_hand_l: Area3D
@export var attack_area: Area3D 

# --- ВНУТРЕННИЕ ПЕРЕМЕННЫЕ ---
var actor: CharacterBody3D

var is_attacking: bool = false
var can_attack: bool = true
var combo_count: int = 0
var current_attack_damage: float = 1.0

# Параметры текущего удара
var current_knockback_strength: float = 0.0 
var current_knockback_height: float = 0.0
var current_attack_knockback_enabled: bool = true
var has_hyper_armor: bool = false 

# Таймеры
var combo_reset_timer: Timer
var combo_cooldown_timer: Timer
var attack_interval_timer: Timer

var hit_enemies_current_attack: Dictionary = {}
var hitbox_active_timer: float = 0.0

func _ready() -> void:
	# Создаем таймеры программно
	combo_reset_timer = Timer.new()
	combo_reset_timer.one_shot = true
	combo_reset_timer.wait_time = combo_window_time
	combo_reset_timer.timeout.connect(func(): combo_count = 0)
	add_child(combo_reset_timer)
	
	combo_cooldown_timer = Timer.new()
	combo_cooldown_timer.one_shot = true
	combo_cooldown_timer.wait_time = combo_cooldown_after_combo
	combo_cooldown_timer.timeout.connect(func():
		print("Combo cooldown ended")
		can_attack = true
	)
	add_child(combo_cooldown_timer)
	
	attack_interval_timer = Timer.new()
	attack_interval_timer.one_shot = true
	attack_interval_timer.timeout.connect(func():
		# Если не в глобальном кулдауне после комбо, разрешаем атаку
		if combo_cooldown_timer.is_stopped():
			can_attack = true
	)
	add_child(attack_interval_timer)

func init(character: CharacterBody3D) -> void:
	actor = character

func _physics_process(delta: float) -> void:
	if hitbox_active_timer > 0:
		hitbox_active_timer -= delta
		_process_hitbox_check()

# --- УПРАВЛЕНИЕ АТАКОЙ ---

func start_attack_sequence() -> void:
	is_attacking = true
	can_attack = false
	combo_reset_timer.stop()
	
	# Сброс списков попаданий
	hitbox_active_timer = 0.0
	hit_enemies_current_attack.clear()

func end_attack_sequence() -> void:
	_stop_hitbox_monitoring()
	is_attacking = false
	combo_count += 1
	
	# Логика завершения серии
	if combo_count >= 3:
		# Финишер был нанесен
		can_attack = false
		combo_cooldown_timer.start(combo_cooldown_after_combo)
		combo_count = 0 # Сброс сразу или после таймера? Обычно сразу.
	else:
		# Обычный удар
		can_attack = false
		attack_interval_timer.start(attack_cooldown)
		combo_reset_timer.start() # Если игрок не ударит снова, комбо сбросится

func configure_attack_parameters(damage: float, is_finisher: bool, hyper_armor: bool) -> void:
	current_attack_damage = damage
	has_hyper_armor = hyper_armor
	
	if is_finisher:
		current_knockback_strength = kb_strength_finisher
		current_knockback_height = kb_height_finisher
	else:
		current_knockback_strength = kb_strength_normal
		current_knockback_height = kb_height_normal

# --- ХИТБОКСЫ И УРОН ---

func start_hitbox_monitoring() -> void:
	hit_enemies_current_attack.clear()
	if punch_hand_r: punch_hand_r.monitoring = true
	if punch_hand_l: punch_hand_l.monitoring = true

func _stop_hitbox_monitoring() -> void:
	hit_enemies_current_attack.clear()
	if punch_hand_r: punch_hand_r.set_deferred("monitoring", false)
	if punch_hand_l: punch_hand_l.set_deferred("monitoring", false)

## Вызывается из AnimationPlayer или Player.gd, чтобы "включить" проверку на N секунд
func activate_hitbox_check(duration: float = 0.1) -> void:
	hitbox_active_timer = duration
	_process_hitbox_check()

func _process_hitbox_check() -> void:
	var hits_occurred = false
	if punch_hand_r: hits_occurred = _check_hand_overlap(punch_hand_r) or hits_occurred
	if punch_hand_l: hits_occurred = _check_hand_overlap(punch_hand_l) or hits_occurred

func _check_hand_overlap(hand: Area3D) -> bool:
	if not hand.monitoring: return false

	# Лимиты целей за один кадр/удар
	var max_enemies = 1
	var max_props = 1
	var enemies_hit = 0
	var props_hit = 0
	
	# Считаем уже ударенных
	for type in hit_enemies_current_attack.values():
		if type == "enemy": enemies_hit += 1
		elif type == "prop": props_hit += 1
	
	if enemies_hit >= max_enemies and props_hit >= max_props:
		return false

	var candidates_enemies: Array[Node3D] = []
	var candidates_props: Array[Node3D] = []
	
	var bodies_in_front = []
	if attack_area:
		bodies_in_front = attack_area.get_overlapping_bodies()
	
	for body in hand.get_overlapping_bodies():
		if body == actor: continue
		if hit_enemies_current_attack.has(body.get_instance_id()): continue
		
		# Если есть AttackArea (конус перед игроком), проверяем, что враг в нём
		# (чтобы не бить врагов строго за спиной при анимации замаха)
		if attack_area and not body in bodies_in_front:
			continue
		
		# Проверка стен
		if not _has_line_of_sight(body):
			continue
		
		if body.is_in_group("enemies"): # Hardcoded string replaced logic
			candidates_enemies.append(body)
		elif body is RigidBody3D or body.has_method("take_damage"):
			candidates_props.append(body)
	
	# Сортировка по дистанции (бьем ближайшего)
	var sort_func = func(a, b):
		return actor.global_position.distance_squared_to(a.global_position) < actor.global_position.distance_squared_to(b.global_position)
		
	if not candidates_enemies.is_empty(): candidates_enemies.sort_custom(sort_func)
	if not candidates_props.is_empty(): candidates_props.sort_custom(sort_func)
	
	var hit_occurred = false
	
	if enemies_hit < max_enemies and not candidates_enemies.is_empty():
		var target = candidates_enemies[0]
		_apply_hit(target)
		hit_enemies_current_attack[target.get_instance_id()] = "enemy"
		hit_occurred = true

	if props_hit < max_props and not candidates_props.is_empty():
		var target = candidates_props[0]
		_apply_hit(target)
		hit_enemies_current_attack[target.get_instance_id()] = "prop"
		hit_occurred = true
		
	return hit_occurred

func _apply_hit(body: Node3D) -> void:
	if not is_attacking: return
	if not actor: return

	var dir = (body.global_position - actor.global_position)
	dir.y = 0
	dir = dir.normalized()
	
	if body.has_method("take_damage"):
		# Определяем финишер по урону или флагу (здесь упрощенно по урону > 1, но лучше передавать флаг)
		# В данном случае damage передается извне.
		var is_finisher = (current_attack_damage > 1.5) # Условность, можно улучшить
		
		var knockback_vec = Vector3.ZERO
		if current_attack_knockback_enabled:
			knockback_vec = dir * current_knockback_strength
			knockback_vec.y = current_knockback_height
		
		# --- Hit Stop & Juice ---
		var is_enemy = body.is_in_group("enemies")
		if is_enemy:
			var enemy_hp_comp = body.get_node_or_null("HealthComponent")
			var is_lethal = false
			if enemy_hp_comp:
				is_lethal = (enemy_hp_comp.current_health - current_attack_damage) <= 0
			
			if is_lethal:
				GameManager.hit_stop_smooth(hs_lethal_time_scale, hs_lethal_duration, 0.0, 0.1) 
				GameEvents.camera_shake_requested.emit(0.6, 0.2)
			elif is_finisher:
				GameManager.hit_stop_smooth(hs_finisher_time_scale, hs_finisher_duration, 0.0, 0.05) 
				GameEvents.camera_shake_requested.emit(0.4, 0.15)
			else:
				GameManager.hit_stop_smooth(hs_normal_time_scale, hs_normal_duration, 0.0, 0.02) 
				GameEvents.camera_shake_requested.emit(0.2, 0.1)
		else:
			# Props
			GameManager.hit_stop_smooth(hs_prop_time_scale, hs_prop_duration, 0.0, 0.0) 
			GameEvents.camera_shake_requested.emit(0.1, 0.05)
		
		# Нанесение урона
		body.take_damage(current_attack_damage, knockback_vec, is_finisher)
		
		# Отдача (Recoil)
		var recoil_force = 15.0 
		if is_finisher: recoil_force = 25.0 
		
		actor.velocity -= dir * recoil_force

func _has_line_of_sight(target: Node3D) -> bool:
	if not actor: return false
	var space_state = actor.get_world_3d().direct_space_state
	
	var origin = actor.global_position + Vector3(0, 1.0, 0)
	var dest = target.global_position + Vector3(0, 0.5, 0) 
	
	var query = PhysicsRayQueryParameters3D.create(origin, dest)
	query.exclude = [actor]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.collider == target
	return false
