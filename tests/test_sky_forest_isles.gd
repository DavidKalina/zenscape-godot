extends SceneTree
## The forested isles (scripts/sky_forest_isle.gd, scripts/sky_forest_isles.gd):
## a seed always grows the same isle; isles are long and broad within their
## bounds; the aisles are clear of trunks and open under the crowns at the
## glide's height; trunks are solid and turn the glide aside, and a crown's
## underside is a ceiling it slides along; the lakes are there and level,
## held by their banks; the isle in sight of the plate stands clear of the
## islands, their jet streams and thermals, the ranges, and of islands and
## islets that turn up later; isles stream in and out round the eye. Headless:
## shapes and queries only, nothing drawn.
const SkyForestIsle = preload("res://scripts/sky_forest_isle.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SEEDS := [101,2024,77777,4242,9]
var failures := 0
var shapes := {}

func _initialize() -> void:
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	_same_seed()
	_sizes()
	_lanes()
	_lakes()
	_meshes()
	_clear_of_everything()
	_streaming()
	_glide()
	print("PASS: sky forest isles" if failures == 0 else "FAIL: sky forest isles")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func shape(seed_value: int) -> RefCounted:
	if not shapes.has(seed_value): shapes[seed_value] = SkyForestIsle.make(seed_value)
	return shapes[seed_value]

func home_seed() -> int:
	return SkyForestIsles.seed_of(Vector2i.ZERO)

func all_seeds() -> Array:
	var out := SEEDS.duplicate()
	out.append(home_seed())
	return out

func _same_seed() -> void:
	var a: RefCounted = shape(home_seed())
	var b: RefCounted = SkyForestIsle.make(home_seed())
	var c: RefCounted = shape(SEEDS[0])
	check(a.heights == b.heights and a.under == b.under and a.trees == b.trees and a.crowns == b.crowns and a.roots == b.roots
		and a.lakes.map(func(l: Dictionary) -> float: return l.level) == b.lakes.map(func(l: Dictionary) -> float: return l.level),"A seed grows the same isle, forest and lakes")
	check(a.heights != c.heights and a.trees != c.trees,"Another seed grows another")
	check(SkyForestIsles.spot(Vector2i(3,-2)) == SkyForestIsles.spot(Vector2i(3,-2)) and SkyForestIsles.spot(Vector2i.ZERO) == Vector4(SkyForestIsles.HOME.x,SkyForestIsles.HOME.y,SkyForestIsles.HOME.z,SkyForestIsles.HOME_TURN),"Spots are the same each time, and the plate's cell holds the isle in sight of it")

## Long and broad: measured along its rim, 200 to 500 m one way and 80 to
## 200 m the other, far longer than wide; deep rock under it, a forest on it.
func _sizes() -> void:
	var worst := ""
	for s: int in all_seeds():
		var isle: RefCounted = shape(s)
		var lo := Vector2(INF,INF)
		var hi := -lo
		for k in range(360):
			var p: Vector2 = isle.rim_point(TAU*k/360.0)
			lo = lo.min(p)
			hi = hi.max(p)
		var size := hi-lo
		var giants := 0
		for k: int in isle.kinds: giants += int(k == -1)
		if size.x < 200.0 or size.x > 500.0 or size.y < 80.0 or size.y > 200.0 or size.x < size.y*1.6: worst += " seed %d is %.0f x %.0f m;" % [s,size.x,size.y]
		if isle.top-isle.bottom < 50.0: worst += " seed %d hangs only %.0f m;" % [s,isle.top-isle.bottom]
		if giants < 20: worst += " seed %d has %d giants;" % [s,giants]
	check(worst == "","Every isle is 200-500 m long, 80-200 m wide, hangs deep and is forested%s" % worst)

## Every aisle: no trunk within AISLE_HALF of its line, and along it, at every
## height in the glide's lane band, the glide is in open air (under every
## crown by CLEAR, over the ground or water); through the forest (off the
## water and in from the rim) most of it runs under crowns; and between any
## two giants' trunks there is a lane of 15 m or so.
func _lanes() -> void:
	for s: int in all_seeds():
		var isle: RefCounted = shape(s)
		var nearest := INF
		for index in range(isle.trees.size()):
			var t: Vector4 = isle.trees[index]
			if isle.kinds[index] != -1: continue
			nearest = minf(nearest,isle.aisle_distance(Vector2(t.x,t.y))-isle.crowns[index].w)
		var blocked := 0
		var points := 0
		var covered := 0
		var wooded := 0
		var gaps := INF
		for a in range(isle.aisles.size()):
			for over in range(int(SkyForestIsle.GLIDE_LANE.x),int(SkyForestIsle.GLIDE_LANE.y)+1):
				for p: Vector3 in isle.lane(a,float(over)):
					points += 1
					var solid: Variant = isle.solid(p)
					if solid == null: continue
					var v := solid as Vector3
					if p.y < v.x+SkyGlide.SKIM and p.y > v.y-SkyGlide.CLEAR: blocked += 1
					var at := Vector2(p.x,p.z)
					if over == int(SkyForestIsle.GLIDE_LANE.x) and isle.share(at) < 0.85 and isle._dry(at,1.5,SkyForestIsle.CHANNEL+6.0):
						wooded += 1
						if _under_crown(isle,at): covered += 1
		# Between any two giants, the open lane between their trunks.
		for i in range(isle.trees.size()):
			if isle.kinds[i] != -1: continue
			var t: Vector4 = isle.trees[i]
			for j in isle.near(Vector2(t.x,t.y)):
				if j <= i or isle.kinds[j] != -1: continue
				var u: Vector4 = isle.trees[j]
				gaps = minf(gaps,Vector2(t.x,t.y).distance_to(Vector2(u.x,u.y))-isle.crowns[i].w-isle.crowns[j].w)
		check(nearest >= SkyForestIsle.AISLE_HALF-0.01 and blocked == 0,"Seed %d: its %d aisles are clear of trunks (%.1f m from the line at the nearest) and open at glide height (%d of %d points blocked)" % [s,isle.aisles.size(),nearest,blocked,points])
		check(covered*2 > wooded,"Seed %d: through the forest the aisles run under the crowns (%d of %d points)" % [s,covered,wooded])
		check(gaps >= 14.5,"Seed %d: between any two giants the lane is %.1f m or more" % [s,gaps])

func _under_crown(isle: RefCounted, p: Vector2) -> bool:
	for index in isle.near(p):
		var t: Vector4 = isle.trees[index]
		if isle.kinds[index] == -1 and p.distance_to(Vector2(t.x,t.y)+isle.leans[index]) < isle.crowns[index].z: return true
	return false

## Every lake: water at its middle at its level, the bed well under it, its
## banks standing over it all round (but where a channel leaves), and the
## water's sheet level; the upper lake stands over the lower, and the
## outflow leaves the lower over the rim.
func _lakes() -> void:
	var worst := ""
	var twos := 0
	for s: int in all_seeds():
		var isle: RefCounted = shape(s)
		for lake: Dictionary in isle.lakes:
			var level: float = lake.level
			var middle: Vector2 = lake.middle
			if not is_equal_approx(isle.water_at(middle),level): worst += " seed %d: no water at a lake's middle;" % s
			if isle.ground_at(middle) > level-1.5: worst += " seed %d: a lake only %.1f m deep;" % [s,level-isle.ground_at(middle)]
			for k in range(72):
				var p: Vector2 = isle._lake_point(lake,TAU*k/72.0,1.25)
				var by_channel := false
				for c: Dictionary in isle.channels:
					if isle.along(c,p).x < SkyForestIsle.CHANNEL+2.0: by_channel = true
				if not by_channel and isle.ground_at(p) < level+0.05:
					worst += " seed %d: a bank stands %.2f m under its lake;" % [s,level-isle.ground_at(p)]
					break
		if isle.lakes.size() == 2:
			twos += 1
			var low: float = isle.lakes[isle.lower].level
			var high: float = isle.lakes[1-isle.lower].level
			if high < low+SkyForestIsle.STEP_UP-0.01: worst += " seed %d: the upper lake stands only %.1f m over the lower;" % [s,high-low]
		if isle.share(isle.lip) > 1.0 or isle.share(isle.lip+isle.lip_out*2.0) <= 1.0 or isle.share(isle.lip+isle.lip_out*20.0) <= 1.0: worst += " seed %d: the outflow's lip is not on the rim, open air past it;" % s
		if not is_equal_approx(isle.lip_level,float(isle.lakes[isle.lower].level)): worst += " seed %d: the outflow is not at the lower lake's level;" % s
	check(worst == "","Every lake holds water at its level, is deep, and is held by its banks%s" % worst)
	check(twos >= 1,"Some isles have two lakes, a stream between (%d of %d)" % [twos,all_seeds().size()])

func _meshes() -> void:
	var isle: RefCounted = shape(home_seed())
	var body: Dictionary = isle.body_arrays([Color.GREEN,Color.DARK_GREEN,Color.SEA_GREEN],Color.TAN,Color.WHEAT,SkyForestIsles.OFF_MAP)
	var top: PackedVector3Array = body.top[Mesh.ARRAY_VERTEX]
	var rock: PackedVector3Array = body.rock[Mesh.ARRAY_VERTEX]
	var worst := 0.0
	for k in range(0,top.size(),97):
		var v := top[k]-SkyForestIsles.OFF_MAP
		if isle.share(Vector2(v.x,v.z)) < 0.95: worst = maxf(worst,absf(isle.ground_at(Vector2(v.x,v.z))-v.y))
	var deepest := INF
	for v in rock: deepest = minf(deepest,v.y*SkyForestIsle.ROCK_SCALE)
	check(top.size() % 3 == 0 and rock.size() % 3 == 0 and top.size()/3+rock.size()/3 < 60000,"The isle is two surfaces, %d faces on top and %d of rock" % [top.size()/3,rock.size()/3])
	check(worst < 0.05,"Its top is the ground the glide reads (worst %.3f m)" % worst)
	check(absf(deepest-isle.bottom) < 0.5,"Its rock reaches down to its keel (%.1f m, keel %.1f m)" % [deepest,isle.bottom])
	var water: Array = isle.water_arrays(Color.BLUE)
	var vertices: PackedVector3Array = water[Mesh.ARRAY_VERTEX]
	var levels := {}
	for lake: Dictionary in isle.lakes: levels[snappedf(lake.level,0.001)] = true
	var off_level := 0
	for v in vertices:
		if levels.has(snappedf(v.y,0.001)): continue
		var on_channel := false
		for c: Dictionary in isle.channels:
			if isle.along(c,Vector2(v.x,v.z)).x < SkyForestIsle.CHANNEL*1.5: on_channel = true
		if not on_channel: off_level += 1
	check(vertices.size() > 0 and off_level == 0,"The lakes' water lies flat at their levels (%d vertices off)" % off_level)

## The isle in sight of the plate: within sight, and clear of the fixed
## islands, of their jet streams and thermals, of the ranges; and no island
## or islet turns up on it later.
func _clear_of_everything() -> void:
	var isle: RefCounted = shape(home_seed())
	var home := SkyForestIsles.HOME
	var turn := SkyForestIsles.HOME_TURN
	var local_of := func(p: Vector3) -> Vector3: return (p-home).rotated(Vector3.UP,-turn)
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var near_rim := INF
	for k in range(72):
		var p: Vector2 = isle.rim_point(TAU*k/72.0)
		var w := home+Vector3(p.x,0.0,p.y).rotated(Vector3.UP,turn)
		near_rim = minf(near_rim,Vector2(w.x,w.z).length())
	check(near_rim > 300.0 and near_rim < 700.0,"The isle stands within sight of the plate (its nearest rim %.0f m off)" % near_rim)
	var tightest := INF
	for s: Vector3 in slots:
		for k in range(72):
			var p: Vector2 = isle.rim_point(TAU*k/72.0)
			var w := home+Vector3(p.x,0.0,p.y).rotated(Vector3.UP,turn)
			tightest = minf(tightest,Vector2(w.x-s.x,w.z-s.z).length())
	check(tightest > 150.0,"Every fixed island stands well clear of its rim (%.0f m at the closest)" % tightest)
	check(not SkyPeaks.blocks(home,isle.reach()),"No range stands on it")
	var currents: Node3D = SkyCurrents.new()
	root.add_child(currents)
	currents.build(slots)
	var through := 0
	var closest := INF
	for c: Dictionary in currents.currents:
		for p: Vector3 in c.points:
			if p.y < isle.bottom+home.y-20.0 or p.y > isle.canopy+home.y+20.0: continue
			var local: Vector3 = local_of.call(p)
			var at := Vector2(local.x,local.z)
			var r := float(c.radius)+15.0
			for k in range(8):
				if isle.share(at+Vector2.from_angle(TAU*k/8.0)*r) <= 1.0: through += 1
			closest = minf(closest,at.length()-isle.reach())
	check(through == 0,"The islands' jet streams and thermals pass clear of it (%d points too near; %.0f m past its reach at the closest)" % [through,closest])
	currents.free()
	var cells := SkyCells.new(slots)
	var on_isle := 0
	for x in range(-6,4):
		for z in range(-5,4):
			var s: Variant = cells.spot(Vector2i(x,z))
			if s != null and Vector2(s.x-home.x,s.z-home.z).length() < isle.reach()+60.0: on_isle += 1
	check(on_isle == 0,"No island turns up on it")
	var islets: Node3D = SkyIslets.new()
	islets.cells = cells
	var islet_on := 0
	for x in range(-12,4):
		for z in range(-10,6):
			var s: Variant = islets.spot(Vector2i(x,z))
			if s == null: continue
			var local: Vector3 = local_of.call(s)
			var at := Vector2(local.x,local.z)
			for k in range(8):
				if isle.share(at+Vector2.from_angle(TAU*k/8.0)*20.0) <= 1.0: islet_on += 1
	check(islet_on == 0,"No islet stands on it")
	islets.free()
	# Far off, a few: never in the archipelago's ring nor on a range.
	var found := 0
	var bad := 0
	for x in range(-6,7):
		for z in range(-6,7):
			var s: Variant = SkyForestIsles.spot(Vector2i(x,z))
			if s == null or Vector2i(x,z) == Vector2i.ZERO: continue
			found += 1
			var at := Vector3(s.x,s.y,s.z)
			if Vector2(at.x,at.z).length() < SkyForestIsles.RING or SkyPeaks.blocks(at,SkyForestIsles.KEEP): bad += 1
	check(found > 10 and found < 100 and bad == 0,"Elsewhere they are few (%d in 168 cells), none in the archipelago's ring or on a range" % found)

func _streaming() -> void:
	var cells := SkyCells.new([Vector3.ZERO])
	var isles: Node3D = SkyForestIsles.new()
	root.add_child(isles)
	isles.reset(cells)
	isles.advance(1.0,Vector3.ZERO)
	isles.flush()
	var b: Dictionary = {}
	for key in isles.built:
		if isles.built[key].cell == Vector2i.ZERO: b = isles.built[key]
	check(not b.is_empty(),"Gliding off the plate, the isle in sight of it is made (%d made)" % isles.isle_count())
	if b.is_empty():
		isles.free()
		return
	var isle: RefCounted = b.shape
	check(isle.heights == shape(home_seed()).heights,"It is the isle its spot's seed grows")
	var instances := 0
	var batches := 0
	for child in (b.node as Node3D).get_children():
		if child is MultiMeshInstance3D:
			batches += 1
			if not str(child.name).contains("Far"): instances += (child as MultiMeshInstance3D).multimesh.instance_count
	print("     %d batches, %d instances near, %d giants, %d spruces, %d ferns, %d roots" % [batches,instances,isle.kinds.count(-1),isle.kinds.size()-isle.kinds.count(-1),isle.ferns.size(),isle.roots.size()])
	check(batches <= 16,"Its forest is drawn in %d instanced batches" % batches)
	var lake: Dictionary = isle.lakes[0]
	var middle: Vector2 = lake.middle
	var over_lake: Variant = isles.body(isles.global_of(b,Vector3(middle.x,30.0,middle.y)))
	check(over_lake is Vector2 and absf((over_lake as Vector2).x-(float(lake.level)+float(b.home.y))) < 0.01,"Over the lake the glide reads the water's level")
	var t: Vector4 = isle.trees[isle.kinds.find(-1)]
	var at_trunk: Vector3 = isles.global_of(b,Vector3(t.x,t.z+10.0,t.y))
	check(isles.stone(at_trunk) and (isles.body(at_trunk) as Vector2).x > at_trunk.y,"A trunk is solid wood")
	check(isles.body(isles.global_of(b,Vector3(isle.reach()+40.0,0.0,0.0))) == null,"Off it, open air")
	var before: Vector3 = isles.global_of(b,Vector3.ZERO)
	cells.origin += Vector3(-300.0,0.0,40.0)
	isles.advance(0.0,Vector3(-300.0,0.0,40.0))
	check((isles.global_of(b,Vector3.ZERO)-before).is_equal_approx(Vector3(-300.0,0.0,40.0)),"It rides the swaps' origin")
	for i in range(3): isles.advance(1.0,Vector3(0.0,0.0,9000.0)+cells.origin)
	isles.flush()
	var home_kept := false
	for key in isles.built:
		if isles.built[key].cell == Vector2i.ZERO: home_kept = true
	check(not home_kept,"Far off it is let go")
	isles.free()

## The glide in the forest: flown at a trunk at lane height it is turned
## aside, never inside the trunk; rising under a crown it slides along its
## underside, never into it; flown down an aisle it is never touched.
func _glide() -> void:
	var cells := SkyCells.new([Vector3.ZERO])
	var isles: Node3D = SkyForestIsles.new()
	root.add_child(isles)
	isles.reset(cells)
	isles.advance(1.0,Vector3.ZERO)
	isles.flush()
	var b: Dictionary = {}
	for key in isles.built:
		if isles.built[key].cell == Vector2i.ZERO: b = isles.built[key]
	var isle: RefCounted = b.shape
	var ground := Callable(isles,"body")
	var glide := SkyGlide.new()
	glide.stone = Callable(isles,"stone")
	# The giant nearest an aisle, flown at from the aisle.
	var best := -1
	var gap := INF
	for index in range(isle.trees.size()):
		if isle.kinds[index] != -1: continue
		var t: Vector4 = isle.trees[index]
		var d: float = isle.aisle_distance(Vector2(t.x,t.y))
		if d < gap and isle.share(Vector2(t.x,t.y)) < 0.8:
			gap = d
			best = index
	var t: Vector4 = isle.trees[best]
	var c: Vector4 = isle.crowns[best]
	var from := Vector2(t.x,t.y)
	var on_aisle := from
	var far := INF
	for a: PackedVector2Array in isle.aisles:
		for k in range(a.size()-1):
			var ab: Vector2 = a[k+1]-a[k]
			var q: Vector2 = a[k]+ab*clampf((from-a[k]).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
			if q.distance_to(from) < far:
				far = q.distance_to(from)
				on_aisle = q
	var toward := (from-on_aisle).normalized()
	var start := on_aisle-toward*2.0
	var y: float = isle.ground_at(start)+12.0
	glide.launch(isles.global_of(b,Vector3(start.x,y,start.y)),atan2(-toward.x,-toward.y)+float(b.turn),8.0,false)
	var inside := 0
	var brushed := false
	for i in range(300):
		glide.step(1.0/60.0,{"rise":0.3},ground)
		brushed = brushed or glide.brushing
		var local: Vector3 = isles.local_of(b,glide.position)
		for index in isle.near(Vector2(local.x,local.z)):
			var u: Vector4 = isle.trees[index]
			if Vector2(local.x,local.z).distance_to(Vector2(u.x,u.y)) < isle.crowns[index].w-0.05 and local.y < u.z+u.w: inside += 1
	check(brushed and inside == 0,"Flown at a trunk, it is turned aside, never inside one (%d steps inside)" % inside)
	# Under the crown, a step off the trunk, rising as it flies out under
	# the crown's lean.
	var lean: Vector2 = isle.leans[best]
	var way_out := lean.normalized() if lean.length() > 0.1 else Vector2.RIGHT
	var under := from+way_out*(c.w+3.0)
	glide.launch(isles.global_of(b,Vector3(under.x,c.x-1.5,under.y)),atan2(-way_out.x,-way_out.y)+float(b.turn),4.0,false)
	var highest := -INF
	var slid := false
	for i in range(120):
		glide.step(1.0/60.0,{"rise":1.0,"flap":i % 20 == 0,"pitch":0.6},ground)
		slid = slid or glide.under_rock
		var local: Vector3 = isles.local_of(b,glide.position)
		var s: Variant = isle.solid(local)
		if s != null and float((s as Vector3).z) > 0.5 and local.y < (s as Vector3).x and local.y > (s as Vector3).y: highest = maxf(highest,local.y-(s as Vector3).y)
	check(slid and highest == -INF,"Rising under a crown, it slides along its underside, never into it (slid %s, %.2f m in at most)" % [slid,highest])
	# Down the first aisle at lane height: never brushed, never under rock.
	var lane: PackedVector3Array = isle.lane(0,12.0)
	var a0: Vector3 = lane[int(lane.size()*0.15)]
	var a1: Vector3 = lane[mini(int(lane.size()*0.15)+1,lane.size()-1)]
	var way := Vector2(a1.x-a0.x,a1.z-a0.z).normalized()
	glide.launch(isles.global_of(b,a0),atan2(-way.x,-way.y)+float(b.turn),6.0,false)
	var touched := false
	var flown := 0.0
	var was: Vector3 = glide.position
	for i in range(240):
		# Steered along the aisle's line.
		var local: Vector3 = isles.local_of(b,glide.position)
		var k := _nearest(lane,local)
		var aim: Vector3 = lane[mini(k+6,lane.size()-1)]
		var want := atan2(-(aim.x-local.x),-(aim.z-local.z))+float(b.turn)
		glide.heading = lerp_angle(glide.heading,want,0.2)
		glide.step(1.0/60.0,{},ground)
		touched = touched or glide.brushing or glide.under_rock
		flown += Vector2(glide.position.x-was.x,glide.position.z-was.z).length()
		was = glide.position
	check(not touched and flown > 15.0,"Flown down an aisle at glide height, nothing touches it (%.0f m flown)" % flown)
	isles.free()

func _nearest(points: PackedVector3Array, p: Vector3) -> int:
	var best := 0
	for k in range(points.size()):
		if Vector2(points[k].x-p.x,points[k].z-p.z).length() < Vector2(points[best].x-p.x,points[best].z-p.z).length(): best = k
	return best
