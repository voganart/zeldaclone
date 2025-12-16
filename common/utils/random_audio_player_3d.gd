class_name RandomAudioPlayer3D
extends AudioStreamPlayer3D

@export var streams: Array[AudioStream]
@export var randomize_pitch: bool = true
@export var min_pitch: float = 0.9
@export var max_pitch: float = 1.1

func play_random():
	if streams.is_empty():
		# Если массив пуст, пробуем проиграть то, что назначено в stream
		if stream:
			_apply_pitch()
			play()
		return

	# Выбираем случайный звук из списка
	stream = streams.pick_random()
	_apply_pitch()
	play()

func _apply_pitch():
	if randomize_pitch:
		pitch_scale = randf_range(min_pitch, max_pitch)
	else:
		pitch_scale = 1.0
