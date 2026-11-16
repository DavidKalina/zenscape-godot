extends "res://scripts/endless/citadel_site.gd"
## The road of tombs (seed 1, the wilderness): from behind the agora's stoa
## north over the ridge's saddle and across the cape to the citadel's main gate
## (citadel_site.gd), lined both sides with tombs and monuments at uneven
## spacing (art/blender/temple_kit/tombs_build.py: house tombs, tower tombs,
## exedras, pillars, sarcophagi; the agora's altar and plinth, the kit's
## columns at COL scale).
##
## - The way: 2 * HALF_CLEAR (16 m) clear between the monuments' fronts. On
##   the plain it is the street's paving between its kerbs (PAVING: one letter a
##   bay of SEG m from the start); up and down the ridge it is a stair of
##   giant steps (`tombs_step`, level, one every STEP_RUN m); in places gone.
## - Across it (ACROSS): the street's arch at the town's end, the agora's gate
##   on the saddle (20 m by 26 m), pairs of columns under a beam, and a
##   cracked arch on the cape (a breakable, "tombs/arch").
## - A cracked tower tomb stands in the line on the inside of the last bend
##   (a breakable, "tombs/tower").
##
## Chunks, drawing, solids and streaming are citadel_site.gd's; this script
## lays the pieces. Trees keep off (`tree_keepouts`); grass keeps off the
## paving and the steps (`grass_off`). `--citadel=0`: none.

## The line's corners before the gate's straight (smoothed, Chaikin): north-east
## off the stoa's back to the ridge's foot, straight up its south slope and
## down its north one by their fall lines (the saddle between), then
## north-west across the cape.
const LINE: Array[Vector2] = [Vector2(-290,-4850),Vector2(-250,-4880),Vector2(-213,-4912),Vector2(-203,-4975),
	Vector2(-180,-5008),Vector2(-176,-5042),Vector2(-180,-5125),Vector2(-507,-5318)]
const SMOOTH := 3
## The street's bay, its kerbs' line and the way's clear half width (street_build.py).
const SEG := 18.5*0.72
const ROW := 9.8
const HALF_CLEAR := 8.0
const KERB_H := 0.55
## The road ends this far out from the gatehouse's front.
const GATE_GAP := 4.0
## Each bay from the start: P paved, B its paving broken, - none, S steps.
const PAVING := "PPBPSSSSSSSSSSSSSSSSSSSSSS-BPPPPPBB--BPPPPPPBPPB-BPPPPPP"
## Kerbs: these bays have lost theirs on the [right, left].
const KERB_GONE := [[2,27,33,34,37,44,49],[3,26,34,37,41,47,49,52]]
const STEP_RUN := 3.0
## A step's top stands this far over the highest ground under it (the land's
## drawn mesh rides over the field's hollows), and the stair rises or falls no
## more than STEP_RISE from one step to the next: over a cliff's band it
## starts up early and stands clear of the ground (a step's blocks go 16 m down).
const STEP_UP := 0.8
const STEP_RISE := 2.7
## Across the way, by the distance along it (m): "arch" the street's arch,
## "gate" the agora's gate, "beam" two columns under the street's cross beam,
## "cracked" the breakable arch.
const ACROSS := [[30.0,"arch"],[178.0,"gate"],[400.0,"beam"],[520.0,"cracked"],[640.0,"beam"]]
## The cracked tower tomb: the distance along the way, its side (-1 right, 1
## left), how far its front stands in from the row (m).
const CRACKED_TOMB := [684.0,-1,2.5]
## The kit's columns among the tombs, at this scale.
const COL := 0.6
## Stations per chunk.
const CHUNK := 7
const CLEAR_ACROSS := 30.0
## Monuments: letter -> [piece, half depth (front to middle), half width along the way, weight on the flat, on a slope].
const KINDS := {
	"H":[&"tombs_house",8.8,7.8,3.0,0.0],
	"h":[&"tombs_house_broken",8.8,7.8,2.0,0.0],
	"T":[&"tombs_tower",7.7,7.7,3.0,2.5],
	"X":[&"tombs_exedra",0.4,8.7,2.0,0.0],
	"I":[&"tombs_pillar",3.9,3.9,2.0,2.0],
	"S":[&"tombs_sarcophagus",4.3,6.1,3.0,0.5],
	"A":[&"agora_altar",3.6,8.0,1.0,0.0],
	"P":[&"agora_plinth",3.4,3.4,1.5,0.5],
	"C":[&"column",1.6,1.6,2.0,2.0],
	"c":[&"column_broken",1.6,1.6,1.5,1.5],
}

static func _line() -> Array[Vector2]:
	var pts: Array[Vector2] = LINE.duplicate()
	var gt := gate()
	var front: Vector2 = (gt[0] as Vector2)+(gt[1] as Vector2)*(GATE_D*0.5+GATE_GAP)
	pts.append(front+(gt[1] as Vector2)*70.0)
	pts.append(front)
	return pts

## The line smoothed, as a dense polyline; the gate's straight kept.
static func _smoothed() -> Array[Vector2]:
	var pts := _line()
	for _i in SMOOTH:
		var out: Array[Vector2] = [pts[0]]
		for k in range(pts.size()-1):
			out.append(pts[k].lerp(pts[k+1],0.25))
			out.append(pts[k].lerp(pts[k+1],0.75))
		out.append(pts[-1])
		pts = out
	return pts

static var _poly: Array[Vector2] = []
static var _cum: Array[float] = []
static var _poly_lock := Mutex.new()

## [the polyline, its running lengths], made once.
static func _way() -> Array:
	_poly_lock.lock()
	if _poly.is_empty():
		var pts := _smoothed()
		var cum: Array[float] = [0.0]
		for k in range(pts.size()-1): cum.append(cum[-1]+pts[k].distance_to(pts[k+1]))
		_cum = cum
		_poly = pts
	var out := [_poly,_cum]
	_poly_lock.unlock()
	return out

static func length() -> float:
	return (_way()[1] as Array[float])[-1]

## [the point, the direction] `s` m along the way.
static func at_s(s: float) -> Array:
	var w := _way()
	var pts: Array[Vector2] = w[0]
	var cum: Array[float] = w[1]
	var lo := 0
	var hi := pts.size()-2
	while lo < hi:
		var mid := (lo+hi)/2
		if cum[mid+1] < s: lo = mid+1
		else: hi = mid
	var a := pts[lo]
	var b := pts[lo+1]
	return [a.lerp(b,clampf((s-cum[lo])/maxf(cum[lo+1]-cum[lo],0.001),-2.0,3.0)),(b-a).normalized()]

## The stations' distances along the way, SEG apart, the last at its end.
static func station_s() -> Array[float]:
	var out: Array[float] = []
	var s := length()
	while s >= 0.0:
		out.push_front(s)
		s -= SEG
	return out

static func _paving(k: int) -> String:
	return PAVING[k] if k < PAVING.length() else "P"

static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	var out: Array = []
	if not wanted(): return out
	_keep_lock.lock()
	if _keep.is_empty():
		var ss := station_s()
		var k := 0
		while k < ss.size()-1:
			var k1 := mini(k+CHUNK,ss.size()-1)
			var a: Vector2 = at_s(ss[k])[0]
			var b: Vector2 = at_s(ss[k1])[0]
			var d := (b-a).normalized()
			var yaw := atan2(d.x,d.y)
			_keep.append([(a+b)*0.5,cos(yaw),sin(yaw),CLEAR_ACROSS,a.distance_to(b)*0.5+SEG*0.5])
			k = k1
	var all: Array = _keep
	_keep_lock.unlock()
	for e: Array in all:
		var c: Vector2 = e[0]
		if c.x > x0-400.0 and c.x < x1+400.0 and c.y > z0-400.0 and c.y < z1+400.0: out.append(e)
	return out

static var _keep: Array = []
static var _keep_lock := Mutex.new()

## The grass kept off the way (endless_grass.gd grow_cell, as street_site.gd's):
## the nodes within GRASS_HALF of a paved or stepped bay's centre line read as
## a river's water. A broken bay keeps grass in patches. Seed 1 only.
const GRASS_HALF := 11.0
static func grass_off(got: Dictionary, land_seed: int, x0: float, z0: float, n: int, pad: int) -> void:
	if land_seed != 1 or not wanted() or not got.has("river"): return
	var gx0 := x0-pad
	var gz0 := z0-pad
	var gx1 := gx0+n-1
	var gz1 := gz0+n-1
	var reach := GRASS_HALF+SEG
	if gx1 < -760.0-reach or gx0 > -150.0+reach or gz1 < -5440.0-reach or gz0 > -4840.0+reach: return
	var ss := station_s()
	var rs: PackedFloat32Array = got.river
	var hit := false
	for k in range(ss.size()-1):
		var letter := _paving(k)
		if letter == "-": continue
		var a: Vector2 = at_s(ss[k])[0]
		var b: Vector2 = at_s(ss[k+1])[0]
		var half := GRASS_HALF if letter != "S" else 9.0
		var i0 := maxi(ceili(minf(a.x,b.x)-half-gx0),0)
		var i1 := mini(floori(maxf(a.x,b.x)+half-gx0),n-1)
		var j0 := maxi(ceili(minf(a.y,b.y)-half-gz0),0)
		var j1 := mini(floori(maxf(a.y,b.y)+half-gz0),n-1)
		if i0 > i1 or j0 > j1: continue
		var ab := b-a
		var len2 := ab.length_squared()
		for jj in range(j0,j1+1):
			for ii in range(i0,i1+1):
				var p := Vector2(gx0+ii,gz0+jj)
				var t := clampf((p-a).dot(ab)/len2,0.0,1.0)
				if p.distance_squared_to(a+ab*t) > half*half: continue
				if letter == "B" and (hash(Vector2i(floori(p.x/3.0),floori(p.y/3.0)))&1023) < 410: continue
				var at := jj*n+ii
				rs[at] = minf(rs[at],-1.0)
				hit = true
	if hit: got.river = rs

## A frame at `p` along `d`, its ends at heights ya (back) and yb (front),
## rolled so its sides differ by `across` over 2*`half` (the street's paving on the ground).
static func _tilted(p: Vector2, d: Vector2, ya: float, yb: float, across: float, half: float) -> Transform3D:
	var pitch := atan2(yb-ya,SEG)
	var roll := atan2(across,2.0*half) if half > 0.0 else 0.0
	var b := Basis(Vector3.UP,atan2(-d.y,d.x))*Basis(Vector3.BACK,pitch)*Basis(Vector3.RIGHT,roll)
	return Transform3D(b,Vector3(p.x,(ya+yb)*0.5,p.y))

static func _scaled(p: Vector2, d: Vector2, y: float, sc: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,atan2(-d.y,d.x)).scaled_local(Vector3.ONE*sc),Vector3(p.x,y,p.y))

## A monument's frame: its front (local +z) toward the way from `p`, `out` the way's outward there.
static func _facing(p: Vector2, out: Vector2, y: float, sc := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,atan2(-out.x,-out.y)).scaled_local(Vector3.ONE*sc),Vector3(p.x,y,p.y))

func _lay(field: Object) -> void:
	var ss := station_s()
	var n := ss.size()
	var total := length()
	var rng := RandomNumberGenerator.new()
	rng.seed = 51877
	# Chunks of CHUNK stations, each in a frame along its stretch.
	var bounds: Array[float] = []
	var k := 0
	while k < n-1:
		var k1 := mini(k+CHUNK,n-1)
		var a: Vector2 = at_s(ss[k])[0]
		var b: Vector2 = at_s(ss[k1])[0]
		_chunk("tombs/%d" % k,_frame((a+b)*0.5,(b-a).normalized(),_h(field,(a+b)*0.5)))
		bounds.append(ss[k1])
		k = k1
	var chunk_of := func(s: float) -> int:
		for i in range(bounds.size()):
			if s <= bounds[i]: return i
		return bounds.size()-1
	# ---- The way: paving and kerbs, or steps.
	var steps: Array = []      # the stair under way: [chunk, XZ, direction, top]
	for bay in range(n-1):
		var letter := _paving(bay)
		var sa := ss[bay]
		var sb := ss[bay+1]
		var c: int = chunk_of.call((sa+sb)*0.5)
		var pa: Vector2 = at_s(sa)[0]
		var pb: Vector2 = at_s(sb)[0]
		var m := (pa+pb)*0.5
		var d := (pb-pa).normalized()
		if letter == "S":
			var s := sa+STEP_RUN*0.5
			while s < sb:
				var e := at_s(s)
				var p: Vector2 = e[0]
				var dd: Vector2 = e[1]
				# The highest ground under the step and a little up and down the way.
				var top := -INF
				for u: float in [-3.0,0.0,3.0]:
					for v: float in [-7.0,-3.5,0.0,3.5,7.0]: top = maxf(top,_h(field,p+dd*u+dd.orthogonal()*v))
				steps.append([c,p,dd,top+STEP_UP])
				s += STEP_RUN
			if bay == n-2 or _paving(bay+1) != "S":
				# The stair's end: its steps eased to STEP_RISE, then laid.
				for i in range(steps.size()-2,-1,-1): steps[i][3] = maxf(float(steps[i][3]),float(steps[i+1][3])-STEP_RISE)
				for i in range(1,steps.size()): steps[i][3] = maxf(float(steps[i][3]),float(steps[i-1][3])-STEP_RISE)
				for st: Array in steps:
					var id: StringName = &"tombs_step_broken" if rng.randf() < 0.14 else &"tombs_step"
					_put(int(st[0]),id,_frame(st[1],(st[2] as Vector2).orthogonal(),float(st[3])))
				steps.clear()
			continue
		if letter == "P" or letter == "B":
			var q := d.orthogonal()*(HALF_CLEAR-1.0)
			var g0 := _h(field,m-d*SEG*0.45)
			var g1 := _h(field,m+d*SEG*0.45)
			var flip := 1.0 if rng.randf() < 0.5 else -1.0
			var across := (_h(field,m+q)-_h(field,m-q))*flip
			_put(c,&"street_paving_broken" if letter == "B" else &"street_paving",
				_tilted(m,d*flip,g0 if flip > 0.0 else g1,g1 if flip > 0.0 else g0,across,HALF_CLEAR-1.0))
		for side in 2:
			if letter == "-" or bay in (KERB_GONE[side] as Array): continue
			var sd := -1.0 if side == 0 else 1.0
			var ka := pa+(at_s(sa)[1] as Vector2).orthogonal()*sd*ROW
			var kb := pb+(at_s(sb)[1] as Vector2).orthogonal()*sd*ROW
			var ya := _low(field,ka,d,2.0,2.0)
			var yb := _low(field,kb,d,2.0,2.0)
			_put(c,&"street_kerb",_tilted((ka+kb)*0.5,(kb-ka).normalized(),ya,yb,0.0,0.0))
	# ---- Across the way.
	var taken: Array = []      # [s, half length] no monument may stand in
	for e: Array in ACROSS:
		var s: float = e[0]
		var w := at_s(s)
		var p: Vector2 = w[0]
		var d: Vector2 = w[1]
		var c: int = chunk_of.call(s)
		var feet: Array[float] = []
		for sd: float in [-1.0,1.0]: feet.append(_low(field,p+d.orthogonal()*sd*ROW,d,2.0,2.0)+KERB_H)
		var yl := minf(feet[0],feet[1])
		match str(e[1]):
			"arch":
				_put(c,&"street_arch",_frame(p,d.orthogonal(),yl))
				taken.append([s,6.0])
			"cracked":
				var xf := _frame(p,d.orthogonal(),yl)
				breaks.add("tombs/arch",&"tombs_arch_cracked",xf,[[&"tombs_arch_broken",xf]])
				taken.append([s,6.0])
			"gate":
				_put(c,&"agora_gate",_frame(p,d,_low(field,p,d,3.0,17.0)-0.2))
				taken.append([s,16.0])
			"beam":
				var cy := yl-KERB_H-0.1
				for sd: float in [-1.0,1.0]:
					_put(c,&"column",_scaled(p+d.orthogonal()*sd*ROW,d,cy,0.72))
				_put(c,&"street_lintel_cross",_frame(p,d.orthogonal(),cy+0.05))
				taken.append([s,5.0])
	# ---- The cracked tower tomb, in the line on the inside of the last bend.
	var ct_s: float = CRACKED_TOMB[0]
	var ct_side: float = CRACKED_TOMB[1]
	var ctw := at_s(ct_s)
	var ct_out: Vector2 = (ctw[1] as Vector2).orthogonal()*ct_side
	var ct_p: Vector2 = (ctw[0] as Vector2)+ct_out*(HALF_CLEAR-float(CRACKED_TOMB[2])+7.7)
	var ct_xf := _facing(ct_p,ct_out,_low(field,ct_p,ct_out,7.0,7.0)-0.1)
	breaks.add("tombs/tower",&"tombs_tower_cracked",ct_xf,[[&"tombs_tower_stump",ct_xf]])
	# ---- The monuments, each side: one after another at uneven gaps.
	var letters: Array = KINDS.keys()
	for side in 2:
		var sd := -1.0 if side == 0 else 1.0
		var s := rng.randf_range(6.0,14.0)
		var last := ""
		while s < total-14.0:
			var w0 := at_s(s)
			var slope := absf(_h(field,(w0[0] as Vector2)+(w0[1] as Vector2)*5.0)-_h(field,(w0[0] as Vector2)-(w0[1] as Vector2)*5.0))/10.0
			var steep := slope > 0.14
			# A kind by weight, not the last one again.
			var sum := 0.0
			for l: String in letters:
				if l != last: sum += float(KINDS[l][4 if steep else 3])
			var pick := rng.randf()*sum
			var kind := "T"
			for l: String in letters:
				if l == last: continue
				pick -= float(KINDS[l][4 if steep else 3])
				if pick <= 0.0:
					kind = l
					break
			var spec: Array = KINDS[kind]
			var half: float = spec[2]
			s += half
			var w := at_s(s)
			var p: Vector2 = w[0]
			var d: Vector2 = w[1]
			var out := d.orthogonal()*sd
			var ok := s < total-12.0
			for t: Array in taken:
				if absf(s-float(t[0])) < float(t[1])+half+2.0: ok = false
			if sd == ct_side and absf(s-ct_s) < 7.7+half+3.0: ok = false
			if ok:
				last = kind
				var c: int = chunk_of.call(s)
				var back := rng.randf_range(0.3,3.2)
				var q := p+out*(HALF_CLEAR+back+float(spec[1]))
				var id: StringName = spec[0]
				if kind == "C" or kind == "c":
					var y := _low(field,q,d,1.6,1.6)-0.1
					_put(c,id,_scaled(q,d if rng.randf() < 0.5 else -d,y,COL))
					if kind == "c" and rng.randf() < 0.6:
						_put(c,&"column_drums",_scaled(q,out.rotated(rng.randf_range(-0.5,0.5)),_low(field,q+out*9.0,d,5.0,5.0)-0.1,COL))
				else:
					var y := _low(field,q,d,half*0.8,float(spec[1])*0.8)-0.1
					var turn := 0.0 if kind in ["H","h","X","T"] else rng.randf_range(-0.12,0.12)
					_put(c,id,_facing(q,out.rotated(turn),y))
			s += half+(rng.randf_range(1.5,9.0) if rng.randf() < 0.75 else rng.randf_range(14.0,30.0))
