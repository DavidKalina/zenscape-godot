extends SceneTree
const Plate = preload("res://scripts/plate.gd")
## Breeze ribbons (scripts/breeze_ribbons.gd, docs/scenic/breeze-ribbons.md):
## strokes ride the air downwind as one continuous path, climb over ground
## ahead, swell and sink, curl through eddies, sweep low and lift off, come in with gust fronts,
## leave at the plate's edge, and run the same at any frame rate. Headless:
## the stroke's look is GPU work.
const Ribbons = preload("res://scripts/breeze_ribbons.gd")
const GustFronts = preload("res://studies/gust_fronts.gd")
var failures := 0

func _initialize() -> void:
	_rides_the_air()
	_eddies()
	_over_woods()
	_fronts()
	_sweeps()
	_sweep_rules()
	_frame_rate()
	print("PASS: breeze ribbons" if failures == 0 else "FAIL: breeze ribbons")
	quit(1 if failures else 0)

## A plate 28 m across with a 3 m hill at x = 4.
static func _ground(p: Vector2) -> Variant:
	if absf(p.x) > Plate.HALF or absf(p.y) > Plate.HALF: return null
	return 3.0 * exp(-pow(p.x - 4.0, 2.0) / 8.0)

func _make() -> Node3D:
	var r: Node3D = Ribbons.new()
	root.add_child(r)
	r.setup(_ground)
	r.set_bounds(Vector2.ZERO, Plate.HALF)
	r._rng.seed = 21
	r._until_lone = INF
	return r

func _rides_the_air() -> void:
	var r := _make()
	r._birth(Vector2(-12.0, 0.0), Vector2.RIGHT, 5.0, 1.0)
	var ribbon: Dictionary = r.ribbons[0]
	ribbon.eddy = {}
	var start: Vector3 = ribbon.pos
	var over_hill := -INF
	var on_flat := INF
	var jump := 0.0
	var last: Vector3 = start
	for i in range(240):
		r._rng.seed = 1000 + i # no eddies here: EDDY_RATE draws stay high
		ribbon.eddy = {}
		r.advance(1.0 / 60.0, 0.4, 0.0)
		if r.ribbons.is_empty(): break
		var p: Vector3 = ribbon.pos
		jump = maxf(jump, p.distance_to(last))
		last = p
		var lift := p.y - float(_ground(Vector2(p.x, p.z)) if _ground(Vector2(p.x, p.z)) != null else 0.0)
		if absf(p.x - 4.0) < 0.5: over_hill = maxf(over_hill, p.y)
		if p.x < -6.0: on_flat = minf(on_flat, p.y)
	check(last.x - start.x > 12.0, "It travels downwind: %.1f m in 4 s" % (last.x - start.x))
	check(over_hill > 3.0, "It rises over the hill: %.2f m at the crest" % over_hill)
	check(jump < 0.2, "Its path is continuous: largest step %.3f m" % jump)
	var path: PackedVector3Array = ribbon.path
	check(path.size() > 30, "It keeps a long tail: %d samples" % path.size())
	var length := 0.0
	for i in range(1, path.size()): length += path[i].distance_to(path[i - 1])
	check(length > 6.0, "Its stroke is long: %.1f m" % length)
	var ys: Array[float] = []
	for p in path: ys.append(p.y)
	check(ys.max() - ys.min() > 0.4, "It rises and falls along its length: %.2f m" % (ys.max() - ys.min()))
	r.free()

func _eddies() -> void:
	var r := _make()
	r._birth(Vector2(-12.0, 0.0), Vector2.RIGHT, 5.0, 1.0)
	var ribbon: Dictionary = r.ribbons[0]
	ribbon.age = 2.0
	ribbon.eddy = {"t": 0.0, "span": 1.4, "spin": 1.0, "axis": Vector3.RIGHT.cross(Vector3.UP)}
	var went_back := false
	var went_up := 0.0
	var y0: float = (ribbon.pos as Vector3).y
	for i in range(84):
		r.advance(1.0 / 60.0, 0.4, 0.0)
		if (ribbon.vel as Vector3).x < 0.0: went_back = true
		went_up = maxf(went_up, (ribbon.pos as Vector3).y - y0)
	check(went_back, "An eddy turns it back on itself: a loop")
	check(went_up > 0.5, "A loop lifts it: %.2f m" % went_up)
	r.free()

## A wood (tree shade) between x = -4 and 0 lifts the ribbon over it, and it
## settles again beyond.
func _over_woods() -> void:
	var r := _make()
	r.set_canopy(func(p: Vector2) -> float: return 0.6 if p.x > -4.0 and p.x < 0.0 else 0.0)
	r._birth(Vector2(-12.0, 0.0), Vector2.RIGHT, 5.0, 1.0)
	var ribbon: Dictionary = r.ribbons[0]
	var over := INF
	for i in range(150):
		ribbon.eddy = {}
		r.advance(1.0 / 60.0, 0.4, 0.0)
		var p: Vector3 = ribbon.pos
		if p.x > -4.0 and p.x < 0.0: over = minf(over, p.y)
	check(over > 7.0, "It clears the wood's crowns: at least %.1f m over it" % over)
	r.publish()
	var head: Vector4 = r.heads[0]
	check(Vector2(head.z, head.w).length() > 0.1, "Its head is published to bow the plants under it")
	r.free()

func _fronts() -> void:
	var r := _make()
	var f: RefCounted = GustFronts.new()
	f.set_bounds(Vector2.ZERO, Plate.HALF)
	var front: Dictionary = f.send(Vector2.RIGHT, 0.4, 0.53, 1.0)
	r.carry_front(front)
	check(r._pending.size() >= GustFronts.SLOTS, "A front brings several ribbons: %d" % r._pending.size())
	var first := INF
	# Ten seconds saw a front across the 28 m plate; as long again per metre now.
	for i in range(ceili(600 * Plate.HALF / Plate.LEGACY_HALF)):
		r.advance(1.0 / 60.0, 0.4, 0.0)
		if not r.ribbons.is_empty() and first == INF: first = float(i) / 60.0
	var due := (Plate.HALF * (1.0 - Ribbons.JOIN) + GustFronts.LEAD_IN) / float(front.speed)
	check(absf(first - due) < 0.8, "They join it where it enters the plate: at %.1f s, due %.1f s" % [first, due])
	check(r.ribbons.is_empty(), "They leave at the plate's edge")
	r.free()

## A forced sweep over flat ground: it descends to skim just above it, rises
## well above its ride as it lifts off, and settles back; it kicks only while
## low or lifting, and the air it throws up is local.
func _sweeps() -> void:
	var r := _make()
	var flat := func(p: Vector2) -> Variant: return null if absf(p.x) > 40.0 or absf(p.y) > 40.0 else 0.0
	r.ground_height = flat
	r.set_bounds(Vector2.ZERO, 40.0)
	r._birth(Vector2(-30.0, 0.0), Vector2.RIGHT, 5.0, 1.0)
	var ribbon: Dictionary = r.ribbons[0]
	ribbon.age = 2.0
	check(r.air_at(Vector3(-30.0, 0.3, 0.0)) == Vector3.ZERO and r.kicks().is_empty(), "No sweep: no kicks and no air")
	check(r.start_sweep(ribbon), "A sweep starts on open ground")
	check(not r.start_sweep(ribbon), "It does not start a second while sweeping")
	var sweep: Dictionary = ribbon.sweep
	var begins: float = float(sweep.descend) + float(sweep.skim)
	var total: float = begins + float(sweep.lift)
	var low := INF
	var skim_min := INF
	var skim_max := -INF
	var kicked_skim := true
	var kicked_after := false
	var peak := -INF
	var peak_air := Vector3.ZERO
	var far_air := Vector3.ZERO
	var near_air := Vector3.ZERO
	var jump := 0.0
	var last: Vector3 = ribbon.pos
	var t := 0.0
	for i in range(int((total + 6.0) * 60.0)):
		r.advance(1.0 / 60.0, 0.4, 0.0)
		t += 1.0 / 60.0
		var p: Vector3 = ribbon.pos
		jump = maxf(jump, p.distance_to(last))
		last = p
		var swept: bool = not (ribbon.sweep as Dictionary).is_empty()
		if swept and t > float(sweep.descend) + 0.6 and t < begins:
			skim_min = minf(skim_min, p.y)
			skim_max = maxf(skim_max, p.y)
			kicked_skim = kicked_skim and r.kicks().size() == 1
		if not swept and t > total + 0.1 and not r.kicks().is_empty(): kicked_after = true
		if swept and t > begins:
			peak = maxf(peak, p.y)
			var air: Vector3 = r.air_at(p - Vector3(0.0, p.y, 0.0) + Vector3(0.0, 0.3, 0.0))
			if air.y > peak_air.y: peak_air = air
		if swept and t < begins:
			far_air += r.air_at(p + Vector3(0.0, 0.3, 4.0))
			if t > float(sweep.descend) + 0.6: near_air = near_air.max(r.air_at(Vector3(p.x - 0.5, 0.2, p.z)).abs())
	check(skim_min >= 0.15 and skim_max <= 0.45, "It skims %.2f to %.2f m over flat ground" % [skim_min, skim_max])
	check(kicked_skim, "It kicks while it skims")
	check(not kicked_after and r.kicks().is_empty(), "No kicks once the sweep is done")
	check(peak > 3.0, "It lifts well above its ride: %.1f m" % peak)
	check(peak_air.y > 1.0, "Lifting, it throws the air up under the head: %.1f m/s" % peak_air.y)
	check(far_air == Vector3.ZERO, "Its air does not reach 4 m aside")
	check(near_air.x > 2.0 and near_air.y < 0.1, "Skimming, it drags the air along its track without lifting it: %.1f m/s" % near_air.x)
	check(jump < 0.2, "Its path stays continuous: largest step %.3f m" % jump)
	check((ribbon.sweep as Dictionary).is_empty(), "The sweep ends")
	# Back to its ride: well under the lift's peak height 5 s on.
	check((ribbon.pos as Vector3).y < peak - 0.5 or r.ribbons.is_empty(), "It settles back toward its ride")
	r.enabled = false
	check(r.kicks().is_empty(), "Disabled, nothing kicks")
	r.free()

## Sweeps keep to open ground, away from eddies, and over a slope stay above it.
func _sweep_rules() -> void:
	var r := _make()
	r.set_canopy(func(_p: Vector2) -> float: return 0.6)
	r._birth(Vector2(-12.0, 0.0), Vector2.RIGHT, 5.0, 1.0, 0.1)
	var ribbon: Dictionary = r.ribbons[0]
	ribbon.age = 2.0
	check(not r.start_sweep(ribbon), "No sweep under a canopy")
	for i in range(120): r.advance(1.0 / 60.0, 0.4, 0.0)
	check(r.kicks().is_empty() and r.ribbons.size() > 0 and (r.ribbons[0].sweep as Dictionary).is_empty(), "A ribbon given a sweep under trees never takes it")
	r.free()
	r = _make()
	r._birth(Vector2(-12.0, 0.0), Vector2.RIGHT, 5.0, 1.0)
	ribbon = r.ribbons[0]
	ribbon.eddy = {"t": 0.0, "span": 1.4, "spin": 1.0, "axis": Vector3.RIGHT.cross(Vector3.UP)}
	check(not r.start_sweep(ribbon), "No sweep mid-eddy")
	ribbon.eddy = {}
	ribbon.dying = true
	check(not r.start_sweep(ribbon), "No sweep while dying")
	ribbon.dying = false
	r.sweep_gain = 0.0
	check(not r.start_sweep(ribbon), "Gain 0 turns sweeps off")
	r.sweep_gain = 1.0
	# Over the 3 m hill at x = 4, skimming.
	check(r.start_sweep(ribbon), "A sweep starts ahead of the hill")
	ribbon.sweep.descend = 0.8
	ribbon.sweep.skim = 4.0
	var under := INF
	for i in range(300):
		ribbon.eddy = {}
		r.advance(1.0 / 60.0, 0.4, 0.0)
		if r.ribbons.is_empty(): break
		var p: Vector3 = ribbon.pos
		var g: Variant = _ground(Vector2(p.x, p.z))
		if g != null: under = minf(under, p.y - float(g))
	check(under > 0.05, "A skim over the hill stays above the ground: %.2f m at its lowest" % under)
	r.free()
	# Between fronts a sweep arrives on its own now and then, over time.
	var count := 0
	for seed in range(20):
		r = _make()
		r._rng.seed = 300 + seed
		r._birth(Vector2(-12.0, 0.0), Vector2.LEFT, 0.5, 1.0)
		r.ribbons[0].speed = 0.1
		for i in range(600):
			r.advance(1.0 / 60.0, 0.4, 0.0)
			if r.ribbons.is_empty(): break
			if not (r.ribbons[0].sweep as Dictionary).is_empty():
				count += 1
				break
		r.free()
	check(count > 0, "Sweeps happen of themselves now and then: %d of 20 ribbons in 10 s" % count)

func _frame_rate() -> void:
	var ends: Array[Vector3] = []
	for fps in [60.0, 7.0]:
		var r := _make()
		r._birth(Vector2(-12.0, 0.0), Vector2.RIGHT, 5.0, 1.0)
		for i in range(int(2.0 * fps)): r.advance(1.0 / fps, 0.4, 0.0)
		ends.append(r.ribbons[0].pos)
		r.free()
	check(ends[0].distance_to(ends[1]) < 0.05, "60 and 7 fps carry it alike: %.3f m apart" % ends[0].distance_to(ends[1]))

func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL: ", what)
