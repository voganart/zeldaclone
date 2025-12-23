@tool
extends EditorScript

const ROOT_DIR = "res://assets/textures/environment/"
const SUFFIX_ALBEDO_BUMP = "_AlbedoBump.png"
const SUFFIX_NORMAL_ROUGH = "_NormalRoughness.png"
const SUFFIX_METALLIC_AO = "_MetallicAO.png"
const MATERIAL_SUFFIX = ".tres"

const USE_TRIPLANAR = false
const UV_SCALE = Vector3(0.5, 0.5, 0.5)
const NORMAL_STRENGTH = 1.0
const AO_LIGHT_AFFECT = 0.5

func _run():
	print("--- STARTING GODOT MATERIAL GENERATOR ---")
	
	EditorInterface.get_resource_filesystem().scan()
	
	_process_directory_recursive(ROOT_DIR)
	
	print("--- MATERIAL GENERATION FINISHED ---")
	EditorInterface.get_resource_filesystem().scan()

func _process_directory_recursive(path: String):
	var dir = DirAccess.open(path)
	if not dir: return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	var files_in_folder: Dictionary = {}
	var subdirectories: Array[String] = []
	
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
			
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			# !! ИСПРАВЛЕНИЕ: УБРАНА ПРОВЕРКА `_1k` !!
			subdirectories.append(full_path)
		elif not file_name.ends_with(".import"):
			files_in_folder[file_name.to_lower()] = file_name
		
		file_name = dir.get_next()
	
	if files_in_folder.size() > 0:
		_process_folder_materials(path, files_in_folder)
	
	for subdir in subdirectories:
		_process_directory_recursive(subdir + "/")

func _process_folder_materials(dir_path: String, files: Dictionary):
	var folder_name = dir_path.get_base_dir().get_file()
	
	var alb_path = dir_path.path_join(folder_name + SUFFIX_ALBEDO_BUMP)
	var nrm_path = dir_path.path_join(folder_name + SUFFIX_NORMAL_ROUGH)
	var mao_path = dir_path.path_join(folder_name + SUFFIX_METALLIC_AO)
	
	if not FileAccess.file_exists(alb_path) and not FileAccess.file_exists(nrm_path):
		return
		
	print("Updating material in: ", folder_name)
	_create_material(dir_path, "Mat_" + folder_name, alb_path, nrm_path, mao_path)

func _create_material(dir: String, name: String, p_alb: String, p_nrm: String, p_mao: String):
	var mat_path = dir.path_join(name + MATERIAL_SUFFIX)
	var mat: StandardMaterial3D
	
	if ResourceLoader.exists(mat_path):
		mat = ResourceLoader.load(mat_path)
	else:
		mat = StandardMaterial3D.new()
	
	var tex_alb = ResourceLoader.load(p_alb, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) if FileAccess.file_exists(p_alb) else null
	var tex_nrm = ResourceLoader.load(p_nrm, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) if FileAccess.file_exists(p_nrm) else null
	var tex_mao = ResourceLoader.load(p_mao, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) if FileAccess.file_exists(p_mao) else null
	
	if tex_alb:
		mat.albedo_texture = tex_alb
		mat.heightmap_enabled = true
		mat.heightmap_scale = 0.05
		mat.heightmap_texture = tex_alb
	
	if tex_nrm:
		mat.normal_enabled = true
		mat.normal_texture = tex_nrm
		mat.normal_scale = NORMAL_STRENGTH
		mat.roughness_texture = tex_nrm
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	
	if tex_mao:
		mat.metallic = 1.0
		mat.metallic_texture = tex_mao
		mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.ao_enabled = true
		mat.ao_texture = tex_mao
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		mat.ao_light_affect = AO_LIGHT_AFFECT
	
	mat.uv1_triplanar = USE_TRIPLANAR
	mat.uv1_scale = UV_SCALE
		
	var err = ResourceSaver.save(mat, mat_path)
	if err == OK:
		print("  Saved/Updated Material: ", mat_path.get_file())
	else:
		printerr("  Failed to save material: ", mat_path)
