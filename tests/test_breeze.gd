extends SceneTree
## The ambient breeze (docs/scenic/breeze.md): its default strength, its
## slow variation, storms reading stronger, frame-rate independence, and the
## shared shader hooks plants call. Headless: the shader side is checked as
## source only; how far plants move is GPU work (see the doc's numbers).
const Atmosphere = preload("res://studies/atmosphere.gd")
var failures := 0

func _initialize() -> void:
	_strength()
	_variation()
	_frame_rate()
	_shaders()
	print("PASS: breeze strength, variation, frame-rate independence and hooks" if failures == 0 else "FAIL: breeze")
	quit(1 if failures else 0)

func _strength() -> void:
	check(is_equal_approx(Atmosphere.breeze_air(0.0), Atmosphere.BREEZE_FLOOR), "A dead-calm dial still breathes at the floor")
	var light := Atmosphere.breeze_air(0.4)
	check(absf(light-0.532) < 0.005, "The default 0.4 air is a 0.53 breeze: %.3f" % light)
	var registered: Variant = ProjectSettings.get_setting("shader_globals/zs_breeze")
	check(registered is Dictionary and absf(float(registered.value)-light) < 0.01, "zs_breeze is registered at the default breeze: %s" % str(registered))
	# The weather's dial order survives the floor, and storms stay well ahead.
	var last := 0.0
	for air in [0.0,0.15,0.4,0.8,1.3,1.4,2.5]:
		var breeze := Atmosphere.breeze_air(air)
		check(breeze > last, "The breeze rises with the air at %.2f" % air)
		last = breeze
	check(Atmosphere.breeze_air(1.4) > 2.5*Atmosphere.breeze_air(0.15), "A storm's breeze is well over twice a calm one's")
	check(absf(Atmosphere.breeze_air(2.5)-2.5) < 0.05, "Strong air passes through nearly unchanged")
	check(Atmosphere.breeze_air(0.15) < 0.75*Atmosphere.breeze_air(0.4), "A calm world stays calmer than a light one")
	# What a freshly opened world publishes, in a deep lull and at a full swell.
	var air: Node3D = Atmosphere.new()
	check(is_equal_approx(air.strength, 0.4), "A fresh atmosphere starts at 0.4 air")
	var low := INF
	var high := -INF
	for i in range(1200):
		air._wind_time = float(i)*0.5
		low = minf(low, air.breeze())
		high = maxf(high, air.breeze())
	check(low > 0.3 and high < 0.76, "A fresh world's breeze stays between 0.3 and 0.76: %.3f to %.3f" % [low,high])
	air.free()

func _variation() -> void:
	var low := INF
	var high := -INF
	var sum := 0.0
	var steepest := 0.0
	var widest := 0.0
	var count := 0
	var t := 0.0
	var window: Array[float] = []
	while t < 900.0:
		var value := Atmosphere.breeze_swell(t)
		low = minf(low, value)
		high = maxf(high, value)
		sum += value
		count += 1
		steepest = maxf(steepest, absf(Atmosphere.breeze_swell(t+0.1)-value)/0.1)
		window.append(value)
		if window.size() > 40: window.pop_front()
		widest = maxf(widest, window.max()-window.min())
		t += 0.5
	check(low >= 0.58 and high <= 1.42, "Swells stay within 0.6 to 1.4: %.3f to %.3f" % [low,high])
	check(absf(sum/count-1.0) < 0.03, "Swells average to 1: %.3f" % (sum/count))
	check(widest > 0.35, "Within 20 s the breeze can lull and swell by over a third: %.3f" % widest)
	# gust_at, which the raw dial breathes by, swings up to about 88 % of
	# its mean in a second, the whole land in step.
	check(steepest < 0.12, "It changes slowly, under 12%% a second: %.3f" % steepest)

func _frame_rate() -> void:
	var fine: Node3D = Atmosphere.new()
	var coarse: Node3D = Atmosphere.new()
	# Settled air: the dial's own easing steps with the frame (an older,
	# separate matter); the breeze and the air's travel must not.
	for air in [fine, coarse]:
		air.strength = 0.9
		air._air_strength = 0.9
	for i in range(600): fine.advance(1.0/60.0, false)
	for i in range(10): coarse.advance(1.0, false)
	check(absf(fine._wind_time-coarse._wind_time) < 1e-6, "The breeze clock is the same at 60 fps and 1 fps")
	check(absf(fine._gust_distance-coarse._gust_distance) < 1e-4, "The air travels alike at 60 fps and 1 fps: %.4f vs %.4f" % [fine._gust_distance,coarse._gust_distance])
	check(absf(fine.breeze()-coarse.breeze()) < 0.002, "The breeze is the same at 60 fps and 1 fps: %.4f vs %.4f" % [fine.breeze(),coarse.breeze()])
	var held: float = fine.breeze()
	fine.advance(5.0, true)
	check(fine.breeze() == held, "A paused world holds its breeze")
	fine.swell = 0.5
	check(fine.breeze() > held, "The painting hand's swell stirs the breeze")
	fine.free()
	coarse.free()

## The shared hooks keep their names (other plants call them) and every
## foliage shader bends in the breeze rather than the raw wind dial.
func _shaders() -> void:
	var wind := FileAccess.get_file_as_string("res://shaders/reference_wind.gdshaderinc")
	for name in ["float zs_breeze_field(", "float zs_gust_pulse_at(", "vec2 zs_gust_push_at(", "vec3 zs_blow_bend(", "float zs_blow_give(",
			"float zs_breeze_air(", "float zs_gust_band_at(", "float zs_wave_crest_at(", "float zs_breeze_lean_at(", "float zs_breeze_lean_wave(",
			"float zs_breeze_pace(", "vec2 zs_breeze_offset(", "vec3 zs_breeze_bend("]:
		check(wind.contains(name), "reference_wind keeps %s" % name)
	check(FileAccess.get_file_as_string("res://shaders/grass_look.gdshaderinc").contains("float zs_grass_crest(vec2 g_root, float g_wave_length, float g_wave_speed, vec2 g_offset)"), "zs_grass_crest keeps its signature")
	check(FileAccess.get_file_as_string("res://shaders/reference_globals.gdshaderinc").contains("global uniform float zs_breeze;"), "zs_breeze is a shared global")
	for path in ["reference_surface.gdshader", "layered_canopy_surface.gdshader", "layered_tree_wood.gdshader", "dense_grass.gdshader", "conifer_wind.gdshaderinc"]:
		var code := FileAccess.get_file_as_string("res://shaders/"+path)
		check(not code.contains("zs_wind_strength"), "%s sways in the breeze, not the raw wind dial" % path)
		check(code.contains("zs_breeze_"), "%s calls the shared breeze" % path)
	# Metal allows 31 varyings; the surface shader sits at the limit (4b6508e).
	var surface := FileAccess.get_file_as_string("res://shaders/reference_surface.gdshader")
	var varyings := 0
	for line in surface.split("\n"):
		if line.strip_edges().begins_with("varying "): varyings += 1
	check(varyings <= 14, "reference_surface adds no varyings: %d declarations" % varyings)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
