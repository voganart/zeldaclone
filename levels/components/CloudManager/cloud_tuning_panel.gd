class_name CloudTuningPanel
extends CanvasLayer

const PROFILE_SECTIONS := [&"Distribution", &"Size & Shape", &"LOD & Recycling"]

var _manager: Node
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _stats_accumulator: float = 0.0
var _rebuilding: bool = false

@onready var _root: Control = %Root
@onready var _fields: VBoxContainer = %Fields
@onready var _stats_label: Label = %StatsLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_root.visible = false
	%RegenerateButton.pressed.connect(_on_regenerate_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%ReloadButton.pressed.connect(_on_reload_pressed)
	%ResetButton.pressed.connect(_on_reset_pressed)


func setup(manager: Node) -> void:
	_manager = manager
	_build_fields()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(GameConstants.INPUT_CLOUD_TUNING_TOGGLE):
		_set_open(not _root.visible)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _root.visible or not is_instance_valid(_manager):
		return
	_stats_accumulator += delta
	if _stats_accumulator < 0.25:
		return
	_stats_accumulator = 0.0
	var stats: Dictionary = _manager.call("get_cloud_stats")
	_stats_label.text = (
		"Active %d | Full %d | Cheap %d | Transition %d | "
		+ "Billboard %d | Pending %d | Capacity %d"
	) % [
		int(stats.get("Active", 0)),
		int(stats.get("Full", 0)),
		int(stats.get("Cheap", 0)),
		int(stats.get("Transition", 0)),
		int(stats.get("Billboard", 0)),
		int(stats.get("Pending", 0)),
		int(stats.get("Capacity", 0)),
	]


func _set_open(value: bool) -> void:
	if value == _root.visible:
		return
	_root.visible = value
	if value:
		_previous_mouse_mode = Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_build_fields()
	else:
		Input.set_mouse_mode(_previous_mouse_mode)


func _build_fields() -> void:
	if not is_instance_valid(_manager):
		return
	var profile := _manager.get("tuning_profile") as CloudTuningProfile
	if profile == null or not is_instance_valid(_fields):
		return
	_rebuilding = true
	for child in _fields.get_children():
		child.free()

	for property_info in profile.get_property_list():
		var usage := int(property_info.get("usage", 0))
		var property_name := StringName(property_info.get("name", ""))
		if (usage & PROPERTY_USAGE_CATEGORY) != 0:
			_add_category(String(property_name))
			continue
		if (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		if property_name == &"script" or property_name == &"resource_path":
			continue
		var property_type := int(property_info.get("type", TYPE_NIL))
		if property_type == TYPE_FLOAT or property_type == TYPE_INT:
			_add_scalar_field(profile, property_info)
		elif property_type == TYPE_VECTOR3:
			_add_vector_field(profile, property_info)
	_rebuilding = false


func _add_category(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	_fields.add_child(label)


func _add_scalar_field(
	profile: CloudTuningProfile,
	property_info: Dictionary
) -> void:
	var property_name := StringName(property_info.get("name", ""))
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = _pretty_name(property_name)
	label.custom_minimum_size.x = 190.0
	row.add_child(label)

	var spin := SpinBox.new()
	spin.custom_minimum_size.x = 110.0
	spin.allow_greater = true
	spin.allow_lesser = true
	_apply_range_hint(spin, String(property_info.get("hint_string", "")))
	spin.value = float(profile.get(property_name))
	row.add_child(spin)

	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = spin.min_value
	slider.max_value = spin.max_value
	slider.step = spin.step
	slider.value = spin.value
	row.add_child(slider)
	_fields.add_child(row)

	spin.value_changed.connect(
		_on_spin_changed.bind(property_name, slider)
	)
	slider.value_changed.connect(
		_on_slider_changed.bind(property_name, spin)
	)


func _add_vector_field(
	profile: CloudTuningProfile,
	property_info: Dictionary
) -> void:
	var property_name := StringName(property_info.get("name", ""))
	var value: Vector3 = profile.get(property_name)
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = _pretty_name(property_name)
	label.custom_minimum_size.x = 190.0
	row.add_child(label)
	for axis in range(3):
		var spin := SpinBox.new()
		spin.custom_minimum_size.x = 100.0
		spin.allow_greater = true
		spin.allow_lesser = false
		spin.min_value = 0.01
		spin.max_value = 1000.0
		spin.step = 1.0
		spin.prefix = ["X ", "Y ", "Z "][axis]
		spin.value = value[axis]
		spin.value_changed.connect(
			_on_vector_changed.bind(property_name, axis)
		)
		row.add_child(spin)
	_fields.add_child(row)


func _apply_range_hint(spin: SpinBox, hint_string: String) -> void:
	var parts := hint_string.split(",")
	if parts.size() >= 2:
		spin.min_value = float(parts[0])
		spin.max_value = float(parts[1])
	if parts.size() >= 3:
		spin.step = maxf(float(parts[2]), 0.0001)
	if spin.max_value <= spin.min_value:
		spin.min_value = 0.0
		spin.max_value = 5000.0
		spin.step = 1.0


func _on_spin_changed(
	value: float,
	property_name: StringName,
	slider: HSlider
) -> void:
	if _rebuilding:
		return
	slider.set_value_no_signal(value)
	_set_profile_value(property_name, value)


func _on_slider_changed(
	value: float,
	property_name: StringName,
	spin: SpinBox
) -> void:
	if _rebuilding:
		return
	spin.set_value_no_signal(value)
	_set_profile_value(property_name, value)


func _on_vector_changed(
	value: float,
	property_name: StringName,
	axis: int
) -> void:
	if _rebuilding or not is_instance_valid(_manager):
		return
	var profile := _manager.get("tuning_profile") as CloudTuningProfile
	if profile == null:
		return
	var vector: Vector3 = profile.get(property_name)
	vector[axis] = value
	profile.set(property_name, vector)
	_manager.call("apply_tuning_profile", profile)


func _set_profile_value(property_name: StringName, value: float) -> void:
	if not is_instance_valid(_manager):
		return
	var profile := _manager.get("tuning_profile") as CloudTuningProfile
	if profile == null:
		return
	var current_value: Variant = profile.get(property_name)
	if current_value is int:
		profile.set(property_name, roundi(value))
	else:
		profile.set(property_name, value)
	_manager.call("apply_tuning_profile", profile)


func _on_regenerate_pressed() -> void:
	if is_instance_valid(_manager):
		_manager.call("regenerate_from_profile")
		_set_status("Regenerated")


func _on_save_pressed() -> void:
	if not is_instance_valid(_manager):
		return
	var error := int(_manager.call("save_tuning_profile"))
	_set_status("Saved to project" if error == OK else error_string(error))


func _on_reload_pressed() -> void:
	if not is_instance_valid(_manager):
		return
	var error := int(_manager.call("reload_tuning_profile"))
	if error == OK:
		_build_fields()
	_set_status("Reloaded" if error == OK else error_string(error))


func _on_reset_pressed() -> void:
	if not is_instance_valid(_manager):
		return
	var profile := _manager.get("tuning_profile") as CloudTuningProfile
	if profile == null:
		return
	profile.copy_values_from(CloudTuningProfile.new())
	_manager.call("apply_tuning_profile", profile)
	_build_fields()
	_set_status("Defaults applied (not saved)")


func _set_status(text: String) -> void:
	_status_label.text = text


func _pretty_name(property_name: StringName) -> String:
	return String(property_name).replace("_", " ").capitalize()
