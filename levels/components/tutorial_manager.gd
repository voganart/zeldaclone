class_name TutorialManager
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
		# 1. ДВИЖЕНИЕ
		Step.MOVE:
			if player.velocity.length() > 1.0:
				step_timer += delta
				if step_timer > 1.5:
					_complete_step()
					_start_camera_toggle_step()

		# 2. СМЕНА КАМЕРЫ (F4 / Select)
		Step.CAMERA_TOGGLE:
			if Input.is_action_just_pressed(GameConstants.INPUT_TOGGLE_CAMERA):
				_complete_step()
				await get_tree().create_timer(1.0).timeout
				_start_camera_look_step()

		# 3. ОБЗОР (Мышь / Стик)
		Step.CAMERA_LOOK:
			# А) Проверка ГЕЙМПАДА (Стик)
			var look = Input.get_vector("camera_look_left", "camera_look_right", "camera_look_up", "camera_look_down")
			if look.length() > 0.2:
				step_timer += delta
			
			# Б) Проверка МЫШИ - см. функцию _input() ниже!
			# Мышь тоже добавляет время в step_timer.
			
			# Общая проверка завершения
			if step_timer > 1.0: # Покрутил камерой 1 секунду
				_complete_step()
				# Дальше туториал замирает и ждет триггеров на уровне (например, прыжок)
				current_step = Step.JUMP 

func _input(event: InputEvent) -> void:
	# Логика для МЫШИ в этапе обзора
	if current_step == Step.CAMERA_LOOK:
		if event is InputEventMouseMotion:
			# Если мышь двигается достаточно быстро
			if event.relative.length() > 2.0:
				# Добавляем время кадра к таймеру.
				# Событий мыши много, поэтому таймер наберется быстро.
				step_timer += get_process_delta_time()

func _complete_step():
	if overlay: overlay.hide_prompt()
	step_timer = 0.0

# --- ЭТАПЫ ---
func _start_move_step():
	current_step = Step.MOVE
	if overlay: overlay.show_prompt("move", "tutorial_move_prompt")

func _start_camera_toggle_step():
	current_step = Step.CAMERA_TOGGLE
	if overlay: overlay.show_prompt(GameConstants.INPUT_TOGGLE_CAMERA, "tutorial_cam_toggle_prompt")

func _start_camera_look_step():
	current_step = Step.CAMERA_LOOK
	if overlay: overlay.show_prompt("camera", "tutorial_cam_look_prompt")

# --- ПУБЛИЧНЫЕ МЕТОДЫ (для триггеров зон) ---
func trigger_jump_tutorial():
	# Запускаем только если мы прошли обзор камеры
	if current_step == Step.JUMP or current_step == Step.FINISHED:
		if overlay: 
			overlay.show_prompt("jump", "tutorial_jump_prompt")
			get_tree().create_timer(4.0).timeout.connect(func(): overlay.hide_prompt())

func trigger_attack_tutorial():
	if overlay:
		overlay.show_prompt("first_attack", "tutorial_attack_prompt")
		get_tree().create_timer(4.0).timeout.connect(func(): overlay.hide_prompt())
