extends Node

@onready var pcam: PhantomCamera3D = get_parent() if get_parent() is PhantomCamera3D else self

@export_group("Input Settings")
@export var mouse_sensitivity: float = 0.15
@export var gamepad_sensitivity: float = 150.0 
@export var invert_y: bool = false
@export var invert_x: bool = false

@export_group("Limits")
@export_range(-90, 0) var min_pitch: float = -80.0
@export_range(-90, 90) var max_pitch: float = 10.0

# Переменная для хранения "Идеального угла" (Аркадный вид)
var stored_default_rotation: Vector3 = Vector3.ZERO
var is_camera_locked: bool = false 

func _ready() -> void:
	if not pcam is PhantomCamera3D:
		set_process(false)
		return
	
	# Ждем инициализацию камеры
	await get_tree().process_frame
	
	# 1. ЗАПОМИНАЕМ начальное положение камеры из редактора
	# Теперь "Аркадный вид" будет таким, каким ты повернул камеру в сцене уровня.
	var current_rot = pcam.get_third_person_rotation()
	if current_rot:
		stored_default_rotation = current_rot
	else:
		# Фолбек, если вернулся null (на всякий случай)
		stored_default_rotation = Vector3(deg_to_rad(-45), 0, 0)

	# 2. Стартуем в залоченном режиме
	set_camera_mode(true) 

func _input(event: InputEvent) -> void:
	# Переключение режима
	if event is InputEventKey and event.pressed and event.keycode == KEY_F4:
		set_camera_mode(!is_camera_locked)
		return

	# Логика захвата мыши
	if not is_camera_locked:
		if event.is_action_pressed("ui_cancel"):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif event is InputEventMouseButton and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if is_camera_locked: return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED: return
	
	if event is InputEventMouseMotion:
		_apply_rotation(event.relative.x, event.relative.y, mouse_sensitivity)

func _process(delta: float) -> void:
	if is_camera_locked: return
	
	var joystick_vec = Input.get_vector(
		"camera_look_left", "camera_look_right", 
		"camera_look_up", "camera_look_down"
	)
	
	if joystick_vec.length() > 0.05:
		var amount_x = joystick_vec.x * gamepad_sensitivity * delta
		var amount_y = joystick_vec.y * gamepad_sensitivity * delta
		_apply_rotation(amount_x, amount_y, 1.0)

func _apply_rotation(yaw_input: float, pitch_input: float, sensitivity: float) -> void:
	if not pcam: return
	
	var current_rot = pcam.get_third_person_rotation()
	if current_rot == null: return

	var yaw_change = -yaw_input * sensitivity
	var pitch_change = -pitch_input * sensitivity
	
	if invert_x: yaw_change *= -1
	if invert_y: pitch_change *= -1
	
	current_rot.y += deg_to_rad(yaw_change)
	current_rot.x += deg_to_rad(pitch_change)
	
	current_rot.x = clamp(current_rot.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	
	pcam.set_third_person_rotation(current_rot)

func set_camera_mode(locked: bool):
	is_camera_locked = locked
	
	if is_camera_locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_tween_to_default_view()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _tween_to_default_view():
	if not pcam: return
	var current_rot = pcam.get_third_person_rotation()
	if current_rot == null: return
	
	# Используем ЗАПОМНЕННЫЙ угол (и Pitch, и Yaw)
	var target_rot = stored_default_rotation
	
	# --- ЛОГИКА КРАТЧАЙШЕГО ПУТИ ПОВОРОТА (Для Yaw) ---
	# Чтобы камера не крутилась на 360 градусов, если мы повернули её чуть влево.
	# PhantomCamera хранит углы в радианах и они могут быть > PI.
	
	# Приводим текущий Y к диапазону целевого, чтобы твин шел по кратчайшему пути
	var diff_y = wrapf(target_rot.y - current_rot.y, -PI, PI)
	# Временная цель для твина, чтобы он не крутил лишнего
	var smart_target_rot = Vector3(target_rot.x, current_rot.y + diff_y, target_rot.z)
	
	var tween = create_tween()
	tween.tween_method(
		func(val): 
			if pcam: pcam.set_third_person_rotation(val),
		current_rot,
		smart_target_rot,
		0.6
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# После твина жестко ставим оригинал, чтобы сбросить накопившиеся обороты
	tween.finished.connect(func(): if pcam: pcam.set_third_person_rotation(target_rot))
