extends State

var player: Player

func enter() -> void:
	player = entity as Player
	# Логика рывка (физика, звук)
	player.air_dash_ability.perform_dash()
	player.sfx_dash.play_random()
	
	# Анимацию запускает сам компонент Ability через вызов trigger_air_dash()
	# Но так как State изолирован, убедимся, что вызов идет корректно:
	player.trigger_air_dash()

func physics_update(_delta: float) -> void:
	# Если компонент закончил дэш (is_dashing стало false)
	if not player.air_dash_ability.is_dashing:
		transitioned.emit(self, GameConstants.STATE_AIR)
		return
