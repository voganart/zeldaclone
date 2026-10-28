extends "res://levels/level_01.gd"

# Тестовая арена для настройки ИИ и боёвки.
# Навмеш запекается при старте; способности открываются только в памяти (сейв не пишется).

@export var navigation_region: NavigationRegion3D


func _ready() -> void:
	if navigation_region:
		navigation_region.bake_navigation_mesh(false)
	for ability_name: StringName in DebugTools.ABILITY_NAMES:
		PlayerData.set_ability_unlocked(ability_name, true)
	super._ready()
