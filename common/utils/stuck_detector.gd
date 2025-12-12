class_name StuckDetector
extends RefCounted # Это легкий класс, не Node

var time_stuck: float = 0.0
var threshold: float = 0.5
var velocity_threshold: float = 0.1

func init(stuck_time_threshold: float = 0.5):
	threshold = stuck_time_threshold

## Возвращает true, если объект застрял
func check(delta: float, current_velocity: Vector3) -> bool:
	# Игнорируем вертикальную скорость (падение)
	var horizontal_speed = Vector2(current_velocity.x, current_velocity.z).length()
	
	if horizontal_speed < velocity_threshold:
		time_stuck += delta
	else:
		time_stuck = max(time_stuck - delta * 2.0, 0.0)
		
	if time_stuck > threshold:
		time_stuck = 0.0 # Сброс после срабатывания
		return true
		
	return false
