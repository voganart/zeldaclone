extends BasePickup

## Ability ID registered in PlayerData, for example:
## roll_ability, double_jump, ground_slam, air_dash, 3_hit_combo.
@export var skill_id: StringName = &""


func _apply_effect(player) -> void:
	player.unlock_ability(String(skill_id))
