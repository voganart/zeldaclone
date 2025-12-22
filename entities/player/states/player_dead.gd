extends State

var player: Player

func enter() -> void:
	player = entity as Player
	
	# Переключаем корневой Transition в "dead"
	player.set_life_state("dead")
	
	player.set_collision_mask_value(3, false)

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0, 10.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, 10.0 * delta)
	player.move_and_slide()
