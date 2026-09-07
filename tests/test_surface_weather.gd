extends SceneTree
const Climate = preload("res://studies/surface_weather.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var c := Climate.new()
	c.cold = 1.0
	c.target_cold = 1.0
	for i in range(100):
		c.advance(0.1, false, 0.8, 0.9, 0.4)
	check(c.snow_cover > 0.7 and c.ice > 0.65, "Sustained snowfall builds snowpack and ice")
	check(c.foliage_wet == 0.0, "Snow does not soak foliage")
	var pack: float = c.snow_cover
	for i in range(50):
		c.advance(0.1, false, 0.0, 0.1, 0.4)
	check(c.snow_cover == pack, "Cold clear weather retains snowpack")
	c.ice = 1.0
	var clock: float = c.flow_time
	c.advance(1.0, false, 0.0, 0.1, 0.4)
	check(c.flow_time == clock, "Fully frozen water retains its motion phase")
	var frozen := Vector4(c.ice, c.snow_cover, c.cold, c.flow_time)
	c.target_cold = 0.0
	c.advance(5.0, true, 1.0, 0.5, 0.4)
	check(Vector4(c.ice, c.snow_cover, c.cold, c.flow_time).is_equal_approx(frozen), "Pause freezes thermal integration and flow time")
	for i in range(150):
		c.advance(0.1, false, 0.0, 0.1, 0.4)
	check(c.ice < 0.3 and c.snow_cover < pack and c.flow_time > clock, "Warmth thaws ice, melts snow and resumes flow")
	var whole := Climate.wet_after(0.2, 0.7, 0.0, 0.8, 0.4, 10.0)
	var stepped := 0.2
	for i in range(100):
		stepped = Climate.wet_after(stepped, 0.7, 0.0, 0.8, 0.4, 0.1)
	check(absf(whole - stepped) < 0.000001, "Ground soaking is independent of frame subdivision")
	check(whole > 0.8, "Rain soaks the ground")
	var dry := Climate.wet_after(whole, 0.0, 0.0, 0.1, 0.4, 10.0)
	check(dry > 0.4 and dry < whole, "Wet ground lingers after rain clears")
	var warm := Climate.new()
	for i in range(100):
		warm.advance(0.1, false, 0.8, 0.5, 0.4)
	check(warm.air_wet > 0.9 and warm.ice == 0.0, "Warm rain leaves suspended drops without ice")
	warm.advance(5.0, false, 0.0, 0.1, 0.4)
	check(warm.air_wet > 0.5, "Suspended drops persist for a post-rain rainbow")
	print("Surface weather checks: ", failures, " failures")
	quit(1 if failures else 0)
