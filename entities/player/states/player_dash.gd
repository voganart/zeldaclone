extends State

var player: Player

func enter() -> void:
	player = entity as Player
	# Логика запуска уже в компоненте, просто дергаем его
	player.air_dash_ability.perform_dash()
	player.sfx_dash.play_random()
	# print("[FSM] Player Dash")

func physics_update(_delta: float) -> void:
	# Компонент сам обновляет физику (или мы можем делать это здесь)
	# В player.gd: if air_dash_ability.is_dashing: return
	# Если компонент закончил дэш (is_dashing стало false)
	if not player.air_dash_ability.is_dashing:
		# Переходим в падение
		transitioned.emit(self, GameConstants.STATE_AIR)
		return
