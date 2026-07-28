class_name CloudCellLayout
extends RefCounted


static func world_to_cell(position: Vector3, cell_size: float) -> Vector3i:
	var safe_cell_size := maxf(cell_size, 0.001)
	return Vector3i(
		floori(position.x / safe_cell_size),
		floori(position.y / safe_cell_size),
		floori(position.z / safe_cell_size)
	)


static func occupancy_threshold(profile: CloudTuningProfile) -> float:
	if profile == null:
		return 0.0
	var slot_count := _candidate_slot_count(profile)
	return clampf(
		float(profile.target_cloud_count) / float(maxi(slot_count, 1)),
		0.0,
		1.0
	)


static func candidate_cells(
	center: Vector3i,
	profile: CloudTuningProfile
) -> Array[Vector3i]:
	var candidates: Array[Vector3i] = []
	if profile == null:
		return candidates
	var radii := _cell_radii(profile)
	var horizontal_radius := radii.x
	var vertical_radius := radii.y
	var threshold := occupancy_threshold(profile)

	for y in range(-vertical_radius, vertical_radius + 1):
		for z in range(-horizontal_radius, horizontal_radius + 1):
			for x in range(-horizontal_radius, horizontal_radius + 1):
				var offset := Vector3i(x, y, z)
				if not _inside_ellipsoid(
					offset,
					horizontal_radius,
					vertical_radius
				):
					continue
				var cell := center + offset
				if _unit_hash(cell, profile.world_seed, 0) <= threshold:
					candidates.append(cell)

	candidates.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var distance_a := Vector3(a - center).length_squared()
		var distance_b := Vector3(b - center).length_squared()
		if not is_equal_approx(distance_a, distance_b):
			return distance_a > distance_b
		return _cell_hash(a, profile.world_seed, 1) < _cell_hash(
			b,
			profile.world_seed,
			1
		)
	)
	return candidates


static func cell_data(
	cell: Vector3i,
	profile: CloudTuningProfile
) -> Dictionary:
	if profile == null:
		return {}
	var safe_cell_size := maxf(profile.cell_size, 0.001)
	var cell_center := (Vector3(cell) + Vector3.ONE * 0.5) * safe_cell_size
	var offset := Vector3(
		lerpf(-0.35, 0.35, _unit_hash(cell, profile.world_seed, 2)),
		lerpf(-0.3, 0.3, _unit_hash(cell, profile.world_seed, 3)),
		lerpf(-0.35, 0.35, _unit_hash(cell, profile.world_seed, 4))
	) * safe_cell_size
	var cloud_scale := Vector3(
		lerpf(
			profile.scale_min.x,
			profile.scale_max.x,
			_unit_hash(cell, profile.world_seed, 5)
		),
		lerpf(
			profile.scale_min.y,
			profile.scale_max.y,
			_unit_hash(cell, profile.world_seed, 6)
		),
		lerpf(
			profile.scale_min.z,
			profile.scale_max.z,
			_unit_hash(cell, profile.world_seed, 7)
		)
	)
	var aspect_min := maxf(1.0 - profile.aspect_variation, 0.1)
	var aspect_max := 1.0 + profile.aspect_variation
	cloud_scale *= Vector3(
		lerpf(aspect_min, aspect_max, _unit_hash(cell, profile.world_seed, 8)),
		lerpf(aspect_min, aspect_max, _unit_hash(cell, profile.world_seed, 9)),
		lerpf(aspect_min, aspect_max, _unit_hash(cell, profile.world_seed, 10))
	)
	if (
		_unit_hash(cell, profile.world_seed, 11)
		< profile.large_cloud_chance
	):
		cloud_scale *= profile.large_cloud_multiplier

	var yaw := TAU * _unit_hash(cell, profile.world_seed, 12)
	var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(cloud_scale)
	var shape_range := maxf(profile.shape_variation, 0.0)
	var shape_offset := Vector3(
		lerpf(-shape_range, shape_range, _unit_hash(cell, profile.world_seed, 13)),
		lerpf(-shape_range, shape_range, _unit_hash(cell, profile.world_seed, 14)),
		lerpf(-shape_range, shape_range, _unit_hash(cell, profile.world_seed, 15))
	)
	return {
		"transform": Transform3D(basis, cell_center + offset),
		"shape_offset": shape_offset,
		"cloud_radius": 0.5 * maxf(
			cloud_scale.x,
			maxf(cloud_scale.y, cloud_scale.z)
		),
		"priority": _unit_hash(cell, profile.world_seed, 16),
	}


static func _candidate_slot_count(profile: CloudTuningProfile) -> int:
	var radii := _cell_radii(profile)
	var count := 0
	for y in range(-radii.y, radii.y + 1):
		for z in range(-radii.x, radii.x + 1):
			for x in range(-radii.x, radii.x + 1):
				if _inside_ellipsoid(Vector3i(x, y, z), radii.x, radii.y):
					count += 1
	return count


static func _cell_radii(profile: CloudTuningProfile) -> Vector2i:
	return Vector2i(
		maxi(ceili(profile.coverage_radius / profile.cell_size), 1),
		maxi(ceili(profile.coverage_height / profile.cell_size), 1)
	)


static func _inside_ellipsoid(
	offset: Vector3i,
	horizontal_radius: int,
	vertical_radius: int
) -> bool:
	var normalized_x := float(offset.x) / float(maxi(horizontal_radius, 1))
	var normalized_z := float(offset.z) / float(maxi(horizontal_radius, 1))
	var normalized_y := float(offset.y) / float(maxi(vertical_radius, 1))
	return (
		normalized_x * normalized_x
		+ normalized_y * normalized_y
		+ normalized_z * normalized_z
	) <= 1.0


static func _unit_hash(cell: Vector3i, world_seed: int, salt: int) -> float:
	return float(posmod(_cell_hash(cell, world_seed, salt), 1000003)) / 1000003.0


static func _cell_hash(cell: Vector3i, world_seed: int, salt: int) -> int:
	return hash("%d:%d:%d:%d:%d" % [
		cell.x,
		cell.y,
		cell.z,
		world_seed,
		salt,
	])
