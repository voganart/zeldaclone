class_name BreakableObject
extends RigidBody3D

@export var health_component: Node
@export var debris_vfx_index: int = 1
@export var vfx_offset: Vector3 = Vector3(0, 0.5, 0)

@onready var nav_obstacle: NavigationObstacle3D = $NavigationObstacle3D

@export var stop_velocity_threshold: float = 0.1 
var _time_since_stopped: float = 0.0
var _is_static_mode: bool = true
var _initial_radius: float = 0.0

func _ready() -> void:
	if health_component:
		health_component.died.connect(_on_broken)
	
	if nav_obstacle:
		_initial_radius = nav_obstacle.radius
		# При старте ящик стоит, включаем статический режим
		nav_obstacle.radius = 0.0
		_is_static_mode = true
	else:
		push_warning("NavigationObstacle3D not found on ", name)


func _physics_process(delta: float) -> void:
	if not nav_obstacle: return

	# Проверяем, движется ли ящик
	if linear_velocity.length() > stop_velocity_threshold:
		# Ящик движется -> переключаемся в динамический режим
		if _is_static_mode:
			_is_static_mode = false
			# Включаем радиус, отключаем статику (устанавливая пустые вершины)
			nav_obstacle.radius = _initial_radius
			nav_obstacle.vertices = PackedVector3Array([]) # Важно!
		_time_since_stopped = 0.0
	else:
		# Ящик стоит
		_time_since_stopped += delta
		# Если стоит неподвижно больше 0.5 секунды и был в динамическом режиме
		if not _is_static_mode and _time_since_stopped > 0.5:
			_is_static_mode = true
			# Отключаем радиус, включаем статику (Godot сам вернет вершины из инспектора)
			nav_obstacle.radius = 0.0
			# Чтобы Godot подхватил статические вершины, нужно "пнуть" свойство
			nav_obstacle.set("vertices", nav_obstacle.get("vertices")) 

# ... (остальные функции take_damage, _on_broken без изменений) ...

func take_damage(amount: float, knockback_force: Vector3, _is_heavy: bool = false) -> void:
	var dampened_force = knockback_force * 0.5 
	dampened_force.y = min(dampened_force.y, 2.0)
	apply_central_impulse(dampened_force)
	
	if health_component:
		health_component.take_damage(amount)

func _on_broken() -> void:
	var pool = get_tree().get_first_node_in_group("vfx_pool")
	if pool:
		pool.spawn_effect(debris_vfx_index, to_global(vfx_offset))
	queue_free()
