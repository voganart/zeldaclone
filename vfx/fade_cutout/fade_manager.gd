extends Node

@export var player_path: NodePath
@onready var player: Node3D = get_node_or_null(player_path)

# Храним словари: { "node": MeshInstance3D, "material": Material }
var fade_targets: Array[Dictionary] = []

func _ready():
	_collect_fade_materials()

func _process(_delta):
	if not is_instance_valid(player):
		return
		
	var pos = player.global_position
	
	# Проходимся по списку задом наперед, чтобы безопасно удалять элементы
	for i in range(fade_targets.size() - 1, -1, -1):
		var target = fade_targets[i]
		var node = target["node"]
		var mat = target["material"]
		
		# 1. Проверка: Жив ли узел?
		if not is_instance_valid(node):
			fade_targets.remove_at(i)
			continue
			
		# 2. Проверка: Жив ли материал? (на всякий случай)
		if mat == null:
			fade_targets.remove_at(i)
			continue
			
		# Обновляем параметр
		mat.set_shader_parameter(GameConstants.SHADER_PARAM_PLAYER_POS, pos)

func _collect_fade_materials():
	fade_targets.clear()
	for node in get_tree().get_nodes_in_group(GameConstants.GROUP_FADE_OBJECTS):
		if node is MeshInstance3D:
			var mat_to_use = null
			
			# Проверяем override материал
			var mat_ov = node.material_override
			if mat_ov:
				if mat_ov.next_pass and (mat_ov.next_pass is ShaderMaterial):
					mat_to_use = mat_ov.next_pass
				elif mat_ov is ShaderMaterial:
					mat_to_use = mat_ov
			
			# Если нет override, берем активный материал со слота 0
			if not mat_to_use:
				var main_mat = node.get_active_material(0)
				if main_mat and (main_mat is ShaderMaterial):
					mat_to_use = main_mat
			
			if mat_to_use:
				fade_targets.append({
					"node": node,
					"material": mat_to_use
				})
