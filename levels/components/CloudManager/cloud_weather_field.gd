class_name CloudWeatherField
extends RefCounted

const DEFAULT_FORMATION_LIFETIME_MIN := 360.0
const DEFAULT_FORMATION_LIFETIME_MAX := 900.0
const DEFAULT_FORMATION_FADE_DURATION := 90.0


static func candidate_chunks(
	center: Vector3i,
	profile: CloudTuningProfile
) -> Array[Vector3i]:
	var chunks: Array[Vector3i] = []
	if profile == null:
		return chunks
	var horizontal_radius: int = (
		profile.horizontal_chunk_radius
		+ profile.horizontal_prewarm_chunks
	)
	var vertical_radius: int = (
		profile.vertical_chunk_radius
		+ profile.vertical_prewarm_chunks
	)
	for y in range(-vertical_radius, vertical_radius + 1):
		for z in range(-horizontal_radius, horizontal_radius + 1):
			for x in range(-horizontal_radius, horizontal_radius + 1):
				var offset := Vector3i(x, y, z)
				if not _inside_chunk_ellipsoid(
					offset,
					horizontal_radius,
					vertical_radius
				):
					continue
				var chunk := center + offset
				if _chunk_density(chunk, profile) >= profile.weather_threshold:
					chunks.append(chunk)
	chunks.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var distance_a := Vector3(a - center).length_squared()
		var distance_b := Vector3(b - center).length_squared()
		if not is_equal_approx(distance_a, distance_b):
			return distance_a > distance_b
		return _chunk_hash(a, profile.world_seed, 91) < _chunk_hash(
			b,
			profile.world_seed,
			91
		)
	)
	return chunks


static func candidate_members(
	center: Vector3i,
	profile: CloudTuningProfile,
	wind_direction: Vector3
) -> Array[Vector4i]:
	var members: Array[Vector4i] = []
	if profile == null:
		return members
	for chunk in candidate_chunks(center, profile):
		var member_count := _formation_member_count(chunk, profile)
		for member_index in range(member_count):
			members.append(Vector4i(
				chunk.x,
				chunk.y,
				chunk.z,
				member_index
			))
	members.sort_custom(func(a: Vector4i, b: Vector4i) -> bool:
		var chunk_a := Vector3i(a.x, a.y, a.z)
		var chunk_b := Vector3i(b.x, b.y, b.z)
		var distance_a := Vector3(chunk_a - center).length_squared()
		var distance_b := Vector3(chunk_b - center).length_squared()
		if not is_equal_approx(distance_a, distance_b):
			return distance_a > distance_b
		return _member_hash(chunk_a, a.w, profile.world_seed, 92) < (
			_member_hash(chunk_b, b.w, profile.world_seed, 92)
		)
	)
	return members


static func member_data(
	key: Vector4i,
	profile: CloudTuningProfile,
	wind_direction: Vector3
) -> Dictionary:
	if profile == null:
		return {}
	var chunk := Vector3i(key.x, key.y, key.z)
	var member_index := key.w
	var member_count := _formation_member_count(chunk, profile)
	if member_index < 0 or member_index >= member_count:
		return {}

	var density := _chunk_density(chunk, profile)
	var density_weight: float = inverse_lerp(
		profile.weather_threshold,
		1.0,
		density
	)
	var chunk_center := (
		Vector3(chunk) + Vector3.ONE * 0.5
	) * profile.chunk_size
	var center_jitter := Vector3(
		lerpf(-0.22, 0.22, _chunk_unit_hash(chunk, profile.world_seed, 20)),
		lerpf(-0.16, 0.16, _chunk_unit_hash(chunk, profile.world_seed, 21)),
		lerpf(-0.22, 0.22, _chunk_unit_hash(chunk, profile.world_seed, 22))
	) * profile.chunk_size

	var major_axis := Vector3(wind_direction.x, 0.0, wind_direction.z)
	if major_axis.length_squared() <= 0.000001:
		major_axis = Vector3.RIGHT
	major_axis = major_axis.normalized()
	var minor_axis := Vector3(-major_axis.z, 0.0, major_axis.x)
	var angle := TAU * _member_unit_hash(
		chunk,
		member_index,
		profile.world_seed,
		1
	)
	var radial_factor := sqrt(_member_unit_hash(
		chunk,
		member_index,
		profile.world_seed,
		2
	))
	var asymmetric_bias := lerpf(
		-0.35,
		0.65,
		_chunk_unit_hash(chunk, profile.world_seed, 23)
	)
	var major_distance := (
		cos(angle) + asymmetric_bias
	) * radial_factor * profile.formation_spread
	var minor_distance := (
		sin(angle)
		* radial_factor
		* profile.formation_spread
		* lerpf(
			0.35,
			0.72,
			_chunk_unit_hash(chunk, profile.world_seed, 24)
		)
	)
	var height_offset := lerpf(
		-profile.formation_thickness,
		profile.formation_thickness,
		_member_unit_hash(chunk, member_index, profile.world_seed, 3)
	)
	var local_offset := (
		major_axis * major_distance
		+ minor_axis * minor_distance
		+ Vector3.UP * height_offset
	)

	var scale_weight := _member_unit_hash(
		chunk,
		member_index,
		profile.world_seed,
		4
	)
	var member_scale := Vector3(
		lerpf(profile.scale_min.x, profile.scale_max.x, scale_weight),
		lerpf(
			profile.scale_min.y,
			profile.scale_max.y,
			_member_unit_hash(chunk, member_index, profile.world_seed, 5)
		),
		lerpf(
			profile.scale_min.z,
			profile.scale_max.z,
			_member_unit_hash(chunk, member_index, profile.world_seed, 6)
		)
	)
	member_scale *= lerpf(0.85, 1.55, density_weight)
	var overlap_scale := lerpf(
		0.78,
		1.3,
		_member_unit_hash(chunk, member_index, profile.world_seed, 7)
	)
	member_scale *= overlap_scale
	var yaw := atan2(major_axis.x, major_axis.z) + lerpf(
		-0.55,
		0.55,
		_member_unit_hash(chunk, member_index, profile.world_seed, 8)
	)
	var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(
		member_scale
	)
	var shape_range := maxf(profile.shape_variation, 0.0)
	var shape_offset := Vector3(
		lerpf(
			-shape_range,
			shape_range,
			_member_unit_hash(chunk, member_index, profile.world_seed, 9)
		),
		lerpf(
			-shape_range,
			shape_range,
			_member_unit_hash(chunk, member_index, profile.world_seed, 10)
		),
		lerpf(
			-shape_range,
			shape_range,
			_member_unit_hash(chunk, member_index, profile.world_seed, 11)
		)
	)
	var formation_phase := fposmod(
		_chunk_unit_hash(chunk, profile.world_seed, 30)
		+ float(member_index) * 0.0125,
		1.0
	)
	var formation_lifetime := lerpf(
		DEFAULT_FORMATION_LIFETIME_MIN,
		DEFAULT_FORMATION_LIFETIME_MAX,
		_chunk_unit_hash(chunk, profile.world_seed, 31)
	)
	return {
		"transform": Transform3D(
			basis,
			chunk_center + center_jitter + local_offset
		),
		"shape_offset": shape_offset,
		"cloud_radius": 0.5 * maxf(
			member_scale.x,
			maxf(member_scale.y, member_scale.z)
		),
		"priority": density + _member_unit_hash(
			chunk,
			member_index,
			profile.world_seed,
			12
		) * 0.1,
		"formation_phase": formation_phase,
		"formation_lifetime": formation_lifetime,
		"formation_fade_duration": DEFAULT_FORMATION_FADE_DURATION,
	}


static func smooth_value_noise(
	position: Vector3,
	world_seed: int
) -> float:
	var lattice := Vector3i(
		floori(position.x),
		floori(position.y),
		floori(position.z)
	)
	var fraction := position - Vector3(lattice)
	var blend := Vector3(
		_smooth_curve(fraction.x),
		_smooth_curve(fraction.y),
		_smooth_curve(fraction.z)
	)
	var value_000 := _lattice_value(lattice, world_seed)
	var value_100 := _lattice_value(lattice + Vector3i.RIGHT, world_seed)
	var value_010 := _lattice_value(lattice + Vector3i.UP, world_seed)
	var value_110 := _lattice_value(
		lattice + Vector3i.RIGHT + Vector3i.UP,
		world_seed
	)
	var value_001 := _lattice_value(lattice + Vector3i.BACK, world_seed)
	var value_101 := _lattice_value(
		lattice + Vector3i.RIGHT + Vector3i.BACK,
		world_seed
	)
	var value_011 := _lattice_value(
		lattice + Vector3i.UP + Vector3i.BACK,
		world_seed
	)
	var value_111 := _lattice_value(
		lattice + Vector3i.ONE,
		world_seed
	)
	var lower_x := lerpf(value_000, value_100, blend.x)
	var upper_x := lerpf(value_010, value_110, blend.x)
	var lower_z := lerpf(value_001, value_101, blend.x)
	var upper_z := lerpf(value_011, value_111, blend.x)
	return lerpf(
		lerpf(lower_x, upper_x, blend.y),
		lerpf(lower_z, upper_z, blend.y),
		blend.z
	)


static func _chunk_density(
	chunk: Vector3i,
	profile: CloudTuningProfile
) -> float:
	var sample_position := (
		(Vector3(chunk) + Vector3.ONE * 0.5)
		* profile.chunk_size
		/ profile.weather_scale
	)
	sample_position.y *= 0.55
	var broad_noise := smooth_value_noise(
		sample_position,
		profile.world_seed
	)
	var detail_noise := smooth_value_noise(
		sample_position * 2.07 + Vector3(13.7, 4.3, -8.1),
		profile.world_seed + 1013
	)
	return broad_noise * 0.78 + detail_noise * 0.22


static func _formation_member_count(
	chunk: Vector3i,
	profile: CloudTuningProfile
) -> int:
	var density_weight: float = clampf(inverse_lerp(
		profile.weather_threshold,
		1.0,
		_chunk_density(chunk, profile)
	), 0.0, 1.0)
	return clampi(
		roundi(lerpf(
			float(profile.formation_min_members),
			float(profile.formation_max_members),
			density_weight
		)),
		profile.formation_min_members,
		profile.formation_max_members
	)


static func _inside_chunk_ellipsoid(
	offset: Vector3i,
	horizontal_radius: int,
	vertical_radius: int
) -> bool:
	var normalized_x := float(offset.x) / float(maxi(horizontal_radius, 1))
	var normalized_z := float(offset.z) / float(maxi(horizontal_radius, 1))
	var normalized_y := (
		0.0
		if vertical_radius <= 0
		else float(offset.y) / float(vertical_radius)
	)
	return (
		normalized_x * normalized_x
		+ normalized_y * normalized_y
		+ normalized_z * normalized_z
	) <= 1.0


static func _smooth_curve(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


static func _lattice_value(point: Vector3i, world_seed: int) -> float:
	return float(posmod(
		_chunk_hash(point, world_seed, 71),
		1000003
	)) / 1000003.0


static func _chunk_unit_hash(
	chunk: Vector3i,
	world_seed: int,
	salt: int
) -> float:
	return float(posmod(
		_chunk_hash(chunk, world_seed, salt),
		1000003
	)) / 1000003.0


static func _member_unit_hash(
	chunk: Vector3i,
	member_index: int,
	world_seed: int,
	salt: int
) -> float:
	return float(posmod(
		_member_hash(chunk, member_index, world_seed, salt),
		1000003
	)) / 1000003.0


static func _member_hash(
	chunk: Vector3i,
	member_index: int,
	world_seed: int,
	salt: int
) -> int:
	return hash("%d:%d:%d:%d:%d:%d" % [
		chunk.x,
		chunk.y,
		chunk.z,
		member_index,
		world_seed,
		salt,
	])


static func _chunk_hash(
	chunk: Vector3i,
	world_seed: int,
	salt: int
) -> int:
	return hash("%d:%d:%d:%d:%d" % [
		chunk.x,
		chunk.y,
		chunk.z,
		world_seed,
		salt,
	])
