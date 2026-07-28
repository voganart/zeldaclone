@tool
extends Node

const MathUtil = preload("res://addons/cloud_impostor_baker/cloud_impostor_math.gd")
const FRAME_COUNT := 8
const ATLAS_RESOLUTION := 2048
const TILE_SIZE := ATLAS_RESOLUTION / FRAME_COUNT
const OUTPUT_DIRECTORY := "res://assets/shaders/Cloud_impostor/generated"
const OUTPUT_PATH := OUTPUT_DIRECTORY + "/cloud_01_albedo.png"


func bake_cloud(cloud: Node3D) -> Dictionary:
	var source_meshes := _collect_volume_meshes(cloud)
	if source_meshes.is_empty():
		return {"ok": false, "error": "No VolumetricMesh* nodes with mesh resources were found."}

	var viewport := _create_viewport()
	add_child(viewport)
	var world_root := Node3D.new()
	viewport.add_child(world_root)

	var baked_cluster := Node3D.new()
	baked_cluster.name = "BakedCloudCluster"
	world_root.add_child(baked_cluster)
	for source_mesh in source_meshes:
		var baked_mesh := _create_baked_mesh(source_mesh)
		if baked_mesh == null:
			viewport.queue_free()
			return {
				"ok": false,
				"error": "%s has no active ShaderMaterial." % source_mesh.name,
			}
		baked_mesh.transform = _relative_transform(cloud, source_mesh)
		baked_cluster.add_child(baked_mesh)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	world_root.add_child(camera)

	var cluster_aabb := _combined_aabb(source_meshes, cloud)
	baked_cluster.position = -cluster_aabb.get_center()
	var view_size := maxf(
		cluster_aabb.size.x,
		maxf(cluster_aabb.size.y, cluster_aabb.size.z)
	) * 1.15
	var camera_distance := maxf(view_size * 2.5, 2.0)
	camera.size = view_size
	camera.near = 0.01
	camera.far = camera_distance * 4.0

	var atlas := Image.create(
		ATLAS_RESOLUTION,
		ATLAS_RESOLUTION,
		false,
		Image.FORMAT_RGBA8
	)
	atlas.fill(Color(0.0, 0.0, 0.0, 0.0))

	await get_tree().process_frame
	for y in range(FRAME_COUNT):
		for x in range(FRAME_COUNT):
			var frame := Vector2i(x, y)
			var direction := MathUtil.grid_to_lower_hemisphere(frame, FRAME_COUNT)
			camera.position = direction * camera_distance
			camera.look_at(Vector3.ZERO, MathUtil.camera_up_for(direction))

			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			var frame_image := viewport.get_texture().get_image()
			if frame_image == null or frame_image.is_empty():
				viewport.queue_free()
				return {"ok": false, "error": "Viewport returned an empty frame at %s." % frame}
			frame_image.convert(Image.FORMAT_RGBA8)
			atlas.blit_rect(
				frame_image,
				Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)),
				MathUtil.atlas_rect(frame, TILE_SIZE).position
			)

	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var output_directory_absolute := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory_absolute)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		viewport.queue_free()
		return {"ok": false, "error": "Cannot create output directory (error %d)." % directory_error}

	var output_absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	var save_error := atlas.save_png(output_absolute)
	viewport.queue_free()
	if save_error != OK:
		return {"ok": false, "error": "Cannot save PNG (error %d)." % save_error}
	return {"ok": true, "path": OUTPUT_PATH}


func _create_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "CloudImpostorBakeViewport"
	viewport.size = Vector2i(TILE_SIZE, TILE_SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	return viewport


func _create_baked_mesh(source: MeshInstance3D) -> MeshInstance3D:
	var active_material := source.get_active_material(0)
	if not active_material is ShaderMaterial:
		return null

	var material := active_material.duplicate(true) as ShaderMaterial

	var baked := MeshInstance3D.new()
	baked.name = "BakedVolumetricMesh"
	baked.mesh = source.mesh
	baked.material_override = material
	baked.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	baked.set_instance_shader_parameter(&"shape_override_enabled", 1.0)
	baked.set_instance_shader_parameter(&"shape_override_scale", Vector3(70.0, 40.0, 110.0))
	baked.set_instance_shader_parameter(&"shape_override_offset", Vector3(0.17, 0.33, 0.61))
	baked.set_instance_shader_parameter(&"lod_fade", 0.0)
	baked.set_instance_shader_parameter(&"lod_is_impostor", false)
	return baked


func _collect_volume_meshes(cloud: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if cloud is MeshInstance3D and cloud.name.begins_with("VolumetricMesh"):
		var root_mesh := cloud as MeshInstance3D
		if root_mesh.mesh != null:
			result.append(root_mesh)
	for node in cloud.find_children("VolumetricMesh*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			result.append(mesh_instance)
	return result


func _combined_aabb(source_meshes: Array[MeshInstance3D], cloud: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	for source_mesh in source_meshes:
		var relative_transform := _relative_transform(cloud, source_mesh)
		var transformed := _transformed_aabb(source_mesh.mesh.get_aabb(), relative_transform)
		if has_bounds:
			result = result.merge(transformed)
		else:
			result = transformed
			has_bounds = true
	return result


func _relative_transform(cloud: Node3D, source: Node3D) -> Transform3D:
	if cloud == source:
		return Transform3D.IDENTITY
	return cloud.global_transform.affine_inverse() * source.global_transform


func _transformed_aabb(source_aabb: AABB, transform: Transform3D) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for x in range(2):
		for y in range(2):
			for z in range(2):
				var corner := source_aabb.position + Vector3(
					source_aabb.size.x * float(x),
					source_aabb.size.y * float(y),
					source_aabb.size.z * float(z)
				)
				var transformed := transform * corner
				minimum = Vector3(
					minf(minimum.x, transformed.x),
					minf(minimum.y, transformed.y),
					minf(minimum.z, transformed.z)
				)
				maximum = Vector3(
					maxf(maximum.x, transformed.x),
					maxf(maximum.y, transformed.y),
					maxf(maximum.z, transformed.z)
				)
	return AABB(minimum, maximum - minimum)
