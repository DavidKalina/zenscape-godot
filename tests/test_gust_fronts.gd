extends SceneTree
## Gust fronts (studies/gust_fronts.gd, docs/scenic/gust-fronts.md): fronts
## come every so often, roll downwind across the plate, hit fast and let go
## slowly with an overshoot, are patchy across and ragged along, hush the
## breeze before they come, hold while paused, and reach every plant through
## the shared breeze lean. Headless: the shader side is checked as source.
const GustFronts = preload("res://studies/gust_fronts.gd")
const Atmosphere = preload("res://studies/atmosphere.gd")
var failures := 0

func _initialize() -> void:
	_push_shape()
	_schedule()
	_travel()
	_lull()
	_atmosphere()
	_shaders()
	print("PASS: gust fronts" if failures == 0 else "FAIL: gust fronts")
	quit(1 if failures else 0)

## At a point the front hits fast, overshoots, and lets go slowly.
func _push_shape() -> void:
	check(GustFronts.push(-1.0) == 0.0, "Nothing before the front comes")
	var peak := 0.0
	var peak_at := 0.0
	var reached := INF
	for i in range(0, 400):
		var tau := -0.5 + float(i) * 0.01
		var v := GustFronts.push(tau)
		if v > peak:
			peak = v
			peak_at = tau
		if reached == INF and v >= 0.8: reached = tau
	check(reached - (-0.35) < 0.65, "It reaches 80 %% within 0.65 s of first stirring: %.2f s" % (reached + 0.35))
	check(peak > 1.1, "Plants overshoot at the hit: peak %.2f" % peak)
	check(peak_at < 0.6, "The overshoot comes at the hit: %.2f s" % peak_at)
	var gone := INF
	for i in range(0, 2000):
		var tau := 1.0 + float(i) * 0.01
		if GustFronts.push(tau) < 0.3:
			gone = tau
			break
	check(gone > 2.5, "It lets go slowly, holding over 30 %% until %.1f s" % gone)
	check(gone - reached > 4.0 * (reached + 0.35), "Letting go takes far longer than the hit")

## Fronts come every so often, sooner in strong air, and at most two at once.
func _schedule() -> void:
	check(GustFronts.gap_for(0.4, 0.0) >= 8.0 and GustFronts.gap_for(0.4, 1.0) <= 32.0, "Default air sends one every 8 to 32 s: %.1f..%.1f" % [GustFronts.gap_for(0.4, 0.0), GustFronts.gap_for(0.4, 1.0)])
	check(GustFronts.gap_for(1.4, 0.5) < 0.6 * GustFronts.gap_for(0.15, 0.5), "A gale sends them far sooner than a calm")
	var f: RefCounted = GustFronts.new()
	f.rng.seed = 7
	var times: Array[float] = []
	var t := 0.0
	var last := 0
	var most := 0
	while t < 600.0:
		f.advance(0.1, Vector2.RIGHT, 0.4, 0.53)
		t += 0.1
		if f.sent > last:
			times.append(t)
			last = f.sent
		var running := 0
		for slot: Dictionary in f.fronts:
			if not slot.is_empty(): running += 1
		most = maxi(most, running)
	check(times.size() >= 18 and times.size() <= 60, "Ten minutes of default air sends 18 to 60 fronts: %d" % times.size())
	check(times[0] < 12.0, "The first comes soon after a world opens: %.1f s" % times[0])
	check(most <= GustFronts.SLOTS, "Never more than %d at once" % GustFronts.SLOTS)

## A front rolls downwind: upwind ground feels it first, ground beyond its
## width not at all, and its strength is patchy across it.
func _travel() -> void:
	var f: RefCounted = GustFronts.new()
	f.rng.seed = 3
	f.set_bounds(Vector2.ZERO, 20.0)
	var front: Dictionary = f.send(Vector2.RIGHT, 0.4, 0.53, 1.0)
	front.half = 30.0
	var up := _arrival(front, Vector2(-10.0, 0.0))
	var down := _arrival(front, Vector2(10.0, 0.0))
	check(up < down, "Upwind ground feels it first: %.1f s, then %.1f s" % [up, down])
	var speed := float(front.speed)
	check(absf((down - up) - 20.0 / speed) < 0.6, "It runs at its own pace: %.1f s for 20 m at %.1f m/s" % [down - up, speed])
	front.half = 8.0
	front.age = 20.0 / speed + 1.0
	check(GustFronts.front_lean(front, Vector2(20.0, 20.0)) == 0.0, "Ground beyond its width stays still")
	# Across many fronts most are patchy (some come even, as real ones do),
	# and their lines are ragged.
	var patchy := 0
	var ragged := 0
	for n in range(8):
		f.fronts[0] = {}
		f.rng.seed = 100 + n
		front = f.send(Vector2.RIGHT, 0.4, 0.53, 1.0)
		front.half = 30.0
		var low := INF
		var high := 0.0
		var lines: Array[float] = []
		for i in range(-12, 13, 2):
			var p := Vector2(0.0, float(i))
			var best := 0.0
			for k in range(0, 200):
				front.age = float(k) * 0.075
				best = maxf(best, GustFronts.front_lean(front, p))
			low = minf(low, best)
			high = maxf(high, best)
			lines.append(_arrival(front, p))
		check(high <= 1.4 * float(front.peak) + 0.001, "The lean never runs past its peak and overshoot")
		if high > 1.6 * low: patchy += 1
		if lines.max() - lines.min() > 0.3: ragged += 1
	check(patchy >= 5, "Most fronts are patchy across: %d of 8" % patchy)
	check(ragged >= 6, "Fronts arrive along a ragged line: %d of 8" % ragged)

func _arrival(front: Dictionary, p: Vector2) -> float:
	for k in range(0, 2000):
		front.age = float(k) * 0.02
		if GustFronts.front_lean(front, p) > 0.05 * float(front.peak): return front.age
	return INF

## The breeze goes quiet before a front comes, and is back after.
func _lull() -> void:
	var f: RefCounted = GustFronts.new()
	f.set_bounds(Vector2.ZERO, 20.0)
	check(is_equal_approx(f.lull(), 1.0), "No front, no lull")
	var front: Dictionary = f.send(Vector2.RIGHT, 0.4, 0.53, 1.0)
	var middle := 26.0 / float(front.speed)
	front.age = middle - 6.0
	var early: float = f.lull()
	front.age = middle - 1.0
	var quiet: float = f.lull()
	front.age = middle + 4.0
	var after: float = f.lull()
	check(early > 0.95, "Well before, the breeze is whole: %.2f" % early)
	check(quiet < 0.85, "Just before, it goes quiet: %.2f" % quiet)
	check(after > 0.95, "After, it is back: %.2f" % after)

## The atmosphere ages fronts on its wind clock: paused, they hold; the
## same air at 60 and 5 fps gives the same fronts.
func _atmosphere() -> void:
	var states: Array = []
	for fps in [60.0, 5.0]:
		var air: Node3D = Atmosphere.new()
		air.fronts.rng.seed = 11
		air.fronts._wait = 2.0
		for i in range(int(12.0 * fps)): air.advance(1.0 / fps, false)
		var front: Dictionary = air.fronts.fronts[0]
		check(not front.is_empty(), "The atmosphere sends a front on its own at %d fps" % fps)
		var age := float(front.get("age", 0.0))
		for i in range(30): air.advance(1.0 / fps, true)
		check(is_equal_approx(float(front.get("age", 0.0)), age), "A paused world holds its front")
		states.append(age)
		air.free()
	check(absf(float(states[0]) - float(states[1])) < 0.001, "60 and 5 fps age it alike: %.2f / %.2f" % states)

func _shaders() -> void:
	var wind := FileAccess.get_file_as_string("res://shaders/reference_wind.gdshaderinc")
	check(wind.contains("float zs_front_at(") and wind.contains("float zs_front_push("), "The shared include has the front hooks")
	var lean := wind.substr(wind.find("float zs_breeze_lean_wave("), 900)
	check(lean.contains("zs_front_at(root, lag)"), "Every plant's breeze lean takes the fronts")
	var globals := FileAccess.get_file_as_string("res://shaders/reference_globals.gdshaderinc")
	for i in range(GustFronts.SLOTS):
		for part in ["a", "b"]:
			var name := "zs_front_%d_%s" % [i, part]
			check(globals.contains("global uniform vec4 %s;" % name), "%s is declared" % name)
			check(ProjectSettings.has_setting("shader_globals/" + name), "%s is registered" % name)
	# Locals in the include clash with same-named uniforms in user shaders.
	var body := wind.substr(wind.find("float zs_front_push("), wind.find("float zs_front_at(") - wind.find("float zs_front_push("))
	var bare := RegEx.create_from_string("\\bfloat (?!fr_)[a-z]+ =")
	check(bare.search(body) == null, "Front locals are prefixed fr_")

func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL: ", what)
