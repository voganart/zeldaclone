@tool
extends Node3D

const CloudCellLayout = preload(
	"res://levels/components/CloudManager/cloud_cell_layout.gd"
)

@export_category("Editor Actions")
@export var generate_clouds: bool = false : set = _on_generate_btn_pressed

@export_category("Main Settings")
@export var cloud_scene: PackedScene
@export var cloud_count: int = 100
@export var tuning_profile: CloudTuningProfile = preload(
	"res://levels/components/CloudManager/cloud_tuning_profile.tres"
)

@export_category("Legacy Settings")
@export var rotation_speed: float = 0.5
@export_enum("Skybox (Legacy)", "World Pool") var mode: int = 1
@export var spawn_radius: float = 150.0
@export var shell_thickness: float = 50.0
@export var recycle_radius: float = 200.0

@export_category("World Pool")
@export var world_seed: int = 1337
@export_range(10.0, 500.0, 1.0) var cell_size: float = 90.0
@export_range(1, 12, 1) var horizontal_cell_radius: int = 4
@export_range(0, 6, 1) var vertical_cell_radius: int = 1
@export_range(0.05, 1.0, 0.05) var cell_density: float = 0.65
@export_range(1, 16, 1) var pool_updates_per_frame: int = 2
@export_range(0.05, 2.0, 0.05) var recycle_fade_duration: float = 0.8

@export_category("Clustering")
@export var use_clustering: bool = true
@export var cluster_count: int = 8
@export var cluster_spread: float = 0.3

@export_category("Random Scale")
@export var scale_min: Vector3 = Vector3(3.0, 1.5, 3.0)
@export var scale_max: Vector3 = Vector3(8.0, 3.0, 8.0)

@export_category("Cloud LOD")
@export_range(0.0, 1000.0, 1.0, "or_greater")
var lod_cheap_volume_start: float = 30.0
@export_range(0.0, 1000.0, 1.0, "or_greater")
var lod_transition_start: float = 70.0
@export_range(0.0, 1000.0, 1.0, "or_greater")
var lod_transition_end: float = 110.0
@export_range(0.0, 10.0, 0.05, "or_greater")
var lod_local_radius: float = 0.5
@export var preview_lod_in_editor: bool = true

var player: Node3D
var _active_cells: Dictionary = {}
var _free_clouds: Array[Node3D] = []
var _requested_cells: Array[Vector3i] = []
var _released_clouds: Array[Node3D] = []
var _recycle_jobs: Dictionary = {}
var _reserved_cells: Dictionary = {}
var _last_player_cell := Vector3i(2147483647, 2147483647, 2147483647)
var _pool_initialized: bool = false
var _pool_settings_dirty: bool = true

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

	var player_cell := CloudCellLayout.world_to_cell(
		player.global_position,
		cell_size
	)
	if player_cell != _last_player_cell or _pool_settings_dirty:
		_request_cells(player_cell)
	_process_relocations()
	_process_recycle_jobs(delta)


func _initialize_runtime_pool() -> void:
	if _pool_initialized:
		return
	if cloud_scene == null:
		push_warning("CloudManager: Cloud Scene not assigned")
		return

	var existing_clouds: Array[Node3D] = []
	for child in get_children():
		if child is Node3D and child.has_method("configure_lod"):
			existing_clouds.append(child as Node3D)

	var pool_size := maxi(cloud_count, 0)
	for index in range(pool_size):
		var cloud: Node3D
		if index < existing_clouds.size():
			cloud = existing_clouds[index]
		else:
			cloud = cloud_scene.instantiate() as Node3D
			add_child(cloud)
		cloud.visible = false
		cloud.call("set_pool_fade", 0.0)
		_configure_cloud_lod(cloud)
		_free_clouds.append(cloud)

	for index in range(pool_size, existing_clouds.size()):
		existing_clouds[index].visible = false

	_pool_initialized = true


func apply_tuning_profile(profile: CloudTuningProfile) -> void:
	if profile == null:
		push_warning("CloudManager: tuning profile is missing")
		return
	tuning_profile = profile
	tuning_profile.sanitize()
	cloud_count = tuning_profile.pool_capacity
	cell_size = tuning_profile.cell_size
	horizontal_cell_radius = ceili(
		tuning_profile.coverage_radius / tuning_profile.cell_size
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
	_configure_existing_cloud_lods()


func _request_cells(center_cell: Vector3i) -> void:
	_last_player_cell = center_cell
	_pool_settings_dirty = false
	var desired := CloudCellLayout.candidate_cells(
		center_cell,
		tuning_profile
	)
	var desired_lookup: Dictionary = {}
	for cell in desired:
		desired_lookup[cell] = true

	for active_cell in _active_cells.keys():
		if desired_lookup.has(active_cell):
			continue
		var released := _active_cells[active_cell] as Node3D
		_active_cells.erase(active_cell)
		_released_clouds.append(released)

	for reserved_cell in _reserved_cells.keys():
		if desired_lookup.has(reserved_cell):
			continue
		var reserved_cloud := _reserved_cells[reserved_cell] as Node3D
		_reserved_cells.erase(reserved_cell)
		if _recycle_jobs.has(reserved_cloud):
			var stale_job: Dictionary = _recycle_jobs[reserved_cloud]
			stale_job["has_target"] = false
			stale_job["phase"] = RecyclePhase.FADING_OUT
			_recycle_jobs[reserved_cloud] = stale_job

	_requested_cells.clear()
	for cell in desired:
		if not _active_cells.has(cell) and not _reserved_cells.has(cell):
			_requested_cells.append(cell)


func _process_relocations() -> void:
	var update_budget := maxi(pool_updates_per_frame, 1)
	while update_budget > 0:
		if not _requested_cells.is_empty():
			var target_cell: Vector3i = _requested_cells.pop_front()
			if _active_cells.has(target_cell) or _reserved_cells.has(target_cell):
				continue
			var cloud: Node3D
			if not _released_clouds.is_empty():
				cloud = _released_clouds.pop_back()
				_start_fade_out(cloud, target_cell, true)
			elif not _free_clouds.is_empty():
				cloud = _free_clouds.pop_back()
				_move_cloud_to_cell(cloud, target_cell)
				_start_fade_in(cloud, target_cell)
			else:
				break
			update_budget -= 1
			continue

		if not _released_clouds.is_empty():
			var released: Node3D = _released_clouds.pop_back()
			_start_fade_out(released, Vector3i.ZERO, false)
			update_budget -= 1
			continue
		break


func _start_fade_out(
	cloud: Node3D,
	target_cell: Vector3i,
	has_target: bool
) -> void:
	if has_target:
		_reserved_cells[target_cell] = cloud
	_recycle_jobs[cloud] = {
		"phase": RecyclePhase.FADING_OUT,
		"fade": 1.0,
		"target_cell": target_cell,
		"has_target": has_target,
	}


func _start_fade_in(cloud: Node3D, target_cell: Vector3i) -> void:
	_reserved_cells[target_cell] = cloud
	cloud.visible = true
	cloud.call("set_pool_fade", 0.0)
	_recycle_jobs[cloud] = {
		"phase": RecyclePhase.FADING_IN,
		"fade": 0.0,
		"target_cell": target_cell,
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
					var target_cell: Vector3i = job["target_cell"]
					_move_cloud_to_cell(cloud, target_cell)
					job["phase"] = RecyclePhase.FADING_IN
				else:
					cloud.visible = false
					_free_clouds.append(cloud)
					_recycle_jobs.erase(cloud)
					continue
		else:
			fade = minf(fade + fade_step, 1.0)
			cloud.call("set_pool_fade", fade)
			if fade >= 1.0:
				var target_cell: Vector3i = job["target_cell"]
				_reserved_cells.erase(target_cell)
				_active_cells[target_cell] = cloud
				_recycle_jobs.erase(cloud)
				continue
		job["fade"] = fade
		_recycle_jobs[cloud] = job


func _move_cloud_to_cell(cloud: Node3D, target_cell: Vector3i) -> void:
	var data := CloudCellLayout.cell_data(target_cell, tuning_profile)
	if data.is_empty():
		return
	var cloud_transform: Transform3D = data["transform"]
	var shape_offset: Vector3 = data["shape_offset"]
	cloud.global_transform = cloud_transform
	cloud.call("set_shape_offset", shape_offset)
	cloud.visible = true


func _configure_existing_cloud_lods() -> void:
	for cloud in get_children():
		_configure_cloud_lod(cloud)


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

	for child in get_children():
		if Engine.is_editor_hint():
			child.free()
		else:
			child.queue_free()

	var cluster_centers: Array[Vector3] = []
	if use_clustering:
		for _index in range(cluster_count):
			cluster_centers.append(Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			).normalized())

	for _index in range(cloud_count):
		var cloud := cloud_scene.instantiate() as Node3D
		add_child(cloud)

		var direction := Vector3.UP
		if use_clustering and not cluster_centers.is_empty():
			var center: Vector3 = cluster_centers.pick_random()
			var offset := Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			) * cluster_spread
			direction = (center + offset).normalized()
		else:
			direction = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0),
				randf_range(-1.0, 1.0)
			).normalized()

		var distance := spawn_radius + randf_range(
			-shell_thickness * 0.5,
			shell_thickness * 0.5
		)
		cloud.position = direction * distance
		cloud.look_at(Vector3(0.0, cloud.position.y, 0.0), Vector3.UP)
		cloud.rotate_y(deg_to_rad(90.0))
		cloud.scale = Vector3(
			randf_range(scale_min.x, scale_max.x),
			randf_range(scale_min.y, scale_max.y),
			randf_range(scale_min.z, scale_max.z)
		)
		_configure_cloud_lod(cloud)

		if Engine.is_editor_hint():
			cloud.owner = get_tree().edited_scene_root
