extends Node

var _failures: Array[String] = []


func _ready() -> void:
	_run()


func _run() -> void:
	var policy_path := "res://levels/components/CloudManager/cloud_lod_policy.gd"
	if not ResourceLoader.exists(policy_path):
		_fail("CloudLodPolicy script is missing")
		_finish()
		return

	var policy_script = load(policy_path)
	if policy_script == null:
		_fail("CloudLodPolicy script is missing")
		_finish()
		return

	_expect(
		policy_script.evaluate(40.0, 2, 80.0, 150.0, 210.0),
		true, false, 0.0, 0.0, "HIGH full"
	)
	_expect(
		policy_script.evaluate(120.0, 2, 80.0, 150.0, 210.0),
		true, false, 0.0, 1.0, "HIGH cheap"
	)
	_expect(
		policy_script.evaluate(180.0, 2, 80.0, 150.0, 210.0),
		true, true, 0.5, 1.0, "HIGH transition"
	)
	_expect(
		policy_script.evaluate(240.0, 2, 80.0, 150.0, 210.0),
		false, true, 1.0, 1.0, "HIGH billboard"
	)
	_expect(
		policy_script.evaluate(20.0, 1, 55.0, 110.0, 165.0),
		true, false, 0.0, 0.65, "MEDIUM near"
	)
	_expect(
		policy_script.evaluate(20.0, 0, 0.0, 45.0, 75.0),
		true, false, 0.0, 1.0, "LOW cheap"
	)

	var invalid_range: Dictionary = policy_script.evaluate(
		120.0, 2, 80.0, 180.0, 120.0
	)
	if not is_equal_approx(invalid_range["lod_fade"], 1.0):
		_fail("Invalid transition range must resolve without division by zero")

	_finish()


func _expect(
	result: Dictionary,
	show_volume: bool,
	show_impostor: bool,
	lod_fade: float,
	volume_lod_factor: float,
	label: String
) -> void:
	if result.get("show_volume") != show_volume:
		_fail("%s: wrong volume visibility" % label)
	if result.get("show_impostor") != show_impostor:
		_fail("%s: wrong impostor visibility" % label)
	if not is_equal_approx(result.get("lod_fade", -1.0), lod_fade):
		_fail("%s: expected fade %.2f, got %.2f" % [label, lod_fade, result.get("lod_fade", -1.0)])
	if not is_equal_approx(
		result.get("volume_lod_factor", -1.0),
		volume_lod_factor
	):
		_fail(
			"%s: expected volume LOD %.2f, got %.2f"
			% [label, volume_lod_factor, result.get("volume_lod_factor", -1.0)]
		)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Cloud LOD policy tests: PASS")
		get_tree().quit(0)
	else:
		print("Cloud LOD policy tests: FAIL (%d)" % _failures.size())
		get_tree().quit(1)
