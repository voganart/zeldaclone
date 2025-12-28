extends State

var enemy: Enemy
var is_performing_attack_anim: bool = false
var attack_timer: float = 0.0

@export var hit_stagger_delay: float = 0.2 

func enter() -> void:
	enemy = entity as Enemy
	is_performing_attack_anim = false
	attack_timer = 0.0
	
	enemy.nav_agent.set_velocity(Vector3.ZERO)
	enemy.attack_component.clear_retreat_state()
	
	# Включаем стойку
	enemy.set_move_mode("chase")
	enemy.current_movement_blend = 0.0 
	enemy.set_locomotion_blend(0.0)
	
	# === ВАЖНО: ВКЛЮЧАЕМ МОНИТОРИНГ ХИТБОКСОВ ===
	# Это не наносит урон, а просто "включает радар" Area3D.
	# Сам урон нанесется, когда анимация вызовет _check_attack_hit.
	if enemy.combat_component:
		enemy.combat_component.start_hitbox_monitoring()
	# ============================================

func physics_update(delta: float) -> void:
	enemy.update_movement_animation(delta) 
	
	if is_performing_attack_anim:
		attack_timer -= delta
		
		# Доводка поворота во время атаки
		if is_instance_valid(enemy.player):
			enemy.handle_rotation(delta, enemy.player.global_position, enemy.attack_rotation_speed)

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
	
	# ИСПРАВЛЕНИЕ НАПРАВЛЕНИЯ
	var forward = enemy.global_transform.basis.z.normalized()
	
	# Применяем рывок вперед
	enemy.receive_push(forward * impulse)
	
	# Запускаем анимацию
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

	if enemy.attack_component.tactical_retreat_pause_timer > 0:
		enemy.attack_component.tactical_retreat_pause_timer -= delta
		enemy.nav_agent.set_velocity(Vector3.ZERO)
		enemy.set_move_mode("chase") 
		enemy.current_movement_blend = move_toward(enemy.current_movement_blend, 0.0, delta * 5.0)
		enemy.set_locomotion_blend(enemy.current_movement_blend)
		enemy.handle_rotation(delta, enemy.player.global_position)
		
		if enemy.attack_component.tactical_retreat_pause_timer <= 0:
			enemy.attack_component.clear_retreat_state()
			transitioned.emit(self, GameConstants.STATE_CHASE)
		return

	enemy.nav_agent.target_position = enemy.attack_component.tactical_retreat_target
	enemy.nav_agent.max_speed = enemy.retreat_speed 
	enemy.move_toward_path()
	enemy.handle_rotation(delta, enemy.player.global_position)
	enemy.set_move_mode("chase")
	enemy.update_movement_animation(delta) 
	
	if enemy.nav_agent.is_navigation_finished():
		enemy.attack_component.tactical_retreat_pause_timer = enemy.attack_component.get_random_retreat_pause_time()

func on_damage_taken(is_heavy: bool = false) -> void:
	if not is_performing_attack_anim: return

	if is_heavy:
		is_performing_attack_anim = false
		AIDirector.return_attack_token(enemy)
		transitioned.emit(self, GameConstants.STATE_CHASE)
		print("Enemy attack INTERRUPTED by heavy hit!")
	else:
		attack_timer += hit_stagger_delay
		print("Enemy attack DELAYED by light hit!")

func exit() -> void:
	is_performing_attack_anim = false
	AIDirector.return_attack_token(enemy)
	
	# === ВЫКЛЮЧАЕМ МОНИТОРИНГ ===
	if enemy.combat_component:
		enemy.combat_component._stop_hitbox_monitoring()
