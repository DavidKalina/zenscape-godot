extends SceneTree
## The pillar forest (scripts/sky_pillar.gd, scripts/sky_pillars.gd): a seed
## always raises the same forest; its pillars are many, slender and tall,
## their tops in the band over the islands, their feet under the cloud sea;
## every lane between two stands is at least LANE m clear across the
## glide's band; the thread's tight slot is open at glide height along its
## line, the bridge has air under it, and the thread's jet runs clear; the
## forest in sight of the plate is clear of the islands, their currents, the
## islets and the mountain range, and nothing turns up in it; its pillars
## are solids the glide is turned aside by and can come down onto; it is
## made and let go with the ranges, its jet and thermal with it; and the
## haze keeps it in sight. Headless: shapes and queries only, nothing drawn.
const SkyPillar = preload("res://scripts/sky_pillar.gd")
const SkyPillars = preload("res://scripts/sky_pillars.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SEEDS := [101,2024,77777]
var failures := 0
var shapes := {}

func _initialize() -> void:
	_same_seed()
	for s: int in [home_seed()]+SEEDS:
		_pillars(s)
		_lanes(s)
		_thread(s)
	_mesh()
	_clear_of_all()
	_streaming()
	_glide()
	print("PASS: sky pillars" if failures == 0 else "FAIL: sky pillars")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func shape(seed_value: int) -> RefCounted:
	if not shapes.has(seed_value): shapes[seed_value] = SkyPillar.make(seed_value)
	return shapes[seed_value]

func home_seed() -> int:
	return SkyPillars.seed_of(Vector2i.ZERO)

func _same_seed() -> void:
	var a: RefCounted = shape(home_seed())
	var b: RefCounted = SkyPillar.make(home_seed())
	var same: bool = a.pillars.size() == b.pillars.size() and a.trees == b.trees and a.wraps == b.wraps
	for i in range(mini(a.pillars.size(),b.pillars.size())):
		same = same and a.pillars[i].radii == b.pillars[i].radii and a.pillars[i].ys == b.pillars[i].ys
	check(same,"A seed raises the same forest")
	check(a.pillars[5].radii != shape(SEEDS[0]).pillars[5].radii,"Another seed raises another")

## Many slender pillars: tops in the band, the low meadow apart; 15 to 45 m
## across; their faces running on down under the cloud sea.
func _pillars(s: int) -> void:
	var forest: RefCounted = shape(s)
	var count: int = forest.pillars.size()
	check(count >= 12 and count <= 30,"Seed %d: %d pillars" % [s,count])
	var worst := ""
	var low := 0
	var leaning := 0
	var fins := 0
	for i in range(count):
		var p: Dictionary = forest.pillars[i]
		# The slot's fins are long walls: their narrow way counts.
		var across := float(p.b)*2.0 if p.role == "slot" else float(p.a)+float(p.b)
		if i != forest.meadow and (float(p.top) < 60.0 or float(p.top) > 250.0): worst = "pillar %d top %.0f m" % [i,p.top]
		if across < 15.0 or across > 45.0: worst = "pillar %d %.0f m across" % [i,across]
		var ring: PackedVector2Array = forest.outline(i,SkyPillar.THREAD_Y if float(p.top) > 10.0 else float(p.top)-2.0)
		var mean := 0.0
		var c: Vector2 = forest.axis(p,SkyPillar.THREAD_Y)
		for v in ring: mean += v.distance_to(c)*2.0/ring.size()
		# Measured, the grooves and the taper aside.
		if mean < 14.0 or mean > 50.0: worst = "pillar %d measures %.0f m across" % [i,mean]
		if (p.ys as PackedFloat32Array)[0] > SkyPillar.SEA-20.0: worst = "pillar %d's foot at %.0f m" % [i,(p.ys as PackedFloat32Array)[0]]
		if float(p.top) < SkyPillar.GLIDE_BAND.y: low += 1
		if (p.lean as Vector2).length() > 0.02: leaning += 1
		if p.role == "fin": fins += 1
	check(worst == "","Seed %d: tops 60 to 250 m over the islands, 15 to 45 m across, feet under the sea %s" % [s,worst])
	var meadow: Dictionary = forest.pillars[forest.meadow]
	check(float(meadow.top) < SkyPillar.THREAD_Y-15.0 and float(meadow.top) > SkyPillar.GLIDE_BAND.x,"Seed %d: the meadow's top lies under the thread, over the glide's floor (%.0f m)" % [s,meadow.top])
	check(low >= 2 and leaning >= 3 and fins >= 2,"Seed %d: some tops low enough to reach (%d), some leaning (%d), some fins (%d)" % [s,low,leaning,fins])
	check(forest.top > 200.0,"Seed %d: the tallest stands %.0f m over the islands" % [s,forest.top])

## Every two pillars of different stands, the slot's two apart, at least
## LANE m apart wherever both stand in the glide's band.
func _lanes(s: int) -> void:
	var forest: RefCounted = shape(s)
	var narrowest := INF
	var which := ""
	for i in range(forest.pillars.size()):
		for j in range(i+1,forest.pillars.size()):
			var p: Dictionary = forest.pillars[i]
			var q: Dictionary = forest.pillars[j]
			if p.group == q.group or (p.role == "slot" and q.role == "slot"): continue
			var y := SkyPillar.GLIDE_BAND.x
			while y <= SkyPillar.GLIDE_BAND.y:
				if y <= float(p.top) and y <= float(q.top):
					var apart := (forest.axis(p,y) as Vector2).distance_to(forest.axis(q,y))-float(p.bound)-float(q.bound)
					if apart < SkyPillar.LANE+5.0:
						var d := _apart(forest.outline(i,y),forest.outline(j,y))
						if d < narrowest:
							narrowest = d
							which = "%d-%d at %.0f m" % [i,j,y]
				y += 10.0
	check(narrowest >= SkyPillar.LANE,"Seed %d: every lane between stands is at least %.0f m clear across the band (narrowest %.1f m, %s)" % [s,SkyPillar.LANE,narrowest,which])

## The least distance between two outlines (vertex to edge, both ways).
func _apart(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var best := INF
	for pass_ in range(2):
		var from := a if pass_ == 0 else b
		var to := b if pass_ == 0 else a
		for v in from:
			for k in range(to.size()):
				var e0 := to[k]
				var e1 := to[(k+1) % to.size()]
				var e := e1-e0
				var t := clampf((v-e0).dot(e)/maxf(e.length_squared(),1e-6),0.0,1.0)
				best = minf(best,v.distance_to(e0+e*t))
	return best

## The thread: the slot is 12 to 18 m wide and open its whole length at
## glide height (5 m either side of its line); the bridge has rock over the
## thread and air under it down to the glide's floor; the jet's line is
## open all the way.
func _thread(s: int) -> void:
	var forest: RefCounted = shape(s)
	var a: Dictionary = forest.pillars[forest.slot.a]
	var b: Dictionary = forest.pillars[forest.slot.b]
	var narrowest := INF
	var widest := 0.0
	var y := -40.0
	while y <= 80.0:
		var d := _apart(forest.outline(forest.slot.a,y),forest.outline(forest.slot.b,y))
		narrowest = minf(narrowest,d)
		widest = maxf(widest,d)
		y += 5.0
	check(narrowest >= 12.0 and widest <= 18.5,"Seed %d: the slot is a tight thread, %.1f to %.1f m wide from -40 to 80 m" % [s,narrowest,widest])
	var blocked := 0
	var tried := 0
	y = SkyPillar.GLIDE_BAND.x+5.0
	while y <= 90.0:
		var z: float = forest.slot.z0
		while z <= float(forest.slot.z1):
			for k in range(-2,3):
				tried += 1
				if _in_rock(forest,Vector3(forest.slot_x(y)+k*2.5,y,z)): blocked += 1
			z += 3.0
		y += 5.0
	check(blocked == 0 and tried > 500,"Seed %d: the slot is open along its line at glide height (%d of %d points in rock)" % [s,blocked,tried])
	# Walls either side of the slot, over the glide's top.
	var walls := _in_rock(forest,Vector3(forest.slot_x(40.0)-forest.slot.gap*0.5-8.0,40.0,(a.c as Vector2).y)) \
		and _in_rock(forest,Vector3(forest.slot_x(40.0)+forest.slot.gap*0.5+8.0,40.0,(b.c as Vector2).y))
	check(walls and float(a.top) > 100.0 and float(b.top) > 100.0,"Seed %d: the slot's walls stand either side, over the glide's top" % s)
	var mid: Vector2 = (forest.bridge.from as Vector2).lerp(forest.bridge.to,0.5)
	var over: Variant = forest.solid_at(Vector3(mid.x,float(forest.bridge.under)+2.0,mid.y))
	check(over is Vector2 and (over as Vector2).y > SkyPillar.THREAD_Y+15.0,"Seed %d: the bridge spans the thread, its underside %.0f m up" % [s,(over as Vector2).y if over is Vector2 else -1.0])
	var under_blocked := 0
	y = SkyPillar.GLIDE_BAND.x
	while y < float(forest.bridge.under)-SkyPillar.BRIDGE_ARCH-2.0:
		for k in range(-3,4):
			if _in_rock(forest,Vector3(mid.x+k*3.0,y,mid.y)): under_blocked += 1
		y += 3.0
	check(under_blocked == 0,"Seed %d: air under the bridge down to the glide's floor (%d points in rock)" % [s,under_blocked])
	var line_blocked := 0
	for p: Vector3 in forest.thread_line(SkyPillar.THREAD_Y,120):
		for o in [Vector3.ZERO,Vector3(5.0,0.0,0.0),Vector3(-5.0,0.0,0.0),Vector3(0.0,6.0,0.0),Vector3(0.0,-6.0,0.0)]:
			if _in_rock(forest,p+o): line_blocked += 1
	check(line_blocked == 0,"Seed %d: the thread's jet runs clear the whole way (%d points in rock)" % [s,line_blocked])
	var thermal: Vector3 = forest.thermal_base()
	var meadow: Dictionary = forest.pillars[forest.meadow]
	check(_in_rock(forest,Vector3(thermal.x,float(meadow.top)-5.0,thermal.z)) and not _in_rock(forest,Vector3(thermal.x,float(meadow.top)+8.0,thermal.z)),
		"Seed %d: the thermal rises off the meadow's top" % s)

## True if a point (the forest's frame) is in rock: under the top of the
## solid there and over its underside.
func _in_rock(forest: RefCounted, p: Vector3) -> bool:
	var s: Variant = forest.solid_at(p)
	return s != null and p.y < (s as Vector2).x and p.y > (s as Vector2).y

func _mesh() -> void:
	var forest: RefCounted = shape(home_seed())
	var arrays: Array = forest.body_arrays([Color.GREEN],[Color.GRAY],Color.WHITE,SkyPillars.OFF_MAP)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var faces := vertices.size()/3
	check(vertices.size() % 3 == 0 and colours.size() == vertices.size() and faces > 20000 and faces < 200000,"The forest is one surface of %d faces, coloured per face" % faces)
	var low := INF
	for v in vertices: low = minf(low,v.y)
	check(low < SkyPillar.SEA-20.0,"Its faces run on down under the sea (to %.0f m)" % low)

## The forest in sight of the plate, clear of every fixed island and the
## islands' currents, of islands and islets that turn up later, and of the
## mountain range.
func _clear_of_all() -> void:
	var forest: RefCounted = shape(home_seed())
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var to_plate := Vector2(SkyPillars.HOME.x,SkyPillars.HOME.z).length()
	check(to_plate > 600.0 and to_plate < 1200.0,"The forest stands within sight of the plate (%.0f m off)" % to_plate)
	var front := Vector3(0.0,0.0,1.0).rotated(Vector3.UP,SkyPillars.HOME_TURN)
	check(front.dot(-SkyPillars.HOME.normalized()) > 0.95,"Its thread's face is turned to the plate")
	var nearest := INF
	var rock_near := 0
	for s: Vector3 in slots:
		nearest = minf(nearest,Vector2(s.x-SkyPillars.HOME.x,s.z-SkyPillars.HOME.z).length())
		for k in range(16):
			for r in [0.0,60.0,120.0]:
				var p: Vector3 = s+Vector3(cos(TAU*k/16.0),0.0,sin(TAU*k/16.0))*float(r)
				for y in [s.y-60.0,s.y,s.y+60.0]:
					if _in_rock(forest,(Vector3(p.x,y,p.z)-SkyPillars.HOME).rotated(Vector3.UP,-SkyPillars.HOME_TURN)): rock_near += 1
	check(nearest > SkyPillars.KEEP,"Every fixed island stands clear of its middle (%.0f m)" % nearest)
	check(rock_near == 0 and forest.reach() < SkyPillars.KEEP-80.0,"No rock within 120 m of a fixed island; the forest reaches %.0f m" % forest.reach())
	var currents: Node3D = SkyCurrents.new()
	root.add_child(currents)
	currents.build(slots)
	var closest := INF
	for c: Dictionary in currents.currents:
		for p: Vector3 in c.points:
			var local := (p-SkyPillars.HOME).rotated(Vector3.UP,-SkyPillars.HOME_TURN)
			for i in range(forest.pillars.size()):
				var q: Dictionary = forest.pillars[i]
				var y := clampf(local.y,SkyPillar.FOOT,float(q.top))
				closest = minf(closest,Vector2(local.x,local.z).distance_to(forest.axis(q,y))-float(q.bound))
	check(closest > 60.0,"The islands' jet streams and thermals pass well clear of the pillars (%.0f m at the closest)" % closest)
	currents.free()
	var cells := SkyCells.new(slots)
	var inside := 0
	for x in range(-5,2):
		for z in range(-5,2):
			var s: Variant = cells.spot(Vector2i(x,z))
			if s != null and Vector2(s.x-SkyPillars.HOME.x,s.z-SkyPillars.HOME.z).length() < SkyPillars.KEEP: inside += 1
	check(inside == 0,"No island turns up in the forest")
	var islets: Node3D = SkyIslets.new()
	islets.cells = cells
	var islet_in := 0
	for x in range(-12,2):
		for z in range(-10,4):
			var s: Variant = islets.spot(Vector2i(x,z))
			if s != null and Vector2(s.x-SkyPillars.HOME.x,s.z-SkyPillars.HOME.z).length() < SkyPillars.KEEP: islet_in += 1
	islets.free()
	check(islet_in == 0,"No islet stands in the forest")
	check(SkyPeaks.blocks(SkyPillars.HOME) and SkyPeaks.blocks(SkyPillars.HOME+Vector3(300.0,0.0,0.0)),"The ranges' keep-out takes in the forest")
	# The range: no range stands within its keep of the forest, and none of
	# the range's rock stands over the sea within the forest's reach.
	var far := INF
	for x in range(-2,3):
		for z in range(-2,3):
			var r: Variant = SkyPeaks.spot(Vector2i(x,z))
			if r != null: far = minf(far,Vector2(r.x-SkyPillars.HOME.x,r.z-SkyPillars.HOME.z).length())
	check(far > SkyPeaks.KEEP,"Every range's middle stands %.0f m off the forest's" % far)
	var peak: RefCounted = SkyPeak.make(SkyPeaks.seed_of(Vector2i.ZERO))
	var range_rock := 0
	for k in range(64):
		for r in [0.0,150.0,300.0,forest.reach()+40.0]:
			var p := SkyPillars.HOME+Vector3(cos(TAU*k/64.0),0.0,sin(TAU*k/64.0))*float(r)
			var local := (p-SkyPeaks.HOME).rotated(Vector3.UP,-SkyPeaks.HOME_TURN)
			var h: Variant = peak.height_at(Vector2(local.x,local.z))
			if h != null and float(h) > SkyPeak.SEA: range_rock += 1
	check(range_rock == 0,"None of the range's rock stands in the forest")

## Made and let go with the ranges: the forest in sight of the plate stands
## up gliding off it, its jet and thermal with it; its pillars are solid;
## the haze keeps it; far off it goes.
func _streaming() -> void:
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var cells := SkyCells.new(slots)
	var currents: Node3D = SkyCurrents.new()
	root.add_child(currents)
	currents.build(slots)
	var peaks: Node3D = SkyPeaks.new()
	root.add_child(peaks)
	peaks.reset(cells,currents)
	peaks.advance(1.0,Vector3.ZERO)
	peaks.flush()
	var pillars: Node3D = peaks.kinds[0]
	check(pillars.forest_count() == 1,"Gliding off the plate, the forest in sight of it is made (%d)" % pillars.forest_count())
	var b: Dictionary = pillars.built.values()[0]
	var forest: RefCounted = b.shape
	check(forest.pillars[3].radii == shape(home_seed()).pillars[3].radii,"It is the forest its spot's seed raises")
	var p: Dictionary = forest.pillars[6]
	var c: Vector2 = forest.axis(p,float(p.top))
	var at: Vector3 = pillars.global_of(b,Vector3(c.x,0.0,c.y))
	var solid: Variant = peaks.body(Vector3(at.x,float(p.top)+20.0,at.z))
	check(solid is Vector2 and absf((solid as Vector2).x-float(p.top)-float(p.dome)) < 1.5 and (solid as Vector2).y < SkyPillar.SEA-200.0,
		"Over a pillar's top the ranges' solid is the pillar, from far under the cloud to its cap")
	check(peaks.solid(Vector3(at.x,0.0,at.z)) and not peaks.solid(pillars.global_of(b,Vector3(0.0,SkyPillar.THREAD_Y,SkyPillar.SLOT_Z))),"Its rock is stone; the slot is air")
	var jets := 0
	var thermals := 0
	for k: Dictionary in currents.currents:
		if str(k.get("key","")).begins_with("pillars:"):
			if k.kind == "jet": jets += 1
			else: thermals += 1
	check(jets == 1 and thermals == 1,"A jet runs down the thread and a thermal rises off the meadow")
	var spots: Array = peaks.haze_spots(Vector3.ZERO)
	var seen := false
	for s: Vector4 in spots:
		if Vector2(s.x-SkyPillars.HOME.x,s.y-SkyPillars.HOME.z).length() < 1.0: seen = true
	check(seen,"The haze keeps the forest in sight further off")
	var before: Vector3 = pillars.global_of(b,Vector3.ZERO)
	cells.origin += Vector3(-300.0,0.0,40.0)
	peaks.advance(0.0,Vector3(-300.0,0.0,40.0))
	check((pillars.global_of(b,Vector3.ZERO)-before).is_equal_approx(Vector3(-300.0,0.0,40.0)),"It rides the swaps' origin")
	for i in range(3): peaks.advance(1.0,Vector3(9000.0,0.0,9000.0)+cells.origin)
	jets = 0
	for k: Dictionary in currents.currents:
		if str(k.get("key","")).begins_with("pillars:"): jets += 1
	check(pillars.forest_count() == 0 and jets == 0,"Far off it is let go, its air with it")
	peaks.free()
	currents.free()

## The glide against the pillars: flown level at one at glide height, it is
## turned aside, never inside; come down onto a low top, it skims it; flown
## down the thread, through the slot and under the bridge, nothing touches.
func _glide() -> void:
	var peaks: Node3D = SkyPeaks.new()
	root.add_child(peaks)
	peaks.reset(SkyCells.new([Vector3.ZERO]),null)
	peaks.advance(1.0,Vector3.ZERO)
	peaks.flush()
	var pillars: Node3D = peaks.kinds[0]
	var b: Dictionary = pillars.built.values()[0]
	var forest: RefCounted = b.shape
	var ground := Callable(peaks,"body")
	var glide := SkyGlide.new()
	glide.stone = Callable(peaks,"solid")
	var tall := -1
	var low := -1
	for i in range(forest.pillars.size()):
		var p: Dictionary = forest.pillars[i]
		if p.role == "" and float(p.top) > 150.0 and tall < 0: tall = i
		if p.role == "" and float(p.top) < 90.0 and low < 0: low = i
	check(tall >= 0 and low >= 0,"The forest has tall pillars and low-topped ones")
	if tall < 0 or low < 0:
		peaks.free()
		return
	var p: Dictionary = forest.pillars[tall]
	var c: Vector2 = forest.axis(p,10.0)
	var from := c+Vector2(float(p.bound)+25.0,0.0)
	glide.launch(pillars.global_of(b,Vector3(from.x,10.0,from.y)),atan2(1.0,0.0)+float(b.turn),12.0,false)
	var inside := 0
	var brushed := false
	for i in range(300):
		glide.step(1.0/60.0,{},ground)
		var here: Variant = peaks.body(glide.position)
		if here != null and glide.position.y < (here as Vector2).x-0.05 and glide.position.y > (here as Vector2).y: inside += 1
		brushed = brushed or glide.brushing
	check(brushed and inside == 0,"Flown at a pillar, it is turned aside along the face, never inside it (%d steps inside)" % inside)
	var q: Dictionary = forest.pillars[low]
	var top_c: Vector2 = forest.axis(q,float(q.top))
	glide.launch(pillars.global_of(b,Vector3(top_c.x,float(q.top)+float(q.dome)+5.0,top_c.y)),float(b.turn),5.0,false)
	var skimmed := false
	var lowest := INF
	for i in range(90):
		glide.step(1.0/60.0,{"dive":1.0},ground)
		skimmed = skimmed or glide.skimming
		var here: Variant = peaks.body(glide.position)
		if here != null: lowest = minf(lowest,glide.position.y-(here as Vector2).x)
	check(skimmed and lowest > -0.05,"Come down onto a low top, it skims it (%.2f m over it at the lowest)" % lowest)
	# Down the thread from its mouth, level, held on the line.
	var line: PackedVector3Array = forest.thread_line(SkyPillar.THREAD_Y,2)
	glide.launch(pillars.global_of(b,line[0]),float(b.turn),14.0,false)
	var touched := 0
	var steps := 0
	while steps < 4000:
		steps += 1
		var local: Vector3 = pillars.local_of(b,glide.position)
		if local.z < SkyPillar.THREAD_TO: break
		# Held to the thread (as the jet would), level.
		glide.position = pillars.global_of(b,Vector3(forest.slot_x(local.y) if local.z > float(forest.slot.z0)-30.0 else 0.0,SkyPillar.THREAD_Y,local.z))
		glide.heading = float(b.turn)
		glide.pitch = 0.0
		glide.speed = 14.0
		glide.step(1.0/60.0,{},ground)
		if glide.brushing or glide.skimming or glide.under_rock: touched += 1
	check(touched == 0 and steps < 4000,"Flown down the thread, through the slot and under the bridge, nothing touches it (%d steps touched)" % touched)
	peaks.free()
