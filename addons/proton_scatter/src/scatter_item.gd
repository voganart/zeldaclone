@tool
extends Node3D


const ScatterUtil := preload('./common/scatter_util.gd')


@export_category("ScatterItem")
@export var proportion := 100:
	set(val):
		proportion = val
		ScatterUtil.request_parent_to_rebuild(self)

@export_enum("From current scene:0", "From disk:1") var source = 1:
	set(val):
		source = val
		property_list_changed.emit()
		# Принудительно сбрасываем кэш при смене режима
		_target_scene = null
		ScatterUtil.request_parent_to_rebuild(self)

@export_group("Source options", "source_")
@export var source_scale_multiplier := 1.0:
	set(val):
		source_scale_multiplier = val
		ScatterUtil.request_parent_to_rebuild(self)

@export var source_ignore_position := true:
	set(val):
		source_ignore_position = val
		ScatterUtil.request_parent_to_rebuild(self)

@export var source_ignore_rotation := true:
	set(val):
		source_ignore_rotation = val
		ScatterUtil.request_parent_to_rebuild(self)

@export var source_ignore_scale := true:
	set(val):
		source_ignore_scale = val
		ScatterUtil.request_parent_to_rebuild(self)

@export_group("Override options", "override_")
@export var override_material: Material:
	set(val):
		override_material = val
		ScatterUtil.request_parent_to_rebuild(self)

@export var override_process_material: Material:
	set(val):
		override_process_material = val
		ScatterUtil.request_parent_to_rebuild(self) # TODO - No need for a full rebuild here

@export var override_cast_shadow: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
	set(val):
		override_cast_shadow = val
		ScatterUtil.request_parent_to_rebuild(self) # TODO - Only change the multimesh flag instead

@export_group("Visibility", "visibility")
@export_flags_3d_render var visibility_layers: int = 1
@export var visibility_range_begin : float = 0
@export var visibility_range_begin_margin : float = 0
@export var visibility_range_end : float = 0
@export var visibility_range_end_margin : float = 0
#TODO what is a nicer way to expose this?
@export_enum("Disabled:0", "Self:1") var visibility_range_fade_mode = 0

@export_group("Level Of Detail", "lod_")
@export var lod_generate := true:
	set(val):
		lod_generate = val
		ScatterUtil.request_parent_to_rebuild(self)
@export_range(0.0, 180.0) var lod_merge_angle := 25.0:
	set(val):
		lod_merge_angle = val
		ScatterUtil.request_parent_to_rebuild(self)
@export_range(0.0, 180.0) var lod_split_angle := 60.0:
	set(val):
		lod_split_angle = val
		ScatterUtil.request_parent_to_rebuild(self)

# --- ПЕРЕМЕННЫЕ ---
var source_position: Vector3
var source_rotation: Vector3
var source_scale: Vector3
var source_data_ready := false

# Храним загруженную сцену (PackedScene)
var _target_scene
# ------------------

var path: String:
	set(val):
		path = val
		source_data_ready = false
		_target_scene = null # Сбрасываем кэш при смене пути
		ScatterUtil.request_parent_to_rebuild(self)


func _get_property_list() -> Array:
	var list := []

	if source == 0:
		list.push_back({
			name = "path",
			type = TYPE_NODE_PATH,
		})
	else:
		list.push_back({
			name = "path",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_FILE,
		})

	return list


func get_item() -> Node3D:
	if path.is_empty():
		return null

	var node: Node3D

	if source == 0 and has_node(path):
		node = get_node(path).duplicate()
	elif source == 1:
		# !!! ИЗМЕНЕНИЕ: Ленивая загрузка (Lazy Loading) !!!
		# Если _target_scene пустая (сбросилась или еще не загружена), пробуем загрузить
		if not _target_scene:
			_force_load_from_disk()
			
		if _target_scene:
			node = _target_scene.instantiate()

	if node:
		# Проверка на то, что это Node3D (Scatter не умеет работать с Node2D или Control)
		if not (node is Node3D):
			print_rich("[color=red]ProtonScatter Error:[/color] The scene/resource at '" + path + "' root node is not a Node3D!")
			node.queue_free()
			return null
			
		_save_source_data(node)
		return node

	return null

# Вспомогательная функция для загрузки ресурсов (Мешей или Сцен)
func _force_load_from_disk():
	if not ResourceLoader.exists(path):
		return

	var res = load(path)
	if res is PackedScene:
		# Это сцена (.tscn, .glb, .gltf)
		_target_scene = res
	elif res is Mesh:
		# Это меш (.obj, .tres, .res) - оборачиваем в сцену
		var mi = MeshInstance3D.new()
		mi.name = path.get_file().get_basename() 
		mi.mesh = res
		var packed = PackedScene.new()
		if packed.pack(mi) == OK:
			_target_scene = packed
		mi.free()
	else:
		print_rich("[color=yellow]ProtonScatter Warning:[/color] Resource at '" + path + "' is not a Scene or Mesh.")
		_target_scene = null


# Takes a transform in input, scale it based on the local scale multiplier
# If the source transform is not ignored, also copy the source position, rotation and scale.
# Returns the processed transform
func process_transform(t: Transform3D) -> Transform3D:
	if not source_data_ready:
		_update_source_data()

	var origin = t.origin
	t.origin = Vector3.ZERO

	t = t.scaled(Vector3.ONE * source_scale_multiplier)

	if not source_ignore_scale:
		t = t.scaled(source_scale)

	if not source_ignore_rotation:
		t = t.rotated(t.basis.x.normalized(), source_rotation.x)
		t = t.rotated(t.basis.y.normalized(), source_rotation.y)
		t = t.rotated(t.basis.z.normalized(), source_rotation.z)

	t.origin = origin

	if not source_ignore_position:
		t.origin += source_position

	return t


func _save_source_data(node: Node3D) -> void:
	if not node:
		return

	source_position = node.position
	source_rotation = node.rotation
	source_scale = node.scale
	source_data_ready = true


func _update_source_data() -> void:
	var node = get_item()
	if node:
		node.queue_free()
