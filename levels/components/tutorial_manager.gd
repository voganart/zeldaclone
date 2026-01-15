class_name TutorialManager # <--- ЭТА СТРОКА ОЧЕНЬ ВАЖНА
extends Node

var overlay: TutorialOverlay
var player: Player

enum Step {
	MOVE,
	CAMERA_TOGGLE,
	CAMERA_LOOK,
	JUMP,
	FINISHED
}

var current_step: Step = Step.MOVE
var step_timer: float = 0.0
var is_active: bool = false

func _ready() -> void:
	# Выключаем процесс, пока Level_01 не вызовет setup()
	set_process(false)
	set_process_input(false)

func setup(p: Player, ov: TutorialOverlay) -> void:
	player = p
	overlay = ov
	is_active = true
	
	set_process(true)
	set_process_input(true)
	
	await get_tree().create_timer(1.0).timeout
	_start_move_step()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return

	match current_step:
		Step.MOVE:
			# Проверяем реальную скорость (больше 1 м/с)
			if player.velocity.length() > 1.0:
				step_timer += delta
				if step_timer > 1.5:
					_complete_step()
					_start_camera_toggle_step()

		Step.CAMERA_TOGGLE:
			if Input.is_action_just_pressed("toggle_camera") or Input.is_key_pressed(KEY_F4):
				_complete_step()
				await get_tree().create_timer(1.0).timeout
				_start_camera_look_step()

		Step.CAMERA_LOOK:
			var look = Input.get_vector("camera_look_left", "camera_look_right", "camera_look_up", "camera_look_down")
			# Если игрок крутит камерой (вектор больше 0.5)
			if look.length() > 0.5:
				step_timer += delta
				if step_timer > 1.0:
					_complete_step()
					# Ждем, пока игрок дойдет до триггера прыжка
					current_step = Step.JUMP

func _complete_step():
	if overlay: overlay.hide_prompt()
	step_timer = 0.0

# --- ЭТАПЫ ---
func _start_move_step():
	current_step = Step.MOVE
	if overlay: overlay.show_prompt("move", "tutorial_move_prompt")

func _start_camera_toggle_step():
	current_step = Step.CAMERA_TOGGLE
	if overlay: overlay.show_prompt("toggle_camera", "tutorial_cam_toggle_prompt")

func _start_camera_look_step():
	current_step = Step.CAMERA_LOOK
	if overlay: overlay.show_prompt("camera", "tutorial_cam_look_prompt")

# --- ПУБЛИЧНЫЕ МЕТОДЫ (для триггеров) ---
func trigger_jump_tutorial():
	if current_step != Step.JUMP and current_step != Step.FINISHED: return
	if overlay: 
		overlay.show_prompt("jump", "tutorial_jump_prompt")
		# Скрываем через 4 секунды
		get_tree().create_timer(4.0).timeout.connect(func(): overlay.hide_prompt())

func trigger_attack_tutorial():
	if overlay:
		overlay.show_prompt("first_attack", "tutorial_attack_prompt")
		get_tree().create_timer(4.0).timeout.connect(func(): overlay.hide_prompt())
