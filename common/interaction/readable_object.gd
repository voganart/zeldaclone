class_name ReadableObject
extends Node3D

@export_multiline var message_text: String = "..."
@export var message_duration: float = 3.0

# Ссылка на Area, если она лежит внутри
@onready var interaction_area: InteractionArea = $InteractionArea

func _ready():
	# Если Area есть внутри сцены, подписываемся автоматически
	if interaction_area:
		interaction_area.triggered.connect(_on_interact)

func _on_interact():
	print("Reading: ", message_text)
	
	# ТУТ БУДЕТ ВЫЗОВ UI ДИАЛОГА
	# Пока используем TutorialOverlay как временное решение для вывода текста
	
	var hud = get_tree().get_first_node_in_group("hud") # Убедись, что HUD в группе "hud"
	if hud and hud.tutorial_overlay:
		# Показываем текст как подсказку
		hud.tutorial_overlay.show_prompt("", message_text)
		
		# Скрываем через время
		get_tree().create_timer(message_duration).timeout.connect(func(): 
			hud.tutorial_overlay.hide_prompt()
		)
