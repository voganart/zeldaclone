@tool
class_name CloudTuningProfile
extends Resource

@export_group("Distribution")
@export_range(100.0, 5000.0, 10.0) var coverage_radius: float = 1400.0
@export_range(50.0, 2000.0, 10.0) var coverage_height: float = 350.0
@export_range(1, 500, 1) var target_cloud_count: int = 80
@export_range(1, 500, 1) var pool_capacity: int = 96
@export_range(25.0, 500.0, 5.0) var cell_size: float = 120.0
@export var world_seed: int = 1337

@export_group("Size & Shape")
@export var scale_min: Vector3 = Vector3(40.0, 20.0, 70.0)
@export var scale_max: Vector3 = Vector3(120.0, 90.0, 180.0)
@export_range(0.0, 1.0, 0.01) var aspect_variation: float = 0.35
@export_range(0.0, 1.0, 0.01) var large_cloud_chance: float = 0.2
@export_range(1.0, 3.0, 0.05) var large_cloud_multiplier: float = 1.5
@export_range(0.0, 10.0, 0.05) var shape_variation: float = 2.0

@export_group("LOD & Recycling")
@export_range(0.0, 1000.0, 5.0) var full_volume_distance: float = 120.0
@export_range(0.0, 2000.0, 5.0) var cheap_volume_distance: float = 250.0
@export_range(0.0, 3000.0, 5.0) var billboard_transition_start: float = 280.0
@export_range(0.0, 4000.0, 5.0) var billboard_transition_end: float = 420.0
@export_range(0.05, 3.0, 0.05) var recycle_fade_duration: float = 1.0
@export_range(1, 16, 1) var updates_per_frame: int = 3


func sanitize() -> void:
	coverage_radius = maxf(coverage_radius, 100.0)
	coverage_height = maxf(coverage_height, 50.0)
	target_cloud_count = maxi(target_cloud_count, 1)
	pool_capacity = maxi(pool_capacity, target_cloud_count)
	cell_size = maxf(cell_size, 25.0)
	scale_min = Vector3(
		maxf(scale_min.x, 0.01),
		maxf(scale_min.y, 0.01),
		maxf(scale_min.z, 0.01)
	)
	scale_max = Vector3(
		maxf(scale_max.x, scale_min.x),
		maxf(scale_max.y, scale_min.y),
		maxf(scale_max.z, scale_min.z)
	)
	aspect_variation = clampf(aspect_variation, 0.0, 1.0)
	large_cloud_chance = clampf(large_cloud_chance, 0.0, 1.0)
	large_cloud_multiplier = maxf(large_cloud_multiplier, 1.0)
	shape_variation = maxf(shape_variation, 0.0)
	full_volume_distance = maxf(full_volume_distance, 0.0)
	cheap_volume_distance = maxf(cheap_volume_distance, full_volume_distance)
	billboard_transition_start = maxf(
		billboard_transition_start,
		cheap_volume_distance
	)
	billboard_transition_end = maxf(
		billboard_transition_end,
		billboard_transition_start + 0.01
	)
	recycle_fade_duration = maxf(recycle_fade_duration, 0.05)
	updates_per_frame = maxi(updates_per_frame, 1)


func copy_values_from(source: CloudTuningProfile) -> void:
	if source == null:
		return
	for property_info in get_property_list():
		var usage := int(property_info.get("usage", 0))
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var property_name := StringName(property_info.get("name", ""))
		if property_name == &"script" or property_name == &"resource_path":
			continue
		set(property_name, source.get(property_name))
	sanitize()
