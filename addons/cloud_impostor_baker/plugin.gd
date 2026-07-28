@tool
extends EditorPlugin

const BakerScript = preload("res://addons/cloud_impostor_baker/cloud_impostor_baker.gd")

var _bake_button: Button
var _baker: Node


func _enter_tree() -> void:
	_baker = BakerScript.new()
	add_child(_baker)

	_bake_button = Button.new()
	_bake_button.text = "Bake Cloud Impostor"
	_bake_button.tooltip_text = "Select a Cloud node containing VolumetricMesh, then bake an 8x8 atlas."
	_bake_button.pressed.connect(_on_bake_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _bake_button)
	add_tool_menu_item("Bake Selected Cloud Impostor", _on_bake_pressed)


func _exit_tree() -> void:
	remove_tool_menu_item("Bake Selected Cloud Impostor")
	if is_instance_valid(_bake_button):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _bake_button)
		_bake_button.queue_free()
	if is_instance_valid(_baker):
		_baker.queue_free()


func _on_bake_pressed() -> void:
	var cloud := _get_selected_cloud()
	if cloud == null:
		push_error("Cloud Impostor Baker: select a Cloud node containing VolumetricMesh.")
		return

	_bake_button.disabled = true
	_bake_button.text = "Baking 8x8..."
	var result: Dictionary = await _baker.bake_cloud(cloud)
	_bake_button.disabled = false
	_bake_button.text = "Bake Cloud Impostor"

	if not bool(result.get("ok", false)):
		push_error("Cloud Impostor Baker: %s" % result.get("error", "Unknown error"))
		return

	get_editor_interface().get_resource_filesystem().scan()
	print("Cloud Impostor Baker: saved %s" % result["path"])


func _get_selected_cloud() -> Node3D:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	for node in selected:
		if node is MeshInstance3D and node.name == "VolumetricMesh":
			return node.get_parent() as Node3D
		if node is Node3D and node.find_child("VolumetricMesh", true, false) is MeshInstance3D:
			return node
	return null
