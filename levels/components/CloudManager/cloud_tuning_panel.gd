class_name CloudTuningPanel
extends CanvasLayer

const PROFILE_SECTIONS: Array[StringName] = [
	&"Distribution",
	&"Weather Chunks",
	&"Size & Shape",
	&"LOD & Recycling",
]
const WEATHER_SECTIONS: Array[StringName] = [
	&"Wind",
	&"Cloud Motion",
	&"Cloud Lifecycle",
]

var _manager: Node
var _weather_manager: Node
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _stats_accumulator: float = 0.0
var _rebuilding: bool = false

@onready var _root: Control = %Root
@onready var _fields: VBoxContainer = %Fields
@onready var _stats_label: Label = %StatsLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	add_to_group(&"cloud_tuning_panel")
	_root.visible = false
	%RegenerateButton.pressed.connect(_on_regenerate_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%ReloadButton.pressed.connect(_on_reload_pressed)
	%ResetButton.pressed.connect(_on_reset_pressed)


func setup(manager: Node) -> void:
	_manager = manager
	_weather_manager = get_node_or_null("/root/WeatherManager")
	_build_fields()


func is_open() -> bool:
	return is_instance_valid(_root) and _root.visible


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
	if not is_instance_valid(_manager) or not is_instance_valid(_fields):
		return
	var cloud_profile := _manager.get(
		"tuning_profile"
	) as CloudTuningProfile
	if cloud_profile == null:
		return
	if not is_instance_valid(_weather_manager):
		_weather_manager = get_node_or_null("/root/WeatherManager")
	var weather_profile: WeatherProfile
	if is_instance_valid(_weather_manager):
		weather_profile = _weather_manager.get("profile") as WeatherProfile

	_rebuilding = true
	for child in _fields.get_children():
		child.free()
	_add_resource_fields(
		"Cloud",
		cloud_profile,
		PROFILE_SECTIONS,
		Callable(_manager, "apply_tuning_profile")
	)
	if weather_profile != null:
		_add_resource_fields(
			"Weather",
			weather_profile,
			WEATHER_SECTIONS,
			Callable(_weather_manager, "apply_profile")
		)
	_rebuilding = false


func _add_resource_fields(
	title: String,
	resource: Resource,
	allowed_categories: Array[StringName],
	apply_callback: Callable
) -> void:
	_add_category(title)
	for property_info in resource.get_property_list():
		var usage := int(property_info.get("usage", 0))
		var property_name := StringName(property_info.get("name", ""))
		if (usage & PROPERTY_USAGE_CATEGORY) != 0:
			if allowed_categories.has(property_name):
				_add_category("  " + String(property_name))
			continue
		if (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		if property_name == &"script" or property_name == &"resource_path":
			continue
		var property_type := int(property_info.get("type", TYPE_NIL))
		if property_type == TYPE_FLOAT or property_type == TYPE_INT:
			_add_scalar_field(
				resource,
				property_info,
				apply_callback
			)
		elif property_type == TYPE_VECTOR3:
			_add_vector_field(
				resource,
				property_info,
				apply_callback
			)


func _add_category(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(
		"font_size",
		20 if not text.begins_with("  ") else 16
	)
	_fields.add_child(label)


func _add_scalar_field(
	resource: Resource,
	property_info: Dictionary,
	apply_callback: Callable
) -> void:
	var property_name := StringName(property_info.get("name", ""))
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = _pretty_name(property_name)
	label.custom_minimum_size.x = 150.0
	row.add_child(label)

	var spin := SpinBox.new()
	spin.custom_minimum_size.x = 90.0
	spin.allow_greater = true
	spin.allow_lesser = true
	_apply_range_hint(spin, String(property_info.get("hint_string", "")))
	spin.value = float(resource.get(property_name))
	row.add_child(spin)
	_fields.add_child(row)

	var property_hint := int(property_info.get("hint", PROPERTY_HINT_NONE))
	if property_hint == PROPERTY_HINT_RANGE:
		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = spin.min_value
		slider.max_value = spin.max_value
		slider.step = spin.step
		slider.value = spin.value
		row.add_child(slider)
		spin.value_changed.connect(_on_spin_changed.bind(
			resource,
			property_name,
			slider,
			apply_callback
		))
		slider.value_changed.connect(_on_slider_changed.bind(
			resource,
			property_name,
			spin,
			apply_callback
		))
	else:
		spin.value_changed.connect(
			_on_scalar_without_slider_changed.bind(
				resource,
				property_name,
				apply_callback
			)
		)


func _add_vector_field(
	resource: Resource,
	property_info: Dictionary,
	apply_callback: Callable
) -> void:
	var property_name := StringName(property_info.get("name", ""))
	var value: Vector3 = resource.get(property_name)
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = _pretty_name(property_name)
	label.custom_minimum_size.x = 150.0
	row.add_child(label)
	for axis in range(3):
		var spin := SpinBox.new()
		spin.custom_minimum_size.x = 80.0
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.min_value = -10000.0
		spin.max_value = 10000.0
		spin.step = 0.05
		match axis:
			0:
				spin.prefix = "X "
			1:
				spin.prefix = "Y "
			_:
				spin.prefix = "Z "
		spin.value = value[axis]
		spin.value_changed.connect(_on_vector_changed.bind(
			resource,
			property_name,
			axis,
			apply_callback
		))
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
	resource: Resource,
	property_name: StringName,
	slider: HSlider,
	apply_callback: Callable
) -> void:
	if _rebuilding:
		return
	slider.set_value_no_signal(value)
	_set_resource_value(resource, property_name, value, apply_callback)


func _on_slider_changed(
	value: float,
	resource: Resource,
	property_name: StringName,
	spin: SpinBox,
	apply_callback: Callable
) -> void:
	if _rebuilding:
		return
	spin.set_value_no_signal(value)
	_set_resource_value(resource, property_name, value, apply_callback)


func _on_scalar_without_slider_changed(
	value: float,
	resource: Resource,
	property_name: StringName,
	apply_callback: Callable
) -> void:
	if not _rebuilding:
		_set_resource_value(
			resource,
			property_name,
			value,
			apply_callback
		)


func _on_vector_changed(
	value: float,
	resource: Resource,
	property_name: StringName,
	axis: int,
	apply_callback: Callable
) -> void:
	if _rebuilding:
		return
	var vector: Vector3 = resource.get(property_name)
	vector[axis] = value
	resource.set(property_name, vector)
	apply_callback.call(resource)


func _set_resource_value(
	resource: Resource,
	property_name: StringName,
	value: float,
	apply_callback: Callable
) -> void:
	var current_value: Variant = resource.get(property_name)
	if current_value is int:
		resource.set(property_name, roundi(value))
	else:
		resource.set(property_name, value)
	apply_callback.call(resource)


func _on_regenerate_pressed() -> void:
	if is_instance_valid(_manager):
		_manager.call("regenerate_from_profile")
		_set_status("Clouds regenerated")


func _on_save_pressed() -> void:
	if not is_instance_valid(_manager):
		return
	var cloud_error := int(_manager.call("save_tuning_profile"))
	var weather_error := int(_manager.call("save_weather_profile"))
	if cloud_error != OK:
		_set_status("Cloud save: " + error_string(cloud_error))
	elif weather_error != OK:
		_set_status("Weather save: " + error_string(weather_error))
	else:
		_set_status("Cloud and Weather saved to project")


func _on_reload_pressed() -> void:
	if not is_instance_valid(_manager):
		return
	var cloud_error := int(_manager.call("reload_tuning_profile"))
	var weather_error := int(_manager.call("reload_weather_profile"))
	if cloud_error == OK and weather_error == OK:
		_build_fields()
		_set_status("Cloud and Weather reloaded")
	elif cloud_error != OK:
		_set_status("Cloud reload: " + error_string(cloud_error))
	else:
		_set_status("Weather reload: " + error_string(weather_error))


func _on_reset_pressed() -> void:
	if not is_instance_valid(_manager):
		return
	var cloud_profile := _manager.get(
		"tuning_profile"
	) as CloudTuningProfile
	if cloud_profile != null:
		cloud_profile.copy_values_from(CloudTuningProfile.new())
		_manager.call("apply_tuning_profile", cloud_profile)
	if not is_instance_valid(_weather_manager):
		_weather_manager = get_node_or_null("/root/WeatherManager")
	if is_instance_valid(_weather_manager):
		var weather_profile := _weather_manager.get(
			"profile"
		) as WeatherProfile
		if weather_profile != null:
			weather_profile.copy_values_from(WeatherProfile.new())
			_weather_manager.call("apply_profile", weather_profile)
	_build_fields()
	_set_status("Defaults applied (not saved)")


func _set_status(text: String) -> void:
	_status_label.text = text


func _pretty_name(property_name: StringName) -> String:
	return String(property_name).replace("_", " ").capitalize()
