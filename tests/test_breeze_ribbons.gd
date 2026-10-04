extends SceneTree
## Breeze ribbons (scripts/breeze_ribbons.gd, docs/scenic/breeze-ribbons.md):
## strokes ride the air downwind as one continuous path, climb over ground
## ahead, swell and sink, curl through eddies, come in with gust fronts,
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
	_frame_rate()
	print("PASS: breeze ribbons" if failures == 0 else "FAIL: breeze ribbons")
	quit(1 if failures else 0)

## A plate 28 m across with a 3 m hill at x = 4.
static func _ground(p: Vector2) -> Variant:
	if absf(p.x) > 14.0 or absf(p.y) > 14.0: return null
	return 3.0 * exp(-pow(p.x - 4.0, 2.0) / 8.0)

func _make() -> Node3D:
	var r: Node3D = Ribbons.new()
	root.add_child(r)
	r.setup(_ground)
	r.set_bounds(Vector2.ZERO, 14.0)
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
	f.set_bounds(Vector2.ZERO, 14.0)
	var front: Dictionary = f.send(Vector2.RIGHT, 0.4, 0.53, 1.0)
	r.carry_front(front)
	check(r._pending.size() >= GustFronts.SLOTS, "A front brings several ribbons: %d" % r._pending.size())
	var first := INF
	for i in range(600):
		r.advance(1.0 / 60.0, 0.4, 0.0)
		if not r.ribbons.is_empty() and first == INF: first = float(i) / 60.0
	var due := (14.0 * (1.0 - Ribbons.JOIN) + GustFronts.LEAD_IN) / float(front.speed)
	check(absf(first - due) < 0.8, "They join it where it enters the plate: at %.1f s, due %.1f s" % [first, due])
	check(r.ribbons.is_empty(), "They leave at the plate's edge")
	r.free()

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
