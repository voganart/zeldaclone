extends Control

@onready var label = $Label
@onready var timer = $Timer

var dot_count = 0
var base_text = ""

func _ready():
	# Получаем переведенный текст "Загрузка" из системы локализации
	base_text = tr("ui_loading")
	label.text = base_text
	timer.timeout.connect(_on_timer_timeout)
	MusicBrain.start_loading_music()
func _on_timer_timeout():
	dot_count = (dot_count + 1) % 4 # Цикл от 0 до 3
	
	# Добавляем точки к тексту
	var dots = ""
	for i in range(dot_count):
		dots += "."
		
	label.text = base_text + dots
