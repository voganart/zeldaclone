class_name RollAbility
extends Node

# --- НАСТРОЙКИ ---
@export_group("Roll Settings")
@export var roll_min_speed: float = 1.0 
@export var roll_max_speed: float = 1.4
@export var roll_control: float = 0.5 
@export_range(0.0, 1.0) var roll_jump_cancel_threshold: float = 0.75 
@export var roll_max_charges: int = 3
@export var roll_cooldown: float = 0.5
@export var roll_recharge_time: float = 3.0

# !!! НОВОЕ: Флаг доступности способности !!!
@export var is_unlocked: bool = false 

# --- СОСТОЯНИЕ ---
var current_roll_charges: int = 3
var roll_penalty_timer: float = 0.0
var roll_regen_timer: float = 0.0
var is_roll_recharging: bool = false
var roll_interval_timer: float = 0.0

# Сигнал для UI (если понадобится реактивный интерфейс)
signal roll_charges_changed(current: int, max_val: int, is_recharging_penalty: bool)

func _ready() -> void:
	current_roll_charges = roll_max_charges

func _process(delta: float) -> void:
	_update_roll_timers(delta)

func can_roll() -> bool:
	# !!! НОВОЕ: Проверка на то, открыта ли способность !!!
	if not is_unlocked: return false
	
	if current_roll_charges <= 0: return false
	if roll_interval_timer > 0: return false
	if is_roll_recharging: return false
	return true

func consume_charge() -> void:
	current_roll_charges -= 1
	
	if current_roll_charges <= 0:
		is_roll_recharging = true
		roll_penalty_timer = roll_recharge_time
	else:
		if roll_regen_timer <= 0:
			roll_regen_timer = roll_cooldown
			
	roll_charges_changed.emit(current_roll_charges, roll_max_charges, is_roll_recharging)

func _update_roll_timers(delta: float) -> void:
	# Логика штрафа (полное истощение)
	if is_roll_recharging:
		roll_penalty_timer -= delta
		if roll_penalty_timer <= 0:
			is_roll_recharging = false
			current_roll_charges = roll_max_charges
			roll_charges_changed.emit(current_roll_charges, roll_max_charges, false)
			
	# Логика обычной регенерации
	elif current_roll_charges < roll_max_charges:
		roll_regen_timer -= delta
		if roll_regen_timer <= 0:
			current_roll_charges += 1
			roll_regen_timer = roll_cooldown
			roll_charges_changed.emit(current_roll_charges, roll_max_charges, false)
			
	# Логика интервала между перекатами (спам-фильтр)
	if roll_interval_timer > 0:
		roll_interval_timer -= delta
