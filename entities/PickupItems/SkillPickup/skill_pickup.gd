class_name SkillPickup
extends BasePickup

## Ability ID registered in PlayerData, for example:
## roll_ability, double_jump, ground_slam, air_dash, 3_hit_combo.
@export var skill_id: StringName = &""


func set_ability_id(ability_id: StringName) -> void:
	skill_id = ability_id


func _apply_effect(player) -> void:
	if skill_id.is_empty():
		push_warning("SkillPickup: ability_id is empty")
		return
	player.unlock_ability(String(skill_id))


func reset_state() -> void:
	super()
	skill_id = &""
