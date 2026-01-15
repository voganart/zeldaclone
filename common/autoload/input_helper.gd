extends Node

signal device_changed(device: Device, device_index: int)

enum Device { KEYBOARD, XBOX, PLAYSTATION, SWITCH, GENERIC }

var current_device: Device = Device.KEYBOARD
var current_joy_id: int = 0

# Пути к папкам согласно твоей структуре
const PATH_KEYBOARD = "res://assets/ui/input_prompts/keyboard/"
const PATH_XBOX = "res://assets/ui/input_prompts/xbox/"
const PATH_PS = "res://assets/ui/input_prompts/playstation/"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)

func _input(event: InputEvent) -> void:
	var new_device = current_device
	
	if event is InputEventKey or event is InputEventMouseButton:
		new_device = Device.KEYBOARD
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.2):
		current_joy_id = event.device
		new_device = _get_device_type(Input.get_joy_name(current_joy_id))

	if new_device != current_device:
		current_device = new_device
		device_changed.emit(current_device, current_joy_id)

# --- ГЛАВНАЯ ФУНКЦИЯ ПОЛУЧЕНИЯ ИКОНКИ ---
func get_icon(action_name: String) -> Texture2D:
	# Специальная логика для осей (Ходьба и Камера)
	if action_name == "move":
		return _get_move_icon()
	if action_name == "camera" or action_name == "look":
		return _get_camera_icon()
		
	# Логика для обычных кнопок
	var events = InputMap.action_get_events(action_name)
	if events.is_empty(): return null
	
	for event in events:
		if current_device == Device.KEYBOARD:
			if event is InputEventKey:
				return _get_key_texture(event.physical_keycode)
			if event is InputEventMouseButton:
				return _get_mouse_texture(event.button_index)
		else:
			if event is InputEventJoypadButton:
				return _get_joy_btn_texture(event.button_index)
			# Если действие на курке (Trigger)
			if event is InputEventJoypadMotion: 
				return _get_joy_axis_texture(event.axis)
				
	return null

# --- СПЕЦИАЛЬНЫЕ ИКОНКИ ДЛЯ ОСЕЙ ---
func _get_move_icon() -> Texture2D:
	if current_device == Device.KEYBOARD:
		return load(PATH_KEYBOARD + "keyboard_arrows.png") # Или keyboard_w.png, если хочешь
	elif current_device == Device.PLAYSTATION:
		return load(PATH_PS + "playstation_stick_l.png")
	else:
		return load(PATH_XBOX + "xbox_stick_l.png")

func _get_camera_icon() -> Texture2D:
	if current_device == Device.KEYBOARD:
		return load(PATH_KEYBOARD + "mouse_move.png")
	elif current_device == Device.PLAYSTATION:
		return load(PATH_PS + "playstation_stick_r.png")
	else:
		return load(PATH_XBOX + "xbox_stick_r.png")

# --- ЗАГРУЗЧИКИ ТЕКСТУР ---

func _get_key_texture(keycode: int) -> Texture2D:
	var key_str = OS.get_keycode_string(keycode).to_lower()
	# Обработка спецсимволов, если имена файлов отличаются
	if key_str == "escape": key_str = "escape" # keyboard_escape.png
	if key_str == "space": key_str = "space"   # keyboard_space.png
	if key_str == "shift": key_str = "shift"   # keyboard_shift.png
	
	var path = PATH_KEYBOARD + "keyboard_" + key_str + ".png"
	if ResourceLoader.exists(path): return load(path)
	return load(PATH_KEYBOARD + "keyboard_any.png") # Фолбек

func _get_mouse_texture(btn_idx: int) -> Texture2D:
	match btn_idx:
		MOUSE_BUTTON_LEFT: return load(PATH_KEYBOARD + "mouse_left.png")
		MOUSE_BUTTON_RIGHT: return load(PATH_KEYBOARD + "mouse_right.png")
		MOUSE_BUTTON_MIDDLE: return load(PATH_KEYBOARD + "mouse_scroll.png")
	return load(PATH_KEYBOARD + "mouse.png")

func _get_joy_btn_texture(btn_idx: int) -> Texture2D:
	var file = ""
	if current_device == Device.PLAYSTATION:
		match btn_idx:
			JOY_BUTTON_A: file = "playstation_button_cross.png"
			JOY_BUTTON_B: file = "playstation_button_circle.png"
			JOY_BUTTON_X: file = "playstation_button_square.png"
			JOY_BUTTON_Y: file = "playstation_button_triangle.png"
			JOY_BUTTON_LEFT_SHOULDER: file = "playstation_trigger_l1.png"
			JOY_BUTTON_RIGHT_SHOULDER: file = "playstation_trigger_r1.png"
			JOY_BUTTON_START: file = "playstation3_button_start.png" # Или options для PS4/5
			JOY_BUTTON_BACK: file = "playstation3_button_select.png"
		if file != "": return load(PATH_PS + file)
	else: # XBOX / GENERIC
		match btn_idx:
			JOY_BUTTON_A: file = "xbox_button_a.png"
			JOY_BUTTON_B: file = "xbox_button_b.png"
			JOY_BUTTON_X: file = "xbox_button_x.png"
			JOY_BUTTON_Y: file = "xbox_button_y.png"
			JOY_BUTTON_LEFT_SHOULDER: file = "xbox_lb.png"
			JOY_BUTTON_RIGHT_SHOULDER: file = "xbox_rb.png"
			JOY_BUTTON_START: file = "xbox_button_start.png" # Или menu
			JOY_BUTTON_BACK: file = "xbox_button_back.png" # Или view
		if file != "": return load(PATH_XBOX + file)
	
	return null

func _get_joy_axis_texture(axis: int) -> Texture2D:
	# Обработка курков (LT/RT, L2/R2)
	if axis == JOY_AXIS_TRIGGER_LEFT:
		if current_device == Device.PLAYSTATION: return load(PATH_PS + "playstation_trigger_l2.png")
		return load(PATH_XBOX + "xbox_lt.png")
	if axis == JOY_AXIS_TRIGGER_RIGHT:
		if current_device == Device.PLAYSTATION: return load(PATH_PS + "playstation_trigger_r2.png")
		return load(PATH_XBOX + "xbox_rt.png")
	return null

func _get_device_type(joy_name: String) -> Device:
	joy_name = joy_name.to_lower()
	if "ps" in joy_name or "dual" in joy_name: return Device.PLAYSTATION
	return Device.XBOX
