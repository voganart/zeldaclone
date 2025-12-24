@tool
extends Node3D

@export_category("Randomizer Settings")
@export var random_rotation_y: bool = true
@export var scale_min: float = 0.8
@export var scale_max: float = 1.2

@export_category("Drop Settings")
@export_flags_3d_physics var ground_layer: int = 1 
@export var ray_height: float = 50.0 
@export var ray_depth: float = 100.0

@export_category("Actions")
@export var apply_randomize: bool = false:
	set(value):
		if value: _randomize_children()
		apply_randomize = false

@export var drop_to_ground: bool = false:
	set(value):
		if value: _drop_children()
		drop_to_ground = false

func _randomize_children():
	var children = get_children()
	if children.is_empty(): return

	for child in children:
		if not (child is Node3D): continue
		
		if random_rotation_y:
			child.rotation.y = randf() * TAU
			child.rotation.x = randf_range(-0.05, 0.05)
			child.rotation.z = randf_range(-0.05, 0.05)
			
		var s = randf_range(scale_min, scale_max)
		child.scale = Vector3(s, s, s)
	
	print("Randomized ", children.size(), " items.")

func _drop_children():
	var children = get_children()
	if children.is_empty(): return
	
	var space_state = get_world_3d().direct_space_state
	var moved_count = 0
	
	for child in children:
		if not (child is Node3D): continue
		
		var from = child.global_position
		from.y += ray_height 
		
		var to = from
		to.y -= (ray_height + ray_depth)
		
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = ground_layer
		
		var exclusions = []
		_collect_collision_rids(child, exclusions)
		query.exclude = exclusions
		
		var result = space_state.intersect_ray(query)
		
		if result:
			child.global_position = result.position
			moved_count += 1
		else:
			print("Ray missed ground for: ", child.name)
			
	print("Dropped ", moved_count, " items to ground.")

func _collect_collision_rids(node: Node, list: Array):
	if node is CollisionObject3D:
		list.append(node.get_rid())
	
	for child in node.get_children():
		_collect_collision_rids(child, list)

func _ready():
	if Engine.is_editor_hint():
		set_process(false)
