extends CanvasLayer

@onready var fps_label = $MarginContainer/VBoxContainer/FPS
@onready var stats_label = $MarginContainer/VBoxContainer/Stats

# --- НАСТРОЙКИ 1% LOW ---
const MAX_SAMPLES = 1000     # Храним историю последних 1000 кадров
const UPDATE_INTERVAL = 0.5  # Обновляем текст раз в полсекунды (экономим ресурсы)

var frame_times: Array[float] = []
var timer: float = 0.0

func _process(delta):
	# 1. Собираем статистику каждый кадр
	frame_times.append(delta)
	if frame_times.size() > MAX_SAMPLES:
		frame_times.pop_front() # Удаляем старые, чтобы не переполнять память

	# 2. Обновляем текст только по таймеру
	timer -= delta
	if timer <= 0:
		timer = UPDATE_INTERVAL
		_update_ui()

func _update_ui():
	var current_fps = Engine.get_frames_per_second()
	var low_1_percent = _calculate_1_percent_low()
	
	# Красим 1% Low в красный, если он сильно ниже нормы (например, ниже 30)
	var _color_code = ""
	if low_1_percent < 30: _color_code = "[color=red]"
	elif low_1_percent < 60: _color_code = "[color=yellow]"
	else: _color_code = "[color=green]"
	
	# Если у тебя Label поддерживает BBCode (RichTextLabel), используй цвета. 
	# Если обычный Label, просто выводи текст:
	fps_label.text = "FPS: %d  |  1%% Low: %d" % [current_fps, low_1_percent]

	# Остальная стата
	var mem = float(OS.get_static_memory_usage()) / 1024.0 / 1024.0
	var obj = Performance.get_monitor(Performance.OBJECT_COUNT)
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	
	stats_label.text = "Memory: %.2f MB\nObjects: %d\nDrawCalls: %d" % [mem, obj, draw_calls]

func _calculate_1_percent_low() -> int:
	if frame_times.is_empty():
		return 0
		
	# 1. Делаем копию, чтобы не ломать порядок записи
	var sorted_times = frame_times.duplicate()
	
	# 2. Сортируем: от малых (быстрых) к большим (медленным)
	sorted_times.sort()
	
	# 3. Нам нужны САМЫЕ БОЛЬШИЕ delta (самые медленные кадры). Они в конце массива.
	var count_1_percent = max(1, int(sorted_times.size() * 0.01)) # Берем 1% от количества
	var total_time = 0.0
	
	# Берем последние элементы массива (самые лагучие)
	for i in range(count_1_percent):
		var index = sorted_times.size() - 1 - i
		total_time += sorted_times[index]
	
	# 4. Считаем среднее время кадра среди худших
	var avg_worst_delta = total_time / count_1_percent
	
	if avg_worst_delta == 0: return 0
	
	# 5. Переводим время обратно в FPS (1 / время)
	return int(1.0 / avg_worst_delta)
