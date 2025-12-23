@tool
extends MeshInstance3D

@export var terrain_path: NodePath
@export_range(1, 16) var simplification_step: int = 4: ## Шаг упрощения. 1 = макс детализация, 4 = оптимально для навмеша
	set(value):
		simplification_step = value

@export var generate_mesh: bool = false:
	set(value):
		if value:
			_generate()
		generate_mesh = false

func _generate():
	if terrain_path.is_empty():
		print("Error: Assign HTerrain node first!")
		return
		
	var terrain = get_node(terrain_path)
	if not terrain: return
	
	# Получаем данные террейна
	if not terrain.has_method("get_data"):
		print("Error: Node is not HTerrain!")
		return
		
	var data = terrain.get_data()
	if not data: return
	
	print("Generating NavMesh geometry...")
	
	# Получаем карту высот
	var heightmap: Image = data.get_image(0) # 0 = CHANNEL_HEIGHT
	var width = heightmap.get_width()
	var height = heightmap.get_height()
	
	# Параметры масштаба
	var map_scale = terrain.map_scale
	
	# Начинаем строить меш
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Создаем вершины
	# Мы идем с шагом simplification_step, чтобы меш был легче
	var step = simplification_step
	var cols = floor((width - 1) / step) + 1
	var rows = floor((height - 1) / step) + 1
	
	for z in range(0, height, step):
		for x in range(0, width, step):
			# Читаем высоту (красный канал)
			var h = heightmap.get_pixel(x, z).r
			
			# Позиция вершины с учетом масштаба террейна
			var pos = Vector3(x * map_scale.x, h, z * map_scale.z)
			
			# UV (опционально, навмешу не нужно, но для порядка)
			st.set_uv(Vector2(float(x)/width, float(z)/height))
			st.add_vertex(pos)
	
	# Создаем индексы (треугольники)
	for z in range(0, rows - 1):
		for x in range(0, cols - 1):
			var top_left = z * cols + x
			var top_right = top_left + 1
			var bottom_left = (z + 1) * cols + x
			var bottom_right = bottom_left + 1
			
			# Треугольник 1
			st.add_index(top_left)
			st.add_index(bottom_left)
			st.add_index(top_right)
			
			# Треугольник 2
			st.add_index(top_right)
			st.add_index(bottom_left)
			st.add_index(bottom_right)
	
	st.generate_normals()
	self.mesh = st.commit()
	
	# Настройка отображения
	self.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	self.visible = false # Скрываем от глаз игрока, но НавМеш его увидит!
	
	# Выравниваем позицию (HTerrain обычно центрирован или нет, ставим в 0 относительно родителя)
	self.global_transform = terrain.global_transform
	# Если у террейна включен Centered, нужно сдвинуть меш. 
	# Но обычно HTerrain строит от 0,0,0 локально. Проверь по месту.
	
	print("NavMesh geometry generated! Vertices: ", cols * rows)
