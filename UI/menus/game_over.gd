extends Control

@onready var btn_retry = $CenterContainer/VBox/BtnRetry
@onready var btn_menu = $CenterContainer/VBox/BtnMenu

func _ready():
	btn_retry.grab_focus() # Чтобы сразу можно было нажать пробел/Enter
	
	btn_retry.pressed.connect(_on_retry_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)

func _on_retry_pressed():
	# Перезагружаем текущий уровень (используя SceneManager для плавности)
	SceneManager.restart_last_level()

func _on_menu_pressed():
	# Возвращаемся в меню
	SceneManager.open_main_menu()
