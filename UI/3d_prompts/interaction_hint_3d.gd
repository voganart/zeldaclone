extends Node3D

@onready var icon: Sprite3D = $Icon
@onready var label: Label3D = $Label

var current_action: String = ""

func _ready():
	InputHelper.device_changed.connect(_on_device_changed)
	# Анимация появления
	scale = Vector3.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func setup(action: String, text: String):
	current_action = action
	label.text = text # Текст уже должен быть переведен через tr() перед передачей
	_update_icon()

func _on_device_changed(_device, _id):
	_update_icon()

func _update_icon():
	var tex = InputHelper.get_icon(current_action)
	if tex:
		icon.texture = tex
		icon.visible = true
	else:
		icon.visible = false

func close():
	InputHelper.device_changed.disconnect(_on_device_changed)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15)
	await tween.finished
	queue_free()
