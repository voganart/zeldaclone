extends Node

@export var mesh_path: NodePath
@export var flash_shader: ShaderMaterial
@export var flash_color: Color = Color(1, 0.1, 0.1)
@export var flash_time := 0.12
@export var flash_strength := 1.0

var shader_mat: ShaderMaterial


func _ready():
	var mesh: MeshInstance3D = get_node(mesh_path)

	# Если у MeshInstance3D уже стоит Override — заменяем его
	var override := mesh.material_override
	if override is ShaderMaterial:
		shader_mat = override.duplicate()
		mesh.material_override = shader_mat
		return

	# Если override есть, но не ShaderMaterial — создаём новый
	if override != null:
		shader_mat = flash_shader.duplicate()
		mesh.material_override = shader_mat
		return

	# Нет override → ищем surface materials
	var surf_count := mesh.mesh.get_surface_count()
	for i in range(surf_count):
		var mat := mesh.get_active_material(i)
		if mat is ShaderMaterial:
			shader_mat = mat.duplicate()
			mesh.set_surface_override_material(i, shader_mat)
			return

	# Нет ShaderMaterial вообще → ставим flash_shader
	shader_mat = flash_shader.duplicate()
	mesh.set_surface_override_material(0, shader_mat)


func flash():
	if shader_mat == null:
		return

	shader_mat.set_shader_parameter("use_hit_flash", true)
	shader_mat.set_shader_parameter("hit_flash_color", flash_color)
	shader_mat.set_shader_parameter("hit_flash_strength", flash_strength)

	_fade_out()


func _fade_out() -> void:
	var strength := flash_strength
	while strength > 0.0:
		strength -= get_process_delta_time() / flash_time
		shader_mat.set_shader_parameter("hit_flash_strength", max(strength, 0.0))
		await get_tree().process_frame

	shader_mat.set_shader_parameter("use_hit_flash", false)
