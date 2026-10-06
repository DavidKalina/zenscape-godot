extends SceneTree
## The other planes (scripts/sky_traffic.gd): a few biplanes on every
## closed jet, each in its own livery and never the wanderer's; hidden till
## the sky is shown; they cruise slower than the jet, keep to a lane beside
## its core and clear of the islands, bank the way they turn, and ride the
## currents when a swap moves them; they climb over ground ahead.
const SkyTraffic = preload("res://scripts/sky_traffic.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
var failures := 0

func _initialize() -> void:
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var currents := SkyCurrents.new()
	root.add_child(currents)
	currents.build(slots)
	var traffic := SkyTraffic.new()
	root.add_child(traffic)
	traffic.build(currents)
	var jets := 0
	for current: Dictionary in currents.currents:
		if current.kind == "jet" and current.closed: jets += 1
	check(jets > 0 and traffic.planes.size() == jets*SkyTraffic.PER_LOOP,"%d planes on %d loops" % [traffic.planes.size(),jets])
	var liveries := {}
	for plane: Dictionary in traffic.planes: liveries[plane.figure.get_child(0).material_override.albedo_color] = true
	check(liveries.size() == traffic.planes.size() and not liveries.has(PlaneFigure.WOOD),"Each in its own livery, none the wanderer's brown")
	check(traffic.planes.all(func(p: Dictionary) -> bool: return not p.figure.visible),"Hidden till the sky is shown")
	traffic.show(true)
	check(traffic.planes.all(func(p: Dictionary) -> bool: return p.figure.visible),"Shown with the sky")
	_fly(traffic,currents,slots)
	_over_ground(traffic,currents)
	# A swap moves the currents: the planes go with them.
	var before: Vector3 = traffic.planes[0].flight.position
	var by := Vector3(120.0,-8.0,-60.0)
	currents.position += by
	traffic._process(0.0)
	var moved: Vector3 = traffic.planes[0].flight.position-before
	check(moved.distance_to(by) < 0.01,"They ride the currents through a swap (moved %s)" % str(moved))
	traffic.show(false)
	check(traffic.planes.all(func(p: Dictionary) -> bool: return not p.figure.visible),"Hidden again on landing")
	print("PASS: sky traffic" if failures == 0 else "FAIL: sky traffic")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## Flies them a few minutes at 30 fps and watches the lanes.
func _fly(traffic: Node, currents: Node3D, slots: Array) -> void:
	var dt := 1.0/30.0
	var fastest := 0.0
	var slowest := INF
	var lane_far := 0.0
	var lane_near := INF
	var islet_near := INF
	var bank_right := 0
	var bank_wrong := 0
	var steady := true
	var last := []
	var headings := []
	for plane: Dictionary in traffic.planes:
		last.append(plane.flight.position)
		headings.append(plane.flight.heading)
	for frame in range(30*240):
		traffic._process(dt)
		for i in range(traffic.planes.size()):
			var plane: Dictionary = traffic.planes[i]
			var flight: RefCounted = plane.flight
			var p: Vector3 = flight.position
			var step := p.distance_to(last[i])/dt
			last[i] = p
			fastest = maxf(fastest,step)
			slowest = minf(slowest,step)
			if not (is_finite(p.x) and is_finite(flight.bank) and is_finite(flight.pitch)): steady = false
			var loop: Dictionary = traffic._loops[plane.loop]
			var core := _nearest(loop.points,p-currents.position)
			lane_far = maxf(lane_far,core)
			lane_near = minf(lane_near,core)
			if frame%15 == 0: islet_near = minf(islet_near,_islet_gap(p-currents.position))
			# Heading falling is a turn to the right: it banks right (positive).
			var turn := angle_difference(float(headings[i]),float(flight.heading))
			headings[i] = flight.heading
			if absf(turn) > 0.002 and absf(flight.bank) > 0.05:
				if signf(turn) == -signf(flight.bank): bank_right += 1
				else: bank_wrong += 1
	check(steady,"Every pose stays finite")
	check(fastest < SkyCurrents.JET and slowest > SkyTraffic.SPEED.x*0.5,"They cruise under the jet's speed (%.1f to %.1f m/s, the jet %.0f)" % [slowest,fastest,SkyCurrents.JET])
	check(lane_near > 4.0 and lane_far < 14.0,"They keep a lane over the core, off the wanderer's line (%.1f to %.1f m out)" % [lane_near,lane_far])
	check(bank_right > bank_wrong*9,"They bank into their turns (%d right, %d wrong)" % [bank_right,bank_wrong])
	print("     nearest islet gap %.1f m (flat, from its middle)" % islet_near)

## A tall mound stood on the first plane's lane: it climbs to keep clear of
## it, and settles back once past.
func _over_ground(traffic: Node, currents: Node3D) -> void:
	var plane: Dictionary = traffic.planes[0]
	var top: Vector3 = traffic._lane(plane,float(plane.at)+150.0)
	var peak := top.y+12.0
	traffic.ground = func(p: Vector3) -> Variant:
		var d := Vector2(p.x-top.x,p.z-top.z).length()
		return peak-d*0.4 if d < 40.0 else null
	var lowest := INF
	var dt := 1.0/30.0
	for frame in range(30*40):
		traffic._process(dt)
		var p: Vector3 = plane.flight.position
		var under: Variant = traffic.ground.call(p)
		if under != null: lowest = minf(lowest,p.y-float(under))
	check(lowest > SkyTraffic.CLEAR*0.6,"It climbs over ground in its lane (lowest %.1f m over it)" % lowest)
	check(float(plane.lift) < 1.0,"And settles back once past (lift %.1f m)" % float(plane.lift))
	traffic.ground = Callable()

static func _nearest(points: PackedVector3Array, p: Vector3) -> float:
	var best := INF
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var ab := b-a
		var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
		best = minf(best,p.distance_to(a+ab*t))
	return best

## How near a point comes to an islet's middle, flat, when within 20 m of
## its height; INF otherwise.
static func _islet_gap(p: Vector3) -> float:
	var cell := Vector2i(floori(p.x/SkyIslets.CELL),floori(p.z/SkyIslets.CELL))
	var best := INF
	for dx in range(-1,2):
		for dz in range(-1,2):
			var home: Variant = SkyIslets.raw(cell+Vector2i(dx,dz))
			if home == null: continue
			var h: Vector3 = home
			if absf(p.y-h.y) > 20.0: continue
			best = minf(best,Vector2(p.x-h.x,p.z-h.z).length())
	return best
