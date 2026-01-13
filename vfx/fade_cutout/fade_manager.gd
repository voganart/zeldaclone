extends Node

@export var player_path: NodePath
var player: Node3D

# Храним словари: { "node": MeshInstance3D, "material": Material }
var fade_targets: Array[Dictionary] = []

func _ready():
	_collect_fade_materials()
	
	# Пытаемся найти сразу, если путь задан
	if player_path:
		player = get_node_or_null(player_path)

func _process(_delta):
	# --- ЛЕНИВЫЙ ПОИСК ИГРОКА ---
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player: return
	# -----------------------------
		
	var pos = player.global_position
	
	for i in range(fade_targets.size() - 1, -1, -1):
		var target = fade_targets[i]
		var node = target["node"]
		var mat = target["material"]
		
		if not is_instance_valid(node) or mat == null:
			fade_targets.remove_at(i)
			continue
			
		# Обновляем параметр шейдера
		mat.set_shader_parameter(GameConstants.SHADER_PARAM_PLAYER_POS, pos)

func _collect_fade_materials():
	fade_targets.clear()
	# Ищем объекты в спец. группе (стены, колонны)
	for node in get_tree().get_nodes_in_group(GameConstants.GROUP_FADE_OBJECTS):
		if node is MeshInstance3D:
			var mat_to_use = null
			
			var mat_ov = node.material_override
			if mat_ov:
				if mat_ov.next_pass and (mat_ov.next_pass is ShaderMaterial):
					mat_to_use = mat_ov.next_pass
				elif mat_ov is ShaderMaterial:
					mat_to_use = mat_ov
			
			if not mat_to_use:
				var main_mat = node.get_active_material(0)
				if main_mat and (main_mat is ShaderMaterial):
					mat_to_use = main_mat
			
			if mat_to_use:
				fade_targets.append({
					"node": node,
					"material": mat_to_use
				})
