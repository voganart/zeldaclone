extends State

var player: Player

func enter() -> void:
	player = entity as Player
	# Запускаем анимацию
	player.anim_player.play(GameConstants.ANIM_PLAYER_DEATH)
	# Отключаем коллизии с врагами (опционально, слой 2 или 3)
	player.set_collision_mask_value(3, false)
	
	print("[FSM] Player Dead")

func physics_update(delta: float) -> void:
	# Оставляем только гравитацию и трение
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0, 10.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, 10.0 * delta)
	
	# Двигаем тело, чтобы оно упало
	player.move_and_slide()
	
	# Никаких переходов отсюда нет. Это конец.
