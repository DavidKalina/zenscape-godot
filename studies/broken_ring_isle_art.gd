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
##
## A family (scripts/kit_isle/motif_broken_ring.gd, docs/design/roguelike/
## motif-families.md): every layout function takes a plan (`rolled`: how
## many isles, their angles, radii and rises, the hops, the centre's hop,
## the circle's missing stones), the authored tables below when none is
## given (`authored`), so the studies, the life and the sky read the
## authored isle as before.
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

# --- The plan -----------------------------------------------------------------------

## The ring's seed the authored tables are (the motif's RING_SEED).
const AUTHORED_SEED := 81
static var _authored: Dictionary = {}
## The authored plan: {seed, sats (as SATS), hops (as HOPS), centre_hop,
## centre_rise, missing}; the layout caches ride in it ("_sats"...).
static func authored() -> Dictionary:
	if _authored.is_empty():
		_authored = {"seed":AUTHORED_SEED,"sats":SATS,"hops":HOPS,"centre_hop":CENTRE_HOP,"centre_rise":CENTRE_RISE,"missing":MISSING}
	return _authored

static func _p(p: Dictionary) -> Dictionary:
	return authored() if p.is_empty() else p

## The satellites' isles are built from the ring's seed and this
## (`satellites`), so a plan knows their outlines before they stand.
const SAT_SEED := 20
## The notes a rolled ring hands out (the summit keeps the gable).
const NOTES := ["arch","piers","fallen","lancet","chest","buttress","wall"]
## A rolled hop's rim-to-rim sky and its rise, from the pilot's own reach
## (`rolled`'s `hop`, his running hop, and `jump`, his small jump's
## height), at climb 1 no more than the authored hops': a jump's sky a
## share of his hop (GAP_JUMP; the authored 2.6 m is 1.1), its rise a
## share of his jump; a stones hop STONES+1 strides each a share of his
## hop (GAP_STONES), each stride rising a share of his jump (RISE_STONES:
## the authored stones climb 1.08 m a stone); a bridge's sky past two hops
## (GAP_BRIDGE), its rise metres of deck slope (RISE_BRIDGE, the authored 3).
const GAP_JUMP := Vector2(1.0,1.1)
const RISE_JUMP := Vector2(0.0,0.75)
const GAP_STONES := Vector2(0.72,0.84)
const RISE_STONES := Vector2(1.05,1.35)
const GAP_BRIDGE := Vector2(1.95,2.7)
const RISE_BRIDGE := Vector2(2.4,3.0)
## The circle's stones a rolled ring may lose, by how many (RuinKit
## `stone_circle`): one run of them, never the gate's (0, 7) nor the
## leaning stone's (1), and only runs that leave the circle a lintel it
## may drop (its weathering's).
const GONE_RUNS := [[[]],[[2],[3],[4],[5],[6]],[[2,3],[3,4],[5,6]],[[2,3,4]]]
## The break between the last isle and the first: past this many hops.
const BREAK_HOPS := 3.0
## The ring's distance from C (m): the authored isles', out to RING_MOST
## when the hops would close the break.
const RING := 26.0
const RING_MOST := 30.0

## A plan rolled from `seed_value` and `knobs` (scripts/kit_isle/
## motif_broken_ring.gd `knob_choices`: isles, jumps, climb, missing),
## with `hop` the pilot's running hop (m) and `jump` his small jump's
## height: the hops' kinds, rises and radii from the seed, each isle's
## angle solved round the ring so its rim stands the hop's sky from the
## last (their outlines as `satellites` builds them), the ring pushed out
## (to RING_MOST) and the bridges' and stones' skies drawn in until the
## break stays wider than BREAK_HOPS hops. Same seed and knobs, the same
## plan.
static func rolled(seed_value: int, knobs: Dictionary, hop: float, jump: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*7919+1013
	var n: int = clampi(int(knobs.isles),3,SATS.size())
	var climb: float = float(knobs.climb)
	# The hops: `jumps` of them jumps (never the first), the rest bridges and
	# stones, a coin each, never three alike in a row.
	var kinds: Array = []
	for i in range(n-1): kinds.append("")
	var spots: Array = range(1,n-1)
	for i in range(spots.size()):
		var j := rng.randi_range(i,spots.size()-1)
		var t: Variant = spots[i]
		spots[i] = spots[j]
		spots[j] = t
	for k in range(mini(int(knobs.jumps),spots.size())): kinds[spots[k]] = "jump"
	for i in range(kinds.size()):
		if kinds[i] != "": continue
		var kind := "bridge" if rng.randf() < 0.5 else "stones"
		if i >= 2 and kinds[i-1] == kind and kinds[i-2] == kind: kind = "stones" if kind == "bridge" else "bridge"
		kinds[i] = kind
	var rises: Array = [0.0]
	var radii: Array = []
	var gaps: Array = []
	for i in range(n): radii.append(snappedf(rng.randf_range(6.0,7.6),0.1))
	for i in range(n-1):
		var rise := 0.0
		match str(kinds[i]):
			"jump":
				rise = jump*rng.randf_range(RISE_JUMP.x,RISE_JUMP.y)
				gaps.append(hop*rng.randf_range(GAP_JUMP.x,GAP_JUMP.y))
			"bridge":
				rise = climb*rng.randf_range(RISE_BRIDGE.x,RISE_BRIDGE.y)
				gaps.append(hop*rng.randf_range(GAP_BRIDGE.x,GAP_BRIDGE.y))
			_:
				rise = climb*(STONES+1)*jump*rng.randf_range(RISE_STONES.x,RISE_STONES.y)
				gaps.append((STONES+1)*hop*rng.randf_range(GAP_STONES.x,GAP_STONES.y))
		rises.append(float(rises[i])+snappedf(rise,0.1))
	var names: Array = NOTES.duplicate()
	for i in range(names.size()):
		var j := rng.randi_range(i,names.size()-1)
		var t: Variant = names[i]
		names[i] = names[j]
		names[j] = t
	names = names.slice(0,n-1)
	names.append("gable")
	var start := float(SATS[0][1])
	var angles: Array = []
	var ring := RING
	var draw_in := 1.0
	for attempt in range(40):
		angles = [start]
		for i in range(n-1):
			var target: float = gaps[i] if kinds[i] == "jump" else float(gaps[i])*draw_in
			angles.append(_solve_angle(seed_value,float(angles[i]),i,ring,radii,target))
		var last := float(angles[n-1])
		var round_gap := _rim_gap(seed_value,last,n-1,start+360.0,0,ring,radii)
		if last-start < 330.0 and round_gap > BREAK_HOPS*hop: break
		if ring < RING_MOST: ring += 1.0
		else: draw_in = maxf(draw_in-0.04,0.5)
	var sats_table: Array = []
	for i in range(n):
		sats_table.append([names[i],fposmod(float(angles[i]),360.0),ring,radii[i],rises[i]])
	var hops_table: Array = []
	for i in range(n-1): hops_table.append([i,i+1,kinds[i]])
	var centre := clampi(roundi((n-1)*0.43),1,n-2)
	# The circle's missing stones: one run of them, from its back and sides.
	var runs: Array = GONE_RUNS[clampi(int(knobs.missing),0,GONE_RUNS.size()-1)]
	var gone: Array = runs[rng.randi_range(0,runs.size()-1)]
	return {"seed":seed_value,"sats":sats_table,"hops":hops_table,"centre_hop":centre,
		"centre_rise":float(rises[centre])+CENTRE_RISE-float(SATS[CENTRE_HOP][4]),"missing":gone}

## The angle (degrees) round C that stands isle `i+1` `target` m of sky
## past isle `i` at `from`, rim to rim (bisected; the angle grows the gap).
static func _solve_angle(seed_value: int, from: float, i: int, ring: float, radii: Array, target: float) -> float:
	var lo := from+4.0
	var hi := from+120.0
	for k in range(30):
		var mid := (lo+hi)*0.5
		if _rim_gap(seed_value,from,i,mid,i+1,ring,radii) < target: lo = mid
		else: hi = mid
	return (lo+hi)*0.5

## The sky between isle `i` at angle `a` and isle `j` at angle `b` along
## the line between their middles, their outlines as `satellites` builds
## them from the ring's seed.
static func _rim_gap(seed_value: int, a: float, i: int, b: float, j: int, ring: float, radii: Array) -> float:
	var ca := C+Vector2.from_angle(deg_to_rad(a))*ring
	var cb := C+Vector2.from_angle(deg_to_rad(b))*ring
	var pa := PackedVector2Array(outline_of(ca,float(radii[i]),seed_value+SAT_SEED+71+i))
	var pb := PackedVector2Array(outline_of(cb,float(radii[j]),seed_value+SAT_SEED+71+j))
	var way := cb-ca
	return way.length()-_reach_out(pa,ca,way.normalized())-_reach_out(pb,cb,-way.normalized())

## How far from `c` along `way` its outline `poly` reaches.
static func _reach_out(poly: PackedVector2Array, c: Vector2, way: Vector2) -> float:
	var best := 0.0
	var far := c+way*100.0
	for k in range(poly.size()):
		var hit: Variant = Geometry2D.segment_intersects_segment(c,far,poly[k],poly[(k+1)%poly.size()])
		if hit != null: best = maxf(best,c.distance_to(hit))
	return best

static func hops(p := {}) -> Array:
	return _p(p).hops

static func missing(p := {}) -> Array:
	return _p(p).missing

static func centre_hop(p := {}) -> int:
	return int(_p(p).centre_hop)

# --- The isles ---------------------------------------------------------------------

## The satellites: {i, note, c (world x, z), r, top (y), ang, seed}.
static func sats(p := {}) -> Array:
	p = _p(p)
	if p.has("_sats"): return p._sats
	var out: Array = []
	var table: Array = p.sats
	for i in range(table.size()):
		var s: Array = table[i]
		var c := C+Vector2.from_angle(deg_to_rad(float(s[1])))*float(s[2])
		out.append({"i":i,"note":s[0],"c":c,"r":float(s[3]),"top":W+float(s[4]),"ang":float(s[1]),"seed":71+i})
	p._sats = out
	return out

static func sat(i: int, p := {}) -> Dictionary:
	return sats(p)[i]

static func count(p := {}) -> int:
	return (_p(p).sats as Array).size()

static func centre_top(p := {}) -> float:
	return W+float(_p(p).centre_rise)

## The highest turf's top (the summit isle's).
static func summit_y(p := {}) -> float:
	return float(sat(count(p)-1,p).top)+SWELL

## A satellite's ground at world (x, z): its top, a low swell in its middle.
static func sat_ground(s: Dictionary, x: float, z: float) -> float:
	var e := Vector2(x,z).distance_to(s.c)/float(s.r)
	return float(s.top)+SWELL*(1.0-smoothstep(0.0,1.0,e))

## The central isle's ground: flat, a low swell, the circle on it.
static func centre_ground(x: float, z: float, p := {}) -> float:
	var e := Vector2(x,z).distance_to(C)/CENTRE_R
	return centre_top(p)+0.25*(1.0-smoothstep(0.0,1.0,e))

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
static func paths(p := {}) -> Array:
	var out: Array = []
	for hop: Array in hops(p):
		var ends := hop_ends(int(hop[0]),int(hop[1]),p)
		out.append([ends[0],ends[1]])
	var s3 := sat(centre_hop(p),p)
	var ca: Vector2 = s3.c
	var dir := (C-ca).normalized()
	out.append([ca+dir*float(s3.r)*INSET,C-dir*CENTRE_R*0.85,C-dir*2.0])
	return out

## Where a hop's two ends stand, each INSET in from the isle's middle toward
## the other: [a (x, z), b (x, z)].
static func hop_ends(from: int, to: int, p := {}) -> Array:
	var sa := sat(from,p)
	var sb := sat(to,p)
	var dir := ((sb.c as Vector2)-(sa.c as Vector2)).normalized()
	return [(sa.c as Vector2)+dir*float(sa.r)*INSET,(sb.c as Vector2)-dir*float(sb.r)*INSET]

static func path_wear(at: Vector2, p := {}) -> float:
	p = _p(p)
	if not p.has("_wear"): p._wear = KitLand.wear_of(paths(p))
	return float((p._wear as Callable).call(at))

## An island (the kit isles' shared builder, scripts/kit_isle/kit_land.gd):
## its top over `flat`, its sides and keel of hanging rock `depth` under it.
static func island(outline_points: Array, depth: float, seed_value: int, flat: Callable, top: float, p := {}) -> Node3D:
	var spec := {"outline":outline_points,"depth":depth,"seed":seed_value,"ground":flat,"top":top,"hang":true,
		"tone":KitLook.turf(seed_value,func(at: Vector2) -> float: return path_wear(at,p))}
	return KitLand.island(spec)

static func central(seed_value: int, p := {}) -> Node3D:
	var node := island(outline_of(C,CENTRE_R,seed_value),24.0,seed_value,func(x: float, z: float) -> float: return centre_ground(x,z,p),centre_top(p),p)
	node.name = "CentralIsle"
	return node

## A satellite's outline (its isle built from `seed_value`, the motif's).
static func sat_outline(s: Dictionary, seed_value: int) -> Array:
	return outline_of(s.c,float(s.r),seed_value+int(s.seed))

static func satellites(seed_value: int, p := {}) -> Array:
	var out: Array = []
	for s: Dictionary in sats(p):
		var flat := func(x: float, z: float) -> float: return sat_ground(s,x,z)
		var node := island(sat_outline(s,seed_value),7.0+float(s.r),seed_value+int(s.seed),flat,float(s.top),p)
		node.name = "Isle_"+str(s.note)
		node.set_meta("spec",s)
		out.append(node)
	return out

# --- The rope bridges -----------------------------------------------------------------

## Each rope bridge: {name, a, b (the deck's ends, world), from, to}. The
## hops marked "bridge", and the central isle's from the fourth satellite.
static func bridges(p := {}) -> Array:
	var out: Array = []
	for hop: Array in hops(p):
		if hop[2] != "bridge": continue
		out.append(_bridge("bridge_%d_%d" % [hop[0],hop[1]],sat(int(hop[0]),p),sat(int(hop[1]),p),p))
	var s3 := sat(centre_hop(p),p)
	var mid := {"c":C,"r":CENTRE_R*0.88/INSET,"top":centre_top(p)+0.25,"centre":true}
	out.append(_bridge("bridge_centre",s3,mid,p))
	return out

static func _bridge(name: String, sa: Dictionary, sb: Dictionary, p := {}) -> Dictionary:
	var ca: Vector2 = sa.c
	var cb: Vector2 = sb.c
	var dir := (cb-ca).normalized()
	var pa := ca+dir*float(sa.r)*INSET
	var pb := cb-dir*float(sb.r)*INSET
	var ya := sat_ground(sa,pa.x,pa.y) if not sa.has("centre") else centre_ground(pa.x,pa.y,p)
	var yb := sat_ground(sb,pb.x,pb.y) if not sb.has("centre") else centre_ground(pb.x,pb.y,p)
	return {"name":name,"a":Vector3(pa.x,ya,pa.y),"b":Vector3(pb.x,yb,pb.y),"from":sa.get("i",-1),"to":sb.get("i",-1)}

# --- The floating stones --------------------------------------------------------------

## Every stone: {name, at (its top's middle, world), size, yaw, kind, chain}.
static func platforms(p := {}) -> Array:
	p = _p(p)
	if p.has("_platforms"): return p._platforms
	var out: Array = []
	for hop: Array in hops(p):
		if hop[2] != "stones": continue
		var sa := sat(int(hop[0]),p)
		var sb := sat(int(hop[1]),p)
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
			var q := start.lerp(end,u)+side*0.55*sin(u*PI)*(1.0 if int(hop[0])%2 == 0 else -1.0)
			var y := lerpf(float(sa.top),float(sb.top),u)
			out.append({"name":"%s_%d" % [chain,k+1],"at":Vector3(q.x,y,q.y),"size":Vector3(1.5,0.7 if k%2 == 0 else 0.9,1.7),
				"yaw":atan2(-dir.y,dir.x)+(0.3 if k%2 else -0.2),"kind":"block","chain":chain})
	p._platforms = out
	return out

static func platform(name: String, p := {}) -> Dictionary:
	for stone: Dictionary in platforms(p):
		if stone.name == name: return stone
	return {}

static func floating_stones(seed_value: int, p := {}) -> Node3D:
	return Art.floating_stones(seed_value,platforms(p))

# --- The stone circle and its turret ---------------------------------------------------------

## The circle's gap faces the fourth satellite's bridge; two stones missing
## (of RuinKit.CIRCLE_STONES 8: the back-left pair, 157.5 and 202.5 degrees
## round from the gap).
const MISSING := [3,4]
## The turret stands this far off the circle's middle (away from the fallen trilithon).
const TURRET_AT := Vector2(0.9,0.7)

static func circle_yaw(p := {}) -> float:
	var d := (sat(centre_hop(p),p).c as Vector2)-C
	return atan2(d.x,d.y)

static func circle_transform(p := {}) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,circle_yaw(p)),Vector3(C.x,centre_top(p)+0.05,C.y))

## The turret's frame: in the circle, its door to the way in.
static func turret_transform(p := {}) -> Transform3D:
	var at := circle_transform(p)*Vector3(TURRET_AT.x,0.0,TURRET_AT.y)
	return Transform3D(Basis(Vector3.UP,circle_yaw(p)+PI),Vector3(at.x,centre_ground(at.x,at.z,p)-0.1,at.z))

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
static func notes(p := {}) -> Array:
	var out: Array = []
	for s: Dictionary in sats(p):
		var i: int = s.i
		var to_next := (sat(i+1,p).c as Vector2)-(s.c as Vector2) if i < count(p)-1 else (C-(s.c as Vector2))
		var across := Vector2(-to_next.y,to_next.x).normalized()
		var base := atan2(to_next.x,to_next.y)
		var outward := ((s.c as Vector2)-C).normalized()
		for spec: Array in note_for(s):
			var off: Vector2 = spec[3]
			var q: Vector2 = (s.c as Vector2)+outward*float(s.r)*NOTE_OUT*(float(spec[5]) if spec.size() > 5 else 1.0)+across*off.x+to_next.normalized()*off.y
			out.append([spec[0],spec[1],spec[2],Transform3D(Basis(Vector3.UP,base+float(spec[4])),Vector3(q.x,sat_ground(s,q.x,q.y)-0.05,q.y))])
	return out

# --- On foot ------------------------------------------------------------------------

## Where the pilot starts: on the lowest isle, looking toward the first hop.
static func start(p := {}) -> Vector3:
	var s := sat(0,p)
	var dir := ((sat(1,p).c as Vector2)-(s.c as Vector2)).normalized()
	var q: Vector2 = (s.c as Vector2)-dir*float(s.r)*0.45
	return Vector3(q.x,sat_ground(s,q.x,q.y),q.y)

static func start_face(p := {}) -> Vector2:
	return ((sat(1,p).c as Vector2)-(sat(0,p).c as Vector2)).normalized()

## The spiral on foot: the points of the walk lowest to highest, [world
## point, how it was reached ("walk", "bridge", "stones", "jump")].
static func spiral(p := {}) -> Array:
	var out: Array = []
	for hop: Array in hops(p):
		var ends := hop_ends(int(hop[0]),int(hop[1]),p)
		var sb := sat(int(hop[1]),p)
		var eb: Vector2 = ends[1]
		out.append({"hop":hop,"to":Vector3(eb.x,sat_ground(sb,eb.x,eb.y),eb.y)})
	return out

# --- The plane's tokens -----------------------------------------------------------------

## The plane's line: [line id, category, kind, points (world)]. A slalom
## through the gaps between the isles, in and out of the ring; under the
## bridges; through the break; over the circle; under the central keel.
static func plane_tokens(p := {}) -> Array:
	var out: Array = []
	# The gaps between hops, a few metres over the lower side.
	for hop: Array in hops(p):
		var sa := sat(int(hop[0]),p)
		var sb := sat(int(hop[1]),p)
		var mid := ((sa.c as Vector2)+(sb.c as Vector2))*0.5
		var y := (float(sa.top)+float(sb.top))*0.5
		match str(hop[2]):
			"bridge":
				var br := _bridge("t",sa,sb,p)
				var m: Vector3 = (br.a as Vector3).lerp(br.b,0.5)
				out.append(["br:under_%d" % hop[0],"air","thread",[m+Vector3.DOWN*4.5]])
			_:
				out.append(["br:gap_%d" % hop[0],"air","thread",[Vector3(mid.x,y+4.0,mid.y)]])
	# Through the break between the last isle and the first.
	var last := sat(count(p)-1,p)
	var first := sat(0,p)
	var bm := ((last.c as Vector2)+(first.c as Vector2))*0.5
	out.append(["br:break","air","thread",[Vector3(bm.x,(float(last.top)+float(first.top))*0.5,bm.y)]])
	# Over the circle's lintels and under the central isle's keel.
	out.append(["br:circle","air","thread",[Vector3(C.x,centre_top(p)+RuinKit.SARSEN.y+RuinKit.LINTEL.y+5.0,C.y)]])
	out.append(["br:keel","under","keel",[Vector3(C.x,centre_top(p)-26.0,C.y)]])
	return out
