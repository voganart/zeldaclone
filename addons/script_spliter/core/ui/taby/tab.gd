@tool
extends Button
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Script Spliter
#	https://github.com/CodeNameTwister/Script-Spliter
#
#	Script Spliter addon for godot 4
#	author:		"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

const SEPARATOR = preload("res://addons/script_spliter/core/ui/taby/separator.tscn")
static var line : VSeparator = null

var _delta : float = 0.0

func _ready() -> void:
	set_process(false)
	add_to_group(&"SP_TAB_BUTTON")
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	setup()

func _get_drag_data(__ : Vector2) -> Variant:
	var c : Control = duplicate(0)
	c.z_index = RenderingServer.CANVAS_ITEM_Z_MAX 
	set_drag_preview(c)
	pressed.emit()
	return self
	
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if is_instance_valid(line):
		line.delete()
	if data is Node:
		if data == self:
			return
		elif data.is_in_group(&"SP_TAB_BUTTON"):
			line.update(self)
			var node : Node = owner
			if node:
				var idx : int = node.get_index()
				if idx >= 0:
					var _node : Node = data.owner
					var lft : bool = false
					if get_global_mouse_position().x <= get_global_rect().get_center().x:
						lft = true
					
					var root : Node = _node
					for __ : int in range(3):
						root = root.get_parent()
						if !is_instance_valid(root):
							return
					for x : Node in get_tree().get_nodes_in_group(&"ScriptSpliter"):
						if x.has_method(&"get_builder"):
							var o : Object = x.call(&"get_builder")
							if o.has_method(&"swap_by_src"):
								o.call(&"swap_by_src", data.tooltip_text, tooltip_text, lft)
								break
					if root:
						if root.has_method(&"update"):
							root.call(&"update")
	
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is Node:
		if data == self:
			return false
		elif data.is_in_group(&"SP_TAB_BUTTON"):
			_delta = 0.0
			if !is_instance_valid(line):
				line = SEPARATOR.instantiate()
				var root : Node = Engine.get_main_loop().root
				if root:
					root.add_child(line)
			if line:
				var rct : Rect2 = get_global_rect()
				line.update(self)
				if at_position.x <= size.x * 0.5:
					line.global_position = rct.position
				else:
					line.global_position = Vector2(rct.end.x, rct.position.y)
				
				var style : StyleBoxLine = line.get(&"theme_override_styles/separator")
				style.set(&"thickness",size.y)
				style.set(&"color",owner.color_rect.color)
			return true
	return false

var is_drag : bool = false:
	set(e):
		is_drag = e
		if is_drag:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

var _fms : float = 0.0

func reset() -> void:
	if is_drag:
		set_process(false)
		is_drag = false
		if is_inside_tree():
			var parent : Node = self
			
			for __ : int in range(10):
				parent = parent.get_parent()
				if parent.has_signal(&"out_dragging"):
					break
			if !is_instance_valid(parent):
				return
			if parent.has_signal(&"out_dragging"):
				for x : Node in parent.get_children():
					if x is TabContainer:
						parent.emit_signal(&"out_dragging",x.get_tab_bar())
						return
				
			

func _init() -> void:
	if is_node_ready():
		_ready()
	
func _enter_tree() -> void:
	if !is_in_group(&"__SPLITER_TAB__"):
		add_to_group(&"__SPLITER_TAB__")
	if is_node_ready():
		return
	owner.modulate.a = 0.0
	get_tree().create_tween().tween_property(owner, "modulate:a", 1.0, 0.5)

func _exit_tree() -> void:
	if is_in_group(&"__SPLITER_TAB__"):
		remove_from_group(&"__SPLITER_TAB__")

func _process(delta: float) -> void:
	_fms += delta
	if _fms > 0.24:
		if is_drag:
			if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				set_process(false)
				is_drag = false
				var parent : Node = self
				
				for __ : int in range(10):
					parent = parent.get_parent()
					if parent.has_signal(&"out_dragging"):
						break
				if !is_instance_valid(parent):
					return
				if parent.has_signal(&"out_dragging"):
					for x : Node in parent.get_children():
						if x is TabContainer:
							parent.emit_signal(&"out_dragging",x.get_tab_bar())
							return
				
			
		else:
			is_drag = true
			var parent : Node = self
			for __ : int in range(10):
				parent = parent.get_parent()
				if parent.has_signal(&"on_dragging"):
					break
				if !is_instance_valid(parent):
					return
			if parent.has_signal(&"on_dragging"):
				for x : Node in parent.get_children():
					if x is TabContainer:
						parent.emit_signal(&"on_dragging",x.get_tab_bar())
						return

func setup() -> void:
	if !gui_input.is_connected(_on_input):
		gui_input.connect(_on_input)
	if !is_in_group(&"__SPLITER_TAB__"):
		add_to_group(&"__SPLITER_TAB__")

func _on_input(e : InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == 1:
			is_drag = false
			if e.pressed:
				_fms = 0.0
				set_process(true)
			else:
				set_process(false)
				if _fms >= 0.24:
					var parent : Node = self
					for __ : int in range(10):
						parent = parent.get_parent()
						if parent.has_signal(&"out_dragging"):
							break
						if !is_instance_valid(parent):
							return
					if parent.has_signal(&"out_dragging"):
						for x : Node in parent.get_children():
							if x is TabContainer:
								parent.emit_signal(&"out_dragging",x.get_tab_bar())
								return
