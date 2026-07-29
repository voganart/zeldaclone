@tool
extends Node3D

const CloudClusterLayout = preload(
	"res://levels/components/CloudManager/cloud_cluster_layout.gd"
)
const CloudExclusionMath = preload(
	"res://levels/components/CloudManager/cloud_exclusion_math.gd"
)
const CloudTuningPanelScene = preload(
	"res://levels/components/CloudManager/cloud_tuning_panel.tscn"
)

signal tuning_profile_changed(profile: CloudTuningProfile)

@export_category("Editor Actions")
@export var generate_clouds: bool = false : set = _on_generate_btn_pressed

@export_category("Main Settings")
@export var cloud_scene: PackedScene
@export_storage var cloud_count: int = 100
@export var tuning_profile: CloudTuningProfile = preload(
	"res://levels/components/CloudManager/cloud_tuning_profile.tres"
)
@export var weather_profile: WeatherProfile = preload(
	"res://common/weather/weather_profile.tres"
)

@export_category("Debug")
@export var enable_runtime_tuning: bool = false

@export_storage var rotation_speed: float = 0.5
@export_storage var mode: int = 1
@export_storage var spawn_radius: float = 150.0
@export_storage var shell_thickness: float = 50.0
@export_storage var recycle_radius: float = 200.0
@export_storage var world_seed: int = 1337
@export_storage var cell_size: float = 90.0
@export_storage var horizontal_cell_radius: int = 4
@export_storage var vertical_cell_radius: int = 1
@export_storage var cell_density: float = 0.65
@export_storage var pool_updates_per_frame: int = 2
@export_storage var recycle_fade_duration: float = 0.8
@export_storage var use_clustering: bool = true
@export_storage var cluster_count: int = 8
@export_storage var cluster_spread: float = 0.3
@export_storage var scale_min: Vector3 = Vector3(3.0, 1.5, 3.0)
@export_storage var scale_max: Vector3 = Vector3(8.0, 3.0, 8.0)
@export_storage var lod_cheap_volume_start: float = 30.0
@export_storage var lod_transition_start: float = 70.0
@export_storage var lod_transition_end: float = 110.0
@export_storage var lod_local_radius: float = 0.5
@export_storage var preview_lod_in_editor: bool = true

var player: Node3D
var _active_cells: Dictionary = {}
var _free_clouds: Array[Node3D] = []
var _requested_cells: Array[Vector4i] = []
var _released_clouds: Array[Node3D] = []
var _recycle_jobs: Dictionary = {}
var _reserved_cells: Dictionary = {}
var _last_player_cell := Vector3i(2147483647, 2147483647, 2147483647)
var _pool_initialized: bool = false
var _pool_settings_dirty: bool = true
var _exclusion_volumes: Array[CloudExclusionVolume] = []
var _preview_clouds: Array[Node3D] = []
var _base_transforms: Dictionary = {}

enum RecyclePhase {
	FADING_OUT,
	FADING_IN,
}


func _on_generate_btn_pressed(value: bool) -> void:
	if value:
		spawn_clouds()
		generate_clouds = false


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_configure_existing_cloud_lods")
	else:
		_apply_weather_profile()
		if tuning_profile == null:
			call_deferred("_preserve_preview_without_streaming")
			return
		apply_tuning_profile(tuning_profile)
		call_deferred("_initialize_runtime_pool")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _pool_initialized:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
		if not is_instance_valid(player):
			return

	var weather_offset := _get_weather_offset()
	_apply_weather_drift(weather_offset)
	_process_preview_clouds()
	var local_player_position := to_local(
		player.global_position - weather_offset
	)
	var player_cell := CloudClusterLayout.world_to_sector(
		local_player_position,
		cell_size
	)
	if player_cell != _last_player_cell or _pool_settings_dirty:
		_request_cells(player_cell)
	_process_relocations()
	_process_recycle_jobs(delta)


func _initialize_runtime_pool() -> void:
	if _pool_initialized:
		return
	if tuning_profile == null:
		_preserve_preview_without_streaming()
		return
	if cloud_scene == null:
		push_warning("CloudManager: Cloud Scene not assigned")
		return

	var existing_clouds: Array[Node3D] = []
	for child in get_children():
		if child is Node3D and child.has_method("configure_lod"):
			existing_clouds.append(child as Node3D)

	var pool_size := maxi(cloud_count, existing_clouds.size())
	for index in range(existing_clouds.size()):
		var cloud: Node3D = existing_clouds[index]
		_preview_clouds.append(cloud)
		_base_transforms[cloud] = cloud.global_transform
		_configure_cloud_lod(cloud)
		cloud.call(
			"set_shape_offset",
			CloudClusterLayout.preview_shape_offset(
				cloud.transform,
				world_seed,
				index,
				tuning_profile.shape_variation
			)
		)
		cloud.visible = true
		cloud.call("set_pool_fade", 1.0)

	for _index in range(existing_clouds.size(), pool_size):
		var cloud := cloud_scene.instantiate() as Node3D
		add_child(cloud)
		cloud.visible = false
		cloud.call("set_pool_fade", 0.0)
		_configure_cloud_lod(cloud)
		_free_clouds.append(cloud)

	_pool_initialized = true
	_refresh_exclusion_volumes()
	if enable_runtime_tuning and OS.is_debug_build():
		_create_tuning_panel()


func _preserve_preview_without_streaming() -> void:
	push_warning(
		"CloudManager: tuning profile is missing; "
		+ "saved preview clouds remain unchanged"
	)
	for child in get_children():
		if not child is Node3D or not child.has_method("configure_lod"):
			continue
		var cloud := child as Node3D
		_preview_clouds.append(cloud)
		_base_transforms[cloud] = cloud.global_transform
		_configure_cloud_lod(cloud)
		cloud.visible = true
		cloud.call("set_pool_fade", 1.0)
	set_process(false)


func _apply_weather_profile() -> void:
	if weather_profile == null:
		return
	var weather_manager := get_node_or_null("/root/WeatherManager")
	if (
		weather_manager != null
		and weather_manager.has_method("apply_profile")
	):
		weather_manager.call("apply_profile", weather_profile, 0.0)


func _get_weather_offset() -> Vector3:
	var weather_manager := get_node_or_null("/root/WeatherManager")
	if (
		weather_manager == null
		or not weather_manager.has_method("get_cloud_offset")
	):
		return Vector3.ZERO
	var value: Variant = weather_manager.call("get_cloud_offset")
	if not value is Vector3:
		return Vector3.ZERO
	var weather_offset: Vector3 = value
	return weather_offset


func _apply_weather_drift(weather_offset: Vector3) -> void:
	for cloud_variant in _base_transforms.keys():
		var cloud := cloud_variant as Node3D
		if not is_instance_valid(cloud):
			_base_transforms.erase(cloud_variant)
			continue
		if not cloud.visible:
			continue
		var base_transform: Transform3D = _base_transforms[cloud_variant]
		cloud.global_transform = base_transform.translated(weather_offset)


func apply_tuning_profile(profile: CloudTuningProfile) -> void:
	if profile == null:
		push_warning("CloudManager: tuning profile is missing")
		return
	tuning_profile = profile
	tuning_profile.sanitize()
	cloud_count = tuning_profile.pool_capacity
	cell_size = tuning_profile.cell_size
	horizontal_cell_radius = ceili(
		(
			tuning_profile.coverage_radius + tuning_profile.prewarm_margin
		) / tuning_profile.cell_size
	)
	vertical_cell_radius = ceili(
		tuning_profile.coverage_height / tuning_profile.cell_size
	)
	cell_density = clampf(
		float(tuning_profile.target_cloud_count)
		/ float(maxi(tuning_profile.pool_capacity * 2, 1)),
		0.01,
		1.0
	)
	world_seed = tuning_profile.world_seed
	scale_min = tuning_profile.scale_min
	scale_max = tuning_profile.scale_max
	lod_cheap_volume_start = tuning_profile.full_volume_distance
	lod_transition_start = tuning_profile.billboard_transition_start
	lod_transition_end = tuning_profile.billboard_transition_end
	recycle_fade_duration = tuning_profile.recycle_fade_duration
	pool_updates_per_frame = tuning_profile.updates_per_frame
	_pool_settings_dirty = true
	_refresh_exclusion_volumes()
	_configure_existing_cloud_lods()
	if _pool_initialized:
		_ensure_pool_capacity()
	tuning_profile_changed.emit(tuning_profile)


func regenerate_from_profile() -> void:
	apply_tuning_profile(tuning_profile)
	_last_player_cell = Vector3i(2147483647, 2147483647, 2147483647)
	_pool_settings_dirty = true


func save_tuning_profile() -> Error:
	if not OS.is_debug_build() or tuning_profile == null:
		return ERR_UNAVAILABLE
	if tuning_profile.resource_path.is_empty():
		return ERR_FILE_BAD_PATH
	tuning_profile.sanitize()
	return ResourceSaver.save(tuning_profile, tuning_profile.resource_path)


func reload_tuning_profile() -> Error:
	if tuning_profile == null or tuning_profile.resource_path.is_empty():
		return ERR_FILE_BAD_PATH
	var loaded_resource := ResourceLoader.load(
		tuning_profile.resource_path,
		"CloudTuningProfile",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	var loaded_profile := loaded_resource as CloudTuningProfile
	if loaded_profile == null:
		return ERR_FILE_CANT_OPEN
	apply_tuning_profile(loaded_profile)
	return OK


func get_cloud_stats() -> Dictionary:
	var stats := {
		"Active": 0,
		"Full": 0,
		"Cheap": 0,
		"Transition": 0,
		"Billboard": 0,
		"Pending": _requested_cells.size(),
		"Capacity": tuning_profile.pool_capacity if tuning_profile != null else cloud_count,
	}
	var seen: Dictionary = {}
	for cloud_variant in _active_cells.values() + _reserved_cells.values():
		var cloud := cloud_variant as Node3D
		if not is_instance_valid(cloud) or seen.has(cloud):
			continue
		seen[cloud] = true
		stats["Active"] = int(stats["Active"]) + 1
		if cloud.has_method("get_lod_mode"):
			var mode := String(cloud.call("get_lod_mode"))
			if stats.has(mode):
				stats[mode] = int(stats[mode]) + 1
	return stats


func _ensure_pool_capacity() -> void:
	if tuning_profile == null or cloud_scene == null:
		return
	var pool_clouds: Array[Node3D] = []
	for child in get_children():
		if child is Node3D and child.has_method("configure_lod"):
			pool_clouds.append(child as Node3D)
	while pool_clouds.size() < tuning_profile.pool_capacity:
		var cloud := cloud_scene.instantiate() as Node3D
		add_child(cloud)
		cloud.visible = false
		cloud.call("set_pool_fade", 0.0)
		_configure_cloud_lod(cloud)
		_free_clouds.append(cloud)
		pool_clouds.append(cloud)


func _create_tuning_panel() -> void:
	if not OS.is_debug_build() or not is_inside_tree():
		return
	var panel := CloudTuningPanelScene.instantiate()
	get_tree().root.add_child(panel)
	panel.call("setup", self)
	tree_exiting.connect(func():
		if is_instance_valid(panel):
			panel.queue_free()
	)


func _refresh_exclusion_volumes() -> void:
	_exclusion_volumes.clear()
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(&"cloud_exclusion"):
		if node is CloudExclusionVolume:
			_exclusion_volumes.append(node as CloudExclusionVolume)


func _member_is_excluded(key: Vector4i) -> bool:
	if _exclusion_volumes.is_empty() or tuning_profile == null:
		return false
	var data := CloudClusterLayout.member_data(key, tuning_profile)
	if data.is_empty():
		return false
	var cloud_transform: Transform3D = data["transform"]
	var cloud_radius: float = data["cloud_radius"]
	var cloud_world_position := (
		to_global(cloud_transform.origin)
		+ _get_weather_offset()
	)
	for volume in _exclusion_volumes:
		if (
			is_instance_valid(volume)
			and CloudExclusionMath.intersects_cloud(
				volume,
				cloud_world_position,
				cloud_radius
			)
		):
			return true
	return false


func _member_overlaps_preview(key: Vector4i) -> bool:
	if _preview_clouds.is_empty():
		return false
	var data := CloudClusterLayout.member_data(key, tuning_profile)
	if data.is_empty():
		return false
	var transform: Transform3D = data["transform"]
	var radius: float = float(data["cloud_radius"]) + cell_size * 0.35
	var world_origin := (
		to_global(transform.origin)
		+ _get_weather_offset()
	)
	for cloud in _preview_clouds:
		if (
			is_instance_valid(cloud)
			and cloud.global_position.distance_to(world_origin) < radius
		):
			return true
	return false


func _process_preview_clouds() -> void:
	if not is_instance_valid(player) or tuning_profile == null:
		return
	var keep_distance := (
		tuning_profile.coverage_radius
		+ tuning_profile.retention_margin
	)
	var preview_copy: Array[Node3D] = _preview_clouds.duplicate()
	for cloud in preview_copy:
		if not is_instance_valid(cloud):
			_preview_clouds.erase(cloud)
			continue
		if cloud.global_position.distance_to(player.global_position) <= keep_distance:
			continue
		_preview_clouds.erase(cloud)
		_start_fade_out(cloud, Vector4i.ZERO, false)
		_pool_settings_dirty = true


func _request_cells(center_cell: Vector3i) -> void:
	_last_player_cell = center_cell
	_pool_settings_dirty = false
	var visible_members := CloudClusterLayout.candidate_members(
		center_cell,
		tuning_profile
	)
	visible_members.reverse()
	var prewarm_members := CloudClusterLayout.candidate_members(
		center_cell,
		tuning_profile,
		tuning_profile.prewarm_margin
	)
	var retained := CloudClusterLayout.candidate_members(
		center_cell,
		tuning_profile,
		tuning_profile.retention_margin
	)
	var desired: Array[Vector4i] = []
	var desired_lookup: Dictionary = {}
	var visible_lookup: Dictionary = {}
	for key in visible_members:
		if (
			not _member_is_excluded(key)
			and not _member_overlaps_preview(key)
		):
			visible_lookup[key] = true
	for key in visible_members + prewarm_members:
		if (
			desired_lookup.has(key)
			or _member_is_excluded(key)
			or _member_overlaps_preview(key)
		):
			continue
		desired.append(key)
		desired_lookup[key] = true
	var request_limit := maxi(
		tuning_profile.pool_capacity - _preview_clouds.size(),
		0
	)
	if desired.size() > request_limit:
		desired.resize(request_limit)
		desired_lookup.clear()
		for key in desired:
			desired_lookup[key] = true
	var retained_lookup: Dictionary = {}
	for key in retained:
		retained_lookup[key] = true

	for active_key in _active_cells.keys():
		if retained_lookup.has(active_key):
			continue
		var released := _active_cells[active_key] as Node3D
		_active_cells.erase(active_key)
		_released_clouds.append(released)

	for reserved_key in _reserved_cells.keys():
		if retained_lookup.has(reserved_key):
			continue
		var reserved_cloud := _reserved_cells[reserved_key] as Node3D
		_reserved_cells.erase(reserved_key)
		if _recycle_jobs.has(reserved_cloud):
			var stale_job: Dictionary = _recycle_jobs[reserved_cloud]
			stale_job["has_target"] = false
			stale_job["phase"] = RecyclePhase.FADING_OUT
			_recycle_jobs[reserved_cloud] = stale_job

	_release_for_visible_members(visible_lookup, desired_lookup)
	_requested_cells.clear()
	for key in desired:
		if (
			desired_lookup.has(key)
			and not _active_cells.has(key)
			and not _reserved_cells.has(key)
		):
			_requested_cells.append(key)


func _release_for_visible_members(
	visible_lookup: Dictionary,
	desired_lookup: Dictionary
) -> void:
	var missing_visible := 0
	for key in visible_lookup:
		if (
			desired_lookup.has(key)
			and not _active_cells.has(key)
			and not _reserved_cells.has(key)
		):
			missing_visible += 1
	var available_capacity := _free_clouds.size() + _released_clouds.size()
	missing_visible = maxi(missing_visible - available_capacity, 0)
	if missing_visible <= 0:
		return
	for active_key in _active_cells.keys():
		if missing_visible <= 0:
			break
		if visible_lookup.has(active_key):
			continue
		var released := _active_cells[active_key] as Node3D
		_active_cells.erase(active_key)
		desired_lookup.erase(active_key)
		_released_clouds.append(released)
		missing_visible -= 1


func _process_relocations() -> void:
	var update_budget := maxi(pool_updates_per_frame, 1)
	while update_budget > 0:
		if not _requested_cells.is_empty():
			var target_key: Vector4i = _requested_cells.front()
			if _active_cells.has(target_key) or _reserved_cells.has(target_key):
				_requested_cells.pop_front()
				continue
			var cloud: Node3D
			var recycle_existing := false
			if not _released_clouds.is_empty():
				cloud = _released_clouds.pop_back()
				recycle_existing = true
			elif not _free_clouds.is_empty():
				cloud = _free_clouds.pop_back()
			else:
				break
			_requested_cells.pop_front()
			if recycle_existing:
				_start_fade_out(cloud, target_key, true)
			else:
				_move_cloud_to_member(cloud, target_key)
				_start_fade_in(cloud, target_key)
			update_budget -= 1
			continue

		if not _released_clouds.is_empty():
			var released: Node3D = _released_clouds.pop_back()
			_start_fade_out(released, Vector4i.ZERO, false)
			update_budget -= 1
			continue
		break


func _start_fade_out(
	cloud: Node3D,
	target_key: Vector4i,
	has_target: bool
) -> void:
	if has_target:
		_reserved_cells[target_key] = cloud
	_recycle_jobs[cloud] = {
		"phase": RecyclePhase.FADING_OUT,
		"fade": 1.0,
		"target_key": target_key,
		"has_target": has_target,
	}


func _start_fade_in(cloud: Node3D, target_key: Vector4i) -> void:
	_reserved_cells[target_key] = cloud
	cloud.visible = true
	cloud.call("set_pool_fade", 0.0)
	_recycle_jobs[cloud] = {
		"phase": RecyclePhase.FADING_IN,
		"fade": 0.0,
		"target_key": target_key,
		"has_target": true,
	}


func _process_recycle_jobs(delta: float) -> void:
	var fade_step := delta / maxf(recycle_fade_duration, 0.01)
	for cloud_variant in _recycle_jobs.keys():
		var cloud := cloud_variant as Node3D
		if not is_instance_valid(cloud):
			_recycle_jobs.erase(cloud_variant)
			continue
		var job: Dictionary = _recycle_jobs[cloud]
		var phase := int(job["phase"])
		var fade := float(job["fade"])
		if phase == RecyclePhase.FADING_OUT:
			fade = maxf(fade - fade_step, 0.0)
			cloud.call("set_pool_fade", fade)
			if fade <= 0.0:
				if bool(job["has_target"]):
					var target_key: Vector4i = job["target_key"]
					_move_cloud_to_member(cloud, target_key)
					job["phase"] = RecyclePhase.FADING_IN
				else:
					cloud.visible = false
					_free_clouds.append(cloud)
					_recycle_jobs.erase(cloud)
					if not _requested_cells.is_empty():
						_pool_settings_dirty = true
					continue
		else:
			fade = minf(fade + fade_step, 1.0)
			cloud.call("set_pool_fade", fade)
			if fade >= 1.0:
				var target_key: Vector4i = job["target_key"]
				_reserved_cells.erase(target_key)
				_active_cells[target_key] = cloud
				_recycle_jobs.erase(cloud)
				if not _requested_cells.is_empty():
					_pool_settings_dirty = true
				continue
		job["fade"] = fade
		_recycle_jobs[cloud] = job


func _move_cloud_to_member(cloud: Node3D, target_key: Vector4i) -> void:
	var data := CloudClusterLayout.member_data(target_key, tuning_profile)
	if data.is_empty():
		return
	var cloud_transform: Transform3D = data["transform"]
	var shape_offset: Vector3 = data["shape_offset"]
	var base_transform := global_transform * cloud_transform
	var weather_offset := _get_weather_offset()
	_base_transforms[cloud] = base_transform
	cloud.global_transform = base_transform.translated(weather_offset)
	cloud.call("set_shape_offset", shape_offset)
	cloud.visible = true


func _configure_existing_cloud_lods() -> void:
	var preview_index := 0
	for cloud in get_children():
		_configure_cloud_lod(cloud)
		if (
			cloud is Node3D
			and cloud.has_method("set_shape_offset")
			and tuning_profile != null
		):
			cloud.call(
				"set_shape_offset",
				CloudClusterLayout.preview_shape_offset(
					(cloud as Node3D).transform,
					tuning_profile.world_seed,
					preview_index,
					tuning_profile.shape_variation
				)
			)
			preview_index += 1


func _configure_cloud_lod(cloud: Node) -> void:
	if not cloud.has_method("configure_lod"):
		return
	if tuning_profile != null and cloud.has_method("configure_from_profile"):
		cloud.call("configure_from_profile", tuning_profile)
		return
	cloud.call(
		"configure_lod",
		lod_cheap_volume_start,
		lod_transition_start,
		lod_transition_end,
		lod_local_radius,
		preview_lod_in_editor
	)


func spawn_clouds() -> void:
	if cloud_scene == null:
		push_warning("CloudManager: Cloud Scene not assigned")
		return
	if tuning_profile == null:
		push_warning("CloudManager: tuning profile is missing")
		return

	for child in get_children():
		if not child.has_method("configure_lod"):
			continue
		if Engine.is_editor_hint():
			child.free()
		else:
			child.queue_free()

	tuning_profile.sanitize()
	var preview_keys := CloudClusterLayout.preview_members(tuning_profile)
	var preview_count := mini(cloud_count, preview_keys.size())
	for index in range(preview_count):
		var key: Vector4i = preview_keys[index]
		var data := CloudClusterLayout.member_data(key, tuning_profile)
		if data.is_empty() or _member_is_excluded(key):
			continue
		var cloud := cloud_scene.instantiate() as Node3D
		add_child(cloud)
		var cloud_transform: Transform3D = data["transform"]
		cloud.transform = cloud_transform
		cloud.call("set_shape_offset", data["shape_offset"])
		_configure_cloud_lod(cloud)

		if Engine.is_editor_hint():
			cloud.owner = get_tree().edited_scene_root
