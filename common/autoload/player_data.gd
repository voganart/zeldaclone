# Содержимое файла: "zeldaclone/common/autoload/player_data.gd"
extends Node

# Глобальные переменные
var current_vabo: int = 0
var max_health: float = 3.0 # Начинаем с 3 сердец

# Способности (пока закрыты)
var abilities = {
	"air_dash": false,
	"ground_slam": false
}

# Сигнал для UI, чтобы обновить счетчик монет
signal vabo_changed(new_amount: int)

func add_vabo(amount: int):
	current_vabo += amount
	emit_signal("vabo_changed", current_vabo)
	print("Vabo collected! Total: ", current_vabo)

func unlock_ability(ability_name: String):
	if abilities.has(ability_name):
		abilities[ability_name] = true
		print("Ability unlocked: ", ability_name)

# Здесь потом добавим сохранение/загрузку
