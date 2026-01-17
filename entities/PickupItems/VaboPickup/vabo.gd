extends BasePickup

@export var amount: int = 1

# Ссылка на файл
const DEFAULT_VABO_SOUND = preload("res://assets/audio/sfx/SFX_Item_Pickup_Vabo.wav")

func _ready():
	# АВТО-ФИКС:
	# Если массив звуков пуст, добавляем дефолтный звук.
	# Делаем это ДО вызова super._ready(), чтобы _setup_audio_player() подхватил звук.
	if sound_streams.is_empty():
		sound_streams.append(DEFAULT_VABO_SOUND)
	
	# Теперь вызываем родителя, который создаст плеер и настроит его
	super._ready()

func _apply_effect(_player):
	PlayerData.add_vabo(amount)
