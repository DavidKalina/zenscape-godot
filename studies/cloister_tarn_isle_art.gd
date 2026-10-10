extends RefCounted
## The cloister tarn's art (studies/cloister_tarn_isle.gd): the mother isle,
## a crater bowl ringing a still tarn; the cloister round the tarn; the
## satellite isles round the mother, their rope bridges and the floating
## stones between them; the tarn's water and its curtain fall.
##
## The mother isle (round C, world x, z) is one heightfield (`ground`):
##   the tarn, a round bowl (TARN wandering) its bed shelving to DEEP under
##     the water at W, a little isle in it (SHRINE) with the lavabo on it;
##   the garth, a grass bank from the shore up to the cloister walk (K);
##   the alley, the cloister's walk, level at K, a square ring between the
##     arcade (ARC, its centreline, Chebyshev from C) and its back (BACK);
##   the rim, a rounded square crest (RIM in a superellipse's metric) whose
##     height above K wanders round it (`crest`): a crag of tiered rock to
##     the north-west (CRAG_TOP, its summit a vista, the kit's stair up the
##     last of its ridge), a terrace to the south level with the
##     arcade's wall-walk (a slab bridge across the alley onto it), a low
##     saddle west (the plane comes in over it), and a notch east where the
##     tarn spills through the cloister's water gate down a channel and off
##     the edge as a wide curtain fall;
##   its outer flank falling to the island's edge (`edge`), where three
##     rope bridges leave for the satellites.
## Where the rim stands high behind the alley its inner face is rock in
## tiers (TIER m each, a jump-catch apart): an expert's climb out of the
## cloister; low, it is a slope walked up.
##
## Angles (`t`, degrees) run counterclockwise seen from above from east:
## east 0, north (-z) 90, west 180, south 270.
const Art = preload("res://studies/aqueduct_isle_art.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Cloister = preload("res://scripts/ruin_kit_cloister.gd")
const Build = RuinKit.Build
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyFallThread = preload("res://scripts/sky_fall_thread.gd")
const FlowFalls = preload("res://scripts/flow_falls.gd")

## The mother's middle (world x, z), the tarn's level, the walk's (K).
const C := Vector2(80.0,0.0)
const W := 30.0
const TOP := W
const K := W+0.5
## The cloister: the arcade's centreline (half the square's side), its
## half thickness, the alley's width, the alley's outer side (BACK).
const ARC := 12.6
const ARC_D := Cloister.THICK*0.5
const ALLEY := 2.8
const BACK := ARC+ARC_D+ALLEY
## The wall-walk's top over K, and the water gate's (over the spill).
const WALK := Cloister.WALK
const GATE_WALK := WALK+0.38
## The piers along a range (corner to corner) and the east range's (the
## water gate the middle bay, wide enough for the plane).
const PIERS := [-12.6,-9.0,-5.4,-1.8,1.8,5.4,9.0,12.6]
const EAST_PIERS := [-12.6,-9.3,-6.0,-2.7,2.7,6.0,9.3,12.6]
## The west range's fallen bays (the cloister's gap) and its two stubs.
const FALLEN := [2,3,4]
const STUBS := {3:3.0,4:2.4}
## The tarn: radius (wandering), its shelf, its deep; the spill channel's
## half width (east), its bed under the water.
const TARN := 10.6
const SHELF := 1.2
const DEEP := 2.6
const CH := 2.0
const CHANNEL_BED := 0.45
## The isle in the tarn (local x, z), its flat top's radius, its beach.
const SHRINE := Vector2(1.0,-4.4)
const SHRINE_TOP := W+0.55
const SHRINE_FLAT := 3.4
const SHRINE_BEACH := 4.4
## The lavabo: pier to pier; its walked top over its foot.
const LAVABO := 3.0
## The rim: the crest's distance (superellipse, exponent RIM_P), its flat
## top's half width, the crag's.
const RIM := 23.0
const RIM_P := 3.0
const CREST_W := 1.4
const CRAG_W := 2.6
## The crag: its summit plateau over K, and the kit stair's foot band (the
## ridge's last rise is the kit's flight, STAIR_HEAD to STAIR_FOOT degrees).
const CRAG_TOP := 10.0
const STAIR_RISE := RuinKit.STEPS*RuinKit.RISER
const KIT_RUN := (RuinKit.STEPS-1)*RuinKit.TREAD+RuinKit.LANDING
const STAIR_HEAD := 138.0
const STAIR_FOOT := 148.4
## Rock tiers on the rim's high inner face: each this high at most.
const TIER := 1.5
## The south terrace (degrees) level with the wall-walk.
const TERRACE := Vector2(250.0,290.0)
## The crest round the rim: [t, crest over K, edge over K].
const CREST := [
	[0.0,1.0,0.4],[25.0,2.6,1.4],[47.0,5.0,3.6],[75.0,7.5,4.5],[100.0,9.0,5.0],[116.0,CRAG_TOP,6.0],
	[STAIR_HEAD,CRAG_TOP,6.0],[STAIR_FOOT+2.6,CRAG_TOP-STAIR_RISE,4.5],[180.0,3.0,1.6],[205.0,3.8,1.4],[228.0,4.0,0.9],
	[TERRACE.x,WALK,1.4],[TERRACE.y,WALK,1.5],[305.0,3.4,1.0],[335.0,2.0,0.6],[360.0,1.0,0.4]]

## The satellites: [name, middle (local x, z), radius, top over K, seed].
const SATELLITES := [
	["west",Vector2(-44.0,0.5),5.2,2.2,61],
	["southwest",Vector2(-31.6,32.7),5.4,-1.6,62],
	["northeast",Vector2(31.0,-33.3),5.8,6.6,63],
	["north",Vector2(-3.6,-43.0),4.8,8.6,64],
]
## The rope bridges: [name, the mother's end (angle t), the satellite].
const BRIDGES := [["west_bridge",180.0,"west"],["southwest_bridge",228.0,"southwest"],["northeast_bridge",47.0,"northeast"]]
## The stones' chains: [chain, from (local x, z, top over K), to, count].
## The north chain: down from the crag's summit to the north isle and on to
## the north-east isle; the west chain: down from the west isle to the
## south-west one.
const KEEL := 30.0

# --- The angles and metrics -----------------------------------------------------------

static func local(x: float, z: float) -> Vector2:
	return Vector2(x-C.x,z-C.y)

static func world(l: Vector2) -> Vector2:
	return C+l

## The angle (degrees) of local `d` from C.
static func angle(d: Vector2) -> float:
	return fposmod(rad_to_deg(atan2(-d.y,d.x)),360.0)

## The local unit way at angle `t`.
static func way(t: float) -> Vector2:
	var a := deg_to_rad(t)
	return Vector2(cos(a),-sin(a))

## The superellipse's scale along unit way `u`: the rim at distance RIM in
## its metric is RIM/n(u) along u.
static func sq(u: Vector2) -> float:
	return pow(pow(absf(u.x),RIM_P)+pow(absf(u.y),RIM_P),1.0/RIM_P)

static func cheb(d: Vector2) -> float:
	return maxf(absf(d.x),absf(d.y))

## The tarn's radius at angle `t`.
static func tarn_r(t: float) -> float:
	var a := deg_to_rad(t)
	return TARN+0.4*sin(3.0*a+1.0)+0.25*sin(5.0*a+2.2)

## The island's edge (local distance from C) at angle `t`: wider at the
## corners, wandering.
static func edge_r(t: float) -> float:
	var a := deg_to_rad(t)
	return 28.6+2.4*pow(absf(sin(2.0*a)),1.2)+0.9*sin(3.0*a+1.0)+0.5*sin(7.0*a+2.0)

## The crest's height over K and the edge's at angle `t`, from CREST.
static func crest(t: float) -> Vector2:
	t = fposmod(t,360.0)
	# The kit stair's band: level at its foot, the plateau sheer at its head.
	if t >= STAIR_HEAD and t <= STAIR_FOOT+2.6: return Vector2(CRAG_TOP-STAIR_RISE,lerpf(6.0,4.5,(t-STAIR_HEAD)/(STAIR_FOOT+2.6-STAIR_HEAD)))
	for i in range(CREST.size()-1):
		var a: Array = CREST[i]
		var b: Array = CREST[i+1]
		if t >= float(a[0]) and t <= float(b[0]):
			var u := smoothstep(float(a[0]),float(b[0]),t)
			return Vector2(lerpf(float(a[1]),float(b[1]),u),lerpf(float(a[2]),float(b[2]),u))
	return Vector2(CREST[0][1],CREST[0][2])

static func crest_w(t: float) -> float:
	return CRAG_W if t >= 108.0 and t <= 156.0 else CREST_W

# --- The ground -----------------------------------------------------------------------

## The mother's ground at world (x, z).
static func ground(x: float, z: float) -> float:
	var d := local(x,z)
	var r := d.length()
	var t := angle(d)
	var q := cheb(d)
	var h := _ground(d,r,t,q)
	# The spill channel: east from the tarn's shelf to the lip.
	if d.x > 0.0 and absf(d.y) < CH and r > tarn_r(t)-SHELF: h = minf(h,W-CHANNEL_BED)
	return h

static func _ground(d: Vector2, r: float, t: float, q: float) -> float:
	if q < ARC-ARC_D:
		var rw := tarn_r(t)
		var h: float
		if r < rw:
			var e := rw-r
			h = W-0.25*e/SHELF if e < SHELF else W-0.25-(DEEP-0.25)*smoothstep(SHELF,SHELF+3.3,e)
		else:
			h = W+0.05+(K-W-0.05)*smoothstep(0.0,1.6,r-rw)
		var s := d.distance_to(SHRINE)
		if s < SHRINE_BEACH:
			var top := SHRINE_TOP if s < SHRINE_FLAT else lerpf(SHRINE_TOP,W-0.5,smoothstep(SHRINE_FLAT,SHRINE_BEACH,s))
			h = maxf(h,top)
		return h
	if q < BACK: return K
	return rim(d,r,t)

## The rim outside the alley at local `d`.
static func rim(d: Vector2, r: float, t: float) -> float:
	var u := d/maxf(r,0.001)
	var m := maxf(absf(u.x),absf(u.y))
	var rb := BACK/m
	var cw := crest_w(t)
	var rc := RIM/sq(u)
	var ri := maxf(rc-cw,rb+1.0)
	var ro := rc+cw
	var hc := crest(t)
	var top := hc.x
	var re := edge_r(t)
	if r >= ri and r <= ro: return K+top
	if r > ro:
		var v := clampf((r-ro)/maxf(re-ro,0.5),0.0,1.0)
		return K+lerpf(top,hc.y,pow(v,1.5))
	# The inner face: the south terrace level; high, rock in tiers; low, a
	# slope.
	if t >= TERRACE.x and t <= TERRACE.y: return K+WALK
	var f := clampf((r-rb)/(ri-rb),0.0,1.0)
	if top <= 5.2: return K+top*smoothstep(0.0,1.0,f)
	var n := ceili(top/TIER)
	# The ledges wander a little round the rim, never one width all round.
	var wob := 0.08*sin(deg_to_rad(t)*7.0+float(n))
	var k := mini(int(floor(clampf(f+wob,0.0,0.999)*n)),n-1)
	return K+top*float(k+1)/n

## The island's outline (world), CCW seen from above.
static func outline() -> Array:
	var out: Array = []
	for i in range(120):
		var t := 360.0*i/120.0
		out.append(world(way(t)*edge_r(t)))
	return out

## How worn the ground is at world `p` (0 off the paths, 1 on their middle).
static var _paths: Array = []
static func path_wear(p: Vector2) -> float:
	if _paths.is_empty(): _paths = paths()
	var best := INF
	for path: Array in _paths:
		for i in range(path.size()-1):
			best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[i],path[i+1])))
	return clampf(1.25-best/1.5,0.0,1.0)

## The worn paths (world polylines): round the alley; up the south-east
## slope and along the crest to the terrace; from the west door up over
## the saddle to the west bridge and along the ridge to the crag's stair;
## to the other bridges.
static func paths() -> Array:
	var out: Array = []
	var mid := ARC+ARC_D+ALLEY*0.5
	var ring: Array = []
	for c: Vector2 in [Vector2(1,1),Vector2(1,-1),Vector2(-1,-1),Vector2(-1,1),Vector2(1,1)]: ring.append(world(c*mid))
	out.append(ring)
	var crest_line := func(t0: float, t1: float) -> Array:
		var line: Array = []
		var steps := maxi(2,int(absf(t1-t0)/5.0))
		for i in range(steps+1):
			var t := lerpf(t0,t1,float(i)/steps)
			line.append(world(way(t)*RIM/sq(way(t))))
		return line
	var se: Array = [world(Vector2(mid,mid))]
	se.append_array(crest_line.call(318.0,272.0))
	out.append(se)
	var w: Array = [world(Vector2(-mid,0.0)),world(Vector2(-RIM,0.0))]
	w.append_array(crest_line.call(180.0,STAIR_FOOT+1.0))
	out.append(w)
	out.append([world(Vector2(-RIM,0.0)),world(way(180.0)*(edge_r(180.0)-1.0))])
	for b: Array in BRIDGES:
		if b[0] == "west_bridge": continue
		out.append([world(way(float(b[1]))*RIM/sq(way(float(b[1])))),world(way(float(b[1]))*(edge_r(float(b[1]))-1.0))])
	return out

## True where the ground is under the water (or at its edge): the tarn, the
## channel.
static func wet(p: Vector2) -> bool:
	return ground(p.x,p.y) < W+0.15 and local(p.x,p.y).length() < edge_r(angle(local(p.x,p.y)))+0.5

## Kept bare by the flora: the worn paths, the water and its edge.
static func bare(p: Vector2) -> float:
	if wet(p): return 1.0
	return path_wear(p)

# --- The satellites ---------------------------------------------------------------

static func satellite(name: String) -> Array:
	for s: Array in SATELLITES:
		if s[0] == name: return s
	return []

## A satellite's ground at world (x, z): its top, a low swell in its middle.
static func satellite_ground(spec: Array, x: float, z: float) -> float:
	var m: Vector2 = world(spec[1])
	var e := Vector2(x,z).distance_to(m)/float(spec[2])
	return K+float(spec[3])+0.45*(1.0-smoothstep(0.0,1.0,e))

static func satellite_outline(spec: Array) -> Array:
	return Art.blob(world(spec[1]),float(spec[2]),int(spec[4]))

# --- The rope bridges ---------------------------------------------------------------

## Each rope bridge: {name, a, b (the deck's ends, world, on the stone
## heads' fronts), heads: [[at (top middle), yaw (the head's +Z toward the
## bridge)]...]}. The mother's head stands in from its edge at angle `t`,
## the satellite's in from its rim toward the mother.
static func bridges() -> Array:
	var out: Array = []
	for spec: Array in BRIDGES:
		var t: float = spec[1]
		var sat := satellite(spec[2])
		var u := way(t)
		var m_at := world(u*(edge_r(t)-1.4))
		var s_mid: Vector2 = world(sat[1])
		var toward := (m_at-s_mid).normalized()
		var s_at := s_mid+toward*(float(sat[2])-1.7)
		var across := (s_at-m_at)
		var dir := across.normalized()
		var hz := Cloister.ABUTMENT.z*0.5
		var m_top := ground(m_at.x,m_at.y)
		var s_top := satellite_ground(sat,s_at.x,s_at.y)
		var a := Vector3(m_at.x+dir.x*hz,m_top,m_at.y+dir.y*hz)
		var b := Vector3(s_at.x-dir.x*hz,s_top,s_at.y-dir.y*hz)
		out.append({"name":spec[0],"a":a,"b":b,"to":spec[2],
			"heads":[[Vector3(m_at.x,m_top,m_at.y),atan2(dir.x,dir.y)],[Vector3(s_at.x,s_top,s_at.y),atan2(-dir.x,-dir.y)]]})
	return out

# --- The floating stones --------------------------------------------------------------

## Every stone stood or floated on: {name, at (its top's middle, world),
## size, yaw, kind, chain, grounded?}.
static var _platforms: Array = []
static func platforms() -> Array:
	if not _platforms.is_empty(): return _platforms
	var out: Array = []
	# The north chain: from the crag's summit down to the north isle, and on
	# down to the north-east isle.
	var summit := way(126.0)*RIM/sq(way(126.0))
	var north: Array = satellite("north")
	var ne: Array = satellite("northeast")
	_chain(out,"north",summit,K+CRAG_TOP,CRAG_W+0.3,north[1],K+float(north[3])+0.45,float(north[2])-0.4,4,0.0)
	_chain(out,"northeast",north[1],K+float(north[3])+0.45,float(north[2])-0.4,ne[1],K+float(ne[3])+0.45,float(ne[2])-0.4,7,0.6)
	var west: Array = satellite("west")
	var sw: Array = satellite("southwest")
	_chain(out,"west",west[1],K+float(west[3])+0.45,float(west[2])-0.4,sw[1],K+float(sw[3])+0.45,float(sw[2])-0.4,6,-0.5)
	# Stepping stones over the tarn from the garth's north-west corner to the
	# little isle.
	var from := Vector2(-8.4,-8.8)
	var to := SHRINE+(from-SHRINE).normalized()*(SHRINE_FLAT+0.9)
	for i in range(3):
		var p := world(from.lerp(to,float(i+1)/4.0))
		out.append({"name":"tarn_%d" % (i+1),"at":Vector3(p.x,W+0.32,p.y),"size":Vector3(1.15,0.9,1.05),"yaw":0.4+0.5*i,"kind":"stepping","chain":"tarn","grounded":true})
	# Over the spill channel in the alley: two slabs.
	for i in range(2):
		var p := world(Vector2(ARC+ARC_D+0.7+1.4*i,0.6-1.2*i))
		out.append({"name":"channel_%d" % (i+1),"at":Vector3(p.x,K-0.05,p.y),"size":Vector3(1.1,0.75,1.5),"yaw":0.2-0.4*i,"kind":"stepping","chain":"channel","grounded":true})
	# The lodestone's stone on the north isle.
	var n_mid: Vector2 = world(north[1])
	out.append({"name":"north_altar","at":Vector3(n_mid.x+1.2,K+float(north[3])+0.45+0.55,n_mid.y+0.8),"size":Vector3(1.8,1.0,1.4),"yaw":0.5,"kind":"block","chain":"lode","grounded":true})
	_platforms = out
	return out

## `count` floating stones from local `a` (its top `ya`, a rim `ra` round
## it) to local `b`, evenly between their rims, the tops stepping from `ya`
## to `yb`, wandering `bend` m off the line.
static func _chain(out: Array, chain: String, a: Vector2, ya: float, ra: float, b: Vector2, yb: float, rb: float, count: int, bend: float) -> void:
	var dir := (b-a).normalized()
	var start := a+dir*ra
	var end := b-dir*rb
	var side := Vector2(-dir.y,dir.x)
	for i in range(count):
		var u := float(i+1)/(count+1)
		var p := world(start.lerp(end,u)+side*bend*sin(u*PI))
		var y := lerpf(ya,yb,u)
		out.append({"name":"%s_%d" % [chain,i+1],"at":Vector3(p.x,y,p.y),"size":Vector3(1.9 if i%2 == 0 else 1.6,0.7 if i%2 == 0 else 0.9,1.7),
			"yaw":atan2(-dir.y,dir.x)+(0.3 if i%2 else -0.2),"kind":"block","chain":chain})

static func platform(name: String) -> Dictionary:
	for p: Dictionary in platforms():
		if p.name == name: return p
	return {}

## The floating stones drawn worn and walked on clean boxes (as the
## aqueduct isle's: studies/aqueduct_isle_art.gd `floating_stones`), a clod
## under the torn-up ones, ivy trailing.
static func floating_stones(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.55,"FloatingStones")
	for p: Dictionary in platforms():
		var size: Vector3 = p.size
		var half := size*0.5
		var at: Vector3 = p.at
		var pose := Transform3D(Basis(Vector3.UP,float(p.yaw)),at-Vector3(0.0,half.y,0.0))
		b.lean = true
		b.solid(RuinKit._box(b,half),pose,RuinKit._stone(b,1.04),false,true,[],-1,1.0)
		b.lean = false
		RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])
		if p.kind == "block" and not p.has("grounded"):
			var deep := b.rng.randf_range(0.9,1.6)
			var clod := RuinKit._prism(5,0.12,minf(half.x,half.z)*0.95,-half.y-deep,-half.y+0.02,b.rng.randf()*TAU)
			b.solid(clod,pose,Art.EARTH.lerp(Art.ROCK,0.4)*b.rng.randf_range(0.85,1.05),false,true,[],-1,1.6,false)
			for i in range(3): Art._tuft(b,pose*Vector3(b.rng.randf_range(-half.x,half.x)*0.8,half.y,b.rng.randf_range(-half.z,half.z)*0.8),0.3,4)
			for i in range(2): b.hang(pose*Vector3(b.rng.randf_range(-half.x,half.x)*0.7,0.0,b.rng.randf_range(-half.z,half.z)*0.7),b.rng.randf_range(0.8,2.2),true,at.y-size.y)
	return b.finish()

# --- The cloister ---------------------------------------------------------------------

## A range's frame (world): its centreline's middle at K, +Z to the garth.
## `side`: "north", "east", "south", "west".
static func range_frame(side: String) -> Transform3D:
	match side:
		"north": return Transform3D(Basis.IDENTITY,Vector3(C.x,K,C.y-ARC))
		"east": return Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3(C.x+ARC,K,C.y))
		"south": return Transform3D(Basis(Vector3.UP,PI),Vector3(C.x,K,C.y+ARC))
	return Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(C.x-ARC,K,C.y))

## The heaps at the west gap's broken ends, in the west range's frame: a
## block in the alley, a chunk of the wall against the standing end.
const HEAPS := [
	[Vector3(-3.9,1.5,-1.32),Vector3(1.4,1.5,1.3),0.0],[Vector3(-3.95,3.0,-0.05),Vector3(1.3,3.0,1.2),-0.05],
	[Vector3(3.9,1.5,-1.32),Vector3(1.4,1.5,1.3),0.0],[Vector3(3.95,3.0,-0.05),Vector3(1.3,3.0,1.2),0.08]]

## The cloister: its four ranges (north and south carry the corners; east
## the water gate; west fallen in the middle), the heaps at the gap, the
## lavabo on its isle, the slab bridge from the south terrace, the walling
## along the alley's back where the rim stands over it. {node, ranges
## (by side), lavabo, slab}.
static func cloister(seed_value: int, weathered: float) -> Dictionary:
	var node := Node3D.new()
	node.name = "Cloister"
	var ranges := {}
	var specs := {
		"north":[PIERS,{"ends":Vector2(0.6,0.6),"buttresses":[-9.0,9.0]}],
		"east":[EAST_PIERS,{"ends":Vector2.ZERO,"skip_piers":[0,7],"tall":{3:GATE_WALK}}],
		"south":[PIERS,{"ends":Vector2(0.6,0.6)}],
		"west":[PIERS,{"ends":Vector2.ZERO,"skip_piers":[0,7],"fallen":FALLEN,"stubs":STUBS}],
	}
	var k := 0
	for side: String in specs:
		var spec: Array = specs[side]
		var r: Node3D = Cloister.range_run(seed_value+k,weathered,spec[0],spec[1])
		r.name = "Range_"+side
		r.transform = range_frame(side)
		node.add_child(r)
		ranges[side] = r
		k += 1
	var heaps: Node3D = Cloister.heap(seed_value+10,weathered,HEAPS)
	heaps.name = "GapHeaps"
	heaps.transform = range_frame("west")
	node.add_child(heaps)
	var lavabo: Node3D = Cloister.pavilion(seed_value+11,weathered*0.9,LAVABO,WALK,lavabo_steps())
	lavabo.name = "Lavabo"
	var sm := world(SHRINE)
	lavabo.position = Vector3(sm.x,SHRINE_TOP,sm.y)
	node.add_child(lavabo)
	# The slab bridge from the south terrace onto the south range's walk.
	var slab: Node3D = Cloister.slab_bridge(seed_value+12,0.35,BACK+0.6-(ARC+ARC_D-0.3),1.7)
	slab.name = "SlabBridge"
	slab.transform = Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(C.x,K+WALK,C.y+(BACK+0.6+ARC+ARC_D-0.3)*0.5))
	node.add_child(slab)
	node.add_child(back_walls(seed_value+13,weathered*0.7))
	return {"node":node,"ranges":ranges,"lavabo":lavabo,"slab":slab}

## The lavabo's drums fallen in a heap at its south-east corner (its
## frame): a way up onto its top.
static func lavabo_steps() -> Array:
	return [[Vector3(2.75,1.5,-1.2),Vector3(1.0,1.5,1.0)],[Vector3(2.55,3.0,0.0),Vector3(1.05,3.0,1.05)]]

## Coursed walling along the alley's back, as high as the rim's first step
## there (the rock rises on behind it), left out where the step is low.
static func back_walls(seed_value: int, weathered: float) -> Node3D:
	var node := Node3D.new()
	node.name = "BackWalls"
	var sides := {"north":Vector2(0.0,-1.0),"east":Vector2(1.0,0.0),"south":Vector2(0.0,1.0),"west":Vector2(-1.0,0.0)}
	var k := 0
	for side: String in sides:
		var n: Vector2 = sides[side]
		var along := Vector2(-n.y,n.x)
		var b := Build.new(seed_value+k,weathered,"BackWall_"+side)
		b.settle = 0.4
		k += 1
		# Its frame: X along the back, +Z into the alley, foot on K.
		var o := world(n*(BACK+0.1))
		b.frame = Transform3D(Basis(Vector3(along.x,0.0,along.y),Vector3.UP,Vector3(-n.x,0.0,-n.y)),Vector3(o.x,K,o.y))
		var step := func(x: float) -> float:
			var p := world(n*(BACK+0.15)+along*x)
			return ground(p.x,p.y)-K
		var top := func(x: float) -> float:
			var s: float = step.call(x)
			return minf(s,WALK) if s > 0.7 else 0.0
		RuinKit._courses(b,Transform3D.IDENTITY,-BACK-0.7,BACK+0.7,0.0,top,0.35,Callable(),0.46)
		var built := b.finish()
		built.name = "BackWall_"+side
		node.add_child(built)
	return node

# --- The water ------------------------------------------------------------------------

## The water the pilot wades and swims (PilotPhysicsGround `pools`).
static func pools() -> Array:
	var lip := edge_r(0.0)
	return [{"rect":Rect2(C.x-ARC+0.6,C.y-ARC+0.6,(ARC-0.6)*2.0,(ARC-0.6)*2.0),"top":W},
		{"rect":Rect2(C.x+ARC-0.6,C.y-CH,lip-ARC+0.6,CH*2.0),"top":W}]

## The tarn's and the channel's surface (world, flat at W): the tarn a disc
## a little past its shore (the bank hides the rest), the channel to the
## lip. Triangles, wound up.
static func water_faces() -> PackedVector3Array:
	var v := PackedVector3Array()
	var n := 72
	var mid := Vector3(C.x,W,C.y)
	for i in range(n):
		var t0 := 360.0*i/n
		var t1 := 360.0*(i+1)/n
		var a := world(way(t0)*(tarn_r(t0)+1.0))
		var b := world(way(t1)*(tarn_r(t1)+1.0))
		v.append_array([mid,Vector3(b.x,W,b.y),Vector3(a.x,W,a.y)])
	var x0 := C.x+TARN-1.5
	var x1 := C.x+edge_r(0.0)
	var p00 := Vector3(x0,W,C.y-CH-0.3)
	var p10 := Vector3(x1,W,C.y-CH-0.3)
	var p11 := Vector3(x1,W,C.y+CH+0.3)
	var p01 := Vector3(x0,W,C.y+CH+0.3)
	v.append_array([p00,p11,p10,p00,p01,p11])
	return v

## The lip the tarn spills off (world) and its outward way.
static func lip() -> Vector3:
	return Vector3(C.x+edge_r(0.0),W,C.y)

## A shape stand-in for the fall's thread plan (SkyIslets `_thread_plan`
## reads its recipe, water, seed).
class FallShape extends RefCounted:
	var recipe := {}
	var seed := 31
	var depth := KEEL
	var _water := {}
	func water() -> Dictionary: return _water

## The curtain fall off the lip: the waterfalls' strand (shaders/
## flow_fall.gdshader) laid as the sky islets lay theirs (SkyIslets
## `curtain`, `_fall`), CH wide each side: a curtain, not a hose; its
## droplets; a soft thread on down to the cloud sea (scripts/
## sky_fall_thread.gd). Drawn only.
static func fall(seed_value: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Fall"
	var at := lip()
	var out := Vector3.RIGHT
	var rings: Dictionary = SkyIslets.curtain(at,out,KEEL*SkyIslets.FALL_DROP.x+SkyIslets.FALL_DROP.y,SkyIslets.FALL_TAIL,CH,0.35,0.75)
	var curtain := MeshInstance3D.new()
	curtain.name = "Curtain"
	curtain.mesh = FlowFalls._build_ring_mesh(SkyIslets.FALL_RINGS)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/flow_fall.gdshader")
	material.render_priority = FlowFalls.CURTAIN_PRIORITY
	material.set_shader_parameter("fall_seed",float(seed_value % 997)*0.37+3.0)
	var white := PackedFloat32Array()
	for s in range(12): white.append(fposmod(sin(float(s*23+seed_value))*43758.5453,1.0))
	material.set_shader_parameter("section_white",white)
	material.set_shader_parameter("ring_count",SkyIslets.FALL_RINGS)
	material.set_shader_parameter("centers_tau",rings.centers)
	material.set_shader_parameter("axis_a_width",rings.across)
	material.set_shader_parameter("axis_b_thick",rings.outward)
	material.set_shader_parameter("aer_steep",rings.aer_steep)
	material.set_shader_parameter("ring_travel",rings.travel)
	material.set_shader_parameter("body_white",0.3*(1.0-smoothstep(0.15,0.8,float(rings.half))))
	material.set_shader_parameter("veil",1.0-smoothstep(0.15,0.85,0.75))
	material.set_shader_parameter("streak_speed",clampf(0.6*sqrt(2.0*9.81*float(rings.face_drop)),2.5,7.0))
	material.set_shader_parameter("break_from",rings.break_from)
	material.set_shader_parameter("break_length",rings.break_length)
	curtain.material_override = material
	curtain.custom_aabb = rings.bounds
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(curtain)
	var shape := FallShape.new()
	shape.seed = seed_value
	shape._water = {"lip":Vector2(at.x,at.z),"level":W,"out":Vector2(1.0,0.0)}
	var plan: Dictionary = SkyFallThread.plan(at,out,float(rings.half),SkyFallThread.SEA,seed_value,float(rings.face_drop),SkyIslets.FALL_SPEED,0.55)
	if not plan.is_empty(): node.add_child(SkyFallThread.node_from(plan))
	node.set_meta("rings",rings)
	return node

# --- The islands ------------------------------------------------------------------

## Where a face stands against the alley's back walling.
static func walled(e: Vector2) -> bool:
	var d := local(e.x,e.y)
	return absf(cheb(d)-BACK) < 0.3

## An island (the kit isles' shared builder, scripts/kit_isle/kit_land.gd
## `island`): its top the plate's ground over `flat`, collided, its crags
## the islets' rock, its sides and keel of hanging rock `depth` under `top`.
## `cliffs`: the box (world) the ground's steps are laid in as cliff points
## (empty: none), `fine` the cell there; under `water` the turf is the
## water's bed. The lip and earth hang from a high rim's own height; the
## cliffs' prisms are held in bodies apart from the ground's.
static func island(outline_points: Array, depth: float, seed_value: int, flat: Callable, top: float, cliffs := Rect2(), fine := 1.2, water := -INF) -> Node3D:
	var wet := func(_p: Vector2, y: float) -> float:
		var over := y-water
		return clampf((0.12-over)/0.3,0.0,1.0) if over < 0.12 else 0.0
	var spec := {"outline":outline_points,"depth":depth,"seed":seed_value,"ground":flat,"top":top,
		"resample":[100.0,120,32],"cliffs":cliffs,"walled":func(e: Vector2) -> bool: return walled(e),
		"fine":fine,"hang":true,"apart":true,
		"tone":KitLook.turf(seed_value,func(p: Vector2) -> float: return path_wear(p),wet)}
	return KitLand.island(spec)

## The mother isle (its cliffs laid all over it), and the satellites.
static func mother(seed_value: int) -> Node3D:
	var box := Rect2(C.x-34.0,C.y-34.0,68.0,68.0)
	var node := island(outline(),KEEL,seed_value,func(x: float, z: float) -> float: return ground(x,z),W,box,1.1,W)
	node.name = "MotherIsle"
	return node

static func satellites(seed_value: int) -> Array:
	var out: Array = []
	for spec: Array in SATELLITES:
		var flat := func(x: float, z: float) -> float: return satellite_ground(spec,x,z)
		var node := island(satellite_outline(spec),7.0+float(spec[2]),seed_value+int(spec[4]),flat,K+float(spec[3]))
		node.name = "Isle_"+str(spec[0])
		node.set_meta("spec",spec)
		out.append(node)
	return out

# --- The ways (for the tests and the doc) -----------------------------------------------

## The easy way onto the wall-walk, walked (world x, z): from the alley's
## south-east corner up the slope to the crest, along it to the south
## terrace, over the slab bridge onto the south range's walk.
static func way_to_walk() -> Array:
	var mid := ARC+ARC_D+ALLEY*0.5
	var out: Array = [world(Vector2(mid-0.3,mid-0.3))]
	var t := 325.0
	while t >= 275.0:
		out.append(world(way(t)*RIM/sq(way(t))))
		t -= 6.0
	out.append(world(Vector2(0.0,BACK+1.6)))
	out.append(world(Vector2(0.0,ARC)))
	return out

## The way up the crag, walked: out of the alley's west door, up over the
## saddle, along the ridge north to the kit stair, up it onto the summit.
static func way_to_crag() -> Array:
	var mid := ARC+ARC_D+ALLEY*0.5
	var out: Array = [world(Vector2(-mid,0.0)),world(Vector2(-BACK-1.5,0.0))]
	var t := 180.0
	while t >= STAIR_FOOT+2.0:
		out.append(world(way(t)*RIM/sq(way(t))))
		t -= 5.0
	var f := stairs_frame()
	for l: float in [KIT_RUN*0.5+1.4,KIT_RUN*0.5-RuinKit.TREAD,-KIT_RUN*0.5-0.4,-KIT_RUN*0.5-2.0]:
		var at := f*Vector3(0.0,0.0,l)
		out.append(Vector2(at.x,at.z))
	return out

## The kit stair up the ridge's last rise (world): its foot at STAIR_FOOT on
## the crest's line, its head (-Z) toward STAIR_HEAD.
static func stairs_frame() -> Transform3D:
	var foot := world(way(STAIR_FOOT)*RIM/sq(way(STAIR_FOOT)))
	var head := world(way(STAIR_HEAD)*RIM/sq(way(STAIR_HEAD)))
	var dir := (head-foot).normalized()
	# Its landing's back 0.25 m into the plateau's sheer face.
	var mid := head-dir*(KIT_RUN*0.5-0.25)
	var back := Vector3(-dir.x,0.0,-dir.y)
	return Transform3D(Basis(Vector3.UP.cross(back).normalized(),Vector3.UP,back),Vector3(mid.x,K+CRAG_TOP-STAIR_RISE,mid.y))
