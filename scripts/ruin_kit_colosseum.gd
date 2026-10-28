extends RefCounted
## The ruin kit's abandoned colosseum (`colosseum`), a set piece standing on
## its own in the amberlands (scripts/endless/set_plan.gd), built with the
## kit's Build and the gothic pieces' mossed stone and thick growth
## (scripts/ruin_kit_gothic.gd, scripts/gothic_growth.gd).
##
## An elliptical amphitheatre RX*2 by RZ*2 m (160 x 190) over its outer
## wall, its long axis along Z, on a podium P m high (stepped down outside):
## - the outer wall: SLOTS bays round the ellipse, each three arched tiers
##   (an engaged column and a cornice a tier on the outer face) and a solid
##   attic, to ATTIC over the podium (50 m over the foot). The two bays on
##   the long axis are the great gates. Some bays' lower arch is walled up,
##   a few are tighter on purpose (TOY_TIGHT), some have lost their attic;
## - the ambulatory: a ring corridor AMB wide and ROOF.x tall inside the
##   outer wall, roofed by the top walkway in most bays, flown as a lap;
## - the inner wall: blind arcading; at every eighth bay a first-tier
##   passage's arch walled up (its tunnel to the arena was the bay's width,
##   too long and tight to thread: closed, not flown), four bays on a
##   second-tier one open (a vomitorium cut through the upper seats to the
##   bowl), and the great gates' inner arches;
## - the seating bowl: TREADS rings stepping down from the walkway to the
##   arena wall; the arena: a flat oval floor at P, fallen in along its long
##   axis over the hypogeum: a trench TRENCH wide flown along its length
##   (its ends ramps of fallen floor), side cells either side;
## - abandoned: one long side (plan `broken`) fallen to its lower tiers in a
##   ragged stepped break, the walkway and upper seats behind it gone to
##   rubble, and a rubble slope outside it.
##
## Cost: each kind of outer and inner bay is built once (a Build of its
## own, its growth dressed on it) and drawn round the ring as MultiMeshes,
## stone and growth apart (under "Bays"), the stone given Godot's levels
## (scripts/ruin_lod.gd), the growth casting no shadow and gone past
## GothicGrowth.FAR_GROWTH. The rest (plinth, floors, the walkway, the
## seats, the arena, the rubble) is one Build ("Mesh"), laid slot by slot
## on the ring's true curve.
##
## Collision: every block in the land is an AABB in the piece's frame
## (scripts/endless/box_solid.gd), so turned blocks would close a curving
## wall's openings. The colosseum's solid is drawn from its plan instead,
## column by column on a grid (CELL, FINE in the walls), merged into boxes
## ("Body", a box hull a shape), so its openings are what the plan says.
##
## The openings: `openings` (as the gothic pieces') gives every flown
## opening's frame and size from the plan, without building it. Widths come
## from toy widths named here through `WorldScale.opening`.
##
## Its foot on y 0 round the origin, its north gate toward +Z. Meta:
## "openings", "bounds", "colosseum" (the plan), "stats".

const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Build = RuinKit.Build
const Gothic = preload("res://scripts/ruin_kit_gothic.gd")
const GothicGrowth = preload("res://scripts/gothic_growth.gd")
const RuinGrowth = preload("res://scripts/ruin_growth.gd")
const RuinLod = preload("res://scripts/ruin_lod.gd")

const PIECES := ["colosseum"]

## Toy widths (the flown openings, scripts/world_scale.gd): the arcade's
## arches, the tight ones, the great gates, the ambulatory and the trench.
const TOY_ARCH := 3.2
const TOY_TIGHT := 2.7
const TOY_GATE := 5.0
const TOY_AMB := 7.0
const TOY_TRENCH := 5.5
## The inner wall's passages (to the arena, up to the bowl).
const TOY_PASS := 2.9
static var ARCH: float = WorldScale.opening(TOY_ARCH)
static var TIGHT: float = WorldScale.opening(TOY_TIGHT)
static var GATE: float = WorldScale.opening(TOY_GATE)
static var AMB: float = WorldScale.opening(TOY_AMB)
static var TRENCH: float = WorldScale.opening(TOY_TRENCH)
static var PASS: float = WorldScale.opening(TOY_PASS)

## The outer ellipse's semi-axes (m): across (x) and along (z).
const RX := 80.0
const RZ := 95.0
## Bays round the ring; the gate bays' width along the ring (m).
const SLOTS := 64
const GATE_SLOT := 17.0
## The podium: the arena's and the ambulatory's floor over the foot (m),
## and how far below the foot the plinth reaches (uneven ground).
const P := 8.0
const FOUND := 8.0
## The outer wall's and the inner wall's half thickness (m).
const WALL_D := 1.3
const INNER_D := 1.2
## The tiers over the podium: (sill, springing, top) each (m).
const TIERS := [Vector3(0.0,6.6,11.5),Vector3(12.3,18.2,23.0),Vector3(23.8,29.4,34.0)]
const ATTIC := 42.0
## The ambulatory's roof (the walkway): underside, top, over the podium.
const ROOF := Vector2(22.0,23.5)
## The great gates' springing over the podium.
const GATE_SPRING := 11.0
## The voussoir ring's depth (m), the walling's course (m).
const RING := 1.0
const COURSE := 2.0
## The seats: rings stepping down from the walkway, each TREAD deep and
## RISE lower than the last.
const TREADS := 10
const TREAD := 3.4
const RISE := 1.9
## The plinth's steps outside the wall: their depth (m) and count.
const STEP := 2.7
const STEPS := 3
## The arena's floor squares (m), the fallen region's half length (z),
## where the trench's ramps start along it, its flown lane's half length.
## The ramps run on under the great gates' passages to the podium at the
## inner wall (`_trench_floor`), so the climb out has no floor edge.
const SQUARE := 3.5
const FALL_Z := 42.0
const RAMP_AT := 26.0
const TRENCH_LANE := 12.0
## The broken side: bays either way of its middle that fall, the rubble
## slope's reach outside the wall at its deepest (m).
const BREAK_HALF := 7.5
const RUBBLE := 30.0
## The solid's grid (m) and, near the walls, its finer cells.
const CELL := 1.0
const FINE := 0.5

## Radial distances inward of the outer face (m).
const OUT_IN := WALL_D*2.0
static var INNER_MID: float = OUT_IN+AMB+INNER_D
static var INNER_IN: float = OUT_IN+AMB+INNER_D*2.0
static var ARENA_D: float = OUT_IN+AMB+INNER_D*2.0+TREADS*TREAD

# --- The ring: the outer ellipse by arc length ------------------------------

## Arc length s runs from the north gate (0, RZ) toward +x; phi with
## (x, z) = (RX sin phi, RZ cos phi). d is how far inward of the outer face.
const TABLE := 4096
static var _len := 0.0
static var _s_at_phi := PackedFloat32Array()
static var _phi_at_s := PackedFloat32Array()
static var _ready := _tables()

static func _tables() -> bool:
	var n := TABLE
	_s_at_phi.resize(n+1)
	var s := 0.0
	var last := Vector2(0.0,RZ)
	_s_at_phi[0] = 0.0
	for i in range(1,n+1):
		var phi := TAU*i/n
		var q := Vector2(RX*sin(phi),RZ*cos(phi))
		s += q.distance_to(last)
		last = q
		_s_at_phi[i] = s
	_len = s
	_phi_at_s.resize(n+1)
	var j := 0
	for i in range(n+1):
		var want := _len*i/n
		while j < n-1 and _s_at_phi[j+1] < want: j += 1
		var t := clampf((want-_s_at_phi[j])/maxf(_s_at_phi[j+1]-_s_at_phi[j],1e-6),0.0,1.0)
		_phi_at_s[i] = TAU*(j+t)/n
	return true

static func ring_length() -> float:
	return _len

static func phi_of(s: float) -> float:
	var u := fposmod(s,_len)/_len*TABLE
	var i := mini(int(u),TABLE-1)
	return lerpf(_phi_at_s[i],_phi_at_s[i+1],u-i)

static func s_of(phi: float) -> float:
	var u := fposmod(phi,TAU)/TAU*TABLE
	var i := mini(int(u),TABLE-1)
	return lerpf(_s_at_phi[i],_s_at_phi[i+1],u-i)

static func normal_at(phi: float) -> Vector3:
	return Vector3(sin(phi)/RX,0.0,cos(phi)/RZ).normalized()

## The ring's curvature at `phi` (1/m).
static func kappa(phi: float) -> float:
	var c := cos(phi)
	var sn := sin(phi)
	return RX*RZ/pow(RX*RX*c*c+RZ*RZ*sn*sn,1.5)

## The point `d` inward of the outer face at arc length `s` (y 0).
static func point(s: float, d: float) -> Vector3:
	var phi := phi_of(s)
	return Vector3(RX*sin(phi),0.0,RZ*cos(phi))-normal_at(phi)*d

## The frame at (s, d): x along the ring (s growing), y up, z outward.
static func frame(s: float, d: float, y := 0.0) -> Transform3D:
	var phi := phi_of(s)
	var n := normal_at(phi)
	var t := Vector3.UP.cross(n)
	return Transform3D(Basis(t,Vector3.UP,n),Vector3(RX*sin(phi),y,RZ*cos(phi))-n*d)

## (s, d) of the point (x, z): its nearest on the outer ellipse (Newton
## from its elliptic angle; inside the evolute it may settle on another
## normal, but every point there is deep in the arena anyway).
static func nearest(x: float, z: float) -> Vector2:
	var phi := atan2(x/RX,z/RZ)
	for i in range(8):
		var sn := sin(phi)
		var c := cos(phi)
		var px := RX*sn-x
		var pz := RZ*c-z
		var dx := RX*c
		var dz := -RZ*sn
		var g := px*dx+pz*dz
		var g2 := dx*dx+dz*dz-px*RX*sn-pz*RZ*c
		if absf(g2) < 1e-6: break
		var step := clampf(g/g2,-0.3,0.3)
		phi -= step
		if absf(step) < 1e-5: break
	var n := normal_at(phi)
	var d := (RX*sin(phi)-x)*n.x+(RZ*cos(phi)-z)*n.z
	return Vector2(s_of(phi),d)

# --- Slots -----------------------------------------------------------------------

## A plain bay's width along the outer ring (m).
static func pitch() -> float:
	return (_len-2.0*GATE_SLOT)/(SLOTS-2)

## Slot `k`'s edges along the ring (s).
static func slot_edges(k: int) -> Vector2:
	var w := pitch()
	var half := SLOTS/2
	var a: float
	if k == 0: a = -GATE_SLOT*0.5
	elif k < half: a = GATE_SLOT*0.5+(k-1)*w
	elif k == half: a = GATE_SLOT*0.5+(half-1)*w
	else: a = GATE_SLOT*1.5+(half-1)*w+(k-half-1)*w
	return Vector2(a,a+(GATE_SLOT if k == 0 or k == half else w))

static func slot_mid(k: int) -> float:
	var e := slot_edges(k)
	return (e.x+e.y)*0.5

## The slot holding arc length `s`.
static func slot_of(s: float) -> int:
	var w := pitch()
	var half := SLOTS/2
	var q := fposmod(s+GATE_SLOT*0.5,_len)-GATE_SLOT*0.5
	if q < GATE_SLOT*0.5: return 0
	var past := GATE_SLOT*0.5+(half-1)*w
	if q < past: return 1+clampi(int((q-GATE_SLOT*0.5)/w),0,half-2)
	if q < past+GATE_SLOT: return half
	return half+1+clampi(int((q-past-GATE_SLOT)/w),0,half-2)

## `s` less slot `k`'s middle, wrapped (along the outer ring, m).
static func off_slot(s: float, k: int) -> float:
	return wrapf(s-slot_mid(k),-_len*0.5,_len*0.5)

## The inner bays are built at a nominal shrink of the ring and scaled
## along it to fit slot `k`.
static func inner_scale(k: int) -> float:
	return (1.0-kappa(phi_of(slot_mid(k)))*INNER_MID)/_inner_nominal()

static func _inner_nominal() -> float:
	return 1.0-INNER_MID/77.0

## The inner bays' arches are built at the nominal shrink and scaled to
## their slot (`inner_scale`), so a hole drawn W wide is W x that scale in
## the world. The gate's is drawn GATE (GATE x its scale in the world, as
## `openings` says); a passage's drawn so its narrowest slot (the long
## axis's ends, the ring's tightest) still opens PASS.
static func _pass_hole() -> float:
	return PASS/((1.0-RZ/(RX*RX)*INNER_MID)/_inner_nominal())

# --- The plan --------------------------------------------------------------------

## The piece's plan from its seed and wear, a pure function: what each bay
## is, which keep their walkway, how far each has fallen, the arena's
## fallen squares. Its own rng, so `openings` gives the same unbuilt.
static func plan(id: String, seed_value: int, weathered := 0.6) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([id,seed_value,"colosseum_plan"])
	var p := {"id":id,"seed":seed_value,"weathered":weathered}
	var broken := SLOTS/4 if r.randf() < 0.5 else SLOTS*3/4
	p["broken"] = broken
	var outer: Array = []
	var inner: Array = []
	var roof: Array = []
	var fall: Array = []
	var cap: Array = []
	for k in range(SLOTS):
		var dk := absf(float(k-broken))
		var f := clampf(1.0-(dk-1.0)/BREAK_HALF,0.0,1.0)
		if f > 0.0: f = clampf(f+r.randf_range(-0.12,0.12),0.0,1.0)
		fall.append(f)
		var o := "whole"
		if k == 0 or k == SLOTS/2: o = "gate"
		elif f > 0.82: o = "stump"
		elif f > 0.56: o = "cut1"
		elif f > 0.3: o = "cut2"
		elif f > 0.06: o = "cut3"
		else:
			var roll := r.randf()
			if roll < 0.13: o = "blocked"
			elif roll < 0.24: o = "tight"
			elif roll < 0.24+0.14*weathered: o = "cut3"
		var i := "blind"
		if o == "gate": i = "gate"
		elif f > 0.45: i = "low"
		elif k%8 == 4: i = "pass2"
		elif k%8 == 0: i = "pass1"
		# A passage's line wants its outer arch open on its tier (a walled
		# first-tier one keeps it so: the arcade line through it stays).
		if i == "pass1" and o == "blocked": o = "whole"
		if i == "pass2" and o == "cut3" and f <= 0.0: o = "whole"
		outer.append(o)
		inner.append(i)
		roof.append(f < 0.15 and r.randf() > 0.16)
		# The seats behind a fallen bay: the treads over this lost.
		cap.append(lerpf(ROOF.y+1.0,4.5,f)+r.randf_range(-1.0,1.0)*f)
	p["outer"] = outer
	p["inner"] = inner
	p["roof"] = roof
	p["fall"] = fall
	p["cap"] = cap
	# The arena's fallen squares: the trench's strip its whole length, the
	# bands beside it often toward the middle.
	var fallen := {}
	var walls := {}
	for key: Vector2i in _arena_squares():
		var c := _square_box(key).get_center()
		var ax := absf(c.x)
		var az := absf(c.z)
		var gone := false
		if ax < TRENCH*0.5: gone = az < FALL_Z
		elif ax < TRENCH*0.5+SQUARE: gone = az < FALL_Z-8.0 and r.randf() < 0.78
		elif ax < TRENCH*0.5+SQUARE*2.0: gone = az < FALL_Z-15.0 and r.randf() < 0.4
		if gone:
			fallen[key] = true
			walls[key] = P-r.randf_range(0.8,2.2)
	p["fallen"] = fallen
	p["wall_top"] = walls
	return p

## The arena's floor squares (grid keys) whose middle is in the arena.
static var _squares: Array = []
static func _arena_squares() -> Array:
	if not _squares.is_empty(): return _squares
	var out: Array = []
	for j in range(-14,14):
		for i in range(-10,10):
			var c := _square_box(Vector2i(i,j)).get_center()
			if nearest(c.x,c.z).y > ARENA_D-1.0: out.append(Vector2i(i,j))
	_squares = out
	return out

## A floor square's box (y the slab) by its key: x keys 0 and -1 the
## trench's halves (|x| < TRENCH/2), then SQUARE bands out; z rows SQUARE.
static func _square_box(key: Vector2i) -> AABB:
	var x0: float
	var x1: float
	var h := TRENCH*0.5
	if key.x == 0:
		x0 = 0.0
		x1 = h
	elif key.x == -1:
		x0 = -h
		x1 = 0.0
	elif key.x > 0:
		x0 = h+SQUARE*(key.x-1)
		x1 = x0+SQUARE
	else:
		x1 = -h-SQUARE*(-key.x-2)
		x0 = x1-SQUARE
	var z0 := key.y*SQUARE
	return AABB(Vector3(x0,P-0.8,z0),Vector3(x1-x0,0.8,SQUARE))

static func _square_of(x: float, z: float) -> Vector2i:
	var h := TRENCH*0.5
	var i: int
	if absf(x) < h: i = 0 if x >= 0.0 else -1
	elif x > 0.0: i = 1+int((x-h)/SQUARE)
	else: i = -2-int((-x-h)/SQUARE)
	return Vector2i(i,floori(z/SQUARE))

## The width of an outer bay's arches.
static func _arch_w(kind: String) -> float:
	return TIGHT if kind == "tight" else ARCH

## The lowest and highest an outer bay of `kind` stands to (over the foot).
static func _outer_low(kind: String) -> float:
	match kind:
		"stump": return P+2.5
		"cut1": return P+8.5
		"cut2": return P+17.0
		"cut3": return P+30.0
	return P+40.0

static func _outer_high(kind: String) -> float:
	match kind:
		"stump": return P+7.0
		"cut1": return P+14.0
		"cut2": return P+25.0
		"cut3": return P+37.0
	return P+ATTIC

## Whether tier `t` (0..2) of an outer bay of `kind` is a whole arch.
static func _tier_open(kind: String, t: int) -> bool:
	if kind == "gate": return t == 2
	if kind == "blocked" and t == 0: return false
	var tier: Vector3 = TIERS[t]
	return P+tier.y+_arch_w(kind)*0.5+RING+0.6 < _outer_low(kind)

## The passages through the seats, each a straight band from the inner
## wall's inner face along its slot's inward normal: {k, kind ("gate",
## "pass1", "pass2"), o (its start, y 0), dir, half (its half width), len}.
static func bands(p: Dictionary) -> Array:
	var out: Array = []
	var inner: Array = p["inner"]
	for k in range(SLOTS):
		var ik := String(inner[k])
		# (A first-tier passage is walled up: no way through the seats.)
		if not ik in ["gate","pass2"]: continue
		var mid := slot_mid(k)
		var o := point(mid,INNER_IN-0.3)
		var dir := -normal_at(phi_of(mid))
		var w := (GATE if ik == "gate" else _pass_hole())*inner_scale(k)
		var l := ARENA_D-INNER_IN+1.0 if ik != "pass2" else _cut_treads()*TREAD+0.6
		out.append({"k":k,"kind":ik,"o":o,"dir":dir,"half":w*0.5,"len":l})
	return out

## The band holding (x, z), or {}.
static func band_at(bs: Array, x: float, z: float) -> Dictionary:
	for bd: Dictionary in bs:
		var o: Vector3 = bd.o
		var dir: Vector3 = bd.dir
		var vx := x-o.x
		var vz := z-o.z
		var along := vx*dir.x+vz*dir.z
		if along < 0.0 or along > float(bd.len): continue
		if absf(vx*dir.z-vz*dir.x) < float(bd.half): return bd
	return {}

## A band's ceiling (a covered passage's flat soffit at its arch's crown)
## or, for a vomitorium, its floor (its arch's sill).
static func band_level(bd: Dictionary) -> float:
	match String(bd.kind):
		"gate": return P+GATE_SPRING+float(bd.half)
		"pass1": return P+(TIERS[0] as Vector3).y+float(bd.half)
	return P+(TIERS[1] as Vector3).x

## How many treads a vomitorium cuts (those over its sill).
static func _cut_treads() -> int:
	var sill: float = (TIERS[1] as Vector3).x
	var n := 0
	for i in range(TREADS):
		if ROOF.y-RISE*i > sill: n = i+1
	return n

# --- The openings ----------------------------------------------------------------

## The piece's flown openings, in its frame (as RuinKitGothic.openings:
## name, kind, frame, size, head, knife, round, lane; some add tier, slot,
## tight, roofed). Kinds:
##   arcade      an outer arch, `tier` 1..3, through the wall (o<slot>_<tier>)
##   vomitorium  a second-tier passage's arch in the inner wall (i<slot>)
##   tunnel      the cut behind a vomitorium, a lane (i<slot>_way)
##   gate        a great gate's outer and inner arches (gate_n, gate_n_in)
##   gate_way    the passage on from a gate to the arena, a lane
##   ambulatory  the ring corridor a bay at a time, along the ring (amb<slot>)
##   arena       the arena, skimmed along the long axis, a lane
##   trench      the trench under the fallen floor (a lane) and its ends
##   break       the gap over the broken side, dropped through inward
##   bowl        the bowl's middle, crossed from the broken side
static func openings(id: String, seed_value: int, weathered := 0.6) -> Array:
	var p := plan(id,seed_value,weathered)
	var out: Array = []
	var outer: Array = p["outer"]
	for k in range(SLOTS):
		var kind := String(outer[k])
		var mid := slot_mid(k)
		var f := frame(mid,WALL_D)
		for t in range(3):
			if not _tier_open(kind,t): continue
			var tier: Vector3 = TIERS[t]
			var w := _arch_w(kind)
			_opening(out,"colosseum/o%d_%d" % [k,t+1],"arcade",f*Vector3(0.0,P+(tier.x+tier.y)*0.5,0.0),f.basis.z,Vector3(w,tier.y-tier.x,WALL_D*2.0),w*0.5,false,false,false,{"tier":t+1,"slot":k,"tight":kind == "tight"})
		if kind == "gate":
			var nm := "colosseum/gate_n" if k == 0 else "colosseum/gate_s"
			_opening(out,nm,"gate",f*Vector3(0.0,P+GATE_SPRING*0.5,0.0),f.basis.z,Vector3(GATE,GATE_SPRING,WALL_D*2.0),GATE*0.5,false,false,false,{"slot":k})
			var fi := frame(mid,INNER_MID)
			var sc := inner_scale(k)
			_opening(out,nm+"_in","gate",fi*Vector3(0.0,P+GATE_SPRING*0.5,0.0),fi.basis.z,Vector3(GATE*sc,GATE_SPRING,INNER_D*2.0),GATE*sc*0.5,false,false,false,{"slot":k})
	for bd: Dictionary in bands(p):
		var k: int = bd.k
		var mid := slot_mid(k)
		var o: Vector3 = bd.o
		var dir: Vector3 = bd.dir
		var l := float(bd.len)-1.0
		var w := float(bd.half)*2.0
		var kind := String(bd.kind)
		var at := o+dir*l*0.5
		if kind == "gate":
			var nm := "colosseum/gate_n" if k == 0 else "colosseum/gate_s"
			_opening(out,nm+"_way","gate_way",at+Vector3.UP*(P+(band_level(bd)-P)*0.5),-dir,Vector3(w,band_level(bd)-P-0.4,l),0.0,false,false,true,{"slot":k})
			continue
		var t := 0 if kind == "pass1" else 1
		var tier: Vector3 = TIERS[t]
		var fi := frame(mid,INNER_MID)
		_opening(out,"colosseum/i%d" % k,"passage" if t == 0 else "vomitorium",fi*Vector3(0.0,P+(tier.x+tier.y)*0.5,0.0),fi.basis.z,Vector3(w,tier.y-tier.x,INNER_D*2.0),w*0.5,false,false,false,{"tier":t+1,"slot":k})
		var lo := P+tier.x
		var hi := band_level(bd) if t == 0 else P+tier.y+w*0.5
		_opening(out,"colosseum/i%d_way" % k,"tunnel",at+Vector3.UP*((lo+hi)*0.5),-dir,Vector3(w,hi-lo-0.4,l),0.0,false,false,true,{"slot":k})
	# The ambulatory, a bay at a time along the ring (s growing).
	var roof: Array = p["roof"]
	for k in range(SLOTS):
		var f := frame(slot_mid(k),OUT_IN+AMB*0.5)
		var lo := 3.0
		var hi := ROOF.x-1.5
		_opening(out,"colosseum/amb%d" % k,"ambulatory",f*Vector3(0.0,P+(lo+hi)*0.5,0.0),f.basis.x,Vector3(AMB-1.0,hi-lo,2.0),0.0,false,false,false,{"slot":k,"roofed":bool(roof[k])})
	# The arena along the long axis, skimmed; the trench and its two ends.
	var az := RZ-ARENA_D
	_opening(out,"colosseum/arena","arena",Vector3(0.0,P+6.0,0.0),Vector3.BACK,Vector3(TRENCH*2.0,10.0,az*2.0-8.0),0.0,false,false,true)
	# The trench is open overhead: flown with the wings under the arena's
	# floor, kept up off its own floor (low over the ground the flight
	# rides it, and a stepped floor is a crash).
	var ty := Vector2(4.0,P+1.0)
	_opening(out,"colosseum/trench","trench",Vector3(0.0,(ty.x+ty.y)*0.5,0.0),Vector3.BACK,Vector3(TRENCH,ty.y-ty.x,TRENCH_LANE*2.0),0.0,false,false,true)
	for sgn: float in [1.0,-1.0]:
		_opening(out,"colosseum/trench_%s" % ("n" if sgn > 0.0 else "s"),"trench",Vector3(0.0,(ty.x+ty.y)*0.5,sgn*(TRENCH_LANE-1.0)),Vector3.BACK,Vector3(TRENCH,ty.y-ty.x,2.0))
	# The broken side: over its lowest bays, inward; then the bowl.
	var bk := int(p["broken"])
	var bf := frame(slot_mid(bk),WALL_D)
	var low := _outer_high("stump")+2.0
	_opening(out,"colosseum/break","break",bf*Vector3(0.0,(low+P+30.0)*0.5,0.0),-bf.basis.z,Vector3(pitch()*3.0,P+30.0-low,WALL_D*2.0))
	_opening(out,"colosseum/bowl","bowl",Vector3(0.0,P+7.0,0.0),-bf.basis.z,Vector3(TRENCH*3.0,10.0,4.0))
	return out

static func _opening(out: Array, name: String, kind: String, centre: Vector3, way: Vector3, size: Vector3, head := 0.0, knife := false, round := false, lane := false, extra := {}) -> void:
	var z := way.normalized()
	var x := Vector3.UP.cross(z).normalized()
	var o := {"name":name,"kind":kind,"frame":Transform3D(Basis(x,Vector3.UP,z),centre),"size":size,"head":head,"knife":knife,"round":round,"lane":lane}
	o.merge(extra)
	out.append(o)

# --- The piece ------------------------------------------------------------------

static func piece(id: String, seed_value: int, weathered := 0.6) -> Node3D:
	if id == "colosseum": return colosseum(seed_value,weathered)
	return null

## The colosseum: see the file's head.
static func colosseum(seed_value: int, weathered := 0.6) -> Node3D:
	var t0 := Time.get_ticks_usec()
	var p := plan("colosseum",seed_value,weathered)
	var root := Node3D.new()
	root.name = "Colosseum"
	var stats := {"bays":{},"tris_bays":0,"tris_bay_growth":0}
	# The bays: each kind built once, drawn round the ring.
	var bays_node := Node3D.new()
	bays_node.name = "Bays"
	root.add_child(bays_node)
	var outer: Array = p["outer"]
	var inner: Array = p["inner"]
	var tops := {}
	var kinds := {}
	for k in range(SLOTS):
		for key: String in ["o:"+String(outer[k]),"i:"+String(inner[k])]:
			if not kinds.has(key): kinds[key] = []
			(kinds[key] as Array).append(k)
	for key: String in kinds:
		var slots: Array = kinds[key]
		var kind := key.substr(2)
		var made: Dictionary = _outer_bay(kind,seed_value,weathered) if key.begins_with("o:") else _inner_bay(kind,seed_value,weathered)
		tops[key] = made.top
		var xfs: Array = []
		for k: int in slots:
			var mid := slot_mid(k)
			var f: Transform3D
			if key.begins_with("o:"): f = frame(mid,WALL_D)
			else:
				f = frame(mid,INNER_MID)
				f.basis = f.basis*Basis.from_scale(Vector3(inner_scale(k),1.0,1.0))
			# Alternate bays a hair apart in height: where neighbours overlap,
			# their faces never fight.
			if k%2 == 1: f.origin.y += 0.02
			xfs.append(f)
		var n := _instances(bays_node,key,made.node,xfs)
		stats.bays[key] = [slots.size(),n.x,n.y]
		stats.tris_bays += n.x*slots.size()
		stats.tris_bay_growth += n.y*slots.size()
	stats["bays_ms"] = (Time.get_ticks_usec()-t0)/1000.0
	# The rest, laid on the ring.
	var b := Gothic._build(seed_value,weathered,"Colosseum")
	var extra: Array = []
	var bs := bands(p)
	_rings(b,p,bs,extra)
	_arena(b,p,extra)
	_rubble(b,p,extra)
	_dress_rings(b,p)
	var built := b.finish()
	for child in built.get_children():
		if child is MeshInstance3D:
			built.remove_child(child)
			root.add_child(child)
	built.free()
	stats["rings_ms"] = (Time.get_ticks_usec()-t0)/1000.0-float(stats.bays_ms)
	# The solid, from the plan.
	var c0 := Time.get_ticks_usec()
	var boxes := solid_boxes(p,tops,bs,extra)
	var body := StaticBody3D.new()
	body.name = "Body"
	for box: AABB in boxes:
		var cs := CollisionShape3D.new()
		var hull := ConvexPolygonShape3D.new()
		var h := box.size*0.5
		var pts := PackedVector3Array()
		for sx: float in [-1.0,1.0]:
			for sy: float in [-1.0,1.0]:
				for sz: float in [-1.0,1.0]: pts.append(Vector3(sx*h.x,sy*h.y,sz*h.z))
		hull.points = pts
		cs.shape = hull
		cs.position = box.get_center()
		body.add_child(cs)
	root.add_child(body)
	stats["boxes"] = boxes.size()
	stats["solid_ms"] = (Time.get_ticks_usec()-c0)/1000.0
	root.set_meta("openings",openings("colosseum",seed_value,weathered))
	root.set_meta("colosseum",p)
	var reach := STEP*STEPS
	root.set_meta("bounds",AABB(Vector3(-RX-reach-RUBBLE,-FOUND,-RZ-reach),Vector3((RX+reach+RUBBLE)*2.0,P+ATTIC+FOUND,(RZ+reach)*2.0)))
	GothicGrowth.far_off(root)
	if OS.get_thread_caller_id() == OS.get_main_thread_id(): realize(root)
	stats["build_ms"] = (Time.get_ticks_usec()-t0)/1000.0
	root.set_meta("stats",stats)
	return root

## Makes the bays' MultiMeshes under `node` from what `_instances` left
## (on the main thread: land_arches.gd calls it as it adds the piece).
static func realize(node: Node) -> void:
	for n in node.find_children("*","MultiMeshInstance3D",true,false):
		var inst := n as MultiMeshInstance3D
		if inst.multimesh != null or not inst.has_meta("mm_buffer"): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = inst.get_meta("mm_mesh")
		mm.instance_count = int(inst.get_meta("mm_count"))
		mm.buffer = inst.get_meta("mm_buffer")
		inst.multimesh = mm
		inst.remove_meta("mm_buffer")
		inst.remove_meta("mm_mesh")
		inst.remove_meta("mm_count")

## A bay's stone and growth as MultiMeshes under `parent`, an instance a
## transform of `xfs`. Answers one bay's (stone, growth) triangles.
static func _instances(parent: Node3D, key: String, node: Node3D, xfs: Array) -> Vector2i:
	var mi := node.get_node_or_null("Mesh") as MeshInstance3D
	var tris := Vector2i.ZERO
	if mi == null or mi.mesh == null:
		node.free()
		return tris
	var leveled := RuinLod.leveled_mesh(mi.mesh as ArrayMesh)
	var stone: ArrayMesh = leveled if leveled != null else mi.mesh as ArrayMesh
	if stone.has_meta("lods"):
		tris.x = int(stone.get_meta("lods").stone)
		tris.y = int(stone.get_meta("lods").growth)
	var meshes := [[stone,"Stone"]]
	if stone.has_meta("growth_mesh"): meshes.append([stone.get_meta("growth_mesh"),"Growth"])
	for pair: Array in meshes:
		var buf := PackedFloat32Array()
		buf.resize(xfs.size()*12)
		for i in range(xfs.size()):
			var f: Transform3D = xfs[i]
			var bs := f.basis
			var o := i*12
			buf[o] = bs.x.x
			buf[o+1] = bs.y.x
			buf[o+2] = bs.z.x
			buf[o+3] = f.origin.x
			buf[o+4] = bs.x.y
			buf[o+5] = bs.y.y
			buf[o+6] = bs.z.y
			buf[o+7] = f.origin.y
			buf[o+8] = bs.x.z
			buf[o+9] = bs.y.z
			buf[o+10] = bs.z.z
			buf[o+11] = f.origin.z
		# The MultiMesh itself is made on the main thread (`realize`): a
		# worker thread's MultiMesh RID can come out wrong.
		var inst := MultiMeshInstance3D.new()
		inst.name = "%s_%s" % [key.replace(":","_"),pair[1]]
		inst.set_meta("mm_mesh",pair[0])
		inst.set_meta("mm_buffer",buf)
		inst.set_meta("mm_count",xfs.size())
		if pair[1] == "Growth":
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			inst.visibility_range_end = GothicGrowth.FAR_GROWTH
			inst.visibility_range_end_margin = GothicGrowth.FAR_MARGIN
			inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(inst)
	node.free()
	return tris

# --- The bays ---------------------------------------------------------------------

## The hole of a bay's arches for `_courses`: `arches` [[w, sill, spring]]
## (over the foot, m), the ring left out round each.
static func _holes(arches: Array) -> Callable:
	return func(y: float) -> Vector2:
		for a: Array in arches:
			var h: float = float(a[0])*0.5
			if y < float(a[1]): continue
			if y < float(a[2]): return Vector2(0.0,h+RING)
			var w := RuinKit._arc_half(h,h,RING,y-float(a[2]))
			if w > 0.0: return Vector2(0.0,w)
		return Vector2(0.0,-1.0)

## Jambs up an arch's sides from `sill` to `spring`, none over `top`.
static func _jambs(b: Build, w: float, sill: float, spring: float, d: float, top: Callable) -> void:
	for s: float in [-1.0,1.0]:
		var y := sill
		var k := 0
		while y < spring-0.2:
			var hgt := minf(COURSE*b.rng.randf_range(0.8,1.2),spring-y)
			if spring-(y+hgt) < 0.6: hgt = spring-y
			var wide := RING*(1.0 if k%2 == 0 else 0.75)
			var x := s*(w*0.5+wide*0.5)
			if y+hgt > float(top.call(x))+0.2: break
			b.solid(RuinKit._box(b,Vector3(wide*0.5,hgt*0.5-0.01,d)),RuinKit._settle(b,Vector3(x,y+hgt*0.5,0.0),0.2),RuinKit._stone(b,1.03),false)
			y += hgt
			k += 1

## A round arch's head (its voussoirs, those over `top` fallen).
static func _round_head(b: Build, pose: Transform3D, w: float, spring: float, d: float, top: Callable, n := 9) -> void:
	var side := -1.0 if b.rng.randf() < 0.5 else 1.0
	RuinKit._ring_order(b,pose,0.0,spring,w*0.5,w*0.5,0.0,RING,d,n,99,side,RuinKit._stone(b,1.02),0,top)

## The arches' clear cores (the bay's frame), kept from the growth.
static func _clear(b: Build, arches: Array, d: float) -> void:
	for a: Array in arches:
		var h: float = float(a[0])*0.5+GothicGrowth.CORE_MARGIN
		var y0: float = float(a[1])
		var y1: float = float(a[2])+float(a[0])*0.5+GothicGrowth.CORE_MARGIN
		b.clear.append(AABB(Vector3(-h,y0,-d-GothicGrowth.CORE_DEPTH),Vector3(h*2.0,y1-y0,(d+GothicGrowth.CORE_DEPTH)*2.0)))

## An outer bay of `kind`, built in its own frame (x along the ring, the
## wall's middle on z 0, +z out): {node, top (Callable(x) -> its line)}.
static func _outer_bay(kind: String, seed_value: int, weathered: float) -> Dictionary:
	var b := Gothic._build(seed_value,weathered,"ColosseumBay_"+kind)
	var w := GATE_SLOT if kind == "gate" else pitch()
	var hw := w*0.5
	var whole := kind in ["whole","tight","blocked","gate"]
	var top: Callable = RuinKit._ruin_line(b,-hw,hw,_outer_low(kind),_outer_high(kind),weathered*(0.3 if whole else 1.0))
	var arches: Array = []
	var aw := _arch_w(kind)
	if kind == "gate":
		arches.append([GATE,P,P+GATE_SPRING])
		var t3: Vector3 = TIERS[2]
		arches.append([ARCH,P+t3.x,P+t3.y])
	else:
		for t in range(3):
			var tier: Vector3 = TIERS[t]
			if kind == "blocked" and t == 0: continue
			arches.append([aw,P+tier.x,P+tier.y])
	RuinKit._courses(b,Transform3D.IDENTITY,-hw,hw,P-1.0,top,WALL_D,_holes(arches),COURSE)
	for a: Array in arches:
		_jambs(b,float(a[0]),float(a[1]),float(a[2]),WALL_D,top)
		_round_head(b,Transform3D.IDENTITY,float(a[0]),float(a[2]),WALL_D,top,11 if float(a[0]) > 8.0 else 9)
	if kind == "blocked":
		# Its first arch walled up to about its springing, set back, its
		# ring standing over the walling.
		var t1: Vector3 = TIERS[0]
		var fill := RuinKit._ruin_line(b,-aw*0.5-RING,aw*0.5+RING,P+t1.y-1.2,P+t1.y,0.8)
		RuinKit._courses(b,Transform3D.IDENTITY,-aw*0.5-RING*0.5,aw*0.5+RING*0.5,P-1.0,fill,WALL_D*0.55,Callable(),COURSE)
		_round_head(b,Transform3D.IDENTITY,aw,P+t1.y,WALL_D,top)
	# The outer face: an engaged column at the bay's edge each tier and a
	# cornice over each tier.
	var floors := [P,P+(TIERS[0] as Vector3).z,P+(TIERS[1] as Vector3).z]
	for t in range(3):
		var tier: Vector3 = TIERS[t]
		var y0: float = floors[t]
		var y1 := P+tier.z-1.0
		var yt := minf(y1,float(top.call(hw-0.4))-0.3)
		if yt > y0+1.0:
			b.solid(RuinKit._prism(8,0.72,0.64,y0,yt,PI/8.0),Transform3D(Basis.IDENTITY,Vector3(hw,0.0,WALL_D+0.15)),RuinKit._stone(b,0.97),false)
			if yt >= y1-0.01: b.solid(RuinKit._box(b,Vector3(0.85,0.3,0.55)),Transform3D(Basis.IDENTITY,Vector3(hw,y1-0.3,WALL_D+0.3)),RuinKit._stone(b,1.0),false)
		for half: float in [-1.0,1.0]:
			var mx := half*hw*0.5
			if float(top.call(mx)) < P+tier.z+0.1: continue
			b.solid(RuinKit._box(b,Vector3(hw*0.5+0.02,0.4,0.42)),RuinKit._settle(b,Vector3(mx,P+tier.z-0.6,WALL_D+0.2),0.2),RuinKit._stone(b,1.05),false)
	# The attic's crown and its flat pilaster.
	if whole:
		for half: float in [-1.0,1.0]:
			var mx := half*hw*0.5
			if float(top.call(mx)) >= P+ATTIC-0.6:
				b.solid(RuinKit._box(b,Vector3(hw*0.5+0.02,0.35,0.5)),RuinKit._settle(b,Vector3(mx,P+ATTIC-1.3,WALL_D+0.2),0.2),RuinKit._stone(b,1.06),false)
		b.solid(RuinKit._box(b,Vector3(0.7,3.6,0.22)),Transform3D(Basis.IDENTITY,Vector3(hw,P+(TIERS[2] as Vector3).z+4.0,WALL_D+0.15)),RuinKit._stone(b,0.98),false)
	_clear(b,arches,WALL_D)
	_dress_bay(b,"outer",P+6.0,WALL_D)
	return {"node":b.finish(),"top":top}

## An inner bay of `kind` (its frame as the outer's, the ambulatory on its
## +z side), built at the ring's nominal shrink.
static func _inner_bay(kind: String, seed_value: int, weathered: float) -> Dictionary:
	var b := Gothic._build(seed_value,weathered,"ColosseumInner_"+kind)
	var nom := _inner_nominal()
	var w := (GATE_SLOT if kind == "gate" else pitch())*nom
	var hw := w*0.5
	var high := P+ROOF.y+1.0
	var top: Callable = RuinKit._ruin_line(b,-hw,hw,high-0.8,high,0.3)
	if kind == "low": top = RuinKit._ruin_line(b,-hw,hw,P+7.0,P+15.0,1.0)
	var arches: Array = []
	var aw := _pass_hole()
	match kind:
		"gate": arches.append([GATE,P,P+GATE_SPRING])
		"pass1": arches.append([aw,P,P+(TIERS[0] as Vector3).y])
		"pass2": arches.append([aw,P+(TIERS[1] as Vector3).x,P+(TIERS[1] as Vector3).y])
	RuinKit._courses(b,Transform3D.IDENTITY,-hw,hw,P-1.0,top,INNER_D,_holes(arches),COURSE)
	for a: Array in arches:
		_jambs(b,float(a[0]),float(a[1]),float(a[2]),INNER_D,top)
		_round_head(b,Transform3D.IDENTITY,float(a[0]),float(a[2]),INNER_D,top)
	if kind == "pass1":
		# Walled up to its crown, set back from both faces, its ring and
		# jambs standing round the walling.
		var r := aw*0.5
		var spring := P+(TIERS[0] as Vector3).y
		var fill := func(x: float) -> float: return spring+sqrt(maxf(r*r-x*x,0.0))+0.3
		RuinKit._courses(b,Transform3D.IDENTITY,-r-0.2,r+0.2,P-1.0,fill,INNER_D*0.6,Callable(),COURSE)
	# Blind arcading on the ambulatory's face: rings proud of the wall on
	# the tiers no passage pierces, a pilaster at the bay's edge.
	for t in range(2):
		var tier: Vector3 = TIERS[t]
		var pierced := (kind == "pass1" and t == 0) or (kind == "pass2" and t == 1) or kind == "gate"
		if pierced or P+tier.y+aw*0.5 > float(top.call(0.0)): continue
		RuinKit._ring_order(b,Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,INNER_D+0.12)),0.0,P+tier.y,aw*0.5,aw*0.5,0.0,0.7,0.16,7,99,1.0,RuinKit._stone(b,1.04),0,top)
	var pil := minf(P+ROOF.x-0.8,float(top.call(hw))-0.3)
	if pil > P+2.0: b.solid(RuinKit._box(b,Vector3(0.55,(pil-P+1.0)*0.5,0.18)),Transform3D(Basis.IDENTITY,Vector3(hw,(pil+P-1.0)*0.5,INNER_D+0.12)),RuinKit._stone(b,0.98),false)
	_clear(b,arches,INNER_D)
	_dress_bay(b,"inner",P+4.0,INNER_D)
	return {"node":b.finish(),"top":top}

## A bay's growth: ivy off its cornices and wall head, curtains under its
## outer cornices, mats on its ledges, low at its foot.
static func _dress_bay(b: Build, label: String, low_y: float, d: float) -> void:
	var dens := GothicGrowth.density(b)
	if dens <= 0.0: return
	var x := GothicGrowth.Dress.new(b,"colosseum_"+label,dens)
	if RuinGrowth.vines:
		x.section("cascades")
		GothicGrowth.cascades(x,P+8.0,P+ATTIC+2.0,3,Vector2(4.0,13.0),5,GothicGrowth.COARSE_MID,0.5,0.3,true)
		x.section("curtains")
		for i in range(2):
			var at := Vector3(b.rng.randf_range(-3.0,3.0),0.0,d+0.45)
			var tier: Vector3 = TIERS[b.rng.randi_range(0,2)]
			GothicGrowth.curtain(x,at,P+tier.z-2.0,P+tier.z+0.5,b.rng.randf_range(3.0,7.0),5,GothicGrowth.COARSE_MID,true)
	x.section("mats")
	GothicGrowth.mats(x,P+8.0,P+ATTIC+2.0,3,0.3,Vector2i(1,3),3.0)
	x.section("low")
	GothicGrowth.low(x,2,low_y)
	x.done()

# --- The rings: plinth, floors, walkway, seats -------------------------------------

## A convex block over the quad `q` (XZ corners, in order round) from `y0`
## to `y1` (the piece's frame), drawn, not solid (the solid comes from the
## plan).
static func _quad(b: Build, q: Array, y0: float, y1: float, tone := 1.0, wear := true, slope := 0.0) -> void:
	var c := Vector3.ZERO
	for v: Vector3 in q: c += v
	c /= q.size()
	c.y = 0.0
	var mid := (y0+y1)*0.5
	# `slope`: the top rising dy/dz through y1 at the middle.
	var up := Vector3(0.0,1.0,-slope)
	var planes: Array[Plane] = [Plane(up.normalized(),(y1-mid)/up.length()),Plane(Vector3.DOWN,mid-y0)]
	for i in range(q.size()):
		var a: Vector3 = q[i]
		var e: Vector3 = q[(i+1)%q.size()]
		var n := Vector3(e.z-a.z,0.0,a.x-e.x)
		if n.length() < 0.001: continue
		n = n.normalized()
		if n.dot(c-Vector3(a.x,0.0,a.z)) > 0.0: n = -n
		planes.append(Plane(n,n.dot(Vector3(a.x,0.0,a.z)-c)))
	b.solid(planes,Transform3D(Basis.IDENTITY,Vector3(c.x,mid,c.z)),RuinKit._stone(b,tone),false,wear)

## The quad on the ring from arc `s0` to `s1`, `d0` to `d1` inward.
static func _ring_quad(s0: float, s1: float, d0: float, d1: float) -> Array:
	return [point(s0,d0),point(s1,d0),point(s1,d1),point(s0,d1)]

## Slot `k`'s pieces along the ring (s ranges, none over ~`most` m at
## depth `d`).
static func _pieces(k: int, d: float, most := 9.0) -> Array:
	var e := slot_edges(k)
	var shrink := maxf(1.0-kappa(phi_of((e.x+e.y)*0.5))*d,0.15)
	var n := maxi(1,int(ceil((e.y-e.x)*shrink/most)))
	var out: Array = []
	for i in range(n): out.append(Vector2(lerpf(e.x,e.y,float(i)/n),lerpf(e.x,e.y,float(i+1)/n)))
	return out

## The seats' tread `i`'s top over the foot.
static func tread_top(i: int) -> float:
	return P+ROOF.y-RISE*i

static func _rings(b: Build, p: Dictionary, bs: Array, extra: Array) -> void:
	var roof: Array = p["roof"]
	var cap: Array = p["cap"]
	for k in range(SLOTS):
		# The plinth's steps (under the rubble slope where the wall fell).
		for st in range(STEPS):
			var d0 := -STEP*(st+1)
			var d1 := -STEP*st+0.3
			var y1 := P*(STEPS-st)/float(STEPS)
			for pc: Vector2 in _pieces(k,d0): _quad(b,_ring_quad(pc.x,pc.y,d0,d1),-FOUND,y1,0.95)
		# The ambulatory's floor and, where it stands, the walkway over it.
		for pc: Vector2 in _pieces(k,OUT_IN):
			_quad(b,_ring_quad(pc.x,pc.y,OUT_IN-0.3,INNER_MID),P-1.2,P,0.9,false)
			if bool(roof[k]): _quad(b,_ring_quad(pc.x,pc.y,OUT_IN-0.4,INNER_MID),P+ROOF.x,P+ROOF.y,1.0)
		# The seats, tread by tread: over the bay's fall a rough fill to its
		# line, through a passage its cut or vault. Near a passage, in short
		# pieces, each judged by its middle.
		var near := false
		var at := point(slot_mid(k),INNER_IN)
		for bd: Dictionary in bs:
			if (bd.o as Vector3).distance_to(at) < 55.0: near = true
		var lost := float(cap[k])+P
		for i in range(TREADS):
			var d0 := INNER_IN+TREAD*i-0.15
			var d1 := INNER_IN+TREAD*(i+1)
			var y1 := tread_top(i)
			var y0 := y1-2.6 if i < TREADS-1 else P-1.0
			for pc: Vector2 in _pieces(k,(d0+d1)*0.5,1.4 if near else 9.0):
				var q := _ring_quad(pc.x,pc.y,d0,d1)
				var top := minf(y1,lost)
				var lo := y0
				if near:
					var m := point((pc.x+pc.y)*0.5,(d0+d1)*0.5)
					var bd := band_at(bs,m.x,m.z)
					if not bd.is_empty():
						var lv := band_level(bd)
						if String(bd.kind) == "pass2": _quad(b,q,minf(y0,lv-2.0),minf(lv,top),0.92)
						elif top > lv+1.5: _quad(b,q,lv,top,0.97)
						# A great gate's passage: the trench's ramp its floor.
						if String(bd.kind) == "gate": _quad(b,q,-1.0,_trench_floor(absf(m.z)),0.88,true,_ramp_slope(m.z))
						continue
					# Beside a gate's passage the seats are walls to the ramp.
					if _by_gate_way(bs,m.x,m.z): lo = -1.0
				if y1 > lost:
					# Fallen: a rough fill to the bay's line, stones on it.
					if lost > lo+0.5:
						_quad(b,q,lo,lost,0.88)
						if b.rng.randf() < 0.35: extra.append(_boulder(b,(q[0]+q[2])*0.5+Vector3.UP*lost,b.rng.randf_range(0.8,1.6)))
					continue
				_quad(b,q,lo,y1,1.0+0.04*(i%2))

## A tumbled boulder on `at` (y its ground): drawn, its box (the piece's
## frame) for the solid.
static func _boulder(b: Build, at: Vector3, size: float) -> AABB:
	var s := Vector3(b.rng.randf_range(0.6,1.0),b.rng.randf_range(0.45,0.8),b.rng.randf_range(0.6,1.0))*size*0.5
	var basis := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.35,0.35))
	var pose := Transform3D(basis,at+Vector3.UP*(s.y*0.8))
	b.solid(RuinKit._box(b,s),pose,RuinKit._stone(b,0.93),false,true,[],-1,2.0)
	return GothicGrowth.box_of(pose,s)

# --- The arena ---------------------------------------------------------------------

static func _arena(b: Build, p: Dictionary, extra: Array) -> void:
	var fallen: Dictionary = p["fallen"]
	var walls: Dictionary = p["wall_top"]
	var h := TRENCH*0.5
	for key: Vector2i in _arena_squares():
		var box := _square_box(key)
		var c := box.get_center()
		var q := _box_quad(box)
		if not fallen.has(key):
			_quad(b,q,P-0.8,P,0.96)
			# Its faces onto a fallen neighbour: the hypogeum's walls.
			for nb: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				if not fallen.has(key+nb): continue
				var face: AABB
				if nb.x != 0:
					var x := box.end.x-0.6 if nb.x > 0 else box.position.x
					face = AABB(Vector3(x,-1.0,box.position.z),Vector3(0.6,P-0.8+1.0,SQUARE))
				else:
					var z := box.end.z-0.6 if nb.y > 0 else box.position.z
					face = AABB(Vector3(box.position.x,-1.0,z),Vector3(box.size.x,P-0.8+1.0,0.6))
				_quad(b,_box_quad(face),face.position.y,face.end.y,0.9)
			continue
		if absf(c.x) < h:
			# The trench: its floor, rising at its ends in a ramp of fallen floor.
			var az := absf(c.z)
			if az+SQUARE*0.5 <= RAMP_AT: _quad(b,q,-1.0,0.4,0.9,false)
			else:
				# A sloped slab (a stepped one's risers are walls to a low pass).
				var y := _trench_floor(az)
				var sz := signf(c.z)
				var g := sz*(_trench_floor(az+SQUARE*0.5)-_trench_floor(maxf(az-SQUARE*0.5,0.0)))/SQUARE
				_quad(b,q,-1.0,y,0.86,true,g)
				# (Its boulders only off the flown middle.)
				if absf(c.x) > 3.0 and b.rng.randf() < 0.5: extra.append(_boulder(b,Vector3(c.x+b.rng.randf_range(-1.0,1.0),y,c.z),b.rng.randf_range(0.7,1.3)))
			continue
		# A side cell: its floor, a cross wall over its middle, the trench's
		# low wall along its inner edge.
		_quad(b,q,-1.0,0.4,0.9,false)
		var wt: float = walls[key]
		var cw := AABB(Vector3(box.position.x,-1.0,c.z-0.5),Vector3(box.size.x,wt-0.6+1.0,1.0))
		_quad(b,_box_quad(cw),cw.position.y,cw.end.y,0.94)
		if key.x == 1 or key.x == -2:
			var lw := AABB(Vector3(h if c.x > 0.0 else -h-1.2,-1.0,box.position.z),Vector3(1.2,wt+1.0,SQUARE))
			_quad(b,_box_quad(lw),lw.position.y,lw.end.y,0.92)

static func _box_quad(a: AABB) -> Array:
	return [Vector3(a.position.x,0,a.position.z),Vector3(a.end.x,0,a.position.z),Vector3(a.end.x,0,a.end.z),Vector3(a.position.x,0,a.end.z)]

## The trench floor's height `az` from the arena's middle along it: flat,
## then a ramp of fallen floor from RAMP_AT on through the arena's end and
## under a great gate's passage to the podium at the inner wall's face.
static func _trench_floor(az: float) -> float:
	if az <= RAMP_AT: return 0.4
	return lerpf(0.4,P,clampf((az-RAMP_AT)/(RZ-INNER_IN-RAMP_AT),0.0,1.0))

## The ramp's rise along z (dy/dz) at `z`, for a sloped slab.
static func _ramp_slope(z: float) -> float:
	if absf(z) <= RAMP_AT or absf(z) >= RZ-INNER_IN: return 0.0
	return signf(z)*(P-0.4)/(RZ-INNER_IN-RAMP_AT)

## Whether (x, z) is under the seats beside a great gate's passage, where
## the seats are drawn solid down to the ramp's foot (its side walls).
static func _by_gate_way(bs: Array, x: float, z: float) -> bool:
	for bd: Dictionary in bs:
		if String(bd.kind) != "gate": continue
		var o: Vector3 = bd.o
		var dir: Vector3 = bd.dir
		var along := (x-o.x)*dir.x+(z-o.z)*dir.z
		if along < -1.0 or along > float(bd.len)+1.0: continue
		if absf((x-o.x)*dir.z-(z-o.z)*dir.x) < float(bd.half)+3.0: return true
	return false

# --- The rubble ----------------------------------------------------------------------

## The rubble slope's top outside slot `k` at `d` (< 0), or -INF.
static func rubble_top(p: Dictionary, k: int, d: float) -> float:
	var f := float((p["fall"] as Array)[k])
	if f < 0.1: return -INF
	var reach := RUBBLE*f
	if d < -reach: return -INF
	var high := P+6.0*f
	return high-(high+1.0)*(-d/reach)

static func _rubble(b: Build, p: Dictionary, extra: Array) -> void:
	var fall: Array = p["fall"]
	for k in range(SLOTS):
		var f := float(fall[k])
		if f < 0.1: continue
		var reach := RUBBLE*f
		var n := 4
		for j in range(n):
			var d0 := -reach*(j+1)/n
			var d1 := -reach*j/n+(0.8 if j == 0 else 0.0)
			var y := rubble_top(p,k,(d0+d1)*0.5)
			if y <= -FOUND+0.5: continue
			for pc: Vector2 in _pieces(k,d0): _quad(b,_ring_quad(pc.x,pc.y,d0,d1),-FOUND,y,0.88)
		for i in range(int(4+8*f)):
			var s := slot_mid(k)+b.rng.randf_range(-0.5,0.5)*pitch()
			var d := -b.rng.randf()*reach*0.9
			var at := point(s,d)
			extra.append(_boulder(b,Vector3(at.x,rubble_top(p,k,d)-0.3,at.z),b.rng.randf_range(1.2,2.6)))
		# Drifts in the ambulatory behind it, kept low.
		for i in range(int(3*f)):
			var at := point(slot_mid(k)+b.rng.randf_range(-0.4,0.4)*pitch(),OUT_IN+b.rng.randf_range(1.0,3.0))
			extra.append(_boulder(b,Vector3(at.x,P,at.z),b.rng.randf_range(0.8,1.4)))

## The rings' growth: ivy down the risers, curtains under the walkway's
## edge, mats on the treads and rubble, low tufts; the flown ways kept clear.
static func _dress_rings(b: Build, p: Dictionary) -> void:
	for o: Dictionary in openings("colosseum",int(p["seed"]),float(p["weathered"])):
		if not String(o.kind) in ["ambulatory","trench","tunnel","gate_way","gate","arena"]: continue
		var half: Vector3 = (o.size as Vector3)*0.5+Vector3(GothicGrowth.CORE_MARGIN*0.6,GothicGrowth.CORE_MARGIN*0.6,0.3)
		b.clear.append(GothicGrowth.box_of(o.frame,half))
	var d := GothicGrowth.density(b)
	if d <= 0.0: return
	var x := GothicGrowth.Dress.new(b,"colosseum_rings",d)
	if RuinGrowth.vines:
		x.section("risers")
		GothicGrowth.cascades(x,P+4.0,P+ROOF.y+1.5,60,Vector2(1.5,3.5),4,GothicGrowth.COARSE_FAR,0.5,1.0,false)
		x.section("walkway")
		for i in range(26):
			var k := b.rng.randi_range(0,SLOTS-1)
			if not bool((p["roof"] as Array)[k]): continue
			var at := point(slot_mid(k)+b.rng.randf_range(-3.0,3.0),INNER_MID-0.8)
			GothicGrowth.curtain(x,Vector3(at.x,0.0,at.z),P+ROOF.x-1.0,P+ROOF.y,b.rng.randf_range(2.0,5.0),5,GothicGrowth.COARSE_MID,true)
	x.section("mats")
	GothicGrowth.mats(x,P+1.0,P+ROOF.y+1.5,50,0.5,Vector2i(2,4),3.4)
	x.section("low")
	GothicGrowth.low(x,30,P+7.0)
	x.done()

# --- The solid ---------------------------------------------------------------------

## The solid's vertical stretches (y0, y1 pairs over the foot) at (x, z),
## (s, d) `sd` there: the plinth and rubble, the walls with their arches cut
## out (`tops` the bays' lines by kind, "o:whole" ...), the walkway, the
## seats with their passages (`bs`), the arena and its fallen squares.
static func column(p: Dictionary, tops: Dictionary, bs: Array, x: float, z: float, sd: Vector2) -> PackedFloat32Array:
	var s := sd.x
	var d := sd.y
	var out := PackedFloat32Array()
	if d < -RUBBLE-1.0: return out
	var k := slot_of(s)
	if d < 0.0:
		var top := -INF
		var st := int(floor(-d/STEP))
		if st < STEPS: top = P*(STEPS-st)/float(STEPS)
		top = maxf(top,rubble_top(p,k,d))
		if top > -INF: out.append_array([-FOUND,_q(top)])
		return out
	var kap := kappa(phi_of(s))
	if d < OUT_IN:
		var kind := String((p["outer"] as Array)[k])
		var lx := off_slot(s,k)*(1.0-kap*WALL_D)
		var hw := (GATE_SLOT if kind == "gate" else pitch())*0.5
		var top := float((tops["o:"+kind] as Callable).call(clampf(lx,-hw,hw)))
		var holes: Array = []
		if kind == "gate":
			holes.append([GATE,P,P+GATE_SPRING])
			holes.append([ARCH,P+(TIERS[2] as Vector3).x,P+(TIERS[2] as Vector3).y])
		else:
			for t in range(3):
				var tier: Vector3 = TIERS[t]
				if kind == "blocked" and t == 0:
					holes.append([ARCH,P+tier.y,P+tier.y])
					continue
				holes.append([_arch_w(kind),P+tier.x,P+tier.y])
		return _cut_holes(-FOUND,_q(top),lx,holes)
	if d < INNER_MID-INNER_D:
		out.append_array([-FOUND,P])
		if bool((p["roof"] as Array)[k]): out.append_array([P+ROOF.x,P+ROOF.y])
		return out
	if d < INNER_IN:
		var kind := String((p["inner"] as Array)[k])
		var nom := _inner_nominal()
		var lx := off_slot(s,k)*(1.0-kap*INNER_MID)/inner_scale(k)
		var hw := (GATE_SLOT if kind == "gate" else pitch())*nom*0.5
		var top := float((tops["i:"+kind] as Callable).call(clampf(lx,-hw,hw)))
		var holes: Array = []
		var aw := _pass_hole()
		match kind:
			"gate": holes.append([GATE,P,P+GATE_SPRING])
			"pass2": holes.append([aw,P+(TIERS[1] as Vector3).x,P+(TIERS[1] as Vector3).y])
		# The world's arch is the nominal one scaled: cut at the unscaled x.
		return _cut_holes(-FOUND,_q(top),lx,holes)
	if d < ARENA_D:
		var i := clampi(int((d-INNER_IN)/TREAD),0,TREADS-1)
		var h := minf(tread_top(i),float((p["cap"] as Array)[k])+P)
		var bd := band_at(bs,x,z)
		if not bd.is_empty():
			var lv := band_level(bd)
			if String(bd.kind) == "pass2":
				out.append_array([-FOUND,_q(minf(h,lv))])
				return out
			out.append_array([-FOUND,_q(_trench_floor(absf(z))) if String(bd.kind) == "gate" else P])
			if h > lv+1.5: out.append_array([_q(lv),_q(h)])
			return out
		out.append_array([-FOUND,_q(h)])
		return out
	# The arena.
	var key := _square_of(x,z)
	var fallen: Dictionary = p["fallen"]
	if not fallen.has(key):
		out.append_array([-FOUND,P])
		return out
	var box := _square_box(key)
	var c := box.get_center()
	if absf(c.x) < TRENCH*0.5:
		out.append_array([-FOUND,_q(0.4 if absf(c.z)+SQUARE*0.5 <= RAMP_AT else _trench_floor(absf(z)))])
		return out
	var wt: float = (p["wall_top"] as Dictionary)[key]
	if (key.x == 1 or key.x == -2) and absf(x) < TRENCH*0.5+1.2: out.append_array([-FOUND,_q(wt)])
	elif absf(z-c.z) < 0.5: out.append_array([-FOUND,_q(wt-0.6)])
	else: out.append_array([-FOUND,0.4])
	return out

## A height for the solid, stepped so neighbouring columns merge.
static func _q(y: float) -> float:
	return snappedf(y,0.25)

## The stretch [y0, y1] less the holes [[w, sill, spring]] (round heads) at
## `lx` across the bay.
static func _cut_holes(y0: float, y1: float, lx: float, holes: Array) -> PackedFloat32Array:
	var spans: Array = [Vector2(y0,y1)]
	for hl: Array in holes:
		var r: float = float(hl[0])*0.5
		if absf(lx) >= r: continue
		var lo: float = float(hl[1])
		var hi: float = _q(float(hl[2])+sqrt(maxf(r*r-lx*lx,0.0))-0.12)
		if hi <= lo: continue
		var next: Array = []
		for sp: Vector2 in spans:
			if hi <= sp.x or lo >= sp.y:
				next.append(sp)
				continue
			if lo > sp.x: next.append(Vector2(sp.x,lo))
			if hi < sp.y: next.append(Vector2(hi,sp.y))
		spans = next
	var out := PackedFloat32Array()
	for sp: Vector2 in spans:
		if sp.y-sp.x > 0.05: out.append_array([sp.x,sp.y])
	return out

## The grid's (s, d) at each cell's middle, seed-free, made once.
static var _grid: Dictionary = {}
static var _grid_lock := Mutex.new()

static func _sd_grid() -> Dictionary:
	_grid_lock.lock()
	if _grid.is_empty():
		var reach := STEP*STEPS+2.0
		var x0 := -RX-RUBBLE-2.0
		var z0 := -RZ-reach
		var nx := int(ceil((RX+RUBBLE+2.0)*2.0/CELL))
		var nz := int(ceil((RZ+reach)*2.0/CELL))
		var sd := PackedVector2Array()
		sd.resize(nx*nz)
		var fine := {}
		for j in range(nz):
			for i in range(nx):
				var v := nearest(x0+(i+0.5)*CELL,z0+(j+0.5)*CELL)
				sd[j*nx+i] = v
				if _walls_near(v.y):
					var sub := PackedVector2Array()
					for fj in range(2):
						for fi in range(2): sub.append(nearest(x0+i*CELL+(fi+0.5)*FINE,z0+j*CELL+(fj+0.5)*FINE))
					fine[j*nx+i] = sub
		_grid = {"x0":x0,"z0":z0,"nx":nx,"nz":nz,"sd":sd,"fine":fine}
	_grid_lock.unlock()
	return _grid

## Whether a cell at depth `d` is by a wall, so wants the finer cells.
static func _walls_near(d: float) -> bool:
	return (d > -1.2 and d < OUT_IN+1.2) or (d > INNER_MID-INNER_D-1.2 and d < INNER_IN+1.2)

## The solid as boxes (the piece's frame): columns on the grid merged along
## x, then along z, and `extra` (the boulders) with them.
static func solid_boxes(p: Dictionary, tops: Dictionary, bs: Array, extra: Array) -> Array:
	var g := _sd_grid()
	var nx: int = g.nx
	var nz: int = g.nz
	var x0: float = g.x0
	var z0: float = g.z0
	var sd: PackedVector2Array = g.sd
	var fine: Dictionary = g.fine
	var coarse := {}
	var boxes: Array = []
	var open := {}
	for r in range(nz*2+1):
		var z := z0+r*FINE
		var now := {}
		if r < nz*2:
			var j := r/2
			var runs: Array = []
			var zc := z0+j*CELL+((r%2)+0.5)*FINE
			for i in range(nx):
				var idx := j*nx+i
				if fine.has(idx):
					var sub: PackedVector2Array = fine[idx]
					for fi in range(2):
						_run(runs,x0+i*CELL+fi*FINE,FINE,column(p,tops,bs,x0+i*CELL+(fi+0.5)*FINE,zc,sub[(r%2)*2+fi]))
				else:
					var col: PackedFloat32Array
					if coarse.has(idx): col = coarse[idx]
					else:
						col = column(p,tops,bs,x0+(i+0.5)*CELL,z0+(j+0.5)*CELL,sd[idx])
						coarse[idx] = col
					_run(runs,x0+i*CELL,CELL,col)
			for run: Array in runs:
				if (run[2] as PackedFloat32Array).is_empty(): continue
				now["%.2f|%.2f|%s" % [run[0],run[1],str(run[2])]] = run
		# A run carried on down z while the next row has its twin; ended,
		# its stretches become boxes.
		for key: String in open:
			if now.has(key): continue
			var o: Array = open[key]
			var run: Array = o[0]
			var cols: PackedFloat32Array = run[2]
			for m in range(0,cols.size(),2):
				boxes.append(AABB(Vector3(run[0],cols[m],o[1]),Vector3(float(run[1])-float(run[0]),cols[m+1]-cols[m],z-float(o[1]))))
		var next := {}
		for key: String in now: next[key] = open[key] if open.has(key) else [now[key],z]
		open = next
	for a: AABB in extra: boxes.append(a)
	return boxes

## Adds a cell (from `x`, `w` wide, stretches `col`) to a row's runs.
static func _run(runs: Array, x: float, w: float, col: PackedFloat32Array) -> void:
	if not runs.is_empty():
		var last: Array = runs[runs.size()-1]
		if absf(float(last[1])-x) < 0.001 and last[2] == col:
			last[1] = x+w
			return
	runs.append([x,x+w,col])
