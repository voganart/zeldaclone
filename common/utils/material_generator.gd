@tool
extends EditorScript

const TEXTURES_PATH = "res://assets/textures/"

# --- НАСТРОЙКИ ---
const USE_TRIPLANAR = false
const UV_SCALE = Vector3(0.5, 0.5, 0.5)
const NORMAL_STRENGTH = 2.0  # Сила нормали
const AO_LIGHT_AFFECT = 0.5  # Влияние AO на свет

func _run():
	EditorInterface.get_resource_filesystem().scan()
	print("--- START UPDATING MATERIALS ---")
	_scan_folder(TEXTURES_PATH)
	print("--- DONE ---")

func _scan_folder(path: String):
	var dir = DirAccess.open(path)
	if not dir: return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	var albedo_tex = null
	var normal_tex = null
	var orm_tex = null
	var subdirs = []

	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				subdirs.append(path + file_name + "/")
		else:
			var lower = file_name.to_lower()
			if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".tga"):
				if "albedo" in lower or "color" in lower or "diffuse" in lower:
					albedo_tex = file_name
				elif "normal" in lower:
					normal_tex = file_name
				elif "orm" in lower:
					orm_tex = file_name
		file_name = dir.get_next()
	
	if albedo_tex:
		_create_material(path, albedo_tex, normal_tex, orm_tex)
		
	for subdir in subdirs:
		_scan_folder(subdir)

func _create_material(path: String, albedo_f: String, normal_f: String, orm_f: String):
	var mat_name = "Mat_" + path.get_base_dir().get_file() + ".tres"
	var save_path = path + mat_name
	
	var mat = StandardMaterial3D.new()
	
	# ALBEDO
	var albedo_res = load(path + albedo_f)
	if albedo_res:
		mat.albedo_texture = albedo_res
	else:
		return 
	
	# NORMAL
	if normal_f:
		var norm_res = load(path + normal_f)
		if norm_res:
			mat.normal_enabled = true
			mat.normal_texture = norm_res
			mat.normal_scale = NORMAL_STRENGTH # <--- Установка силы нормали (2.0)
	
	# ORM
	if orm_f:
		var orm_res = load(path + orm_f)
		if orm_res:
			# AO
			mat.ao_enabled = true
			mat.ao_texture = orm_res
			mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			mat.ao_light_affect = AO_LIGHT_AFFECT # <--- Установка влияния AO (0.5)
			
			# Roughness
			mat.roughness_texture = orm_res
			mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			
			# Metallic
			mat.metallic = 1.0
			mat.metallic_texture = orm_res
			mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	
	# UV SETTINGS
	if USE_TRIPLANAR:
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
	
	mat.uv1_scale = UV_SCALE
		
	var err = ResourceSaver.save(mat, save_path)
	if err == OK:
		print("UPDATED: " + mat_name)
