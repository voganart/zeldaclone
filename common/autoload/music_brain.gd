extends Node

# Настройки
@export var bpm: float = 120.0
@export var bars: int = 4

# Ссылки на слои
var layers: Dictionary = {} 
var active_layers: Array = [] 
var time_per_beat: float = 0.0
var time_per_bar: float = 0.0

var is_playing: bool = false
var combat_agents_count: int = 0

func _ready():
	if bpm > 0:
		time_per_beat = 60.0 / bpm
		time_per_bar = time_per_beat * 4.0

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
	
	# Сброс состояния
	combat_agents_count = 0
	_update_music_layers(false)

## ПУБЛИЧНАЯ ФУНКЦИЯ ДЛЯ ВРАГОВ
func set_combat_state(enemy_entering_combat: bool):
	if enemy_entering_combat:
		combat_agents_count += 1
	else:
		combat_agents_count = max(0, combat_agents_count - 1)
	
	var is_combat_active = combat_agents_count > 0
	_update_music_layers(is_combat_active)
	
	# print("MusicBrain: Combat Agents = ", combat_agents_count)

func _update_music_layers(is_combat: bool):
	if is_combat:
		# БОЙ: Только агрессия
		_fade_layer("Drums", true, 0.5)
		_fade_layer("Strings", true, 1.0)
		
		# Выключаем мирные инструменты
		_fade_layer("Base", false, 2.0)  # Пианино уходит
		_fade_layer("Flute", false, 1.0) # Флейта уходит
	else:
		# МИР: Спокойствие
		_fade_layer("Drums", false, 2.0)
		_fade_layer("Strings", false, 2.0)
		
		# Включаем мирные
		_fade_layer("Base", true, 2.0)   # Пианино возвращается
		_fade_layer("Flute", true, 3.0)  # Флейта возвращается

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
