extends Node

@export var player_path: NodePath
@onready var player: Node3D = get_node_or_null(player_path)

var fade_materials: Array = []

func _ready():
	_collect_fade_materials()

func _process(_delta):
	if not player:
		return
	var pos = player.global_position
	for mat in fade_materials:
		mat.set_shader_parameter(GameConstants.SHADER_PARAM_PLAYER_POS, pos)

func _collect_fade_materials():
	fade_materials.clear()
	for node in get_tree().get_nodes_in_group(GameConstants.GROUP_FADE_OBJECTS):
		if node is MeshInstance3D:
			# берем material_override, и если у него есть next_pass — используем next_pass
			var main_mat = node.get_active_material(0)
			# material_override может содержать основной материал
			var mat = node.material_override
			# если есть Next Pass в material_override:
			if mat and mat.next_pass and (mat.next_pass is ShaderMaterial):
				fade_materials.append(mat.next_pass)
			# иначе, если main материал сам shadermaterial с нашим шейдером:
			elif main_mat and (main_mat is ShaderMaterial):
				fade_materials.append(main_mat)
