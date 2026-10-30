## The Peak's split (docs/design/endless-flight/spec-crown.md, trunk step 2): a
## prow of rock divides the way in, and two gorges run from its nose, on the
## valley's floor, up to a saddle under the towers, inside the mountain.
##
## ICE, the long one, swings wide round the -v side at a grade the plane can
## hold unaided. ROCK, the short steep one, holds the stair and the lift
## (PeakRoutes), and its floor comes in pitches.
##
## Each gorge is a line in the massif's frame (a, v): knots, a spline through
## them, resampled every STRIDE m, with a floor height and a half-width (from
## a toy width by WorldScale.opening) at every sample. A grid of CELL m over the
## whole split holds, for each gorge, how far a point lies past the floor's edge
## (`e`) and the floor's height there; a third layer holds the hull, the ground
## between the two lines, which is the prow. Baked once per process, since it
## depends on no seed and no placement: the massif's `_h` only reads it.
##
## `carve` lays it on the massif's height: raises the prow and each gorge's
## ridges (the mass), then cuts each gorge's profile out of it, so what stands
## between the two gorges is what is left, and the walls meet in sharp aretes.
extends RefCounted

const WorldScale = preload("res://scripts/world_scale.gd")

const ICE := 0
const ROCK := 1

## The grid: its reach in (a, v) and its cell (m).
const A_SPAN := Vector2(120.0,2240.0)
const V_SPAN := Vector2(-1060.0,860.0)
const CELL := 20.0
## A sample every STRIDE m along each line.
const STRIDE := 20.0
## Each sample stamps the grid out to its half-width plus this (m). Past it a
## gorge says nothing: `e` reads FAR, the floor reads the plain slope `_far`.
const REACH := 240.0
const FAR := 400.0

## Both lines start at the prow's nose, on the valley's floor, and meet at the
## saddle; from there one wide ramp, TAIL, runs up to the plateau's edge.
const NOSE_Y := 308.0
const SADDLE_Y := 832.0
const PLATEAU_EDGE_Y := 880.0

## The lines: a, v, toy width of the floor at that knot (WorldScale.opening). The
## tight places are knots of 34..42, the wide bowls 90..100.
const ICE_KNOTS := [
	[1985.0,165.0,40.0],[1900.0,10.0,75.0],[1790.0,-200.0,95.0],[1650.0,-340.0,60.0],[1500.0,-500.0,28.0],
	[1330.0,-560.0,80.0],[1200.0,-420.0,100.0],[1075.0,-225.0,60.0],[960.0,-105.0,27.0],[825.0,-190.0,70.0],
	[720.0,-420.0,90.0],[590.0,-600.0,60.0],[450.0,-560.0,28.0],[440.0,-400.0,75.0],[470.0,-240.0,90.0],
	[420.0,-100.0,60.0],[345.0,0.0,85.0]]
const ROCK_KNOTS := [
	[1985.0,165.0,40.0],[1900.0,290.0,70.0],[1760.0,420.0,90.0],[1610.0,430.0,28.0],[1450.0,470.0,70.0],
	[1290.0,520.0,95.0],[1130.0,500.0,30.0],[980.0,520.0,80.0],[830.0,470.0,27.0],[700.0,340.0,70.0],
	[570.0,230.0,30.0],[470.0,130.0,65.0],[345.0,0.0,85.0]]
const TAIL_KNOTS := [[262.0,0.0,95.0],[170.0,0.0,110.0]]
## Each floor's height by the share of the way from nose to saddle. The ice's
## grade stays near 0.17: the plane holds about 0.19 at a flying speed, and the
## next step stands seracs on it to weave. The rock's comes in pitches of up to
## about 0.37, which the lift carries.
const ICE_FLOOR := [[0.0,NOSE_Y],[0.3,462.0],[0.55,590.0],[0.8,724.0],[1.0,SADDLE_Y]]
const ROCK_FLOOR := [[0.0,NOSE_Y],[0.18,372.0],[0.36,452.0],[0.5,530.0],[0.62,610.0],[0.72,680.0],[0.84,765.0],[0.93,810.0],[1.0,SADDLE_Y]]

## The wall's profile, from the floor's edge: SLOPE m up per m out after a foot
## of FOOT m, to ELBOW m out, then EASE m per m on up.
const SLOPE := 2.6
const FOOT := 10.0
const ELBOW := 70.0
const EASE := 1.15
## The wall's line wanders by up to BUTTRESS m, on noise SPUR_SCALE times the
## rock noise's scale. Tiers across the wall: BAND.x m of swing, one every
## TAU/BAND.y m of height, their level wandering with the buttresses.
const BUTTRESS := 22.0
const SPUR_SCALE := 0.55
const BAND := Vector2(8.0,0.098)
## How much of the rock noise is left on a gorge's floor.
const FLOOR_ROUGH := 0.3
## A gorge's own ridge: RIDGE_UP m over its floor, from where the walls' top
## stands RIDGE m past the floor's edge, falling OUT_FALL m per m outward.
## Grown in over RIDGE_IN m of the floor's rise, so the outer ridges come late
## and the prow stands alone at the mouth; lower near the top.
const RIDGE_UP := 170.0
const RIDGE := 62.0
const OUT_FALL := 2.0
const RIDGE_IN := Vector2(330.0,480.0)
const RIDGE_LOW := Vector2(640.0,830.0)
const RIDGE_LOWS := 0.5
const RIDGE_OUT := Vector2(835.0,872.0)
## The prow's back, by a: the highest it stands (over the sea), before the sight
## line (below) takes its due.
const TOPS := [[1985.0,500.0],[1900.0,690.0],[1800.0,720.0],[1600.0,690.0],[1300.0,720.0],[1000.0,790.0],[700.0,850.0],[450.0,880.0],[345.0,890.0]]
const TOP_BREAK := 40.0
const ROOF_RISE := 0.42
## The sight line from the start meadow, an eye SIGHT_EYE m up at a SIGHT_A on the
## axis: everything the split raises stands under the line from that eye to
## SIGHT_Y m at the towers, within SIGHT_W m of the ray to each (SIGHT_RAYS, the
## towers' (a, v), peak_massif.gd's CROWN), so their bodies show over the front.
## Between the rays the prow may stand SIGHT_OVER m past the line (x at its nose
## by SIGHT_OVER_A, y on up): it fills the notches between the towers, not the
## towers, and so stands over everything at the mouth. The outer ridges stay OUTER_UNDER
## m under it at the mouth, and off the rays go free past OUTER_FREE along a.
const SIGHT_A := 3500.0
const SIGHT_EYE := 25.0
const SIGHT_Y := 1000.0
const SIGHT_TO := -260.0
const SIGHT_RAYS := [[-260.0,-400.0],[-440.0,90.0],[-70.0,460.0]]
const SIGHT_W := Vector2(30.0,75.0)
const SIGHT_OVER := Vector2(250.0,130.0)
const SIGHT_OVER_A := Vector2(1820.0,1450.0)
const OUTER_UNDER := 40.0
const OUTER_FREE := Vector2(1650.0,1250.0)
## Cols: the tops of the prow and the ridges drop by up to NOTCH m on a broad
## noise, so a crest isn't one even comb.
const NOTCH := 75.0
const NOTCH_SCALE := 0.3

## Per gorge: (a, v, floor) of every sample, half-widths, where the saddle is.
static var _lines: Array = []
static var _halves: Array = []
static var _saddle := PackedInt32Array()
static var _lengths := PackedFloat32Array()
## The grid's layers, _na by _nv.
static var _e: Array = []
static var _f: Array = []
static var _hull := PackedFloat32Array()
## 0 on a sight ray, 1 clear of them all.
static var _gap := PackedFloat32Array()
static var _na := 0
static var _nv := 0
static var _tops := PackedFloat32Array()
static var _baked := false
static var _lock := Mutex.new()
## How long the bake took (ms), for the cost drivers.
static var bake_ms := 0.0

## Bakes once, from any thread.
static func bake() -> void:
	_lock.lock()
	if not _baked:
		var t0 := Time.get_ticks_usec()
		_lay(ICE,ICE_KNOTS,ICE_FLOOR)
		_lay(ROCK,ROCK_KNOTS,ROCK_FLOOR)
		_stamp()
		_stamp_hull()
		_stamp_gap()
		_lay_tops()
		_baked = true
		bake_ms = (Time.get_ticks_usec()-t0)/1000.0
	_lock.unlock()

## Gorge `g`'s line: (a, v, floor) every STRIDE m from the nose, through the
## saddle, to the plateau's edge.
static func line(g: int) -> PackedVector3Array:
	return _lines[g]

## Gorge `g`'s floor's half-width at each sample of `line`.
static func halves(g: int) -> PackedFloat32Array:
	return _halves[g]

## The sample of `line` at the saddle.
static func saddle(g: int) -> int:
	return _saddle[g]

## Gorge `g`'s length, nose to saddle (m).
static func length(g: int) -> float:
	return _lengths[g]

## A Catmull-Rom point between knots p1 and p2.
static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	return 0.5*(2.0*p1+(p2-p0)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(3.0*p1-p0-3.0*p2+p3)*t*t*t)

## `table`'s height at share `t` (pairs, in order).
static func _at(table: Array, t: float) -> float:
	var k := 0
	while k+2 < table.size() and t > float(table[k+1][0]): k += 1
	var r0: Array = table[k]
	var r1: Array = table[k+1]
	return lerpf(float(r0[1]),float(r1[1]),clampf((t-float(r0[0]))/(float(r1[0])-float(r0[0])),0.0,1.0))

## Lays gorge `g`: the spline through its knots and the tail, every STRIDE m,
## its widths (opening of a toy width) and floor.
static func _lay(g: int, knots: Array, floors: Array) -> void:
	var kn: Array[Vector3] = []
	for r: Array in knots+TAIL_KNOTS: kn.append(Vector3(float(r[0]),float(r[1]),float(r[2])))
	var saddle_knot := knots.size()-1
	var fine := PackedVector3Array()
	var at_saddle := 0
	for k in kn.size()-1:
		var p0 := kn[maxi(k-1,0)]
		var p3 := kn[mini(k+2,kn.size()-1)]
		if k == saddle_knot: at_saddle = fine.size()
		for q in 32: fine.append(_cr(p0,kn[k],kn[k+1],p3,q/32.0))
	fine.append(kn[kn.size()-1])
	var pts := PackedVector3Array()
	var hs := PackedFloat32Array()
	var run := 0.0
	var next := 0.0
	var i_saddle := 0
	var length_s := 0.0
	for k in fine.size():
		if k > 0: run += Vector2(fine[k].x-fine[k-1].x,fine[k].y-fine[k-1].y).length()
		if k == at_saddle: length_s = run
		if run >= next or k == fine.size()-1:
			pts.append(fine[k])
			hs.append(WorldScale.opening(fine[k].z)*0.5)
			next += STRIDE
			if k <= at_saddle: i_saddle = pts.size()-1
	# The floor, graded by the way along, smoothed so a pitch has no kink.
	var ys := PackedFloat32Array()
	ys.resize(pts.size())
	for k in pts.size():
		if k <= i_saddle: ys[k] = _at(floors,float(k)/i_saddle)
		else: ys[k] = lerpf(SADDLE_Y,PLATEAU_EDGE_Y,float(k-i_saddle)/(pts.size()-1-i_saddle))
	for pass_n in 3:
		var was := ys.duplicate()
		for k in range(1,ys.size()-1): ys[k] = (was[k-1]+was[k]+was[k+1])/3.0
	for k in pts.size(): pts[k].z = ys[k]
	_lines.append(pts)
	_halves.append(hs)
	_saddle.append(i_saddle)
	_lengths.append(length_s)

## The plain slope of the floors: what a cell reads past every gorge's reach.
static func _far(a: float) -> float:
	return NOSE_Y+(A_SPAN.y-250.0-a)*0.31

## Stamps each gorge's distance and floor into the grid.
static func _stamp() -> void:
	_na = int((A_SPAN.y-A_SPAN.x)/CELL)+1
	_nv = int((V_SPAN.y-V_SPAN.x)/CELL)+1
	var far_f := PackedFloat32Array()
	far_f.resize(_na*_nv)
	for j in _nv:
		for i in _na: far_f[j*_na+i] = _far(A_SPAN.x+i*CELL)
	for g in 2:
		var e := PackedFloat32Array()
		e.resize(_na*_nv)
		e.fill(FAR)
		var f := far_f.duplicate()
		var pts: PackedVector3Array = _lines[g]
		var hs: PackedFloat32Array = _halves[g]
		var half_stride := STRIDE*0.5
		for k in pts.size():
			var p := pts[k]
			var o := pts[mini(k+1,pts.size()-1)]-pts[maxi(k-1,0)]
			var tan_a := Vector2(o.x,o.y).normalized()
			var half := hs[k]
			var reach := half+REACH
			var r2 := reach*reach
			var i0 := maxi(int(ceil((p.x-reach-A_SPAN.x)/CELL)),0)
			var i1 := mini(int(floor((p.x+reach-A_SPAN.x)/CELL)),_na-1)
			var j0 := maxi(int(ceil((p.y-reach-V_SPAN.x)/CELL)),0)
			var j1 := mini(int(floor((p.y+reach-V_SPAN.x)/CELL)),_nv-1)
			for j in range(j0,j1+1):
				var dv := V_SPAN.x+j*CELL-p.y
				var row := j*_na
				for i in range(i0,i1+1):
					var da := A_SPAN.x+i*CELL-p.x
					var d2 := da*da+dv*dv
					if d2 > r2: continue
					# Off this sample's own STRIDE of line, square to it.
					var along := absf(da*tan_a.x+dv*tan_a.y)
					var perp := absf(da*tan_a.y-dv*tan_a.x)
					var over := maxf(along-half_stride,0.0)
					var ee := sqrt(perp*perp+over*over)-half
					if ee < e[row+i]:
						e[row+i] = ee
						f[row+i] = p.z
		_e.append(e)
		_f.append(f)

## The hull: 1 between the two lines, nose to saddle (the even-odd rule, on
## each row of the grid along v).
static func _stamp_hull() -> void:
	_hull.resize(_na*_nv)
	var loop := PackedVector2Array()
	var ice: PackedVector3Array = _lines[ICE]
	var rock: PackedVector3Array = _lines[ROCK]
	for k in _saddle[ICE]+1: loop.append(Vector2(ice[k].x,ice[k].y))
	for k in range(_saddle[ROCK],-1,-1): loop.append(Vector2(rock[k].x,rock[k].y))
	var hits: Array = []
	hits.resize(_nv)
	for j in _nv: hits[j] = []
	for k in loop.size():
		var p := loop[k]
		var q := loop[(k+1)%loop.size()]
		var lo := minf(p.y,q.y)
		var hi := maxf(p.y,q.y)
		var j0 := maxi(int(ceil((lo-V_SPAN.x)/CELL)),0)
		var j1 := mini(int(floor((hi-V_SPAN.x)/CELL)),_nv-1)
		for j in range(j0,j1+1):
			var v := V_SPAN.x+j*CELL
			if v < lo or v >= hi: continue
			(hits[j] as Array).append(lerpf(p.x,q.x,(v-p.y)/(q.y-p.y)))
	for j in _nv:
		var row: Array = hits[j]
		row.sort()
		var c := 0
		while c+1 < row.size():
			var i0 := maxi(int(ceil((float(row[c])-A_SPAN.x)/CELL)),0)
			var i1 := mini(int(floor((float(row[c+1])-A_SPAN.x)/CELL)),_na-1)
			for i in range(i0,i1+1): _hull[j*_na+i] = 1.0
			c += 2

## Each cell's way off the sight rays.
static func _stamp_gap() -> void:
	_gap.resize(_na*_nv)
	for j in _nv:
		var v := V_SPAN.x+j*CELL
		for i in _na:
			var a := A_SPAN.x+i*CELL
			var g := 1.0
			for r: Array in SIGHT_RAYS:
				var off := absf(v-float(r[1])*(SIGHT_A-a)/(SIGHT_A-float(r[0])))
				g = minf(g,smoothstep(SIGHT_W.x,SIGHT_W.y,off))
			_gap[j*_na+i] = g

## The sight line's height at `a`.
static func _sight(a: float) -> float:
	return SIGHT_EYE+(SIGHT_Y-SIGHT_EYE)*(SIGHT_A-a)/(SIGHT_A-SIGHT_TO)

## The prow's tops, one every 50 m along a from A_SPAN.x.
static func _lay_tops() -> void:
	var n := int((A_SPAN.y-A_SPAN.x)/50.0)+2
	_tops.resize(n)
	for k in n:
		var a := A_SPAN.x+k*50.0
		var y := float(TOPS[TOPS.size()-1][1])
		if a >= float(TOPS[0][0]): y = float(TOPS[0][1])
		else:
			for r in TOPS.size()-1:
				var r0: Array = TOPS[r]
				var r1: Array = TOPS[r+1]
				if a <= float(r0[0]) and a >= float(r1[0]):
					y = lerpf(float(r0[1]),float(r1[1]),smoothstep(float(r0[0]),float(r1[0]),a))
					break
		_tops[k] = y

## The wall's rise `ee` m past the floor's edge; `tier` shifts the tiers' level.
static func _rise(ee: float, tier: float) -> float:
	if ee <= 0.0: return 0.0
	var r: float
	if ee < FOOT: r = SLOPE*ee*ee/(2.0*FOOT)
	elif ee < ELBOW: r = SLOPE*(ee-FOOT*0.5)
	else: r = SLOPE*(ELBOW-FOOT*0.5)+EASE*(ee-ELBOW)
	return r+BAND.x*sin(r*BAND.y+tier)*minf(ee/FOOT,1.0)

## A gorge's ridge's height over its floor where the floor stands at `f`.
static func _ridge(f: float) -> float:
	return smoothstep(RIDGE_IN.x,RIDGE_IN.y,f)*_edge(f)

## The prow's side of it, which stands from the first.
static func _edge(f: float) -> float:
	return RIDGE_UP*(1.0-RIDGE_LOWS*smoothstep(RIDGE_LOW.x,RIDGE_LOW.y,f))*(1.0-smoothstep(RIDGE_OUT.x,RIDGE_OUT.y,f))

## The massif's height `h` at (a, v) with the split on it. `n` the rock noise
## here, `rough` its height (m), `noise` the massif's noise.
static func carve(a: float, v: float, h: float, n: float, rough: float, noise: FastNoiseLite) -> float:
	var x := (a-A_SPAN.x)/CELL
	var y := (v-V_SPAN.x)/CELL
	if x < 0.0 or y < 0.0: return h
	var i := int(x)
	var j := int(y)
	if i >= _na-1 or j >= _nv-1: return h
	var k := j*_na+i
	var fx := x-i
	var fy := y-j
	var e0: PackedFloat32Array = _e[0]
	var e1: PackedFloat32Array = _e[1]
	var w00 := (1.0-fx)*(1.0-fy)
	var w10 := fx*(1.0-fy)
	var w01 := (1.0-fx)*fy
	var w11 := fx*fy
	var k1 := k+1
	var k2 := k+_na
	var k3 := k2+1
	var ei := e0[k]*w00+e0[k1]*w10+e0[k2]*w01+e0[k3]*w11
	var er := e1[k]*w00+e1[k1]*w10+e1[k2]*w01+e1[k3]*w11
	var hull := _hull[k]*w00+_hull[k1]*w10+_hull[k2]*w01+_hull[k3]*w11
	if ei >= FAR-1.0 and er >= FAR-1.0 and hull <= 0.0: return h
	var f0: PackedFloat32Array = _f[0]
	var f1: PackedFloat32Array = _f[1]
	var fi := f0[k]*w00+f0[k1]*w10+f0[k2]*w01+f0[k3]*w11
	var fr := f1[k]*w00+f1[k1]*w10+f1[k2]*w01+f1[k3]*w11
	var gap := _gap[k]*w00+_gap[k1]*w10+_gap[k2]*w01+_gap[k3]*w11
	var spur := noise.get_noise_2d(a*SPUR_SCALE+1900.0,v*SPUR_SCALE-1300.0)
	var wander := BUTTRESS*spur*1.6
	var tier := spur*5.0
	var notch := NOTCH*smoothstep(0.02,0.3,noise.get_noise_2d(a*NOTCH_SCALE+3100.0,v*NOTCH_SCALE-700.0))
	# The mass: the prow's back between the lines, each gorge's ridge outside,
	# each under the sight line.
	var mass := h
	var near := minf(ei,er)
	var fn := fi if ei < er else fr
	var line := _sight(a)
	var out := rough*n
	var inner := clampf(hull*2.0-0.5,0.0,1.0)
	if hull > 0.0:
		var t := (a-A_SPAN.x)/50.0
		var ti := clampi(int(t),0,_tops.size()-2)
		var top := lerpf(_tops[ti],_tops[ti+1],t-ti)-TOP_BREAK*maxf(noise.get_noise_2d(a*0.45-2100.0,v*0.45+800.0)*2.0+0.3,0.0)
		var over := lerpf(SIGHT_OVER.y,SIGHT_OVER.x,smoothstep(SIGHT_OVER_A.y,SIGHT_OVER_A.x,a))
		top = minf(top,line+over*gap)-notch*smoothstep(1850.0,1650.0,a)
		var roof := minf(top,fn+_edge(fn)+ROOF_RISE*maxf(near-RIDGE,0.0))+out
		mass = maxf(mass,roof)
	if inner < 1.0:
		var free := smoothstep(OUTER_FREE.x,OUTER_FREE.y,a)*gap
		var cap := line-OUTER_UNDER+free*600.0-notch
		if ei < REACH: mass = maxf(mass,minf(fi+_ridge(fi)-notch-maxf(ei-RIDGE,0.0)*OUT_FALL,cap)+out)
		if er < REACH: mass = maxf(mass,minf(fr+_ridge(fr)-notch-maxf(er-RIDGE,0.0)*OUT_FALL,cap)+out)
	# The gorges, cut out of it.
	var low := n*rough*FLOOR_ROUGH
	var y0 := fi+_rise(ei+wander,tier)+low if ei < FAR-1.0 else INF
	var y1 := fr+_rise(er+wander,tier)+low if er < FAR-1.0 else INF
	return minf(mass,minf(y0,y1))
