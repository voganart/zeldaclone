class_name CloudCellLayout
extends RefCounted


static func world_to_cell(position: Vector3, cell_size: float) -> Vector3i:
	var safe_cell_size := maxf(cell_size, 0.001)
	return Vector3i(
		floori(position.x / safe_cell_size),
		floori(position.y / safe_cell_size),
		floori(position.z / safe_cell_size)
	)


static func desired_cells(
	center: Vector3i,
	horizontal_radius: int,
	vertical_radius: int,
	density: float,
	world_seed: int,
	limit: int
) -> Array[Vector3i]:
	horizontal_radius = maxi(horizontal_radius, 1)
	vertical_radius = maxi(vertical_radius, 0)
	density = clampf(density, 0.0, 1.0)
	limit = maxi(limit, 0)

	var candidates: Array[Vector3i] = []
	for y in range(-vertical_radius, vertical_radius + 1):
		for z in range(-horizontal_radius, horizontal_radius + 1):
			for x in range(-horizontal_radius, horizontal_radius + 1):
				var normalized_x := float(x) / float(horizontal_radius)
				var normalized_z := float(z) / float(horizontal_radius)
				var normalized_y := 0.0
				if vertical_radius > 0:
					normalized_y = float(y) / float(vertical_radius)
				var ellipsoid_distance := (
					normalized_x * normalized_x
					+ normalized_y * normalized_y
					+ normalized_z * normalized_z
				)
				if ellipsoid_distance > 1.0:
					continue
				var cell := center + Vector3i(x, y, z)
				if _unit_hash(cell, world_seed, 0) <= density:
					candidates.append(cell)

	candidates.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var distance_a := Vector3(a - center).length_squared()
		var distance_b := Vector3(b - center).length_squared()
		if not is_equal_approx(distance_a, distance_b):
			return distance_a < distance_b
		return _cell_hash(a, world_seed, 1) < _cell_hash(b, world_seed, 1)
	)
	if candidates.size() > limit:
		candidates.resize(limit)
	return candidates


static func cell_transform(
	cell: Vector3i,
	cell_size: float,
	world_seed: int,
	scale_min: Vector3,
	scale_max: Vector3
) -> Transform3D:
	var safe_cell_size := maxf(cell_size, 0.001)
	var cell_center := (Vector3(cell) + Vector3.ONE * 0.5) * safe_cell_size
	var offset := Vector3(
		lerpf(-0.35, 0.35, _unit_hash(cell, world_seed, 2)),
		lerpf(-0.3, 0.3, _unit_hash(cell, world_seed, 3)),
		lerpf(-0.35, 0.35, _unit_hash(cell, world_seed, 4))
	) * safe_cell_size
	var cloud_scale := Vector3(
		lerpf(scale_min.x, scale_max.x, _unit_hash(cell, world_seed, 5)),
		lerpf(scale_min.y, scale_max.y, _unit_hash(cell, world_seed, 6)),
		lerpf(scale_min.z, scale_max.z, _unit_hash(cell, world_seed, 7))
	)
	var yaw := TAU * _unit_hash(cell, world_seed, 8)
	var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(cloud_scale)
	return Transform3D(basis, cell_center + offset)


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
