@tool
class_name ArenaDressing
extends Node3D

## Оформление арены: кольцо каменных столбов с огнями и светящийся круг.
## Генерируется кодом (виден и в редакторе), в сцену не сохраняется.
## В бою свет переключается с Амбдулиры (бирюза) на Ткакамчу (красный).

@export var radius: float = 9.0:
	set(value):
		radius = value
		_rebuild()
@export var pillar_count: int = 8:
	set(value):
		pillar_count = value
		_rebuild()
@export var pillar_offset: float = 1.5 ## Насколько столбы дальше круга
@export var pillar_meshes: Array[Mesh] = []:
	set(value):
		pillar_meshes = value
		_rebuild()
@export var pillar_material: Material
@export var pillar_scale: Vector3 = Vector3(1.0, 1.8, 1.0)
@export var random_seed: int = 7

@export_group("Glow")
@export var idle_color: Color = Color(0.3, 0.9, 1.0)
@export var active_color: Color = Color(1.0, 0.25, 0.08)
@export var idle_energy: float = 1.2
@export var active_energy: float = 3.0
@export var ring_width: float = 0.3

var _lights: Array[OmniLight3D] = []
var _ring_material: StandardMaterial3D
var _generated: Node3D


func _ready() -> void:
	_rebuild()


func set_active(value: bool) -> void:
	var color := active_color if value else idle_color
	var energy := active_energy if value else idle_energy
	var tween := create_tween().set_parallel()
	for light in _lights:
		tween.tween_property(light, "light_color", color, 0.4)
		tween.tween_property(light, "light_energy", energy, 0.4)
	if _ring_material:
		tween.tween_property(_ring_material, "emission", color, 0.4)
		tween.tween_property(_ring_material, "albedo_color", color, 0.4)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _generated:
		_generated.queue_free()
	_lights.clear()
	_generated = Node3D.new()
	_generated.name = "_Generated"
	add_child(_generated)

	_build_ring()
	_build_pillars()


func _build_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - ring_width * 0.5
	torus.outer_radius = radius + ring_width * 0.5
	torus.ring_segments = 8
	torus.rings = 96
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = idle_color
	_ring_material.emission_enabled = true
	_ring_material.emission = idle_color
	_ring_material.emission_energy_multiplier = 2.0
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = _ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.15, 1.0)
	ring.position.y = 0.05
	_generated.add_child(ring)


func _build_pillars() -> void:
	if pillar_count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var pillar_radius := radius + pillar_offset
	for i in pillar_count:
		var angle := TAU * float(i) / float(pillar_count)
		var pos := Vector3(cos(angle), 0.0, sin(angle)) * pillar_radius

		if not pillar_meshes.is_empty():
			var pillar := MeshInstance3D.new()
			pillar.mesh = pillar_meshes[rng.randi() % pillar_meshes.size()]
			if pillar_material:
				pillar.material_override = pillar_material
			pillar.position = pos
			pillar.rotation.y = rng.randf() * TAU
			pillar.scale = pillar_scale * rng.randf_range(0.85, 1.15)
			_generated.add_child(pillar)

		var light := OmniLight3D.new()
		light.light_color = idle_color
		light.light_energy = idle_energy
		light.omni_range = 4.0
		light.shadow_enabled = false
		light.position = pos + Vector3(0, pillar_scale.y * 1.5, 0)
		_generated.add_child(light)
		_lights.append(light)
