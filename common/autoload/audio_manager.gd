extends Node

# Для 2D звуков (UI, подбор предметов)
# Добавили аргумент volume_db с дефолтным значением 0.0
func play_ui_sound(stream: AudioStream, volume_db: float = 0.0):
	if not stream: return # Защита от пустых звуков
	
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db # Применяем громкость
	player.bus = "SFX"
	
	add_child(player)
	player.play()
	
	await player.finished
	player.queue_free()
	
# Для 3D звуков (удары, шаги, взрывы)
func play_sfx_3d(stream: AudioStream, position: Vector3, pitch_random: bool = true, volume_db: float = 0.0):
	if not stream: return
	
	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.position = position
	player.volume_db = volume_db 
	player.bus = "SFX"
	
	player.unit_size = 5.0 
	player.max_distance = 20.0
	
	if pitch_random:
		player.pitch_scale = randf_range(0.9, 1.1)
	
	add_child(player)
	player.play()
	
	await player.finished
	player.queue_free()
