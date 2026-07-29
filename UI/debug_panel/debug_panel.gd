class_name DebugPanel
extends CanvasLayer

@onready var save_header: Button = $Panel/Margin/Scroll/Sections/SaveHeader
@onready var save_content: VBoxContainer = \
	$Panel/Margin/Scroll/Sections/SaveContent
@onready var player_header: Button = \
	$Panel/Margin/Scroll/Sections/PlayerHeader
@onready var player_content: VBoxContainer = \
	$Panel/Margin/Scroll/Sections/PlayerContent
@onready var progression_header: Button = \
	$Panel/Margin/Scroll/Sections/ProgressionHeader
@onready var progression_content: VBoxContainer = \
	$Panel/Margin/Scroll/Sections/ProgressionContent
@onready var checkpoint_header: Button = \
	$Panel/Margin/Scroll/Sections/CheckpointHeader
@onready var checkpoint_content: VBoxContainer = \
	$Panel/Margin/Scroll/Sections/CheckpointContent
@onready var reset_confirm_label: Label = \
	$Panel/Margin/Scroll/Sections/SaveContent/ResetConfirmLabel
@onready var reset_confirm_row: HBoxContainer = \
	$Panel/Margin/Scroll/Sections/SaveContent/ResetConfirmRow
@onready var vabo_spin_box: SpinBox = \
	$Panel/Margin/Scroll/Sections/ProgressionContent/VaboRow/VaboSpinBox
@onready var status_label: Label = \
	$Panel/Margin/Scroll/Sections/StatusLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/Margin/Scroll/Sections/TitleRow/CloseButton.pressed.connect(
		_on_close_pressed
	)
	_connect_section(
		save_header,
		save_content,
		&"debug_category_save",
		true
	)
	_connect_section(
		player_header,
		player_content,
		&"debug_category_player",
		false
	)
	_connect_section(
		progression_header,
		progression_content,
		&"debug_category_progression",
		false
	)
	_connect_section(
		checkpoint_header,
		checkpoint_content,
		&"debug_category_checkpoint",
		false
	)
	$Panel/Margin/Scroll/Sections/SaveContent/ResetSaveButton.pressed.connect(
		_on_reset_save_pressed
	)
	$Panel/Margin/Scroll/Sections/SaveContent/ResetConfirmRow/ResetConfirmButton.pressed.connect(
		_on_reset_confirmed
	)
	$Panel/Margin/Scroll/Sections/SaveContent/ResetConfirmRow/ResetCancelButton.pressed.connect(
		_hide_reset_confirmation
	)
	$Panel/Margin/Scroll/Sections/PlayerContent/RestoreHealthButton.pressed.connect(
		_on_restore_health_pressed
	)
	$Panel/Margin/Scroll/Sections/PlayerContent/ReloadLevelButton.pressed.connect(
		_on_reload_level_pressed
	)
	$Panel/Margin/Scroll/Sections/ProgressionContent/VaboRow/VaboApplyButton.pressed.connect(
		_on_vabo_apply_pressed
	)
	$Panel/Margin/Scroll/Sections/ProgressionContent/UnlockAllButton.pressed.connect(
		_on_unlock_all_pressed
	)
	$Panel/Margin/Scroll/Sections/ProgressionContent/LockAllButton.pressed.connect(
		_on_lock_all_pressed
	)
	$Panel/Margin/Scroll/Sections/CheckpointContent/TeleportCheckpointButton.pressed.connect(
		_on_teleport_checkpoint_pressed
	)


func set_open(value: bool) -> void:
	visible = value
	if value:
		vabo_spin_box.value = PlayerData.current_vabo
		status_label.text = ""
	else:
		_hide_reset_confirmation()


func _on_close_pressed() -> void:
	DebugTools.set_panel_open(false)


func _connect_section(
	header: Button,
	content: Control,
	title_key: StringName,
	expanded: bool
) -> void:
	header.pressed.connect(
		_toggle_section.bind(header, content, title_key)
	)
	_set_section_expanded(header, content, title_key, expanded)


func _toggle_section(
	header: Button,
	content: Control,
	title_key: StringName
) -> void:
	_set_section_expanded(
		header,
		content,
		title_key,
		not content.visible
	)


func _set_section_expanded(
	header: Button,
	content: Control,
	title_key: StringName,
	expanded: bool
) -> void:
	header.button_pressed = expanded
	content.visible = expanded
	header.text = (
		("▼ " if expanded else "▶ ")
		+ tr(String(title_key))
	)


func _on_reset_save_pressed() -> void:
	reset_confirm_label.visible = true
	reset_confirm_row.visible = true


func _hide_reset_confirmation() -> void:
	reset_confirm_label.visible = false
	reset_confirm_row.visible = false


func _on_reset_confirmed() -> void:
	var error: Error = await DebugTools.reset_save_and_reload()
	if error != OK:
		_show_status(&"debug_status_save_reset_failed")


func _on_restore_health_pressed() -> void:
	_show_status(
		&"debug_status_health_restored"
		if DebugTools.restore_health()
		else &"debug_status_player_missing"
	)


func _on_reload_level_pressed() -> void:
	DebugTools.reload_level()


func _on_vabo_apply_pressed() -> void:
	DebugTools.set_vabo(int(vabo_spin_box.value))
	_show_status(&"debug_status_progression_updated")


func _on_unlock_all_pressed() -> void:
	DebugTools.set_all_abilities(true)
	_show_status(&"debug_status_progression_updated")


func _on_lock_all_pressed() -> void:
	DebugTools.set_all_abilities(false)
	_show_status(&"debug_status_progression_updated")


func _on_teleport_checkpoint_pressed() -> void:
	_show_status(
		&"debug_status_checkpoint_teleported"
		if DebugTools.teleport_to_checkpoint()
		else &"debug_status_checkpoint_missing"
	)


func _show_status(text_key: StringName) -> void:
	status_label.text = tr(String(text_key))
