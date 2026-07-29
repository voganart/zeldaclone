class_name WeatherProfile
extends Resource

@export_group("Wind")
@export var wind_direction: Vector3 = Vector3(1.0, 0.0, 0.25)
@export_range(0.0, 100.0, 0.05) var wind_speed: float = 1.0
@export_range(0.0, 4.0, 0.01) var wind_strength: float = 0.3
@export_range(0.0, 4.0, 0.01) var wind_turbulence: float = 0.15
@export_range(0.0, 30.0, 0.1) var manual_blend_duration: float = 3.0

@export_group("Cloud Motion")
@export_range(0.0, 20.0, 0.05) var cloud_drift_multiplier: float = 1.0
@export_range(0.0, 20.0, 0.05) var cloud_noise_advection: float = 1.0
@export_range(0.0, 2.0, 0.001) var cloud_evolution_speed: float = 0.015

@export_group("Cloud Lifecycle")
@export_range(10.0, 3600.0, 1.0) var formation_lifetime_min: float = 360.0
@export_range(10.0, 3600.0, 1.0) var formation_lifetime_max: float = 900.0
@export_range(1.0, 600.0, 1.0) var formation_fade_duration: float = 90.0

var _last_valid_direction: Vector3 = Vector3.RIGHT


func sanitize() -> void:
	var horizontal_direction := Vector3(
		wind_direction.x,
		0.0,
		wind_direction.z
	)
	if horizontal_direction.length_squared() > 0.000001:
		_last_valid_direction = horizontal_direction.normalized()
	wind_direction = _last_valid_direction
	wind_speed = maxf(wind_speed, 0.0)
	wind_strength = maxf(wind_strength, 0.0)
	wind_turbulence = maxf(wind_turbulence, 0.0)
	manual_blend_duration = maxf(manual_blend_duration, 0.0)
	cloud_drift_multiplier = maxf(cloud_drift_multiplier, 0.0)
	cloud_noise_advection = maxf(cloud_noise_advection, 0.0)
	cloud_evolution_speed = maxf(cloud_evolution_speed, 0.0)
	formation_lifetime_min = maxf(formation_lifetime_min, 10.0)
	formation_lifetime_max = maxf(
		formation_lifetime_max,
		formation_lifetime_min
	)
	formation_fade_duration = minf(
		maxf(formation_fade_duration, 1.0),
		formation_lifetime_min * 0.45
	)


func copy_values_from(source: WeatherProfile) -> void:
	if source == null:
		return
	wind_direction = source.wind_direction
	wind_speed = source.wind_speed
	wind_strength = source.wind_strength
	wind_turbulence = source.wind_turbulence
	manual_blend_duration = source.manual_blend_duration
	cloud_drift_multiplier = source.cloud_drift_multiplier
	cloud_noise_advection = source.cloud_noise_advection
	cloud_evolution_speed = source.cloud_evolution_speed
	formation_lifetime_min = source.formation_lifetime_min
	formation_lifetime_max = source.formation_lifetime_max
	formation_fade_duration = source.formation_fade_duration
	sanitize()
