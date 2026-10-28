extends Control

@onready var btn_new_game = $UI_Layer/Margin/VBox/ButtonsVBox/BtnNewGame
@onready var btn_start_over = $UI_Layer/Margin/VBox/ButtonsVBox/BtnStartOver
@onready var btn_settings = $UI_Layer/Margin/VBox/ButtonsVBox/BtnSettings
@onready var btn_exit = $UI_Layer/Margin/VBox/ButtonsVBox/BtnExit

func _ready():
	var can_continue := (
		SaveManager.has_save()
		and not PlayerData.current_level_path.is_empty()
	)
	btn_new_game.text = tr("ui_continue" if can_continue else "ui_new_game")
	btn_start_over.visible = can_continue
	btn_start_over.pressed.connect(_on_start_over_pressed)

	# Фокус на первую кнопку для управления с геймпада/клавиатуры
	btn_new_game.grab_focus()
	
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	
	# Проигрываем музыку меню (если есть)
	MusicBrain.play_menu_music()

	if SaveManager.invalid_save_recovered:
		$UI_Layer/Margin/VBox/SaveStatusLabel.text = tr(
			"save_data_invalid"
		)
		$UI_Layer/Margin/VBox/SaveStatusLabel.visible = true
		SaveManager.invalid_save_recovered = false

func _on_new_game_pressed():
	SceneManager.continue_or_start_game()

# Новая игра поверх сохранения: первое нажатие просит подтверждения
func _on_start_over_pressed():
	if btn_start_over.text != tr("ui_new_game_confirm"):
		btn_start_over.text = tr("ui_new_game_confirm")
		return
	SceneManager.start_new_game()

func _on_settings_pressed():
	print("Settings not implemented yet")
	# Позже сделаем тут открытие окна настроек

func _on_exit_pressed():
	get_tree().quit()
