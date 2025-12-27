class_name EnemyAttackComponent
extends Node

@export_group("Combat")
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var attack_speed: float = 1.0

# ВЕРНУЛИ ОДНУ ПЕРЕМЕННУЮ
# Теперь это просто сила рывка для любой атаки.
@export var attack_impulse: float = 2.0

@export_group("Tactical Retreat")
@export var tactical_retreat_chance: float = 0.3
@export var tactical_retreat_distance: float = 4.0
@export var retreat_interrupt_range: float = 2.5
@export var tactical_retreat_pause_min: float = 0.5
@export var tactical_retreat_pause_max: float = 1.5

# Данные об атаках (для визуального разнообразия анимаций)
var monster_attacks = [GameConstants.ANIM_ENEMY_ATTACK_1, GameConstants.ANIM_ENEMY_ATTACK_2]
var last_attack_index = -1
var last_attack_time: float = -999.0

# Состояние отступления
var should_tactical_retreat: bool = false
var tactical_retreat_target: Vector3 = Vector3.ZERO
var tactical_retreat_pause_timer: float = 0.0

@onready var actor: Node3D = get_parent()

func is_attack_ready() -> bool:
	var time_now = Time.get_ticks_msec() / 1000.0
	return (time_now - last_attack_time) >= attack_cooldown

func get_next_attack_animation() -> String:
	# Просто чередуем анимации (левой/правой), но физика будет одинаковой
	last_attack_index = (last_attack_index + 1) % monster_attacks.size()
	return monster_attacks[last_attack_index]

func register_attack() -> float:
	last_attack_time = Time.get_ticks_msec() / 1000.0
	_check_for_tactical_retreat()
	
	# Возвращаем единый настроенный импульс
	return attack_impulse

func _check_for_tactical_retreat() -> void:
	if randf() < tactical_retreat_chance:
		should_tactical_retreat = true
		tactical_retreat_pause_timer = 0.0
	else:
		should_tactical_retreat = false

func calculate_retreat_target(target: Node3D) -> Vector3:
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
