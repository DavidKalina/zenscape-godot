extends RefCounted
## The drowned nave's art (studies/drowned_nave_isle.gd; docs/scenic/
## drowned-nave.md): a larger isle with a wide shallow basin of still water
## over most of its top and a long gothic nave half drowned in it.
##
## One heightfield (`ground`), round C (world x, z), the nave along X, west
## to east (angles `t` in degrees, counterclockwise from above from east:
## east 0, north (-z) 90, west 180, south 270):
##   the basin, an ellipse (BASIN_A by BASIN_B, wandering, true at both ends
##     of the nave) whose bed shelves to DEEP under the water at W; the
##     nave's own floor (NAVE_FLOOR) a raised flagged strip down the middle,
##     wading deep, with the moat swimming deep either side of it;
##   the nave, two rows of piers and pointed arches (scripts/
##     ruin_kit_cloister.gd `range_run`, 5.4 m bays) along z = +-ROW_Z, each
##     row fallen in a run (the south row's gap, the north row's), their
##     wall-walks carried on the arches;
##   the shore, a grass bank from the water up to the shoulders round the
##     basin, a long beach to the west where the plane comes in, a lancet
##     window standing on it;
##   the apse, a rock mass rising in three tiers to a plateau (PLATEAU over
##     K) at the nave's far end, a grand stair up its axis from the shore,
##     the rose gable standing on the plateau with the nave seen through
##     its door, buttresses bracing it from behind, the lookout;
##   the spill, a channel from the basin's north shore to the lip, and the
##     curtain fall off it into the cloud sea.
const Art = preload("res://studies/aqueduct_isle_art.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Cloister = preload("res://scripts/ruin_kit_cloister.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Build = RuinKit.Build
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyFallThread = preload("res://scripts/sky_fall_thread.gd")
const FlowFalls = preload("res://scripts/flow_falls.gd")

## The isle's middle (world x, z), the water's level, the shore's (K).
const C := Vector2(80.0,0.0)
const W := 30.0
const TOP := W
const K := W+0.5
## The nave's floor (under the water) and the rows' offset from its axis.
const NAVE_FLOOR := W-0.4
const ROW_Z := 5.4
## The rows' bays (both rows alike, so they face each other across the
## nave): BAYS of them, the walker's bay BAY pier to pier (the cloister's
## 5.4 m: its arch 4.46 clear, its crown 4 m over the floor; walker-sized)
## but the crossing bay CROSS_AT, where the plane goes out through the rows:
## the south row's gap (fallen, a stub at each of its piers) and, facing it,
## the north row's great arch standing (CROSS_WALK its walk). The crossing's
## clear is an opening (scripts/world_scale.gd) on the toy era's clear of a
## walker's bay (TOY_CROSS 4.46: the toy plane threaded any bay), 8.47 m at
## the defaults; at `--plane-scale=1 --opening-ratio=1` it is a walker's bay
## again (nine bays 5.4 apart).
## PIERS: the piers' x along the nave (world x from C, west to east).
const BAY := 5.4
const BAYS := 9
const CROSS_AT := 5
## What a bay's arch keeps off its piers' middles (the cloister kit's `_bay`).
const ARCH_OFF := Cloister.PIER_HALF+0.15
const TOY_CROSS := BAY-2.0*ARCH_OFF
static var CROSS_CLEAR: float = WorldScale.opening(TOY_CROSS)
static var CROSS: float = CROSS_CLEAR+2.0*ARCH_OFF
static var PIERS: Array = _piers()
## The south row's fallen run (bays, west to east, as PIERS), its snapped
## piers (pier index: height), the crossing's two; the north row's, east of
## the great arch.
const SOUTH_FALLEN := [CROSS_AT-1,CROSS_AT,CROSS_AT+1]
const SOUTH_STUBS := {CROSS_AT:2.3,CROSS_AT+1:3.1}
const NORTH_FALLEN := [CROSS_AT+1,CROSS_AT+2]
const NORTH_STUBS := {CROSS_AT+2:2.9}
## The rows' stepped buttresses (pier index), north and south.
const NORTH_BUTTRESS := 1
const SOUTH_BUTTRESS := 2
## The arcade's walk (the tall bays', as the cloister's water gate), and
## over the crossing's great arch: its crown's ring (the kit's two orders)
## under the coping, never under TALL (TALL exactly at the toy's bay).
const TALL := Cloister.WALK+0.38
static var CROSS_WALK: float = maxf(TALL,Cloister.SPRING+CROSS_CLEAR*0.5+RuinKit.ORDER*2.0+0.04+Cloister.COPING)

static func _piers() -> Array:
	var out: Array = []
	var x := -(BAY*(BAYS-1)+CROSS)*0.5
	out.append(x)
	for i in range(BAYS):
		x += CROSS if i == CROSS_AT else BAY
		out.append(x)
	return out

## The crossing's middle (world x from C).
static func cross_mid() -> float:
	return bay_mid(CROSS_AT)

## The middle of bay `i` (world x from C).
static func bay_mid(i: int) -> float:
	return (float(PIERS[i])+float(PIERS[i+1]))*0.5
## The nave floor strip's half width and how fast it falls to the moat.
const NAVE_HW := 7.4
const NAVE_X := 30.0
## The basin: its semi-axes, its shelf, its deep (m under W).
const BASIN_A := 33.0
const BASIN_B := 19.0
const SHELF := 1.2
const DEEP := 2.4
## The island's edge: semi-axes (wandering).
const EDGE_A := 62.0
const EDGE_B := 46.0
## The apse: its middle (local), its plateau's radius, its rock's, the
## plateau over K (the grand stair's rise), the tiers.
const APSE := Vector2(53.0,0.0)
const RHO_TOP := 8.5
const RHO_OUT := 20.5
const PLATEAU := 2.0*RuinKit.GRAND_STEPS*RuinKit.GRAND_RISER
const TIERS := 3
## The grand stair: its origin's local x (foot at x-6.72, head at x+5.62),
## the way cleared for it (half width) and where the plateau begins.
const STAIR_X := 41.6
const STAIR_HALF := 3.0
const STAIR_FOOT_X := 34.2
const STAIR_END_X := 46.7
## The gable stands on the plateau at this local x.
const GABLE_X := 55.5
## The spill: the channel's local x, half width, its bed under W.
const SPILL_X := -9.0
const CH := 2.2
const CHANNEL_BED := 0.45
const KEEL := 30.0

# --- The angles and metrics -----------------------------------------------------------

static func local(x: float, z: float) -> Vector2:
	return Vector2(x-C.x,z-C.y)

static func world(l: Vector2) -> Vector2:
	return C+l

static func angle(d: Vector2) -> float:
	return fposmod(rad_to_deg(atan2(-d.y,d.x)),360.0)

static func way(t: float) -> Vector2:
	var a := deg_to_rad(t)
	return Vector2(cos(a),-sin(a))

## The ellipse (a by b) radius at angle `t`.
static func ellipse(a: float, b: float, t: float) -> float:
	var r := deg_to_rad(t)
	return a*b/sqrt(pow(b*cos(r),2.0)+pow(a*sin(r),2.0))

## The basin's shore radius at `t`: true at both ends of the nave.
static func basin_r(t: float) -> float:
	var a := deg_to_rad(t)
	return ellipse(BASIN_A,BASIN_B,t)*(1.0+0.025*sin(3.0*a)-0.02*sin(5.0*a)+0.012*sin(9.0*a+1.0)*pow(sin(a),2.0))

## The island's edge at `t`.
static func edge_r(t: float) -> float:
	var a := deg_to_rad(t)
	return ellipse(EDGE_A,EDGE_B,t)*(1.0+0.03*sin(3.0*a)+0.018*sin(7.0*a)+0.01*sin(11.0*a+2.0)*pow(sin(a),2.0))

# --- The ground -----------------------------------------------------------------------

static func ground(x: float, z: float) -> float:
	var d := local(x,z)
	var r := d.length()
	var t := angle(d)
	var h := _ground(d,r,t)
	# The spill channel, north from the basin's shore to the lip.
	if d.y < 0.0:
		var u := absf(d.x-SPILL_X)
		h = minf(h,W-CHANNEL_BED+3.0*smoothstep(CH,CH+3.5,u)+maxf(0.0,u-CH-3.5)*2.0)
	return h

static func _ground(d: Vector2, r: float, t: float) -> float:
	var rb := basin_r(t)
	if r < rb:
		var e := rb-r
		var base := W-0.25*e/SHELF if e < SHELF else W-0.25-(DEEP-0.25)*smoothstep(SHELF,SHELF+4.0,e)
		# The nave's raised floor.
		var n := (1.0-smoothstep(NAVE_HW,NAVE_HW+2.6,absf(d.y)))*(1.0-smoothstep(NAVE_X-0.5,NAVE_X+2.6,absf(d.x)))
		return lerpf(base,maxf(base,NAVE_FLOOR),n)
	var re := edge_r(t)
	var f := clampf((r-rb)/maxf(re-rb,1.0),0.0,1.0)
	var lift := shore_lift(t)*smoothstep(0.05,0.45,f)*(1.0-0.45*smoothstep(0.7,1.0,f))
	var tiers := apse_tiers(d)
	var corridor := absf(d.y) < STAIR_HALF and d.x > STAIR_FOOT_X-1.0 and d.x < STAIR_END_X
	var top := K+(0.0 if corridor else maxf(lift,tiers))
	if d.x >= STAIR_END_X and absf(d.y) < STAIR_HALF and tiers >= PLATEAU-0.01: top = K+PLATEAU
	return W+0.05+(top-W-0.05)*smoothstep(0.0,1.6,r-rb)

## The shore's roll over K round the basin: low, a little higher at the
## corners.
static func shore_lift(t: float) -> float:
	var a := deg_to_rad(t)
	return 0.5+0.55*(0.5+0.5*sin(2.0*a+1.0))+1.1*pow(absf(sin(2.0*a)),3.0)

## The apse rock's height over K at local `d`: three tiers about 4 m wide
## to the plateau.
static func apse_tiers(d: Vector2) -> float:
	var rho := Vector2(d.x-APSE.x,d.y*1.15).length()
	var q := clampf((RHO_OUT-rho)/(RHO_OUT-RHO_TOP),0.0,1.0)
	if q <= 0.0: return 0.0
	if q >= 1.0: return PLATEAU
	var wob := 0.06*sin(deg_to_rad(angle(d))*5.0)
	var k := mini(int(floor(clampf(q*TIERS+wob,0.0,float(TIERS)))),TIERS-1)
	return PLATEAU*float(k)/float(TIERS)

## The plateau's top (world y).
static func plateau_top() -> float:
	return K+PLATEAU

static func outline() -> Array:
	var out: Array = []
	for i in range(120):
		var t := 360.0*i/120.0
		out.append(world(way(t)*edge_r(t)))
	return out

static func on_isle(p: Vector2) -> bool:
	var d := local(p.x,p.y)
	return d.length() < edge_r(angle(d))

## The spill's lip (world): where the channel's centre meets the edge.
static var _lip := Vector3.INF
static func lip() -> Vector3:
	if _lip != Vector3.INF: return _lip
	var z := 18.0
	while z < 80.0:
		var d := Vector2(SPILL_X,-z)
		if d.length() >= edge_r(angle(d)):
			_lip = Vector3(C.x+SPILL_X,W,C.y-z)
			return _lip
		z += 0.1
	_lip = Vector3(C.x+SPILL_X,W,C.y-EDGE_B)
	return _lip

## True where the ground is under the water (or at its edge).
static func wet(p: Vector2) -> bool:
	return ground(p.x,p.y) < W+0.15 and on_isle(p)

## How worn the ground is at world `p` (0 off the paths, 1 on their middle).
static var _paths: Array = []
static func path_wear(p: Vector2) -> float:
	if _paths.is_empty(): _paths = paths()
	var best := INF
	for path: Array in _paths:
		for i in range(path.size()-1):
			best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[i],path[i+1])))
	return clampf(1.25-best/1.5,0.0,1.0)

## The worn paths (world): the beach to the lancet window and along the
## north shore round to the stair; the south shore likewise; the stair up
## the apse.
static func paths() -> Array:
	var out: Array = []
	var pts := func(list: Array) -> Array:
		var line: Array = []
		for l: Vector2 in list: line.append(world(l))
		return line
	out.append(pts.call([Vector2(-60.0,0.0),Vector2(-44.0,0.0),Vector2(-36.0,-1.0)]))
	out.append(pts.call([Vector2(-36.0,-2.0),Vector2(-30.0,-20.5),Vector2(-9.0,-22.5),Vector2(14.0,-21.5),Vector2(33.0,-13.0),Vector2(38.0,-7.0),Vector2(STAIR_FOOT_X,0.0)]))
	out.append(pts.call([Vector2(-36.0,1.0),Vector2(-30.0,20.0),Vector2(0.0,23.0),Vector2(24.0,19.0),Vector2(33.0,10.0),Vector2(STAIR_FOOT_X,0.0)]))
	out.append(pts.call([Vector2(STAIR_FOOT_X,0.0),Vector2(STAIR_END_X+4.0,0.0)]))
	return out

## Kept bare by the flora: the worn paths, the water and its edge.
static func bare(p: Vector2) -> float:
	if wet(p): return 1.0
	return path_wear(p)

# --- The stones -------------------------------------------------------------------------

## Every stone stood on: {name, at (its top's middle, world), size, yaw,
## kind, chain, grounded}. The causeway down the nave (slabs and drums
## fallen into the water, tops just over it), the landing stones, the
## lodestone's block on the plateau.
static var _platforms: Array = []
static func platforms() -> Array:
	if not _platforms.is_empty(): return _platforms
	var out: Array = []
	var x := -28.4
	var i := 0
	while x < 30.5:
		var zig := 0.55*sin(float(i)*1.7)
		var p := world(Vector2(x,zig))
		var top := W+(0.30 if i%2 == 0 else 0.42)
		out.append({"name":"causeway_%d" % (i+1),"at":Vector3(p.x,top,p.y),"size":Vector3(1.9 if i%2 == 0 else 1.6,top-(NAVE_FLOOR-0.3),1.7),"yaw":0.3*sin(float(i)*2.3),"kind":"block","chain":"causeway","grounded":true})
		x += 2.95
		i += 1
	# Over the spill channel at the north shore: two slabs.
	for k in range(2):
		var p := world(Vector2(SPILL_X+0.5-1.0*k,-(basin_r(90.0)+1.2+1.4*k)))
		out.append({"name":"spill_%d" % (k+1),"at":Vector3(p.x,K-0.05,p.y),"size":Vector3(1.1,0.75,1.5),"yaw":0.2-0.4*k,"kind":"block","chain":"spill","grounded":true})
	var lode := world(Vector2(GABLE_X+3.3,3.4))
	out.append({"name":"lode","at":Vector3(lode.x,plateau_top()+1.0,lode.y),"size":Vector3(1.8,1.0,1.4),"yaw":0.5,"kind":"block","chain":"lode","grounded":true})
	_platforms = out
	return out

static func platform(name: String) -> Dictionary:
	for p: Dictionary in platforms():
		if p.name == name: return p
	return {}

## The stones drawn worn and walked on clean boxes (as the aqueduct isle's
## floating stones).
static func stones(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.55,"CausewayStones")
	for p: Dictionary in platforms():
		var size: Vector3 = p.size
		var half := size*0.5
		var at: Vector3 = p.at
		var pose := Transform3D(Basis(Vector3.UP,float(p.yaw)),at-Vector3(0.0,half.y,0.0))
		b.lean = true
		b.solid(RuinKit._box(b,half),pose,RuinKit._stone(b,1.04),false,true,[],-1,1.0)
		b.lean = false
		RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])
	return b.finish()

# --- The nave -----------------------------------------------------------------------------

## The rows: [name, frame (world), options]. The north row faces the nave
## (+Z), the south row turned round to.
static func row_frame(side: String) -> Transform3D:
	if side == "north": return Transform3D(Basis.IDENTITY,Vector3(C.x,NAVE_FLOOR,C.y-ROW_Z))
	return Transform3D(Basis(Vector3.UP,PI),Vector3(C.x,NAVE_FLOOR,C.y+ROW_Z))

## The nave: two rows of piers and arches (the south row's gap, the
## north row's), the floor's slabs, the fallen piers by the causeway, the
## chancel's springers. {node, rows (by side)}.
static func nave(seed_value: int, weathered: float) -> Dictionary:
	var node := Node3D.new()
	node.name = "Nave"
	var tall := {}
	for i in range(BAYS): tall[i] = CROSS_WALK if i == CROSS_AT else TALL
	# The south row is turned round (its x runs east to west): its piers,
	# bays and stubs counted from the east end.
	var south_fallen: Array = SOUTH_FALLEN.map(func(i: int) -> int: return BAYS-1-i)
	var south_stubs := {}
	for j: int in SOUTH_STUBS: south_stubs[BAYS-j] = SOUTH_STUBS[j]
	var south_tall := {}
	for i: int in tall: south_tall[BAYS-1-i] = tall[i]
	var south_piers: Array = PIERS.map(func(x: float) -> float: return -x)
	south_piers.reverse()
	var rows := {}
	var specs := {
		"north":[PIERS,{"ends":Vector2(0.6,0.6),"fallen":NORTH_FALLEN,"stubs":NORTH_STUBS,"tall":tall,"buttresses":[PIERS[NORTH_BUTTRESS]]}],
		"south":[south_piers,{"ends":Vector2(0.6,0.6),"fallen":south_fallen,"stubs":south_stubs,"tall":south_tall,"buttresses":[-float(PIERS[SOUTH_BUTTRESS])]}],
	}
	var k := 0
	for side: String in specs:
		var row: Node3D = Cloister.range_run(seed_value+k,weathered,specs[side][0],specs[side][1])
		row.name = "Row_"+side
		row.transform = row_frame(side)
		node.add_child(row)
		rows[side] = row
		k += 1
	# Flagstones of the nave floor, a few patches (weathered: mostly gone).
	var patches := [Vector2(-22.0,2.6),Vector2(-8.0,-2.6),Vector2(5.0,2.4),Vector2(20.0,-2.4)]
	for j in range(patches.size()):
		var slabs: Node3D = RuinKit.floor_slabs(seed_value+10+j,0.8)
		slabs.name = "Flags_%d" % j
		var at := world(patches[j])
		slabs.transform = Transform3D(Basis(Vector3.UP,0.4*j),Vector3(at.x,NAVE_FLOOR,at.y))
		node.add_child(slabs)
	# Piers fallen along the nave, each by the causeway, not on it.
	var fallen := [[Vector2(-15.0,2.9),0.25],[Vector2(-1.0,-3.0),-0.2],[Vector2(12.0,3.1),0.15],[Vector2(23.0,-3.0),-0.3]]
	for j in range(fallen.size()):
		var piece: Node3D = RuinKit.fallen_pier(seed_value+20+j,0.6)
		var at := world(fallen[j][0])
		piece.transform = Transform3D(Basis(Vector3.UP,float(fallen[j][1])),Vector3(at.x,NAVE_FLOOR,at.y))
		node.add_child(piece)
	# The chancel's vault springers, their ribs broken off over the nave:
	# the roof's last, the gap the plane pulls up through.
	for s: float in [-1.0,1.0]:
		var vault: Node3D = RuinKit.vault(seed_value+30+int(s),0.5)
		var at := world(Vector2(PIERS[PIERS.size()-1]+2.2,s*(ROW_Z+0.9)))
		vault.transform = Transform3D(Basis(Vector3.UP,-PI*0.5 if s < 0.0 else PI),Vector3(at.x,NAVE_FLOOR,at.y))
		node.add_child(vault)
	return {"node":node,"rows":rows}

## The apse: the grand stair, the rose gable, the buttresses behind it, the
## springers' neighbours, a chest by the lodestone's block. {node, stair}.
static func apse(seed_value: int, weathered: float) -> Dictionary:
	var node := Node3D.new()
	node.name = "Apse"
	var stair: Node3D = RuinKit.grand_stair(seed_value,0.3)
	stair.name = "GrandStair"
	var o := world(Vector2(STAIR_X,0.0))
	stair.transform = Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3(o.x,K,o.y))
	node.add_child(stair)
	var gable: Node3D = RuinKit.rose_gable(seed_value+1,weathered)
	gable.name = "RoseGable"
	var g := world(Vector2(GABLE_X,0.0))
	gable.transform = Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3(g.x,plateau_top(),g.y))
	node.add_child(gable)
	for s: float in [-1.0,1.0]:
		var piece: Node3D = RuinKit.buttress(seed_value+2+int(s),0.7)
		var at := world(Vector2(GABLE_X+1.7,s*3.9))
		piece.transform = Transform3D(Basis(Vector3.UP,PI*0.5)*Basis(Vector3.RIGHT,0.0),Vector3(at.x,plateau_top(),at.y))
		node.add_child(piece)
	var chest: Node3D = RuinKit.tomb_chest(seed_value+4,0.5)
	var c := world(Vector2(GABLE_X-3.4,-4.0))
	chest.transform = Transform3D(Basis(Vector3.UP,1.1),Vector3(c.x,plateau_top(),c.y))
	node.add_child(chest)
	return {"node":node,"stair":stair}

## The shore's pieces: the lancet window on the beach framing the nave;
## snapped piers, a wall, an arch and a fallen pier on the shores.
static func shore(seed_value: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Shore"
	var place := func(piece_id: String, seed_off: int, weathered: float, l: Vector2, yaw: float) -> void:
		var at := world(l)
		var piece: Node3D = RuinKit.piece(piece_id,seed_value+seed_off,weathered)
		piece.transform = Transform3D(Basis(Vector3.UP,yaw),Vector3(at.x,ground(at.x,at.y),at.y))
		node.add_child(piece)
	place.call("lancet_wall",0,0.5,Vector2(-41.0,0.0),PI*0.5)
	place.call("pier",1,0.75,Vector2(-38.0,-12.0),0.4)
	place.call("pier",2,0.8,Vector2(-37.0,12.5),1.9)
	place.call("wall",3,0.6,Vector2(-46.0,-9.0),0.3)
	place.call("wall",4,0.6,Vector2(-45.0,10.0),-0.5)
	place.call("arch",5,0.45,Vector2(-12.0,25.5),PI*0.5)
	place.call("arch",6,0.5,Vector2(20.0,-24.0),PI*0.5+0.2)
	place.call("fallen_pier",7,0.6,Vector2(-4.0,27.5),0.3)
	place.call("wall",8,0.6,Vector2(8.0,-26.0),-0.2)
	place.call("pier",9,0.7,Vector2(34.0,-14.0),0.9)
	return node

# --- The water ------------------------------------------------------------------------------

## The water the pilot wades and swims (PilotPhysicsGround `pools`).
static func pools() -> Array:
	var lp := lip()
	return [{"rect":Rect2(C.x-BASIN_A,C.y-BASIN_B,BASIN_A*2.0,BASIN_B*2.0),"top":W},
		{"rect":Rect2(lp.x-CH,lp.z,CH*2.0,C.y-BASIN_B+3.0-lp.z),"top":W}]

## The basin's and the channel's surface (world, flat at W), for the plane
## to skim. Triangles, wound up.
static func water_faces() -> PackedVector3Array:
	var v := PackedVector3Array()
	var n := 96
	var mid := Vector3(C.x,W,C.y)
	for i in range(n):
		var t0 := 360.0*i/n
		var t1 := 360.0*(i+1)/n
		var a := world(way(t0)*(basin_r(t0)+1.0))
		var b := world(way(t1)*(basin_r(t1)+1.0))
		v.append_array([mid,Vector3(b.x,W,b.y),Vector3(a.x,W,a.y)])
	var lp := lip()
	var x0 := lp.x-CH-0.3
	var x1 := lp.x+CH+0.3
	var z0 := lp.z
	var z1 := C.y-BASIN_B+2.0
	var p00 := Vector3(x0,W,z0)
	var p10 := Vector3(x1,W,z0)
	var p11 := Vector3(x1,W,z1)
	var p01 := Vector3(x0,W,z1)
	v.append_array([p00,p10,p11,p00,p11,p01])
	return v

## How steeped the water is (scripts/kit_isle/kit_water.gd `tea`): a
## flooded stone floor, clearer than the tarn, dark over the moat.
const TEA := 0.5
const SURROUND := Vector4(0.2,0.22,0.2,0.34)
## The water's grid: coarser than the tarn's 0.25 m (the basin is some
## six times its area).
const CELL := 0.5

static func water() -> MeshInstance3D:
	var at := lip()
	return KitWater.still({"name":"Nave","level":W,"cell":CELL,
		"ground":func(x: float, z: float) -> float: return ground(x,z),
		"rect":Rect2(C.x-BASIN_A-1.5,at.z-0.5,BASIN_A*2.0+3.0,C.y+BASIN_B+1.5-(at.z-0.5)),
		"inside":func(p: Vector2) -> bool: return on_isle(p),
		"tea":TEA,"surround":SURROUND})

class FallShape extends RefCounted:
	var recipe := {}
	var seed := 31
	var depth := KEEL
	var _water := {}
	func water() -> Dictionary: return _water

## The curtain fall off the lip (as the tarn's), north.
static func fall(seed_value: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Fall"
	var at := lip()
	var out := Vector3(0.0,0.0,-1.0)
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
	var plan: Dictionary = SkyFallThread.plan(at,out,float(rings.half),SkyFallThread.SEA,seed_value,float(rings.face_drop),SkyIslets.FALL_SPEED,0.55)
	if not plan.is_empty(): node.add_child(SkyFallThread.node_from(plan))
	node.set_meta("rings",rings)
	return node

# --- The isle ----------------------------------------------------------------------------------

## True where the apse's steps are walled by nothing (the island builder's
## `walled`).
static func walled(_e: Vector2) -> bool:
	return false

## The island (the kit isles' builder): the apse and the stair's cliffs laid
## in a box; the basin under the water bedded.
static func isle(seed_value: int) -> Node3D:
	var wet_tone := func(_p: Vector2, y: float) -> float:
		var over := y-W
		return clampf((0.12-over)/0.3,0.0,1.0) if over < 0.12 else 0.0
	var spec := {"outline":outline(),"depth":KEEL,"seed":seed_value,
		"ground":func(x: float, z: float) -> float: return ground(x,z),"top":W,
		"resample":[100.0,150,32],"cliffs":Rect2(C.x+28.0,C.y-24.0,40.0,48.0),
		"walled":func(e: Vector2) -> bool: return walled(e),
		"cell":1.8,"fine":1.1,"fine_box":Rect2(C.x-38.0,C.y-25.0,108.0,50.0),
		"hang":true,"apart":true,
		"tone":KitLook.turf(seed_value,func(p: Vector2) -> float: return path_wear(p),wet_tone)}
	var node: Node3D = KitLand.island(spec)
	node.name = "NaveIsle"
	return node
