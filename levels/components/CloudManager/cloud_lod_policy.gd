class_name CloudLodPolicy
extends RefCounted

enum QualityPolicy {
	LOW,
	MEDIUM,
	HIGH,
}


static func evaluate(
	distance: float,
	policy: int,
	cheap_start: float,
	transition_start: float,
	transition_end: float
) -> Dictionary:
	if transition_end <= transition_start:
		return {
			"show_volume": false,
			"show_impostor": true,
			"lod_fade": 1.0,
			"volume_lod_factor": 1.0,
		}

	var safe_cheap_start := minf(maxf(cheap_start, 0.0), transition_start)
	var volume_lod_factor := smoothstep(
		safe_cheap_start,
		maxf(transition_start, safe_cheap_start + 0.01),
		distance
	)
	if policy <= QualityPolicy.LOW:
		volume_lod_factor = 1.0
	elif policy == QualityPolicy.MEDIUM:
		volume_lod_factor = maxf(volume_lod_factor, 0.65)

	var fade := clampf(
		(distance - transition_start) / (transition_end - transition_start),
		0.0,
		1.0
	)
	return {
		"show_volume": fade < 1.0,
		"show_impostor": fade > 0.0,
		"lod_fade": fade,
		"volume_lod_factor": volume_lod_factor,
	}
