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
const INPUT_RUN = "run" # Используется для бега и переката
const INPUT_ATTACK_PRIMARY = "first_attack"
const INPUT_SPAWN = "spawn" # Debug spawn

# --- СОСТОЯНИЯ (STATES) ---
# Имена состояний должны быть в нижнем регистре, так как StateMachine приводит их к to_lower()
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

# --- АНИМАЦИИ ИГРОКА (PLAYER ANIMATIONS) ---
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

# Атаки игрока
const ANIM_PLAYER_ATTACK_1 = "Boy_attack_naked_1"
const ANIM_PLAYER_ATTACK_2 = "Boy_attack_naked_2"
const ANIM_PLAYER_ATTACK_3 = "Boy_attack_naked_3"

# Ground Slam игрока
const ANIM_PLAYER_SLAM_START = "Boy_attack_air_naked_start"
const ANIM_PLAYER_SLAM_MID = "Boy_attack_air_naked_mid"
const ANIM_PLAYER_SLAM_END = "Boy_attack_air_naked_end"

# --- АНИМАЦИИ ВРАГА (ENEMY ANIMATIONS) ---
const ANIM_ENEMY_IDLE = "Monstr_idle"
const ANIM_ENEMY_WALK = "Monstr_walk"
const ANIM_ENEMY_RUN = "Monstr_run"
const ANIM_ENEMY_DEATH = "Monstr_death"
const ANIM_ENEMY_ANGRY = "Monstr_angry" # Frustrated
const ANIM_ENEMY_ATTACK_IDLE = "Monstr_attack_idle" # Combat Idle
const ANIM_ENEMY_ATTACK_1 = "Monstr_attack_1"
const ANIM_ENEMY_ATTACK_2 = "Monstr_attack_2"
const ANIM_ENEMY_KNOCKDOWN = "Monstr_knockdown"
const ANIM_ENEMY_HIT = "Monstr_hit"

# --- ПАРАМЕТРЫ ШЕЙДЕРОВ (SHADER PARAMS) ---
const SHADER_PARAM_PLAYER_POS = "player_position"
const SHADER_PARAM_DISSOLVE = "dissolve_amount"
const SHADER_PARAM_HEALTH = "health"
const SHADER_PARAM_DELAYED_HEALTH = "delayed_health"
const SHADER_PARAM_OPACITY = "opacity"

# Hit Flash
const SHADER_PARAM_FLASH_USE = "use_hit_flash"
const SHADER_PARAM_FLASH_COLOR = "hit_flash_color"
const SHADER_PARAM_FLASH_STRENGTH = "hit_flash_strength"
