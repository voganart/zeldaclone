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
@onready var sections: VBoxContainer = $Panel/Margin/Scroll/Sections

const STATS_UPDATE_MSEC := 250
const SPAWN_COUNTS: Array[int] = [1, 3, 5]
const TIME_SCALE_PRESETS: Array[float] = [0.1, 0.25, 0.5, 1.0, 2.0]

var _stats_label: Label
var _checkpoint_list: VBoxContainer
var _god_mode_toggle: CheckBox
var _infinite_health_toggle: CheckBox
var _no_cooldowns_toggle: CheckBox
var _flight_speed_slider: HSlider
var _flight_speed_label: Label
var _time_scale_slider: HSlider
var _time_scale_label: Label
var _enemy_kind_option: OptionButton
var _spawn_count_option: OptionButton
var _freeze_ai_toggle: CheckBox
var _enemy_labels_toggle: CheckBox
var _vision_toggle: CheckBox
var _navigation_toggle: CheckBox
var _collision_toggle: CheckBox
var _next_stats_update_msec := 0


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
	_build_extra_controls()
	DebugTools.state_changed.connect(_sync_state)


func set_open(value: bool) -> void:
	visible = value
	if value:
		vabo_spin_box.value = PlayerData.current_vabo
		status_label.text = ""
		_rebuild_checkpoint_list()
		_sync_state()
		_update_stats()
	else:
		_hide_reset_confirmation()


func _process(_delta: float) -> void:
	if not visible or Time.get_ticks_msec() < _next_stats_update_msec:
		return
	_update_stats()


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


# ============================================================================
# РАСШИРЕННЫЕ КОНТРОЛЫ (строятся в коде, без правки .tscn)
# ============================================================================
func _build_extra_controls() -> void:
	_stats_label = Label.new()
	_stats_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sections.add_child(_stats_label)
	sections.move_child(_stats_label, 1)
	var hotkeys_label := Label.new()
	hotkeys_label.text = "debug_hotkeys_hint"
	hotkeys_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hotkeys_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
	sections.add_child(hotkeys_label)
	sections.move_child(hotkeys_label, 2)

	_add_button(save_content, &"debug_save_now", _on_save_now_pressed)
	_add_button(
		progression_content,
		&"debug_add_vabo",
		_on_add_vabo_pressed
	)
	_checkpoint_list = VBoxContainer.new()
	_checkpoint_list.add_theme_constant_override("separation", 4)
	checkpoint_content.add_child(_checkpoint_list)

	var cheats := _add_section(&"debug_category_cheats")
	_god_mode_toggle = _add_toggle(
		cheats,
		&"debug_god_mode",
		DebugTools.set_god_mode
	)
	_infinite_health_toggle = _add_toggle(
		cheats,
		&"debug_infinite_health",
		DebugTools.set_infinite_health
	)
	_no_cooldowns_toggle = _add_toggle(
		cheats,
		&"debug_no_cooldowns",
		DebugTools.set_no_cooldowns
	)
	_add_button(cheats, &"debug_flight_toggle", _on_flight_toggle_pressed)
	var flight_row := _add_row(cheats)
	_flight_speed_label = _add_value_label(flight_row, &"debug_flight_speed")
	_flight_speed_slider = _add_slider(flight_row, 5.0, 200.0, 5.0)
	_flight_speed_slider.value_changed.connect(_on_flight_speed_changed)

	var time := _add_section(&"debug_category_time")
	var time_row := _add_row(time)
	_time_scale_label = _add_value_label(time_row, &"debug_time_scale")
	_time_scale_slider = _add_slider(
		time_row,
		DebugTools.MIN_TIME_SCALE,
		DebugTools.MAX_TIME_SCALE,
		0.05
	)
	_time_scale_slider.value_changed.connect(DebugTools.set_time_scale)
	var time_buttons := _add_row(time)
	for scale_value: float in TIME_SCALE_PRESETS:
		var scale_button := _add_button(
			time_buttons,
			&"",
			DebugTools.set_time_scale.bind(scale_value)
		)
		scale_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		scale_button.text = "x%s" % scale_value
		scale_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var enemies := _add_section(&"debug_category_enemies")
	var spawn_row := _add_row(enemies)
	_enemy_kind_option = OptionButton.new()
	_enemy_kind_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for kind: StringName in DebugTools.ENEMY_KINDS:
		_enemy_kind_option.add_item("debug_enemy_type_%s" % kind)
	spawn_row.add_child(_enemy_kind_option)
	_spawn_count_option = OptionButton.new()
	_spawn_count_option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for count: int in SPAWN_COUNTS:
		_spawn_count_option.add_item("x%d" % count)
	spawn_row.add_child(_spawn_count_option)
	_add_button(enemies, &"debug_spawn_enemy", _on_spawn_pressed.bind(false))
	_add_button(enemies, &"debug_spawn_elite", _on_spawn_pressed.bind(true))
	_add_button(enemies, &"debug_spawn_wave", _on_spawn_wave_pressed)
	_add_button(enemies, &"debug_kill_all", _on_kill_all_pressed)
	_freeze_ai_toggle = _add_toggle(
		enemies,
		&"debug_freeze_ai",
		DebugTools.set_enemy_ai_frozen
	)

	var ai_debug := _add_section(&"debug_category_ai_debug")
	_enemy_labels_toggle = _add_toggle(
		ai_debug,
		&"debug_enemy_labels",
		DebugTools.set_enemy_debug_labels
	)
	_vision_toggle = _add_toggle(
		ai_debug,
		&"debug_vision_spheres",
		DebugTools.set_enemy_vision_debug
	)
	_navigation_toggle = _add_toggle(
		ai_debug,
		&"debug_navigation",
		DebugTools.set_navigation_debug
	)
	_collision_toggle = _add_toggle(
		ai_debug,
		&"debug_collisions",
		DebugTools.set_collision_debug
	)

	var levels := _add_section(&"debug_category_levels")
	_add_button(levels, &"debug_open_ai_arena", DebugTools.open_ai_test_arena)
	_add_button(
		levels,
		&"debug_back_to_level_01",
		DebugTools.return_to_level_01
	)


func _add_section(title_key: StringName) -> VBoxContainer:
	var header := Button.new()
	header.custom_minimum_size = Vector2(0, 30)
	header.toggle_mode = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	for node: Control in [header, content]:
		sections.add_child(node)
		sections.move_child(node, status_label.get_index())
	_connect_section(header, content, title_key, false)
	return content


func _add_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	return row


func _add_button(
	parent: Control,
	text_key: StringName,
	callback: Callable
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 30)
	button.text = String(text_key)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_toggle(
	parent: Control,
	text_key: StringName,
	callback: Callable
) -> CheckBox:
	var toggle := CheckBox.new()
	toggle.text = String(text_key)
	toggle.toggled.connect(callback)
	parent.add_child(toggle)
	return toggle


func _add_value_label(parent: Control, text_key: StringName) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(120, 0)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.set_meta(&"text_key", text_key)
	parent.add_child(label)
	return label


func _add_slider(
	parent: Control,
	min_value: float,
	max_value: float,
	step: float
) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(slider)
	return slider


func _set_value_label(label: Label, value: float) -> void:
	label.text = "%s: %s" % [
		tr(String(label.get_meta(&"text_key"))),
		snappedf(value, 0.01),
	]


func _sync_state() -> void:
	if not visible:
		return
	_god_mode_toggle.set_pressed_no_signal(DebugTools.god_mode)
	_infinite_health_toggle.set_pressed_no_signal(DebugTools.infinite_health)
	_no_cooldowns_toggle.set_pressed_no_signal(DebugTools.no_cooldowns)
	_freeze_ai_toggle.set_pressed_no_signal(DebugTools.enemy_ai_frozen)
	_enemy_labels_toggle.set_pressed_no_signal(DebugTools.enemy_debug_labels)
	_vision_toggle.set_pressed_no_signal(DebugTools.enemy_vision_debug)
	_navigation_toggle.set_pressed_no_signal(DebugTools.navigation_debug)
	_collision_toggle.set_pressed_no_signal(DebugTools.collision_debug)
	_flight_speed_slider.set_value_no_signal(DebugTools.get_flight_speed())
	_set_value_label(_flight_speed_label, _flight_speed_slider.value)
	_time_scale_slider.set_value_no_signal(DebugTools.get_time_scale())
	_set_value_label(_time_scale_label, _time_scale_slider.value)


func _update_stats() -> void:
	_next_stats_update_msec = Time.get_ticks_msec() + STATS_UPDATE_MSEC
	_stats_label.text = "\n".join(DebugTools.get_stats_lines())


func _rebuild_checkpoint_list() -> void:
	for child: Node in _checkpoint_list.get_children():
		child.queue_free()
	var checkpoints := DebugTools.get_level_checkpoints()
	if checkpoints.is_empty():
		var empty_label := Label.new()
		empty_label.text = "debug_checkpoints_none"
		_checkpoint_list.add_child(empty_label)
		return
	for checkpoint: Node3D in checkpoints:
		var checkpoint_id := String(checkpoint.get("checkpoint_id"))
		if checkpoint_id.is_empty():
			checkpoint_id = String(checkpoint.name)
		var button := _add_button(
			_checkpoint_list,
			&"",
			_on_teleport_to_node_pressed.bind(checkpoint)
		)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.text = tr("debug_teleport_to") % checkpoint_id


func _on_save_now_pressed() -> void:
	_show_status(
		&"debug_status_saved"
		if DebugTools.save_now() == OK
		else &"debug_status_save_failed"
	)


func _on_add_vabo_pressed() -> void:
	DebugTools.add_vabo(100)
	vabo_spin_box.value = PlayerData.current_vabo
	_show_status(&"debug_status_progression_updated")


func _on_flight_toggle_pressed() -> void:
	if not DebugTools.toggle_flight():
		_show_status(&"debug_status_player_missing")


func _on_flight_speed_changed(value: float) -> void:
	DebugTools.set_flight_speed(value)
	_set_value_label(_flight_speed_label, value)


func _on_spawn_pressed(elite: bool) -> void:
	_show_spawn_result(
		DebugTools.spawn_enemies(
			_get_selected_enemy_kind(),
			_get_selected_spawn_count(),
			elite
		)
	)


func _on_spawn_wave_pressed() -> void:
	_show_spawn_result(
		DebugTools.spawn_wave(
			_get_selected_enemy_kind(),
			_get_selected_spawn_count()
		)
	)


func _on_kill_all_pressed() -> void:
	DebugTools.kill_all_enemies()
	_show_status(&"debug_status_enemies_killed")


func _on_teleport_to_node_pressed(node: Node3D) -> void:
	_show_status(
		&"debug_status_checkpoint_teleported"
		if DebugTools.teleport_to_node(node)
		else &"debug_status_checkpoint_missing"
	)


func _show_spawn_result(spawned: int) -> void:
	_show_status(
		&"debug_status_spawned"
		if spawned > 0
		else &"debug_status_spawn_failed"
	)


func _get_selected_enemy_kind() -> StringName:
	return DebugTools.ENEMY_KINDS[maxi(_enemy_kind_option.selected, 0)]


func _get_selected_spawn_count() -> int:
	return SPAWN_COUNTS[maxi(_spawn_count_option.selected, 0)]
