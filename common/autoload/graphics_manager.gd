extends Node

signal quality_changed(settings: Dictionary)

enum Quality { LOW, MEDIUM, HIGH }

var current_quality: Quality = Quality.HIGH

# Имя группы для объектов, которые должны исчезать
const GROUP_DETAIL_OBJECTS = "level_detail_objects"

var presets = {
	Quality.LOW: {
		# --- ОБЩИЕ ---
		"scale_3d": 0.75,
		"msaa": Viewport.MSAA_DISABLED,
		"fxaa": false,
		"vsync": DisplayServer.VSYNC_DISABLED,
		
		# --- ТЕНИ ---
		"shadow_size": 2048,
		"shadow_filter": RenderingServer.SHADOW_QUALITY_HARD,
		"shadow_16_bits": false,
		"pos_shadow_size": 2048,
		
		# --- НАСТРОЙКИ СОЛНЦА (DirectionalLight3D) ---
		# Orthogonal - самый быстрый режим (один проход), но тени могут быть мыльными
		"sun_shadow_mode": DirectionalLight3D.SHADOW_ORTHOGONAL,
		"sun_max_dist": 50.0, 
		
		# --- ЭФФЕКТЫ ---
		"ssao": false, "ssil": false, "sdfgi": false, "ssr": false, "glow": false, "volumetric_fog": false,
		
		# --- LOD ---
		"lod_threshold": 5.0,
		"grass_distance": 20.0, "grass_level": 2.0,
		"vis_range": 30.0, "vis_margin": 5.0,
		
		# --- AI LOD ---
		"ai_anim_lod_dists_sq": [5.0*5.0, 10.0*10.0, 15.0*15.0] as Array[float],
		"ai_anim_lod_skips": [3, 8, 20] as Array[int],
		"ai_phys_lod_dist_sq": 15.0 * 15.0,
		"ai_phys_lod_skip": 25,
	},
	Quality.MEDIUM: {
		# --- ОБЩИЕ ---
		"scale_3d": 1.0,
		"msaa": Viewport.MSAA_2X,
		"fxaa": true,
		"vsync": DisplayServer.VSYNC_DISABLED,
		
		# --- ТЕНИ ---
		"shadow_size": 4096,
		"shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"shadow_16_bits": false,
		"pos_shadow_size": 4096,
		
		# --- НАСТРОЙКИ СОЛНЦА ---
		# 2 сплита - золотая середина производительности
		"sun_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"sun_max_dist": 100.0, 
		
		# --- ЭФФЕКТЫ ---
		"ssao": true, "ssil": false, "sdfgi": false, "ssr": false, "glow": true, "volumetric_fog": false,
		
		# --- LOD ---
		"lod_threshold": 1.0,
		"grass_distance": 60.0, "grass_level": 10.0,
		"vis_range": 80.0, "vis_margin": 20.0,

		# --- AI LOD ---
		"ai_anim_lod_dists_sq": [7.0*7.0, 12.0*12.0, 18.0*18.0] as Array[float],
		"ai_anim_lod_skips": [2, 6, 18] as Array[int],
		"ai_phys_lod_dist_sq": 22.0 * 22.0,
		"ai_phys_lod_skip": 15,
	},
	Quality.HIGH: {
		# --- ОБЩИЕ ---
		"scale_3d": 1.0,
		"msaa": Viewport.MSAA_4X,
		"fxaa": true,
		"vsync": DisplayServer.VSYNC_DISABLED,
		
		# --- ТЕНИ (УЛУЧШЕННЫЕ) ---
		"shadow_size": 8192,
		"shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"shadow_16_bits": true,
		"pos_shadow_size": 8192,
		
		# --- НАСТРОЙКИ СОЛНЦА ---
		# 4 сплита - максимальная четкость на всех дистанциях
		"sun_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
		"sun_max_dist": 200.0,
		
		# --- ЭФФЕКТЫ ---
		"ssao": true, "ssil": true, "sdfgi": true, "ssr": true, "glow": true, "volumetric_fog": true,
		
		# --- LOD ---
		"lod_threshold": 0.01,
		"grass_distance": 120.0, "grass_level": 20.0,
		"vis_range": 500.0, "vis_margin": 50.0,

		# --- AI LOD ---
		"ai_anim_lod_dists_sq": [8.0*8.0, 15.0*15.0, 20.0*20.0] as Array[float],
		"ai_anim_lod_skips": [2, 5, 15] as Array[int],
		"ai_phys_lod_dist_sq": 30.0 * 30.0,
		"ai_phys_lod_skip": 10,
	}
}

func _ready() -> void:
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
	
	# 2. RenderingServer (Тени)
	RenderingServer.directional_shadow_atlas_set_size(p["shadow_size"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p["shadow_filter"])
	viewport.positional_shadow_atlas_size = p["pos_shadow_size"]
	
	# 3. Environment
	_apply_environment_settings(p)
	
	# 4. Настройка Солнца
	_apply_sun_settings(p)
	
	# 5. Обновление объектов
	_update_detail_objects(p)
	
	# 6. Сигнал
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

func _apply_sun_settings(p: Dictionary) -> void:
	var sun = get_viewport().find_child("DirectionalLight3D", true, false)
	if not sun: return
	
	sun.directional_shadow_mode = p["sun_shadow_mode"]
	sun.directional_shadow_max_distance = p["sun_max_dist"]
	
	if p["shadow_16_bits"]:
		sun.shadow_bias = 0.02 
		sun.shadow_normal_bias = 1.0
	else:
		sun.shadow_bias = 0.05 
		sun.shadow_normal_bias = 2.0

func _update_detail_objects(p: Dictionary) -> void:
	var nodes = get_tree().get_nodes_in_group(GROUP_DETAIL_OBJECTS)
	for node in nodes:
		_apply_visibility_recursive(node, p["vis_range"], p["vis_margin"])

func _apply_visibility_recursive(node: Node, range_end: float, margin: float) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_end = range_end
		node.visibility_range_end_margin = margin
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in node.get_children():
		_apply_visibility_recursive(child, range_end, margin)
