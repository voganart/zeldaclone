class_name CloudExclusionMath
extends RefCounted


static func intersects_cloud(
	volume: CloudExclusionVolume,
	cloud_center: Vector3,
	cloud_radius: float
) -> bool:
	if volume == null:
		return false
	var shape := volume.get_exclusion_shape()
	if shape == null:
		return false
	var shape_transform := volume.get_exclusion_transform()
	var clearance := maxf(volume.get_clearance(), 0.0)
	var world_scale := shape_transform.basis.get_scale().abs()

	if shape is BoxShape3D:
		var box := shape as BoxShape3D
		var local_center := shape_transform.affine_inverse() * cloud_center
		var minimum_scale := maxf(
			minf(world_scale.x, minf(world_scale.y, world_scale.z)),
			0.001
		)
		var local_padding := (maxf(cloud_radius, 0.0) + clearance) / minimum_scale
		var half_size := box.size * 0.5
		var closest := Vector3(
			clampf(local_center.x, -half_size.x, half_size.x),
			clampf(local_center.y, -half_size.y, half_size.y),
			clampf(local_center.z, -half_size.z, half_size.z)
		)
		return local_center.distance_squared_to(closest) <= (
			local_padding * local_padding
		)

	if shape is SphereShape3D:
		var sphere := shape as SphereShape3D
		var maximum_scale := maxf(
			world_scale.x,
			maxf(world_scale.y, world_scale.z)
		)
		var exclusion_radius := (
			sphere.radius * maximum_scale
			+ clearance
			+ maxf(cloud_radius, 0.0)
		)
		return cloud_center.distance_squared_to(shape_transform.origin) <= (
			exclusion_radius * exclusion_radius
		)

	return false
