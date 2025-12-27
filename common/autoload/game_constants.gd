class_name GameConstants
extends RefCounted

# --- ГРУППЫ (GROUPS) ---
const GROUP_PLAYER = "player"
const GROUP_ENEMIES = "enemies"
const GROUP_FADE_OBJECTS = "fade_objects"

# --- ВВОД (INPUT ACTIONS) ---
const INPUT_MOVE_LEFT = "left"
const INPUT_MOVE_RIGHT = "right"
const INPUT_MOVE_UP = "up"
const INPUT_MOVE_DOWN = "down"
const INPUT_JUMP = "jump"
const INPUT_RUN = "run"
const INPUT_ATTACK_PRIMARY = "first_attack"
const INPUT_SPAWN = "spawn"

# --- СОСТОЯНИЯ (STATES) ---
const STATE_IDLE = "idle"
const STATE_MOVE = "move"
const STATE_RUN = "run"
const STATE_AIR = "air"
const STATE_DASH = "dash"
const STATE_SLAM = "slam"
const STATE_ATTACK = "attack"
const STATE_ROLL = "roll"
const STATE_PATROL = "patrol"
const STATE_CHASE = "chase"
const STATE_FRUSTRATED = "frustrated"
const STATE_DEAD = "dead"
const STATE_COMBAT_STANCE = "combatstance"

# --- АНИМАЦИИ (Resource Names) ---
const ANIM_PLAYER_IDLE = "Boy_idle"
const ANIM_PLAYER_WALK = "Boy_walk"
const ANIM_PLAYER_RUN = "Boy_run"
const ANIM_PLAYER_STOPPING = "Boy_stopping"
const ANIM_PLAYER_JUMP_START = "Boy_jump_start"
const ANIM_PLAYER_JUMP_MID = "Boy_jump_mid"
const ANIM_PLAYER_JUMP_END = "Boy_jump_end"
const ANIM_PLAYER_AIR_DASH = "Boy_air_dash"
const ANIM_PLAYER_ROLL = "Boy_roll"
const ANIM_PLAYER_DEATH = "Boy_death"
const ANIM_PLAYER_ATTACK_1 = "Boy_attack_naked_1"
const ANIM_PLAYER_ATTACK_2 = "Boy_attack_naked_2"
const ANIM_PLAYER_ATTACK_3 = "Boy_attack_naked_3"
const ANIM_PLAYER_SLAM_START = "Boy_attack_air_naked_start"
const ANIM_PLAYER_SLAM_MID = "Boy_attack_air_naked_mid"
const ANIM_PLAYER_SLAM_END = "Boy_attack_air_naked_end"

# --- АНИМАЦИИ ВРАГА ---
const ANIM_ENEMY_IDLE = "Monstr_idle"
const ANIM_ENEMY_WALK = "Monstr_walk"
const ANIM_ENEMY_RUN = "Monstr_run"
const ANIM_ENEMY_DEATH = "Monstr_death"
const ANIM_ENEMY_ANGRY = "Monstr_angry"
const ANIM_ENEMY_ATTACK_IDLE = "Monstr_attack_idle"
const ANIM_ENEMY_ATTACK_1 = "Monstr_attack_1"
const ANIM_ENEMY_ATTACK_2 = "Monstr_attack_2"
const ANIM_ENEMY_KNOCKDOWN = "Monstr_knockdown"
const ANIM_ENEMY_HIT = "Monstr_hit"
const ANIM_ENEMY_STRAFE_L = "Monstr_walk_strafe_l"
const ANIM_ENEMY_STRAFE_R = "Monstr_walk_strafe_r"
	
# 1. Root State
const TREE_PARAM_STATE = "parameters/state/transition_request" # "alive", "dead"

# 2. Main Chain
const TREE_PARAM_HIT_SHOT = "parameters/hit_oneshot/request"
const TREE_PARAM_DASH_SHOT = "parameters/dash_oneshot/request"
const TREE_PARAM_ROLL_SHOT = "parameters/roll_oneshot/request"
const TREE_PARAM_ATTACK_SHOT = "parameters/attack_oneshot/request"
const TREE_PARAM_ATTACK_IDX = "parameters/attack_idx/transition_request" # "Attack1", "Attack2", "Attack3"
const TREE_PARAM_ATTACK_SPEED = "parameters/AttackSpeed/scale"
# 3. Locomotion & Air
const TREE_PARAM_SLAM_STATE = "parameters/slam_state/transition_request" # "start", "mid", "end", "off"
const TREE_PARAM_AIR_TRANSITION = "parameters/air_transition/transition_request" # "ground", "air"
const TREE_PARAM_JUMP_STATE = "parameters/jump_state/transition_request" # "Start", "Mid", "End" (С большой буквы на скрине!)
const TREE_PARAM_STOPPING_SHOT = "parameters/stopping_oneshot/request"
const TREE_PARAM_LOCOMOTION = "parameters/locomotion_blend/blend_position"

const TREE_ONE_SHOT_KNOCKDOWN = "parameters/knockdown_oneshot/request"
const TREE_ANGRY_SEEK = "parameters/TimeSeek/seek_request"
const TREE_PARAM_STRAFE_BLEND = "parameters/strafe_blend/blend_position"
const TREE_PARAM_CHASE_BLEND = "parameters/chase_blend/blend_position"
# 4. Misc
const TREE_PARAM_TIMESCALE = "parameters/TimeScale/scale" 
const TREE_PARAM_LOCOMOTION_SPEED = "parameters/LocomotionSpeed/scale"
# --- ПАРАМЕТРЫ ШЕЙДЕРОВ ---
const SHADER_PARAM_PLAYER_POS = "player_position"
const SHADER_PARAM_DISSOLVE = "dissolve_amount"
const SHADER_PARAM_HEALTH = "health"
const SHADER_PARAM_DELAYED_HEALTH = "delayed_health"
const SHADER_PARAM_OPACITY = "opacity"
const SHADER_PARAM_FLASH_USE = "use_hit_flash"
const SHADER_PARAM_FLASH_COLOR = "hit_flash_color"
const SHADER_PARAM_FLASH_STRENGTH = "hit_flash_strength"
