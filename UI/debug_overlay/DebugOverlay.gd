extends CanvasLayer

@onready var fps_label = $MarginContainer/VBoxContainer/FPS
@onready var stats_label = $MarginContainer/VBoxContainer/Stats

func _process(_delta):
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	var mem = float(OS.get_static_memory_usage()) / 1024.0 / 1024.0
	var obj = Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)


	stats_label.text = "Memory: %.2f MB\nObjects: %d\nNodes: %d\nDrawCalls: %d" % [mem, obj, nodes, draw_calls]
