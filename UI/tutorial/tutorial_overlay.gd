class_name TutorialOverlay
extends Control

# Ссылка на вложенную сцену строки
@onready var row = $MarginContainer/PanelContainer/TutorialRow
@onready var panel = $MarginContainer/PanelContainer

var current_action_name: String = ""
var tween: Tween

func _ready() -> void:
	# Скрываем при старте (прозрачность 0)
	modulate.a = 0.0
	
	# Подписываемся на смену управления (клава/геймпад)
	# InputHelper сам скажет, когда устройство сменилось
	InputHelper.device_changed.connect(_on_device_changed)

func show_prompt(action: String, text_key: String) -> void:
	current_action_name = action
	
	# 1. Получаем данные через InputHelper
	var icon = InputHelper.get_icon(action)
	var text = tr(text_key)
	
	# 2. Обновляем наш TutorialRow
	# У TutorialRow есть метод update_display, который мы писали ранее
	if row.has_method("update_display"):
		row.update_display(icon, text)
	
	# 3. Анимация появления (Fade In)
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC)

func hide_prompt() -> void:
	# Анимация исчезновения (Fade Out)
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC)

# Автоматическое обновление иконки при смене геймпада/клавиатуры
func _on_device_changed(_device, _id):
	# Если плашка видна и действие задано
	if modulate.a > 0.01 and current_action_name != "":
		var icon = InputHelper.get_icon(current_action_name)
		if row.has_method("update_icon"):
			row.update_icon(icon)
