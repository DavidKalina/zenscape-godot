extends RefCounted
## The Peak's carve: things to fly past on the way up the mountain, hand-sited on
## seed 1 in the massif's frame (a along the facing, v across it, y over the sea;
## PeakMassif). Two lines climb it from the nose of the prow to the spires, either
## side of one wall of rock:
##
##   the Dike      a sheet of basalt on the prow's main crest, DIKE; its HOLES cross
##                 from one line to the other
##   the Sills     walls across the Slot (SILLS, SILL_HOLES): a choice of gaps
##   the Slot      the hanging valley between the prow's two crests, -v of the Dike,
##                 then up tower 0's root: rock, BLADES and EYES (LINE_SLOT)
##   the Bench     the shelf +v of the Dike over the rock gorge, then up tower 2's
##                 root: the pilgrims' gates and arcades, RUINS (LINE_BENCH)
##
## The tables were fitted to the land: a line runs 15 to 25 m over the highest ground
## across its width, and a hole stands on the crest's teeth. A change to the land
## wants them refitted. Nothing stands on a gorge's floor, the strip, the apron or
## the strip's lanes, and nothing stands on a spire: the outline stays the mountain's.
##
## A pure function of the land: `specs` is the same on every worker. Each piece is a
## spec for LandArches (arch_build.gd builds it, land_arches.gd streams it and answers
## the flight, so the near misses, camera and wheels read it as they read any arch),
## named `peak/carve/<kind>/<n>` and placed through scripts/layout_overrides.gd.
##
## --peak-carve=0 stands none of it.

const Field = preload("res://scripts/endless/land_field.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const CELL := 480.0

## The way each line is flown: [a, v, y over the sea], in order up the mountain.
## Pieces stand off these by hand; a gate stands on them.
const LINE_SLOT := [[2060.0,-30.0,335.0],[1960.0,-30.0,355.0],[1900.0,-30.0,395.0],[1830.0,-30.0,455.0],[1770.0,-25.0,520.0],[1710.0,5.0,562.0],[1660.0,35.0,540.0],[1600.0,40.0,516.0],[1550.0,40.0,548.0],[1500.0,40.0,592.0],[1400.0,45.0,608.0],[1300.0,40.0,632.0],[1250.0,45.0,606.0],[1200.0,62.0,632.0],[1150.0,70.0,642.0],[1100.0,60.0,684.0],[1025.0,50.0,692.0],[950.0,70.0,720.0],[875.0,60.0,746.0],[800.0,60.0,763.0],[750.0,50.0,746.0],[700.0,50.0,756.0],[650.0,60.0,804.0],[575.0,80.0,820.0],[510.0,105.0,836.0],[450.0,90.0,848.0],[395.0,10.0,870.0],[350.0,-90.0,912.0],[320.0,-190.0,950.0],[285.0,-280.0,962.0],[250.0,-330.0,955.0],[150.0,-360.0,935.0],[60.0,-360.0,945.0],[0.0,-350.0,975.0],[-50.0,-345.0,1020.0],[-100.0,-340.0,1085.0],[-150.0,-340.0,1150.0],[-185.0,-300.0,1200.0],[-205.0,-250.0,1250.0]]
const LINE_BENCH := [[2000.0,220.0,345.0],[1850.0,270.0,368.0],[1790.0,320.0,440.0],[1735.0,320.0,520.0],[1675.0,285.0,612.0],[1625.0,262.0,596.0],[1550.0,252.0,572.0],[1500.0,258.0,580.0],[1450.0,250.0,600.0],[1400.0,250.0,590.0],[1350.0,258.0,612.0],[1300.0,274.0,636.0],[1200.0,300.0,658.0],[1150.0,320.0,658.0],[1100.0,320.0,620.0],[1050.0,320.0,664.0],[1000.0,340.0,714.0],[950.0,340.0,718.0],[900.0,340.0,670.0],[825.0,350.0,678.0],[750.0,350.0,728.0],[650.0,350.0,756.0],[620.0,375.0,760.0],[560.0,395.0,756.0],[500.0,405.0,758.0],[450.0,410.0,805.0],[380.0,440.0,838.0],[300.0,470.0,842.0],[200.0,490.0,838.0],[120.0,500.0,893.0],[30.0,520.0,1008.0],[-30.0,535.0,1083.0],[-85.0,510.0,1145.0],[-125.0,470.0,1205.0]]

## The Dike, on the main crest: [a, v, top y over the sea, half thickness at the foot].
const DIKE := [[1810.0,150.0,610.0,14.0],[1720.0,150.0,740.0,18.0],[1640.0,150.0,745.0,18.0],[1550.0,130.0,735.0,16.0],[1450.0,150.0,785.0,18.0],[1350.0,150.0,840.0,20.0],[1250.0,180.0,865.0,20.0],[1150.0,170.0,855.0,18.0],[1050.0,150.0,865.0,20.0],[990.0,170.0,865.0,20.0],[900.0,190.0,900.0,22.0],[800.0,175.0,895.0,20.0],[715.0,175.0,880.0,16.0]]
## Its holes: [a, v, y over the sea, width, height (toy, WorldScale.opening; twice
## that in m at the defaults, as half sizes here), way (da, dv, dy)].
const HOLES := [
	[1570.0,132.0,672.0,18.0,22.0,[-0.75,1.0,0.25]],
	[1480.0,146.0,722.0,13.0,26.0,[-0.75,-1.0,-0.15]],
	[1365.0,150.0,778.0,20.0,18.0,[-0.8,1.0,0.1]],
	[1160.0,170.0,796.0,20.0,24.0,[-0.8,-1.0,-0.3]],
	[1040.0,150.0,808.0,19.0,22.0,[-0.8,1.0,0.1]],
	[860.0,185.0,868.0,17.0,16.0,[-0.8,-1.0,-0.2]],
]
## The Sills, across the Slot, each its own wall: its line, as DIKE.
const SILLS := [
	[[1195.0,-100.0,850.0,18.0],[1176.0,20.0,800.0,20.0],[1180.0,135.0,855.0,18.0]],
	[[770.0,-70.0,885.0,16.0],[748.0,50.0,860.0,18.0],[755.0,140.0,890.0,16.0]],
]
## Their gaps: as HOLES, the sill's number first.
const SILL_HOLES := [
	[0,1178.0,66.0,644.0,22.0,28.0,[-1.0,0.0,0.08]],
	[0,1187.0,-30.0,772.0,14.0,24.0,[-1.0,0.0,0.25]],
	[0,1178.0,105.0,762.0,17.0,17.0,[-1.0,-0.2,0.2]],
	[1,750.0,52.0,746.0,19.0,25.0,[-1.0,0.0,0.05]],
	[1,757.0,-30.0,830.0,18.0,24.0,[-1.0,0.1,0.42]],
]
## Short walls across a line with one eye on it: [line (0 Slot, 1 Bench), a, half width,
## half height, wall's half length, its top over the eye's middle, half thickness].
## The eye's way is the line's, climb and all.
const EYES := [
	[0,1704.0,22.0,26.0,48.0,64.0,12.0],
	[0,1400.0,19.0,22.0,40.0,60.0,12.0],
	[0,960.0,19.0,22.0,40.0,60.0,12.0],
	[0,520.0,19.0,22.0,44.0,62.0,12.0],
	[0,280.0,20.0,22.0,46.0,60.0,12.0],
	[0,20.0,23.0,30.0,52.0,60.0,12.0],
	[0,-60.0,23.0,30.0,50.0,58.0,12.0],
	[0,-125.0,23.0,30.0,48.0,56.0,12.0],
	[1,90.0,22.0,26.0,46.0,56.0,12.0],
	[1,-30.0,23.0,30.0,48.0,56.0,12.0],
]
## The Slot's fins, in groups: each [name, [a, off (m from the line, + toward +v),
## height over the ground (and 0.6 of it over the line), half long, half thin, yaw off the line (deg), tilt]...].
const BLADES := [
	["nose",[1815.0,-33.0,95.0,24.0,9.0,8.0,10.0],[1815.0,33.0,110.0,24.0,9.0,-6.0,-12.0]],
	["lip",[1645.0,-25.0,56.0,24.0,7.0,5.0,8.0],[1595.0,25.0,60.0,26.0,7.0,-4.0,-8.0],[1545.0,-25.0,60.0,24.0,7.0,4.0,8.0],[1495.0,25.0,60.0,24.0,7.0,-4.0,-8.0]],
	["run1",[1345.0,-25.0,66.0,24.0,8.0,6.0,8.0],[1290.0,25.0,62.0,26.0,7.0,-6.0,-8.0],[1235.0,-25.0,60.0,24.0,7.0,4.0,8.0]],
	["run2",[1085.0,25.0,66.0,26.0,8.0,6.0,10.0],[1030.0,-25.0,70.0,26.0,8.0,-6.0,-10.0],[890.0,25.0,70.0,26.0,8.0,6.0,10.0],[835.0,-25.0,72.0,26.0,8.0,-5.0,-10.0]],
	["top",[665.0,25.0,64.0,24.0,8.0,5.0,8.0],[610.0,-25.0,66.0,24.0,8.0,-5.0,-8.0],[560.0,25.0,62.0,22.0,7.0,6.0,8.0]],
	["over",[325.0,-25.0,50.0,22.0,8.0,0.0,8.0]],
]

## The ruins on the Bench: [kind, a, opening (toy width), spans]; "gate" a pointed
## arch on the line, "arcade" a run of spans across it.
const RUINS := [
	["gate",1650.0,15.0,0],
	["gate",1590.0,14.0,0],
	["arcade",1490.0,14.0,3],
	["gate",1390.0,15.0,0],
	["gate",1290.0,14.0,0],
	["arcade",1190.0,15.0,3],
	["gate",1095.0,15.0,0],
	["gate",1000.0,14.0,0],
	["arcade",905.0,14.0,3],
	["gate",815.0,14.0,0],
	["gate",720.0,15.0,0],
	["arcade",625.0,14.0,3],
	["gate",520.0,15.0,0],
	["gate",430.0,15.0,0],
	["arcade",310.0,15.0,3],
]

static var _cache := {}
static var _lock := Mutex.new()
## A gate's grid (m): `gates_grid` keys.
const GATE_CELL := 128.0
## How far past its opening a pass still counts (m): the solid stops a wing long before.
const GATE_SLACK := 2.0

static func wanted() -> bool:
	return not "--peak-carve=0" in LaunchArgs.user_args()

## The specs of world cell (cx, cz) added to `specs`.
static func with_arches(field: RefCounted, cx: int, cz: int, specs: Array) -> Array:
	var got: Dictionary = _all(field)
	var mine: Variant = got.get(Vector2i(cx,cz))
	if mine == null: return specs
	var out := specs.duplicate()
	out.append_array(mine)
	return out

## Every opening a plane threads, by grid cell: {Vector2i: [{c, n, r, u, w, h, name}...]}.
## `n` the way through, `r` and `u` across and up it, w and h its half sizes.
static func gates_grid(field: RefCounted) -> Dictionary:
	if not wanted() or not field.has_method("peak"): return {}
	var peak: RefCounted = field.peak()
	if peak == null: return {}
	var list: Array = []
	var add := func(name: String, c: Vector3, n: Vector3, w: float, h: float) -> void:
		var r := Vector3.UP.cross(n).normalized()
		list.append({"c":c,"n":n,"r":r,"u":n.cross(r).normalized(),"w":w,"h":h,"name":name})
	for k in HOLES.size():
		var h: Array = HOLES[k]
		add.call("dike/%d" % k,at(peak,float(h[0]),float(h[1]),float(h[2])),way(peak,h[5]),_half(h[3]),_half(h[4]))
	for k in SILL_HOLES.size():
		var h: Array = SILL_HOLES[k]
		add.call("sill/%d" % k,at(peak,float(h[1]),float(h[2]),float(h[3])),way(peak,h[6]),_half(h[4]),_half(h[5]))
	for k in EYES.size():
		var e: Array = EYES[k]
		var table: Array = LINE_BENCH if int(e[0]) == 1 else LINE_SLOT
		var on := _on(table,float(e[1]))
		add.call("eye/%d" % k,at(peak,float(e[1]),on.x,on.y),_tangent(peak,table,float(e[1])),_half(e[2]),_half(e[3]))
	for k in RUINS.size():
		var r: Array = RUINS[k]
		var on := _on(LINE_BENCH,float(r[1]))
		var wide := WorldScale.opening(float(r[2]))
		add.call("ruin/%d" % k,at(peak,float(r[1]),on.x,on.y),_tangent(peak,LINE_BENCH,float(r[1])),wide*0.5,wide*0.9)
	var out := {}
	for g: Dictionary in list:
		var c: Vector3 = g.c
		var key := Vector2i(floori(c.x/GATE_CELL),floori(c.z/GATE_CELL))
		for dz in range(-1,2):
			for dx in range(-1,2):
				var q := key+Vector2i(dx,dz)
				if not out.has(q): out[q] = []
				(out[q] as Array).append(g)
	return out

## The cells that hold a piece: {Vector2i: true}.
static func cells(field: RefCounted) -> Dictionary:
	var out := {}
	for k: Vector2i in _all(field): out[k] = true
	return out

## Every spec, by cell.
static func _all(field: RefCounted) -> Dictionary:
	if not wanted() or not field.has_method("peak"): return {}
	var peak: RefCounted = field.peak()
	if peak == null: return {}
	var key := [int(field.seed),peak.centre,peak.facing]
	_lock.lock()
	var got: Variant = _cache.get(key)
	_lock.unlock()
	if got != null: return got
	var out := {}
	for s: Dictionary in _plan(field,peak):
		var p: Vector3 = s.pos
		var c := Vector2i(floori(p.x/CELL),floori(p.z/CELL))
		if not out.has(c): out[c] = []
		(out[c] as Array).append(s)
	_lock.lock()
	_cache[key] = out
	_lock.unlock()
	return out

## World position of (a, v) at `y` over the sea.
static func at(peak: RefCounted, a: float, v: float, y: float) -> Vector3:
	var w: Vector2 = peak.world(a,v)
	return Vector3(w.x,y+Field.SEA_Y,w.y)

## A way (da, dv, dy) in world space.
static func way(peak: RefCounted, d: Array) -> Vector3:
	var o: Vector2 = peak.world(0.0,0.0)
	var w: Vector2 = peak.world(float(d[0]),float(d[1]))-o
	return Vector3(w.x,float(d[2]),w.y).normalized()

## The line's points in world space: LINE_SLOT or LINE_BENCH.
static func line(peak: RefCounted, table: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for r: Array in table: out.append(at(peak,float(r[0]),float(r[1]),float(r[2])))
	return out

static func _plan(field: RefCounted, peak: RefCounted) -> Array:
	var out: Array = []
	_dike(out,field,peak)
	_sills(out,field,peak)
	_eyes(out,field,peak)
	_blades(out,field,peak)
	_ruins(out,field,peak)
	return out

static func _rock_spec(field: RefCounted, name: String, pos: Vector3, prims: Array, cell := 3.0) -> Dictionary:
	return {"kind":"rock","carve":true,"name":name,"form":"carve","pos":pos,"yaw":0.0,"seed":hash([int(field.seed),name]),"prims":prims,"cell":cell,"foot":[],"reach":0.0}

## A run of a wall's line as one prim, `o` its local origin.
static func _wall_prim(peak: RefCounted, rows: Array, o: Vector3) -> Dictionary:
	var pts: Array = []
	var tops: Array = []
	var half: Array = []
	for r: Array in rows:
		var p := at(peak,float(r[0]),float(r[1]),float(r[2]))-o
		pts.append(Vector2(p.x,p.z))
		tops.append(p.y)
		half.append(float(r[3]))
	return {"wall":pts,"tops":tops,"half":half}

## A half size in the tables is a toy width's: half of WorldScale.opening.
static func _half(toy: Variant) -> float:
	return WorldScale.opening(float(toy))*0.5

static func _hole_prim(peak: RefCounted, r: Array, o: Vector3) -> Dictionary:
	return {"hole":at(peak,float(r[0]),float(r[1]),float(r[2]))-o,"way":way(peak,r[5]),"w":_half(r[3]),"h":_half(r[4]),"deep":60.0}

## The Dike, in runs of about RUN m, each its own piece.
const RUN := 340.0
static func _dike(out: Array, field: RefCounted, peak: RefCounted) -> void:
	var n := 0
	var k := 0
	while k < DIKE.size()-1:
		var rows: Array = [DIKE[k]]
		var long := 0.0
		while k < DIKE.size()-1 and long < RUN:
			var p: Array = DIKE[k]
			var q: Array = DIKE[k+1]
			long += Vector2(float(p[0])-float(q[0]),float(p[1])-float(q[1])).length()
			k += 1
			rows.append(q)
		var mid: Array = rows[rows.size()/2]
		var o := at(peak,float(mid[0]),float(mid[1]),float(mid[2])-120.0)
		var prims: Array = [_wall_prim(peak,rows,o)]
		var a0 := minf(float(rows[0][0]),float(rows[-1][0]))-70.0
		var a1 := maxf(float(rows[0][0]),float(rows[-1][0]))+70.0
		for h: Array in HOLES:
			if float(h[0]) >= a0 and float(h[0]) <= a1: prims.append(_hole_prim(peak,h,o))
		out.append(_rock_spec(field,"peak/carve/dike/%d" % n,o,prims,3.5))
		n += 1

static func _sills(out: Array, field: RefCounted, peak: RefCounted) -> void:
	for k in SILLS.size():
		var rows: Array = SILLS[k]
		var mid: Array = rows[1]
		var o := at(peak,float(mid[0]),float(mid[1]),float(mid[2])-120.0)
		var prims: Array = [_wall_prim(peak,rows,o)]
		for h: Array in SILL_HOLES:
			if int(h[0]) == k: prims.append(_hole_prim(peak,h.slice(1),o))
		out.append(_rock_spec(field,"peak/carve/sill/%d" % k,o,prims))

## Along `table` at a: Vector3(v, y, 0), and the way (world XZ, unit).
static func _on(table: Array, a: float) -> Vector2:
	for k in table.size()-1:
		var p: Array = table[k]
		var q: Array = table[k+1]
		if float(q[0]) <= a:
			var t := (a-float(p[0]))/(float(q[0])-float(p[0]))
			return Vector2(lerpf(float(p[1]),float(q[1]),t),lerpf(float(p[2]),float(q[2]),t))
	return Vector2(float(table[-1][1]),float(table[-1][2]))

static func _tangent(peak: RefCounted, table: Array, a: float) -> Vector3:
	var p := _on(table,a+12.0)
	var q := _on(table,a-12.0)
	var u := at(peak,a+12.0,p.x,p.y)
	var w := at(peak,a-12.0,q.x,q.y)
	return (w-u).normalized()

## An eye: a short wall square to the line, a hole along it.
static func _eyes(out: Array, field: RefCounted, peak: RefCounted) -> void:
	for n in EYES.size():
		var r: Array = EYES[n]
		var table: Array = LINE_BENCH if int(r[0]) == 1 else LINE_SLOT
		var a := float(r[1])
		var on := _on(table,a)
		var c := at(peak,a,on.x,on.y)
		var t := _tangent(peak,table,a)
		var across := Vector2(t.z,-t.x).normalized()
		var half := float(r[4])
		var top := float(r[5])
		var thick := float(r[6])
		var o := Vector3(c.x,c.y-80.0,c.z)
		var p0 := Vector2(c.x-o.x,c.z-o.z)-across*half
		var p1 := Vector2(c.x-o.x,c.z-o.z)+across*half
		var y := c.y-o.y+top
		var prims: Array = [{"wall":[p0,p1],"tops":[y+float(n%3)*4.0-4.0,y-float(n%2)*8.0],"half":[thick,thick]},
			{"hole":c-o,"way":t,"w":_half(r[2]),"h":_half(r[3]),"deep":50.0}]
		out.append(_rock_spec(field,"peak/carve/eye/%d" % n,o,prims))

static func _blades(out: Array, field: RefCounted, peak: RefCounted) -> void:
	for g: Array in BLADES:
		var rows: Array = []
		var mid := Vector3.ZERO
		for i in range(1,g.size()):
			var r: Array = g[i]
			var a := float(r[0])
			var on := _on(LINE_SLOT,a)
			var t := _tangent(peak,LINE_SLOT,a)
			var across := Vector2(t.z,-t.x).normalized()
			# Toward +v.
			if across.dot(peak.side) < 0.0: across = -across
			var p := at(peak,a,on.x,0.0)
			var q := Vector2(p.x,p.z)+across*float(r[1])
			rows.append([q,atan2(t.z,t.x)+deg_to_rad(float(r[5])),r])
			mid += Vector3(q.x,0.0,q.y)
		mid /= float(rows.size())
		mid.y = float(field.height(mid.x,mid.z))
		var prims: Array = []
		for e: Array in rows:
			var q: Vector2 = e[0]
			var r: Array = e[2]
			var gy := float(field.height(q.x,q.y))
			# It stands over the plane on the line, however low its foot.
			var over := _on(LINE_SLOT,float(r[0])).y+Field.SEA_Y+float(r[2])*0.6
			prims.append({"blade":Vector2(q.x-mid.x,q.y-mid.z),"yaw":float(e[1]),"long":float(r[3]),"thin":float(r[4]),
				"top":maxf(gy+float(r[2]),over)-mid.y,"tilt":float(r[6]),"low":gy-mid.y-24.0,"lean":Vector2(0.0,0.0)})
		out.append(_rock_spec(field,"peak/carve/blades/%s" % str(g[0]),mid,prims))

static func _ruins(out: Array, field: RefCounted, peak: RefCounted) -> void:
	for n in RUINS.size():
		var r: Array = RUINS[n]
		var kind := str(r[0])
		var a := float(r[1])
		var on := _on(LINE_BENCH,a)
		var c := at(peak,a,on.x,on.y)
		var t := _tangent(peak,LINE_BENCH,a)
		var dir := Vector2(t.x,t.z).normalized()
		var yaw := atan2(dir.x,dir.y)
		var fly_y := c.y
		var name := "peak/carve/%s/%d" % [kind,n]
		var sd := hash([int(field.seed),name])
		var across := Vector2(dir.y,-dir.x)
		var wide := WorldScale.opening(float(r[2]))
		var top := -INF
		for s: float in [-1.0,0.0,1.0]:
			var q := Vector2(c.x,c.z)+across*s*wide*0.5
			top = maxf(top,float(field.height(q.x,q.y)))
		# Over low ground a gate stands on an arcade's long piers.
		if kind == "gate" and top < fly_y-16.0: kind = "arcade"
		if kind == "gate":
			var grow := wide/RuinKit.ARCH_SPAN
			c.y = minf(top,fly_y-8.0)
			out.append({"kind":"gate","grow":grow,"weathered":0.45,"yaw":yaw,"pos":c,"seed":sd,"name":name,"foot":[],"tone":"carve"})
		else:
			var count := maxi(int(r[3]),1)
			var grow := wide/Aqueduct.CLEAR
			var length: float = Aqueduct.SPAN*grow*count
			c.y = fly_y+wide*1.05-Aqueduct.DECK*grow
			out.append({"kind":"aqueduct","grow":grow,"count":count,"head":false,"break_at":count-1 if count > 1 else -1,"weathered":0.5,"yaw":yaw,"pos":c,"seed":sd,"name":name,"foot":[],"length":length,"tone":"carve","dry":true})
