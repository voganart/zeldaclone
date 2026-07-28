@tool
class_name CloudLodController
extends Node3D

const LodPolicy = preload("res://levels/components/CloudManager/cloud_lod_policy.gd")

enum PreviewMode {
	AUTO,
	FULL_VOLUME,
	CHEAP_VOLUME,
	BILLBOARD,
	TRANSITION,
}

@export_category("Cloud Meshes")
@export var volume_mesh_path: NodePath = NodePath("VolumetricMesh")
@export var impostor_mesh_path: NodePath = NodePath("ImpostorMesh")

@export_category("LOD")
@export_enum("Low", "Medium", "High") var quality_policy: int = LodPolicy.QualityPolicy.HIGH
@export_range(0.0, 10000.0, 1.0, "or_greater") var cheap_volume_start: float = 80.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var transition_start: float = 50.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var transition_end: float = 90.0
@export_range(0.0, 100.0, 0.05, "or_greater") var lod_local_radius: float = 0.5

@export_category("Runtime")
@export var camera_path: NodePath
@export var auto_update_from_camera: bool = true
@export var preview_lod_in_editor: bool = true
@export_enum("Auto", "Full Volume", "Cheap Volume", "Billboard", "Transition")
var preview_mode: int = PreviewMode.AUTO : set = _set_preview_mode
@export_range(0.05, 1.0, 0.05) var update_interval: float = 0.15

@export_category("Editor Preview Shape")
@export var preview_shape_scale: Vector3 = Vector3(70.0, 40.0, 110.0)
@export var preview_shape_offset: Vector3 = Vector3(0.17, 0.33, 0.61)

var _volume_meshes: Array[MeshInstance3D] = []
var _impostor_mesh: MeshInstance3D
var _graphics_manager: Node
var _update_accumulator: float = 0.0
var _pool_fade: float = 1.0


func _ready() -> void:
	_resolve_meshes()
	_update_accumulator = randf_range(0.0, update_interval)
	if Engine.is_editor_hint():
		if preview_lod_in_editor:
			_set_shape_override(true)
			apply_distance(_preview_distance())
		else:
			_set_shape_override(false)
	else:
		_set_shape_override(false)
		_connect_graphics_manager()
		apply_distance(_distance_to_camera())
	set_pool_fade(_pool_fade)


func _process(delta: float) -> void:
	if not auto_update_from_camera:
		return
	if Engine.is_editor_hint() and not preview_lod_in_editor:
		return
	if (
		Engine.is_editor_hint()
		and _is_editing_cloud_scene()
		and preview_mode == PreviewMode.AUTO
	):
		return
	_update_accumulator += delta
	if _update_accumulator < update_interval:
		return
	_update_accumulator = 0.0
	apply_distance(_preview_distance() if Engine.is_editor_hint() else _distance_to_camera())


func apply_distance(distance: float) -> void:
	_resolve_meshes()
	var state: Dictionary = LodPolicy.evaluate(
		distance,
		quality_policy,
		cheap_volume_start,
		transition_start,
		transition_end
	)
	var fade := float(state["lod_fade"])
	var volume_lod_factor := float(state["volume_lod_factor"])

	for volume_mesh in _volume_meshes:
		if not is_instance_valid(volume_mesh):
			continue
		volume_mesh.visible = bool(state["show_volume"])
		volume_mesh.set_instance_shader_parameter(&"lod_fade", fade)
		volume_mesh.set_instance_shader_parameter(&"lod_is_impostor", false)
		volume_mesh.set_instance_shader_parameter(
			&"volume_lod_factor",
			volume_lod_factor
		)

	if is_instance_valid(_impostor_mesh):
		_impostor_mesh.visible = bool(state["show_impostor"])
		_impostor_mesh.set_instance_shader_parameter(&"lod_fade", fade)
		_impostor_mesh.set_instance_shader_parameter(&"lod_is_impostor", true)


func set_quality_policy(value: int) -> void:
	quality_policy = clampi(
		value,
		LodPolicy.QualityPolicy.LOW,
		LodPolicy.QualityPolicy.HIGH
	)
	apply_distance(_preview_distance() if Engine.is_editor_hint() else _distance_to_camera())


func set_pool_fade(value: float) -> void:
	_pool_fade = clampf(value, 0.0, 1.0)
	_resolve_meshes()
	for volume_mesh in _volume_meshes:
		if is_instance_valid(volume_mesh):
			volume_mesh.set_instance_shader_parameter(&"pool_fade", _pool_fade)
	if is_instance_valid(_impostor_mesh):
		_impostor_mesh.set_instance_shader_parameter(&"pool_fade", _pool_fade)


func configure_lod(
	cheap_start_distance: float,
	start_distance: float,
	end_distance: float,
	local_radius: float,
	editor_preview_enabled: bool = true
) -> void:
	cheap_volume_start = maxf(cheap_start_distance, 0.0)
	transition_start = maxf(start_distance, 0.0)
	cheap_volume_start = minf(cheap_volume_start, transition_start)
	transition_end = maxf(end_distance, transition_start + 0.01)
	lod_local_radius = maxf(local_radius, 0.0)
	if Engine.is_editor_hint():
		preview_lod_in_editor = editor_preview_enabled
		_set_shape_override(preview_lod_in_editor)
		if not preview_lod_in_editor:
			return
	apply_distance(_preview_distance() if Engine.is_editor_hint() else _distance_to_camera())


func _set_preview_mode(value: int) -> void:
	preview_mode = value
	if Engine.is_editor_hint() and is_inside_tree() and preview_lod_in_editor:
		apply_distance(_preview_distance())


func _connect_graphics_manager() -> void:
	_graphics_manager = get_node_or_null("/root/GraphicsManager")
	if _graphics_manager == null:
		return
	quality_policy = int(_graphics_manager.current_quality)
	var settings: Dictionary = _graphics_manager.presets.get(
		_graphics_manager.current_quality,
		{}
	)
	_apply_quality_settings(settings)
	if not _graphics_manager.quality_changed.is_connected(_on_graphics_quality_changed):
		_graphics_manager.quality_changed.connect(_on_graphics_quality_changed)


func _on_graphics_quality_changed(settings: Dictionary) -> void:
	_apply_quality_settings(settings)
	apply_distance(_distance_to_camera())


func _apply_quality_settings(settings: Dictionary) -> void:
	if settings.is_empty():
		return
	quality_policy = int(settings.get("cloud_quality", quality_policy))
	cheap_volume_start = float(settings.get(
		"cloud_cheap_start",
		cheap_volume_start
	))
	transition_start = float(settings.get(
		"cloud_transition_start",
		transition_start
	))
	transition_end = maxf(
		float(settings.get("cloud_transition_end", transition_end)),
		transition_start + 0.01
	)
	_set_volume_material_parameter(
		&"steps",
		int(settings.get("cloud_full_steps", 64))
	)
	_set_volume_material_parameter(
		&"cheap_steps",
		int(settings.get("cloud_cheap_steps", 16))
	)
	_set_impostor_material_parameter(
		&"billboard_steps",
		int(settings.get("cloud_billboard_steps", 8))
	)


func _set_volume_material_parameter(name: StringName, value: Variant) -> void:
	_resolve_meshes()
	for volume_mesh in _volume_meshes:
		if not is_instance_valid(volume_mesh):
			continue
		var material := volume_mesh.get_active_material(0) as ShaderMaterial
		if material != null:
			material.set_shader_parameter(name, value)
			return


func _set_impostor_material_parameter(name: StringName, value: Variant) -> void:
	_resolve_meshes()
	if not is_instance_valid(_impostor_mesh):
		return
	var material := _impostor_mesh.get_active_material(0) as ShaderMaterial
	if material != null:
		material.set_shader_parameter(name, value)


func _resolve_meshes() -> void:
	if _volume_meshes.is_empty():
		var primary := get_node_or_null(volume_mesh_path) as MeshInstance3D
		if primary != null:
			_volume_meshes.append(primary)
		_collect_volume_meshes(self)
	if not is_instance_valid(_impostor_mesh):
		_impostor_mesh = get_node_or_null(impostor_mesh_path) as MeshInstance3D


func _collect_volume_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.name.begins_with("VolumetricMesh"):
			var mesh := child as MeshInstance3D
			if not _volume_meshes.has(mesh):
				_volume_meshes.append(mesh)
		_collect_volume_meshes(child)


func _set_shape_override(enabled: bool) -> void:
	_resolve_meshes()
	for volume_mesh in _volume_meshes:
		if not is_instance_valid(volume_mesh):
			continue
		volume_mesh.set_instance_shader_parameter(
			&"shape_override_enabled",
			1.0 if enabled else 0.0
		)
		volume_mesh.set_instance_shader_parameter(&"shape_override_scale", preview_shape_scale)
		volume_mesh.set_instance_shader_parameter(&"shape_override_offset", preview_shape_offset)
	if is_instance_valid(_impostor_mesh):
		_impostor_mesh.set_instance_shader_parameter(
			&"shape_override_enabled",
			1.0 if enabled else 0.0
		)
		_impostor_mesh.set_instance_shader_parameter(
			&"shape_override_scale",
			preview_shape_scale
		)
		_impostor_mesh.set_instance_shader_parameter(
			&"shape_override_offset",
			preview_shape_offset
		)


func _is_editing_cloud_scene() -> bool:
	return Engine.is_editor_hint() and get_tree().edited_scene_root == self


func _editor_preview_distance() -> float:
	if _is_editing_cloud_scene():
		return 0.0
	return _distance_to_camera()


func _preview_distance() -> float:
	match preview_mode:
		PreviewMode.FULL_VOLUME:
			return 0.0
		PreviewMode.CHEAP_VOLUME:
			return lerpf(cheap_volume_start, transition_start, 0.75)
		PreviewMode.BILLBOARD:
			return transition_end + 1.0
		PreviewMode.TRANSITION:
			return lerpf(transition_start, transition_end, 0.5)
		_:
			return _editor_preview_distance()


func _distance_to_camera() -> float:
	var camera := get_node_or_null(camera_path) as Camera3D
	if camera == null and get_viewport() != null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return transition_end
	var center_distance := global_position.distance_to(camera.global_position)
	var world_scale := global_transform.basis.get_scale().abs()
	var world_radius := lod_local_radius * maxf(world_scale.x, maxf(world_scale.y, world_scale.z))
	return maxf(center_distance - world_radius, 0.0)
