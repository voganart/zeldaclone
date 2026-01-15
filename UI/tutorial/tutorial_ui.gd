extends Control

# Настройка строк обучения.
var tutorial_items = [
	{ "action": "move", "text": "ui_move" },
	{ "action": "camera", "text": "ui_look" },
	{ "action": "jump", "text": "ui_jump" },
	{ "action": "run", "text": "ui_dash" },
	{ "action": "first_attack", "text": "ui_attack" },
	{ "action": "interact", "text": "ui_interact" }
]

@onready var container = $PanelContainer/MarginContainer/VBoxContainer
@export var row_scene: PackedScene 

func _ready():
	InputHelper.device_changed.connect(_on_device_changed)
	_populate_list()
	
	# Автоматическое скрытие через 15 секунд (раскомментируй, если нужно)
	# await get_tree().create_timer(15.0).timeout
	# hide_tutorial()

func _populate_list():
	# Очистка старых, если были (например, заглушки в редакторе)
	for child in container.get_children():
		child.queue_free()
		
	for item in tutorial_items:
		if not row_scene:
			printerr("TutorialUI: Row Scene is not assigned!")
			return

		# Создаем строку
		var row = row_scene.instantiate() as TutorialRow # Используем наш новый класс
		container.add_child(row)
		
		var icon_tex = InputHelper.get_icon(item["action"])
		# Если строки нет в переводе, покажет ключ. Убедись, что ключи есть в csv.
		var label_text = tr(item["text"]) 
		
		# --- ИСПРАВЛЕНИЕ: Используем метод класса, а не get_node ---
		if row.has_method("update_display"):
			row.update_display(icon_tex, label_text)
		
		# Сохраняем имя экшена в метаданных строки, чтобы обновлять иконку
		row.set_meta("action_name", item["action"])

func _on_device_changed(_device, _id):
	# Обновляем только иконки
	for child in container.get_children():
		if child is TutorialRow:
			var action = child.get_meta("action_name")
			var icon_tex = InputHelper.get_icon(action)
			child.update_icon(icon_tex)

func hide_tutorial():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	visible = false
