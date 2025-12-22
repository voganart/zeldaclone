extends Node

# !!! ИЗМЕНЕНИЕ: Добавляем max_health в сигнал !!!
signal health_changed(new_health: float, max_health: float)

# Сигнал, который будет отправляться, когда здоровье достигает нуля или меньше
signal died

@export var max_health: float = 10.0 

var current_health: float = 10.0:
	set(value):
		var old_health = current_health
		current_health = clamp(value, 0, max_health)
		
		# Отправляем сигнал, если здоровье изменилось
		if old_health != current_health:
			# !!! ИЗМЕНЕНИЕ: Передаем max_health вторым аргументом !!!
			health_changed.emit(current_health, max_health)
			
		if current_health <= 0 and old_health > 0:
			died.emit()

func _ready() -> void:
	current_health = max_health

func take_damage(amount: float) -> void:
	if amount > 0:
		current_health -= amount
		
func heal(amount: float) -> void:
	if amount > 0:
		current_health = min(current_health + amount, max_health)

func get_health() -> float:
	return current_health

func get_max_health() -> float:
	return max_health
