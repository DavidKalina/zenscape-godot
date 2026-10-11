extends RefCounted
## The Broken Ring's art (studies/broken_ring_isle.gd; docs/scenic/
## broken-ring.md): size in number, not mass. A central isle carries a
## standing stone circle (two stones missing) round a broken turret, and
## round it a loose spiral of eight small isles climbs 21 m, from the
## lowest (a lone arch) to the highest (a rose gable), a broken ring with a
## 50 degree gap in it. Each satellite carries one small ruin note.
##
## The spiral on foot, lowest to highest (HOPS): a rope bridge, floating
## stones, a rope bridge, a jump (the pilot's jump over a 2.7 m gap), floating
## stones, a rope bridge, a jump. The central isle hangs off the fourth by a
## rope bridge. Everything in the world's frame (y up); the isles' middles
## are RING m out of C, their tops (W + rise) over the sky.
const Art = preload("res://studies/aqueduct_isle_art.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Build = RuinKit.Build

## The ring's middle (the central isle's) and the lowest turf's height.
const C := Vector2(80.0,-10.0)
const W := 30.0
const TOP := W
## The central isle: radius, rise over W, seed. The stone circle on it is
## RuinKit.CIRCLE_RADIUS (9.3 m at plane 2) round.
const CENTRE_R := 13.5
const CENTRE_RISE := 12.0
const CENTRE_SEED := 11
## A satellite's ground swells this much in its middle.
const SWELL := 0.4
## A bridge's ends stand this far (of the radius) in from the isle's middle.
const INSET := 0.7
## The ring's break (degrees): the sky between the last isle and the first.
const BREAK := 54.6

## The satellites: [ruin note, angle (degrees round C), distance from C, radius, rise over W].
const SATS := [
	["arch",200.0,26.0,7.0,0.0],
	["piers",242.0,26.0,6.0,3.0],
	["fallen",294.0,26.0,6.5,8.4],
	["lancet",336.0,26.0,7.6,11.4],
	["chest",13.0,26.0,7.5,12.0],
	["buttress",65.0,27.5,6.0,17.4],
	["wall",107.0,26.0,7.6,20.4],
	["gable",145.4,26.0,7.5,21.0],
]
## The spiral's hops: [from, to, how]. "bridge": a rope bridge; "stones":
## floating stones; "jump": a gap to jump. The central isle's bridge is
## BRIDGE_CENTRE.
const HOPS := [[0,1,"bridge"],[1,2,"stones"],[2,3,"bridge"],[3,4,"jump"],[4,5,"stones"],[5,6,"bridge"],[6,7,"jump"]]
const CENTRE_HOP := 3
## How many floating stones a stones hop has.
const STONES := 4

# --- The isles ---------------------------------------------------------------------

static var _sats: Array = []
## The satellites: {i, note, c (world x, z), r, top (y), ang, seed}.
static func sats() -> Array:
	if not _sats.is_empty(): return _sats
	var out: Array = []
	for i in range(SATS.size()):
		var s: Array = SATS[i]
		var c := C+Vector2.from_angle(deg_to_rad(float(s[1])))*float(s[2])
		out.append({"i":i,"note":s[0],"c":c,"r":float(s[3]),"top":W+float(s[4]),"ang":float(s[1]),"seed":71+i})
	_sats = out
	return out

static func sat(i: int) -> Dictionary:
	return sats()[i]

static func centre_top() -> float:
	return W+CENTRE_RISE

## The highest turf's top (the summit isle's).
static func summit_y() -> float:
	return float(sat(SATS.size()-1).top)+SWELL

## A satellite's ground at world (x, z): its top, a low swell in its middle.
static func sat_ground(s: Dictionary, x: float, z: float) -> float:
	var e := Vector2(x,z).distance_to(s.c)/float(s.r)
	return float(s.top)+SWELL*(1.0-smoothstep(0.0,1.0,e))

## The central isle's ground: flat, a low swell, the circle on it.
static func centre_ground(x: float, z: float) -> float:
	var e := Vector2(x,z).distance_to(C)/CENTRE_R
	return centre_top()+0.25*(1.0-smoothstep(0.0,1.0,e))

## The isle's outline: a ring of 12 points of a wandering radius, kept near
## `r` (0.92-1.05) so a gap measured from the middles is the gap at the rims.
static func outline_of(c: Vector2, r: float, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for k in range(12):
		var a := k*TAU/12.0+rng.randf_range(-0.1,0.1)
		out.append(c+Vector2(cos(a),sin(a))*r*rng.randf_range(0.92,1.05))
	return out

## The worn way over each isle (world x, z): bridge end to bridge end, and
## round the circle's front to the turret.
static func paths() -> Array:
	var out: Array = []
	for hop: Array in HOPS:
		var ends := hop_ends(int(hop[0]),int(hop[1]))
		out.append([ends[0],ends[1]])
	var s3 := sat(CENTRE_HOP)
	var ca: Vector2 = s3.c
	var dir := (C-ca).normalized()
	out.append([ca+dir*float(s3.r)*INSET,C-dir*CENTRE_R*0.85,C-dir*2.0])
	return out

## Where a hop's two ends stand, each INSET in from the isle's middle toward
## the other: [a (x, z), b (x, z)].
static func hop_ends(from: int, to: int) -> Array:
	var sa := sat(from)
	var sb := sat(to)
	var dir := ((sb.c as Vector2)-(sa.c as Vector2)).normalized()
	return [(sa.c as Vector2)+dir*float(sa.r)*INSET,(sb.c as Vector2)-dir*float(sb.r)*INSET]

static func path_wear(p: Vector2) -> float:
	if _wear == null: _wear = KitLand.wear_of(paths())
	return float(_wear.call(p))
static var _wear: Variant = null

## An island (the kit isles' shared builder, scripts/kit_isle/kit_land.gd):
## its top over `flat`, its sides and keel of hanging rock `depth` under it.
static func island(outline_points: Array, depth: float, seed_value: int, flat: Callable, top: float) -> Node3D:
	var spec := {"outline":outline_points,"depth":depth,"seed":seed_value,"ground":flat,"top":top,"hang":true,
		"tone":KitLook.turf(seed_value,func(p: Vector2) -> float: return path_wear(p))}
	return KitLand.island(spec)

static func central(seed_value: int) -> Node3D:
	var node := island(outline_of(C,CENTRE_R,seed_value),24.0,seed_value,func(x: float, z: float) -> float: return centre_ground(x,z),centre_top())
	node.name = "CentralIsle"
	return node

static func satellites(seed_value: int) -> Array:
	var out: Array = []
	for s: Dictionary in sats():
		var flat := func(x: float, z: float) -> float: return sat_ground(s,x,z)
		var node := island(outline_of(s.c,float(s.r),seed_value+int(s.seed)),7.0+float(s.r),seed_value+int(s.seed),flat,float(s.top))
		node.name = "Isle_"+str(s.note)
		node.set_meta("spec",s)
		out.append(node)
	return out

# --- The rope bridges -----------------------------------------------------------------

## Each rope bridge: {name, a, b (the deck's ends, world), from, to}. The
## hops marked "bridge", and the central isle's from the fourth satellite.
static func bridges() -> Array:
	var out: Array = []
	for hop: Array in HOPS:
		if hop[2] != "bridge": continue
		out.append(_bridge("bridge_%d_%d" % [hop[0],hop[1]],sat(int(hop[0])),sat(int(hop[1]))))
	var s3 := sat(CENTRE_HOP)
	var mid := {"c":C,"r":CENTRE_R*0.88/INSET,"top":centre_top()+0.25,"centre":true}
	out.append(_bridge("bridge_centre",s3,mid))
	return out

static func _bridge(name: String, sa: Dictionary, sb: Dictionary) -> Dictionary:
	var ca: Vector2 = sa.c
	var cb: Vector2 = sb.c
	var dir := (cb-ca).normalized()
	var pa := ca+dir*float(sa.r)*INSET
	var pb := cb-dir*float(sb.r)*INSET
	var ya := sat_ground(sa,pa.x,pa.y) if not sa.has("centre") else centre_ground(pa.x,pa.y)
	var yb := sat_ground(sb,pb.x,pb.y) if not sb.has("centre") else centre_ground(pb.x,pb.y)
	return {"name":name,"a":Vector3(pa.x,ya,pa.y),"b":Vector3(pb.x,yb,pb.y),"from":sa.get("i",-1),"to":sb.get("i",-1)}

# --- The floating stones --------------------------------------------------------------

static var _platforms: Array = []
## Every stone: {name, at (its top's middle, world), size, yaw, kind, chain}.
static func platforms() -> Array:
	if not _platforms.is_empty(): return _platforms
	var out: Array = []
	for hop: Array in HOPS:
		if hop[2] != "stones": continue
		var sa := sat(int(hop[0]))
		var sb := sat(int(hop[1]))
		var ca: Vector2 = sa.c
		var cb: Vector2 = sb.c
		var dir := (cb-ca).normalized()
		var side := Vector2(-dir.y,dir.x)
		# From just inside the first isle's rim to just inside the second's.
		var start := ca+dir*(float(sa.r)*0.96-0.4)
		var end := cb-dir*(float(sb.r)*0.96-0.4)
		var chain := "stones_%d_%d" % [hop[0],hop[1]]
		for k in range(STONES):
			var u := float(k+1)/(STONES+1)
			var p := start.lerp(end,u)+side*0.55*sin(u*PI)*(1.0 if int(hop[0])%2 == 0 else -1.0)
			var y := lerpf(float(sa.top),float(sb.top),u)
			out.append({"name":"%s_%d" % [chain,k+1],"at":Vector3(p.x,y,p.y),"size":Vector3(1.5,0.7 if k%2 == 0 else 0.9,1.7),
				"yaw":atan2(-dir.y,dir.x)+(0.3 if k%2 else -0.2),"kind":"block","chain":chain})
	_platforms = out
	return out

static func platform(name: String) -> Dictionary:
	for p: Dictionary in platforms():
		if p.name == name: return p
	return {}

static func floating_stones(seed_value: int) -> Node3D:
	return Art.floating_stones(seed_value,platforms())

# --- The stone circle and its turret ---------------------------------------------------------

## The circle's gap faces the fourth satellite's bridge; two stones missing
## (of RuinKit.CIRCLE_STONES 8: the back-left pair, 157.5 and 202.5 degrees
## round from the gap).
const MISSING := [3,4]
## The turret stands this far off the circle's middle (away from the fallen trilithon).
const TURRET_AT := Vector2(0.9,0.7)

static func circle_yaw() -> float:
	var d := (sat(CENTRE_HOP).c as Vector2)-C
	return atan2(d.x,d.y)

static func circle_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP,circle_yaw()),Vector3(C.x,centre_top()+0.05,C.y))

## The turret's frame: in the circle, its door to the way in.
static func turret_transform() -> Transform3D:
	var at := circle_transform()*Vector3(TURRET_AT.x,0.0,TURRET_AT.y)
	return Transform3D(Basis(Vector3.UP,circle_yaw()+PI),Vector3(at.x,centre_ground(at.x,at.z)-0.1,at.z))

# --- The ruin notes -------------------------------------------------------------------

## A note stands this far (of the radius) out from the isle's middle, away from the ring's, off the through way.
const NOTE_OUT := 0.42

## The piece each satellite carries: [piece id, seed, weathered, offset (x, z) from the isle's middle, yaw about, count of pair].
static func note_for(s: Dictionary) -> Array:
	match str(s.note):
		"arch": return [["arch",91,0.4,Vector2(0.0,1.0),0.0,0.0]]
		"piers": return [["pier",92,0.7,Vector2(-1.6,0.3),0.4],["pier",93,0.45,Vector2(1.6,-0.2),1.3]]
		"fallen": return [["fallen_pier",94,0.6,Vector2(-0.4,0.2),0.9]]
		"lancet": return [["lancet_wall",95,0.65,Vector2(0.0,-1.0),0.0]]
		"chest": return [["tomb_chest",96,0.5,Vector2(0.3,0.0),0.5]]
		"buttress": return [["buttress",97,0.55,Vector2(0.0,0.0),0.0]]
		"wall": return [["wall",98,0.7,Vector2(0.0,0.0),0.0]]
		"gable": return [["rose_gable",99,0.5,Vector2(0.0,0.0),0.0]]
	return []

## The note's piece frames: [piece id, seed, weathered, Transform3D]. Each
## faces toward the isle's next hop (the spiral's way), its middle on the ground.
static func notes() -> Array:
	var out: Array = []
	for s: Dictionary in sats():
		var i: int = s.i
		var to_next := (sat(i+1).c as Vector2)-(s.c as Vector2) if i < SATS.size()-1 else (C-(s.c as Vector2))
		var across := Vector2(-to_next.y,to_next.x).normalized()
		var base := atan2(to_next.x,to_next.y)
		var outward := ((s.c as Vector2)-C).normalized()
		for spec: Array in note_for(s):
			var off: Vector2 = spec[3]
			var p: Vector2 = (s.c as Vector2)+outward*float(s.r)*NOTE_OUT*(float(spec[5]) if spec.size() > 5 else 1.0)+across*off.x+to_next.normalized()*off.y
			out.append([spec[0],spec[1],spec[2],Transform3D(Basis(Vector3.UP,base+float(spec[4])),Vector3(p.x,sat_ground(s,p.x,p.y)-0.05,p.y))])
	return out

# --- On foot ------------------------------------------------------------------------

## Where the pilot starts: on the lowest isle, looking toward the first hop.
static func start() -> Vector3:
	var s := sat(0)
	var dir := ((sat(1).c as Vector2)-(s.c as Vector2)).normalized()
	var p: Vector2 = (s.c as Vector2)-dir*float(s.r)*0.45
	return Vector3(p.x,sat_ground(s,p.x,p.y),p.y)

static func start_face() -> Vector2:
	return ((sat(1).c as Vector2)-(sat(0).c as Vector2)).normalized()

## The spiral on foot: the points of the walk lowest to highest, [world
## point, how it was reached ("walk", "bridge", "stones", "jump")].
static func spiral() -> Array:
	var out: Array = []
	for hop: Array in HOPS:
		var ends := hop_ends(int(hop[0]),int(hop[1]))
		var sb := sat(int(hop[1]))
		var eb: Vector2 = ends[1]
		out.append({"hop":hop,"to":Vector3(eb.x,sat_ground(sb,eb.x,eb.y),eb.y)})
	return out

# --- The plane's tokens -----------------------------------------------------------------

## The plane's line: [line id, category, kind, points (world)]. A slalom
## through the gaps between the isles, in and out of the ring; under the
## bridges; through the break; over the circle; under the central keel.
static func plane_tokens() -> Array:
	var out: Array = []
	# The gaps between hops, a few metres over the lower side.
	for hop: Array in HOPS:
		var sa := sat(int(hop[0]))
		var sb := sat(int(hop[1]))
		var mid := ((sa.c as Vector2)+(sb.c as Vector2))*0.5
		var y := (float(sa.top)+float(sb.top))*0.5
		match str(hop[2]):
			"bridge":
				var br := _bridge("t",sa,sb)
				var m: Vector3 = (br.a as Vector3).lerp(br.b,0.5)
				out.append(["br:under_%d" % hop[0],"air","thread",[m+Vector3.DOWN*4.5]])
			_:
				out.append(["br:gap_%d" % hop[0],"air","thread",[Vector3(mid.x,y+4.0,mid.y)]])
	# Through the break between the last isle and the first.
	var last := sat(SATS.size()-1)
	var first := sat(0)
	var bm := ((last.c as Vector2)+(first.c as Vector2))*0.5
	out.append(["br:break","air","thread",[Vector3(bm.x,(float(last.top)+float(first.top))*0.5,bm.y)]])
	# Over the circle's lintels and under the central isle's keel.
	out.append(["br:circle","air","thread",[Vector3(C.x,centre_top()+RuinKit.SARSEN.y+RuinKit.LINTEL.y+5.0,C.y)]])
	out.append(["br:keel","under","keel",[Vector3(C.x,centre_top()-26.0,C.y)]])
	return out
