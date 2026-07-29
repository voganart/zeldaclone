extends Node

signal weather_changed(profile: WeatherProfile)

const PROFILE_PATH := "res://common/weather/weather_profile.tres"

@export var profile: WeatherProfile = preload(PROFILE_PATH)

var _current_direction: Vector3 = Vector3.RIGHT
var _current_wind_speed: float = 0.0
var _current_wind_strength: float = 0.0
var _current_turbulence: float = 0.0
var _current_drift_multiplier: float = 0.0
var _current_noise_advection: float = 0.0
var _current_evolution_speed: float = 0.0
var _cloud_offset: Vector3 = Vector3.ZERO
var _cloud_evolution: float = 0.0
var _blend_remaining: float = 0.0


func _ready() -> void:
	if profile == null:
		profile = WeatherProfile.new()
	profile.sanitize()
	_snap_to_profile()
	_publish_weather()


func _process(delta: float) -> void:
	if profile == null:
		return
	if _blend_remaining > 0.0:
		var blend_step: float = minf(delta, _blend_remaining)
		var weight: float = blend_step / maxf(_blend_remaining, 0.0001)
		_current_direction = _current_direction.slerp(
			profile.wind_direction,
			weight
		).normalized()
		_current_wind_speed = lerpf(
			_current_wind_speed,
			profile.wind_speed,
			weight
		)
		_current_wind_strength = lerpf(
			_current_wind_strength,
			profile.wind_strength,
			weight
		)
		_current_turbulence = lerpf(
			_current_turbulence,
			profile.wind_turbulence,
			weight
		)
		_current_drift_multiplier = lerpf(
			_current_drift_multiplier,
			profile.cloud_drift_multiplier,
			weight
		)
		_current_noise_advection = lerpf(
			_current_noise_advection,
			profile.cloud_noise_advection,
			weight
		)
		_current_evolution_speed = lerpf(
			_current_evolution_speed,
			profile.cloud_evolution_speed,
			weight
		)
		_blend_remaining -= blend_step
	else:
		_snap_to_profile()

	var drift_velocity: Vector3 = (
		_current_direction
		* _current_wind_speed
		* _current_drift_multiplier
	)
	_cloud_offset += drift_velocity * delta
	_cloud_evolution += _current_evolution_speed * delta
	_publish_weather()


func apply_profile(
	new_profile: WeatherProfile,
	blend_duration: float = -1.0
) -> void:
	if new_profile == null:
		return
	new_profile.sanitize()
	profile = new_profile
	_blend_remaining = (
		profile.manual_blend_duration
		if blend_duration < 0.0
		else maxf(blend_duration, 0.0)
	)
	if _blend_remaining <= 0.0:
		_snap_to_profile()
		_publish_weather()
	weather_changed.emit(profile)


func get_cloud_offset() -> Vector3:
	return _cloud_offset


func get_cloud_evolution() -> float:
	return _cloud_evolution


func _snap_to_profile() -> void:
	_current_direction = profile.wind_direction
	_current_wind_speed = profile.wind_speed
	_current_wind_strength = profile.wind_strength
	_current_turbulence = profile.wind_turbulence
	_current_drift_multiplier = profile.cloud_drift_multiplier
	_current_noise_advection = profile.cloud_noise_advection
	_current_evolution_speed = profile.cloud_evolution_speed


func _publish_weather() -> void:
	RenderingServer.global_shader_parameter_set(
		&"weather_wind_direction",
		_current_direction
	)
	RenderingServer.global_shader_parameter_set(
		&"weather_wind_speed",
		_current_wind_speed
	)
	RenderingServer.global_shader_parameter_set(
		&"weather_wind_strength",
		_current_wind_strength
	)
	RenderingServer.global_shader_parameter_set(
		&"weather_wind_turbulence",
		_current_turbulence
	)
	RenderingServer.global_shader_parameter_set(
		&"weather_cloud_offset",
		_cloud_offset * _current_noise_advection
	)
	RenderingServer.global_shader_parameter_set(
		&"weather_cloud_evolution",
		_cloud_evolution
	)
	RenderingServer.global_shader_parameter_set(
		&"wind_direction",
		_current_direction
	)
	RenderingServer.global_shader_parameter_set(
		&"wind_intensity",
		_current_wind_strength
	)

	var simple_grass := get_node_or_null("/root/SimpleGrass")
	if simple_grass != null:
		if simple_grass.has_method("set_wind_direction"):
			simple_grass.set_wind_direction(_current_direction)
		if simple_grass.has_method("set_wind_strength"):
			simple_grass.set_wind_strength(_current_wind_strength)
		if simple_grass.has_method("set_wind_turbulence"):
			simple_grass.set_wind_turbulence(_current_turbulence)
