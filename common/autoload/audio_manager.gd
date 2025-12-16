extends Node
# Каналы для музыки
var music_player: AudioStreamPlayer

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music" # Убедись, что создал шину Music в настройках аудио
	add_child(music_player)

func play_music(stream: AudioStream, fade_duration: float = 1.0):
	if music_player.stream == stream:
		return
		
	# Простой кроссфейд (можно усложнить через Tween)
	music_player.stream = stream
	music_player.play()

# Для 2D звуков (UI и т.д.)
func play_ui_sound(stream: AudioStream):
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	add_child(player)
	player.play()
	await player.finished
	player.queue_free()
	
func play_sfx_3d(stream: AudioStream, position: Vector3, pitch_random: bool = true, volume_db: float = 0.0):
	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.position = position
	player.volume_db = volume_db # Применяем громкость
	player.bus = "SFX"
	
	# Настройка дистанции (чтобы ящики не было слышно за километр)
	player.unit_size = 5.0 
	player.max_distance = 20.0
	
	if pitch_random:
		player.pitch_scale = randf_range(0.9, 1.1)
	
	add_child(player)
	player.play()
	await player.finished
	player.queue_free()
