extends Node

@warning_ignore("unused_signal")
signal player_health_changed(current_hp: float, max_hp: float)

@warning_ignore("unused_signal")
signal player_died

@warning_ignore("unused_signal")
signal camera_shake_requested(strength: float, duration: float)
