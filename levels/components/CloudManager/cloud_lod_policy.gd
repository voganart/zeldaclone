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
	transition_start: float,
	transition_end: float
) -> Dictionary:
	if policy <= QualityPolicy.LOW:
		return {
			"show_volume": false,
			"show_impostor": false,
			"lod_fade": 1.0,
		}

	if policy == QualityPolicy.MEDIUM:
		return {
			"show_volume": false,
			"show_impostor": true,
			"lod_fade": 1.0,
		}

	if transition_end <= transition_start:
		return {
			"show_volume": false,
			"show_impostor": true,
			"lod_fade": 1.0,
		}

	var fade := clampf(
		(distance - transition_start) / (transition_end - transition_start),
		0.0,
		1.0
	)
	return {
		"show_volume": fade < 1.0,
		"show_impostor": fade > 0.0,
		"lod_fade": fade,
	}
