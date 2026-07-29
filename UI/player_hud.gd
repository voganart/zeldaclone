@tool
class_name PlayerHUD
extends Control

@export_category("References")
@export var player_path: NodePath
@onready var tutorial_overlay: TutorialOverlay = $TutorialOverlay 
@onready var save_feedback: Label = $SaveFeedback
@onready var vabo_value: Label = \
	$HealthContainer/HealthStack/VaboOffset/VaboContainer/VaboValue
@onready var hearts_container: HBoxContainer = \
	$HealthContainer/HealthStack/HeartsLayout
@onready var roll_container: HBoxContainer = \
	$ActionsContainer/AbilityStrip/RollContainer
@onready var double_jump_icon: TextureRect = \
	$ActionsContainer/AbilityStrip/DoubleJumpIcon
@onready var slam_bar: TextureProgressBar = \
	$ActionsContainer/AbilityStrip/SlamIcon
@onready var air_dash_bar: TextureProgressBar = \
	$ActionsContainer/AbilityStrip/AirDashIcon
@onready var combo_bar: TextureProgressBar = \
	$ActionsContainer/AbilityStrip/ComboIcon

@onready var pips: Array[TextureProgressBar] = [
	$ActionsContainer/AbilityStrip/RollContainer/Pip1,
	$ActionsContainer/AbilityStrip/RollContainer/Pip2,
	$ActionsContainer/AbilityStrip/RollContainer/Pip3,
]

@export_category("Visual Settings")
@export var pip_texture: Texture2D 
@export var slam_texture: Texture2D
@export var heart_texture: Texture2D 
@export var heart_size: Vector2 = Vector2(32, 32) ## Размер иконки сердца

@export_group("Colors")
@export var color_ready: Color = Color("ffffff")
@export var color_recharging: Color = Color("ffffff80")
@export var color_background: Color = Color("00000060")
@export var color_penalty: Color = Color("ff4d4d")
@export var color_unavailable: Color = Color("777777cc")

@export_group("Health Colors")
@export var color_heart_full: Color = Color("ff3333")
@export var color_heart_empty: Color = Color("33000080")

# --- ПРЕВЬЮ В РЕДАКТОРЕ ---
@export_group("Editor Preview")
@export_range(0, 20) var debug_hearts_count: int = 3:
	set(value):
		debug_hearts_count = value
		# Обновляем только если мы в редакторе
		if Engine.is_editor_hint() and is_node_ready():
			_setup_hearts(float(value))
			_update_hearts(float(value)) # Заполняем их полностью для вида

var player: Player
var hearts: Array[TextureRect] = []
var save_feedback_tween: Tween

func _ready() -> void:
	# Настройка иконок
	if pip_texture:
		for pip in pips: _setup_progress_bar(pip, pip_texture)
	if slam_texture:
		_setup_progress_bar(slam_bar, slam_texture)
	
	# === ЛОГИКА РЕДАКТОРА ===
	if Engine.is_editor_hint():
		# Просто рисуем превью и выходим, не ищем игрока
		_setup_hearts(float(debug_hearts_count))
		_update_hearts(float(debug_hearts_count))
		return
	# ========================
	_connect_progress_signals()
	_sync_progress_feedback()
	if not GameEvents.save_feedback_requested.is_connected(
		_on_save_feedback_requested
	):
		GameEvents.save_feedback_requested.connect(
			_on_save_feedback_requested
		)
	await get_tree().process_frame
	if not player:
		_find_player()

	
	if player and player.health_component:
		_setup_hearts(player.health_component.max_health)
		_update_hearts(player.health_component.current_health)


func _connect_progress_signals() -> void:
	if not PlayerData.vabo_changed.is_connected(_on_vabo_changed):
		PlayerData.vabo_changed.connect(_on_vabo_changed)
	if not PlayerData.ability_unlocked.is_connected(_on_ability_unlocked):
		PlayerData.ability_unlocked.connect(_on_ability_unlocked)


func _sync_progress_feedback() -> void:
	_on_vabo_changed(PlayerData.current_vabo)
	var indicators: Dictionary = {
		&"roll_ability": roll_container,
		&"double_jump": double_jump_icon,
		&"ground_slam": slam_bar,
		&"air_dash": air_dash_bar,
		&"3_hit_combo": combo_bar,
	}
	for ability_name: StringName in indicators:
		var indicator: Control = indicators[ability_name]
		if indicator is TextureRect and indicator.texture == null:
			indicator.visible = false
			continue
		indicator.visible = PlayerData.is_ability_unlocked(ability_name)


func _on_vabo_changed(new_amount: int) -> void:
	vabo_value.text = str(maxi(new_amount, 0))


func _on_ability_unlocked(_ability_name: StringName) -> void:
	_sync_progress_feedback()


func setup_player(new_player: Player) -> void:
	player = new_player
	
	# Отключаем старые сигналы HP, если были
	if GameEvents.player_health_changed.is_connected(_on_health_changed):
		GameEvents.player_health_changed.disconnect(_on_health_changed)
	
	# Подключаем новые сигналы HP
	GameEvents.player_health_changed.connect(_on_health_changed)
	
	# Инициализируем UI Здоровья
	if player.health_component:
		_setup_hearts(player.health_component.max_health)
		_update_hearts(player.health_component.current_health)
		
	# Подключаем сигнал переката
	if player.roll_ability:
		# Создаем Callable для обновления UI переката
		var roll_update_func = Callable(self, "_on_roll_charges_changed_from_player")
		
		# Если уже подключено - отключаем (на случай рестарта)
		if player.roll_ability.roll_charges_changed.is_connected(roll_update_func):
			player.roll_ability.roll_charges_changed.disconnect(roll_update_func)
			
		player.roll_ability.roll_charges_changed.connect(roll_update_func)
		
		# Принудительно обновляем UI сразу
		_update_roll_pips()

# Вспомогательная функция, чтобы сигнал приходил корректно
func _on_roll_charges_changed_from_player(_current: int, _max_val: int, _is_penalty: bool) -> void:
	# Мы просто вызываем обновление UI, так как оно берет данные из переменной player
	_update_roll_pips()
func _setup_progress_bar(bar: TextureProgressBar, tex: Texture2D) -> void:
	bar.texture_under = tex
	bar.texture_progress = tex
	bar.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	bar.tint_under = color_background
	bar.tint_progress = color_ready
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0

func _setup_hearts(max_hp: float) -> void:
	# Если контейнер еще не готов (бывает при загрузке сцены), пропускаем
	if not hearts_container: return
	
	# Очищаем старые
	for child in hearts_container.get_children():
		child.queue_free()
	hearts.clear()
	
	var count = ceil(max_hp)
	
	for i in range(count):
		var heart = TextureRect.new()
		heart.texture = heart_texture
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# ИСПОЛЬЗУЕМ НАСТРОЙКУ РАЗМЕРА
		heart.custom_minimum_size = heart_size 
		
		hearts_container.add_child(heart)
		hearts.append(heart)

func _find_player() -> void:
	if has_node(player_path):
		player = get_node(player_path)
	else:
		player = get_tree().get_first_node_in_group("player")
		
	if player:
		GameEvents.player_health_changed.connect(_on_health_changed)

func _process(_delta: float) -> void:
	# В редакторе process не гоняем
	if Engine.is_editor_hint(): return
	if not player: return
	
	_update_roll_pips()
	_update_double_jump_icon()
	_update_slam_bar()
	_update_air_dash_bar()
	_update_combo_bar()

func _on_health_changed(current: float, _max: float) -> void:
	_update_hearts(current)

func _update_hearts(current_hp: float) -> void:
	for i in range(hearts.size()):
		var heart = hearts[i]
		if (i + 1) <= current_hp:
			heart.modulate = color_heart_full
		else:
			heart.modulate = color_heart_empty

func _update_roll_pips() -> void:
	if not player.roll_ability or not player.roll_ability.is_unlocked:
		roll_container.visible = false
		return
	roll_container.visible = true

	var current_charges = player.current_roll_charges
	var is_penalty = player.is_roll_recharging
	
	for i in range(pips.size()):
		var pip = pips[i]
		if is_penalty:
			pip.tint_progress = color_penalty
			var max_p = player.roll_recharge_time
			if max_p > 0: pip.value = 1.0 - (player.roll_penalty_timer / max_p)
			else: pip.value = 0.0
			continue
		
		pip.tint_progress = color_ready
		if i < current_charges:
			pip.value = 1.0
		elif i == current_charges:
			var max_t = player.roll_cooldown
			if max_t > 0: 
				pip.value = 1.0 - (player.roll_regen_timer / max_t)
				pip.tint_progress = color_recharging
			else: 
				pip.value = 1.0
		else:
			pip.value = 0.0

func _update_slam_bar() -> void:
	if not player.ground_slam_ability or not player.ground_slam_ability.is_unlocked:
		slam_bar.visible = false
		return
	slam_bar.visible = true
	_update_cooldown_bar(
		slam_bar,
		player.ground_slam_ability.cooldown_timer,
		player.ground_slam_ability.slam_cooldown
	)


func _update_double_jump_icon() -> void:
	if not PlayerData.is_ability_unlocked(&"double_jump"):
		double_jump_icon.visible = false
		return
	double_jump_icon.visible = true
	double_jump_icon.modulate = (
		color_ready if player.current_jump_count < 2 else color_unavailable
	)


func _update_air_dash_bar() -> void:
	var ability: AirDashAbility = player.air_dash_ability
	if not ability or not ability.is_unlocked:
		air_dash_bar.visible = false
		return
	air_dash_bar.visible = true
	_update_cooldown_bar(
		air_dash_bar,
		maxf(ability.cooldown_timer, 0.0),
		ability.air_dash_cooldown
	)
	if ability.cooldown_timer <= 0.0 and ability.dash_used_in_air:
		air_dash_bar.tint_progress = color_unavailable


func _update_combo_bar() -> void:
	if not PlayerData.is_ability_unlocked(&"3_hit_combo"):
		combo_bar.visible = false
		return
	combo_bar.visible = true
	if not player.combat_component:
		return
	var timer: Timer = player.combat_component.combo_cooldown_timer
	var time_left: float = 0.0
	if timer and not timer.is_stopped():
		time_left = timer.time_left
	_update_cooldown_bar(
		combo_bar,
		time_left,
		player.combat_component.combo_cooldown_after_combo
	)


func _update_cooldown_bar(
	bar: TextureProgressBar,
	time_left: float,
	max_time: float
) -> void:
	if max_time <= 0.0 or time_left <= 0.0:
		bar.value = 1.0
		bar.tint_progress = color_ready
		return
	bar.value = clampf(1.0 - (time_left / max_time), 0.0, 1.0)
	bar.tint_progress = color_recharging


func _on_save_feedback_requested(text_key: StringName) -> void:
	save_feedback.text = tr(String(text_key))
	if save_feedback_tween and save_feedback_tween.is_valid():
		save_feedback_tween.kill()
	save_feedback.modulate.a = 0.0
	save_feedback_tween = create_tween()
	save_feedback_tween.tween_property(
		save_feedback,
		"modulate:a",
		1.0,
		0.2
	)
	save_feedback_tween.tween_interval(1.2)
	save_feedback_tween.tween_property(
		save_feedback,
		"modulate:a",
		0.0,
		0.4
	)
