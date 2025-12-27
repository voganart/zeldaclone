class_name AnimationController
extends Node

@export var anim_tree: AnimationTree

# Ссылки на параметры (взяты из GameConstants, но можно хранить локально для удобства)
const P_STATE = "parameters/state/transition_request"
const P_MOVE_MODE = "parameters/move_mode/transition_request"
const P_AIR_TRANSITION = "parameters/air_transition/transition_request"
const P_JUMP_STATE = "parameters/jump_state/transition_request"
const P_SLAM_STATE = "parameters/slam_state/transition_request"

const P_ATTACK_IDX = "parameters/attack_idx/transition_request"
const P_ATTACK_SHOT = "parameters/attack_oneshot/request"
const P_ATTACK_SPEED = "parameters/AttackSpeed/scale"

const P_HIT_SHOT = "parameters/hit_oneshot/request"
const P_DASH_SHOT = "parameters/dash_oneshot/request"
const P_ROLL_SHOT = "parameters/roll_oneshot/request"
const P_STOPPING_SHOT = "parameters/stopping_oneshot/request"

const P_LOCOMOTION = "parameters/locomotion_blend/blend_position"
const P_LOCOMOTION_SPEED = "parameters/LocomotionSpeed/scale"

func _ready():
	if anim_tree:
		anim_tree.active = true

# --- Основные состояния ---
func set_state(state_name: String) -> void:
	# alive, dead, etc.
	anim_tree.set(P_STATE, state_name)

func set_move_mode(mode_name: String) -> void:
	# normal, strafe
	anim_tree.set(P_MOVE_MODE, mode_name)

func set_air_state(state_name: String) -> void:
	# ground, air
	anim_tree.set(P_AIR_TRANSITION, state_name)

func set_jump_state(state_name: String) -> void:
	# Start, Mid, End
	anim_tree.set(P_JUMP_STATE, state_name)

func set_slam_state(state_name: String) -> void:
	# start, mid, end, off
	anim_tree.set(P_SLAM_STATE, state_name)

# --- Блендинг ---
func set_locomotion_blend(value: float) -> void:
	anim_tree.set(P_LOCOMOTION, value)

func set_locomotion_speed_scale(value: float) -> void:
	anim_tree.set(P_LOCOMOTION_SPEED, value)

# --- Триггеры (OneShots) ---
func trigger_attack(attack_idx: int) -> void:
	var idx_str = "Attack1"
	if attack_idx == 1: idx_str = "Attack2"
	elif attack_idx == 2: idx_str = "Attack3"
	
	anim_tree.set(P_ATTACK_IDX, idx_str)
	anim_tree.set(P_ATTACK_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func set_attack_speed(value: float) -> void:
	anim_tree.set(P_ATTACK_SPEED, value)

func trigger_hit() -> void:
	anim_tree.set(P_HIT_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func trigger_dash() -> void:
	anim_tree.set(P_DASH_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func trigger_roll() -> void:
	anim_tree.set(P_ROLL_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func trigger_stopping() -> void:
	anim_tree.set(P_STOPPING_SHOT, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# Получение данных Root Motion (для Player.gd)
func get_root_motion_position() -> Vector3:
	return anim_tree.get_root_motion_position()

func get_root_motion_rotation() -> Quaternion:
	return anim_tree.get_root_motion_rotation()
