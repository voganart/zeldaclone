extends Node

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://savegame.json"

var save_path: String = DEFAULT_SAVE_PATH
var invalid_save_recovered: bool = false
var _player_data: Node

signal checkpoint_changed(checkpoint_id: StringName)
signal save_completed(reason: StringName)


func _ready() -> void:
	if not _player_data:
		_player_data = get_node_or_null("/root/PlayerData")
	load_save()


func set_player_data_source(source: Node) -> void:
	_player_data = source


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func start_new_game() -> void:
	clear_save()
	_data().reset_progress()
	invalid_save_recovered = false


func save_checkpoint(level_path: String, checkpoint_id: StringName) -> Error:
	var data := _data()
	if not data:
		return ERR_UNCONFIGURED
	data.current_level_path = level_path
	data.active_checkpoint_id = String(checkpoint_id)
	var error := _write_snapshot()
	if error == OK:
		checkpoint_changed.emit(checkpoint_id)
		save_completed.emit(&"checkpoint")
	return error


func save_permanent_event() -> Error:
	if not _data():
		return ERR_UNCONFIGURED
	var error := _write_snapshot()
	if error == OK:
		save_completed.emit(&"permanent_event")
	return error


func complete_persistent_id(id: StringName) -> bool:
	var data := _data()
	if not data or not data.complete_persistent_id(id):
		return false
	save_permanent_event()
	return true


func is_persistent_id_complete(id: StringName) -> bool:
	var data := _data()
	return data != null and data.is_persistent_id_complete(id)


func load_save() -> bool:
	invalid_save_recovered = false
	if not has_save():
		return false

	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return _recover_invalid_save()
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return _recover_invalid_save()
	var parsed: Variant = json.data

	if not (parsed is Dictionary):
		return _recover_invalid_save()
	var save_data: Dictionary = parsed
	if (
		int(save_data.get("version", -1)) != SAVE_VERSION
		or not (save_data.get("player_data", null) is Dictionary)
	):
		return _recover_invalid_save()

	var data := _data()
	if not data:
		return false
	data.apply_snapshot(save_data["player_data"])
	return true


func clear_save() -> Error:
	var result := OK
	for path: String in [save_path, save_path + ".tmp"]:
		if not FileAccess.file_exists(path):
			continue
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if error != OK:
			result = error
	return result


func _write_snapshot() -> Error:
	var data := _data()
	if not data:
		return ERR_UNCONFIGURED

	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"player_data": data.create_snapshot(),
	}))
	file.flush()
	file.close()

	var target_absolute := ProjectSettings.globalize_path(save_path)
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(save_path):
		var remove_error := DirAccess.remove_absolute(target_absolute)
		if remove_error != OK:
			return remove_error
	return DirAccess.rename_absolute(temporary_absolute, target_absolute)


func _recover_invalid_save() -> bool:
	var data := _data()
	if data:
		data.reset_progress()
	clear_save()
	invalid_save_recovered = true
	return false


func _data() -> Node:
	if not _player_data:
		_player_data = get_node_or_null("/root/PlayerData")
	return _player_data
