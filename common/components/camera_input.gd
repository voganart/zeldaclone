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

var stored_default_rotation: Vector3 = Vector3.ZERO
var is_camera_locked: bool = false 
var active_spring_arm_mask: int = 0

func _ready() -> void:
	if not pcam is PhantomCamera3D:
		set_process(false)
		return
	
	await get_tree().process_frame
	
	# 1. Запоминаем угол
	var current_rot = pcam.get_third_person_rotation()
	if current_rot:
		stored_default_rotation = current_rot
	else:
		stored_default_rotation = Vector3(deg_to_rad(-45), 0, 0)

	# 2. Запоминаем маску коллизии (УНИВЕРСАЛЬНЫЙ МЕТОД)
	active_spring_arm_mask = _get_current_mask()
	print("CameraInput: Saved SpringArm Mask = ", active_spring_arm_mask)

	# 3. Старт
	set_camera_mode(true) 

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(GameConstants.INPUT_TOGGLE_CAMERA):
		set_camera_mode(!is_camera_locked)
		return

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
		# Выключаем коллизию (0)
		_set_mask_value(0)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_tween_to_default_view()
	else:
		# Включаем коллизию (сохраненная или 1 по умолчанию)
		var mask_to_restore = active_spring_arm_mask if active_spring_arm_mask != 0 else 1
		_set_mask_value(mask_to_restore)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# --- ХЕЛПЕРЫ ДЛЯ РАБОТЫ С РАЗНЫМИ ВЕРСИЯМИ PHANTOM CAMERA ---

func _get_current_mask() -> int:
	# 1. Пробуем через Ресурс (Новые версии)
	var params = pcam.get("third_person_parameters")
	if params and "spring_arm_collision_mask" in params:
		return params.spring_arm_collision_mask
	
	# 2. Пробуем напрямую (spring_arm_collision_mask)
	if "spring_arm_collision_mask" in pcam:
		return pcam.spring_arm_collision_mask
	
	# 3. Пробуем напрямую (collision_mask - как у обычного SpringArm3D)
	if "collision_mask" in pcam:
		return pcam.collision_mask
		
	printerr("CameraInput: Could not find any collision mask property!")
	return 1 # Fallback

func _set_mask_value(val: int) -> void:
	# 1. Пробуем через Ресурс
	var params = pcam.get("third_person_parameters")
	if params and "spring_arm_collision_mask" in params:
		params.spring_arm_collision_mask = val
		return
	
	# 2. Пробуем напрямую
	if "spring_arm_collision_mask" in pcam:
		pcam.spring_arm_collision_mask = val
		return
		
	# 3. Пробуем напрямую (collision_mask)
	if "collision_mask" in pcam:
		pcam.collision_mask = val
		return

# -----------------------------------------------------------

func _tween_to_default_view():
	if not pcam: return
	var current_rot = pcam.get_third_person_rotation()
	if current_rot == null: return
	
	var target_rot = stored_default_rotation
	var diff_y = wrapf(target_rot.y - current_rot.y, -PI, PI)
	var smart_target_rot = Vector3(target_rot.x, current_rot.y + diff_y, target_rot.z)
	
	var tween = create_tween()
	tween.tween_method(
		func(val): if pcam: pcam.set_third_person_rotation(val),
		current_rot,
		smart_target_rot,
		0.6
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	tween.finished.connect(func(): if pcam: pcam.set_third_person_rotation(target_rot))
