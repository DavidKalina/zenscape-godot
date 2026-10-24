extends RefCounted
## Mountain tunnels (docs/design/endless-flight/overgrown-tunnels-brief.md,
## spec-mountain-tunnels.md): a massif raised over a winding bore, the bore
## running from a mouth on one flank to a mouth on the other. A layer over
## the land field, as the ponds and the slot halls' cuts are: LandField
## (land_field.gd) raises the massif and cuts the mouths' trenches after the
## ponds, before the slot halls' cut, so the recipe and the native kernels
## don't change and wilderness (no `tunnels` layer) hashes as before.
##
## The path: alternating straight hall stretches (whole hall bays, `hall`)
## and caverns of bare rock (`cave`), a cavern holding one to three gentle
## bends (arcs of RADIUS m, TURN rad, their turns alternating so the run
## never strays far from its first way) with short straight runs between.
## The floor is level from mouth to mouth. The path is kept as samples
## STEP m apart along it (`pts`, `tans`, `ss`), and as a table over its
## first way (`u`, from mouth A): the path's offset across, its tangent's
## cos and sin and the distance along it, every STEP m of `u`. The path
## never turns past a right angle from its first way, so each `u` has one
## path point, and `local` reads (distance along, offset across) from it.
##
## The massif: a crest along the path, COVER_MOUTH m over the floor at a
## mouth, rising over RISE m to `crest` m over the floor (varied by noise,
## a short range of peaks and saddles), its flanks falling at FLANK with
## gullies of noise, and past the mouths its nose falling at END. It is
## blended into the land with a smooth max (BLEND m), so it has no plinth
## edge and the land past it is the land exactly. Each mouth then has a
## trench cut into the nose, as hall_sites.gd's cut is: flat for APRON m
## at the floor, then climbing at GRADE to the land, with sheer walls
## leaning back.
##
## `--tunnel-test`: one tunnel TEST_AHEAD m ahead of the start, on its
## heading (the world's spawn, `--at=` and `--heading=`). Named
## `<world>/tunnel/test`; a streamed tunnel will be `<world>/tunnel/<cx>_<cz>`.
## Placed through scripts/layout_overrides.gd: a move in the layout file
## moves mouth A (its yaw and place), and the path, the massif and the
## trenches follow.

const SEA_Y := -40.0
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const Sites = preload("res://scripts/endless/hall_sites.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The bore's cross-section (m): its half width and its vault's crown over
## the floor, in the hall stretches (the slot halls' walls' outer faces)
## and in the caverns (wider and taller; wider still on a bend's inside).
static var HALL_HALF: float = Sites.HALF
const HALL_VAULT := 18.0
static var CAVE_HALF: float = Sites.HALF+5.0
const CAVE_VAULT := 22.0
const CAVE_INSIDE := 6.0

## The path: its length (m, rolled), the bends over the run, a bend's
## radius (m) and turn (rad), a cavern's straight runs between its bends
## and at its ends (m), a hall stretch's fewest bays, the samples' spacing.
const LENGTH := Vector2(1400.0,2100.0)
const BENDS := Vector2i(3,5)
const RADIUS := Vector2(130.0,220.0)
const TURN := Vector2(deg_to_rad(22.0),deg_to_rad(34.0))
const CAVE_RUN := Vector2(20.0,60.0)
const CAVE_END := 16.0
const HALL_BAYS_MIN := 10
const STEP := 4.0

## The massif: its crest over the floor (m, rolled), at least CREST_OVER m
## over the highest land on the path; over the floor at a mouth (m); the
## rise from a mouth to the crest (m along); how much the crest dips in its
## saddles (0..1) and the noise's wavelength (m); the flanks' fall (rise
## over run) and the crest's rounding (m across); the nose's fall past a
## mouth; the blend into the land (m); the gullies' depth (m) and
## wavelength (m), and from how far off the path they start (m).
const CREST := Vector2(280.0,380.0)
const CREST_OVER := 150.0
const COVER_MOUTH := 34.0
const RISE := 650.0
const CREST_VARY := 0.34
const CREST_WAVE := 380.0
const FLANK := 0.62
## How much each flank's fall varies along the path (0..1): shoulders and
## steeper faces, each side its own.
const FLANK_VARY := 0.3
const CREST_R := 45.0
const END := 0.7
const BLEND := 30.0
const GULLY := 70.0
const GULLY_WAVE := 240.0
const GULLY_FROM := Vector2(35.0,170.0)
## The meadow fades over this much lift (m), and no river runs on lifted land.
const MEADOW_LIFT := Vector2(4.0,30.0)

## The mouths' trenches (hall_sites.gd's cut): the walls' rise, sheer
## height and lean, the floor's sink, the flat, the climb and its most.
const EDGE := Sites.EDGE
const SHEER := Sites.SHEER
const LEAN := Sites.LEAN
const SINK := Sites.SINK
const APRON := 24.0
const GRADE := Sites.GRADE
const RAMP_MOST := 100.0
static var TRENCH_WIDE: float = HALL_HALF+EDGE+60.0
const TRENCH_REACH := APRON+RAMP_MOST

## `--tunnel-test`: mouth A this far ahead of the start (m).
const TEST_AHEAD := 450.0

## One tunnel. Built once (on whichever thread asks first), then only read.
class Site extends RefCounted:
	var name := ""
	## Mouth A on the floor, the way in along +X (the hall frame's way).
	var frame := Transform3D()
	var coded := Transform3D()
	var seed := 0
	var floor_y := 0.0
	## The crest over the floor at its highest (m).
	var crest := 0.0
	var length := 0.0
	## The pieces in order: {kind ("hall"/"cave"), s0, s1, and for a hall
	## its bays, for a cave its bends}; the segments: {piece, type
	## ("line"/"arc"), s0, s1, turn, radius}.
	var pieces: Array = []
	var segs: Array = []
	## The samples along the path (world xz), their tangents and distances.
	var pts := PackedVector2Array()
	var tans := PackedVector2Array()
	var ss := PackedFloat32Array()
	## Mouth A (xz) and the first way; mouth B and its way out.
	var origin := Vector2.ZERO
	var way := Vector2.RIGHT
	var mouth_b := Vector2.ZERO
	var out_b := Vector2.RIGHT
	## The table over u (every STEP m from mouth A along `way`).
	var u_end := 0.0
	var tv := PackedFloat32Array()
	var tc := PackedFloat32Array()
	var tsn := PackedFloat32Array()
	var ts := PackedFloat32Array()
	## Everything the massif and the trenches touch (world xz).
	var box := Rect2()
	var crest_noise: FastNoiseLite
	var gully: FastNoiseLite

## The tunnels' density: the world's `tunnels` layer (0: none), then
## `--tunnels=X` or `--no-tunnels`.
static func wanted(default := 0.0) -> float:
	var out := default
	for a: String in LaunchArgs.user_args():
		if a == "--no-tunnels": out = 0.0
		elif a.begins_with("--tunnels="): out = maxf(0.0,float(a.get_slice("=",1)))
	return out

## Whether `--tunnel-test` asks for the one tunnel ahead of the start.
static func test_wanted() -> bool:
	return "--tunnel-test" in LaunchArgs.user_args()

## The test tunnel: mouth A TEST_AHEAD m ahead of the start on its heading,
## the floor at the land there (read from `impl`, the field doing the work,
## at full detail). `world` the WorldProfile (its spawn).
static func test_site(impl: Object, seed: int, world: RefCounted) -> Site:
	var at: Vector2 = world.spawn.get("at",Vector2.ZERO)
	var deg := float(world.spawn.get("heading",0.0))
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--at="):
			var p := a.get_slice("=",1).split(",")
			if p.size() >= 2: at = Vector2(float(p[0]),float(p[1]))
		elif a.begins_with("--heading=") and a != "--heading=sun": deg = float(a.get_slice("=",1))
	# Clockwise from -z.
	var fwd := Vector2(sin(deg_to_rad(deg)),-cos(deg_to_rad(deg)))
	var mouth := at+fwd*TEST_AHEAD
	var was: float = impl.detail
	impl.detail = 0.0
	var floor_y := maxf(_h(impl,mouth.x,mouth.y),SEA_Y+3.0)
	var name := "%s/tunnel/test" % _world_id()
	var coded := Transform3D(Basis(Vector3.UP,atan2(-fwd.y,fwd.x)),Vector3(mouth.x,floor_y,mouth.y))
	var xf := LayoutOverrides.xform(name,coded)
	var frame := Transform3D(Basis(Vector3.UP,atan2(-xf.basis.x.z,xf.basis.x.x)),xf.origin)
	var t := _build(impl,hash([seed,"tunnel_test"]),frame,true)
	impl.detail = was
	t.name = name
	t.coded = coded
	return t

static func _h(impl: Object, x: float, z: float) -> float:
	return (impl.sample(x,z) as Vector2).x

static func _world_id() -> String:
	return String(preload("res://scripts/endless/world/world_profile.gd").current().id)

# --- The path ----------------------------------------------------------------------

## A tunnel from frame `frame` (mouth A on the floor, the way in along +X),
## its path rolled from `seed`. `test`: 2 or 3 hall stretches, else 3 to 5.
static func _build(impl: Object, seed: int, frame: Transform3D, test: bool) -> Site:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var t := Site.new()
	t.seed = seed
	t.frame = frame
	t.floor_y = frame.origin.y
	t.origin = Vector2(frame.origin.x,frame.origin.z)
	t.way = Vector2(frame.basis.x.x,frame.basis.x.z).normalized()
	var halls := rng.randi_range(2,3) if test else rng.randi_range(3,5)
	var caves := halls-1
	var bends := rng.randi_range(BENDS.x,BENDS.y)
	bends = clampi(bends,caves,caves*3)
	var per: Array = []
	for c in caves: per.append(1)
	for b in bends-caves: per[b % caves] += 1
	# The caverns' segments, their bends alternating.
	var sign := 1.0 if rng.randf() < 0.5 else -1.0
	var cave_segs: Array = []
	var cave_len := 0.0
	for c in caves:
		var list: Array = [{"type":"line","len":CAVE_END,"turn":0.0,"radius":0.0}]
		for b in int(per[c]):
			if b > 0: list.append({"type":"line","len":rng.randf_range(CAVE_RUN.x,CAVE_RUN.y),"turn":0.0,"radius":0.0})
			var r := rng.randf_range(RADIUS.x,RADIUS.y)
			var a := rng.randf_range(TURN.x,TURN.y)
			list.append({"type":"arc","len":r*a,"turn":a*sign,"radius":r})
			sign = -sign
		list.append({"type":"line","len":CAVE_END,"turn":0.0,"radius":0.0})
		for sg: Dictionary in list: cave_len += float(sg.len)
		cave_segs.append(list)
	# The hall stretches share the rest, in whole bays.
	var want := rng.randf_range(LENGTH.x,LENGTH.y)
	var weights: Array = []
	var wsum := 0.0
	for h in halls:
		var w := rng.randf_range(0.8,1.2)
		weights.append(w)
		wsum += w
	var hall_bays: Array = []
	for h in halls:
		hall_bays.append(maxi(HALL_BAYS_MIN,roundi((want-cave_len)*float(weights[h])/wsum/Hall.BAY)))
	# Lay the pieces out.
	var s := 0.0
	for h in halls:
		var hl := int(hall_bays[h])*Hall.BAY
		t.pieces.append({"kind":"hall","s0":s,"s1":s+hl,"bays":int(hall_bays[h])})
		t.segs.append({"piece":t.pieces.size()-1,"type":"line","s0":s,"s1":s+hl,"turn":0.0,"radius":0.0})
		s += hl
		if h == halls-1: break
		var c0 := s
		for sg: Dictionary in cave_segs[h]:
			t.segs.append({"piece":t.pieces.size(),"type":sg.type,"s0":s,"s1":s+float(sg.len),"turn":sg.turn,"radius":sg.radius})
			s += float(sg.len)
		t.pieces.append({"kind":"cave","s0":c0,"s1":s,"bends":int(per[h])})
	t.length = s
	_sample_path(t)
	_table(t)
	# The crest: over the highest land on the path by CREST_OVER at least.
	var top := t.floor_y
	var k := 0
	while k < t.pts.size():
		top = maxf(top,_h(impl,t.pts[k].x,t.pts[k].y))
		k += 12
	t.crest = maxf(rng.randf_range(CREST.x,CREST.y),top-t.floor_y+CREST_OVER)
	t.crest_noise = FastNoiseLite.new()
	t.crest_noise.seed = seed & 0x7fffffff
	t.crest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	t.crest_noise.frequency = 1.0/CREST_WAVE
	t.crest_noise.fractal_octaves = 3
	t.gully = FastNoiseLite.new()
	t.gully.seed = (seed >> 3) & 0x7fffffff
	t.gully.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	t.gully.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	t.gully.frequency = 1.0/GULLY_WAVE
	t.gully.fractal_octaves = 4
	# The box: the path grown by the flanks' reach.
	var reach := (t.crest+GULLY+BLEND)/(FLANK*(1.0-FLANK_VARY))+CREST_R
	var lo := t.pts[0]
	var hi := t.pts[0]
	for p: Vector2 in t.pts:
		lo = Vector2(minf(lo.x,p.x),minf(lo.y,p.y))
		hi = Vector2(maxf(hi.x,p.x),maxf(hi.y,p.y))
	t.box = Rect2(lo,hi-lo).grow(reach)
	return t

## The path's samples every STEP m (and its end), from its segments.
static func _sample_path(t: Site) -> void:
	var p := t.origin
	var d := t.way
	t.pts.append(p)
	t.tans.append(d)
	t.ss.append(0.0)
	for sg: Dictionary in t.segs:
		var s0 := float(sg.s0)
		var s1 := float(sg.s1)
		var n := maxi(1,ceili((s1-s0)/STEP))
		var ds := (s1-s0)/n
		var turn := float(sg.turn)/n
		for i in n:
			# Exact on an arc: the chord at the half-turn.
			if turn != 0.0:
				var chord := 2.0*float(sg.radius)*sin(absf(turn)*0.5)
				p += d.rotated(turn*0.5)*chord
				d = d.rotated(turn)
			else:
				p += d*ds
			t.pts.append(p)
			t.tans.append(d)
			t.ss.append(s0+ds*(i+1))
	t.mouth_b = p
	t.out_b = d

## The table over u, every STEP m from mouth A (the path continued past
## mouth B along its way out, so the last step reads right).
static func _table(t: Site) -> void:
	var us := PackedFloat32Array()
	var vs := PackedFloat32Array()
	var cs := PackedFloat32Array()
	var sns := PackedFloat32Array()
	var sl := PackedFloat32Array()
	var n := Vector2(-t.way.y,t.way.x)
	for i in t.pts.size():
		var q := t.pts[i]-t.origin
		us.append(q.dot(t.way))
		vs.append(q.dot(n))
		cs.append(t.tans[i].dot(t.way))
		sns.append(t.tans[i].dot(n))
		sl.append(t.ss[i])
	for e in 3:
		var q := t.mouth_b+t.out_b*STEP*(e+1)-t.origin
		us.append(q.dot(t.way))
		vs.append(q.dot(n))
		cs.append(t.out_b.dot(t.way))
		sns.append(t.out_b.dot(n))
		sl.append(t.length+STEP*(e+1))
	t.u_end = us[t.pts.size()-1]
	var count := ceili(t.u_end/STEP)+1
	var j := 0
	for k in count+1:
		var u := k*STEP
		while j < us.size()-2 and us[j+1] < u: j += 1
		var a := clampf((u-us[j])/maxf(us[j+1]-us[j],0.0001),0.0,1.0)
		t.tv.append(lerpf(vs[j],vs[j+1],a))
		t.tc.append(lerpf(cs[j],cs[j+1],a))
		t.tsn.append(lerpf(sns[j],sns[j+1],a))
		t.ts.append(lerpf(sl[j],sl[j+1],a))

## (x, z) in tunnel `t`'s path frame: Vector2(distance along the path from
## mouth A, offset across it); straight on past either mouth.
static func local(t: Site, x: float, z: float) -> Vector2:
	var dx := x-t.origin.x
	var dz := z-t.origin.y
	var u := dx*t.way.x+dz*t.way.y
	var v := -dx*t.way.y+dz*t.way.x
	if u <= 0.0: return Vector2(u,v)
	if u >= t.u_end:
		var q := Vector2(x,z)-t.mouth_b
		return Vector2(t.length+q.dot(t.out_b),t.out_b.x*q.y-t.out_b.y*q.x)
	var f := u/STEP
	var k := mini(int(f),t.tv.size()-2)
	var a := f-k
	var dv := v-lerpf(t.tv[k],t.tv[k+1],a)
	return Vector2(lerpf(t.ts[k],t.ts[k+1],a)+dv*lerpf(t.tsn[k],t.tsn[k+1],a),dv*lerpf(t.tc[k],t.tc[k+1],a))

## The path's point (world xz) at distance `s` along it, and its tangent.
static func at_s(t: Site, s: float) -> Array:
	if s <= 0.0: return [t.origin+t.way*s,t.way]
	if s >= t.length: return [t.mouth_b+t.out_b*(s-t.length),t.out_b]
	var i := clampi(int(s/STEP),0,t.ss.size()-2)
	while i < t.ss.size()-2 and t.ss[i+1] < s: i += 1
	while i > 0 and t.ss[i] > s: i -= 1
	var a := clampf((s-t.ss[i])/maxf(t.ss[i+1]-t.ss[i],0.0001),0.0,1.0)
	return [t.pts[i].lerp(t.pts[i+1],a),t.tans[i].slerp(t.tans[i+1],a)]

# --- The massif and the trenches ------------------------------------------------------

## The crest's height (world y) at distance `s` along the path.
static func top(t: Site, s: float) -> float:
	var c := t.floor_y+COVER_MOUTH
	if s <= 0.0: return c+s*END
	if s >= t.length: return c-(s-t.length)*END
	var q := clampf(minf(s,t.length-s)/RISE,0.0,1.0)
	var r := 1.0-(1.0-q)*(1.0-q)
	var vary := 1.0-CREST_VARY*(0.5+0.5*t.crest_noise.get_noise_1d(s))
	return c+(t.crest-COVER_MOUTH)*r*vary

## The massif's surface (world y) at (x, z), before it meets the land.
static func massif(t: Site, x: float, z: float) -> float:
	var q := local(t,x,z)
	var a := absf(q.y)
	# Each side's fall varies along the path (the crest noise, read apart).
	var fall := FLANK*(1.0+FLANK_VARY*t.crest_noise.get_noise_2d(q.x*0.7,7000.0 if q.y > 0.0 else -7000.0))
	var y := top(t,q.x)-fall*(a*a/(2.0*CREST_R) if a < CREST_R else a-CREST_R*0.5)
	var w := smoothstep(GULLY_FROM.x,GULLY_FROM.y,a)
	if w > 0.0: y += GULLY*w*t.gully.get_noise_2d(x,z)
	return y

## A smooth max: exactly the larger where they're `k` or more apart.
static func _smax(a: float, b: float, k: float) -> float:
	var h := clampf(0.5+0.5*(a-b)/k,0.0,1.0)
	return lerpf(b,a,h)+k*h*(1.0-h)

## The land's height `base` with tunnel `t`'s massif raised and its mouths'
## trenches cut, at (x, z).
static func carve(t: Site, base: float, x: float, z: float) -> float:
	if not t.box.has_point(Vector2(x,z)): return base
	var y := _smax(massif(t,x,z),base,BLEND)
	y = _trench(t,y,t.origin,-t.way,x,z)
	return _trench(t,y,t.mouth_b,t.out_b,x,z)

## The trench out of the mouth at `m` (xz), facing out along `o`.
static func _trench(t: Site, y: float, m: Vector2, o: Vector2, x: float, z: float) -> float:
	var qx := x-m.x
	var qz := z-m.y
	var a := qx*o.x+qz*o.y
	if a < 0.0 or a > TRENCH_REACH: return y
	var b := absf(o.x*qz-o.y*qx)
	if b > TRENCH_WIDE: return y
	var lid := t.floor_y-SINK
	if a > APRON: lid += (a-APRON)*GRADE
	if y <= lid: return y
	if b <= HALL_HALF: return lid
	if b <= HALL_HALF+EDGE: return minf(y,lid+SHEER*(b-HALL_HALF)/EDGE)
	return minf(y,lid+SHEER+(b-HALL_HALF-EDGE)/LEAN)

## True where (x, z) is on a trench's floor (no grass there).
static func on_trench(t: Site, x: float, z: float) -> bool:
	for m in 2:
		var at: Vector2 = t.origin if m == 0 else t.mouth_b
		var o: Vector2 = -t.way if m == 0 else t.out_b
		var q := Vector2(x,z)-at
		var a := q.dot(o)
		if a >= 0.0 and a <= TRENCH_REACH and absf(o.cross(q)) <= HALL_HALF+EDGE+1.0: return true
	return false

## The tunnels whose box meets the box (x0, z0)..(x1, z1).
static func sites_in(sites: Array, x0: float, z0: float, x1: float, z1: float) -> Array:
	var out: Array = []
	var r := Rect2(x0,z0,x1-x0,z1-z0)
	for t: Site in sites:
		if t.box.intersects(r,true): out.append(t)
	return out

## Whether slot hall site `s` (hall_sites.gd's array) meets a tunnel's box.
static func blocks_hall(sites: Array, s: PackedFloat32Array) -> bool:
	if s.is_empty(): return false
	var r := s[7]+s[8]
	var hb := Rect2(s[0]-r,s[1]-r,r*2.0,r*2.0)
	for t: Site in sites:
		if t.box.intersects(hb,true): return true
	return false

# --- Over a chunk's and a grid's arrays ---------------------------------------------

## The tunnels' pass over a chunk's arrays (LandField.build_chunk; its
## args), after the ponds', before the slot halls'. `field` the LandField.
static func apply_chunk(field: Object, impl: Object, made: Dictionary, ts: Array, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var heights: PackedFloat32Array = made.heights
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	var colours: PackedColorArray = made.colours
	var carved: PackedByteArray = made.carved
	var river: PackedFloat32Array = made.river
	var lift := PackedFloat32Array()
	lift.resize(n*n)
	var moved := PackedByteArray()
	moved.resize(n*n)
	var any_moved := false
	for t: Site in ts:
		var i0 := clampi(floori((t.box.position.x-x0)/step),0,cells)
		var i1 := clampi(ceili((t.box.end.x-x0)/step),0,cells)
		var j0 := clampi(floori((t.box.position.y-z0)/step),0,cells)
		var j1 := clampi(ceili((t.box.end.y-z0)/step),0,cells)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var v := j*n+i
				var y := carve(t,heights[v],x0+i*step,z0+j*step)
				if absf(y-heights[v]) > 0.0005:
					lift[v] += y-heights[v]
					heights[v] = y
					verts[v] = Vector3(verts[v].x,y,verts[v].z)
					moved[v] = 1
					any_moved = true
	if not any_moved: return
	var redo := PackedByteArray()
	redo.resize(n*n)
	for j in n:
		for i in n:
			if moved[j*n+i] == 0: continue
			for d: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var ii := i+d.x
				var jj := j+d.y
				if ii >= 0 and ii < n and jj >= 0 and jj < n: redo[jj*n+ii] = 1
	for j in n:
		for i in n:
			var v := j*n+i
			if redo[v] == 0: continue
			var x := x0+i*step
			var z := z0+j*step
			var hl: float = heights[v-1] if i > 0 else field.height(x-step,z)
			var hr: float = heights[v+1] if i < cells else field.height(x+step,z)
			var hd: float = heights[v-n] if j > 0 else field.height(x,z-step)
			var hu: float = heights[v+n] if j < cells else field.height(x,z+step)
			var normal := Vector3(hl-hr,2.0*step,hd-hu).normalized()
			normals[v] = normal
			var meadow := colours[v].a
			if moved[v] != 0: meadow *= _meadow_keep(lift[v])
			var c: Color = impl.colour(x,z,heights[v],normal.y,meadow)
			c.a = meadow
			colours[v] = c
			if moved[v] != 0:
				carved[v*4] = 0
				carved[v*4+1] = 0
				if lift[v] > 1.0:
					# No river on the mountain: far from any, its flow still.
					carved[v*4+2] = 128
					carved[v*4+3] = 128
					river[v*3] = 1000.0
					river[v*3+1] = 0.0
					river[v*3+2] = SEA_Y-100.0
	var edges := [[],[],[],[]]
	for t in n:
		edges[0].append(t)
		edges[1].append(t*n+cells)
		edges[2].append(cells*n+t)
		edges[3].append(t*n)
	for e in 4:
		for t in n:
			var from: int = edges[e][t]
			if redo[from] == 0: continue
			var v := n*n+e*n+t
			verts[v] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[v] = normals[from]
			colours[v] = colours[from]
			for q in 4: carved[v*4+q] = carved[from*4+q]
			river[v*3] = river[from*3]
			river[v*3+1] = -river[from*3+1]
			river[v*3+2] = river[from*3+2]
	made.heights = heights
	made.verts = verts
	made.normals = normals
	made.colours = colours
	made.carved = carved
	made.river = river

## How much of the meadow stays where the land was lifted `lift` m (none
## where it was cut down: a trench).
static func _meadow_keep(lift: float) -> float:
	if lift < 0.0: return 0.0
	return 1.0-smoothstep(MEADOW_LIFT.x,MEADOW_LIFT.y,lift)

## The tunnels' pass over LandField.grid's arrays (the grass's): the
## massif's heights, its meadows faded with the lift, no river on it, and
## the trenches' floors read as a river's water (`river` -1).
static func apply_grid(got: Dictionary, ts: Array, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var ms: PackedFloat32Array = got.meadows
	var rs: PackedFloat32Array = got.river
	for t: Site in ts:
		var i0 := clampi(floori((t.box.position.x-x0)/step)+pad,0,nx-1)
		var i1 := clampi(ceili((t.box.end.x-x0)/step)+pad,0,nx-1)
		var j0 := clampi(floori((t.box.position.y-z0)/step)+pad,0,nz-1)
		var j1 := clampi(ceili((t.box.end.y-z0)/step)+pad,0,nz-1)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var x := x0+(i-pad)*step
				var z := z0+(j-pad)*step
				var k := j*nx+i
				var y := carve(t,hs[k],x,z)
				var d := y-hs[k]
				if absf(d) <= 0.0005: continue
				hs[k] = y
				ms[k] *= _meadow_keep(d)
				if d > 1.0: rs[k] = maxf(rs[k],1000.0)
				if d < 0.0 and on_trench(t,x,z): rs[k] = minf(rs[k],-1.0)
	got.heights = hs
	got.meadows = ms
	got.river = rs
