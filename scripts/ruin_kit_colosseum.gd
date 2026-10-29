extends RefCounted
## The ruin kit's abandoned colosseum (`colosseum`), a set piece standing on
## its own in the amberlands (scripts/endless/set_plan.gd), built with the
## kit's Build and the gothic pieces' mossed stone and thick growth
## (scripts/ruin_kit_gothic.gd, scripts/gothic_growth.gd).
##
## An elliptical amphitheatre RX*2 by RZ*2 m (320 x 380) over its outer
## wall, its long axis along Z, on a podium P m high (stepped down outside):
## - the outer wall: SLOTS bays round the ellipse, each three arched tiers
##   (an engaged column and a cornice a tier on the outer face) and a solid
##   attic, to ATTIC over the podium (100 m over the foot). The two bays on
##   the long axis are the great gates. Some bays' lower arch is walled up,
##   a few are tighter on purpose (TOY_TIGHT), some have lost their attic;
## - the ambulatory: a ring corridor AMB wide and ROOF.x tall inside the
##   outer wall, roofed by the top walkway in most bays, flown as a lap;
## - the inner wall: blind arcading; at every eighth bay a first-tier
##   passage open (a tunnel under the seats to the arena, flown since the
##   colosseum grew to K: walled up at its first size, too tight), four
##   bays on a second-tier one (a vomitorium cut through the upper seats to
##   the bowl), and the great gates' inner arches;
## - in the arena (`_arena_works`): a row of free-standing arches over the
##   trench along the long axis (the spina), and an aqueduct striding
##   across the bowl on the short axis, its arches flown under, one end
##   fallen;
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

## The scale: every length here against the first colosseum's (160 x 190 m,
## 50 m tall, 2026-10-27), its openings' toy widths and its blocks too, so
## it stands K times as large and its arches open K times as wide.
const K := 2.0

## Toy widths (the flown openings, scripts/world_scale.gd): the arcade's
## arches, the tight ones, the great gates, the ambulatory and the trench.
const TOY_ARCH := 3.2
const TOY_TIGHT := 2.7
const TOY_GATE := 5.0
const TOY_AMB := 7.0
const TOY_TRENCH := 5.5
## The inner wall's passages (to the arena, up to the bowl).
const TOY_PASS := 2.9
static var ARCH: float = WorldScale.opening(TOY_ARCH*K)
static var TIGHT: float = WorldScale.opening(TOY_TIGHT*K)
static var GATE: float = WorldScale.opening(TOY_GATE*K)
static var AMB: float = WorldScale.opening(TOY_AMB*K)
static var TRENCH: float = WorldScale.opening(TOY_TRENCH*K)
static var PASS: float = WorldScale.opening(TOY_PASS*K)

## The outer ellipse's semi-axes (m): across (x) and along (z).
const RX := 80.0*K
const RZ := 95.0*K
## Bays round the ring; the gate bays' width along the ring (m).
const SLOTS := 64
const GATE_SLOT := 17.0*K
## The podium: the arena's and the ambulatory's floor over the foot (m),
## and how far below the foot the plinth reaches (uneven ground).
const P := 8.0*K
const FOUND := 8.0*K
## The outer wall's and the inner wall's half thickness (m).
const WALL_D := 1.3*K
const INNER_D := 1.2*K
## The tiers over the podium: (sill, springing, top) each (m).
const TIERS := [Vector3(0.0,6.6,11.5)*K,Vector3(12.3,18.2,23.0)*K,Vector3(23.8,29.4,34.0)*K]
const ATTIC := 42.0*K
## The ambulatory's roof (the walkway): underside, top, over the podium.
const ROOF := Vector2(22.0,23.5)*K
## The great gates' springing over the podium.
const GATE_SPRING := 11.0*K
## The voussoir ring's depth (m), the walling's course (m).
const RING := 1.0*K
const COURSE := 2.0*K
## The seats: rings stepping down from the walkway, each TREAD deep and
## RISE lower than the last.
const TREADS := 10
const TREAD := 3.4*K
const RISE := 1.9*K
## The plinth's steps outside the wall: their depth (m) and count.
const STEP := 2.7*K
const STEPS := 3
## The arena's floor squares (m), the fallen region's half length (z),
## where the trench's ramps start along it, its flown lane's half length.
## The ramps run on under the great gates' passages to the podium at the
## inner wall (`_trench_floor`), so the climb out has no floor edge.
const SQUARE := 3.5*K
const FALL_Z := 42.0*K
const RAMP_AT := 26.0*K
const TRENCH_LANE := 12.0*K
## The broken side: bays either way of its middle that fall, the rubble
## slope's reach outside the wall at its deepest (m).
const BREAK_HALF := 7.5
const RUBBLE := 30.0*K
## The arena's works (`works`). The spina: arches standing over the trench
## along the long axis at SPINA_Z (m from the middle), each SPINA clear
## (from its toy width), its piers SPINA_PIER wide, SPINA_D half thick,
## springing SPINA_SPRING over the podium, its head between SPINA_TOP.
const TOY_SPINA := 6.5
static var SPINA: float = WorldScale.opening(TOY_SPINA*K)
const SPINA_Z := [-30.0*K,-12.0*K,30.0*K]
const SPINA_PIER := 3.0*K
const SPINA_D := 1.6*K
const SPINA_SPRING := 9.0*K
const SPINA_TOP := Vector2(17.0,20.0)*K
## The aqueduct across the bowl along x at AQ_Z, its ends on the inner
## wall: its arches out from the long axis (mirrored), each (middle x,
## toy width, springing over the podium; x K), AQ_PIER between the two
## middle ones, AQ_D half thick, its deck's top AQ_TOP over the podium;
## those within AQ_FLOWN of the middle stand over the arena and are flown.
const AQ_Z := 12.0*K
const AQ := [Vector3(0.0,7.5,12.0),Vector3(17.0,6.5,13.0),Vector3(33.0,6.5,13.0),Vector3(47.0,4.5,18.0)]
const AQ_PIER := 3.0*K
const AQ_D := 1.5*K
const AQ_TOP := 27.0*K
const AQ_FLOWN := 25.0*K

## The solid's grid (m) and, near the walls, its finer cells.
const CELL := 1.0*K
const FINE := 0.5*K

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
	return 1.0-INNER_MID/(77.0*K)

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
			if roll < 0.06: o = "blocked"
			elif roll < 0.13: o = "tight"
			elif roll < 0.13+0.14*weathered: o = "cut3"
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
		cap.append(lerpf(ROOF.y+1.0*K,4.5*K,f)+r.randf_range(-1.0,1.0)*f*K)
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
		elif ax < TRENCH*0.5+SQUARE: gone = az < FALL_Z-8.0*K and r.randf() < 0.78
		elif ax < TRENCH*0.5+SQUARE*2.0: gone = az < FALL_Z-15.0*K and r.randf() < 0.4
		if gone:
			fallen[key] = true
			walls[key] = P-r.randf_range(0.8,2.2)*K
	p["fallen"] = fallen
	p["wall_top"] = walls
	# The arena's works: the spina arch that lost its crown; the side (+x 1,
	# -x -1) whose aqueduct end fell, the broken side's.
	var spina: Array = []
	var lost := r.randi_range(0,SPINA_Z.size()-1)
	for i in range(SPINA_Z.size()): spina.append("crown" if i == lost else "whole")
	p["spina"] = spina
	p["aq_fall"] = 1.0 if broken == SLOTS/4 else -1.0
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
	return AABB(Vector3(x0,P-0.8*K,z0),Vector3(x1-x0,0.8*K,SQUARE))

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
		"stump": return P+2.5*K
		"cut1": return P+8.5*K
		"cut2": return P+17.0*K
		"cut3": return P+30.0*K
	return P+40.0*K

static func _outer_high(kind: String) -> float:
	match kind:
		"stump": return P+7.0*K
		"cut1": return P+14.0*K
		"cut2": return P+25.0*K
		"cut3": return P+37.0*K
	return P+ATTIC

## Whether tier `t` (0..2) of an outer bay of `kind` is a whole arch.
static func _tier_open(kind: String, t: int) -> bool:
	if kind == "gate": return t == 2
	if kind == "blocked" and t == 0: return false
	var tier: Vector3 = TIERS[t]
	return P+tier.y+_arch_w(kind)*0.5+RING+0.6*K < _outer_low(kind)

## The passages through the seats, each a straight band from the inner
## wall's inner face along its slot's inward normal: {k, kind ("gate",
## "pass1", "pass2"), o (its start, y 0), dir, half (its half width), len}.
static func bands(p: Dictionary) -> Array:
	var out: Array = []
	var inner: Array = p["inner"]
	for k in range(SLOTS):
		var ik := String(inner[k])
		if not ik in ["gate","pass1","pass2"]: continue
		var mid := slot_mid(k)
		var o := point(mid,INNER_IN-0.3*K)
		var dir := -normal_at(phi_of(mid))
		var w := (GATE if ik == "gate" else _pass_hole())*inner_scale(k)
		var l := ARENA_D-INNER_IN+1.0*K if ik != "pass2" else _cut_treads()*TREAD+0.6*K
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
		var l := float(bd.len)-1.0*K
		var w := float(bd.half)*2.0
		var kind := String(bd.kind)
		var at := o+dir*l*0.5
		if kind == "gate":
			var nm := "colosseum/gate_n" if k == 0 else "colosseum/gate_s"
			_opening(out,nm+"_way","gate_way",at+Vector3.UP*(P+(band_level(bd)-P)*0.5),-dir,Vector3(w,band_level(bd)-P-0.4*K,l),0.0,false,false,true,{"slot":k})
			continue
		var t := 0 if kind == "pass1" else 1
		var tier: Vector3 = TIERS[t]
		var fi := frame(mid,INNER_MID)
		_opening(out,"colosseum/i%d" % k,"passage" if t == 0 else "vomitorium",fi*Vector3(0.0,P+(tier.x+tier.y)*0.5,0.0),fi.basis.z,Vector3(w,tier.y-tier.x,INNER_D*2.0),w*0.5,false,false,false,{"tier":t+1,"slot":k})
		var lo := P+tier.x
		var hi := band_level(bd) if t == 0 else P+tier.y+w*0.5
		_opening(out,"colosseum/i%d_way" % k,"tunnel",at+Vector3.UP*((lo+hi)*0.5),-dir,Vector3(w,hi-lo-0.4*K,l),0.0,false,false,true,{"slot":k})
	# The ambulatory, a bay at a time along the ring (s growing).
	var roof: Array = p["roof"]
	for k in range(SLOTS):
		var f := frame(slot_mid(k),OUT_IN+AMB*0.5)
		var lo := 3.0*K
		var hi := ROOF.x-1.5*K
		_opening(out,"colosseum/amb%d" % k,"ambulatory",f*Vector3(0.0,P+(lo+hi)*0.5,0.0),f.basis.x,Vector3(AMB-1.0*K,hi-lo,2.0*K),0.0,false,false,false,{"slot":k,"roofed":bool(roof[k])})
	# The arena along the long axis, skimmed; the trench and its two ends.
	var az := RZ-ARENA_D
	_opening(out,"colosseum/arena","arena",Vector3(0.0,P+6.0*K,0.0),Vector3.BACK,Vector3(TRENCH,10.0*K,az*2.0-8.0*K),0.0,false,false,true)
	# The trench is open overhead: flown with the wings under the arena's
	# floor, kept up off its own floor (low over the ground the flight
	# rides it, and a stepped floor is a crash).
	var ty := Vector2(4.0*K,P+1.0*K)
	_opening(out,"colosseum/trench","trench",Vector3(0.0,(ty.x+ty.y)*0.5,0.0),Vector3.BACK,Vector3(TRENCH,ty.y-ty.x,TRENCH_LANE*2.0),0.0,false,false,true)
	for sgn: float in [1.0,-1.0]:
		_opening(out,"colosseum/trench_%s" % ("n" if sgn > 0.0 else "s"),"trench",Vector3(0.0,(ty.x+ty.y)*0.5,sgn*(TRENCH_LANE-1.0*K)),Vector3.BACK,Vector3(TRENCH,ty.y-ty.x,2.0*K))
	# The broken side: over its lowest bays, inward; then the bowl.
	var bk := int(p["broken"])
	var bf := frame(slot_mid(bk),WALL_D)
	var low := _outer_high("stump")+2.0*K
	_opening(out,"colosseum/break","break",bf*Vector3(0.0,(low+P+30.0*K)*0.5,0.0),-bf.basis.z,Vector3(pitch()*3.0,P+30.0*K-low,WALL_D*2.0))
	_opening(out,"colosseum/bowl","bowl",Vector3(0.0,P+7.0*K,0.0),-bf.basis.z,Vector3(TRENCH*1.5,10.0*K,4.0*K))
	# The arena's works' arches: the spina's and the aqueduct's over the
	# arena, from the podium to their springing.
	for w: Dictionary in works(p):
		if not bool(w.flown): continue
		var hole: Array = w.hole
		var hw := float(hole[0])
		var spring := float(hole[2])
		_opening(out,String(w.name),"arch",Vector3(float(w.cx),(P+spring)*0.5,float(w.z)),Vector3.BACK,Vector3(hw,spring-P,float(w.d)*2.0),hw*0.5)
	return out

static func _opening(out: Array, name: String, kind: String, centre: Vector3, way: Vector3, size: Vector3, head := 0.0, knife := false, round := false, lane := false, extra := {}) -> void:
	var z := way.normalized()
	var x := Vector3.UP.cross(z).normalized()
	var o := {"name":name,"kind":kind,"frame":Transform3D(Basis(x,Vector3.UP,z),centre),"size":size,"head":head,"knife":knife,"round":round,"lane":lane}
	o.merge(extra)
	out.append(o)

# --- The piece ------------------------------------------------------------------

## The gothic pieces' Build (its mossed stone, its growth), its blocks K
## times as long as theirs (its courses are COURSE high).
static func _kbuild(seed_value: int, weathered: float, label: String) -> Build:
	var b := Gothic._build(seed_value,weathered,label)
	b.course *= K
	return b

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
	var b := _kbuild(seed_value,weathered,"Colosseum")
	var extra: Array = []
	var bs := bands(p)
	_rings(b,p,bs,extra)
	_arena(b,p,extra)
	_arena_works(b,p,extra)
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
	# The far level (its mesh made on the main thread, `realize`).
	var far := MeshInstance3D.new()
	far.name = "Far"
	var shell := _far_shell(p,tops,seed_value,weathered)
	far.set_meta("far_arrays",shell)
	root.add_child(far)
	_levels(root,far)
	stats["tris_far"] = shell[2]
	stats["far_levels"] = (shell[1] as Dictionary).values().map(func(ix: PackedInt32Array) -> int: return ix.size()/3)
	if OS.get_thread_caller_id() == OS.get_main_thread_id(): realize(root)
	stats["build_ms"] = (Time.get_ticks_usec()-t0)/1000.0
	root.set_meta("stats",stats)
	return root

## Makes the bays' MultiMeshes under `node` from what `_instances` left
## (on the main thread: land_arches.gd calls it as it adds the piece).
static func realize(node: Node) -> void:
	for n in node.find_children("Far","MeshInstance3D",true,false):
		var far := n as MeshInstance3D
		if far.mesh != null or not far.has_meta("far_arrays"): continue
		var shell: Array = far.get_meta("far_arrays")
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,shell[0],[],shell[1])
		mesh.surface_set_material(0,GothicGrowth.stone())
		far.mesh = mesh
		far.remove_meta("far_arrays")
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

# --- The far level -----------------------------------------------------------------

## Past FAR_AT (m from the piece's middle) the bays, the rings and their
## growth give way to one coarse shell ("Far", `_far_shell`), crossfaded
## over FAR_FADE: the outer wall a band round the ring with its arches cut
## through (heads in four chords) and its cornices, the broken side's
## ragged line sampled from the bays' own wall heads, the inner wall, the
## walkway, the seats a block a tread, the arena's floor with its trench
## and cells, the plinth's steps and the rubble slope. Drawn only: the
## solid and the flown openings are the near level's.
const FAR_AT := 850.0
const FAR_FADE := 80.0
## The shell's stone against the near level's mean block (its growth and
## crevices darken it at a distance), and its dark faces'.
const FAR_TONE := 0.74
const FAR_DARK := 0.45

class FarFaces extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var base := Color()
	var rng := RandomNumberGenerator.new()

	## A colour near the stone's middle (the near level's block tones, as
	## they average at a distance), `t` over it.
	func tone(t: float) -> Color:
		var col := base*(t*(1.0+rng.randf_range(-0.5,0.5)*0.12))
		col.a = 1.0
		return col

	## A quad a, b, cc, d (in order round), facing away from `inside`.
	func quad(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, inside: Vector3, col: Color) -> void:
		var nrm := (cc-a).cross(d-b)
		if nrm.length_squared() < 1e-6: return
		nrm = nrm.normalized()
		var mid := (a+b+cc+d)*0.25
		if nrm.dot(mid-inside) < 0.0: nrm = -nrm
		for t: Array in [[a,b,cc],[a,cc,d]]:
			var p0: Vector3 = t[0]
			var p1: Vector3 = t[1]
			var p2: Vector3 = t[2]
			if (p1-p0).cross(p2-p0).length_squared() < 1e-8: continue
			# Front faces are clockwise.
			if (p1-p0).cross(p2-p0).dot(nrm) > 0.0:
				var s := p1
				p1 = p2
				p2 = s
			for q: Vector3 in [p0,p1,p2]:
				v.append(q)
				n.append(nrm)
				c.append(col)

## A far block's faces (bits of a mask).
const F_OUT := 1
const F_IN := 2
const F_TOP := 4
const F_BOT := 8
const F_S0 := 16
const F_S1 := 32
const F_ALL := 63

## A block on the ring from arc `s0` to `s1`, `d0` to `d1` inward, its
## foot and head `ya` (y0, y1) at s0 and `yb` at s1 (the piece's frame).
## `shade` the vertex alpha of its faces but its top (1 open air); the
## faces in `dim` in the dark (under a roof, in an arch's reveal: the near
## level's shadowed depths, which a coarse face would light).
static func _fbox(f: FarFaces, s0: float, s1: float, d0: float, d1: float, ya: Vector2, yb: Vector2, col: Color, mask := F_ALL, shade := 1.0, dim := 0) -> void:
	if ya.y-ya.x < 0.05 and yb.y-yb.x < 0.05: return
	var p00 := point(s0,d0)
	var p10 := point(s1,d0)
	var p01 := point(s0,d1)
	var p11 := point(s1,d1)
	var up := Vector3.UP
	var a0 := p00+up*ya.x
	var a1 := p00+up*ya.y
	var b0 := p10+up*yb.x
	var b1 := p10+up*yb.y
	var c0 := p01+up*ya.x
	var c1 := p01+up*ya.y
	var e0 := p11+up*yb.x
	var e1 := p11+up*yb.y
	var mid := (a0+a1+b0+b1+c0+c1+e0+e1)*0.125
	var lit := col
	lit.a = shade
	var dark := col*FAR_DARK
	dark.a = 0.25
	if mask & F_OUT: f.quad(a0,b0,b1,a1,mid,dark if dim & F_OUT else lit)
	if mask & F_IN: f.quad(c0,e0,e1,c1,mid,dark if dim & F_IN else lit)
	if mask & F_TOP: f.quad(a1,b1,e1,c1,mid,dark if dim & F_TOP else col)
	if mask & F_BOT: f.quad(a0,b0,e0,c0,mid,dark if dim & F_BOT else lit)
	if mask & F_S0: f.quad(a0,c0,c1,a1,mid,dark if dim & F_S0 else lit)
	if mask & F_S1: f.quad(b0,e0,e1,b1,mid,dark if dim & F_S1 else lit)

## A bay's wall from `d0` to `d1` inward round slot middle `mid`, its
## local x `u` (-hw..hw) at arc mid+u*su, from `base` up to `top`(u),
## pierced by `arches` [[w, sill, spring]] (round heads in four chords);
## `ragged`: its head sampled finer (a fallen bay); `side` its face on
## the ambulatory (F_IN or F_OUT), dark as the arches' reveals.
static func _fwall(f: FarFaces, mid: float, su: float, hw: float, d0: float, d1: float, base: float, top: Callable, arches: Array, ragged: bool, side: int) -> void:
	var us := [-hw,hw]
	for a: Array in arches:
		var r := float(a[0])*0.5
		for t: float in [-1.0,-0.5,0.0,0.5,1.0]:
			if absf(t*r) < hw-0.05: us.append(t*r)
	var steps := 6 if ragged else 2
	for i in range(1,steps): us.append(lerpf(-hw,hw,float(i)/steps))
	us.sort()
	var cuts: Array = []
	for u: float in us:
		if cuts.is_empty() or u-float(cuts[-1]) > 0.2: cuts.append(u)
	if hw-float(cuts[-1]) > 0.01: cuts[-1] = hw
	var ops := arches.duplicate()
	ops.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) < float(y[1]))
	var col := f.tone(1.0)
	# Each strip's solid segments [foot at ua, foot at ub, head at ua, head
	# at ub, dark faces], then drawn, a side face left out where the next
	# strip's stone covers it.
	var strips: Array = []
	for i in range(cuts.size()-1):
		var ua: float = cuts[i]
		var ub: float = cuts[i+1]
		var um := (ua+ub)*0.5
		var ta := float(top.call(ua))
		var tb := float(top.call(ub))
		var lo := Vector2(base,base)
		var segs: Array = []
		for a: Array in ops:
			var r := float(a[0])*0.5
			if absf(um) >= r: continue
			var sill := float(a[1])
			var spring := float(a[2])
			segs.append([lo,Vector2(minf(sill,ta),minf(sill,tb)),side|F_S0|F_S1|F_BOT])
			lo = Vector2(maxf(lo.x,spring+sqrt(maxf(r*r-ua*ua,0.0))),maxf(lo.y,spring+sqrt(maxf(r*r-ub*ub,0.0))))
		segs.append([lo,Vector2(maxf(ta,lo.x),maxf(tb,lo.y)),side|F_BOT|(F_S0|F_S1 if lo.x > base+0.01 else 0)])
		strips.append(segs)
	var covered := func(segs: Array, end: int, y0: float, y1: float) -> bool:
		for sg: Array in segs:
			if (sg[0] as Vector2)[end] <= y0+0.05 and (sg[1] as Vector2)[end] >= y1-0.05: return true
		return false
	for i in range(strips.size()):
		for sg: Array in strips[i]:
			var foot: Vector2 = sg[0]
			var head: Vector2 = sg[1]
			var mask := F_OUT|F_IN|F_TOP|(F_BOT if foot.x > base+0.01 else 0)
			# The strip's ends: at the bay's edges only its wall head (a
			# neighbour's head may stand lower), inside where uncovered.
			if i > 0: mask |= 0 if covered.call(strips[i-1],1,foot.x,head.x) else F_S0
			elif foot.x > base+0.01 or head.x > foot.x: mask |= F_S0 if foot.x > base+0.01 or (strips[i] as Array).size() == 1 else 0
			if i < strips.size()-1: mask |= 0 if covered.call(strips[i+1],0,foot.y,head.y) else F_S1
			elif (strips[i] as Array).size() == 1 or foot.y > base+0.01: mask |= F_S1
			_fbox(f,mid+float(cuts[i])*su,mid+float(cuts[i+1])*su,d0,d1,Vector2(foot.x,head.x),Vector2(foot.y,head.y),col,mask,1.0,int(sg[2]))

## The far shell: [its arrays (indexed), its levels, its triangles], from
## the plan and the bays' wall heads (`tops`, as `colosseum` made them).
static func _far_shell(p: Dictionary, tops: Dictionary, seed_value: int, weathered: float) -> Array:
	var f := FarFaces.new()
	f.rng.seed = hash([seed_value,"colosseum_far"])
	var cb := _kbuild(seed_value,weathered,"ColosseumFar")
	var mean := Color(0,0,0,0)
	for i in range(24): mean += RuinKit._stone(cb,1.0)
	cb.root.free()
	f.base = mean/24.0*FAR_TONE
	var outer: Array = p["outer"]
	var inner: Array = p["inner"]
	var roof: Array = p["roof"]
	var cap: Array = p["cap"]
	var fall: Array = p["fall"]
	var nom := _inner_nominal()
	var down := Vector3(0.0,-50.0*K,0.0)
	for k in range(SLOTS):
		var e := slot_edges(k)
		var mid := slot_mid(k)
		var ok := String(outer[k])
		var ik := String(inner[k])
		var gate := ok == "gate"
		# The outer wall, its arches through.
		var hw := (GATE_SLOT if gate else pitch())*0.5
		var arches: Array = []
		var aw := _arch_w(ok)
		if gate:
			arches.append([GATE,P,P+GATE_SPRING])
			arches.append([ARCH,P+(TIERS[2] as Vector3).x,P+(TIERS[2] as Vector3).y])
		else:
			for t in range(3):
				if ok == "blocked" and t == 0: continue
				var tier: Vector3 = TIERS[t]
				arches.append([aw,P+tier.x,P+tier.y])
		var otop: Callable = tops["o:"+ok]
		_fwall(f,mid,1.0,hw,0.0,OUT_IN,P-1.0*K,otop,arches,not ok in ["whole","tight","blocked","gate"],F_IN)
		# Its cornices, proud of the face, where the wall stands to them.
		for t in range(3):
			var y := P+(TIERS[t] as Vector3).z-0.6*K
			if minf(float(otop.call(-hw)),float(otop.call(hw))) < y+0.4*K: continue
			_fbox(f,e.x,e.y,-0.45*K,0.05,Vector2(y-0.35*K,y+0.05*K),Vector2(y-0.35*K,y+0.05*K),f.tone(1.06),F_OUT|F_TOP|F_BOT)
		# The inner wall: its gate and vomitorium open, the rest blind.
		var ihw := (GATE_SLOT if gate else pitch())*nom*0.5
		var iarch: Array = []
		match ik:
			"gate": iarch.append([GATE,P,P+GATE_SPRING])
			"pass1": iarch.append([_pass_hole(),P,P+(TIERS[0] as Vector3).y])
			"pass2": iarch.append([_pass_hole(),P+(TIERS[1] as Vector3).x,P+(TIERS[1] as Vector3).y])
		_fwall(f,mid,1.0/nom,ihw,INNER_MID-INNER_D,INNER_IN,P-1.0*K,tops["i:"+ik],iarch,ik == "low",F_OUT)
		# The ambulatory's floor and the walkway over it.
		_fbox(f,e.x,e.y,OUT_IN-0.3*K,INNER_MID,Vector2(P-1.2*K,P),Vector2(P-1.2*K,P),f.tone(0.9),F_TOP,1.0,F_TOP if bool(roof[k]) else 0)
		if bool(roof[k]):
			var sides := (0 if bool(roof[(k+SLOTS-1)%SLOTS]) else F_S0)|(0 if bool(roof[(k+1)%SLOTS]) else F_S1)
			_fbox(f,e.x,e.y,OUT_IN-0.4*K,INNER_MID,Vector2(P+ROOF.x,P+ROOF.y),Vector2(P+ROOF.x,P+ROOF.y),f.tone(1.0),F_TOP|F_BOT|sides,1.0,F_BOT)
		# The seats, a block a tread, cut to the bay's fall; over a great
		# gate's passage from its soffit up.
		var lost := float(cap[k])+P
		var broke := float(fall[k]) > 0.0 or float(fall[(k+SLOTS-1)%SLOTS]) > 0.0 or float(fall[(k+1)%SLOTS]) > 0.0
		var soffit := P+GATE_SPRING+GATE*0.5
		for i in range(TREADS):
			var d0 := INNER_IN+TREAD*i-0.15*K
			var d1 := INNER_IN+TREAD*(i+1)
			var y1 := minf(tread_top(i),lost)
			var y0 := tread_top(i)-2.6*K if i < TREADS-1 else P-1.0*K
			if gate:
				if y1 < soffit+1.5*K: continue
				y0 = soffit
			if y1 < y0+0.3*K: continue
			var mask := F_TOP|F_IN|(F_S0|F_S1 if broke else 0)|(F_BOT if gate else 0)
			_fbox(f,e.x,e.y,d0,d1,Vector2(y0,y1),Vector2(y0,y1),f.tone(1.0+0.04*(i%2)),mask)
		if gate:
			# The passage's floor: the trench's ramp on to the podium.
			var qs: Array = [point(e.x,INNER_IN),point(e.y,INNER_IN),point(e.y,ARENA_D),point(e.x,ARENA_D)]
			for qi in range(4):
				var q: Vector3 = qs[qi]
				q.y = _trench_floor(absf(q.z))
				qs[qi] = q
			f.quad(qs[0],qs[1],qs[2],qs[3],down,f.tone(0.88))
		# The plinth's steps.
		for st in range(STEPS):
			var y := P*(STEPS-st)/float(STEPS)
			_fbox(f,e.x,e.y,-STEP*(st+1),-STEP*st+0.3,Vector2(-FOUND,y),Vector2(-FOUND,y),f.tone(0.95),F_OUT|F_TOP)
		# The rubble slope where the wall fell, its edges shared with its
		# neighbours'.
		var fa := (float(fall[k])+float(fall[(k+SLOTS-1)%SLOTS]))*0.5
		var fb := (float(fall[k])+float(fall[(k+1)%SLOTS]))*0.5
		if maxf(fa,fb) >= 0.1:
			var top0 := point(e.x,0.8*K)+Vector3.UP*(P+6.0*K*fa)
			var top1 := point(e.y,0.8*K)+Vector3.UP*(P+6.0*K*fb)
			var toe1 := point(e.y,-RUBBLE*fb)+Vector3.UP*-K
			var toe0 := point(e.x,-RUBBLE*fa)+Vector3.UP*-K
			f.quad(top0,top1,toe1,toe0,down,f.tone(0.88))
	# The arena: its floor in runs, the trench and side cells sunk, the
	# hypogeum's walls where the floor fell.
	var fallen: Dictionary = p["fallen"]
	var rows := {}
	for key: Vector2i in _arena_squares():
		if not rows.has(key.y): rows[key.y] = []
		(rows[key.y] as Array).append(key.x)
	var h := TRENCH*0.5
	for j: int in rows:
		var xs: Array = rows[j]
		xs.sort()
		var run_at := -1
		for idx in range(xs.size()+1):
			var here := idx < xs.size() and not fallen.has(Vector2i(int(xs[mini(idx,xs.size()-1)]),j))
			var joined := here and run_at >= 0 and int(xs[idx])-int(xs[idx-1]) == 1
			if run_at >= 0 and not joined:
				var a := _square_box(Vector2i(int(xs[run_at]),j))
				var b := _square_box(Vector2i(int(xs[idx-1]),j))
				f.quad(Vector3(a.position.x,P,a.position.z),Vector3(b.end.x,P,a.position.z),Vector3(b.end.x,P,a.end.z),Vector3(a.position.x,P,a.end.z),down,f.tone(0.96))
				run_at = -1
			if here and run_at < 0: run_at = idx
		for x: int in xs:
			var key := Vector2i(x,j)
			var box := _square_box(key)
			var c := box.get_center()
			if fallen.has(key):
				var z0 := box.position.z
				var z1 := box.end.z
				var ya := _trench_floor(absf(z0)) if absf(c.x) < h else 0.4*K
				var yb := _trench_floor(absf(z1)) if absf(c.x) < h else 0.4*K
				f.quad(Vector3(box.position.x,ya,z0),Vector3(box.end.x,ya,z0),Vector3(box.end.x,yb,z1),Vector3(box.position.x,yb,z1),down,f.tone(0.88))
				continue
			for nb: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				if not fallen.has(key+nb): continue
				var e0: Vector3
				var e1: Vector3
				if nb.x != 0:
					var x0 := box.end.x if nb.x > 0 else box.position.x
					e0 = Vector3(x0,0.0,box.position.z)
					e1 = Vector3(x0,0.0,box.end.z)
				else:
					var zz := box.end.z if nb.y > 0 else box.position.z
					e0 = Vector3(box.position.x,0.0,zz)
					e1 = Vector3(box.end.x,0.0,zz)
				f.quad(e0+Vector3.UP*0.4*K,e1+Vector3.UP*0.4*K,e1+Vector3.UP*P,e0+Vector3.UP*P,Vector3(c.x,P*0.5,c.z),f.tone(0.9))
	_far_works(f,p)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = f.v
	arrays[Mesh.ARRAY_NORMAL] = f.n
	arrays[Mesh.ARRAY_COLOR] = f.c
	# Welded and given Godot's levels here (on the build's thread), as
	# RuinLod's stone; the mesh is made of them on the main thread.
	var weld := SurfaceTool.new()
	weld.create_from_arrays(arrays)
	weld.index()
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,weld.commit_to_arrays())
	importer.generate_lods(RuinLod.STONE_MERGE_ANGLE,60.0,[])
	var lods := {}
	for l in range(importer.get_surface_lod_count(0)):
		lods[importer.get_surface_lod_size(0,l)] = importer.get_surface_lod_indices(0,l)
	return [importer.get_surface_arrays(0),lods,f.v.size()/3]

## The near level (every drawn instance but the far shell and the shadow
## chunks, which stop far nearer) ended at FAR_AT, the shell begun there,
## faded across FAR_FADE.
static func _levels(root: Node3D, far: GeometryInstance3D) -> void:
	for n in root.find_children("*","GeometryInstance3D",true,false):
		var g := n as GeometryInstance3D
		if g == far or String(g.name).begins_with("Shade"): continue
		g.visibility_range_end = FAR_AT if g.visibility_range_end <= 0.0 else minf(g.visibility_range_end,FAR_AT)
		g.visibility_range_end_margin = FAR_FADE
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	far.visibility_range_begin = FAR_AT
	far.visibility_range_begin_margin = FAR_FADE
	far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

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
		while y < spring-0.2*K:
			var hgt := minf(COURSE*b.rng.randf_range(0.8,1.2),spring-y)
			if spring-(y+hgt) < 0.6*K: hgt = spring-y
			var wide := RING*(1.0 if k%2 == 0 else 0.75)
			var x := s*(w*0.5+wide*0.5)
			if y+hgt > float(top.call(x))+0.2*K: break
			b.solid(RuinKit._box(b,Vector3(wide*0.5,hgt*0.5-0.01,d)),RuinKit._settle(b,Vector3(x,y+hgt*0.5,0.0),0.2*K),RuinKit._stone(b,1.03),false)
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
	var b := _kbuild(seed_value,weathered,"ColosseumBay_"+kind)
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
	RuinKit._courses(b,Transform3D.IDENTITY,-hw,hw,P-1.0*K,top,WALL_D,_holes(arches),COURSE)
	for a: Array in arches:
		_jambs(b,float(a[0]),float(a[1]),float(a[2]),WALL_D,top)
		_round_head(b,Transform3D.IDENTITY,float(a[0]),float(a[2]),WALL_D,top,11 if float(a[0]) > 8.0*K else 9)
	if kind == "blocked":
		# Its first arch walled up to about its springing, set back, its
		# ring standing over the walling.
		var t1: Vector3 = TIERS[0]
		var fill := RuinKit._ruin_line(b,-aw*0.5-RING,aw*0.5+RING,P+t1.y-1.2*K,P+t1.y,0.8)
		RuinKit._courses(b,Transform3D.IDENTITY,-aw*0.5-RING*0.5,aw*0.5+RING*0.5,P-1.0*K,fill,WALL_D*0.55,Callable(),COURSE)
		_round_head(b,Transform3D.IDENTITY,aw,P+t1.y,WALL_D,top)
	# The outer face: an engaged column at the bay's edge each tier and a
	# cornice over each tier.
	var floors := [P,P+(TIERS[0] as Vector3).z,P+(TIERS[1] as Vector3).z]
	for t in range(3):
		var tier: Vector3 = TIERS[t]
		var y0: float = floors[t]
		var y1 := P+tier.z-1.0*K
		var yt := minf(y1,float(top.call(hw-0.4*K))-0.3*K)
		if yt > y0+1.0*K:
			b.solid(RuinKit._prism(8,0.72*K,0.64*K,y0,yt,PI/8.0),Transform3D(Basis.IDENTITY,Vector3(hw,0.0,WALL_D+0.15*K)),RuinKit._stone(b,0.97),false)
			if yt >= y1-0.01: b.solid(RuinKit._box(b,Vector3(0.85,0.3,0.55)*K),Transform3D(Basis.IDENTITY,Vector3(hw,y1-0.3*K,WALL_D+0.3*K)),RuinKit._stone(b,1.0),false)
		for half: float in [-1.0,1.0]:
			var mx := half*hw*0.5
			if float(top.call(mx)) < P+tier.z+0.1*K: continue
			b.solid(RuinKit._box(b,Vector3(hw*0.5+0.02,0.4*K,0.42*K)),RuinKit._settle(b,Vector3(mx,P+tier.z-0.6*K,WALL_D+0.2*K),0.2*K),RuinKit._stone(b,1.05),false)
	# The attic's crown and its flat pilaster.
	if whole:
		for half: float in [-1.0,1.0]:
			var mx := half*hw*0.5
			if float(top.call(mx)) >= P+ATTIC-0.6*K:
				b.solid(RuinKit._box(b,Vector3(hw*0.5+0.02,0.35*K,0.5*K)),RuinKit._settle(b,Vector3(mx,P+ATTIC-1.3*K,WALL_D+0.2*K),0.2*K),RuinKit._stone(b,1.06),false)
		b.solid(RuinKit._box(b,Vector3(0.7,3.6,0.22)*K),Transform3D(Basis.IDENTITY,Vector3(hw,P+(TIERS[2] as Vector3).z+4.0*K,WALL_D+0.15*K)),RuinKit._stone(b,0.98),false)
	_clear(b,arches,WALL_D)
	_dress_bay(b,"outer",P+6.0*K,WALL_D)
	return {"node":b.finish(),"top":top}

## An inner bay of `kind` (its frame as the outer's, the ambulatory on its
## +z side), built at the ring's nominal shrink.
static func _inner_bay(kind: String, seed_value: int, weathered: float) -> Dictionary:
	var b := _kbuild(seed_value,weathered,"ColosseumInner_"+kind)
	var nom := _inner_nominal()
	var w := (GATE_SLOT if kind == "gate" else pitch())*nom
	var hw := w*0.5
	var high := P+ROOF.y+1.0*K
	var top: Callable = RuinKit._ruin_line(b,-hw,hw,high-0.8*K,high,0.3)
	if kind == "low": top = RuinKit._ruin_line(b,-hw,hw,P+7.0*K,P+15.0*K,1.0)
	var arches: Array = []
	var aw := _pass_hole()
	match kind:
		"gate": arches.append([GATE,P,P+GATE_SPRING])
		"pass1": arches.append([aw,P,P+(TIERS[0] as Vector3).y])
		"pass2": arches.append([aw,P+(TIERS[1] as Vector3).x,P+(TIERS[1] as Vector3).y])
	RuinKit._courses(b,Transform3D.IDENTITY,-hw,hw,P-1.0*K,top,INNER_D,_holes(arches),COURSE)
	for a: Array in arches:
		_jambs(b,float(a[0]),float(a[1]),float(a[2]),INNER_D,top)
		_round_head(b,Transform3D.IDENTITY,float(a[0]),float(a[2]),INNER_D,top)
	# Blind arcading on the ambulatory's face: rings proud of the wall on
	# the tiers no passage pierces, a pilaster at the bay's edge.
	for t in range(2):
		var tier: Vector3 = TIERS[t]
		var pierced := (kind == "pass1" and t == 0) or (kind == "pass2" and t == 1) or kind == "gate"
		if pierced or P+tier.y+aw*0.5 > float(top.call(0.0)): continue
		RuinKit._ring_order(b,Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,INNER_D+0.12*K)),0.0,P+tier.y,aw*0.5,aw*0.5,0.0,0.7*K,0.16*K,7,99,1.0,RuinKit._stone(b,1.04),0,top)
	var pil := minf(P+ROOF.x-0.8*K,float(top.call(hw))-0.3*K)
	if pil > P+2.0*K: b.solid(RuinKit._box(b,Vector3(0.55*K,(pil-P+1.0*K)*0.5,0.18*K)),Transform3D(Basis.IDENTITY,Vector3(hw,(pil+P-1.0*K)*0.5,INNER_D+0.12*K)),RuinKit._stone(b,0.98),false)
	_clear(b,arches,INNER_D)
	_dress_bay(b,"inner",P+4.0*K,INNER_D)
	return {"node":b.finish(),"top":top}

## A bay's growth: ivy off its cornices and wall head, curtains under its
## outer cornices, mats on its ledges, low at its foot.
static func _dress_bay(b: Build, label: String, low_y: float, d: float) -> void:
	var dens := GothicGrowth.density(b)
	if dens <= 0.0: return
	var x := GothicGrowth.Dress.new(b,"colosseum_"+label,dens)
	if RuinGrowth.vines:
		x.section("cascades")
		GothicGrowth.cascades(x,P+8.0*K,P+ATTIC+2.0*K,3,Vector2(4.0,13.0)*1.4,5,GothicGrowth.COARSE_MID,0.5,0.3,true)
		x.section("curtains")
		for i in range(2):
			var at := Vector3(b.rng.randf_range(-3.0,3.0)*K,0.0,d+0.45*K)
			var tier: Vector3 = TIERS[b.rng.randi_range(0,2)]
			GothicGrowth.curtain(x,at,P+tier.z-2.0*K,P+tier.z+0.5*K,b.rng.randf_range(3.0,7.0)*K,5,GothicGrowth.COARSE_MID,true)
	x.section("mats")
	GothicGrowth.mats(x,P+8.0*K,P+ATTIC+2.0*K,3,0.3,Vector2i(1,3),3.0)
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
static func _pieces(k: int, d: float, most := 9.0*K) -> Array:
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
			var d1 := -STEP*st+0.3*K
			var y1 := P*(STEPS-st)/float(STEPS)
			for pc: Vector2 in _pieces(k,d0): _quad(b,_ring_quad(pc.x,pc.y,d0,d1),-FOUND,y1,0.95)
		# The ambulatory's floor and, where it stands, the walkway over it.
		for pc: Vector2 in _pieces(k,OUT_IN):
			_quad(b,_ring_quad(pc.x,pc.y,OUT_IN-0.3*K,INNER_MID),P-1.2*K,P,0.9,false)
			if bool(roof[k]): _quad(b,_ring_quad(pc.x,pc.y,OUT_IN-0.4*K,INNER_MID),P+ROOF.x,P+ROOF.y,1.0)
		# The seats, tread by tread: over the bay's fall a rough fill to its
		# line, through a passage its cut or vault. Near a passage, in short
		# pieces, each judged by its middle.
		var near := false
		var at := point(slot_mid(k),INNER_IN)
		for bd: Dictionary in bs:
			if (bd.o as Vector3).distance_to(at) < 55.0*K: near = true
		var lost := float(cap[k])+P
		for i in range(TREADS):
			var d0 := INNER_IN+TREAD*i-0.15*K
			var d1 := INNER_IN+TREAD*(i+1)
			var y1 := tread_top(i)
			var y0 := y1-2.6*K if i < TREADS-1 else P-1.0*K
			for pc: Vector2 in _pieces(k,(d0+d1)*0.5,1.4*K if near else 9.0*K):
				var q := _ring_quad(pc.x,pc.y,d0,d1)
				var top := minf(y1,lost)
				var lo := y0
				if near:
					var m := point((pc.x+pc.y)*0.5,(d0+d1)*0.5)
					var bd := band_at(bs,m.x,m.z)
					if not bd.is_empty():
						var lv := band_level(bd)
						if String(bd.kind) == "pass2": _quad(b,q,minf(y0,lv-2.0*K),minf(lv,top),0.92)
						elif top > lv+1.5*K: _quad(b,q,lv,top,0.97)
						# A great gate's passage: the trench's ramp its floor; a
						# first-tier one's, the podium's.
						if String(bd.kind) == "gate": _quad(b,q,-K,_trench_floor(absf(m.z)),0.88,true,_ramp_slope(m.z))
						elif String(bd.kind) == "pass1": _quad(b,q,P-1.2*K,P,0.9,false)
						continue
					# Beside a gate's or a first-tier passage the seats are walls to
					# its floor.
					if _by_gate_way(bs,m.x,m.z): lo = -K
				if y1 > lost:
					# Fallen: a rough fill to the bay's line, stones on it.
					if lost > lo+0.5*K:
						_quad(b,q,lo,lost,0.88)
						if b.rng.randf() < 0.35: extra.append(_boulder(b,(q[0]+q[2])*0.5+Vector3.UP*lost,b.rng.randf_range(0.8,1.6)*K))
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
			_quad(b,q,P-0.8*K,P,0.96)
			# Its faces onto a fallen neighbour: the hypogeum's walls.
			for nb: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				if not fallen.has(key+nb): continue
				var face: AABB
				if nb.x != 0:
					var x := box.end.x-0.6*K if nb.x > 0 else box.position.x
					face = AABB(Vector3(x,-K,box.position.z),Vector3(0.6*K,P-0.8*K+K,SQUARE))
				else:
					var z := box.end.z-0.6*K if nb.y > 0 else box.position.z
					face = AABB(Vector3(box.position.x,-K,z),Vector3(box.size.x,P-0.8*K+K,0.6*K))
				_quad(b,_box_quad(face),face.position.y,face.end.y,0.9)
			continue
		if absf(c.x) < h:
			# The trench: its floor, rising at its ends in a ramp of fallen floor.
			var az := absf(c.z)
			if az+SQUARE*0.5 <= RAMP_AT: _quad(b,q,-K,0.4*K,0.9,false)
			else:
				# A sloped slab (a stepped one's risers are walls to a low pass).
				var y := _trench_floor(az)
				var sz := signf(c.z)
				var g := sz*(_trench_floor(az+SQUARE*0.5)-_trench_floor(maxf(az-SQUARE*0.5,0.0)))/SQUARE
				_quad(b,q,-K,y,0.86,true,g)
				# (Its boulders only off the flown middle.)
				if absf(c.x) > 3.0*K and b.rng.randf() < 0.5: extra.append(_boulder(b,Vector3(c.x+b.rng.randf_range(-1.0,1.0)*K,y,c.z),b.rng.randf_range(0.7,1.3)*K))
			continue
		# A side cell: its floor, a cross wall over its middle, the trench's
		# low wall along its inner edge.
		_quad(b,q,-K,0.4*K,0.9,false)
		var wt: float = walls[key]
		var cw := AABB(Vector3(box.position.x,-K,c.z-0.5*K),Vector3(box.size.x,wt-0.6*K+K,K))
		_quad(b,_box_quad(cw),cw.position.y,cw.end.y,0.94)
		if key.x == 1 or key.x == -2:
			var lw := AABB(Vector3(h if c.x > 0.0 else -h-1.2*K,-K,box.position.z),Vector3(1.2*K,wt+K,SQUARE))
			_quad(b,_box_quad(lw),lw.position.y,lw.end.y,0.92)

static func _box_quad(a: AABB) -> Array:
	return [Vector3(a.position.x,0,a.position.z),Vector3(a.end.x,0,a.position.z),Vector3(a.end.x,0,a.end.z),Vector3(a.position.x,0,a.end.z)]

## The trench floor's height `az` from the arena's middle along it: flat,
## then a ramp of fallen floor from RAMP_AT on through the arena's end and
## under a great gate's passage to the podium at the inner wall's face.
static func _trench_floor(az: float) -> float:
	if az <= RAMP_AT: return 0.4*K
	return lerpf(0.4*K,P,clampf((az-RAMP_AT)/(RZ-INNER_IN-RAMP_AT),0.0,1.0))

## The ramp's rise along z (dy/dz) at `z`, for a sloped slab.
static func _ramp_slope(z: float) -> float:
	if absf(z) <= RAMP_AT or absf(z) >= RZ-INNER_IN: return 0.0
	return signf(z)*(P-0.4*K)/(RZ-INNER_IN-RAMP_AT)

## Whether (x, z) is under the seats beside a great gate's passage or a
## first-tier one, where the seats are drawn solid down to its floor (its
## side walls).
static func _by_gate_way(bs: Array, x: float, z: float) -> bool:
	for bd: Dictionary in bs:
		if not String(bd.kind) in ["gate","pass1"]: continue
		var o: Vector3 = bd.o
		var dir: Vector3 = bd.dir
		var along := (x-o.x)*dir.x+(z-o.z)*dir.z
		if along < -K or along > float(bd.len)+K: continue
		if absf((x-o.x)*dir.z-(z-o.z)*dir.x) < float(bd.half)+3.0*K: return true
	return false

# --- The arena's works ----------------------------------------------------------------

## The arena's works as straight walls along x, each a segment centred on
## (cx, z) from cx-hw to cx+hw, d half thick: {name, cx, z, hw, d, hole
## ([w, sill, spring] centred, [] none), low, high (its head between),
## form, flown}. Forms: "whole"; "crown" (its arch's crown fallen, its
## piers standing); "falls" (its head falling away outward, toward
## `out`, the aqueduct's broken end); "stump" (a pier's foot, no arch).
static func works(p: Dictionary) -> Array:
	var out: Array = []
	var spina: Array = p["spina"]
	for i in range(SPINA_Z.size()):
		out.append({"name":"colosseum/spina%d" % i,"cx":0.0,"z":float(SPINA_Z[i]),"hw":SPINA*0.5+RING+SPINA_PIER,"d":SPINA_D,
			"hole":[SPINA,-K,P+SPINA_SPRING],"low":P+SPINA_TOP.x,"high":P+SPINA_TOP.y,"form":String(spina[i]),"flown":true,"out":0.0})
	var fall := float(p["aq_fall"])
	var end := RX*sqrt(1.0-AQ_Z*AQ_Z/(RZ*RZ))-INNER_MID
	for sgn: float in [1.0,-1.0]:
		var at := 0.0
		for i in range(AQ.size()):
			var a: Vector3 = AQ[i]
			if i == 0 and sgn < 0.0:
				at = (WorldScale.opening(a.y*K)+AQ_PIER)*0.5
				continue
			var w := WorldScale.opening(a.y*K)
			var cx := a.x*K
			var hw := (w+AQ_PIER)*0.5 if i == 0 else cx-at
			at = cx+hw
			var broke := sgn == fall and i > 0
			var form := "whole"
			if broke: form = "falls" if i == 1 else "gone"
			var nm := "colosseum/aq0" if i == 0 else "colosseum/aq_%s%d" % ["e" if sgn > 0.0 else "w",i]
			if form != "gone": out.append({"name":nm,"cx":cx*sgn,"z":AQ_Z,"hw":hw,"d":AQ_D,"hole":[w,-K,P+a.z*K],"low":P+AQ_TOP-0.6*K,"high":P+AQ_TOP,
				"form":form,"flown":cx < AQ_FLOWN,"out":sgn})
			# The fallen end: the piers' feet standing on the seats.
			elif i < AQ.size()-1: out.append({"name":nm+"_stump","cx":at*sgn,"z":AQ_Z,"hw":AQ_PIER*0.5,"d":AQ_D,"hole":[],
				"low":P+16.0*K,"high":P+22.0*K,"form":"stump","flown":false,"out":sgn})
		if sgn != fall: out.append({"name":"colosseum/aq_%s_end" % ("e" if sgn > 0.0 else "w"),"cx":(at+end)*0.5*sgn,"z":AQ_Z,"hw":(end-at)*0.5,"d":AQ_D,"hole":[],
			"low":P+AQ_TOP-0.6*K,"high":P+AQ_TOP,"form":"whole","flown":false,"out":sgn})
	return out

## Work `w`'s head line over its local x (-hw..hw), drawn with `b`'s rng.
static func _work_top(b: Build, w: Dictionary) -> Callable:
	var hw := float(w.hw)
	var low := float(w.low)
	var high := float(w.high)
	var form := String(w.form)
	var line: Callable = RuinKit._ruin_line(b,-hw,hw,low,high,1.0 if form == "stump" else 0.3)
	if form == "crown":
		var hole: Array = w.hole
		var r := float(hole[0])*0.5+RING
		var cut := float(hole[2])+float(hole[0])*0.12
		return func(x: float) -> float: return minf(float(line.call(x)),cut) if absf(x) < r else float(line.call(x))
	if form == "falls":
		var sgn := signf(float(w.cx))
		var foot := P+10.0*K
		return func(x: float) -> float:
			var t := clampf((x*sgn+hw)/(hw*2.0),0.0,1.0)
			return minf(float(line.call(x)),lerpf(high+1.0,foot,smoothstep(0.25,1.0,t)))
	return line

static func _arena_works(b: Build, p: Dictionary, extra: Array) -> void:
	for w: Dictionary in works(p):
		var cx := float(w.cx)
		var z := float(w.z)
		var hw := float(w.hw)
		var d := float(w.d)
		var hole: Array = w.hole
		var top := _work_top(b,w)
		var keep := b.frame
		b.frame = Transform3D(Basis.IDENTITY,Vector3(cx,0.0,z))
		RuinKit._courses(b,Transform3D.IDENTITY,-hw,hw,-K,top,d,_holes([hole]) if not hole.is_empty() else Callable(),COURSE)
		if not hole.is_empty():
			_jambs(b,float(hole[0]),float(hole[1]),float(hole[2]),d,top)
			_round_head(b,Transform3D.IDENTITY,float(hole[0]),float(hole[2]),d,top,11)
		b.frame = keep
		_wall_boxes(cx,z,-hw,hw,d,-K,top,[hole] if not hole.is_empty() else [],extra)
		if not hole.is_empty():
			var h := float(hole[0])*0.5+GothicGrowth.CORE_MARGIN
			var y1 := float(hole[2])+float(hole[0])*0.5+GothicGrowth.CORE_MARGIN
			b.clear.append(AABB(Vector3(cx-h,-K,z-d-GothicGrowth.CORE_DEPTH),Vector3(h*2.0,y1+K,(d+GothicGrowth.CORE_DEPTH)*2.0)))
		# Under the aqueduct's fallen end, its stone tumbled on the seats.
		if String(w.form) in ["falls","stump"]:
			for i in range(6):
				var x := cx+b.rng.randf_range(-1.0,1.0)*hw*1.6
				var zz := z+b.rng.randf_range(-1.0,1.0)*d*3.0
				var sd := nearest(x,zz)
				if sd.y < INNER_IN or sd.y > ARENA_D: continue
				var ti := clampi(int((sd.y-INNER_IN)/TREAD),0,TREADS-1)
				extra.append(_boulder(b,Vector3(x,tread_top(ti),zz),b.rng.randf_range(1.2,2.4)*K))

## A straight wall's solid (the piece's frame) at (cx, z), d half thick,
## along x from x0 to x1 (local), from y0 up to `top` less `holes`
## (`_cut_holes`): columns FINE wide, merged where they match.
static func _wall_boxes(cx: float, z: float, x0: float, x1: float, d: float, y0: float, top: Callable, holes: Array, out: Array) -> void:
	var n := maxi(1,int(ceil((x1-x0)/FINE)))
	var last := PackedFloat32Array()
	var from := x0
	for i in range(n+1):
		var col := PackedFloat32Array()
		if i < n:
			var lx := lerpf(x0,x1,(i+0.5)/n)
			col = _cut_holes(y0,_q(float(top.call(lx))),lx,holes)
		if i == 0:
			last = col
			continue
		if col == last: continue
		var at := lerpf(x0,x1,float(i)/n)
		for m in range(0,last.size(),2): out.append(AABB(Vector3(cx+from,last[m],z-d),Vector3(at-from,last[m+1]-last[m],d*2.0)))
		from = at
		last = col

## The works in the far shell: each pier and the walling over its arch's
## crown a block, its head at the middle of its line.
static func _far_works(f: FarFaces, p: Dictionary) -> void:
	for w: Dictionary in works(p):
		var cx := float(w.cx)
		var z := float(w.z)
		var hw := float(w.hw)
		var d := float(w.d)
		var top := (float(w.low)+float(w.high))*0.5
		var hole: Array = w.hole
		var col := f.tone(1.0)
		if hole.is_empty():
			_fslab(f,cx-hw,cx+hw,z-d,z+d,-K,top,col)
			continue
		var r := float(hole[0])*0.5
		var form := String(w.form)
		# A falling head low on its outer side.
		var lo := top
		var hi := top
		if form == "falls":
			if cx > 0.0: hi = P+12.0*K
			else: lo = P+12.0*K
		_fslab(f,cx-hw,cx-r,z-d,z+d,-K,lo,col)
		_fslab(f,cx+r,cx+hw,z-d,z+d,-K,hi,col)
		if form == "whole": _fslab(f,cx-r,cx+r,z-d,z+d,float(hole[2])+r*0.7,top,col)

## An upright block from (x0, y0, z0) to (x1, y1, z1) in the far shell
## (its foot left out).
static func _fslab(f: FarFaces, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, col: Color) -> void:
	if y1-y0 < 0.05 or x1-x0 < 0.05: return
	var c := Vector3((x0+x1)*0.5,(y0+y1)*0.5,(z0+z1)*0.5)
	var a: Array = [Vector3(x0,y0,z0),Vector3(x1,y0,z0),Vector3(x1,y0,z1),Vector3(x0,y0,z1)]
	var t: Array = [Vector3(x0,y1,z0),Vector3(x1,y1,z0),Vector3(x1,y1,z1),Vector3(x0,y1,z1)]
	f.quad(t[0],t[1],t[2],t[3],c,col)
	for i in range(4): f.quad(a[i],a[(i+1)%4],t[(i+1)%4],t[i],c,col)

# --- The rubble ----------------------------------------------------------------------

## The rubble slope's top outside slot `k` at `d` (< 0), or -INF.
static func rubble_top(p: Dictionary, k: int, d: float) -> float:
	var f := float((p["fall"] as Array)[k])
	if f < 0.1: return -INF
	var reach := RUBBLE*f
	if d < -reach: return -INF
	var high := P+6.0*K*f
	return high-(high+K)*(-d/reach)

static func _rubble(b: Build, p: Dictionary, extra: Array) -> void:
	var fall: Array = p["fall"]
	for k in range(SLOTS):
		var f := float(fall[k])
		if f < 0.1: continue
		var reach := RUBBLE*f
		var n := 4
		for j in range(n):
			var d0 := -reach*(j+1)/n
			var d1 := -reach*j/n+(0.8*K if j == 0 else 0.0)
			var y := rubble_top(p,k,(d0+d1)*0.5)
			if y <= -FOUND+0.5*K: continue
			for pc: Vector2 in _pieces(k,d0): _quad(b,_ring_quad(pc.x,pc.y,d0,d1),-FOUND,y,0.88)
		for i in range(int(5+10*f)):
			var s := slot_mid(k)+b.rng.randf_range(-0.5,0.5)*pitch()
			var d := -b.rng.randf()*reach*0.9
			var at := point(s,d)
			extra.append(_boulder(b,Vector3(at.x,rubble_top(p,k,d)-0.3*K,at.z),b.rng.randf_range(1.2,2.6)*K))
		# Drifts in the ambulatory behind it, kept low.
		for i in range(int(3*f)):
			var at := point(slot_mid(k)+b.rng.randf_range(-0.4,0.4)*pitch(),OUT_IN+b.rng.randf_range(1.0,3.0)*K)
			extra.append(_boulder(b,Vector3(at.x,P,at.z),b.rng.randf_range(0.8,1.4)*K))

## The rings' growth: ivy down the risers, curtains under the walkway's
## edge, mats on the treads and rubble, low tufts; the flown ways kept clear.
static func _dress_rings(b: Build, p: Dictionary) -> void:
	for o: Dictionary in openings("colosseum",int(p["seed"]),float(p["weathered"])):
		if not String(o.kind) in ["ambulatory","trench","tunnel","gate_way","gate","arena","arch"]: continue
		var half: Vector3 = (o.size as Vector3)*0.5+Vector3(GothicGrowth.CORE_MARGIN*0.6,GothicGrowth.CORE_MARGIN*0.6,0.3)
		b.clear.append(GothicGrowth.box_of(o.frame,half))
	var d := GothicGrowth.density(b)
	if d <= 0.0: return
	var x := GothicGrowth.Dress.new(b,"colosseum_rings",d)
	if RuinGrowth.vines:
		x.section("risers")
		GothicGrowth.cascades(x,P+4.0*K,P+ROOF.y+1.5*K,60,Vector2(1.5,3.5),4,GothicGrowth.COARSE_FAR,0.5,1.0,false)
		x.section("walkway")
		for i in range(26):
			var k := b.rng.randi_range(0,SLOTS-1)
			if not bool((p["roof"] as Array)[k]): continue
			var at := point(slot_mid(k)+b.rng.randf_range(-3.0,3.0)*K,INNER_MID-0.8*K)
			GothicGrowth.curtain(x,Vector3(at.x,0.0,at.z),P+ROOF.x-1.0*K,P+ROOF.y,b.rng.randf_range(2.0,5.0)*K,5,GothicGrowth.COARSE_MID,true)
	x.section("mats")
	GothicGrowth.mats(x,P+1.0*K,P+ROOF.y+1.5*K,50,0.5,Vector2i(2,4),3.4)
	x.section("low")
	GothicGrowth.low(x,30,P+7.0*K)
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
	if d < -RUBBLE-K: return out
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
			"pass1": holes.append([aw,P,P+(TIERS[0] as Vector3).y])
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
			if h > lv+1.5*K: out.append_array([_q(lv),_q(h)])
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
		out.append_array([-FOUND,_q(0.4*K if absf(c.z)+SQUARE*0.5 <= RAMP_AT else _trench_floor(absf(z)))])
		return out
	var wt: float = (p["wall_top"] as Dictionary)[key]
	if (key.x == 1 or key.x == -2) and absf(x) < TRENCH*0.5+1.2*K: out.append_array([-FOUND,_q(wt)])
	elif absf(z-c.z) < 0.5*K: out.append_array([-FOUND,_q(wt-0.6*K)])
	else: out.append_array([-FOUND,0.4*K])
	return out

## A height for the solid, stepped so neighbouring columns merge.
static func _q(y: float) -> float:
	return snappedf(y,0.25*K)

## The stretch [y0, y1] less the holes [[w, sill, spring]] (round heads) at
## `lx` across the bay.
static func _cut_holes(y0: float, y1: float, lx: float, holes: Array) -> PackedFloat32Array:
	var spans: Array = [Vector2(y0,y1)]
	for hl: Array in holes:
		var r: float = float(hl[0])*0.5
		if absf(lx) >= r: continue
		var lo: float = float(hl[1])
		var hi: float = _q(float(hl[2])+sqrt(maxf(r*r-lx*lx,0.0))-0.12*K)
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
		var reach := STEP*STEPS+2.0*K
		var x0 := -RX-RUBBLE-2.0*K
		var z0 := -RZ-reach
		var nx := int(ceil((RX+RUBBLE+2.0*K)*2.0/CELL))
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
	return (d > -1.2*K and d < OUT_IN+1.2*K) or (d > INNER_MID-INNER_D-1.2*K and d < INNER_IN+1.2*K)

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
