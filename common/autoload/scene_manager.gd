extends Node

# Пути к сценам (замени на свои реальные пути)
const MAIN_MENU_PATH = "res://ui/menus/main_menu.tscn"
const LEVEL_1_PATH = "res://levels/island/island.tscn" # Твой уровень
const GAME_OVER_PATH = "res://ui/menus/game_over.tscn"

# Ссылка на UI затемнения (нужно создать простую сцену с ColorRect)
var transition_layer: CanvasLayer
var color_rect: ColorRect

func _ready():
	# Создаем слой затемнения программно, чтобы не таскать сцены
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 100 # Поверх всего
	add_child(transition_layer)
	
	color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.color = Color(0, 0, 0, 0) # Прозрачный черный
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(color_rect)

func change_scene(scene_path: String):
	# 1. Fade In (Затемнение)
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, 0.5)
	await tween.finished
	
	# 2. Смена сцены
	get_tree().paused = false # Снимаем паузу если была
	get_tree().change_scene_to_file(scene_path)
	
	# 3. Fade Out (Просветление)
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, 0.5)

func reload_current_scene():
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, 0.3)
	await tween.finished
	
	get_tree().reload_current_scene()
	get_tree().paused = false
	
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, 0.3)
