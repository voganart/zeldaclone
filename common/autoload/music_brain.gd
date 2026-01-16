extends Node

# --- НАСТРОЙКИ ВРЕМЕНИ ---
@export var transition_duration: float = 4.0 # Время перехода
@export var overlap_ratio: float = 0.4 # Нахлест (0.4 = 40% времени играют оба)

# Длительность звучания музыки
@export var music_interval_min: float = 25.0
@export var music_interval_max: float = 45.0

# Длительность тишины
@export var silence_interval_min: float = 8.0
@export var silence_interval_max: float = 15.0

@export var combat_cooldown_time: float = 3.0

# Громкость
const VOL_ON: float = 0.0
const VOL_OFF: float = -80.0

# --- ПУТИ К ФАЙЛАМ ---
const MUSIC_PATH = "res://assets/audio/music/"

# --- СОСТОЯНИЕ ---
enum MusicState { MENU, LOADING, EXPLORE, COMBAT }
var current_state = MusicState.MENU

# Добавили SILENCE в список вариантов
enum ExploreArrangement { CALM_ONLY, BASE_ONLY, FULL_MIX, SILENCE }
var current_arrangement = ExploreArrangement.CALM_ONLY

var players: Dictionary = {}
var combat_agents_count: int = 0
var is_playing: bool = false

# Таймеры и Твины
var arrangement_timer: Timer
var combat_exit_timer: Timer
var active_tween: Tween 

var is_first_transition_pending: bool = true

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	arrangement_timer = Timer.new()
	arrangement_timer.one_shot = true
	arrangement_timer.timeout.connect(_on_arrangement_timer_timeout)
	add_child(arrangement_timer)
	
	combat_exit_timer = Timer.new()
	combat_exit_timer.one_shot = true
	combat_exit_timer.timeout.connect(_on_combat_cooldown_ended)
	add_child(combat_exit_timer)
	
	_setup_players()
	call_deferred("_init_default_music_state")

# --- ПУБЛИЧНЫЕ ФУНКЦИИ ---

func play_menu_music():
	print("MusicBrain: Menu State")
	_ensure_playback_started()
	current_state = MusicState.MENU
	arrangement_timer.stop()
	_fade_to_volumes(VOL_ON, VOL_OFF, VOL_OFF, 2.0)

func start_loading_music():
	print("MusicBrain: Loading State")
	current_state = MusicState.LOADING
	arrangement_timer.stop()
	_fade_to_volumes(VOL_OFF, VOL_OFF, VOL_OFF, 0.5)

func play_level_music():
	print("MusicBrain: Level Start")
	_ensure_playback_started()
	
	current_state = MusicState.EXPLORE
	combat_agents_count = 0
	is_first_transition_pending = true
	
	# Старт уровня: Calm
	current_arrangement = ExploreArrangement.CALM_ONLY
	_fade_to_volumes(VOL_OFF, VOL_ON, VOL_OFF, 2.0)
	
	arrangement_timer.start(randf_range(music_interval_min, music_interval_max)) 

func set_combat_state(is_entering_combat: bool):
	if is_entering_combat:
		combat_agents_count += 1
		if combat_agents_count == 1:
			combat_exit_timer.stop()
			_enter_combat_mode()
	else:
		combat_agents_count = max(0, combat_agents_count - 1)
		if combat_agents_count == 0 and combat_exit_timer.is_stopped():
			combat_exit_timer.start(combat_cooldown_time)

# --- ВНУТРЕННЯЯ ЛОГИКА ---

func _init_default_music_state():
	if is_playing: return
	play_menu_music()

func _ensure_playback_started():
	if is_playing: return
	print("MusicBrain: Sync Start")
	for p in players.values():
		if not p.playing:
			p.volume_db = VOL_OFF
			p.play()
	is_playing = true

func _enter_combat_mode():
	if current_state == MusicState.COMBAT: return
	print("MusicBrain: !!! COMBAT !!!")
	current_state = MusicState.COMBAT
	arrangement_timer.set_paused(true)
	# Вход в бой резкий, без нахлеста
	_fade_to_volumes(VOL_OFF, VOL_OFF, VOL_ON, 0.5, false) 

func _on_combat_cooldown_ended():
	if combat_agents_count == 0:
		_exit_combat_mode()

func _exit_combat_mode():
	if current_state != MusicState.COMBAT: return
	print("MusicBrain: Back to Explore")
	current_state = MusicState.EXPLORE
	
	arrangement_timer.set_paused(false)
	if arrangement_timer.is_stopped():
		arrangement_timer.start(1.0) # Сразу переходим к решению, что играть дальше
	
	# Восстанавливаем звук
	_apply_current_exploration_arrangement(3.0)

# --- ГЛАВНАЯ ЛОГИКА ВЫБОРА МУЗЫКИ ---
func _on_arrangement_timer_timeout():
	if current_state != MusicState.EXPLORE: return
	
	if is_first_transition_pending:
		# Первый переход всегда в BASE для динамики
		print("MusicBrain: Scenario -> BASE")
		is_first_transition_pending = false
		current_arrangement = ExploreArrangement.BASE_ONLY
	else:
		# Выбираем новую аранжировку с учетом весов
		var new_arr = current_arrangement
		# Пытаемся не повторяться (но для Тишины можно сделать исключение, если надо)
		var attempts = 0
		while new_arr == current_arrangement and attempts < 5:
			new_arr = _pick_weighted_arrangement()
			attempts += 1
		
		current_arrangement = new_arr
		print("MusicBrain: Cycle -> ", ExploreArrangement.keys()[current_arrangement])

	# Применяем
	_apply_current_exploration_arrangement(transition_duration)
	
	# Выбираем время следующего таймера
	if current_arrangement == ExploreArrangement.SILENCE:
		# Если выпала тишина, пауза короче (8-15 сек)
		arrangement_timer.start(randf_range(silence_interval_min, silence_interval_max))
	else:
		# Если играет музыка, играем дольше (25-45 сек)
		arrangement_timer.start(randf_range(music_interval_min, music_interval_max))

# Функция вероятностей (Шансы тут!)
func _pick_weighted_arrangement() -> int:
	var roll = randf() # Число от 0.0 до 1.0
	
	# Настройка шансов (сумма должна быть 1.0)
	# Calm:    40% (0.00 - 0.40)
	# Silence: 30% (0.40 - 0.70)
	# Base:    20% (0.70 - 0.90)
	# Mix:     10% (0.90 - 1.00)
	
	if roll < 0.40:
		return ExploreArrangement.CALM_ONLY
	elif roll < 0.70:
		return ExploreArrangement.SILENCE
	elif roll < 0.90:
		return ExploreArrangement.BASE_ONLY
	else:
		return ExploreArrangement.FULL_MIX

func _apply_current_exploration_arrangement(fade_time: float):
	match current_arrangement:
		ExploreArrangement.CALM_ONLY:
			_fade_to_volumes(VOL_OFF, VOL_ON, VOL_OFF, fade_time, true)
		
		ExploreArrangement.BASE_ONLY:
			_fade_to_volumes(VOL_ON, VOL_OFF, VOL_OFF, fade_time, true)
		
		ExploreArrangement.FULL_MIX:
			_fade_to_volumes(VOL_ON, VOL_ON, VOL_OFF, fade_time, true)
			
		ExploreArrangement.SILENCE:
			# Для тишины нахлест не нужен, просто плавный Fade Out всего
			_fade_to_volumes(VOL_OFF, VOL_OFF, VOL_OFF, fade_time, false)

# --- МИКШЕР ---

func _setup_players():
	var layer_names = ["Base", "Calm", "Combat"]
	for layer_name in layer_names:
		var stream = load(MUSIC_PATH + "Music_layer_" + layer_name.to_lower() + ".mp3")
		if stream:
			var player = AudioStreamPlayer.new()
			player.stream = stream
			player.name = layer_name
			
			# !!! ВАЖНО: ЗДЕСЬ УКАЗЫВАЕТСЯ ШИНА !!!
			# Если в Audio Layout (снизу) нет шины "Music", звук пойдет в Master
			player.bus = "Music" 
			
			player.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(player)
			players[layer_name] = player

func _fade_to_volumes(base_vol: float, calm_vol: float, combat_vol: float, duration: float, use_overlap: bool = false):
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	active_tween = create_tween().set_parallel()
	
	_tween_single_track(players.get("Base"), base_vol, duration, use_overlap)
	_tween_single_track(players.get("Calm"), calm_vol, duration, use_overlap)
	_tween_single_track(players.get("Combat"), combat_vol, duration, use_overlap)

func _tween_single_track(player: AudioStreamPlayer, target_vol: float, duration: float, use_overlap: bool):
	if not player: return
	
	var current_vol = player.volume_db
	var is_fading_in = target_vol > current_vol
	
	if abs(target_vol - current_vol) < 1.0: return

	if is_fading_in:
		# Fade In: Сразу и быстро
		active_tween.tween_property(player, "volume_db", target_vol, duration)\
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		# Fade Out: С задержкой (если включен нахлест)
		if use_overlap:
			var delay_time = duration * overlap_ratio
			var fade_time = duration - delay_time
			
			active_tween.tween_property(player, "volume_db", target_vol, fade_time)\
				.set_delay(delay_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			active_tween.tween_property(player, "volume_db", target_vol, duration)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
