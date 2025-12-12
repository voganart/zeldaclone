extends Label

func _ready() -> void:
	# Подписываемся на глобальное событие
	GameEvents.player_health_changed.connect(_on_player_health_changed)
	
	# Можно инициализировать текст, если есть доступ к данным, 
	# но обычно событие прилетает сразу при старте игрока.
	text = "HP: --"

func _on_player_health_changed(current_hp: float, _max_hp: float) -> void:
	# Форматируем текст
	text = "HP: %d" % ceil(current_hp)
