extends Node

# Пути к сценам
const MAIN_MENU_PATH = "res://ui/menus/main_menu.tscn"
const LOADING_SCREEN_PATH = "res://ui/menus/loading_screen.tscn"
const GAME_OVER_PATH = "res://ui/menus/game_over.tscn"
# Укажи путь к твоему первому уровню
const LEVEL_1_PATH = "res://levels/test_level/level.tscn" 

var _target_scene_path: String = ""
var last_played_level: String = "" 
var _loading: bool = false
var transition_layer: CanvasLayer
var color_rect: ColorRect

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Работает даже при паузе
	
	# Слой затемнения (как и было)
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 100
	add_child(transition_layer)
	
	color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(color_rect)

# 1. Простая смена (для меню -> настройки)
func change_scene_simple(scene_path: String):
	await _fade_in()
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
	_fade_out()

# 2. Смена с загрузкой (для меню -> уровень)
func change_scene_with_loading(scene_path: String):
	# ЗАПОМИНАЕМ уровень перед загрузкой!
	last_played_level = scene_path 
	
	await _fade_in()
	_target_scene_path = scene_path
	get_tree().change_scene_to_file(LOADING_SCREEN_PATH)
	await get_tree().process_frame
	ResourceLoader.load_threaded_request(_target_scene_path)
	_loading = true
	_fade_out()

func _process(_delta):
	if not _loading: return
	
	var status = ResourceLoader.load_threaded_get_status(_target_scene_path)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_loading = false
		var new_scene_resource = ResourceLoader.load_threaded_get(_target_scene_path)
		
		# Убеждаемся, что экран черный (на всякий случай)
		color_rect.color.a = 1.0 
		
		# Меняем сцену
		get_tree().change_scene_to_packed(new_scene_resource)
		get_tree().paused = false
		
		# --- ФАЗА СТАБИЛИЗАЦИИ (НОВОЕ) ---
		
		# 1. Ждем один кадр, чтобы сработали все функции _ready()
		await get_tree().process_frame
		
		# 2. Ждем небольшое время (например 0.5 - 1.0 сек), пока физика "утрясется"
		# За это время ящики упадут, игрок встанет на пол, шейдеры прогрузятся.
		# Экран все это время остается черным.
		await get_tree().create_timer(0.8).timeout 
		
		# ---------------------------------
		
		# Теперь плавно показываем игру
		_fade_out()
		
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		printerr("SceneManager: Ошибка загрузки сцены ", _target_scene_path)
		_loading = false

# --- Анимации ---
func _fade_in():
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, 0.5)
	await tween.finished

func _fade_out():
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, 0.5)
	await tween.finished

func reload_current_scene():
	await _fade_in()
	get_tree().reload_current_scene()
	get_tree().paused = false
	_fade_out()

func restart_last_level():
	if last_played_level != "":
		# Загружаем тот уровень, который был запомнен
		change_scene_with_loading(last_played_level)
	else:
		# Если вдруг переменная пуста, вернемся в меню (чтобы не крашнулось)
		print("Error: No last level saved!")
		open_main_menu()
		
func open_main_menu():
	change_scene_simple(MAIN_MENU_PATH)
	
func open_game_over():
	# Можно использовать simple, так как сцена смерти легкая
	change_scene_simple(GAME_OVER_PATH)
