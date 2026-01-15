class_name TutorialRow
extends HBoxContainer

# Убедись, что в сцене TutorialRow.tscn имена узлов совпадают с этими:
@onready var icon_rect: TextureRect = $Icon
@onready var label: Label = $Label

func update_display(icon: Texture2D, text: String) -> void:
	if icon_rect:
		icon_rect.texture = icon
	if label:
		label.text = text

func update_icon(icon: Texture2D) -> void:
	if icon_rect:
		icon_rect.texture = icon
