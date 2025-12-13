extends Node

@export_group("Settings")
@export var trauma_decay: float = 2.0
@export var max_position_shake: Vector3 = Vector3(1.5, 1.5, 1.5)
@export var max_rotation_shake: Vector3 = Vector3(5.0, 5.0, 5.0)

var trauma: float = 0.0
var pcam: PhantomCamera3D

func _ready() -> void:
	pcam = get_parent() as PhantomCamera3D
	if not pcam:
		print("ERROR: CameraShaker не нашел PhantomCamera3D!")
		return
	
	# Проверка ресурса шума
	if not pcam.noise:
		print("ERROR: В PhantomCamera3D не назначен ресурс Noise!")
	else:
		print("DEBUG: Noise ресурс найден. Класс: ", pcam.noise.get_class())
		# Выведем свойства, чтобы узнать их точные имена
		print("DEBUG: Свойства ресурса Noise:")
		for prop in pcam.noise.get_property_list():
			if "amplitude" in prop.name:
				print("- ", prop.name)

	add_to_group("camera_shaker")
	print("DEBUG: CameraShaker инициализирован и добавлен в группу.")

func _process(delta: float) -> void:
	if trauma <= 0: return
	
	trauma = max(trauma - delta * trauma_decay, 0.0)
	_apply_shake_to_pcam()

func add_trauma(amount: float) -> void:
	print("DEBUG: add_trauma вызван! Было: ", trauma, " Стало: ", trauma + amount)
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _apply_shake_to_pcam() -> void:
	if not pcam.noise: return
	
	var shake_power = trauma * trauma
	var noise_res = pcam.noise
	
	# 1. Пробуем positional_amplitude (обычно это Vector3)
	if "positional_amplitude" in noise_res:
		# Проверяем тип текущего значения
		var current_val = noise_res.get("positional_amplitude")
		if typeof(current_val) == TYPE_VECTOR3:
			noise_res.positional_amplitude = max_position_shake * shake_power
		elif typeof(current_val) == TYPE_FLOAT:
			# Если вдруг это число, берем длину вектора или просто X
			noise_res.positional_amplitude = max_position_shake.x * shake_power

	# 2. Пробуем просто amplitude (обычно это float)
	elif "amplitude" in noise_res:
		# Если свойство называется amplitude, оно скорее всего float
		noise_res.amplitude = max_position_shake.x * shake_power
		
	# 3. Пробуем rotational_amplitude
	if "rotational_amplitude" in noise_res:
		var current_rot = noise_res.get("rotational_amplitude")
		if typeof(current_rot) == TYPE_VECTOR3:
			noise_res.rotational_amplitude = max_rotation_shake * shake_power
		elif typeof(current_rot) == TYPE_FLOAT:
			noise_res.rotational_amplitude = max_rotation_shake.x * shake_power
