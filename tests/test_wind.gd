extends SceneTree
var failures := 0
func _initialize() -> void:
	var atmosphere = load("res://studies/atmosphere.gd").new()
	var samples = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/wind-checks.json"))
	for sample in samples:
		check(absf(atmosphere.gust_at(sample.t) - sample.value) < 1e-12, "Source wind strength at " + str(sample.t))
	atmosphere.strength = 2.0
	atmosphere._air_strength = 2.0
	atmosphere.advance(3.0, false)
	check(is_equal_approx(atmosphere._gust_distance, 16.2), "Air travels at source gustSpeed")
	var distance_before: float = atmosphere._gust_distance
	var clock_before: float = atmosphere._wind_time
	atmosphere.advance(10.0, true)
	check(atmosphere._gust_distance == distance_before and atmosphere._wind_time == clock_before, "Pause holds both strength and field clocks")
	atmosphere.direction_angle = 110.0
	atmosphere.advance(1.0, false)
	check(is_equal_approx(atmosphere._gust_distance, 21.6), "Turning wind preserves accumulated field distance")
	atmosphere.free()
	print("PASS: source wind strength, travel and pause" if failures == 0 else "FAIL: wind")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
