extends Node

signal quality_changed(settings: Dictionary)

enum Quality { LOW, MEDIUM, HIGH }

var current_quality: Quality = Quality.HIGH

# Имя группы для объектов, которые должны исчезать
const GROUP_DETAIL_OBJECTS = "level_detail_objects"

var presets = {
	Quality.LOW: {
		# --- ГРАФИКА (GPU) ---
		"scale_3d": 0.75,
		"msaa": Viewport.MSAA_DISABLED,
		"fxaa": false,
		"shadow_size": 1024,
		"shadow_filter": RenderingServer.SHADOW_QUALITY_HARD,
		"vsync": DisplayServer.VSYNC_DISABLED,
		"ssao": false, "ssil": false, "sdfgi": false, "ssr": false, "glow": false, "volumetric_fog": false,
		"lod_threshold": 5.0,
		"grass_distance": 20.0, "grass_level": 2.0,
		"vis_range": 30.0, "vis_margin": 5.0,
		
		# --- ИСПРАВЛЕНИЕ: Добавляем явное приведение типов к массивам ---
		"ai_anim_lod_dists_sq": [5.0*5.0, 10.0*10.0, 15.0*15.0] as Array[float],
		"ai_anim_lod_skips": [3, 8, 20] as Array[int],
		"ai_phys_lod_dist_sq": 15.0 * 15.0,
		"ai_phys_lod_skip": 25,
	},
	Quality.MEDIUM: {
		# --- ГРАФИКА (GPU) ---
		"scale_3d": 1.0,
		"msaa": Viewport.MSAA_2X,
		"fxaa": true,
		"shadow_size": 2048,
		"shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"vsync": DisplayServer.VSYNC_DISABLED,
		"ssao": true, "ssil": false, "sdfgi": false, "ssr": false, "glow": true, "volumetric_fog": false,
		"lod_threshold": 1.0,
		"grass_distance": 60.0, "grass_level": 10.0,
		"vis_range": 80.0, "vis_margin": 20.0,

		# --- ИСПРАВЛЕНИЕ: Добавляем явное приведение типов к массивам ---
		"ai_anim_lod_dists_sq": [7.0*7.0, 12.0*12.0, 18.0*18.0] as Array[float],
		"ai_anim_lod_skips": [2, 6, 18] as Array[int],
		"ai_phys_lod_dist_sq": 22.0 * 22.0,
		"ai_phys_lod_skip": 15,
	},
	Quality.HIGH: {
		# --- ГРАФИКА (GPU) ---
		"scale_3d": 1.0,
		"msaa": Viewport.MSAA_4X,
		"fxaa": true,
		"shadow_size": 4096,
		"shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"vsync": DisplayServer.VSYNC_DISABLED,
		"ssao": true, "ssil": true, "sdfgi": true, "ssr": true, "glow": true, "volumetric_fog": true,
		"lod_threshold": 0.1,
		"grass_distance": 120.0, "grass_level": 20.0,
		"vis_range": 500.0, "vis_margin": 50.0,

		# --- ИСПРАВЛЕНИЕ: Добавляем явное приведение типов к массивам ---
		"ai_anim_lod_dists_sq": [8.0*8.0, 15.0*15.0, 20.0*20.0] as Array[float],
		"ai_anim_lod_skips": [2, 5, 15] as Array[int],
		"ai_phys_lod_dist_sq": 30.0 * 30.0,
		"ai_phys_lod_skip": 10,
	}
}

func _ready() -> void:
	# Ждем кадр, чтобы все объекты успели загрузиться в сцену
	await get_tree().process_frame
	apply_preset(Quality.HIGH)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			apply_preset(Quality.LOW)
			print("Graphics: LOW")
		elif event.keycode == KEY_F2:
			apply_preset(Quality.MEDIUM)
			print("Graphics: MEDIUM")
		elif event.keycode == KEY_F3:
			apply_preset(Quality.HIGH)
			print("Graphics: HIGH")

func apply_preset(quality: Quality) -> void:
	current_quality = quality
	var p = presets[quality]
	DisplayServer.window_set_vsync_mode(p["vsync"])
	var viewport = get_viewport()
	
	# 1. Viewport
	viewport.scaling_3d_scale = p["scale_3d"]
	viewport.msaa_3d = p["msaa"]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.mesh_lod_threshold = p["lod_threshold"]
	
	# 2. RenderingServer
	RenderingServer.directional_shadow_atlas_set_size(p["shadow_size"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p["shadow_filter"])
	
	# 3. Environment
	_apply_environment_settings(p)
	
	# 4. Обновление объектов (Culling)
	_update_detail_objects(p)
	
	# 5. Сигнал (трава, AI и т.д.)
	quality_changed.emit(p)

func _apply_environment_settings(p: Dictionary) -> void:
	var world_env = get_tree().get_first_node_in_group("world_env")
	if not world_env or not world_env.environment:
		return
		
	var env = world_env.environment
	env.ssao_enabled = p["ssao"]
	env.ssil_enabled = p["ssil"]
	env.sdfgi_enabled = p["sdfgi"]
	env.ssr_enabled = p["ssr"]
	env.glow_enabled = p["glow"]
	env.volumetric_fog_enabled = p["volumetric_fog"]

# --- НОВАЯ ФУНКЦИЯ ДЛЯ ОБЪЕКТОВ ---
func _update_detail_objects(p: Dictionary) -> void:
	# Берем все объекты из группы
	var nodes = get_tree().get_nodes_in_group(GROUP_DETAIL_OBJECTS)
	
	for node in nodes:
		# Запускаем поиск мешей внутри каждого объекта
		_apply_visibility_recursive(node, p["vis_range"], p["vis_margin"])

# Рекурсивная функция: ищет MeshInstance3D внутри переданного узла и его детей
func _apply_visibility_recursive(node: Node, range_end: float, margin: float) -> void:
	# 1. Если этот узел сам является Мешем (MeshInstance3D, MultiMeshInstance3D и т.д.)
	if node is GeometryInstance3D:
		node.visibility_range_end = range_end
		node.visibility_range_end_margin = margin
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	
	# 2. Проходимся по всем детям этого узла (чтобы найти меши внутри сцены Ящика, Дерева и т.д.)
	for child in node.get_children():
		_apply_visibility_recursive(child, range_end, margin)
