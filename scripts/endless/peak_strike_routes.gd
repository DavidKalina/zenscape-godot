extends RefCounted
## The ways down the mountain a strike runs (scripts/endless/peak_strike.gd):
## spines from the three spires down every side of the massif, sited on seed 1
## in the massif's frame (a along the facing, v across it, y over the sea;
## PeakMassif) and baked once at setup into world points close over the land.
##
##   slot, bench   the lines flown up the front (PeakCarve LINE_SLOT, LINE_BENCH)
##   dike          off the Slot and along the prow's main crest (PeakCarve DIKE)
##   ice, rock     off the Slot and the Bench into the gorges (PeakSplit)
##   west, east    down the arms' outer flanks: a gully and the crest each side
##   back          down the back face: spurs and a gully from all three spires
##
## The tables here, WEST_* and so on, were traced on the height grid (gullies by
## the lowest way down, spurs by the highest) and want refitting if the land
## changes. A row is [a, v], laid HUG m over the land, or [a, v, y], which holds
## that height (the flown lines, which thread the eyes and the Sills), never
## less than HUG_LEAST m over the land.
##
## Routes off one spire run together until they fork, so while a strike is on
## the shared stretch it can still take the other way (`forks`).

const Carve := preload("res://scripts/endless/peak_carve.gd")
const Split := preload("res://scripts/endless/peak_split.gd")
const Field := preload("res://scripts/endless/land_field.gd")

## A point every STRIDE m or so.
const STRIDE := 20.0
## Over the land (m): the line's height, the least, and how far to each side
## the land is read for them.
const HUG := 46.0
const HUG_LEAST := 34.0
const WIDE := 18.0
## Smoothing passes on the height.
const EASE := 4
## Clear of a spire by this (m).
const TOWER_ROOM := 34.0
## Drawn no closer than this (m), and as many points as the strike's line holds.
const DRAW_EVERY := 40.0
## Routes share their way while their points lie within this (m).
const SAME := 4.0
## The gorges' lines are read every this many of their samples, and to this a.
const GORGE_EVERY := 4
const FRONT_END := 1900.0

const WEST_GULLY := [[100.0,-360.0],[147.0,-437.0],[216.0,-501.0],[263.0,-580.0],[307.0,-637.0],[369.0,-701.0],[380.0,-780.0],[387.0,-860.0],[420.0,-940.0],[451.0,-1020.0],[481.0,-1100.0],[445.0,-1180.0],[420.0,-1280.0]]
const WEST_CREST := [[200.0,-360.0],[256.0,-420.0],[293.0,-500.0],[316.0,-579.0],[379.0,-643.0],[419.0,-720.0],[480.0,-777.0],[553.0,-821.0],[601.0,-880.0],[660.0,-940.0],[720.0,-997.0],[780.0,-1036.0],[840.0,-1081.0],[900.0,-1136.0],[980.0,-1169.0],[1020.0,-1160.0]]
const BACK_LEFT := [[-300.0,-470.0,1190.0],[-340.0,-480.0],[-400.0,-540.0],[-460.0,-600.0],[-509.0,-660.0],[-531.0,-739.0],[-600.0,-795.0],[-680.0,-816.0],[-760.0,-773.0],[-840.0,-742.0]]
const BACK_SPUR := [[-470.0,90.0,1120.0],[-540.0,80.0],[-620.0,90.0],[-700.0,62.0],[-780.0,100.0],[-840.0,136.0],[-920.0,140.0],[-1000.0,127.0],[-1080.0,120.0],[-1160.0,119.0]]
const BACK_GULLY := [[-470.0,90.0,1120.0],[-540.0,80.0],[-600.0,40.0],[-660.0,0.0],[-720.0,-40.0],[-800.0,-77.0],[-880.0,-73.0],[-960.0,-49.0],[-1020.0,-4.0],[-1100.0,43.0]]
const BACK_RIGHT := [[-110.0,520.0,1130.0],[-160.0,560.0],[-220.0,609.0],[-300.0,644.0],[-360.0,700.0],[-420.0,760.0],[-480.0,810.0],[-560.0,837.0]]
const EAST_GULLY := [[200.0,521.0],[267.0,577.0],[340.0,616.0],[416.0,663.0],[424.0,740.0],[384.0,820.0],[340.0,900.0],[314.0,980.0],[356.0,1060.0]]
const EAST_CREST := [[380.0,484.0],[446.0,540.0],[482.0,620.0],[499.0,700.0],[511.0,780.0],[557.0,840.0],[602.0,900.0],[647.0,957.0],[719.0,1013.0],[782.0,1080.0],[827.0,1139.0],[900.0,1163.0],[960.0,1180.0]]
## Down off the Slot's shelf into the ice gorge.
const ICE_JOIN := [[337.0,-321.0],[401.0,-384.0]]
## Where the side roads meet the gorges: (a, v).
const ICE_AT := Vector2(440.0,-400.0)
const ROCK_AT := Vector2(700.0,340.0)
## Over the Dike's crest (m).
const DIKE_OVER := 24.0


## Every route, baked: {name, spire, pts (world), s (metres along at each), k
## (drawn every k-th point), length, forks ({other route's index: metres shared})}.
## `height`: the land's height (world y) at (x, z). `towers`: the spires.
static func bake(peak: RefCounted, height: Callable, towers: Node3D, most_points: int) -> Array:
	var out: Array = []
	for t: Array in _table():
		out.append(_bake_one(peak,height,towers,str(t[0]),int(t[1]),t[2],most_points))
	for i in out.size():
		var a: Dictionary = out[i]
		for j in out.size():
			var b: Dictionary = out[j]
			if i == j or a.spire != b.spire: continue
			var pa: PackedVector3Array = a.pts
			var pb: PackedVector3Array = b.pts
			var n := 0
			while n < mini(pa.size(),pb.size()) and pa[n].distance_to(pb[n]) < SAME: n += 1
			if n > 1: (a.forks as Dictionary)[j] = (a.s as PackedFloat32Array)[n-1]
	return out

## The routes: [name, spire, rows]. --peak-strike-route= counts this order.
static func _table() -> Array:
	var slot := _flip(Carve.LINE_SLOT)
	var bench := _flip(Carve.LINE_BENCH)
	var dike: Array = []
	for r: Array in Carve.DIKE: dike.append([float(r[0]),float(r[1]),float(r[2])+DIKE_OVER])
	dike.reverse()
	return [
		["slot",0,_to(slot,FRONT_END)],
		["dike",0,_to(slot,650.0)+dike],
		["ice",0,_to(slot,285.0)+ICE_JOIN+_gorge(Split.ICE,ICE_AT)],
		["west crest",0,_to(slot,150.0)+WEST_CREST],
		["west gully",0,_to(slot,60.0)+WEST_GULLY],
		["back left",0,BACK_LEFT],
		["back spur",1,BACK_SPUR],
		["back gully",1,BACK_GULLY],
		["back right",2,BACK_RIGHT],
		["east gully",2,_to(bench,120.0)+EAST_GULLY],
		["east crest",2,_to(bench,300.0)+EAST_CREST],
		["bench",2,_to(bench,FRONT_END)],
		["rock",2,_to(bench,650.0)+_gorge(Split.ROCK,ROCK_AT)],
	]

## Down the mountain: a table runs up it.
static func _flip(table: Array) -> Array:
	var out := table.duplicate()
	out.reverse()
	return out

## Rows as far as `a`.
static func _to(rows: Array, a: float) -> Array:
	var out: Array = []
	for r: Array in rows:
		if float(r[0]) > a: break
		out.append(r)
	return out

## Gorge `g` from its sample nearest `at` down to the mouth, as far as FRONT_END.
static func _gorge(g: int, at: Vector2) -> Array:
	var line := Split.line(g)
	var from := 0
	var least := INF
	for k in line.size():
		var d := Vector2(line[k].x,line[k].y).distance_to(at)
		if d < least:
			least = d
			from = k
	var out: Array = []
	var k := from
	while k > 0 and line[k].x < FRONT_END:
		out.append([line[k].x,line[k].y])
		k -= GORGE_EVERY
	return out

static func _bake_one(peak: RefCounted, height: Callable, towers: Node3D, name: String, spire: int, rows: Array, most_points: int) -> Dictionary:
	# Through the rows every STRIDE m or so, in (a, v).
	var at: Array[Vector2] = []
	var spans := PackedInt32Array()
	var q: Array[Vector2] = []
	for r: Array in rows: q.append(Vector2(float(r[0]),float(r[1])))
	for i in q.size()-1:
		var p0 := q[maxi(i-1,0)]
		var p1 := q[i]
		var p2 := q[i+1]
		var p3 := q[mini(i+2,q.size()-1)]
		var steps := maxi(int(ceil(p1.distance_to(p2)/STRIDE)),1)
		spans.append(at.size())
		for m in steps: at.append(p1.cubic_interpolate(p2,p0,p3,float(m)/float(steps)))
	spans.append(at.size())
	at.append(q[q.size()-1])
	var n := at.size()
	# The land under it, and the height of each stretch.
	var ground := PackedFloat32Array()
	ground.resize(n)
	var off := Vector2.ZERO
	for i in n:
		var flat: Vector2 = at[mini(i+1,n-1)]-at[maxi(i-1,0)]
		var w: Vector2 = peak.world(at[i].x,at[i].y)
		var o: Vector2 = peak.world(at[i].x+flat.y,at[i].y-flat.x)-w
		off = o.normalized()*WIDE if o.length() > 0.01 else off
		ground[i] = maxf(float(height.call(w.x,w.y)),maxf(float(height.call(w.x+off.x,w.y+off.y)),float(height.call(w.x-off.x,w.y-off.y))))
	var ys := PackedFloat32Array()
	ys.resize(n)
	for i in n: ys[i] = ground[i]+HUG
	for k in spans.size()-1:
		var a: Array = rows[k]
		var b: Array = rows[k+1]
		if a.size() < 3 and b.size() < 3: continue
		var i0 := spans[k]
		var i1 := spans[k+1]
		var y0 := float(a[2])+Field.SEA_Y if a.size() > 2 else ground[i0]+HUG
		var y1 := float(b[2])+Field.SEA_Y if b.size() > 2 else ground[i1]+HUG
		for i in range(i0,i1+1): ys[i] = lerpf(y0,y1,float(i-i0)/float(maxi(i1-i0,1)))
	for pass_n in EASE:
		var was := ys.duplicate()
		for i in range(1,n-1): ys[i] = (was[i-1]+was[i]*2.0+was[i+1])*0.25
	for i in n: ys[i] = maxf(ys[i],ground[i]+HUG_LEAST)
	# World, clear of the spires.
	var pts := PackedVector3Array()
	pts.resize(n)
	var axes: Array = towers.axes() if towers != null else []
	for i in n:
		var w: Vector2 = peak.world(at[i].x,at[i].y)
		pts[i] = _clear_of(towers,axes,Vector3(w.x,ys[i],w.y))
	var ds := PackedFloat32Array()
	ds.resize(n)
	for i in range(1,n): ds[i] = ds[i-1]+pts[i].distance_to(pts[i-1])
	var k := maxi(int(ceil(DRAW_EVERY/STRIDE)),int(ceil(float(n)/float(most_points))))
	return {"name":name,"spire":spire,"pts":pts,"s":ds,"k":k,"length":ds[n-1],"forks":{}}

static func _clear_of(towers: Node3D, axes: Array, p: Vector3) -> Vector3:
	if towers == null or not towers.inside(p,TOWER_ROOM): return p
	var best: Dictionary = axes[0]
	var least := INF
	for t: Dictionary in axes:
		var d := Vector2(p.x,p.z).distance_to(Vector2((t.tip as Vector3).x,(t.tip as Vector3).z))
		if d < least:
			least = d
			best = t
	var base: Vector3 = best.base
	var tip: Vector3 = best.tip
	var c := base.lerp(tip,clampf((p.y-base.y)/maxf(tip.y-base.y,1.0),0.0,1.0))
	var way := Vector3(p.x-c.x,0.0,p.z-c.z).normalized()
	for i in 24:
		if not towers.inside(p,TOWER_ROOM): break
		p += way*12.0
	return p
