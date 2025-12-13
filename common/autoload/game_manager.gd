extends Node

func hit_stop(time_scale: float, duration: float):
	# Если уже идет хитстоп - не перебиваем его (или можно перебивать, по вкусу)
	if Engine.time_scale != 1.0:
		return
		
	Engine.time_scale = time_scale
	
	# Ждем duration секунд РЕАЛЬНОГО времени (ignore_time_scale = true)
	# Умножать на time_scale НЕ НАДО
	await get_tree().create_timer(duration, true, false, true).timeout
	
	Engine.time_scale = 1.0
