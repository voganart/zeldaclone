extends BasePickup
@export var heal_amount = 1.0
func _apply_effect(player):
	player.health_component.heal(heal_amount)
	# Индекс 3 - это эффект лечения (зеленые крестики)
	VfxPool.spawn_attached_effect(3, player, Vector3(0, 1.0, 0))
