extends SceneTree
## The sky tepui (scripts/sky_tepui.gd, scripts/sky_tepuis.gd): a seed always
## raises the same table mountain; its walls stand 200 to 350 m over the
## cloud sea and are sheer; its plateau is flat but uneven, with rock towers
## on it; its water runs downhill over its beds; each fall's lip is on the
## rim and its course is clear of rock all the way down, with a flyable gap
## behind the great fall's curtain the whole height of the glide's band;
## the faces end under the sea all round; it is a solid the glide skims on
## the plateau and is turned aside by at a wall, and can thread behind the
## fall; the one in sight of the plate is clear of the islands, the islets,
## the jet streams and the range; its updraft is open and rises over the
## plateau; and the haze keeps it in sight. Headless: shapes and queries
## only, nothing drawn.
const SkyTepui = preload("res://scripts/sky_tepui.gd")
const SkyTepuis = preload("res://scripts/sky_tepuis.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SEEDS := [101,2024,9]
var failures := 0
var shapes := {}

func _initialize() -> void:
	_same_seed()
	_walls()
	_plateau()
	_water()
	_falls()
	_gap()
	_base()
	_placement()
	_streaming()
	_glide()
	print("PASS: sky tepui" if failures == 0 else "FAIL: sky tepui")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func shape(seed_value: int) -> RefCounted:
	if not shapes.has(seed_value): shapes[seed_value] = SkyTepui.make(seed_value)
	return shapes[seed_value]

func all_seeds() -> Array:
	var out := [SkyTepuis.SEED]
	out.append_array(SEEDS)
	return out

func _same_seed() -> void:
	var a: RefCounted = shape(SkyTepuis.SEED)
	var b: RefCounted = SkyTepui.make(SkyTepuis.SEED)
	check(a.heights == b.heights and a.water == b.water and str(a.falls) == str(b.falls) and a.trees == b.trees,"A seed raises the same tepui")
	check(a.heights != shape(SEEDS[0]).heights,"Another seed raises another")

## Round the rim (away from the coves): the plateau's edge stands 200 to
## 350 m over the sea, and the wall under it is sheer, a hundred metres down
## within 25 m out from the rim's edge.
func _walls() -> void:
	for s: int in all_seeds():
		var t: RefCounted = shape(s)
		var tall := 0
		var sheer := 0
		var counted := 0
		var low := INF
		var high := -INF
		for k in range(96):
			var way := Vector2.from_angle(TAU*k/96.0)
			if _near_cove(t,way): continue
			var r: float = t.rim_radius(way)
			var top: Variant = t.height_at(way*(r-10.0))
			if top == null: continue
			counted += 1
			var wall := float(top)-SkyTepui.SEA
			low = minf(low,wall)
			high = maxf(high,wall)
			if wall >= 200.0 and wall <= 350.0: tall += 1
			# From the rim's edge, how far out the wall has fallen 100 m.
			var edge := -1.0
			var run := INF
			for m in range(0,120):
				var h: Variant = t.height_at(way*(r-25.0+m))
				var fall := float(top)-(float(h) if h != null else -INF)
				if edge < 0.0 and fall > 8.0: edge = m
				if edge >= 0.0 and fall > 108.0:
					run = m-edge
					break
			if run < 25.0: sheer += 1
		check(counted > 70 and tall == counted,"Seed %d: the walls stand 200 to 350 m over the sea all round (%.0f to %.0f m)" % [s,low,high])
		check(sheer > counted*0.85,"Seed %d: the walls are sheer (%d of %d fall 100 m within 25 m of the rim)" % [s,sheer,counted])
		check(t.ledges.size() >= 1 and float(t.ledges[0]) > SkyTepui.GLIDE_BAND.x and float(t.ledges[0]) < SkyTepui.GLIDE_BAND.y,"Seed %d: a ledge runs round at glide height (%.0f m)" % [s,t.ledges[0]])

func _near_cove(t: RefCounted, way: Vector2) -> bool:
	for f: Dictionary in t.falls:
		var r: float = t.rim_radius(f.out)
		var half: float = float(f.cove.x)+40.0
		if absf(angle_difference(way.angle(),(f.out as Vector2).angle())) < half/r: return true
	return false

## The plateau, well in from the rim and off the towers: flat but uneven
## (its 10th to 90th percentile 8 to 55 m apart), about its planned height;
## rock towers stand on it.
func _plateau() -> void:
	for s: int in all_seeds():
		var t: RefCounted = shape(s)
		var hs := []
		for j in range(0,t.nz,4):
			for i in range(0,t.nx,4):
				var p: Vector2 = t.point(i,j)
				if t.inside(p) < 50.0 or t.kinds[j*t.nx+i] == SkyTepui.KIND_TOWER: continue
				hs.append(t.heights[j*t.nx+i])
		hs.sort()
		var lo: float = hs[int(hs.size()*0.1)]
		var hi: float = hs[int(hs.size()*0.9)]
		var mid: float = hs[hs.size()/2]
		check(hs.size() > 1000 and hi-lo > 8.0 and hi-lo < 55.0,"Seed %d: the plateau is flat but uneven (%.0f m from its 10th to 90th percentile)" % [s,hi-lo])
		check(absf(mid-t.plateau) < 20.0,"Seed %d: it stands about its height (%.0f m, planned %.0f)" % [s,mid,t.plateau])
		var proud := 0
		for tw: Vector4 in t.towers:
			var h: Variant = t.height_at(Vector2(tw.x,tw.y))
			if h != null and float(h)-t._base(Vector2(tw.x,tw.y)) > 10.0: proud += 1
		check(proud >= 8,"Seed %d: rock towers stand on it (%d over 10 m proud)" % [s,proud])

## The streams run downhill (never rising along their course), their water
## stands over their beds, and there are pools.
func _water() -> void:
	for s: int in all_seeds():
		var t: RefCounted = shape(s)
		var downhill := true
		var dry := 0
		for stream: Array in t.streams:
			for k in range(1,stream.size()):
				if float(stream[k].level) > float(stream[k-1].level)+0.001: downhill = false
			for k in range(stream.size()-1):
				var h: Variant = t.height_at(stream[k].at)
				if h == null or float(h) > float(stream[k].level)-0.5: dry += 1
		var wet := 0
		for c in range(t.water.size()): wet += int(not is_nan(t.water[c]))
		var widest := 0.0
		for p: Dictionary in t.streams[0]: widest = maxf(widest,float(p.half))
		check(downhill and dry == 0,"Seed %d: the streams run downhill over their beds (%d dry points)" % [s,dry])
		check(t.streams.size() == 2 and wet > 300 and widest >= SkyTepui.POOL.x,"Seed %d: there are pools along the stream (%d wet points, widest %.0f m)" % [s,wet,widest])

## Each fall's lip is on the rim, at the channel's end: water behind it, a
## sheer drop in front; and its course is clear of rock all the way down.
func _falls() -> void:
	for s: int in all_seeds():
		var t: RefCounted = shape(s)
		for f: Dictionary in t.falls:
			var lip: Vector3 = f.lip
			var way: Vector2 = f.out
			var at := Vector2(lip.x,lip.z)
			var behind: Variant = t.height_at(at-way*3.0)
			var front: Variant = t.height_at(at+way*4.0)
			var on_rim: bool = behind != null and float(behind) < lip.y and float(behind) > lip.y-SkyTepui.DEPTH-2.0 and (front == null or float(front) < lip.y-30.0)
			check(on_rim,"Seed %d: the %s fall's lip is on the rim (behind %.1f, in front %s, lip %.1f m)" % [s,"great" if f.main else "small",float(behind) if behind != null else -INF,str(front),lip.y])
			var across := Vector2(way.y,-way.x)
			var worst := INF
			var d := 3.0
			while d <= float(f.drop):
				var p := SkyTepui.fall_point(f,d)
				var half := SkyTepui.fall_half(f,d)
				var thick := SkyTepui.fall_thick(f,d)
				for u in [-1.0,-0.5,0.0,0.5,1.0]:
					for v in [-1.0,0.0,1.0]:
						var q := Vector2(p.x,p.z)+across*half*float(u)+way*thick*float(v)
						var h: Variant = t.height_at(q)
						if h != null: worst = minf(worst,p.y-float(h))
				d += 3.0
			check(worst > 2.0 and float(f.drop) > 200.0,"Seed %d: the %s fall drops %.0f m clear of rock (%.1f m over it at the closest)" % [s,"great" if f.main else "small",f.drop,worst])

## Behind the great fall's curtain, at every height in the glide's band, a
## gap of at least GAP m to the rock, open across the curtain's width; and
## rock behind it (an alcove, not open sky).
func _gap() -> void:
	for s: int in all_seeds():
		var t: RefCounted = shape(s)
		var f: Dictionary = t.falls[0]
		var lip: Vector3 = f.lip
		var way: Vector2 = f.out
		var across := Vector2(way.y,-way.x)
		var least := INF
		var most := 0.0
		var blocked := 0
		var y := SkyTepui.GLIDE_BAND.x
		while y <= SkyTepui.GLIDE_BAND.y:
			var g: float = t.gap(y)
			least = minf(least,g)
			most = maxf(most,g)
			var d := lip.y-y
			var p := SkyTepui.fall_point(f,d)
			var middle: Vector2 = Vector2(p.x,p.z)-way*(SkyTepui.fall_thick(f,d)+g*0.5)
			var half := SkyTepui.fall_half(f,d)
			for k in range(-4,5):
				var h: Variant = t.height_at(middle+across*half*k/4.0)
				if h != null and float(h) > y-6.0: blocked += 1
			y += 5.0
		check(least >= SkyTepui.GAP and blocked == 0,"Seed %d: behind the great fall there is a flyable gap the whole band (%.0f to %.0f m)" % [s,least,most])
		check(most < 70.0,"Seed %d: the gap is an alcove, rock close behind it" % s)

## The faces stop only under the sea, and run on past it.
func _base() -> void:
	for s: int in [SkyTepuis.SEED,SEEDS[1]]:
		var t: RefCounted = shape(s)
		var highest_rim := -INF
		var lowest := INF
		for j in range(t.nz-1):
			for i in range(t.nx-1):
				if not _built(t,i,j): continue
				lowest = minf(lowest,_cell_top(t,i,j))
				var rim: bool = i == 0 or j == 0 or i == t.nx-2 or j == t.nz-2
				if not rim:
					for o: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
						if not _built(t,i+o.x,j+o.y): rim = true
				# A sheer face may stand over its last cell's far corner: what
				# counts is that the faces reach down under the sea there.
				if rim: highest_rim = maxf(highest_rim,_cell_bottom(t,i,j))
		check(highest_rim < SkyTepui.SEA-20.0,"Seed %d: the faces end well under the cloud sea all round (highest edge's foot %.0f m)" % [s,highest_rim])
		check(lowest < SkyTepui.SEA-20.0,"Seed %d: the walls run on down past the sea (to %.0f m)" % [s,lowest])
	var t: RefCounted = shape(SkyTepuis.SEED)
	var arrays: Array = t.body_arrays([Color.GREEN],[Color.GRAY],Color.WHITE,SkyTepuis.OFF_MAP)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# The faces lie on the heights the glide reads: the plateau's on them,
	# and every wall's within a grid cell or so of where the heightfield
	# passes through its height (the walls are sheer: a cell across is many
	# metres up).
	var worst := 0.0
	var tried := 0
	for k in range(0,vertices.size(),331):
		var v := vertices[k]-SkyTepuis.OFF_MAP
		if v.y < SkyTepui.CUT: continue
		tried += 1
		var found := INF
		var lo := INF
		var hi := -INF
		for ring in range(0,9):
			var reach := ring*0.75
			for m in range(16 if ring > 0 else 1):
				var h: Variant = t.height_at(Vector2(v.x,v.z)+Vector2.from_angle(TAU*m/16.0)*reach+Vector2(0.01,0.01))
				if h == null: continue
				lo = minf(lo,float(h))
				hi = maxf(hi,float(h))
			if lo <= v.y+1.0 and hi >= v.y-1.0:
				found = reach
				break
		worst = maxf(worst,found)
	check(vertices.size()/3 < 200000 and tried > 300 and worst <= 6.0,"The tepui is one surface of %d faces, lying on the heights the glide reads (within %.1f m)" % [vertices.size()/3,worst])
	var water: Array = t.water_arrays(Color.BLUE)
	check(not water.is_empty() and (water[Mesh.ARRAY_CUSTOM0] as PackedFloat32Array).size() == (water[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()*4,"Its water is one surface for the pond water")

func _cell_bottom(t: RefCounted, i: int, j: int) -> float:
	var n: int = t.nx
	return minf(minf(t.heights[j*n+i],t.heights[j*n+i+1]),minf(t.heights[(j+1)*n+i],t.heights[(j+1)*n+i+1]))

func _built(t: RefCounted, i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= t.nx-1 or j >= t.nz-1: return false
	return _cell_top(t,i,j) >= SkyTepui.CUT

func _cell_top(t: RefCounted, i: int, j: int) -> float:
	var n: int = t.nx
	return maxf(maxf(t.heights[j*n+i],t.heights[j*n+i+1]),maxf(t.heights[(j+1)*n+i],t.heights[(j+1)*n+i+1]))

## The rock's height under a home point (the tepui at HOME), or -INF.
func _rock(t: RefCounted, p: Vector3) -> float:
	var local := (p-SkyTepuis.HOME).rotated(Vector3.UP,-SkyTepuis.HOME_TURN)
	var h: Variant = t.height_at(Vector2(local.x,local.z))
	return -INF if h == null else float(h)

## The tepui in sight of the plate: within view, clear of every fixed
## island, of the islands' currents, of islands and islets that turn up
## later, and of the mountain range.
func _placement() -> void:
	var t: RefCounted = shape(SkyTepuis.SEED)
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	var near_rock := INF
	var rock_points := []
	for j in range(0,t.nz,3):
		for i in range(0,t.nx,3):
			if t.heights[j*t.nx+i] < SkyTepui.SEA: continue
			var p: Vector2 = t.point(i,j)
			var w := SkyTepuis.HOME+Vector3(p.x,0.0,p.y).rotated(Vector3.UP,SkyTepuis.HOME_TURN)
			rock_points.append(w)
			near_rock = minf(near_rock,Vector2(w.x,w.z).length())
	check(near_rock > 500.0 and near_rock < 1200.0,"The tepui stands within sight of the plate (its nearest rock %.0f m off)" % near_rock)
	var nearest := INF
	var rock_near := false
	for s: Vector3 in slots:
		nearest = minf(nearest,Vector2(s.x-SkyTepuis.HOME.x,s.z-SkyTepuis.HOME.z).length())
		for k in range(16):
			var p := s+Vector3(cos(TAU*k/16.0),0.0,sin(TAU*k/16.0))*60.0
			if _rock(t,p) > s.y-60.0: rock_near = true
	check(nearest > SkyTepuis.KEEP and not rock_near,"Every fixed island stands clear of it (%.0f m from its middle)" % nearest)
	# The range's rock and the tepui's never come within 150 m.
	var range_shape: RefCounted = SkyPeak.make(SkyPeaks.seed_of(Vector2i.ZERO))
	var closest := INF
	var range_points := []
	for j in range(0,range_shape.nz,4):
		for i in range(0,range_shape.nx,4):
			if range_shape.heights[j*range_shape.nx+i] < SkyPeak.SEA: continue
			var p: Vector2 = range_shape.point(i,j)
			range_points.append(SkyPeaks.HOME+Vector3(p.x,0.0,p.y).rotated(Vector3.UP,SkyPeaks.HOME_TURN))
	for k in range(0,rock_points.size(),7):
		var a: Vector3 = rock_points[k]
		for b: Vector3 in range_points: closest = minf(closest,Vector2(a.x-b.x,a.z-b.z).length())
	check(closest > 150.0,"It stands clear of the mountain range (%.0f m between their rock)" % closest)
	check(not SkyTepuis.blocks(SkyPeaks.HOME) and SkyPeaks.blocks(SkyTepuis.HOME),"The range's middle is clear of it, and nothing turns up on it")
	# The ranges scattered through the far cells: their whole frame, spread,
	# stands clear of its rock.
	var worst := INF
	var cell := SkyPeaks.cell_of(SkyTepuis.HOME)
	for dx in range(-2,3):
		for dz in range(-2,3):
			var c := cell+Vector2i(dx,dz)
			var sp: Variant = SkyPeaks.spot(c)
			if sp == null or c == Vector2i.ZERO: continue
			var far: float = Vector2(sp.x-SkyTepuis.HOME.x,sp.z-SkyTepuis.HOME.z).length()-SkyPeak.HALF.length()*SkyPeaks.spread_of(c)-t.reach()
			worst = minf(worst,far)
	check(worst > 50.0,"It stands clear of the ranges scattered round it (%.0f m to spare at the least)" % worst)
	var currents: Node3D = SkyCurrents.new()
	root.add_child(currents)
	currents.build(slots)
	var lowest := INF
	for c: Dictionary in currents.currents:
		for p: Vector3 in c.points: lowest = minf(lowest,p.y-_rock(t,p))
	check(lowest > 30.0,"The islands' jet streams and thermals pass well clear of it (%.0f m over its rock at the closest)" % lowest)
	currents.free()
	var cells := SkyCells.new(slots)
	var on := 0
	for x in range(-6,2):
		for z in range(-5,2):
			var s: Variant = cells.spot(Vector2i(x,z))
			if s != null and (Vector2(s.x-SkyTepuis.HOME.x,s.z-SkyTepuis.HOME.z).length() < SkyTepuis.KEEP or _rock(t,s) > s.y-80.0): on += 1
	check(on == 0,"No island turns up on it")
	var islets: Node3D = SkyIslets.new()
	islets.cells = cells
	var islet_on := 0
	for x in range(-14,0):
		for z in range(-12,4):
			var s: Variant = islets.spot(Vector2i(x,z))
			if s != null and (_rock(t,s) > s.y-80.0 or _near_fall(t,s)): islet_on += 1
	check(islet_on == 0,"No islet stands on it or in its falls")
	islets.free()

func _near_fall(t: RefCounted, home: Vector3) -> bool:
	var local := (home-SkyTepuis.HOME).rotated(Vector3.UP,-SkyTepuis.HOME_TURN)
	for f: Dictionary in t.falls:
		var foot := SkyTepui.fall_point(f,float(f.drop))
		if Vector2(local.x-foot.x,local.z-foot.z).length() < 120.0: return true
	return false

## Made gliding off the plate; a solid under its plateau, open over it;
## its updraft added, open and rising over the plateau; it rides the swaps'
## origin and is let go far off, its updraft with it; the haze keeps it.
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
	var tepuis: Node3D = peaks.tepuis
	check(tepuis.tepui_count() == 1,"Gliding off the plate, the tepui in sight of it is made (%d)" % tepuis.tepui_count())
	if tepuis.tepui_count() == 0:
		peaks.free()
		currents.free()
		return
	var b: Dictionary = tepuis.built.values()[0]
	var t: RefCounted = b.shape
	check(t.heights == shape(SkyTepuis.SEED).heights,"It is the tepui its seed raises")
	var middle: Vector3 = tepuis.global_of(b,Vector3(0.0,0.0,-40.0))
	var body: Variant = peaks.body(middle)
	var h: Variant = t.height_at(Vector2(0.0,-40.0))
	check(body is Vector2 and h != null and absf((body as Vector2).x-float(h)) < 0.01 and (body as Vector2).y < SkyTepui.SEA-200.0,"Through the peaks, under its plateau it is a solid from far under the cloud")
	check(peaks.solid(middle) and peaks.body(tepuis.global_of(b,Vector3(SkyTepui.HALF+60.0,0.0,0.0))) == null,"It is stone to the glide; off it, open air")
	var lift: Dictionary = {}
	for c: Dictionary in currents.currents:
		if str(c.get("key","")).begins_with("tepui:"): lift = c
	check(not lift.is_empty() and lift.kind == "thermal","Its updraft rises beside the great fall")
	if not lift.is_empty():
		var points: PackedVector3Array = lift.points
		var top: Vector3 = points[points.size()-1]+currents.position
		var room := INF
		for p: Vector3 in points:
			for k in range(8):
				var q: Vector3 = p+currents.position+Vector3(cos(TAU*k/8.0),0.0,sin(TAU*k/8.0))*float(lift.radius)
				var under: Variant = tepuis.body(q)
				if under != null: room = minf(room,q.y-(under as Vector2).x)
		check(top.y > t.top+10.0 and room > 5.0,"It rises clear of the walls (%.0f m at the closest) to over the plateau (%.0f m, top %.0f)" % [room,top.y,t.top])
		var air: Dictionary = currents.air_at(points[points.size()/2]+currents.position)
		check(float(air.thermal) > 0.9 and (air.wind as Vector3).y > 5.0,"In it the air lifts (%.1f m/s)" % (air.wind as Vector3).y)
	var spots: Array = peaks.haze_spots(Vector3.ZERO)
	var seen := false
	for sp: Vector4 in spots: seen = seen or Vector2(sp.x-b.home.x,sp.y-b.home.z).length() < 1.0
	check(seen,"The haze knows it as a landform")
	var before: Vector3 = tepuis.global_of(b,Vector3.ZERO)
	cells.origin += Vector3(-300.0,0.0,40.0)
	peaks.advance(0.0,Vector3(-300.0,0.0,40.0))
	check((tepuis.global_of(b,Vector3.ZERO)-before).is_equal_approx(Vector3(-300.0,0.0,40.0)) and peaks.solid(middle+Vector3(-300.0,0.0,40.0)),"It rides the swaps' origin")
	for i in range(3): peaks.advance(1.0,Vector3(9000.0,0.0,9000.0)+cells.origin)
	var lifts := 0
	for c: Dictionary in currents.currents:
		if str(c.get("key","")).begins_with("tepui:"): lifts += 1
	check(tepuis.tepui_count() == 0 and lifts == 0,"Far off it is let go, its updraft with it")
	peaks.free()
	currents.free()

## The glide against it: flown at a wall it is turned aside, never inside;
## dived onto the plateau it skims; and threaded behind the great fall's
## curtain, it passes through the gap without touching rock.
func _glide() -> void:
	var peaks: Node3D = SkyPeaks.new()
	root.add_child(peaks)
	peaks.reset(SkyCells.new([Vector3.ZERO]),null)
	peaks.advance(1.0,Vector3.ZERO)
	peaks.flush()
	var tepuis: Node3D = peaks.tepuis
	var b: Dictionary = tepuis.built.values()[0]
	var t: RefCounted = b.shape
	var ground := Callable(peaks,"body")
	var glide := SkyGlide.new()
	glide.stone = Callable(peaks,"solid")
	# At a wall away from the coves, flown straight in over the ledge.
	var way := Vector2.from_angle(PI*0.5+2.6)
	while _near_cove(t,way): way = way.rotated(0.3)
	var r: float = t.rim_radius(way)
	var start: Vector3 = tepuis.global_of(b,Vector3(way.x*(r+60.0),118.0,way.y*(r+60.0)))
	var heading := atan2(way.x,way.y)+float(b.turn)
	glide.launch(start,heading,12.0,false)
	var inside := 0
	var brushed := false
	var climbed := 0.0
	for i in range(600):
		var was: Vector3 = glide.position
		glide.step(1.0/60.0,{},ground)
		var here: Variant = peaks.body(glide.position)
		if here != null and glide.position.y < (here as Vector2).x-0.05: inside += 1
		climbed = maxf(climbed,(glide.position.y-was.y)-Vector2(glide.position.x-was.x,glide.position.z-was.z).length()*SkyGlide.STEEP)
		brushed = brushed or glide.brushing
	check(brushed and inside == 0 and climbed < 0.5,"Flown at a wall, it is turned aside along it, never inside it nor carried up it (%d steps inside)" % inside)
	# Onto the plateau.
	var over: Vector3 = tepuis.global_of(b,Vector3(-60.0,float(t.height_at(Vector2(-60.0,-60.0)))+5.0,-60.0))
	glide.launch(over,float(b.turn),6.0,false)
	var skimmed := false
	var low := INF
	for i in range(180):
		glide.step(1.0/60.0,{"dive":1.0},ground)
		skimmed = skimmed or glide.skimming
		var here: Variant = peaks.body(glide.position)
		if here != null: low = minf(low,glide.position.y-(here as Vector2).x)
	check(skimmed and low > -0.05,"Dived onto the plateau, it skims along it (%.2f m over the rock at the lowest)" % low)
	# Behind the curtain: from one side of the cove to the other at 40 m.
	var f: Dictionary = t.falls[0]
	var lip: Vector3 = f.lip
	var out: Vector2 = f.out
	var across := Vector2(out.y,-out.x)
	var d := lip.y-40.0
	var at := SkyTepui.fall_point(f,d)
	var middle: Vector2 = Vector2(at.x,at.z)-out*(SkyTepui.fall_thick(f,d)+t.gap(40.0)*0.5)
	var from: Vector2 = middle-across*30.0
	glide.launch(tepuis.global_of(b,Vector3(from.x,40.0,from.y)),atan2(-across.x,-across.y)+float(b.turn),12.0,false)
	glide.airborne = 10.0
	var touched := false
	var passed := false
	for i in range(480):
		glide.step(1.0/60.0,{"rise":0.6},ground)
		touched = touched or glide.brushing or glide.skimming
		var local: Vector3 = tepuis.local_of(b,glide.position)
		if (Vector2(local.x,local.z)-middle).dot(across) > 30.0:
			passed = true
			break
	check(passed and not touched,"Threaded behind the great fall's curtain, it passes through without touching rock")
	peaks.free()
