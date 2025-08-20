extends Node

@export var player_stats: Node
@export var player: CharacterBody3D
@export var attack_timer: Timer
@export var anim_player: AnimationPlayer
var can_attack := true
var is_attacking := false
var primary_naked_attacks := ["Boy_attack_naked_1", "Boy_attack_naked_2", "Boy_attack_naked_3","Boy_attack_naked_1","Boy_attack_naked_3","Boy_attack_naked_1","Boy_attack_naked_3"]

func _input(event):
	if event.is_action_pressed("first_attack"):
		first_attack(player_stats.primary_attack_speed)
		
		
func animation_player():
	if is_attacking: return
	var speed_2d: float = Vector2(player.velocity.x, player.velocity.z).length()
	var has_input := Input.get_vector("left","right","up","down").length() > 0

	# Прыжки
	if not player.is_on_floor():
		player_stats.is_stopping = false
		if player.velocity.y > 0.5 and player_stats.jump_phase != "start":
			anim_player.play("Boy_jump_start", 0.1)
			player_stats.jump_phase = "start"
		elif player.velocity.y <= 0.1 and player_stats.jump_phase != "mid":
			anim_player.play("Boy_jump_mid", 0.2, lerp(0.5, 1.25, 0.1))
			player_stats.jump_phase = "mid"
		return
	else:
		if player_stats.jump_phase in ["start", "mid"]:
			anim_player.play("Boy_jump_end", 0, lerp(0.5, 1.25, 0.1))
			player_stats.jump_phase = ""

	# Движение по земле
	if has_input:
		player_stats.is_stopping = false
		if speed_2d > lerp(player_stats.base_speed, player_stats.run_speed, 0.5):
			anim_player.play("Boy_run", 0.3, lerp(0.5, 1.25, speed_2d/player_stats.run_speed))
		elif speed_2d > 0.2:
			anim_player.play("Boy_walk", 0.3, lerp(0.5, 1.25, speed_2d/player_stats.base_speed))
	else:
		# торможение
		if speed_2d > 3.2:
			if not player_stats.is_stopping:
				player_stats.is_stopping = true
				anim_player.play("Boy_stopping", 0.2, 0.1)
		else:
			player_stats.is_stopping = false
			anim_player.play("Boy_idle", 0.5)

func first_attack(attack_speed):
	if not can_attack or not player.is_on_floor():
		return
	is_attacking = true
	can_attack = false
	var rand_anim = primary_naked_attacks.pick_random()
	var rand_anim_length = anim_player.get_animation(rand_anim).length
	attack_timer.start(rand_anim_length + player_stats.attack_cooldown)
	anim_player.play(rand_anim, 0, attack_speed)
	await anim_player.animation_finished
	is_attacking = false
	can_attack = true

func _on_first_attack_timer_timeout() -> void:
	can_attack = true
	is_attacking = false
