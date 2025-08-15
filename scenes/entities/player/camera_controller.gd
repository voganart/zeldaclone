extends Node3D

@export var camera_movement_speed := 0.005

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_from_vector(event.relative * camera_movement_speed)
		
func rotate_from_vector(v: Vector2):
	if v.length() == 0: return
	rotation.y -= v.x
