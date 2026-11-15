## The ice tunnel (docs/design/endless-flight/spec-icefield.md, lane tunnel): a
## flown bore inside the Peak's massif, from a mouth in the glacier's flank on
## the ice gorge's side (-v), climbing under the ice gorge's first bowls and
## the prow to a mouth at the spine's end over the rock gorge's last bowl, the
## saddle straight ahead. Hand-sited in the massif's frame (PeakMassif.world),
## seed 1's land: KNOTS (a, v), the floor by FLOOR (distance along, height
## over the sea).
##
## The path and the solid only, safe on a worker (the chunk build reads
## `hole_mask`); land_ice_tunnel.gd builds what it stands and answers the
## flight. Like tunnel_sites.gd's bore: a flat floor and a superellipse vault
## (`profile`, `roof_over`, `profile_point`), but the floor climbs with the
## path (`floor_at`), and the field is not reshaped: the land's mesh is holed
## where it crosses the bore at the two mouths and round each window
## (`hole_mask`), and the solid answers inside.
##
## `--ice-tunnel=0` off.
extends RefCounted

const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const SEA_Y := -40.0

## The line: (a, v) in the massif's frame. The first and the last knots
## stand outside the rock, so the mouths' approach is on line.
const KNOTS := [
	[2262.0,-212.0],
	[2180.0,-292.0],
	[2050.0,-350.0],
	[1890.0,-340.0],
	[1720.0,-340.0],
	[1545.0,-270.0],
	[1360.0,-170.0],
	[1200.0,-60.0],
	[1060.0,-15.0],
	[945.0,0.0],
	[860.0,65.0],
	[810.0,125.0],
	[740.0,165.0],
	[640.0,172.0],
	[560.0,195.0],
	[480.0,160.0],
	[400.0,70.0],
	[345.0,5.0],
]
## The floor: (m along the path, height over the sea), straight between,
## then smoothed. Level past mouth A, under the ice gorge's first bowl (its
## floor about 60 m over the vault), then one climb to mouth B.
const FLOOR := [[0.0,292.0],[500.0,322.0],[700.0,364.0],[1851.0,809.0],[2111.0,820.0]]
## The floor's climb is smoothed over this much path either side (m).
const SMOOTH := 70.0
## A sample every STEP m along the path.
const STEP := 2.0

## The bore: half width at the floor and crown over it (m), its roundness (a
## superellipse's power: 2 round, higher boxier). Higher than wide; the width
## is at least WorldScale.opening(TOY) across at the plane's working height.
const TOY := 5.0
const HALF := 12.0
const CROWN := 30.0
const ROUND := 2.6
## The chamber: from CHAMBER.x to CHAMBER.y along the path (m), the bore grown
## to CHAMBER_HALF and CHAMBER_CROWN, eased in and out over CHAMBER_EASE m.
## It sits where the rock over it is deepest (130 m and more).
const CHAMBER := Vector2(1030.0,1140.0)
const CHAMBER_HALF := 26.0
const CHAMBER_CROWN := 46.0
const CHAMBER_EASE := 40.0
## The windows to the sky: shafts up from the vault's crown, at these
## distances along the path (m), WINDOW_R m round (the chamber's light).
const WINDOWS := [1085.0]
const WINDOW_R := 8.0
## The mouths: where the bore meets the land (m along the path); the tube
## runs MOUTH_OUT_A / MOUTH_OUT_B m past each, out to where the land in front
## comes down to the floor (the bank under mouth A is a 40 m ramp).
const MOUTH_A := 105.0
const MOUTH_B := 1826.0
const MOUTH_OUT := 14.0
const MOUTH_OUT_A := 50.0
const MOUTH_OUT_B := 45.0
## The open stretches (m along the path): where the land comes down into the
## bore, so the land is holed where it lies inside the bore (HOLE_PAD m past
## the vault) and the tube's mesh is trimmed where it stands out of the land:
## the two mouths, and the gully between the blade and the spine that the
## bore crosses in the open (a window to the sky, 100 m of slot in its floor).
## The crossing stays in the blade past the Slot's eye at a 960, then cuts the
## Slot line steeply at a ~865, between its blades at a 890 (+v) and a 835 (-v).
const OPENINGS := [Vector2(MOUTH_A-MOUTH_OUT_A,MOUTH_A+26.0),Vector2(1500.0,1600.0),Vector2(MOUTH_B-26.0,MOUTH_B+MOUTH_OUT_B)]
const HOLE_PAD := 3.0
## The window's hole: WINDOW_PAD m past its rim.
const WINDOW_PAD := 2.0
## The lookup grid's cell (m) and the reach a sample is filed under.
const GRID := 16.0
const REACH := 48.0

## The path (world): samples STEP m apart, their tangents (xz, unit), floor
## heights (world y) and distances.
var pts := PackedVector2Array()
var tans := PackedVector2Array()
var ys := PackedFloat32Array()
var length := 0.0
var box := Rect2()
## The windows: {s, at (world xz), floor (world y), crown (world y)}.
var windows: Array = []
var _grid := {}

static var _made: Dictionary = {}
static var _lock := Mutex.new()

## Off by default (taken out 2026-11-14); `--ice-tunnel=1` brings it back.
static func wanted() -> bool:
	return "--ice-tunnel=1" in LaunchArgs.user_args()

## The tunnel in `massif`'s frame (PeakMassif: `world(a, v)`), built once per
## frame; null without a massif or with `--ice-tunnel=0`.
static func make(massif: RefCounted) -> RefCounted:
	if massif == null or not wanted(): return null
	var c: Vector2 = massif.centre
	var f: Vector2 = massif.facing
	var key := "%.2f,%.2f,%.4f,%.4f" % [c.x,c.y,f.x,f.y]
	_lock.lock()
	var got: RefCounted = _made.get(key)
	if got == null:
		got = new()
		got._build(massif)
		_made[key] = got
	_lock.unlock()
	return got

func _build(massif: RefCounted) -> void:
	# The knots in the world, a Catmull-Rom through them, walked finely.
	var kp: Array[Vector2] = []
	for k: Array in KNOTS:
		kp.append(massif.world(float(k[0]),float(k[1])))
	var fine := PackedVector2Array()
	var fine_s := PackedFloat32Array()
	var run := 0.0
	var last := kp[0]
	for i in kp.size()-1:
		var p0: Vector2 = kp[maxi(i-1,0)]
		var p1: Vector2 = kp[i]
		var p2: Vector2 = kp[i+1]
		var p3: Vector2 = kp[mini(i+2,kp.size()-1)]
		if i == 0: p0 = p1*2.0-p2
		if i+2 >= kp.size(): p3 = p2*2.0-p1
		for j in 40:
			var p := _cr(p0,p1,p2,p3,float(j)/40.0)
			run += p.distance_to(last)
			last = p
			fine.append(p)
			fine_s.append(run)
	fine.append(kp[kp.size()-1])
	run += kp[kp.size()-1].distance_to(last)
	fine_s.append(run)
	length = run
	# Resample every STEP m; the floor straight between the knots by
	# distance, then smoothed.
	var n := int(length/STEP)+1
	var raw := PackedFloat32Array()
	var k := 0
	for i in n:
		var s := minf(i*STEP,length)
		while k < fine_s.size()-2 and fine_s[k+1] < s: k += 1
		var t := clampf((s-fine_s[k])/maxf(fine_s[k+1]-fine_s[k],1e-4),0.0,1.0)
		pts.append(fine[k].lerp(fine[k+1],t))
		var m := 0
		while m < FLOOR.size()-2 and float(FLOOR[m+1][0]) < s: m += 1
		var u := clampf((s-float(FLOOR[m][0]))/maxf(float(FLOOR[m+1][0])-float(FLOOR[m][0]),1e-4),0.0,1.0)
		raw.append(lerpf(float(FLOOR[m][1]),float(FLOOR[m+1][1]),u)+SEA_Y)
	var w := int(SMOOTH/STEP)
	for i in n:
		var sum := 0.0
		var cnt := 0
		for j in range(i-w,i+w+1):
			sum += raw[clampi(j,0,n-1)]
			cnt += 1
		ys.append(sum/cnt)
	for i in n:
		var a := pts[maxi(i-1,0)]
		var b := pts[mini(i+1,n-1)]
		tans.append((b-a).normalized())
	# The lookup grid and the box.
	box = Rect2(pts[0],Vector2.ZERO)
	for i in n:
		box = box.expand(pts[i])
		var p := pts[i]
		for gj in range(floori((p.y-REACH)/GRID),floori((p.y+REACH)/GRID)+1):
			for gi in range(floori((p.x-REACH)/GRID),floori((p.x+REACH)/GRID)+1):
				var key := Vector2i(gi,gj)
				if not _grid.has(key): _grid[key] = PackedInt32Array()
				var arr: PackedInt32Array = _grid[key]
				arr.append(i)
				_grid[key] = arr
	box = box.grow(REACH)
	for s: float in WINDOWS:
		var pr := profile(s)
		windows.append({"s":s,"at":at_s(s),"floor":floor_at(s),"crown":floor_at(s)+pr.y})

static func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t*t
	var t3 := t2*t
	return 0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t2+(-p0+3.0*p1-3.0*p2+p3)*t3)

# --- Along the path ------------------------------------------------------------------

func _i(s: float) -> int:
	return clampi(int(s/STEP),0,pts.size()-2)

## The path's point (world xz) at `s`.
func at_s(s: float) -> Vector2:
	var i := _i(s)
	return pts[i].lerp(pts[i+1],clampf(s/STEP-i,0.0,1.0)) if s >= 0.0 and s <= length else (pts[0]+tans[0]*s if s < 0.0 else pts[pts.size()-1]+tans[tans.size()-1]*(s-length))

## The tangent (xz, unit) at `s`.
func tan_s(s: float) -> Vector2:
	var i := _i(s)
	return tans[i].lerp(tans[i+1],clampf(s/STEP-i,0.0,1.0)).normalized()

## The floor (world y) at `s`.
func floor_at(s: float) -> float:
	var i := _i(s)
	return lerpf(ys[i],ys[i+1],clampf(s/STEP-i,0.0,1.0))

## The floor's grade (rise over run) at `s`.
func grade(s: float) -> float:
	return (floor_at(s+STEP)-floor_at(s-STEP))/(2.0*STEP)

## Vector3(s along, d across (+ to the left of the way), 1) for world (x, z)
## near the path, or Vector3(NAN, NAN, 0) far from it.
func local(x: float, z: float) -> Vector3:
	var arr: Variant = _grid.get(Vector2i(floori(x/GRID),floori(z/GRID)))
	if arr == null: return Vector3(NAN,NAN,0.0)
	var q := Vector2(x,z)
	var best := -1
	var bd := INF
	for i: int in arr:
		var dd := pts[i].distance_squared_to(q)
		if dd < bd:
			bd = dd
			best = i
	# Onto the nearer of the two segments either side.
	var out := Vector3(NAN,NAN,0.0)
	var od := INF
	for i0 in [best-1,best]:
		if i0 < 0 or i0 >= pts.size()-1: continue
		var a := pts[i0]
		var ab := pts[i0+1]-a
		var t := (q-a).dot(ab)/maxf(ab.length_squared(),1e-6)
		var lo := 0.0 if i0 > 0 else -INF
		var hi := 1.0 if i0 < pts.size()-2 else INF
		t = clampf(t,lo,hi)
		var c := a+ab*t
		var dd := c.distance_squared_to(q)
		if dd < od:
			od = dd
			var tg := ab.normalized()
			out = Vector3((i0+t)*STEP,tg.cross(q-a)*-1.0,1.0)
	return out

## The bore's cross-section at `s`: Vector3(half width, crown over the floor,
## roundness).
func profile(s: float) -> Vector3:
	var c := _chamber(s)
	return Vector3(lerpf(HALF,CHAMBER_HALF,c),lerpf(CROWN,CHAMBER_CROWN,c),ROUND)

func _chamber(s: float) -> float:
	return smoothstep(CHAMBER.x-CHAMBER_EASE,CHAMBER.x,s)*(1.0-smoothstep(CHAMBER.y,CHAMBER.y+CHAMBER_EASE,s))

## The vault's height over the floor at `d` across for profile `pr`, NAN past
## the walls.
static func roof_over(pr: Vector3, d: float) -> float:
	var x := absf(d)/pr.x
	if x >= 1.0: return NAN
	return pr.y*pow(1.0-pow(x,pr.z),1.0/pr.z)

## The profile's point at `th` (0 the +d wall's foot, PI/2 the crown, PI the
## -d foot): Vector2(d, height over the floor).
static func profile_point(pr: Vector3, th: float) -> Vector2:
	var c := cos(th)
	var sn := sin(th) if sin(th) > 1e-5 else 0.0
	return Vector2(pr.x*signf(c)*pow(absf(c),2.0/pr.z),pr.y*pow(sn,2.0/pr.z))

## The half width clear at `h` m over the floor for profile `pr`.
static func half_at(pr: Vector3, h: float) -> float:
	var f := clampf(h/pr.y,0.0,0.9999)
	return pr.x*pow(1.0-pow(f,pr.z),1.0/pr.z)

## Whether `s` is on the tube (between the faces, and MOUTH_OUT past each).
## On an open stretch the solid is the bore only where the land is over it
## (land_ice_tunnel.gd `ground`).
func on_tube(s: float) -> bool:
	return s >= MOUTH_A-MOUTH_OUT_A and s <= MOUTH_B+MOUTH_OUT_B

## Whether `s` is on an open stretch (OPENINGS), `pad` m wider each way.
static func open_at(s: float, pad := 0.0) -> bool:
	for op: Vector2 in OPENINGS:
		if s >= op.x-pad and s <= op.y+pad: return true
	return false

# --- The solid -----------------------------------------------------------------------

## Vector2(floor, roof) (world y) over (x, z) in the bore's tube, `grow` m
## off the walls and the vault (a wingtip's reach); NAN off it.
func bore(x: float, z: float, grow := 0.0) -> Vector2:
	if not box.has_point(Vector2(x,z)): return Vector2(NAN,NAN)
	var q := local(x,z)
	if is_nan(q.x) or not on_tube(q.x): return Vector2(NAN,NAN)
	var pr := profile(q.x)
	var h := roof_over(pr,absf(q.y)+grow)
	if is_nan(h): return Vector2(NAN,NAN)
	var f := floor_at(q.x)
	return Vector2(f,f+h)

## Which window's shaft (x, z) is in, `grow` m in from its rim, or -1.
func window_at(x: float, z: float, grow := 0.0) -> int:
	for i in windows.size():
		var w: Dictionary = windows[i]
		if (w.at as Vector2).distance_to(Vector2(x,z)) < WINDOW_R-grow: return i
	return -1

# --- The land's holes ----------------------------------------------------------------

## The chunk's vertices to hole (LandStream `_portal_holes`): 1 where a vertex
## of the grid at (x0, z0), `step` m, `cells` across (heights in `verts`' y)
## lies in the bore on an open stretch (grown HOLE_PAD) or a window's rim;
## empty if none.
func hole_mask(verts: PackedVector3Array, x0: float, z0: float, step: float, cells: int) -> PackedByteArray:
	var out := PackedByteArray()
	var size := step*cells
	if not box.intersects(Rect2(x0,z0,size,size)): return out
	var n := cells+1
	var any := false
	for op: Vector2 in OPENINGS:
		var s0 := op.x
		var s1 := op.y
		# Bound the stretch by its samples.
		var lo := Vector2(INF,INF)
		var hi := Vector2(-INF,-INF)
		var ss := s0
		while ss <= s1+STEP:
			var p := at_s(minf(ss,s1))
			lo = Vector2(minf(lo.x,p.x),minf(lo.y,p.y))
			hi = Vector2(maxf(hi.x,p.x),maxf(hi.y,p.y))
			ss += 8.0
		var r := CHAMBER_HALF+HOLE_PAD+step
		var i0 := clampi(floori((lo.x-r-x0)/step),0,cells)
		var i1 := clampi(ceili((hi.x+r-x0)/step),0,cells)
		var j0 := clampi(floori((lo.y-r-z0)/step),0,cells)
		var j1 := clampi(ceili((hi.y+r-z0)/step),0,cells)
		if i0 >= i1 or j0 >= j1: continue
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var x := x0+i*step
				var z := z0+j*step
				var q := local(x,z)
				if is_nan(q.x) or q.x < s0 or q.x > s1: continue
				var pr := profile(q.x)
				var grown := Vector3(pr.x+HOLE_PAD+step,pr.y+HOLE_PAD+step,pr.z)
				var h := roof_over(grown,q.y)
				if is_nan(h): continue
				var y := verts[j*n+i].y
				var f := floor_at(q.x)
				if y < f-step or y > f+h: continue
				if not any:
					out.resize(n*n)
					any = true
				out[j*n+i] = 1
	for w: Dictionary in windows:
		var at: Vector2 = w.at
		var r := WINDOW_R+WINDOW_PAD
		var i0 := clampi(floori((at.x-r-x0)/step),0,cells)
		var i1 := clampi(ceili((at.x+r-x0)/step),0,cells)
		var j0 := clampi(floori((at.y-r-z0)/step),0,cells)
		var j1 := clampi(ceili((at.y+r-z0)/step),0,cells)
		if i0 >= i1 or j0 >= j1: continue
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				if Vector2(x0+i*step,z0+j*step).distance_to(at) > r: continue
				if not any:
					out.resize(n*n)
					any = true
				out[j*n+i] = 1
	return out

## A point deep inside (world), for a find (the chamber's middle, 3 m over
## its floor).
func deep_point() -> Vector3:
	var s := (CHAMBER.x+CHAMBER.y)*0.5
	var p := at_s(s)
	return Vector3(p.x,floor_at(s)+3.0,p.y)
