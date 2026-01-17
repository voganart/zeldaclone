extends Node

var active_tween: Tween

# --- НАСТРОЙКИ СКОРОСТИ ---
var base_time_scale: float = 1.0 # Текущая базовая скорость игры

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Важно, чтобы ввод работал даже в паузе
	
	await get_tree().process_frame
	if has_node("/root/SimpleGrass"):
		print("SimpleGrass found, enabling interaction...")
		get_node("/root/SimpleGrass").set_interactive(true)
	else:
		print("SimpleGrass NOT found in Game Manager!")

func _input(event: InputEvent) -> void:
	# Только для дебага (можно убрать в релизе)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_KP_ADD: # Numpad +
			set_global_time_scale(base_time_scale + 0.1)
		elif event.keycode == KEY_KP_SUBTRACT: # Numpad -
			set_global_time_scale(base_time_scale - 0.1)
		elif event.keycode == KEY_KP_ENTER or event.keycode == KEY_KP_0: # Numpad Enter/0
			set_global_time_scale(1.0)

## Установка глобальной скорости игры
func set_global_time_scale(value: float):
	base_time_scale = clamp(value, 0.0, 10.0) # Ограничиваем от 0 до 10
	Engine.time_scale = base_time_scale
	print("Game Speed: ", snapped(base_time_scale, 0.01))

## Плавная глобальная остановка времени (Hit Stop)
func hit_stop_smooth(target_scale: float, duration_hold: float, fade_in_time: float = 0.0, fade_out_time: float = 0.2):
	# Если твин уже работает, убиваем его
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	active_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	
	# 1. Замедление (Fade In)
	# Замедляем относительно ТЕКУЩЕЙ базы. 
	# Если база 0.5, а удар требует 0.1, мы идем к 0.1.
	if fade_in_time > 0:
		active_tween.tween_property(Engine, "time_scale", target_scale, fade_in_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		Engine.time_scale = target_scale
	
	# 2. Удержание (Hold)
	# Используем ignore_time_scale = true внутри tween_interval нельзя, 
	# но так как tween в режиме IDLE, он тикает в реальном времени, если не зависит от time_scale.
	# Однако tween_interval зависит от time_scale самого движка? Нет, в Godot Tween обычно уважает time_scale.
	# Для надежности при hit_stop лучше делать расчет времени вручную, но для простоты оставим так:
	active_tween.tween_interval(duration_hold * base_time_scale) # Компенсируем, если игра замедлена
	
	# 3. Возврат в норму (Fade Out)
	# !!! ВАЖНО: Возвращаем не к 1.0, а к base_time_scale !!!
	active_tween.tween_property(Engine, "time_scale", base_time_scale, fade_out_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

## Старый метод для совместимости
func hit_stop_local(anim_players: Array[AnimationPlayer], duration: float):
	for ap in anim_players:
		if is_instance_valid(ap): ap.speed_scale = 0.0
	
	await get_tree().create_timer(duration, true, false, true).timeout
	
	for ap in anim_players:
		if is_instance_valid(ap): ap.speed_scale = 1.0

# Wrapper
func hit_stop(time_scale: float, duration: float):
	hit_stop_smooth(time_scale, duration, 0.0, 0.1)
