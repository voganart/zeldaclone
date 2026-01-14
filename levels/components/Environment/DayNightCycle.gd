@tool
extends Node3D

@export_category("Editor Actions")
@export var load_defaults: bool = false : set = _on_load_defaults_pressed

@export_category("Time Settings")
@export_range(0.0, 24.0, 0.01) var time_of_day: float = 12.0 : set = _set_time
@export var day_duration_seconds: float = 120.0
@export var is_playing: bool = true

@export_category("Components")
@export var sun_light: DirectionalLight3D
@export var moon_light: DirectionalLight3D # НОВОЕ: Ссылка на Луну
@export var world_env: WorldEnvironment

@export_group("Cloud Material")
@export var cloud_material: ShaderMaterial 

@export_category("Sun Settings")
@export var sun_color: Gradient
@export var sun_energy: Curve

@export_category("Moon Settings") # НОВОЕ
@export var moon_color: Gradient
@export var moon_energy: Curve

@export_category("Sky Gradients")
@export var sky_top_color: Gradient
@export var sky_horizon_color: Gradient
@export var sky_bottom_color: Gradient

@export_category("Cloud Gradients")
@export var cloud_light_color: Gradient
@export var cloud_shadow_color: Gradient

func _ready():
	if not sun_light:
		sun_light = get_node_or_null("DirectionalLight3D")
	# Пытаемся найти луну (обычно это второй DirectionalLight)
	if not moon_light:
		var lights = find_children("*", "DirectionalLight3D", false)
		for l in lights:
			if l != sun_light:
				moon_light = l
				break
	if not world_env:
		world_env = get_node_or_null("WorldEnvironment")

func _process(delta):
	if not Engine.is_editor_hint():
		if is_playing:
			time_of_day += (delta / day_duration_seconds) * 24.0
			if time_of_day >= 24.0:
				time_of_day = 0.0
			update_environment()
	else:
		update_environment()

func _set_time(value):
	time_of_day = value
	update_environment()

func _on_load_defaults_pressed(value):
	if value:
		_generate_beautiful_defaults()
		load_defaults = false
		update_environment()

func update_environment():
	var sample_pos = time_of_day / 24.0
	var angle = (sample_pos * 360.0) - 90.0
	
	# 1. Солнце
	if sun_light:
		sun_light.rotation_degrees = Vector3(-angle, 30.0, 0.0)
		if sun_color: sun_light.light_color = sun_color.sample(sample_pos)
		if sun_energy: 
			sun_light.light_energy = sun_energy.sample(sample_pos)
			sun_light.shadow_enabled = sun_light.light_energy > 0.05

	# 2. Луна (Всегда напротив солнца)
	if moon_light:
		# Луна повернута на 180 градусов относительно солнца
		moon_light.rotation_degrees = Vector3(-angle + 180.0, 30.0, 0.0)
		
		if moon_color: moon_light.light_color = moon_color.sample(sample_pos)
		if moon_energy: 
			moon_light.light_energy = moon_energy.sample(sample_pos)
			moon_light.shadow_enabled = moon_light.light_energy > 0.05

	# 3. Небо и Звезды
	if world_env and world_env.environment and world_env.environment.sky:
		var sky_mat = world_env.environment.sky.sky_material as ShaderMaterial
		if sky_mat:
			if sky_top_color: sky_mat.set_shader_parameter("sky_top_color", sky_top_color.sample(sample_pos))
			if sky_horizon_color: sky_mat.set_shader_parameter("sky_horizon_color", sky_horizon_color.sample(sample_pos))
			if sky_bottom_color: sky_mat.set_shader_parameter("sky_bottom_color", sky_bottom_color.sample(sample_pos))
			
			# Расчет видимости звезд (видны только ночью)
			# Если время < 0.25 (6 утра) или > 0.75 (18 вечера), звезды есть
			var stars_val = 0.0
			if sample_pos < 0.25 or sample_pos > 0.75:
				# Плавное появление
				if sample_pos < 0.25: 
					stars_val = 1.0 - (sample_pos / 0.25) # От 0 до 6 утра затухают
				else:
					stars_val = (sample_pos - 0.75) / 0.25 # От 18 до 24 разгораются
			
			sky_mat.set_shader_parameter("stars_intensity", stars_val)

	# 4. Облака
	if cloud_material:
		if cloud_light_color:
			var c_light = cloud_light_color.sample(sample_pos)
			cloud_material.set_shader_parameter("color_light", c_light)
			
		if cloud_shadow_color:
			var c_shadow = cloud_shadow_color.sample(sample_pos)
			cloud_material.set_shader_parameter("color_shadow", c_shadow)

func _generate_beautiful_defaults():
	print("Generating Zelda-style colors (Casual Night)...")
	
	var create_grad = func(colors: Array, offsets: Array) -> Gradient:
		var g = Gradient.new()
		if g.get_point_count() > 0: g.remove_point(0)
		if g.get_point_count() > 0: g.remove_point(0)
		g.offsets = PackedFloat32Array(offsets)
		g.colors = PackedColorArray(colors)
		return g

	var times = [0.0, 0.22, 0.26, 0.5, 0.74, 0.78, 1.0]
	
	# SUN: Делаем ночь не черной, а темно-синей
	var sun_cols = [
		Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0), # Ночью солнце не светит (светит луна)
		Color(1.0, 0.6, 0.3), Color(1.0, 0.95, 0.9), Color(1.0, 0.45, 0.2), 
		Color(0.2, 0.1, 0.3), Color(0.0, 0.0, 0.0)
	]
	sun_color = create_grad.call(sun_cols, times)
	
	# SUN ENERGY: Ночью 0
	sun_energy = Curve.new()
	for p in [Vector2(0,0), Vector2(0.22,0), Vector2(0.26,0.5), Vector2(0.5,1.5), Vector2(0.74,0.5), Vector2(0.78,0), Vector2(1,0)]:
		sun_energy.add_point(p)

	# MOON COLOR: Холодный сине-белый свет
	var moon_cols = [
		Color(0.6, 0.7, 0.9), Color(0.6, 0.7, 0.9), # Ночь (Луна светит)
		Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0), # День (Луна выкл)
		Color(0.0, 0.0, 0.0), 
		Color(0.6, 0.7, 0.9)  # Ночь
	]
	moon_color = create_grad.call(moon_cols, times)
	
	# MOON ENERGY: Светит только ночью (0.3 - достаточно ярко для казуальной ночи)
	moon_energy = Curve.new()
	for p in [Vector2(0,0.4), Vector2(0.2,0.4), Vector2(0.25,0), Vector2(0.75,0), Vector2(0.8,0.4), Vector2(1,0.4)]:
		moon_energy.add_point(p)

	# SKY TOP: Светлее, насыщенный синий (не черный!)
	var sky_top_cols = [
		Color(0.05, 0.1, 0.25),   # Ночь (Синяя, не черная)
		Color(0.1, 0.15, 0.3), 
		Color(0.2, 0.5, 0.8),
		Color(0.0, 0.45, 0.85),
		Color(0.2, 0.1, 0.4),
		Color(0.1, 0.1, 0.25),
		Color(0.05, 0.1, 0.25)
	]
	sky_top_color = create_grad.call(sky_top_cols, times)
	
	# SKY HORIZON: Светящийся циан/синий ночью
	var sky_hor_cols = [
		Color(0.1, 0.2, 0.35),    # Ночь (Светлый горизонт для видимости)
		Color(0.15, 0.2, 0.35),
		Color(1.0, 0.8, 0.5),
		Color(0.4, 0.75, 0.95),
		Color(1.0, 0.3, 0.2),
		Color(0.2, 0.15, 0.3),
		Color(0.1, 0.2, 0.35)
	]
	sky_horizon_color = create_grad.call(sky_hor_cols, times)
	
	# SKY BOTTOM:
	var sky_bot_cols = [
		Color(0.05, 0.1, 0.15),   # Ночь
		Color(0.1, 0.1, 0.15),
		Color(0.2, 0.3, 0.4),
		Color(0.25, 0.35, 0.45),
		Color(0.2, 0.1, 0.2),
		Color(0.05, 0.1, 0.15),
		Color(0.05, 0.1, 0.15)
	]
	sky_bottom_color = create_grad.call(sky_bot_cols, times)
	
	# CLOUD LIGHT: Ночью облака слегка подсвечены луной
	var c_light_cols = [
		Color(0.15, 0.2, 0.3),    # Ночь (Лунный свет на облаках)
		Color(0.2, 0.2, 0.3),
		Color(1.0, 0.85, 0.7),
		Color(1.0, 1.0, 1.0),
		Color(1.0, 0.6, 0.3),
		Color(0.25, 0.2, 0.35),
		Color(0.15, 0.2, 0.3)
	]
	cloud_light_color = create_grad.call(c_light_cols, times)
	
	# CLOUD SHADOW:
	var c_shadow_cols = [
		Color(0.05, 0.08, 0.15),  # Ночь (Темно-синие тени)
		Color(0.05, 0.05, 0.1),
		Color(0.3, 0.3, 0.5),
		Color(0.25, 0.35, 0.55),
		Color(0.25, 0.1, 0.3),
		Color(0.1, 0.05, 0.15),
		Color(0.05, 0.08, 0.15)
	]
	cloud_shadow_color = create_grad.call(c_shadow_cols, times)
	
	print("Defaults loaded! Move the Time slider to see changes.")
