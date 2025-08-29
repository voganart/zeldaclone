extends Node

# Сигнал, который будет отправляться, когда здоровье изменяется
# Полезен для обновления UI (интерфейса пользователя)
signal health_changed(new_health: float)

# Сигнал, который будет отправляться, когда здоровье достигает нуля или меньше
signal died

@export var max_health: float = 10.0 # Максимальное здоровье, устанавливается в инспекторе

var current_health: float = 10.0:
	set(value):
		# Обновляем здоровье, но не позволяем ему быть меньше 0 или больше max_health
		var old_health = current_health
		current_health = clamp(value, 0, max_health)
		
		# Отправляем сигнал, если здоровье изменилось
		if old_health != current_health:
			health_changed.emit(current_health)
			
		# Отправляем сигнал 'died', если здоровье достигло нуля
		if current_health <= 0 and old_health > 0:
			died.emit()

func _ready() -> void:
	# Инициализируем текущее здоровье максимальным при старте
	current_health = max_health

## Принимает урон от других объектов
func take_damage(amount: float) -> void:
	# Проверяем, что урон положительный
	if amount > 0:
		current_health -= amount
		
## Восстанавливает здоровье
func heal(amount: float) -> void:
	# Проверяем, что лечение положительное
	if amount > 0:
		current_health += amount

## Возвращает текущее здоровье
func get_health() -> float:
	return current_health

## Возвращает максимальное здоровье
func get_max_health() -> float:
	return max_health
