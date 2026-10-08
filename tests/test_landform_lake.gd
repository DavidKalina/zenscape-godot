extends SceneTree
## suite: serial
## The lake landform (scripts/landform_lake.gd), the lower world's island
## holding an inland lake: it keeps the landforms' contract (NAME, ACROSS,
## `recipe`); over a few seeds and sizes across its range its recipe and
## islet are the same for the same draw; the water lies in its bowl, dry
## land all round its rim but the spill, where it pours off as a wide fall;
## the lake is a fair share of the land, shallow round a deep middle; a
## tarn steeps dark, a mere stays clear; the pilot's motor wades into it
## and swims its deep water, held to the surface over the bed; and the
## biggest builds in time (its triangles printed).
const Landform = preload("res://scripts/landform_lake.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const IsletLake = preload("res://scripts/islet_lake.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const SEEDS := [3,11,29,47]
const SIZES := [30.0,60.0,90.0]
## The biggest island's shape and arrays must build within this (ms,
## headless; on a worker in the game).
const BUDGET := 4000.0
var failures := 0

func _initialize() -> void:
	_contract()
	_same_draw()
	var islets := []
	for s: int in SEEDS:
		for across: float in SIZES: islets.append(_build(s,across))
	_bowls(islets)
	_shares(islets)
	_spills(islets)
	_tea()
	_swims(islets)
	_build_time()
	print("Landform lake: %d failures" % failures)
	quit(1 if failures > 0 else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _recipe(s: int, across: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return Landform.recipe(rng,across)

func _build(s: int, across: float) -> RefCounted:
	return SkyIslet.author(s*977+int(across),_recipe(s,across))

func _contract() -> void:
	check(Landform.NAME == "lake","Its name is lake")
	check(Landform.ACROSS is Vector2 and Landform.ACROSS.x >= 30.0 and Landform.ACROSS.y <= 90.0 and Landform.ACROSS.x < Landform.ACROSS.y,
		"It spans %s m across" % str(Landform.ACROSS))
	var spec := _recipe(5,60.0)
	check(spec.has("lake") and is_equal_approx(float(spec.radius),30.0),"Its recipe is a SkyIslet recipe with a lake, half as wide as asked")

func _same_draw() -> void:
	var a := _recipe(13,72.0)
	var b := _recipe(13,72.0)
	check(var_to_str(a) == var_to_str(b),"The same draw gives the same recipe")
	var one: RefCounted = SkyIslet.author(99,a)
	var two: RefCounted = SkyIslet.author(99,b)
	check(one.heights == two.heights and one.objects == two.objects and is_equal_approx(float(one.water_level),float(two.water_level)),
		"The same recipe and seed give the same island")

## The water in its bowl: every rim point stands over the water but where
## the spill's channel leaves, and the water's sheet lies at its level over
## wet ground only.
func _bowls(islets: Array) -> void:
	var leaks := []
	var sheets := true
	for islet: RefCounted in islets:
		var level: float = islet.water_level
		var channel: float = IsletLake._channel(islet)
		var edges: PackedInt32Array = islet.shore_edges
		for k in range(0,edges.size(),3):
			var p: Vector2 = islet.points[edges[k]]
			if islet._channel_distance(p) < channel*1.6: continue
			if float(islet.heights[edges[k]]) <= level+0.05:
				leaks.append("%s at %s" % [islet.recipe.flavour,str(p.snapped(Vector2.ONE*0.1))])
				break
		var arrays: Array = islet.water_arrays(Color.WHITE)
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			if not is_equal_approx(v.y,level): sheets = false
	check(leaks.is_empty(),"Dry rim all round each lake but its spill (%d islands%s)" % [islets.size(),"" if leaks.is_empty() else ", leaks: %s" % str(leaks)])
	check(sheets,"Each lake's sheet lies at its level")

## The lake a fair share of the land, shallow shelves round deep water.
func _shares(islets: Array) -> void:
	var least := 1.0
	var most := 0.0
	var shelved := true
	for islet: RefCounted in islets:
		var share: float = float(islet.lake.area)/islet.land_area()
		least = minf(least,share)
		most = maxf(most,share)
		var shallow := 0
		var deep := 0
		for i in range(islet.points.size()):
			if islet.shore_distance[i] < 0.0: continue
			var under: float = float(islet.water_level)-float(islet.heights[i])
			if under > 0.05 and under < 0.4: shallow += 1
			if under > 1.5: deep += 1
		if shallow < 20 or deep < 20: shelved = false
	check(least > 0.3 and most < 0.75,"The lake is a fair share of each island (%.0f%% to %.0f%%)" % [least*100.0,most*100.0])
	check(shelved,"Shallow shelves round deep water in every lake")

## Every lake spills off its rim as a fall wider than the lake motif's.
func _spills(islets: Array) -> void:
	var ok := true
	var widths := []
	for islet: RefCounted in islets:
		var w: Dictionary = islet.water()
		widths.append(snappedf(float(w.get("half",0.0))*2.0,0.1))
		var inside: Vector2 = (islet.lip as Vector2)-(islet.lip_out as Vector2)*0.4
		if not islet.lake.spilled or not islet.wet(inside) or float(w.get("half",0.0)) <= IsletLake.FALL_HALF: ok = false
	check(ok,"Each lake spills off its rim as a wide fall (%s m)" % str(widths))

## A tarn steeps dark by what grows round it, never past its cap; a mere
## and an isle lake stay clear.
func _tea() -> void:
	var tarns := []
	var clear := true
	for s in range(40):
		var spec := _recipe(500+s,50.0)
		if spec.flavour != "tarn" and tarns.size() < 1 and s < 39: continue
		var islet: RefCounted = SkyIslet.author(700+s,spec)
		if spec.flavour == "tarn": tarns.append(float(islet.lake.get("tea",0.0)))
		elif islet.lake.has("tea"): clear = false
		if tarns.size() >= 2: break
	check(not tarns.is_empty() and tarns.all(func(t: float) -> bool: return t > 0.2 and t <= Landform.TEA+0.001),"A tarn steeps dark (%s)" % str(tarns))
	check(clear,"A mere stays clear")

## The pilot's motor (scripts/pilot_motor.gd), walked from the bank toward
## deep water as the wanderer walks it on an islet (WandererEye
## `_advance_perch`, its water SkyIslet `swim_depth`): it wades, slowed,
## then swims, its feet SWIM_DRAFT under the surface and never under the
## bed; the walker isn't blocked by the water.
func _swims(islets: Array) -> void:
	var tried := 0
	var waded := 0
	var swam := 0
	var afloat := true
	var open := true
	for islet: RefCounted in islets:
		if tried >= 6: break
		var deep := _deep_point(islet)
		if deep == Vector2.INF: continue
		if SkyIslets.blocked(islet,deep): open = false
		# Out from the deep water to the first dry ground, then a metre on.
		var way := Vector2.from_angle(float(tried)*1.3)
		var start := Vector2.INF
		for k in range(1,200):
			var p := deep+way*k*0.25
			if not islet.inside(p): break
			if float(islet.swim_depth(p)) <= 0.0 and not islet.wet(p):
				start = p+way*1.0
				break
		if start == Vector2.INF or not islet.inside(start) or SkyIslets.blocked(islet,start): continue
		tried += 1
		var motor := PilotMotor.new()
		motor.water = func(p: Vector2) -> float: return float(islet.swim_depth(p))
		var ground := func(p: Vector2) -> float: return float(islet.ground_at(p)) if islet.inside(p) else -INF
		var slide := func(feet: Vector3, step: Vector2) -> Vector3:
			var next := Vector2(feet.x,feet.z)+step
			if SkyIslets.blocked(islet,next): next = Vector2(feet.x,feet.z)
			return Vector3(next.x,feet.y,next.y)
		motor.reset(Vector3(start.x,float(islet.ground_at(start)),start.y),0.0)
		var did_wade := false
		var did_swim := false
		for frame in range(60*20):
			var to := deep-Vector2(motor.feet.x,motor.feet.z)
			if to.length() < 0.4: break
			motor.step(1.0/60.0,to.normalized(),PilotMotor.WALK,false,ground,slide)
			if motor.grounded and motor.wade > PilotMotor.WADE_FROM: did_wade = true
			if motor.swimming:
				did_swim = true
				var at := Vector2(motor.feet.x,motor.feet.z)
				var bed := float(islet.ground_at(at))
				if motor.feet.y < bed-0.01: afloat = false
				if frame % 30 == 0 and motor.feet.y > float(islet.water_level)-PilotMotor.SWIM_DRAFT*0.4: afloat = false
		if did_wade: waded += 1
		if did_swim: swam += 1
	check(open,"The walker isn't blocked by a lake's water")
	check(tried >= 4 and waded == tried,"Walked in from the bank, the pilot wades (%d of %d)" % [waded,tried])
	check(swam == tried,"And swims its deep water (%d of %d)" % [swam,tried])
	check(afloat,"Swimming, he floats under the surface and never under the bed")

## A point of the lake at least two metres deep, well in from its edge.
func _deep_point(islet: RefCounted) -> Vector2:
	var best := Vector2.INF
	var deepest := 0.0
	for i in range(0,islet.points.size(),3):
		var p: Vector2 = islet.points[i]
		var d := float(islet.swim_depth(p))
		if d > deepest and d > 2.0 and IsletLake.distance(islet,p+Vector2(1.5,0.0)) == 0.0 and IsletLake.distance(islet,p-Vector2(1.5,0.0)) == 0.0:
			deepest = d
			best = p
			if d > 2.4: break
	return best

func _build_time() -> void:
	var spec := _recipe(21,90.0)
	var began := Time.get_ticks_usec()
	var islet: RefCounted = SkyIslet.author(4321,spec)
	var shaped := (Time.get_ticks_usec()-began)/1000.0
	var top: Array = islet.top_arrays(SkyIslet.plain_palette())
	var sides: Array = islet.side_arrays()
	var water: Array = islet.water_arrays()
	var ms := (Time.get_ticks_usec()-began)/1000.0
	var count := func(a: Array) -> int: return (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3 if not a.is_empty() else 0
	print("     90 m %s: shape %.0f ms, with arrays %.0f ms; triangles top %d, sides %d, water %d; %d objects" % [
		spec.flavour,shaped,ms,count.call(top),count.call(sides),count.call(water),islet.objects.size()])
	check(ms < BUDGET,"The biggest lake island builds within %.0f ms (%.0f ms)" % [BUDGET,ms])
