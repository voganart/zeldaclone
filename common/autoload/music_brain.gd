extends Node

# Настройки
@export var bpm: float = 120.0
@export var bars: int = 4
@export var combat_cooldown_time: float = 4.0 # Сколько секунд музыка играет после конца боя

# Ссылки на слои
var layers: Dictionary = {} 
var active_layers: Array = [] 
var time_per_beat: float = 0.0
var time_per_bar: float = 0.0

var is_playing: bool = false
var combat_agents_count: int = 0

# Таймер задержки
var combat_exit_timer: Timer

func _ready():
	if bpm > 0:
		time_per_beat = 60.0 / bpm
		time_per_bar = time_per_beat * 4.0
	
	# Создаем таймер программно
	combat_exit_timer = Timer.new()
	combat_exit_timer.one_shot = true
	combat_exit_timer.wait_time = combat_cooldown_time
	combat_exit_timer.timeout.connect(_on_combat_cooldown_ended)
	add_child(combat_exit_timer)

func setup_track(track_name: String, stream: AudioStream, bus: String = "Music"):
	var p = AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = -80.0
	p.autoplay = false
	add_child(p)
	layers[track_name] = p

func start_music():
	is_playing = true
	for key in layers:
		var p = layers[key]
		if p.stream:
			p.play()
	
	combat_agents_count = 0
	_update_music_layers(false)

## ПУБЛИЧНАЯ ФУНКЦИЯ ДЛЯ ВРАГОВ
func set_combat_state(enemy_entering_combat: bool):
	if enemy_entering_combat:
		combat_agents_count += 1
	else:
		combat_agents_count = max(0, combat_agents_count - 1)
	
	# ЛОГИКА ЗАДЕРЖКИ
	if combat_agents_count > 0:
		# Если есть враги - немедленно включаем бой и отменяем таймер выхода
		combat_exit_timer.stop()
		_update_music_layers(true)
	else:
		# Если врагов стало 0 - НЕ выключаем музыку сразу!
		# Запускаем таймер. Если за это время никто не нападет снова, музыка утихнет.
		if combat_exit_timer.is_stopped():
			combat_exit_timer.start(combat_cooldown_time)

func _on_combat_cooldown_ended():
	# Двойная проверка: точно ли врагов нет?
	if combat_agents_count == 0:
		_update_music_layers(false)

func _update_music_layers(is_combat: bool):
	if is_combat:
		# --- ВХОД В БОЙ ---
		# Атака (Вступление) должно быть резким и быстрым
		_fade_layer("Drums", true, 0.5)   # Барабаны врываются за полсекунды
		_fade_layer("Strings", true, 1.0) # Скрипки подтягиваются
		
		# Релиз (Уход) мирной музыки должен быть медленным, 
		# чтобы она еще звучала, пока барабаны разгоняются
		_fade_layer("Base", false, 4.0)   # Пианино уходит очень долго
		_fade_layer("Flute", false, 2.0)
	else:
		# --- ВЫХОД ИЗ БОЯ ---
		# Мирная музыка возвращается довольно быстро, чтобы заполнить пустоту
		_fade_layer("Base", true, 1.5)
		_fade_layer("Flute", true, 2.0)
		
		# Боевая музыка уходит очень-очень плавно (эхо войны)
		_fade_layer("Drums", false, 5.0)
		_fade_layer("Strings", false, 5.0)

func _fade_layer(layer_name: String, active: bool, duration: float):
	var player = layers.get(layer_name)
	if not player: return
	
	var target_db = 0.0 if active else -80.0
	
	if player.has_meta("tween"):
		var existing_tween = player.get_meta("tween")
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, duration)
	player.set_meta("tween", tween)
