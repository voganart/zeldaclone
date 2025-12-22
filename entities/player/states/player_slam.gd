extends State

var player: Player

func enter() -> void:
	player = entity as Player
	# Компонент вызовет player.set_slam_state("start")
	player.ground_slam_ability.start_slam()

func physics_update(delta: float) -> void:
	player.ground_slam_ability.update_physics(delta)
	
	if not player.ground_slam_ability.is_slamming and not player.ground_slam_ability.is_recovering:
		# Перед выходом обязательно выключаем стейт в дереве!
		player.set_slam_state("off")
		transitioned.emit(self, GameConstants.STATE_MOVE)
		return
