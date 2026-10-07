extends SceneTree
## The showcase cluster (scripts/sky_showcase.gd, --showcase): its members
## are authored islets (scripts/sky_islet.gd `author`) standing fixed in
## the islets' own records, never let go, the seeded islets kept off them.
## The lead is a farm islet (cabin, lamps, wheat, a pond that falls off the
## rim), the forest a real wood; the stepping stones down to the dock are a
## running jump apart and a jump's height apart; the footbridge and the
## dock are decks the pilot walks; at night the lights come on and the
## lighthouse's beams sweep.
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyShowcase = preload("res://scripts/sky_showcase.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _run() -> void:
	var cells := SkyCells.new([Vector3.ZERO,Vector3(380.0,-20.0,-160.0)])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var show: Node3D = SkyShowcase.new()
	show.islets = islets
	root.add_child(show)
	var began := Time.get_ticks_usec()
	show.build()
	show.flush()
	print("showcase made and stood in %.0f ms" % ((Time.get_ticks_usec()-began)/1000.0))
	var names: Array = SkyShowcase.members().map(func(m: Dictionary) -> String: return m.name)
	var all := true
	for n: String in names:
		if not show.built.has(n) or not islets.built.has("show:"+n): all = false
	check(all,"Every member stands in the islets' records (%d)" % names.size())
	for n: String in names:
		var shape: RefCounted = show.built[n].shape
		var box: Rect2 = shape.extent()
		print("  %-7s %-6s across %4.1f m, land %5.0f m², %3d trees, %4d records" % [n,shape.kind,maxf(box.size.x,box.size.y),shape.land_area(),_trees(shape),shape.objects.size()])
	var lead: RefCounted = show.built.lead.shape
	var lead_box: Rect2 = lead.extent()
	check(maxf(lead_box.size.x,lead_box.size.y) > 32.0,"The lead is far bigger than a seeded islet")
	check(_count(lead,"cabin") == 1 and _count(lead,"stone_lamp") >= 2 and _count(lead,"wheat") > 300,"The lead holds the cabin, lamps and a wheat field")
	check(not lead.water().is_empty(),"The lead has its pond, falling off the rim")
	check((show.built.lead.node as Node3D).get_node_or_null("Fall") != null,"Its fall pours")
	check(_trees(show.built.forest.shape) >= 25,"The forest is a wood (%d trees)" % _trees(show.built.forest.shape))
	# The route: each stone a running jump on from the one before, rim to rim,
	# and never more than a jump's height up coming back.
	var route := ["lead","stone0","stone1","stone2","dock"]
	var gaps_ok := true
	var rises_ok := true
	for k in range(route.size()-1):
		var a: Dictionary = show.built[route[k]]
		var b: Dictionary = show.built[route[k+1]]
		var gap := _gap(islets,a,b)
		var rise: float = (islets.place(a)-islets.place(b)).y
		print("  %s -> %s: gap %.2f m, %.2f m down" % [route[k],route[k+1],gap,rise])
		if gap > 2.2 or gap < 0.6: gaps_ok = false
		if rise > PilotMotor.JUMPS[1]: rises_ok = false
	check(gaps_ok,"The stepping stones are a running jump apart (0.6 to 2.2 m rim to rim)")
	check(rises_ok,"Coming back, each step up is within a jump")
	# The bridge's deck carries on from the lead to the forest.
	var deck: Dictionary = lead.decks[0]
	var a3: Vector3 = deck.a
	var b3: Vector3 = deck.b
	var walk := true
	for i in range(21):
		var p := Vector2(a3.x,a3.z).lerp(Vector2(b3.x,b3.z),i/20.0)
		if not lead.inside(p): walk = false
	check(walk,"The footbridge is walked as the lead's deck")
	var forest_off: Vector3 = islets.place(show.built.forest)-islets.place(show.built.lead)
	var far_end := Vector2(b3.x-forest_off.x,b3.z-forest_off.z)
	check(show.built.forest.shape.inside(far_end),"Its far end is on the forest")
	check(absf(b3.y-(show.built.forest.shape.ground_at(far_end)+forest_off.y)) < 0.3,"And meets its ground")
	var dock: RefCounted = show.built.dock.shape
	var dd: Dictionary = dock.decks[0]
	var tip: Vector3 = dd.b
	check(dock.inside(Vector2(tip.x,tip.z)) and not dock.on_land(Vector2(tip.x,tip.z)),"The dock reaches out past the rim, walkable")
	var on_dock: Vector3 = (dd.a as Vector3).lerp(tip,0.9)
	check(islets.body(islets.place(show.built.dock)+on_dock+Vector3.UP*5.0) is Vector2,"The glide reads the dock as solid")
	# Never let go, and the seeded islets keep off.
	for i in range(120):
		islets.advance(1.0/60.0,Vector3(-2000.0,0.0,-2000.0))
		islets.flush()
	check(show.built.keys().all(func(n: String) -> bool: return islets.built.has("show:"+n)),"Far away, the members stay")
	for i in range(120):
		islets.advance(1.0/60.0,SkyShowcase.CENTRE)
		islets.flush()
	var near := false
	for key: String in islets.built:
		if key.begins_with("show:"): continue
		var home: Vector3 = islets.built[key].home
		if Vector2(home.x-SkyShowcase.CENTRE.x,home.z-SkyShowcase.CENTRE.z).length() < SkyShowcase.KEEP: near = true
	check(not near,"No seeded islet stands in the showcase's room")
	# Night: the lights and the beams.
	show.daylight_override = 0.0
	for i in range(240): await process_frame
	check(show.night > 0.9,"At night the showcase is lit (%.2f)" % show.night)
	var lights := 0
	for entry: Array in show._lights:
		if (entry[0] as OmniLight3D).visible: lights += 1
	check(lights >= 6,"Its lights are on (%d)" % lights)
	check(show._beams.visible,"The lighthouse's beams sweep")
	show.queue_free()
	islets.queue_free()
	await process_frame
	print("PASS: sky showcase" if failures == 0 else "FAIL: sky showcase")
	quit(1 if failures else 0)

func _count(shape: RefCounted, asset: String) -> int:
	return shape.objects.filter(func(o: Dictionary) -> bool: return o.asset == asset).size()

func _trees(shape: RefCounted) -> int:
	return shape.objects.filter(func(o: Dictionary) -> bool: return o.asset in ["tree","redwood","juniper","broadleaf","birch","willow","layered_tree"]).size()

## The narrowest rim-to-rim gap between two members, by sampling their rims.
func _gap(islets: Node3D, a: Dictionary, b: Dictionary) -> float:
	var off: Vector3 = islets.place(b)-islets.place(a)
	var rim_b := []
	for j in range(96): rim_b.append(b.shape.rim_point(TAU*j/96.0)+Vector2(off.x,off.z))
	var best := INF
	for i in range(96):
		var pa: Vector2 = a.shape.rim_point(TAU*i/96.0)
		for pb: Vector2 in rim_b: best = minf(best,pa.distance_to(pb))
	return best
