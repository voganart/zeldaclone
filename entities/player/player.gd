extends CharacterBody3D

@onready var anim_controller: Node = $AnimController
@onready var move_controller: Node = $MoveController

func _physics_process(delta: float) -> void:
	move_controller.move_logic(delta)
	move_controller.jump_logic(delta)
	move_controller.rot_char(delta)
	move_controller.tilt_character(delta)
	anim_controller.animation_player()
	move_and_slide()
