extends RefCounted
## Three islands in the sea south of the start (seed 1, wilderness only;
## docs/design/endless-flight/spec-wilderness-demo.md, lane coast): a stamp over
## the land field like the Peak's massif, so the ground, its paint, grass,
## collision, the horizon and the landing all come with it. LandField calls it
## last; `apply` only ever raises the land, and only inside each isle's circle
## (where the isle stands above the sea bed), so all land outside the
## footprints is the field's own.
##
## The GDScript is the only copy: the C++ kernels never see the isles
## (LandField `native_impl_in` is null where they meet a box, as for the Peak),
## and a chunk pays this pass only inside the three circles.
##
##   coast/long    Long Isle: turf, beach, a bluff at its east end, the strip.
##   coast/light   Light Rock: a cliffed table, the lighthouse, a dare of a flat.
##   coast/horn    The Horn: a broken ring of crag round a lagoon, the boat.
##
## Each isle's handle moves it (LayoutOverrides `xform`): origin its centre,
## basis its yaw, +x (`u`) its long axis. `--isles=0` takes them off.

const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## LandField.SEA_Y (land_field.gd preloads this file).
const SEA_Y := -40.0
const LONG := 0
const LIGHT := 1
const HORN := 2

## [handle, kind, x, z, yaw degrees (about up), reach m].
const SPOTS := [
	["coast/long",LONG,500.0,3500.0,12.0,860.0],
	["coast/light",LIGHT,2150.0,3250.0,-28.0,560.0],
	["coast/horn",HORN,3250.0,3800.0,200.0,800.0],
]

## Long Isle's strip, in its frame: from u0 to u1, half-width, height over sea.
const STRIP_LONG := [-340.0,250.0,30.0,8.0]
## Light Rock's flat on top (same fields).
const STRIP_LIGHT := [-190.0,70.0,26.0,58.0]
## Where the light stands on Light Rock, in its frame.
const LIGHT_AT := Vector2(165.0,0.0)
## Where the boat lies in the Horn's lagoon, in its frame, and the way her
## bow points (radians about up from +u).
const BOAT_AT := Vector2(70.0,0.0)

var _name: PackedStringArray = []
var _kind := PackedInt32Array()
var _cx := PackedFloat64Array()
var _cz := PackedFloat64Array()
var _ca := PackedFloat64Array()
var _sa := PackedFloat64Array()
var _r := PackedFloat64Array()

## What the last `apply` moved: the rise over the land it was on.
var last_lift := 0.0

## The isles for this land, or null: seed 1's wilderness, no `--isles=0`.
static func make(land_seed: int, world_id: String) -> RefCounted:
	if land_seed != 1 or not world_id in ["wilderness","doors"]: return null
	if "--isles=0" in LaunchArgs.user_args(): return null
	return new()

func _init() -> void:
	for s: Array in SPOTS:
		var a := deg_to_rad(float(s[4]))
		var coded := Transform3D(Basis(Vector3.UP,a),Vector3(float(s[2]),0.0,float(s[3])))
		if LayoutOverrides.deleted(String(s[0])): continue
		var t: Transform3D = LayoutOverrides.xform(String(s[0]),coded)
		var u := t.basis.x.normalized()
		_name.append(String(s[0]))
		_kind.append(int(s[1]))
		_cx.append(t.origin.x)
		_cz.append(t.origin.z)
		_ca.append(u.x)
		_sa.append(u.z)
		_r.append(float(s[5]))

## An isle's centre by handle, Vector2.INF if deleted.
func centre(handle: String) -> Vector2:
	var i := _name.find(handle)
	return Vector2.INF if i < 0 else Vector2(_cx[i],_cz[i])

## The world XZ of (u, v) in the frame of the isle `handle`.
func world(handle: String, u: float, v := 0.0) -> Vector2:
	var i := _name.find(handle)
	if i < 0: return Vector2.INF
	return Vector2(_cx[i]+u*_ca[i]-v*_sa[i],_cz[i]+u*_sa[i]+v*_ca[i])

## The yaw of the isle's +u about up (Basis(Vector3.UP, this) x is +u).
func yaw(handle: String) -> float:
	var i := _name.find(handle)
	return 0.0 if i < 0 else atan2(-_sa[i],_ca[i])

## Whether (x, z) lies inside any isle's circle.
func reaches(x: float, z: float) -> bool:
	for i in _r.size():
		var dx := x-_cx[i]
		var dz := z-_cz[i]
		if dx*dx+dz*dz < _r[i]*_r[i]: return true
	return false

## Whether a site of reach `r` at (x, z) keeps clear of every isle.
func clear(x: float, z: float, r := 0.0) -> bool:
	for i in _r.size():
		var dx := x-_cx[i]
		var dz := z-_cz[i]
		var far := _r[i]+r
		if dx*dx+dz*dz < far*far: return false
	return true

## Whether the box (x0, z0)..(x1, z1) meets any isle's circle.
func meets(x0: float, z0: float, x1: float, z1: float) -> bool:
	for i in _r.size():
		var dx := _cx[i]-clampf(_cx[i],x0,x1)
		var dz := _cz[i]-clampf(_cz[i],z0,z1)
		if dx*dx+dz*dz < _r[i]*_r[i]: return true
	return false

## Vector2(world height, meadow) `got` with the isles on it at (x, z).
func apply(got: Vector2, x: float, z: float) -> Vector2:
	last_lift = 0.0
	for i in _r.size():
		var dx := x-_cx[i]
		var dz := z-_cz[i]
		if dx*dx+dz*dz >= _r[i]*_r[i]: continue
		var u := dx*_ca[i]+dz*_sa[i]
		var v := dz*_ca[i]-dx*_sa[i]
		var p: Vector2
		match _kind[i]:
			LONG: p = _long(u,v,x,z)
			LIGHT: p = _light(u,v,x,z)
			_: p = _horn(u,v,x,z)
		var y := p.x+SEA_Y
		if y > got.x:
			last_lift = y-got.x
			got = Vector2(y,p.y)
	return got

# --- The isles: (height over the sea, meadow) in each one's frame -----------------

## Long Isle: beach, a low turf back, the strip down it, a bluff at the east.
func _long(u: float, v: float, x: float, z: float) -> Vector2:
	var l := 560.0
	var taper := 0.72+0.28*cos(clampf(u/l,-1.0,1.0)*PI*0.5)
	var warp := (_n(x*0.006,z*0.006)-0.5)*120.0+(_n(x*0.021,z*0.021)-0.5)*42.0
	var du := maxf(absf(u)-l,0.0)
	var d := 170.0*taper+warp-sqrt(du*du+v*v)
	var y := _shelf(d)
	if d > 0.0:
		y = lerpf(d*0.075,9.0+(_n(x*0.011,z*0.011)-0.5)*7.0,smoothstep(38.0,110.0,d))
		# The bluff: the land heaps up to a cliffed east end.
		var bluff := smoothstep(290.0,470.0,u)*smoothstep(8.0,44.0,d)
		y += bluff*(30.0+18.0*_n(x*0.014,z*0.014))
	var m := smoothstep(34.0,84.0,d)*(1.0-0.45*smoothstep(330.0,430.0,u))
	var s := _strip(u,v,STRIP_LONG)
	return Vector2(lerpf(y,float(STRIP_LONG[3]),s),maxf(m,s))

## Light Rock: sheer sides, a turf cap sloping up to the light.
func _light(u: float, v: float, x: float, z: float) -> Vector2:
	var warp := (_n(x*0.012,z*0.012)-0.5)*72.0+(_n(x*0.043,z*0.043)-0.5)*26.0
	# Buttresses and gullies down the cliff, so it is broken rock, not a lump.
	warp += (1.0-absf(2.0*_n(x*0.075,z*0.075)-1.0))*11.0+(_n(x*0.19,z*0.19)-0.5)*5.0
	var e := sqrt(u*u/1.7+v*v)
	var d := 178.0+warp-e
	var y := _shelf(d*2.2)
	if d > 0.0:
		var top := 58.0+6.0*smoothstep(70.0,160.0,u)+(_n(x*0.017,z*0.017)-0.5)*5.0
		y = _strata(top*smoothstep(0.0,17.0,d),6.5,0.55,x,z)
		y = maxf(y,top*smoothstep(14.0,20.0,d))
	var m := smoothstep(20.0,44.0,d)*0.8
	var s := _strip(u,v,STRIP_LIGHT)*smoothstep(14.0,30.0,d)
	return Vector2(lerpf(y,float(STRIP_LIGHT[3]),s),maxf(m,s))

## The Horn: a broken ring of crag open along +u, its tall end at -u.
func _horn(u: float, v: float, x: float, z: float) -> Vector2:
	var r := sqrt(u*u+v*v)
	var a := absf(atan2(v,u))
	var warp := (_n(x*0.009,z*0.009)-0.5)*95.0+(_n(x*0.031,z*0.031)-0.5)*34.0
	var big := smoothstep(1.2,2.9,a)
	var wall := 62.0+58.0*big
	var d := wall+warp-absf(r-(370.0+warp*0.4))
	# The mouth, the wall's ends thinning to horns.
	d = minf(d,(a-0.62)*r*0.8+warp*0.45)
	if d <= 0.0: return Vector2(_shelf(d*1.6),0.0)
	var crest := 1.0-absf(2.0*_n(x*0.0085,z*0.0085)-1.0)
	var h := (46.0+105.0*big)*(0.62+0.62*crest)
	var y := h*pow(clampf(d/(wall*0.62),0.0,1.0),0.8)
	y += (_n(x*0.05,z*0.05)-0.5)*7.0*smoothstep(0.0,18.0,d)
	return Vector2(_strata(y,8.0,0.6,x,z),0.0)

## The sea bed's shelf off a shore `d` m inland (negative out to sea).
static func _shelf(d: float) -> float:
	return d*0.2 if d > -30.0 else -6.0+(d+30.0)*0.65

## How much of the strip `f` covers (u, v): 1 on it, easing to 0 round it.
static func _strip(u: float, v: float, f: Array) -> float:
	var along := 1.0-smoothstep(0.0,60.0,maxf(float(f[0])-u,u-float(f[1])))
	return along*(1.0-smoothstep(float(f[2]),float(f[2])+32.0,absf(v)))

## `y` stepped into beds of `bed` m, `k` of the way, the beds tilted a little.
func _strata(y: float, bed: float, k: float, x: float, z: float) -> float:
	var t := y+(x*0.018+z*0.011)+(_n(x*0.008,z*0.008)-0.5)*5.0
	var f := t/bed
	var flat := (floorf(f)+smoothstep(0.65,1.0,f-floorf(f)))*bed
	return lerpf(y,flat-(t-y),k)

## Value noise 0..1, deterministic (integer hash, no float maths of the libm).
static func _n(x: float, z: float) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x-ix
	var fz := z-iz
	var ux := fx*fx*(3.0-2.0*fx)
	var uz := fz*fz*(3.0-2.0*fz)
	var a := lerpf(_h(ix,iz),_h(ix+1,iz),ux)
	var b := lerpf(_h(ix,iz+1),_h(ix+1,iz+1),ux)
	return lerpf(a,b,uz)

static func _h(ix: int, iz: int) -> float:
	var k := (ix*374761393+iz*668265263) & 0xFFFFFFFF
	k = ((k^(k>>13))*1274126177) & 0xFFFFFFFF
	return float((k^(k>>16)) & 0xFFFF)/65535.0

# --- The land's arrays ------------------------------------------------------------

## The isles' pass over a chunk's arrays (LandField.build_chunk's): heights,
## then the normals and colours round what moved, the skirt's copies.
func apply_chunk(field: Object, impl: Object, made: Dictionary, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var w := n+2
	var heights: PackedFloat32Array = made.heights
	var hs := PackedFloat32Array()
	var ms := PackedFloat32Array()
	var mv := PackedByteArray()
	hs.resize(w*w)
	ms.resize(w*w)
	mv.resize(w*w)
	var any := false
	for j in w:
		for i in w:
			var x := x0+(i-1)*step
			var z := z0+(j-1)*step
			var k := j*w+i
			var inner := i >= 1 and i <= n and j >= 1 and j <= n
			if not reaches(x,z):
				hs[k] = heights[(j-1)*n+i-1] if inner else float(impl.height(x,z))
				continue
			var base := heights[(j-1)*n+i-1] if inner else float(impl.height(x,z))
			var got := apply(Vector2(base,0.0),x,z)
			hs[k] = got.x
			ms[k] = got.y
			if last_lift > 0.0:
				mv[k] = 1
				any = any or inner
	if not any: return
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	var colours: PackedColorArray = made.colours
	var carved: PackedByteArray = made.carved
	var river: PackedFloat32Array = made.river
	# The vertices the paint is asked for: all that moved or touch one that did.
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	var ys := PackedFloat32Array()
	var ups := PackedFloat32Array()
	var mds := PackedFloat32Array()
	var ids := PackedInt32Array()
	for j in n:
		for i in n:
			var k := (j+1)*w+i+1
			if mv[k]+mv[k-1]+mv[k+1]+mv[k-w]+mv[k+w] == 0: continue
			var v := j*n+i
			var y := hs[k]
			var nrm := Vector3(hs[k-1]-hs[k+1],2.0*step,hs[k-w]-hs[k+w]).normalized()
			normals[v] = nrm
			if mv[k] == 0:
				continue
			heights[v] = y
			verts[v] = Vector3(i*step,y,j*step)
			xs.append(x0+i*step)
			zs.append(z0+j*step)
			ys.append(y)
			ups.append(nrm.y)
			mds.append(ms[k])
			ids.append(v)
			# No river; the rock's groove and crest from the slope.
			river[v*3] = 1000.0
			river[v*3+1] = 0.0
			river[v*3+2] = SEA_Y-100.0
			var rough := _n((x0+i*step)*0.07,(z0+j*step)*0.07)
			carved[v*4] = int(clampf(rough*1.4-0.2,0.0,1.0)*255.0)
			carved[v*4+1] = int(clampf(1.2-rough*1.4,0.0,1.0)*255.0)
	if not ids.is_empty():
		var cs: PackedColorArray = field.colours(xs,zs,ys,ups,mds)
		for q in ids.size():
			var c := _weather(cs[q],ups[q],xs[q],ys[q],zs[q])
			c.a = mds[q]
			colours[ids[q]] = c
	for e in 4:
		for t in n:
			var from: int = t if e == 0 else (t*n+cells if e == 1 else (cells*n+t if e == 2 else t*n))
			var k := ((from/n)+1)*w+(from%n)+1
			if mv[k]+mv[k-1]+mv[k+1]+mv[k-w]+mv[k+w] == 0: continue
			var sv := n*n+e*n+t
			verts[sv] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[sv] = normals[from]
			colours[sv] = colours[from]
			for q in 4: carved[sv*4+q] = carved[from*4+q]
			river[sv*3] = river[from*3]
			river[sv*3+1] = -river[from*3+1]
			river[sv*3+2] = river[from*3+2]
	made.heights = heights
	made.verts = verts
	made.normals = normals
	made.colours = colours
	made.carved = carved
	made.river = river

## The field's colour `c` on bare stone: cold grey-black beds with pale salt
## streaks, away from the field's warm rock, which on sheer cliffs reads soft.
func _weather(c: Color, up: float, x: float, y: float, z: float) -> Color:
	var bare := 1.0-smoothstep(0.55,0.85,up)
	if bare <= 0.0: return c
	var bed := 0.5+0.5*sin((y+(x*0.018+z*0.011))*1.9+_n(x*0.02,z*0.02)*5.0)
	var streak := pow(_n(x*0.11,z*0.11),3.0)*smoothstep(-2.0,10.0,y-SEA_Y)
	var stone := Color(0.20,0.21,0.23).lerp(Color(0.36,0.35,0.34),bed)
	stone = stone.lerp(Color(0.62,0.60,0.56),streak*0.8)
	# The tide's black band at the foot.
	stone = stone.lerp(Color(0.07,0.075,0.07),1.0-smoothstep(1.0,4.5,y-SEA_Y))
	return c.lerp(stone,0.85*bare)

## The isles' pass over LandField.grid's arrays (the grass's, the horizon's).
func apply_grid(got: Dictionary, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var ms: PackedFloat32Array = got.get("meadows",PackedFloat32Array())
	var rs: PackedFloat32Array = got.get("river",PackedFloat32Array())
	for j in nz:
		for i in nx:
			var x := x0+(i-pad)*step
			var z := z0+(j-pad)*step
			if not reaches(x,z): continue
			var k := j*nx+i
			var y := apply(Vector2(hs[k],ms[k] if not ms.is_empty() else 0.0),x,z)
			if last_lift <= 0.0: continue
			hs[k] = y.x
			if not ms.is_empty(): ms[k] = y.y
			if not rs.is_empty(): rs[k] = 1000.0
	got.heights = hs
	if not ms.is_empty(): got.meadows = ms
	if not rs.is_empty(): got.river = rs
