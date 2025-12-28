class_name EnemyAttackComponent
extends Node

@export_group("Combat")
@export var attack_damage: float = 1.0 # Базовый урон атаки
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var attack_speed: float = 1.0
@export var attack_impulse: float = 2.0

@export_group("Tactical Retreat")
@export var tactical_retreat_chance: float = 0.3
@export var tactical_retreat_distance: float = 4.0
@export var retreat_interrupt_range: float = 2.5
@export var tactical_retreat_pause_min: float = 0.5
@export var tactical_retreat_pause_max: float = 1.5

# Данные об атаках
var monster_attacks = [GameConstants.ANIM_ENEMY_ATTACK_1, GameConstants.ANIM_ENEMY_ATTACK_2]
var last_attack_index = -1
var last_attack_time: float = -999.0

# Состояние отступления
var should_tactical_retreat: bool = false
var tactical_retreat_target: Vector3 = Vector3.ZERO
var tactical_retreat_pause_timer: float = 0.0

@onready var actor = _find_actor()

func _find_actor():
	var p = get_parent()
	if p is Enemy: return p
	if p and p.get_parent() is Enemy: return p.get_parent()
	return null

func is_attack_ready() -> bool:
	var time_now = Time.get_ticks_msec() / 1000.0
	return (time_now - last_attack_time) >= attack_cooldown

func get_next_attack_animation() -> String:
	last_attack_index = (last_attack_index + 1) % monster_attacks.size()
	return monster_attacks[last_attack_index]

# Вызывается из EnemyAttack State перед началом удара
func register_attack() -> float:
	last_attack_time = Time.get_ticks_msec() / 1000.0
	_check_for_tactical_retreat()
	
	# === ИНТЕГРАЦИЯ С COMBAT COMPONENT ===
	if actor and actor.has_node("Components/CombatComponent"):
		var combat_comp = actor.get_node("Components/CombatComponent")
		# 1. Сбрасываем старые данные
		combat_comp.start_attack_sequence()
		# 2. Настраиваем урон
		combat_comp.configure_attack_parameters(attack_damage, false, false)
		
		# !!! ВАЖНО: МЫ УБРАЛИ activate_hitbox_check() ОТСЮДА !!!
		# Теперь мы полностью полагаемся на вызов из AnimationPlayer (как у игрока).
	# =====================================
	
	return attack_impulse

func _check_for_tactical_retreat() -> void:
	if randf() < tactical_retreat_chance:
		should_tactical_retreat = true
		tactical_retreat_pause_timer = 0.0
	else:
		should_tactical_retreat = false

func calculate_retreat_target(target: Node3D) -> Vector3:
	if not is_instance_valid(actor):
		return Vector3.ZERO
		
	if is_instance_valid(target):
		var retreat_dir = (actor.global_position - target.global_position).normalized()
		tactical_retreat_target = actor.global_position + retreat_dir * tactical_retreat_distance
	else:
		tactical_retreat_target = actor.global_position
	return tactical_retreat_target

func clear_retreat_state() -> void:
	should_tactical_retreat = false
	tactical_retreat_target = Vector3.ZERO
	tactical_retreat_pause_timer = 0.0

func get_random_retreat_pause_time() -> float:
	return randf_range(tactical_retreat_pause_min, tactical_retreat_pause_max)
