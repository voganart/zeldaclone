extends Control

@onready var btn_new_game = $UI_Layer/Margin/VBox/ButtonsVBox/BtnNewGame
@onready var btn_settings = $UI_Layer/Margin/VBox/ButtonsVBox/BtnSettings
@onready var btn_exit = $UI_Layer/Margin/VBox/ButtonsVBox/BtnExit

func _ready():
	# Фокус на первую кнопку для управления с геймпада/клавиатуры
	btn_new_game.grab_focus()
	
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	
	# Проигрываем музыку меню (если есть)
	MusicBrain.play_menu_music()

func _on_new_game_pressed():
	# Используем наш новый метод с загрузкой!
	# Убедись, что в SceneManager.LEVEL_1_PATH стоит правильный путь к уровню
	SceneManager.change_scene_with_loading(SceneManager.LEVEL_1_PATH)

func _on_settings_pressed():
	print("Settings not implemented yet")
	# Позже сделаем тут открытие окна настроек

func _on_exit_pressed():
	get_tree().quit()
