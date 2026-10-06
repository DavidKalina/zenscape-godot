extends SceneTree
## The other planes (scripts/sky_traffic.gd): a few biplanes, each in its
## own livery and never the wanderer's; hidden till the sky is shown. Their
## pilots are lively: their lines wander and turn, rise and fall; they lap
## the islands, fly through clouds and buzz islets; they barrel roll, loop
## and swoop; they bank the way they turn, cruise under the jet's speed,
## stay among the islands, keep clear over ground ahead, and ride the
## currents when a swap moves them.
const SkyTraffic = preload("res://scripts/sky_traffic.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
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
	# A cloud always somewhat ahead of whoever asks.
	traffic.cloud_near = func(point: Vector3, _reach: float) -> Variant: return point
	traffic.build(currents,slots)
	check(traffic.planes.size() == SkyTraffic.COUNT,"%d planes" % traffic.planes.size())
	var liveries := {}
	for plane: Dictionary in traffic.planes: liveries[plane.figure.get_child(0).material_override.albedo_color] = true
	check(liveries.size() == traffic.planes.size() and not liveries.has(PlaneFigure.WOOD),"Each in its own livery, none the wanderer's brown")
	check(traffic.planes.all(func(p: Dictionary) -> bool: return not p.figure.visible),"Hidden till the sky is shown")
	traffic.show(true)
	check(traffic.planes.all(func(p: Dictionary) -> bool: return p.figure.visible),"Shown with the sky")
	_fly(traffic,slots)
	_over_ground(traffic)
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

## Flies them five minutes at 30 fps and watches how they fly.
func _fly(traffic: Node, slots: Array) -> void:
	var dt := 1.0/30.0
	var centre := Vector3.ZERO
	for s: Vector3 in slots: centre += s
	centre /= float(slots.size())
	var reach := 0.0
	for s: Vector3 in slots: reach = maxf(reach,Vector2(s.x-centre.x,s.z-centre.z).length())
	var fastest := 0.0
	var slowest := INF
	var steady := true
	var bank_right := 0
	var bank_wrong := 0
	var farthest := 0.0
	var turned := []
	var low := []
	var high := []
	var tricks := {}
	var goals := {}
	var last := []
	var headings := []
	for plane: Dictionary in traffic.planes:
		last.append(plane.flight.position)
		headings.append(plane.flight.heading)
		turned.append(0.0)
		low.append(INF)
		high.append(-INF)
	for frame in range(30*300):
		traffic._process(dt)
		for i in range(traffic.planes.size()):
			var plane: Dictionary = traffic.planes[i]
			var flight: RefCounted = plane.flight
			var p: Vector3 = flight.position
			var step := p.distance_to(last[i])/dt
			last[i] = p
			fastest = maxf(fastest,step)
			slowest = minf(slowest,step)
			if not (is_finite(p.x) and is_finite(p.y) and is_finite(flight.bank) and is_finite(flight.pitch)): steady = false
			farthest = maxf(farthest,Vector2(p.x-centre.x,p.z-centre.z).length())
			low[i] = minf(low[i],p.y)
			high[i] = maxf(high[i],p.y)
			goals[plane.goal.kind] = true
			if not plane.trick.is_empty(): tricks[plane.trick.kind] = true
			# Heading falling is a turn to the right: it banks right (positive).
			var turn := angle_difference(float(headings[i]),float(flight.heading))
			headings[i] = flight.heading
			if plane.trick.is_empty() or plane.trick.kind != "loop":
				turned[i] = float(turned[i])+absf(turn)
				if absf(turn) > 0.002 and absf(flight.bank) > 0.05:
					if signf(turn) == -signf(flight.bank): bank_right += 1
					else: bank_wrong += 1
	check(steady,"Every pose stays finite")
	check(fastest < SkyCurrents.JET and slowest > SkyTraffic.SPEED.x*0.5,"They cruise under the jet's speed (%.1f to %.1f m/s, the jet %.0f)" % [slowest,fastest,SkyCurrents.JET])
	check(bank_right > bank_wrong*9,"They bank into their turns (%d right, %d wrong)" % [bank_right,bank_wrong])
	var winding := 0
	var rising := 0
	for i in range(traffic.planes.size()):
		if float(turned[i]) > TAU*3.0: winding += 1
		if float(high[i])-float(low[i]) > 15.0: rising += 1
	check(winding == traffic.planes.size(),"Their lines turn and wind, never one straight beeline (%s rad turned each)" % str(turned.map(func(x: float) -> int: return int(x))))
	check(rising == traffic.planes.size(),"They rise and fall (%d of %d over 15 m)" % [rising,traffic.planes.size()])
	check(tricks.has("roll") and tricks.has("loop") and tricks.has("swoop"),"They show off: rolls, loops and swoops (%s)" % str(tricks.keys()))
	check(goals.has("lap") and goals.has("cloud") and goals.has("islet"),"They lap islands, fly through clouds and buzz islets (%s)" % str(goals.keys()))
	check(farthest < reach+300.0,"They stay among the islands (farthest %.0f m from the middle, the islands out to %.0f)" % [farthest,reach])

## Ground stood everywhere just under the first plane: it climbs to keep
## clear of it.
func _over_ground(traffic: Node) -> void:
	var plane: Dictionary = traffic.planes[0]
	var level: float = plane.flight.position.y+5.0
	traffic.ground = func(_p: Vector3) -> Variant: return level
	var dt := 1.0/30.0
	for frame in range(30*20): traffic._process(dt)
	var over: float = plane.flight.position.y-level
	check(over > SkyTraffic.CLEAR*0.8,"It climbs clear over ground (%.1f m over it)" % over)
	traffic.ground = Callable()
