extends Node

var _failures: Array[String] = []


func _ready() -> void:
	var controller_script = load("res://levels/components/CloudManager/cloud_lod_controller.gd")
	if controller_script == null:
		_fail("CloudLodController script is missing")
		_finish()
		return

	var controller: Node3D = controller_script.new()
	var volume := _make_mesh("Volume")
	var impostor := _make_mesh("Impostor")
	controller.add_child(volume)
	controller.add_child(impostor)
	add_child(controller)
	controller.volume_mesh_path = NodePath("Volume")
	controller.impostor_mesh_path = NodePath("Impostor")
	controller.quality_policy = 2
	controller.cheap_volume_start = 80.0
	controller.transition_start = 150.0
	controller.transition_end = 210.0

	_expect_state(controller, volume, impostor, 40.0, true, false, 0.0, 0.0)
	_expect_state(controller, volume, impostor, 120.0, true, false, 0.0, 1.0)
	_expect_state(controller, volume, impostor, 180.0, true, true, 0.5, 1.0)
	_expect_state(controller, volume, impostor, 240.0, false, true, 1.0, 1.0)

	controller.quality_policy = 1
	_expect_state(controller, volume, impostor, 20.0, true, false, 0.0, 0.65)
	controller.quality_policy = 0
	_expect_state(controller, volume, impostor, 20.0, true, false, 0.0, 1.0)
	_finish()


func _make_mesh(node_name: String) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = BoxMesh.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
instance uniform float lod_fade = 0.0;
instance uniform bool lod_is_impostor = false;
instance uniform float volume_lod_factor = 0.0;
void fragment() { ALBEDO = vec3(lod_fade); }
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh_instance.material_override = material
	return mesh_instance


func _expect_state(
	controller: Node3D,
	volume: MeshInstance3D,
	impostor: MeshInstance3D,
	distance: float,
	expected_volume: bool,
	expected_impostor: bool,
	expected_fade: float,
	expected_volume_lod: float
) -> void:
	controller.apply_distance(distance)
	if volume.visible != expected_volume:
		_fail("Distance %.1f: wrong volume visibility" % distance)
	if impostor.visible != expected_impostor:
		_fail("Distance %.1f: wrong impostor visibility" % distance)
	if not is_equal_approx(float(volume.get_instance_shader_parameter("lod_fade")), expected_fade):
		_fail("Distance %.1f: wrong volume fade" % distance)
	if not is_equal_approx(float(impostor.get_instance_shader_parameter("lod_fade")), expected_fade):
		_fail("Distance %.1f: wrong impostor fade" % distance)
	if bool(volume.get_instance_shader_parameter("lod_is_impostor")):
		_fail("Volume must use the volume half of complementary dither")
	if not bool(impostor.get_instance_shader_parameter("lod_is_impostor")):
		_fail("Impostor must use the impostor half of complementary dither")
	if not is_equal_approx(
		float(volume.get_instance_shader_parameter("volume_lod_factor")),
		expected_volume_lod
	):
		_fail("Distance %.1f: wrong volume raymarch LOD" % distance)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Cloud LOD controller tests: PASS")
		get_tree().quit(0)
	else:
		print("Cloud LOD controller tests: FAIL (%d)" % _failures.size())
		get_tree().quit(1)
