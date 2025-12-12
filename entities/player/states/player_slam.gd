extends State

var player: Player

func enter() -> void:
	player = entity as Player
	player.ground_slam_ability.start_slam()
	# print("[FSM] Player Slam")

func physics_update(delta: float) -> void:
	# ЯВНО вызываем обновление физики компонента
	player.ground_slam_ability.update_physics(delta)
	
	# Проверяем флаги: если способность закончила работу
	if not player.ground_slam_ability.is_slamming and not player.ground_slam_ability.is_recovering:
		transitioned.emit(self, GameConstants.STATE_MOVE)
