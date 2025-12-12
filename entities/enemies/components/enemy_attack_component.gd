class_name EnemyAttackComponent
extends Node

@export_group("Combat")
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var attack_speed: float = 1.0
@export var attack_impulse: float = 2.0 # Forward impulse applied when performing attack

@export_group("Tactical Retreat")
@export var tactical_retreat_chance: float = 0.3 # 30% chance to retreat after attack
@export var tactical_retreat_distance: float = 4.0
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

@onready var actor: Node3D = get_parent()

## Возвращает true, если кулдаун атаки прошел
func is_attack_ready() -> bool:
	var time_now = Time.get_ticks_msec() / 1000.0
	return (time_now - last_attack_time) >= attack_cooldown

## Выбирает следующую анимацию атаки из списка
func get_next_attack_animation() -> String:
	last_attack_index = (last_attack_index + 1) % monster_attacks.size()
	return monster_attacks[last_attack_index]

## Фиксирует факт совершения атаки (обновляет таймеры)
## Возвращает импульс, который нужно применить к врагу
func register_attack() -> float:
	last_attack_time = Time.get_ticks_msec() / 1000.0
	_check_for_tactical_retreat()
	return attack_impulse

## Внутренняя логика проверки шанса на отступление
func _check_for_tactical_retreat() -> void:
	if randf() < tactical_retreat_chance:
		should_tactical_retreat = true
		# Таймер паузы будет установлен, когда враг доберется до точки
		tactical_retreat_pause_timer = 0.0
	else:
		should_tactical_retreat = false

## Рассчитывает позицию для отступления относительно цели
func calculate_retreat_target(target: Node3D) -> Vector3:
	if is_instance_valid(target):
		# Compute a fixed retreat target now so it doesn't chase the player
		var retreat_dir = (actor.global_position - target.global_position).normalized()
		# Place target at a distance from current pos in retreat_dir
		tactical_retreat_target = actor.global_position + retreat_dir * tactical_retreat_distance
	else:
		tactical_retreat_target = actor.global_position
	
	return tactical_retreat_target

## Метод для сброса состояния отступления
func clear_retreat_state() -> void:
	should_tactical_retreat = false
	tactical_retreat_target = Vector3.ZERO
	tactical_retreat_pause_timer = 0.0

## Утилита для получения случайного времени паузы при отступлении
func get_random_retreat_pause_time() -> float:
	return randf_range(tactical_retreat_pause_min, tactical_retreat_pause_max)
