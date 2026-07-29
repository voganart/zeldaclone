extends Node

const DEFAULT_MAX_HEALTH := 3.0
const DEFAULT_ABILITIES: Dictionary = {
	"roll_ability": false,
	"double_jump": false,
	"ground_slam": false,
	"air_dash": false,
	"3_hit_combo": false,
}

var current_vabo: int = 0
var max_health: float = DEFAULT_MAX_HEALTH
var abilities: Dictionary = DEFAULT_ABILITIES.duplicate(true)
var completed_persistent_ids: Array[String] = []
var current_level_path: String = ""
var active_checkpoint_id: String = ""

signal vabo_changed(new_amount: int)
signal ability_unlocked(ability_name: StringName)
signal ability_state_changed(
	ability_name: StringName,
	unlocked: bool
)
signal persistent_id_completed(id: StringName)


func add_vabo(amount: int) -> void:
	if amount <= 0:
		return
	set_vabo(current_vabo + amount)


func set_vabo(amount: int) -> bool:
	var normalized_amount := maxi(amount, 0)
	if normalized_amount == current_vabo:
		return false
	current_vabo = normalized_amount
	vabo_changed.emit(current_vabo)
	return true


func reset_progress() -> void:
	current_vabo = 0
	max_health = DEFAULT_MAX_HEALTH
	abilities = DEFAULT_ABILITIES.duplicate(true)
	completed_persistent_ids.clear()
	current_level_path = ""
	active_checkpoint_id = ""
	vabo_changed.emit(current_vabo)


func unlock_ability(ability_name: StringName) -> bool:
	return set_ability_unlocked(ability_name, true)


func set_ability_unlocked(
	ability_name: StringName,
	unlocked: bool
) -> bool:
	var key := String(ability_name)
	if not abilities.has(key) or bool(abilities[key]) == unlocked:
		return false
	abilities[key] = unlocked
	if unlocked:
		ability_unlocked.emit(ability_name)
	ability_state_changed.emit(ability_name, unlocked)
	return true


func is_ability_unlocked(ability_name: StringName) -> bool:
	var key := String(ability_name)
	return abilities.has(key) and bool(abilities[key])


func complete_persistent_id(id: StringName) -> bool:
	var key := String(id)
	if key.is_empty() or completed_persistent_ids.has(key):
		return false
	completed_persistent_ids.append(key)
	persistent_id_completed.emit(id)
	return true


func is_persistent_id_complete(id: StringName) -> bool:
	return completed_persistent_ids.has(String(id))


func create_snapshot() -> Dictionary:
	return {
		"current_vabo": current_vabo,
		"max_health": max_health,
		"abilities": abilities.duplicate(true),
		"completed_persistent_ids": completed_persistent_ids.duplicate(),
		"current_level_path": current_level_path,
		"active_checkpoint_id": active_checkpoint_id,
	}


func apply_snapshot(snapshot: Dictionary) -> void:
	current_vabo = maxi(int(snapshot.get("current_vabo", 0)), 0)
	max_health = maxf(
		float(snapshot.get("max_health", DEFAULT_MAX_HEALTH)),
		1.0
	)

	abilities = DEFAULT_ABILITIES.duplicate(true)
	var saved_abilities: Variant = snapshot.get("abilities", {})
	if saved_abilities is Dictionary:
		for key: String in DEFAULT_ABILITIES:
			if saved_abilities.has(key):
				abilities[key] = bool(saved_abilities[key])

	completed_persistent_ids.clear()
	var saved_ids: Variant = snapshot.get("completed_persistent_ids", [])
	if saved_ids is Array:
		for value: Variant in saved_ids:
			var id := String(value)
			if not id.is_empty() and not completed_persistent_ids.has(id):
				completed_persistent_ids.append(id)

	current_level_path = String(snapshot.get("current_level_path", ""))
	active_checkpoint_id = String(snapshot.get("active_checkpoint_id", ""))
	vabo_changed.emit(current_vabo)
