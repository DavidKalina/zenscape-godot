extends SceneTree
## The sky peaks (scripts/sky_peak.gd, scripts/sky_peaks.gd): a seed always
## raises the same range; its summits stand in the band over the islands; the
## gorge is clear the whole way through at glide height, with walls standing
## over the glide on both sides; the built faces end under the cloud sea all
## round; the range in sight of the plate is clear of the islands, the
## islets and the islands' jet streams, and nothing turns up on it; it is a
## solid the glide skims over a ledge but is turned aside by at a cliff; its
## jet runs down the gorge; and it stays in the haze's sight further off than
## an island. Headless: shapes and queries only, nothing drawn.
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SkyHaze = preload("res://scripts/sky_haze.gd")
const SEEDS := [101,2024,77777,4242,9]
var failures := 0
var shapes := {}

func _initialize() -> void:
	# The wonders are off in play (SkyHomes `stone`, `isles`); on here.
	preload("res://scripts/sky_homes.gd").stone = true
	preload("res://scripts/sky_homes.gd").isles = true
	# The open sky, endless, its kinds scattered through the cells (SkyWorld
	# `ring` off); the bounded world's are checked in tests/test_sky_world.gd.
	preload("res://scripts/sky_world.gd").ring = false
	_same_seed()
	_summits()
	_gorge()
	_base()
	_clear_of_islands()
	_streaming()
	_scattered()
	_glide()
	_haze()
	print("PASS: sky peaks" if failures == 0 else "FAIL: sky peaks")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func shape(seed_value: int) -> RefCounted:
	if not shapes.has(seed_value): shapes[seed_value] = SkyPeak.make(seed_value)
	return shapes[seed_value]

func home_seed() -> int:
	return SkyPeaks.seed_of(Vector2i.ZERO)

func _same_seed() -> void:
	var a: RefCounted = shape(home_seed())
	var b: RefCounted = SkyPeak.make(home_seed())
	var c: RefCounted = shape(SEEDS[0])
	check(a.heights == b.heights and a.summits == b.summits and a.wraps == b.wraps,"A seed raises the same range")
	check(a.heights != c.heights,"Another seed raises another")

func _summits() -> void:
	var all_seeds := SEEDS.duplicate()
	all_seeds.append(home_seed())
	var ok := true
	var counts := {}
	var worst := ""
	for s: int in all_seeds:
		var peak: RefCounted = shape(s)
		counts[peak.summits.size()] = true
		if peak.top < 150.0 or peak.top > 350.0: ok = false
		for summit: Vector3 in peak.summits:
			if summit.y < 150.0 or summit.y > 350.0:
				ok = false
				worst = "seed %d summit %.0f m" % [s,summit.y]
		if absf(peak.top-(peak.summits[0] as Vector3).y) > 0.01: worst = "seed %d: the highest point is not its first summit" % s
	check(ok and worst == "","Every summit stands 150 to 350 m over the islands' plane %s" % worst)
	check(counts.size() >= 2,"Ranges vary in how many summits they have (%s)" % str(counts.keys()))

## Along the gorge's line, every point within CLEAR_HALF of it is open from
## the glide's floor to its ceiling, except through a pinch, where it is open
## over the fins (the wide way, still most of the band) and the slot between
## them (the tight line) is open the whole band down, and truly narrow; at
## its middle the walls stand over the ceiling on both sides; and both its
## mouths open out of the range.
func _gorge() -> void:
	var pinched := 0
	for s: int in [home_seed(),SEEDS[1],SEEDS[2],SEEDS[3],SEEDS[4]]:
		var peak: RefCounted = shape(s)
		var tightest := INF
		var slot := INF
		var narrow := INF
		var z := -SkyPeak.HALF.y
		while z <= SkyPeak.HALF.y:
			var way: Vector2 = peak.gorge_way(z)
			var across := Vector2(way.y,-way.x)
			var line := Vector2(peak.gorge_x(z),z)
			var share: float = peak.pinch_share(z)
			var low: float = SkyPeak.GLIDE_BAND.x if share <= 0.0 else maxf(SkyPeak.GLIDE_BAND.x,float(peak.pinch.top)+2.0)
			for k in range(-4,5):
				var p := line+across*SkyPeak.CLEAR_HALF*float(k)/4.0
				var h: Variant = peak.height_at(p)
				if h != null: tightest = minf(tightest,low-float(h))
			if share > 0.0:
				for k in range(-2,3):
					var h: Variant = peak.height_at(line+across*(SkyPeak.PINCH_HALF-3.0)*float(k)/2.0)
					if h != null: slot = minf(slot,SkyPeak.GLIDE_BAND.x-float(h))
			if share >= 0.999:
				for side in [1.0,-1.0]:
					var h: Variant = peak.height_at(line+across*side*(SkyPeak.PINCH_HALF+5.0))
					narrow = minf(narrow,(float(h) if h != null else -INF)-SkyPeak.GLIDE_BAND.x)
			z += 4.0
		check(tightest > 1.0,"Seed %d: the gorge is open all the way through at glide height, 40 m wide (%.1f m to spare)" % [s,tightest])
		if not peak.pinch.is_empty():
			pinched += 1
			check(float(peak.pinch.top) < SkyPeak.GLIDE_BAND.y-60.0,"Seed %d: over its pinch the wide way keeps most of the band (fins to %.0f m)" % [s,peak.pinch.top])
			check(slot > 1.0,"Seed %d: the pinch's tight line is open the whole band down (%.1f m to spare)" % [s,slot])
			check(narrow > 20.0,"Seed %d: and it is truly tight, rock %.0f m up just past it" % [s,narrow])
		var middle := Vector2(peak.gorge_x(0.0),0.0)
		var walls := []
		for side in [1.0,-1.0]:
			var high := -INF
			for d in range(30,200,4): high = maxf(high,float(peak.height_at(middle+Vector2(side*d,0.0)) if peak.height_at(middle+Vector2(side*d,0.0)) != null else -INF))
			walls.append(high)
		check(minf(walls[0],walls[1]) > SkyPeak.GLIDE_BAND.y,"Seed %d: at its middle the walls stand over the glide on both sides (%.0f, %.0f m)" % [s,walls[0],walls[1]])
		var ends := []
		for zz in [-SkyPeak.HALF.y+20.0,SkyPeak.HALF.y-20.0]:
			var h: Variant = peak.height_at(Vector2(peak.gorge_x(zz),zz))
			ends.append(h == null or float(h) < SkyPeak.SEA)
		check(ends[0] and ends[1],"Seed %d: both mouths open out under the sea" % s)
	check(pinched >= 1 and pinched < 5,"Some gorges have a pinch, not all (%d of 5)" % pinched)

## The faces stop only under the sea: every built cell that borders an
## unbuilt one, or the grid's edge, lies under the cloud sea's top.
func _base() -> void:
	for s: int in [home_seed(),SEEDS[3]]:
		var peak: RefCounted = shape(s)
		var highest_rim := -INF
		var lowest := INF
		for j in range(peak.nz-1):
			for i in range(peak.nx-1):
				if not _built(peak,i,j): continue
				lowest = minf(lowest,_cell_top(peak,i,j))
				var rim: bool = i == 0 or j == 0 or i == peak.nx-2 or j == peak.nz-2
				if not rim:
					for o: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
						if not _built(peak,i+o.x,j+o.y): rim = true
				if rim: highest_rim = maxf(highest_rim,_cell_top(peak,i,j))
		check(highest_rim < SkyPeak.SEA,"Seed %d: the faces end under the cloud sea all round (highest edge %.0f m)" % [s,highest_rim])
		check(lowest < SkyPeak.SEA-20.0,"Seed %d: the flanks run on down past the sea (to %.0f m)" % [s,lowest])
	var peak: RefCounted = shape(home_seed())
	var arrays: Array = peak.body_arrays([Color.GREEN],[Color.GRAY],Color.WHITE,SkyPeaks.OFF_MAP)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var ok := vertices.size() % 3 == 0 and colours.size() == vertices.size() and vertices.size() > 0
	var faces := vertices.size()/3
	# The mesh is the heightfield the glide reads, a few corners checked.
	var worst := 0.0
	for k in range(0,vertices.size(),997):
		var v := vertices[k]-SkyPeaks.OFF_MAP
		var h: Variant = peak.height_at(Vector2(v.x,v.z)+Vector2(0.01,0.01))
		if h != null: worst = maxf(worst,absf(float(h)-v.y))
	check(ok and faces < 160000,"The range is one surface of %d faces, coloured per face" % faces)
	# Snow: on the high ground, none low down, steep faces left bare.
	var white := Color(0.97,0.98,1.0)
	arrays = peak.body_arrays([Color(0.1,0.3,0.1)],[Color(0.27,0.23,0.18)],Color(0.3,0.3,0.28),SkyPeaks.OFF_MAP,1,white)
	vertices = arrays[Mesh.ARRAY_VERTEX]
	colours = arrays[Mesh.ARRAY_COLOR]
	var high := 0
	var high_snow := 0
	var low_snow := 0
	var steep_snow := 0
	var steep_high := 0
	for k in range(0,vertices.size(),3):
		var snowy: bool = colours[k].b > 0.8
		var y: float = (vertices[k].y+vertices[k+1].y+vertices[k+2].y)/3.0
		var n := (vertices[k+2]-vertices[k]).cross(vertices[k+1]-vertices[k]).normalized()
		if y > peak.top-40.0:
			high += 1
			if snowy: high_snow += 1
			if absf(n.y) < 0.3:
				steep_high += 1
				if snowy: steep_snow += 1
		if y < peak.snowline-SkyPeak.SNOW_RAG-25.0*SkyPeak.SNOW_HOLLOW-SkyPeak.SNOW_LINGER*1.3-2.0 and snowy: low_snow += 1
	check(high_snow > high/3,"Snow lies on the summits' high ground (%d of %d faces)" % [high_snow,high])
	check(low_snow == 0,"None lies far under the snow line")
	check(steep_snow < steep_high,"The sheerest faces up there stay bare rock (%d of %d snowed)" % [steep_snow,steep_high])
	check(worst < 0.8,"Its faces are the heights the glide reads (worst %.2f m)" % worst)
	# Grass lies in patches on the ground's broad lie, hardly ever a green
	# facet on a cliff.
	var green := 0
	var cliff_green := 0
	for k in range(0,vertices.size(),3):
		var c := colours[k]
		if not (c.g > c.r*1.6 and c.g > c.b*1.6): continue
		green += 1
		var n := (vertices[k+2]-vertices[k]).cross(vertices[k+1]-vertices[k]).normalized()
		if absf(n.y) < 0.5: cliff_green += 1
	check(green > 0 and cliff_green < green*0.025,"Grass lies in patches, hardly any on the cliffs (%d of %d green faces)" % [cliff_green,green])
	# The beds: mostly the granite's tones, with bands of sand and of shale
	# as an island's side has.
	var kinds := {}
	for index in range(-10,30): kinds[peak._bed_kind(index)] = kinds.get(peak._bed_kind(index),0)+1
	var granite: int = kinds.get("core_a",0)+kinds.get("core_b",0)+kinds.get("core_c",0)
	check(kinds.has("sand") and kinds.has("shale_dark") and granite > 20,"The rock is layered: granite beds with bands of sand and shale (%s)" % str(kinds))
	# Not a layer cake: the beds run unevenly thick, and the ledges and the
	# colours read the same beds (`bed_height` undoes `bed_at`).
	var thin := INF
	var thick := 0.0
	var worst_back := 0.0
	for k in range(-8,12):
		var at := Vector2(37.0*k,-21.0*k)
		var a: float = peak.bed_height(float(k),at)
		var b: float = peak.bed_height(float(k)+1.0,at)
		thin = minf(thin,b-a)
		thick = maxf(thick,b-a)
		worst_back = maxf(worst_back,absf(peak.bed_at(a,at)-float(k)))
	check(thin > 0.0 and thick > thin*2.0,"The beds run unevenly thick (%.0f to %.0f m)" % [thin,thick])
	check(worst_back < 0.001,"The ledges and the colours read the same beds")

func _built(peak: RefCounted, i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= peak.nx-1 or j >= peak.nz-1: return false
	return _cell_top(peak,i,j) >= SkyPeak.CUT

func _cell_top(peak: RefCounted, i: int, j: int) -> float:
	var n: int = peak.nx
	return maxf(maxf(peak.heights[j*n+i],peak.heights[j*n+i+1]),maxf(peak.heights[(j+1)*n+i],peak.heights[(j+1)*n+i+1]))

## The range in sight of the plate, clear of every fixed island, of the
## islands' jet streams, and of islands and islets that turn up later.
func _clear_of_islands() -> void:
	var peak: RefCounted = shape(home_seed())
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	# The nearest rock over the sea to the plate's middle.
	var near_rock := INF
	for j in range(0,peak.nz,2):
		for i in range(0,peak.nx,2):
			if peak.heights[j*peak.nx+i] < SkyPeak.SEA: continue
			var p: Vector2 = peak.point(i,j)
			var w := SkyPeaks.HOME+Vector3(p.x,0.0,p.y).rotated(Vector3.UP,SkyPeaks.HOME_TURN)
			near_rock = minf(near_rock,Vector2(w.x,w.z).length())
	check(near_rock > 500.0 and near_rock < 1200.0,"The range stands within sight of the plate (its nearest rock %.0f m off)" % near_rock)
	var nearest := INF
	var rock_near := false
	for s: Vector3 in slots:
		nearest = minf(nearest,Vector2(s.x-SkyPeaks.HOME.x,s.z-SkyPeaks.HOME.z).length())
		# Round each island its chunk and some air: no rock stands there.
		for k in range(16):
			var p := s+Vector3(cos(TAU*k/16.0),0.0,sin(TAU*k/16.0))*60.0
			if _rock(peak,p) > s.y-60.0: rock_near = true
	check(nearest > SkyPeaks.KEEP,"Every fixed island stands clear of its middle (%.0f m)" % nearest)
	check(not rock_near,"No rock stands within 60 m of a fixed island, nor up to 60 m under one")
	var currents: Node3D = SkyCurrents.new()
	root.add_child(currents)
	currents.build(slots)
	var closest := INF
	for c: Dictionary in currents.currents:
		for p: Vector3 in c.points: closest = minf(closest,p.y-_rock(peak,p))
	check(closest > 30.0,"The islands' jet streams and thermals pass well clear of the rock (%.0f m over it at the closest)" % closest)
	currents.free()
	var cells := SkyCells.new(slots)
	var on_range := 0
	for x in range(-3,4):
		for z in range(-4,2):
			var s: Variant = cells.spot(Vector2i(x,z))
			if s != null and Vector2(s.x-SkyPeaks.HOME.x,s.z-SkyPeaks.HOME.z).length() < SkyPeaks.KEEP: on_range += 1
	check(on_range == 0,"No island turns up on the range")
	var islets: Node3D = SkyIslets.new()
	islets.cells = cells
	var islet_on := 0
	for x in range(-8,10):
		for z in range(-12,2):
			var s: Variant = islets.spot(Vector2i(x,z))
			if s != null and (Vector2(s.x-SkyPeaks.HOME.x,s.z-SkyPeaks.HOME.z).length() < SkyPeaks.KEEP or _rock(peak,s) > s.y-80.0): islet_on += 1
	check(islet_on == 0,"No islet stands on the range")
	islets.free()

## The rock's height under a home point (the range at HOME), or -INF.
func _rock(peak: RefCounted, p: Vector3) -> float:
	var local := (p-SkyPeaks.HOME).rotated(Vector3.UP,-SkyPeaks.HOME_TURN)
	var h: Variant = peak.height_at(Vector2(local.x,local.z))
	return -INF if h == null else float(h)

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
	check(peaks.built.has("0,0"),"Gliding off the plate, the range in sight of it is made (%d made in all)" % peaks.range_count())
	var b: Dictionary = peaks.built["0,0"]
	check(b.node.get_node_or_null("BodyFar") != null and (b.node.get_node("BodyFar").mesh as ArrayMesh).surface_get_array_len(0) < (b.node.get_node("Body").mesh as ArrayMesh).surface_get_array_len(0)/3,"Far off it draws a coarser body")
	var shape_now: RefCounted = b.shape
	check(shape_now.heights == shape(home_seed()).heights,"It is the range its spot's seed raises")
	# Solid under its summit, open over it.
	var summit: Vector3 = shape_now.summits[0]
	var under: Vector3 = peaks.global_of(b,Vector3(summit.x,0.0,summit.z))
	var body: Variant = peaks.body(under)
	check(body is Vector2 and absf((body as Vector2).x-summit.y) < 0.5 and (body as Vector2).y < SkyPeak.SEA-200.0,"Under its summit it is a solid from far under the cloud up to the summit")
	check(peaks.body(peaks.global_of(b,Vector3(SkyPeak.HALF.x+50.0,0.0,0.0))) == null,"Off it, open air")
	# Its jet runs down the gorge, away from the plate, clear of the walls.
	var jet: Dictionary = {}
	for c: Dictionary in currents.currents:
		if str(c.get("key","")) == "peak:0,0": jet = c
	check(not jet.is_empty() and jet.kind == "jet" and not jet.closed,"A jet stream runs down the gorge")
	if not jet.is_empty():
		var points: PackedVector3Array = jet.points
		var start: Vector3 = points[0]+currents.position
		var finish: Vector3 = points[points.size()-1]+currents.position
		check(Vector2(start.x,start.z).length() < Vector2(finish.x,finish.z).length(),"It runs away from the plate")
		var room := INF
		for p: Vector3 in points:
			var local: Vector3 = peaks.local_of(b,p+currents.position)
			for k in range(-2,3):
				var h: Variant = shape_now.height_at(Vector2(local.x+k*SkyCurrents.JET_RADIUS*0.5,local.z))
				if h != null: room = minf(room,p.y-float(h))
		check(room > 20.0,"Its core keeps clear of the gorge's walls (%.0f m over the rock at the closest)" % room)
	# A swap: the origin moves, the range with it.
	var before: Vector3 = peaks.global_of(b,Vector3.ZERO)
	cells.origin += Vector3(-300.0,0.0,40.0)
	peaks.advance(0.0,Vector3(-300.0,0.0,40.0))
	var moved: Vector3 = peaks.global_of(b,Vector3.ZERO)-before
	check(moved.is_equal_approx(Vector3(-300.0,0.0,40.0)),"It rides the swaps' origin")
	# Far off it goes, and its jet with it.
	for i in range(3): peaks.advance(1.0,Vector3(9000.0,0.0,9000.0)+cells.origin)
	var jets := 0
	for c: Dictionary in currents.currents:
		if str(c.get("key","")).begins_with("peak:"): jets += 1
	check(peaks.range_count() == 0 and jets == 0,"Far off it is let go, its jet with it")
	peaks.free()
	currents.free()

## Ranges scattered through the far cells: sparse, each its own height and
## spread, far apart, with no island or islet on one, and the same one for
## the same cell.
func _scattered() -> void:
	var cells := 0
	var held: Array[Vector3] = []
	var statures := {}
	var spreads := {}
	for x in range(-6,7):
		for z in range(-6,7):
			cells += 1
			var cell := Vector2i(x,z)
			var s: Variant = SkyPeaks.spot(cell)
			if s == null: continue
			held.append(Vector3(s.x,0.0,s.z))
			statures[snappedf(SkyPeaks.stature_of(cell),0.01)] = true
			spreads[snappedf(SkyPeaks.spread_of(cell),0.01)] = true
			if SkyPeaks.stature_of(cell) < SkyPeaks.STATURE.x-0.001 or SkyPeaks.spread_of(cell) > SkyPeaks.SPREAD.y+0.001: statures[-1] = true
	check(held.size() > 8 and held.size() < cells/2,"Ranges are scattered, sparsely (%d in %d cells)" % [held.size(),cells])
	check(statures.size() > 4 and spreads.size() > 4 and not statures.has(-1),"Each stands its own height and spread")
	var closest := INF
	for i in range(held.size()):
		for j in range(i+1,held.size()): closest = minf(closest,Vector2(held[i].x-held[j].x,held[i].z-held[j].z).length())
	check(closest > SkyPeaks.KEEP*SkyPeaks.SPREAD.y*2.0,"No two stand close (%.0f m at the closest)" % closest)
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var grid := SkyCells.new(slots)
	var on := 0
	for x in range(-30,31):
		for z in range(-30,31):
			var s: Variant = grid.spot(Vector2i(x,z))
			if s != null and SkyPeaks.blocks(s): on += 1
	check(on == 0,"No island turns up on any of them")
	var cell := SkyPeaks.cell_of(held[held.size()-1])
	var a: RefCounted = SkyPeak.make(SkyPeaks.seed_of(cell),SkyPeaks.stature_of(cell))
	check(a.top >= 150.0 and a.top <= 350.0,"A far one's summit stands in the band too (%.0f m)" % a.top)

## The glide against the rock: dived onto a gentle ledge it skims; flown at a
## cliff it is turned aside, never carried up the face, never inside it.
func _glide() -> void:
	var slots := [Vector3.ZERO]
	var peaks: Node3D = SkyPeaks.new()
	root.add_child(peaks)
	peaks.reset(SkyCells.new(slots),null)
	peaks.advance(1.0,Vector3.ZERO)
	peaks.flush()
	var b: Dictionary = peaks.built["0,0"]
	var peak: RefCounted = b.shape
	var ground := Callable(peaks,"body")
	# A steep face: a spot over 1.6 rise per metre, flown at level, at glide
	# height, straight up the slope.
	var face := _find(peak,func(slope: float, h: float) -> bool: return slope > 2.0 and h > 10.0 and h < 70.0)
	# A ledge, not a gully's floor between steep walls: gentle all round.
	var ledge := _find(peak,func(slope: float, h: float) -> bool: return slope < 0.35 and h > -40.0 and h < 80.0,0.7)
	check(not face.is_empty() and not ledge.is_empty(),"The range has steep faces and gentle ledges at glide height")
	if face.is_empty() or ledge.is_empty():
		peaks.free()
		return
	var glide := SkyGlide.new()
	glide.stone = Callable(peaks,"solid")
	var up: Vector2 = face.up
	var start: Vector3 = peaks.global_of(b,Vector3(face.at.x-up.x*30.0,float(face.h)-6.0,face.at.y-up.y*30.0))
	var heading_local := atan2(-up.x,-up.y)
	glide.launch(start,heading_local+float(b.turn),12.0,false)
	var inside := 0
	var climbed := 0.0
	var brushed := false
	for i in range(240):
		var was: Vector3 = glide.position
		glide.step(1.0/60.0,{},ground)
		var here: Variant = peaks.body(glide.position)
		if here != null and glide.position.y < (here as Vector2).x-0.05: inside += 1
		climbed = maxf(climbed,(glide.position.y-was.y)-Vector2(glide.position.x-was.x,glide.position.z-was.z).length()*SkyGlide.STEEP)
		brushed = brushed or glide.brushing
	check(brushed and inside == 0,"Flown at a cliff, it is turned aside along the face, never inside it (%d steps inside)" % inside)
	check(climbed < 0.5,"Nor is it carried up the face (%.2f m over the ride's limit in a step)" % climbed)
	var over: Vector3 = peaks.global_of(b,Vector3(ledge.at.x,float(ledge.h)+5.0,ledge.at.y))
	glide.launch(over,float(b.turn),6.0,false)
	var skimmed := false
	var low := INF
	for i in range(180):
		glide.step(1.0/60.0,{"dive":1.0},ground)
		skimmed = skimmed or glide.skimming
		var here: Variant = peaks.body(glide.position)
		if here != null: low = minf(low,glide.position.y-(here as Vector2).x)
	check(skimmed and low > -0.05,"Dived onto a ledge, it skims along it (%.2f m over the rock at the lowest)" % low)
	peaks.free()

## A grid point of the range where `want(slope, height)` holds, as {at,
## h, up (the way uphill)}.
## With `around` under INF, each of its eight neighbours must also rise
## less than that.
func _find(peak: RefCounted, want: Callable, around := INF) -> Dictionary:
	for j in range(10,peak.nz-10,3):
		for i in range(10,peak.nx-10,3):
			var g: Vector2 = peak._gradient(peak.heights,i,j)
			var h: float = peak.heights[j*peak.nx+i]
			var p: Vector2 = peak.point(i,j)
			# Clear of the gorge, which has its own walls.
			if absf(peak.gorge_distance(p)) < 120.0: continue
			var steepest := 0.0
			if around < INF:
				for dj in range(-1,2):
					for di in range(-1,2): steepest = maxf(steepest,(peak._gradient(peak.heights,i+di,j+dj) as Vector2).length())
			if steepest >= around: continue
			if want.call(g.length(),h): return {"at":p,"h":h,"up":g.normalized()}
	return {}

func _haze() -> void:
	var island := SkyHaze.fog(1000.0,0.0)
	var range_fog := SkyHaze.fog_far(1000.0,0.0,1.0)
	check(island > 0.95 and range_fog < 0.7,"A kilometre off, an island is gone in the haze (%.2f) but a range still shows (%.2f)" % [island,range_fog])
	check(is_equal_approx(SkyHaze.fog_far(420.0,-30.0,0.0),SkyHaze.fog(420.0,-30.0)),"Off a range the curve is the islands' own")
	var shader := FileAccess.get_file_as_string("res://shaders/glide_haze.gdshaderinc")
	check(shader.contains("ZS_PEAK_REACH = %s" % str(SkyHaze.PEAK_REACH)) and shader.contains("ZS_PEAK_WHOLE = %s" % str(SkyHaze.PEAK_WHOLE)),"The shader's range curve is the one here")
