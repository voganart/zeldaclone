extends State

var enemy: Enemy
var is_performing_attack_anim: bool = false
var attack_timer: float = 0.0

func enter() -> void:
	enemy = entity as Enemy
	is_performing_attack_anim = false
	attack_timer = 0.0
	
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	enemy.attack_component.clear_retreat_state()
	
	# СБРОС БЛЕНДА ПРИ ВХОДЕ
	# Это гарантирует, что под анимацией атаки будет проигрываться Idle, а не бег
	enemy.set_move_mode("normal")
	enemy.current_movement_blend = 0.0 
	enemy.set_locomotion_blend(0.0)

func physics_update(delta: float) -> void:
	# Принудительно обновляем анимацию (которая внутри enemy.gd теперь будет сводить бленд к 0)
	# Это нужно, чтобы если враг получил импульс от атаки, ноги не начали "бежать"
	enemy.update_movement_animation(delta) 
	
	if is_performing_attack_anim:
		attack_timer -= delta
		if attack_timer <= 0:
			_finish_attack()
		return
	
	if enemy.attack_component.should_tactical_retreat:
		_handle_retreat(delta)
		return

	_perform_attack()

func _perform_attack() -> void:
	is_performing_attack_anim = true
	
	var anim_name_full = enemy.attack_component.get_next_attack_animation()
	var tree_attack_idx = "Attack1"
	if "2" in anim_name_full:
		tree_attack_idx = "Attack2"
	
	var impulse = enemy.attack_component.register_attack()
	var forward = -enemy.global_transform.basis.z.normalized()
	enemy.receive_push(forward * impulse)
	
	enemy.trigger_attack_oneshot(tree_attack_idx)
	
	var anim_length = 1.0
	if enemy.anim_player.has_animation(anim_name_full):
		anim_length = enemy.anim_player.get_animation(anim_name_full).length
	
	attack_timer = anim_length / enemy.attack_component.attack_speed

func _finish_attack() -> void:
	if state_machine.current_state != self: return

	is_performing_attack_anim = false
	AIDirector.return_attack_token(enemy) 
	
	if enemy.attack_component.should_tactical_retreat:
		enemy.attack_component.calculate_retreat_target(enemy.player)
	else:
		transitioned.emit(self, GameConstants.STATE_CHASE)

func _handle_retreat(delta: float) -> void:
	if not is_instance_valid(enemy.player):
		transitioned.emit(self, GameConstants.STATE_PATROL)
		return

	var dist_to_player = enemy.global_position.distance_to(enemy.player.global_position)
	
	if dist_to_player < enemy.attack_component.retreat_interrupt_range:
		enemy.attack_component.clear_retreat_state()
		transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# Фаза 1: Пауза
	if enemy.attack_component.tactical_retreat_pause_timer > 0:
		enemy.attack_component.tactical_retreat_pause_timer -= delta
		enemy.nav_agent.set_velocity(Vector3.ZERO)
		enemy.set_move_mode("normal")
		# В паузе стоим - бленд 0
		enemy.current_movement_blend = move_toward(enemy.current_movement_blend, 0.0, delta * 5.0)
		enemy.set_locomotion_blend(enemy.current_movement_blend)
		
		enemy.handle_rotation(delta, enemy.player.global_position)
		
		if enemy.attack_component.tactical_retreat_pause_timer <= 0:
			enemy.attack_component.clear_retreat_state()
			transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	# Фаза 2: Движение
	enemy.nav_agent.target_position = enemy.attack_component.tactical_retreat_target
	enemy.nav_agent.max_speed = enemy.retreat_speed 
	enemy.move_toward_path()
	enemy.handle_rotation(delta, enemy.player.global_position)
	
	# Вот здесь вызываем update_movement_animation. 
	# Так как мы пятимся, скорость по Z будет положительной, и сработает логика "Backwards" из enemy.gd
	enemy.update_movement_animation(delta) 
	
	if enemy.nav_agent.is_navigation_finished():
		enemy.attack_component.tactical_retreat_pause_timer = enemy.attack_component.get_random_retreat_pause_time()

func on_damage_taken() -> void:
	if enemy.attack_component.should_tactical_retreat:
		enemy.attack_component.clear_retreat_state()
		transitioned.emit(self, GameConstants.STATE_CHASE)

func exit() -> void:
	is_performing_attack_anim = false
	AIDirector.return_attack_token(enemy)
