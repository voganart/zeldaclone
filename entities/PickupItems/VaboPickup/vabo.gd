# Содержимое файла: "zeldaclone/entities/PickupItems/VaboPickup/vabo.gd"
extends BasePickup

@export var amount: int = 1

func _apply_effect(_player):
	# Обращаемся к глобальному хранилищу
	PlayerData.add_vabo(amount)
	
	# Индекс 2 - это эффект "сбора" (звездочки), убедись что он есть в VfxPool
	# Или создай свой эффект и укажи его индекс
	# VfxPool.spawn_effect(2, global_position)
