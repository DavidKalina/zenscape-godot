extends "res://scripts/rune_serpent.gd"
## The linger serpent's body (docs/design/roguelike/linger-serpent-round1.md,
## linger-serpent-round2.md): the rune serpent (scripts/rune_serpent.gd: its
## pebbled basalt, its chain of rings on the head's traced path, the neck's
## S, the breath and tongue) grown by the node's scale into a colossus, with
## a ruff of stone feathers behind its head (Kukulkan's) and, from round 2,
## a head of its own: a broad viper's skull carved in the same stone, heavy
## brows over sunk eyes, a hinged lower jaw that drops with weight and slams
## shut, fangs and teeth, a dark mouth and throat.
##
## It flies no route: its head is steered by scripts/roguelike/linger.gd,
## which hands it a place a frame (`go_to`, local), and every ring follows
## the exact way the head has gone. `rewind` takes the head back along its
## own way (the rear before a strike, the draw back after). Behind DRAPE m
## of body on an isle the rest is draped (`drape`): from there over the
## nearest rim and down into the void, so only its front lies on the isle.
##
## Solid (round 2): capsules along it on layer 1, moved every frame, so the
## wanderer is stopped by its body (and can stand and ride on it). Its sound
## is the threat's.

const FEATHERS := 4
const FEATHER_LONG := 3.6
const FEATHER_SIDE := 0.8
const FEATHER_WIDE := 2.9
const FEATHER_FAN := 0.06
const FEATHER_ARC := 0.95
const FEATHER_ROW2 := 0.7
const FEATHER_TONE := Color("4f4d4a")
const FEATHER_TIP := Color("3c3d40")
const RUNE_DIM := 0.08
const PEBBLE_K := 0.6
## Its eyes' light and haze times this (the rune serpent's are lamps).
const EYE_DIM := 0.4

## The head (shares of its girth `hr`, along it 0 at its back to 1 at the
## snout): [t, half width, skull's height over the lip, jaw's depth under
## it, the lip's height]. Broad at the jowls, a viper's wedge, blunt.
const SKULL := [
	[0.0,0.84,0.74,0.56,-0.1],
	[0.12,1.06,0.78,0.62,-0.1],
	[0.24,1.2,0.78,0.62,-0.1],
	[0.38,1.14,0.74,0.54,-0.1],
	[0.52,1.0,0.7,0.46,-0.09],
	[0.66,0.86,0.62,0.38,-0.08],
	[0.78,0.74,0.54,0.31,-0.07],
	[0.88,0.62,0.46,0.25,-0.06],
	[0.95,0.5,0.38,0.18,-0.05],
	[1.0,0.36,0.28,0.11,-0.05]]
## Round the skull (lip to lip over the top) and the jaw (lip to lip under).
## The head's girth over the rune serpent's (a viper's broad head on its neck).
const HEAD_BIG := 1.2
const SKULL_SIDES := 14
const JAW_SIDES := 10
## The cross-sections' squareness (2 an ellipse, more a box): the skull's
## flat top and hard edges, the jaw's rounder chin.
const SKULL_SQ := 3.0
const JAW_SQ := 2.3
## The brows: a heavy shelf jutting out over each eye (shares of hr), along
## the head (t from, to), round the skull (radians up from the lip, from, to).
const BROW := 0.24
const BROW_T := Vector2(0.4,0.74)
const BROW_A := Vector2(0.42,1.05)
## The eye: its middle along the head (t) and round it (radians up from the
## lip), its half size (along, up; shares of hr), how far it is sunk.
const EYE_T := 0.57
const EYE_A := 0.27
const EYE_HALF := Vector2(0.26,0.17)
## The jaw's hinge (head frame, shares of hr: up, along) and how far inside
## the upper lip it sits (share of the width).
const HINGE := Vector2(-0.18,-0.06)
const JAW_IN := 0.93
## Fangs and teeth (shares of hr): the fangs' t, length, root width; the
## upper teeth's and lower teeth's span of t, count a side, length.
const FANG_T := 0.83
const FANG_LONG := 0.36
const FANG_WIDE := 0.075
const TEETH_T := Vector2(0.3,0.74)
const TEETH := 6
const TOOTH := 0.13
const LOW_T := Vector2(0.36,0.86)
const LOW_TEETH := 5
const LOW_TOOTH := 0.11
const MOUTH_DARK := Color("140d0b")
const GUM := Color("2b1d19")
## The jaw's weight: it opens on a soft spring (overshooting a little, as a
## heavy thing does) and shuts on a hard one (a slam, a small bounce).
const JAW_OPEN_HZ := 2.4
const JAW_OPEN_DAMP := 0.5
const JAW_SHUT_HZ := 9.0
const JAW_SHUT_DAMP := 0.35
## The look's own springs while it hunts (Hz, damping): quicker than the
## rune serpent's slow sky looks.
const LOOK_HZ := 1.4
## The drape: rings at most this many local m apart along it.
const DRAPE_STEP := 0.5
## Its capsules: one over this many rings, this share of their girth.
const SOLID_RINGS := 2
const SOLID_SHARE := 0.88

var stretch := 1.0
## The jaw's goal (radians); it follows with weight (`_jaw_x`).
var jaw := 0.0
var fixed := false
var pace := 0.0
## The look's spring speed (Hz); 0 leaves the rune serpent's.
var look_hz := 0.0

## The drape (local): how much of it is worn (0 the real way, 1 the drape),
## the trail arc it starts at, its points from there back (DRAPE_STEP apart).
var drape_w := 0.0
var drape_a0 := 0.0
var drape := PackedVector3Array()

var _oldest := 0
var _ruff: MeshInstance3D
var _jaw_x := 0.0
var _jaw_v := 0.0
var _lk := PackedFloat32Array([0.0,0.0,0.0,0.0])
var _lv := PackedFloat32Array([0.0,0.0,0.0,0.0])
var _lg := PackedFloat32Array([0.0,0.0,0.0,0.0])
var _hr := 1.0

func _init() -> void:
	name = "LingerSerpent"

## Built (the rune serpent's body, solid) and its ruff; laid on the
## aqueduct's way until `lay` puts it where it belongs.
func build(study: Node3D) -> void:
	solid = true
	pebbled = true
	rng_seed = 4411
	setup(study)
	_material.set_shader_parameter("pebble_size",PEBBLE_SIZE*GRAIN*PEBBLE_K)
	_build_ruff()
	if _solid != null:
		_solid.set_meta(&"moving_ground",true)

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	pass

# --- The way ----------------------------------------------------------------

func lay(points: PackedVector3Array) -> void:
	_laid = -1
	_oldest = 0
	travelled = 0.0
	_live_p = points[0]
	_live_b = points[0]
	_live_r = 0.0
	_lay(0)
	for i in range(1,points.size()): go_to(points[i])
	_head_fwd = (points[points.size()-1]-points[points.size()-2]).normalized()
	_pose(0.0)

func go_to(p: Vector3, roll := 0.0) -> float:
	var d := p.distance_to(_live_p)
	if d < 1e-5: return 0.0
	var from := travelled
	var from_p := _live_p
	var from_r := _live_r
	travelled += d
	_live_p = p
	_live_b = p
	_live_r = roll
	while float(_laid+1)*STEP <= travelled:
		var k := _laid+1
		var f := (k*STEP-from)/d
		var slot := k%TRAIL
		_tp[slot] = from_p.lerp(p,f)
		_tb[slot] = _tp[slot]
		_tr[slot] = lerpf(from_r,roll,f)
		_laid = k
	_oldest = maxi(_oldest,_laid-TRAIL+1)
	return d

func rewind(dist: float) -> float:
	var most := rewind_room()
	dist = clampf(dist,0.0,most)
	if dist <= 0.0: return 0.0
	var to := travelled-dist
	var t := real_trail_at(to)
	travelled = to
	_laid = mini(_laid,floori(to/STEP))
	_live_p = t[0]
	_live_b = t[1]
	_live_r = float(t[2])
	return dist

## How far back the head may go now (local m): within the kept way, and
## never back past the drape's start.
func rewind_room() -> float:
	var most := travelled-(float(_oldest)*STEP+LENGTH+STEP*6.0)
	return maxf(most,0.0)

## The way as laid, never draped.
func real_trail_at(a: float) -> Array:
	return super.trail_at(a)

## The way, draped behind `drape_a0` (where `drape` holds its points).
func trail_at(a: float) -> Array:
	var t: Array = super.trail_at(a)
	if drape_w <= 0.0 or a >= drape_a0 or drape.size() < 2: return t
	var d := (drape_a0-a)/DRAPE_STEP
	var n := drape.size()
	var p: Vector3
	if d >= float(n-1):
		p = drape[n-1]+(drape[n-1]-drape[n-2]).normalized()*(d-float(n-1))*DRAPE_STEP
	else:
		var i := floori(d)
		p = drape[i].lerp(drape[i+1],d-float(i))
	if drape_w < 1.0: p = (t[0] as Vector3).lerp(p,drape_w)
	return [p,p,t[2]]

func live() -> Vector3:
	return _live_p

func way() -> Vector3:
	var back: Vector3 = real_trail_at(travelled-2.0)[0]
	var w := _live_p-back
	return w.normalized() if w.length() > 1e-4 else _head_fwd

# --- Looking ----------------------------------------------------------------

## The look's goals: turn and tilt off its way (radians), the head's lean
## toward the look and its lift (local m).
func look(yaw: float, pitch: float, lean := 0.0, lift := 0.0) -> void:
	_sg[S_YAW] = clampf(yaw,-LOOK_MAX.x,LOOK_MAX.x)
	_sg[S_PITCH] = clampf(pitch,-LOOK_MAX.y,LOOK_MAX.y)
	_sg[S_LEAN] = lean
	_sg[S_LIFT] = lift
	_lg[0] = _sg[S_YAW]
	_lg[1] = _sg[S_PITCH]
	_lg[2] = lean
	_lg[3] = lift

func look_snap() -> void:
	for i in [S_YAW,S_PITCH,S_LEAN,S_LIFT]:
		_sx[i] = 0.0
		_sv[i] = 0.0
		_sf[i] = 0.0
		_sg[i] = 0.0
	for c in range(4):
		_lk[c] = 0.0
		_lv[c] = 0.0
		_lg[c] = 0.0

func look_dir() -> Vector3:
	return _head_dir

func forward() -> Vector3:
	return _head_fwd

## The jaw now (radians, after its weight).
func jaw_now() -> float:
	return _jaw_x

# --- A frame ----------------------------------------------------------------

func step(delta: float, snap := false) -> void:
	_time += delta
	_sg[S_SPEED] = 0.0
	_sg[S_WEAVE] = 0.0
	_sg[S_VEER] = 0.0
	_sg[S_BANK] = 0.0
	_springs(delta)
	if look_hz > 0.0: _look_springs(delta)
	_jaw_step(delta)
	_sx[S_JAW] = _jaw_x
	_sv[S_JAW] = 0.0
	_sx[S_SPEED] = pace
	mode = "watch" if fixed else "roam"
	_scroll += pace*delta*RUNE_RUN
	_pose(0.0 if snap else delta)
	_stretch_head()
	_light(delta)
	_material.set_shader_parameter("energy",float(_material.get_shader_parameter("energy"))*RUNE_DIM)
	# The eyes dim and warm: polished stone that catches a little light,
	# lit when it fixes on him but never a lamp.
	_material.set_shader_parameter("eye_energy",float(_material.get_shader_parameter("eye_energy"))*EYE_DIM)
	_haze.set_shader_parameter("strength",float(_haze.get_shader_parameter("strength"))*EYE_DIM)
	_place_solid()

## Yaw, pitch, lean and lift on critically damped springs at `look_hz`.
func _look_springs(delta: float) -> void:
	var w := TAU*look_hz
	var count := ceili(delta/0.01)
	var h := delta/maxf(count,1)
	for c in range(4):
		var x := _lk[c]
		var v := _lv[c]
		for _n in range(count):
			v += ((_lg[c]-x)*w*w-v*2.0*w)*h
			x += v*h
		_lk[c] = x
		_lv[c] = v
	_sx[S_YAW] = _lk[0]
	_sx[S_PITCH] = _lk[1]
	_sx[S_LEAN] = _lk[2]
	_sx[S_LIFT] = _lk[3]

## The jaw after its goal: soft and overshooting opening, hard shutting.
func _jaw_step(delta: float) -> void:
	var shutting := jaw < _jaw_x-0.02
	var hz := JAW_SHUT_HZ if shutting else JAW_OPEN_HZ
	var z := JAW_SHUT_DAMP if shutting else JAW_OPEN_DAMP
	var w := TAU*hz
	var count := ceili(delta/0.005)
	var h := delta/maxf(count,1)
	for _n in range(count):
		_jaw_v += ((jaw-_jaw_x)*w*w-_jaw_v*2.0*z*w)*h
		_jaw_x += _jaw_v*h
		# The jaw stops on the lip: a shut jaw bounces, never closes past.
		if _jaw_x < -0.01:
			_jaw_x = -0.01
			_jaw_v = absf(_jaw_v)*0.3

func _stretch_head() -> void:
	if _skeleton == null or absf(stretch-1.0) < 0.005: return
	var sq := 1.0/sqrt(maxf(stretch,0.1))
	var sc := Basis.from_scale(Vector3(sq,sq,stretch))
	for b in [STATIONS,STATIONS+2]:
		var xf := _skeleton.get_bone_pose(b)
		xf.basis = xf.basis*sc
		_skeleton.set_bone_pose(b,xf)

## The rune serpent's pose, the jaw then hung on its own hinge (at the
## head's back, low), not the head's middle.
func _pose(delta: float) -> void:
	super._pose(delta)
	if _skeleton == null: return
	var hinge := Vector3(0.0,HINGE.x*_hr,HINGE.y*_hr)
	var r := Basis(Vector3.RIGHT,_sx[S_JAW])
	_skeleton.set_bone_pose(STATIONS+2,_head_xf*Transform3D(r,hinge-r*hinge))

# --- Solid ------------------------------------------------------------------

## Capsules over SOLID_RINGS rings each and one for the head.
func _build_solid() -> void:
	_solid = AnimatableBody3D.new()
	_solid.name = "Solid"
	_solid.collision_layer = SOLID_LAYER
	_solid.collision_mask = 0
	_solid.sync_to_physics = false
	add_child(_solid)
	var k := 0
	while k < STATIONS-1:
		var to := mini(k+SOLID_RINGS,STATIONS-1)
		var r := 0.0
		for i in range(k,to+1): r = maxf(r,_radius[i])
		_add_capsule(r*SOLID_SHARE,_arc[to]-_arc[k])
		_capsule_rings.append(Vector2i(k,to))
		k = to
	_add_capsule(RADIUS*girth*0.8,HEAD)
	_capsule_rings.append(Vector2i(-1,-1))
	# The head is not ground or wall: it would slide under him and lift
	# him; what it does to him is its bite (the threat's).
	_capsules.back().disabled = true

## Its capsules, for the threat's push (world): [a, b, radius].
func capsules() -> Array:
	var out: Array = []
	var s := global_transform.basis.get_scale().x
	for i in range(_capsules.size()):
		var c := _capsules[i]
		var shape := c.shape as CapsuleShape3D
		var xf := global_transform*c.transform
		var half := (shape.height*0.5-shape.radius)
		var y := xf.basis.y.normalized()
		out.append([xf.origin-y*half*s,xf.origin+y*half*s,shape.radius*s])
	return out

# --- The head ---------------------------------------------------------------

## The body's rings (as the rune serpent's) and the new head on its bones:
## the skull on the head's, the jaw on the jaw's; the eyes' haze.
func _build_mesh() -> ArrayMesh:
	var mesh := MeshParts.new()
	var rings: Array = []
	for k in range(STATIONS): rings.append(ring_corners(k))
	var bands := {}
	for k in range(3,STATIONS-5):
		if k%BAND_EVERY == 0 and Variety.unit([k,41]) >= BAND_SKIP: bands[k] = true
	for k in range(STATIONS-1):
		var seg := _arc[k+1]-_arc[k]
		var tone := 1.0+(Variety.unit([k,17])-0.5)*SEGMENT_TONE
		var stone := STONE.lerp(COOL,Variety.unit([k,23]))
		for j in range(8):
			var n := (j+1)%8
			var colour := stone*float(FACE_TONE[j])*tone
			if j == 4: colour = UNDER*tone
			if k == 0 and j != 4: colour = CRESCENT
			if Variety.unit([k,j,59]) < 0.08: colour = colour*(1.0+WORN)
			var what := 0
			var width: float = (rings[k][j] as Vector3).distance_to(rings[k][n])
			if k > 0 and j == 0: what = 1
			elif bands.has(k) and j != 4 and j != 0: what = 2
			var count := maxf(1.0,roundf(seg/(width*0.95)))
			var aspect := SPINE_CELL/maxf(width,0.05) if what == 1 else (seg/count)/maxf(width,0.05)
			mesh.paint(colour,what,aspect,float(k*8+j),count)
			mesh.quad(rings[k][j],k,rings[k][n],k,rings[k+1][j],k+1,rings[k+1][n],k+1,-_arc[k],-_arc[k+1],_arc[k],_arc[k+1])
	_hr = RADIUS*girth*_profile(0.0)*HEAD_GIRTH*HEAD_BIG
	var eyes := _build_head(mesh,rings[0])
	var built := mesh.commit(_material)
	var haze := HazeParts.new()
	for e in eyes: haze.light(e,STATIONS,HAZE*0.8,1.0)
	haze.commit(built,_haze)
	return built

## The section at station `i` of SKULL, as numbers: [t, w, h, d, lip].
func _sec(t: float) -> Array:
	for i in range(SKULL.size()-1):
		var a: Array = SKULL[i]
		var b: Array = SKULL[i+1]
		if t <= float(b[0]) or i == SKULL.size()-2:
			var f := clampf((t-float(a[0]))/(float(b[0])-float(a[0])),0.0,1.0)
			f = f*f*(3.0-2.0*f)*0.5+f*0.5
			var out := [t]
			for k in range(1,5): out.append(lerpf(float(a[k]),float(b[k]),f))
			return out
	return SKULL[0]

static func _sq(c: float, e: float) -> float:
	return signf(c)*pow(absf(c),e)

## The skull's surface (head frame): `t` along (0 back, 1 snout), `a` round
## from the right lip (0) over the top (PI/2) to the left lip (PI). The
## brows jut out over the eyes; the crown dips a little between them.
func _skull(t: float, a: float) -> Vector3:
	var s := _sec(t)
	var hr := _hr
	var e := 2.0/SKULL_SQ
	var x := float(s[1])*hr*_sq(cos(a),e)
	var y := float(s[4])*hr+float(s[2])*hr*pow(absf(sin(a)),e)
	var z := t*HEAD
	# The brow shelf: out and up over the eye, on both sides.
	var up := minf(a,PI-a)
	var bt := smoothstep(BROW_T.x,lerpf(BROW_T.x,BROW_T.y,0.4),t)*(1.0-smoothstep(lerpf(BROW_T.x,BROW_T.y,0.7),BROW_T.y,t))
	var ba := smoothstep(BROW_A.x,lerpf(BROW_A.x,BROW_A.y,0.35),up)*(1.0-smoothstep(lerpf(BROW_A.x,BROW_A.y,0.75),BROW_A.y,up))
	var bump := BROW*hr*bt*ba
	x += signf(cos(a))*bump*0.85
	y += bump*0.3
	# The crown's dip between the brows.
	y -= 0.05*hr*bt*(1.0-smoothstep(0.0,0.45,absf(cos(a))))
	return Vector3(x,y,z)

## The jaw's surface (head frame, at rest): `t` along, `a` round from the
## right lip (0) under the chin (PI/2) to the left lip (PI).
func _jaw_at(t: float, a: float) -> Vector3:
	var tj := t*0.97
	var s := _sec(tj)
	var hr := _hr
	var e := 2.0/JAW_SQ
	var x := float(s[1])*JAW_IN*hr*_sq(cos(a),e)
	var y := float(s[4])*hr-float(s[3])*hr*pow(absf(sin(a)),e)
	return Vector3(x,y,tj*HEAD)

## A smooth normal of a surface `f(t, a)` (pointing `out` of it).
func _normal(f: Callable, t: float, a: float, sign_k: float) -> Vector3:
	var dt := 0.01
	var da := 0.02
	var p0: Vector3 = f.call(clampf(t-dt,0.0,1.0),a)
	var p1: Vector3 = f.call(clampf(t+dt,0.0,1.0),a)
	var q0: Vector3 = f.call(t,a-da)
	var q1: Vector3 = f.call(t,a+da)
	var n := (p1-p0).cross(q1-q0)*sign_k
	return n.normalized() if n.length() > 1e-8 else Vector3.UP

## The head: skull and jaw lofted, the eyes, brows, the mouth inside, its
## throat and gape, fangs and teeth, and the collar to the neck's first
## ring. Returns the eyes' places (head frame) for their haze.
func _build_head(mesh: MeshParts, ring0: Array) -> Array:
	var h := STATIONS
	var jb := STATIONS+2
	var ts: Array[float] = []
	for i in range(13): ts.append(pow(float(i)/12.0,0.9))
	var skull := func(t: float, a: float) -> Vector3: return _skull(t,a)
	var jawf := func(t: float, a: float) -> Vector3: return _jaw_at(t,a)
	# The skull: lip to lip over the top.
	var sk: Array = []
	var skn: Array = []
	for t in ts:
		var row: Array[Vector3] = []
		var nrow: Array[Vector3] = []
		for k in range(SKULL_SIDES+1):
			var a := PI*float(k)/SKULL_SIDES
			row.append(_skull(t,a))
			nrow.append(_normal(skull,t,a,-1.0))
		sk.append(row)
		skn.append(nrow)
	_loft(mesh,sk,skn,ts,h,h,"skull")
	# The jaw: lip to lip under the chin.
	var jw: Array = []
	var jwn: Array = []
	for t in ts:
		var row: Array[Vector3] = []
		var nrow: Array[Vector3] = []
		for k in range(JAW_SIDES+1):
			var a := PI*float(k)/JAW_SIDES
			row.append(_jaw_at(t,a))
			nrow.append(_normal(jawf,t,a,1.0))
		jw.append(row)
		jwn.append(nrow)
	_loft(mesh,jw,jwn,ts,jb,jb,"jaw")
	# The snout's and chin's tips closed.
	_cap(mesh,sk[ts.size()-1],h,Vector3(0.0,0.0,1.0))
	_cap(mesh,jw[ts.size()-1],jb,Vector3(0.0,-0.3,1.0))
	# Inside: the palate over the upper lip line, the mouth's floor in the
	# jaw, the gape at the corners (stretched as the jaw drops), the throat.
	var palate: Array = []
	var floor_: Array = []
	for t in ts:
		var s := _sec(t)
		var lip_r: Vector3 = _skull(t,0.0)
		var lip_l: Vector3 = _skull(t,PI)
		var jr: Vector3 = _jaw_at(t,0.0)
		var jl: Vector3 = _jaw_at(t,PI)
		var prow: Array[Vector3] = []
		var frow: Array[Vector3] = []
		for k in range(7):
			var u := float(k)/6.0
			var arch := sin(PI*u)
			prow.append(lip_r.lerp(lip_l,u)*Vector3(0.94,1.0,1.0)+Vector3(0.0,float(s[2])*_hr*0.42*arch,-0.02))
			frow.append(jr.lerp(jl,u)*Vector3(0.94,1.0,1.0)-Vector3(0.0,float(s[3])*_hr*0.45*arch,0.02))
		palate.append(prow)
		floor_.append(frow)
	mesh.paint(MOUTH_DARK,5,1.0,0.0,1.0)
	_sheet(mesh,palate,ts,h,Vector3.DOWN)
	_sheet(mesh,floor_,ts,jb,Vector3.UP)
	# Lips' inner faces: from the skull's lip in to the palate, the jaw's
	# lip in to its floor (gums).
	mesh.paint(GUM,0,1.0,0.0,1.0)
	for i in range(ts.size()-1):
		for side in [0,1]:
			var k_out := 0 if side == 0 else SKULL_SIDES
			var kj := 0 if side == 0 else JAW_SIDES
			var kp := 0 if side == 0 else 6
			var inward := Vector3(-1.0 if side == 0 else 1.0,0.0,0.0)
			_quad(mesh,sk[i][k_out],h,sk[i+1][k_out],h,palate[i+1][kp],h,palate[i][kp],h,inward+Vector3.DOWN*0.5)
			_quad(mesh,jw[i][kj],jb,jw[i+1][kj],jb,floor_[i+1][kp],jb,floor_[i][kp],jb,inward+Vector3.UP*0.5)
	# The gape: the mouth's corners, upper lip (head) to lower (jaw), over
	# its back third, and the throat across the back.
	mesh.paint(GUM,5,1.0,0.0,1.0)
	for i in range(4):
		for side in [0,1]:
			var ks := 0 if side == 0 else SKULL_SIDES
			var kj := 0 if side == 0 else JAW_SIDES
			var out := Vector3(1.0 if side == 0 else -1.0,0.0,0.0)
			_quad(mesh,sk[i][ks],h,sk[i+1][ks],h,jw[i+1][kj],jb,jw[i][kj],jb,out,true)
	mesh.paint(MOUTH_DARK,5,1.0,0.0,1.0)
	for k in range(6):
		_quad(mesh,palate[0][k],h,palate[0][k+1],h,floor_[0][k+1],jb,floor_[0][k],jb,Vector3.FORWARD*-1.0,true)
	# Fangs and teeth: pale worn stone, hung from the upper lip and set in
	# the jaw, seen as it opens.
	mesh.paint(PEBBLE_FANG,0,1.0,0.0,1.0)
	for side: float in [-1.0,1.0]:
		var a := 0.0 if side > 0.0 else PI
		var root: Vector3 = _skull(FANG_T,a)*Vector3(0.97,1.0,1.0)+Vector3(0.0,0.02*_hr,0.0)
		var fl := FANG_LONG*_hr
		_tube(mesh,[root+Vector3(0,0.06*_hr,0),root+Vector3(0.0,-fl*0.45,-0.03*_hr),root+Vector3(-side*0.01*_hr,-fl*0.85,-0.12*_hr),root+Vector3(-side*0.03*_hr,-fl,-0.2*_hr)],[FANG_WIDE*_hr,FANG_WIDE*0.8*_hr,FANG_WIDE*0.45*_hr,0.0],h,6)
		for i in range(TEETH):
			var t := lerpf(TEETH_T.x,TEETH_T.y,float(i)/float(TEETH-1))
			var at: Vector3 = _skull(t,a)*Vector3(0.86,1.0,1.0)
			var tl := TOOTH*_hr*lerpf(0.8,1.15,float(i)/float(TEETH-1))
			_tube(mesh,[at+Vector3(0,0.03*_hr,0),at+Vector3(0.0,-tl,-0.04*_hr)],[0.035*_hr,0.0],h,4)
		for i in range(LOW_TEETH):
			var t := lerpf(LOW_T.x,LOW_T.y,float(i)/float(LOW_TEETH-1))
			var at: Vector3 = _jaw_at(t,a)*Vector3(0.84,1.0,1.0)
			var tl := LOW_TOOTH*_hr
			_tube(mesh,[at-Vector3(0,0.03*_hr,0),at+Vector3(0.0,tl,-0.03*_hr)],[0.03*_hr,0.0],jb,4)
	# The eyes, sunk under the brows: a patch of the eye's carving laid on
	# the skull (shaders/rune_serpent_runes.gdshaderinc `rs_eye`).
	var eyes: Array = []
	for side: float in [-1.0,1.0]:
		var a0 := EYE_A if side > 0.0 else PI-EYE_A
		eyes.append(_eye(mesh,a0,side))
	# The collar: the head's back (skull and jaw) to the neck's first ring.
	var back: Array = []
	var back_bone: Array = []
	for k in range(SKULL_SIDES+1):
		back.append(sk[0][k])
		back_bone.append(h)
	for k in range(JAW_SIDES-1,0,-1):
		back.append(jw[0][k])
		back_bone.append(jb)
	mesh.paint(CRESCENT,0,1.0,0.0,1.0)
	_zip(mesh,back,back_bone,ring0,0)
	return eyes

## A lofted surface: rows of points along `ts`, their normals; on bones.
func _loft(mesh: MeshParts, rows: Array, normals: Array, ts: Array[float], bone_a: int, bone_b: int, which: String) -> void:
	for i in range(rows.size()-1):
		var r0: Array = rows[i]
		var r1: Array = rows[i+1]
		for k in range(r0.size()-1):
			var p := [r0[k],r0[k+1],r1[k+1],r1[k]]
			var n := [normals[i][k],normals[i][k+1],normals[i+1][k+1],normals[i+1][k]]
			var mid: Vector3 = ((p[0] as Vector3)+p[1]+p[2]+p[3])*0.25
			var nm: Vector3 = ((n[0] as Vector3)+n[1]+n[2]+n[3]).normalized()
			mesh.paint(_tone(nm,mid,which),0,1.0,float(i*31+k),1.0)
			_raw_tri(mesh,[p[0],p[1],p[2]],[n[0],n[1],n[2]],[bone_a,bone_a,bone_b])
			_raw_tri(mesh,[p[0],p[2],p[3]],[n[0],n[2],n[3]],[bone_a,bone_b,bone_b])

## The stone's tone by where a face looks: the top paler, the flanks the
## body's, under it the belly's, the lips a worn band; each face a shade off.
func _tone(n: Vector3, mid: Vector3, which: String) -> Color:
	var shade := 1.0+(Variety.unit([roundi(mid.x*40.0),roundi(mid.y*40.0),roundi(mid.z*40.0),7])-0.5)*SEGMENT_TONE
	if n.y < -0.35: return UNDER*shade
	if which == "jaw": return STONE.lerp(UNDER,0.35)*shade
	var c := STONE.lerp(COOL,0.4)*lerpf(0.98,1.08,clampf(n.y,0.0,1.0))
	return c*shade

## A triangle with its own normals (smooth), wound to show outward.
func _raw_tri(mesh: MeshParts, p: Array, n: Array, b: Array) -> void:
	var a: Vector3 = p[0]
	var bb: Vector3 = p[1]
	var c: Vector3 = p[2]
	var face := (bb-a).cross(c-a)
	if face.length_squared() < 1e-12: return
	var out: Vector3 = (n[0] as Vector3)+n[1]+n[2]
	var order := [0,2,1] if face.dot(out) > 0.0 else [0,1,2]
	for i: int in order:
		var q: Vector3 = p[i]
		var made := mesh.dress_corner(q,HEAD-q.z)
		mesh.raw(q,int(b[i]),n[i],made[0],made[1],HEAD-q.z,Vector2.ZERO)

## A flat quad a b c d (each on its bone) showing toward `out`; `both`: from
## behind too.
func _quad(mesh: MeshParts, a: Vector3, ba: int, b: Vector3, bb: int, c: Vector3, bc: int, d: Vector3, bd: int, out: Vector3, both := false) -> void:
	_flat(mesh,a,ba,b,bb,c,bc,out)
	_flat(mesh,a,ba,c,bc,d,bd,out)
	if both:
		_flat(mesh,a,ba,b,bb,c,bc,-out)
		_flat(mesh,a,ba,c,bc,d,bd,-out)

func _flat(mesh: MeshParts, a: Vector3, ba: int, b: Vector3, bb: int, c: Vector3, bc: int, out: Vector3) -> void:
	var n := (b-a).cross(c-a)
	if n.length_squared() < 1e-12: return
	n = n.normalized()
	if n.dot(out) < 0.0: n = -n
	_raw_tri(mesh,[a,b,c],[n,n,n],[ba,bb,bc])

## A sheet of rows (inside the mouth) showing toward `out`.
func _sheet(mesh: MeshParts, rows: Array, _ts: Array[float], bone: int, out: Vector3) -> void:
	for i in range(rows.size()-1):
		for k in range(rows[i].size()-1):
			_quad(mesh,rows[i][k],bone,rows[i][k+1],bone,rows[i+1][k+1],bone,rows[i+1][k],bone,out)

## A tip closed in a fan to its middle, pushed out a little.
func _cap(mesh: MeshParts, row: Array, bone: int, out: Vector3) -> void:
	var mid := Vector3.ZERO
	for p: Vector3 in row: mid += p
	mid /= float(row.size())
	mid += out.normalized()*0.04*_hr
	for k in range(row.size()-1):
		_flat(mesh,row[k],bone,row[k+1],bone,mid,bone,out)
	_flat(mesh,row[row.size()-1],bone,row[0],bone,mid,bone,out)

## The eye on side `side` (+1 right): a grid on the skull round its middle
## (EYE_T, `a0`), sunk under the brow, the eye's square across it (x back
## to front, y foot to brow). Returns its middle.
func _eye(mesh: MeshParts, a0: float, side: float) -> Vector3:
	const GU := 10
	const GV := 8
	var dt := EYE_HALF.x*_hr/HEAD
	var da := EYE_HALF.y*1.4
	var grid: Array = []
	var skull := func(t: float, a: float) -> Vector3: return _skull(t,a)
	for iv in range(GV+1):
		var row: Array = []
		for iu in range(GU+1):
			var u := float(iu)/GU
			var v := float(iv)/GV
			var t := EYE_T+(u*2.0-1.0)*dt
			# Up the side toward the brow: right side a grows up, left falls.
			var a := a0+(v*2.0-1.0)*da*side
			var n := _normal(skull,t,a,-1.0)
			row.append([_skull(t,a)+n*0.02*_hr,n,Vector2(u,v)])
		grid.append(row)
	mesh.paint(STONE*1.04,4,1.0,0.0,1.0)
	for iv in range(GV):
		for iu in range(GU):
			var c := [grid[iv][iu],grid[iv][iu+1],grid[iv+1][iu+1],grid[iv+1][iu]]
			for tri: Array in [[0,1,2],[0,2,3]]:
				var p: Array = []
				var nn: Array = []
				var sq: Array = []
				for m: int in tri:
					p.append(c[m][0])
					nn.append(c[m][1])
					sq.append(c[m][2])
				var p0: Vector3 = p[0]
				var p1: Vector3 = p[1]
				var p2: Vector3 = p[2]
				var face := (p1-p0).cross(p2-p0)
				var out: Vector3 = (nn[0] as Vector3)+nn[1]+nn[2]
				var order := [0,2,1] if face.dot(out) > 0.0 else [0,1,2]
				for i: int in order:
					var q: Vector3 = p[i]
					var made := mesh.dress_corner(q,HEAD-q.z)
					mesh.raw(q,STATIONS,nn[i],made[0],made[1],HEAD-q.z,sq[i])
	var mid: Vector3 = _skull(EYE_T,a0)
	return mid+_normal(skull,EYE_T,a0,-1.0)*0.25

## Two loops joined by angle round the head's axis: `a` (each point its own
## bone) to the ring `b` (all on bone `bone_b`), faces showing outward.
func _zip(mesh: MeshParts, a: Array, a_bones: Array, b: Array, bone_b: int) -> void:
	var c := Vector2(0.0,-0.05*_hr)
	var ang := func(p: Vector3) -> float: return fposmod(atan2(p.y-c.y,p.x-c.x),TAU)
	var ia := _sorted(a,ang)
	var ib := _sorted(b,ang)
	var na := ia.size()
	var nb := ib.size()
	var aa := func(k: int) -> float: return float(ang.call(a[ia[k%na]]))+(TAU if k >= na else 0.0)
	var ab := func(k: int) -> float: return float(ang.call(b[ib[k%nb]]))+(TAU if k >= nb else 0.0)
	var i := 0
	var j := 0
	while i < na or j < nb:
		var pa: Vector3 = a[ia[i%na]]
		var pb: Vector3 = b[ib[j%nb]]
		var mid := (pa+pb)*0.5
		var out := Vector3(mid.x,mid.y-c.y,0.0)
		if j >= nb or (i < na and float(aa.call(i+1)) <= float(ab.call(j+1))):
			var pn: Vector3 = a[ia[(i+1)%na]]
			_flat(mesh,pa,int(a_bones[ia[i%na]]),pn,int(a_bones[ia[(i+1)%na]]),pb,bone_b,out)
			i += 1
		else:
			var pn: Vector3 = b[ib[(j+1)%nb]]
			_flat(mesh,pa,int(a_bones[ia[i%na]]),pn,bone_b,pb,bone_b,out)
			j += 1

static func _sorted(pts: Array, ang: Callable) -> Array:
	var idx: Array = range(pts.size())
	idx.sort_custom(func(x: int, y: int) -> bool: return float(ang.call(pts[x])) < float(ang.call(pts[y])))
	return idx

# --- The ruff ---------------------------------------------------------------

## Kukulkan's ruff: stone feathers fanned back over the neck from the
## skull's back and sides, two rows, rooted on the skull itself.
func _build_ruff() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(2):
		var n := FEATHERS if row == 0 else FEATHERS-1
		for i in range(n):
			var u := (float(i)+(0.0 if row == 0 else 0.5))/float(FEATHERS-1)
			var a := lerpf(-FEATHER_ARC*0.5,FEATHER_ARC*0.5,u)
			var round_a := PI*0.5-a*0.85
			var t := 0.1 if row == 0 else 0.05
			var on := _skull(t,round_a)
			var out := Vector3(on.x,on.y+0.1*_hr,0.0).normalized()
			var root := on-out*0.12*_hr
			var side_share := absf(a)/(FEATHER_ARC*0.5)
			var length := FEATHER_LONG*lerpf(1.0,FEATHER_SIDE,side_share)*(1.0 if row == 0 else FEATHER_ROW2)
			var fan := FEATHER_FAN*(1.0 if row == 0 else 1.25)
			var dir := (Vector3(0.0,0.0,-1.0)*cos(fan)+out*sin(fan)).normalized()
			_feather(st,root,dir,out,length,FEATHER_WIDE*(1.0 if row == 0 else 0.8),i*7+row*31)
	st.generate_normals()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("fill",FILL*0.6)
	mat.set_shader_parameter("rim",RIM)
	mat.set_shader_parameter("roughness_value",0.95)
	mat.set_shader_parameter("weather",WEATHER)
	mat.set_shader_parameter("bump_strength",BUMP)
	_ruff = MeshInstance3D.new()
	_ruff.name = "Ruff"
	_ruff.mesh = mesh
	_ruff.material_override = mat
	var at := BoneAttachment3D.new()
	at.name = "RuffBone"
	_skeleton.add_child(at)
	at.bone_name = "head"
	at.add_child(_ruff)

func _feather(st: SurfaceTool, root: Vector3, dir: Vector3, out: Vector3, length: float, wide: float, salt: int) -> void:
	const SEGS := 6
	var across := dir.cross(out).normalized()
	var face := across.cross(dir).normalized()
	var secs: Array = []
	for s in range(SEGS+1):
		var t := float(s)/SEGS
		var w := wide*(0.6+0.5*sin(PI*minf(t*0.7+0.15,1.0)))*(1.0-0.45*t*t*t)
		var thick := 0.36*(1.0-0.5*t)
		var curl := face*(0.12*length*t*t)
		var c := root+dir*length*t+curl
		var jag := 0.06*sin(float(salt)+t*9.0)
		secs.append([c-across*w*0.5+face*jag,c+face*thick,c+across*w*0.5+face*jag,c-face*thick*0.6,t])
	for s in range(SEGS):
		var a: Array = secs[s]
		var b: Array = secs[s+1]
		for k in range(4):
			var k2 := (k+1)%4
			var occ := 0.75 if k == 3 or k2 == 3 else 1.0
			_fq(st,a[k],a[k2],b[k2],b[k],float(a[4]),float(b[4]),occ)

func _fq(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t0: float, t1: float, occ: float) -> void:
	for pair in [[p0,t0],[p1,t0],[p2,t1],[p0,t0],[p2,t1],[p3,t1]]:
		var p: Vector3 = pair[0]
		var tone := FEATHER_TONE.lerp(FEATHER_TIP,smoothstep(0.55,1.0,float(pair[1])))
		st.set_color(Color(tone.r*occ,tone.g*occ,tone.b*occ,occ))
		st.set_uv(Vector2(p.x,p.y))
		st.set_uv2(Vector2(p.z,0.0))
		st.add_vertex(p)
