extends Node

var active_tween: Tween
func _ready() -> void:

	await get_tree().process_frame
	if has_node("/root/SimpleGrass"):
		print("SimpleGrass found, enabling interaction...")
		get_node("/root/SimpleGrass").set_interactive(true)
	else:
		print("SimpleGrass NOT found in Game Manager!")
## Плавная глобальная остановка времени
## target_scale: до какой скорости замедляем (например 0.05 - почти стоп)
## duration_hold: сколько времени держим замедление (в реальных секундах)
## fade_in_time: за сколько секунд время замедляется (0.0 = мгновенно, удар резче)
## fade_out_time: за сколько секунд время разгоняется обратно (изниг)
func hit_stop_smooth(target_scale: float, duration_hold: float, fade_in_time: float = 0.0, fade_out_time: float = 0.2):
	# Если твин уже работает, убиваем его, чтобы не было конфликтов
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	active_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE) # Работает даже при паузе
	
	# 1. Замедление (Fade In)
	# Обычно для удара лучше 0.0 (мгновенно), но ты просил изинг
	if fade_in_time > 0:
		active_tween.tween_property(Engine, "time_scale", target_scale, fade_in_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		Engine.time_scale = target_scale
	
	# 2. Удержание (Hold)
	# Добавляем пустой интервал (паузу) в твин
	active_tween.tween_interval(duration_hold)
	
	# 3. Возврат в норму (Fade Out)
	active_tween.tween_property(Engine, "time_scale", 1.0, fade_out_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

## Старый метод для совместимости (можно оставить для простых случаев)
func hit_stop_local(anim_players: Array[AnimationPlayer], duration: float):
	for ap in anim_players:
		if is_instance_valid(ap): ap.speed_scale = 0.0
	# IMPORTANT: Используем ignore_time_scale = true, чтобы таймер работал
	# даже при глобальном замедлении времени (Engine.time_scale ~ 0.0)
	await get_tree().create_timer(duration, true, false, true).timeout
	for ap in anim_players:
		if is_instance_valid(ap): ap.speed_scale = 1.0

# Wrapper for simple hit_stop if needed somewhere else (referencing old code)
func hit_stop(time_scale: float, duration: float):
	hit_stop_smooth(time_scale, duration, 0.0, 0.1)
