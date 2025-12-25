@tool
class_name FoliageType
extends Resource

@export_group("Source Mesh")
@export var mesh_to_spawn: Mesh

@export_group("Generation Rules")
@export var count_per_triangle: int = 2
@export var push_out_from_surface: float = 0.05

@export_group("Scale & Transform")
@export var scale_min: float = 0.5
@export var scale_max: float = 0.8
@export_range(0, 180) var gravity_tilt_min: float = 60.0
@export_range(0, 180) var gravity_tilt_max: float = 75.0
@export var random_side_tilt: float = 0.1
@export var random_spin: float = 0.1
