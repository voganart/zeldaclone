@tool
class_name CloudExclusionVolume
extends Area3D

@export_range(0.0, 500.0, 1.0) var clearance: float = 30.0:
	set(value):
		clearance = maxf(value, 0.0)
		_debug_signature = ""
@export var show_debug_volume: bool = true:
	set(value):
		show_debug_volume = value
		_debug_signature = ""

@onready var _debug_mesh: MeshInstance3D = get_node_or_null("DebugMesh")
var _debug_signature: String = ""


func _enter_tree() -> void:
	add_to_group(&"cloud_exclusion")


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		_update_debug_mesh()
	elif is_instance_valid(_debug_mesh):
		_debug_mesh.visible = false


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_debug_mesh()


func get_exclusion_shape() -> Shape3D:
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	return collision.shape if collision != null else null


func get_exclusion_transform() -> Transform3D:
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	return collision.global_transform if collision != null else global_transform


func get_clearance() -> float:
	return clearance


func _update_debug_mesh() -> void:
	if not is_instance_valid(_debug_mesh):
		return
	_debug_mesh.visible = show_debug_volume
	if not show_debug_volume:
		return
	var shape := get_exclusion_shape()
	if shape == null:
		_debug_mesh.mesh = null
		return
	var signature := "%s:%s:%s" % [shape, clearance, scale]
	if signature == _debug_signature:
		return
	_debug_signature = signature

	if shape is BoxShape3D:
		var box_shape := shape as BoxShape3D
		var box_mesh := BoxMesh.new()
		box_mesh.size = box_shape.size + Vector3.ONE * clearance * 2.0
		_debug_mesh.mesh = box_mesh
	elif shape is SphereShape3D:
		var sphere_shape := shape as SphereShape3D
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = sphere_shape.radius + clearance
		sphere_mesh.height = sphere_mesh.radius * 2.0
		_debug_mesh.mesh = sphere_mesh
	else:
		_debug_mesh.mesh = null
