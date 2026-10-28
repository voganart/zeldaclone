extends BasePickup

@export var amount: int = 1

# Ссылка на файл
const DEFAULT_VABO_SOUND = preload("res://assets/audio/sfx/SFX_Item_Pickup_Vabo.wav")

var _placed_id: String = ""

func _ready():
	# АВТО-ФИКС:
	# Если массив звуков пуст, добавляем дефолтный звук.
	# Делаем это ДО вызова super._ready(), чтобы _setup_audio_player() подхватил звук.
	if sound_streams.is_empty():
		sound_streams.append(DEFAULT_VABO_SOUND)
	
	# Теперь вызываем родителя, который создаст плеер и настроит его
	super._ready()

	# Расставленные на уровне Вабо (не из пула) подбираются один раз за заход
	if owner:
		_placed_id = str(get_path())
		if PlayerData.is_pickup_collected(_placed_id):
			queue_free()

func _apply_effect(_player):
	PlayerData.add_vabo(amount)
	PlayerData.mark_pickup_collected(_placed_id)
