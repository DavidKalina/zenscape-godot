extends RefCounted
## The wreck cluster's numbers and land (studies/wreck_cluster.gd): four
## land masses round the origin at TOP, one silhouette in open sky.
##
##   main     the long body: the plane parked at its west end on a strip
##            running east to the edge (STRIP), two crisp turf tiers on its
##            north side (TIER_A a plain jump-catch up, TIER_B a chained one),
##            an air ring over tier A throwing up to a floating perch, a
##            broken wall and a fallen pier
##   spire    north-east, a deep-keeled rock a jump-catch over a SPIRE_GAP
##            gap off the main's north rim, the kit's tower shell on it: in
##            at its door, kick up the shaft to the coping
##   rope     west, an islet ROPE_GAP m off the main's west rim, a swing
##            rope's frame on each side (there and back)
##   knight   south-east, an islet on the end of a narrow causeway (the
##            rune knight's deck) a hop off the main's south rim
##
## Every gap and rise here is sized from the walker (RuinKit GRAB_TOP 1.875,
## CHAIN_TOP 2.575, the jumps' carries; `tools/kit_piece.py numbers`).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const RuinKitTower = preload("res://scripts/ruin_kit_tower.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")

## The main's turf (world y).
const TOP := 30.0
## Tier A: a plain jump catches its lip (SET_OFF, under GRAB_TOP); tier B
## on it: the chained jump catches it (2.2 over A, under CHAIN_TOP).
static var TIER_A_RISE: float = RuinKit.SET_OFF
const TIER_B_RISE := 2.2
const TIER_A := Rect2(-34.0,-24.0,30.0,18.0)
const TIER_B := Rect2(-28.0,-24.0,12.0,12.5)
## The take-off strip: a clear run along z STRIP_Z from the plane east to
## the main's east rim (about 75 m), STRIP_HALF either side kept clear.
const STRIP_Z := 6.0
const STRIP_HALF := 6.0
## The parked plane: its middle on the strip's west end, facing east
## (heading -PI/2: forward is (-sin h, 0, -cos h)).
const PLANE_AT := Vector2(-30.0,STRIP_Z)
const PLANE_HEADING := -PI*0.5

## The spire's landing over the main's turf: one jump-catch up (under
## GRAB_TOP once the gap is crossed), the gap a running jump's (carry 2.38
## level); behind the landing (north of SPIRE_LEDGE m in from its south rim)
## a crag a plain jump-catch higher again (SET_OFF) to the tower's plateau.
const SPIRE_RISE := 1.2
const SPIRE_GAP := 1.6
const SPIRE_LEDGE := 2.7
const TOWER_AT := Vector2(30.0,-25.6)
## The tower shell's height: a short kick (scripts/ruin_kit_tower.gd LOWEST 5).
const TOWER_HEIGHT := 9.0
## The rope islet: ROPE_GAP m of sky off the main's west rim, past a long
## jump's carry (4.24) and inside a swing rope's run-in swing let go well
## (about 7 m, the wreck round's drive; pumped, far more:
## scripts/interactables/swing_rope.gd), ROPE_DROP m under the main.
const ROPE_GAP := 5.0
const ROPE_DROP := 0.5
## The knight's causeway: CAUSEWAY_HALF m either side of x 24, a hop
## (CAUSEWAY_GAP) off the main's south rim, to the knight's islet.
const CAUSEWAY_X := 24.0
const CAUSEWAY_HALF := 1.4
const CAUSEWAY_FROM := 19.0
const CAUSEWAY_TO := 37.0

# --- Outlines ---------------------------------------------------------------------

## The main body (x, z), its north rim at x 30 about z -16.7, its south rim at
## x 24 about z 17.3, its west rim about x -47.6.
static func main_outline() -> Array:
	return [Vector2(-48.0,-2.0),Vector2(-46.0,-10.0),Vector2(-38.0,-17.0),Vector2(-24.0,-20.0),Vector2(-8.0,-19.0),
		Vector2(8.0,-18.0),Vector2(22.0,-17.0),Vector2(34.0,-16.5),Vector2(44.0,-11.0),Vector2(49.0,-3.0),
		Vector2(49.0,8.0),Vector2(44.0,14.0),Vector2(32.0,17.0),Vector2(20.0,17.5),Vector2(6.0,18.0),
		Vector2(-10.0,17.0),Vector2(-26.0,16.0),Vector2(-40.0,13.0),Vector2(-47.0,6.0)]

## The spire: its south rim SPIRE_GAP north of the main's at x 27..33.
static func spire_outline() -> Array:
	var s := SPIRE_SOUTH
	return [Vector2(27.0,s),Vector2(33.0,s),Vector2(36.0,s-3.2),Vector2(36.5,s-7.7),Vector2(34.0,s-11.7),
		Vector2(30.0,s-12.9),Vector2(26.0,s-11.7),Vector2(23.5,s-7.7),Vector2(24.0,s-3.2)]

## The rope islet: its east rim ROPE_GAP west of the main's.
static func rope_east() -> float:
	return -47.6-ROPE_GAP

static func rope_outline() -> Array:
	var e := rope_east()
	return [Vector2(e,-3.0),Vector2(e,5.0),Vector2(e-2.4,9.5),Vector2(e-7.4,11.0),Vector2(e-12.4,9.0),
		Vector2(e-14.9,4.0),Vector2(e-14.4,-2.0),Vector2(e-11.4,-6.5),Vector2(e-6.4,-7.5),Vector2(e-2.4,-6.0)]

## The knight's islet with its causeway (one land).
static func knight_outline() -> Array:
	var w := CAUSEWAY_X-CAUSEWAY_HALF
	var e := CAUSEWAY_X+CAUSEWAY_HALF
	return [Vector2(w,CAUSEWAY_FROM),Vector2(e,CAUSEWAY_FROM),Vector2(e,CAUSEWAY_TO),Vector2(30.0,38.0),Vector2(33.0,42.0),
		Vector2(33.5,47.0),Vector2(30.0,51.5),Vector2(24.0,53.0),Vector2(18.0,51.5),Vector2(14.5,47.0),
		Vector2(15.0,42.0),Vector2(18.0,38.0),Vector2(w,CAUSEWAY_TO)]

# --- Ground -----------------------------------------------------------------------

static func main_ground(x: float, z: float) -> float:
	var p := Vector2(x,z)
	if TIER_B.has_point(p): return TOP+TIER_A_RISE+TIER_B_RISE
	if TIER_A.has_point(p): return TOP+TIER_A_RISE
	return TOP

## The spire's south rim (z) and its ground: the landing, then the plateau.
const SPIRE_SOUTH := -16.7-SPIRE_GAP
static func spire_top() -> float:
	return TOP+SPIRE_RISE

static func plateau_top() -> float:
	return spire_top()+RuinKit.SET_OFF

static func spire_ground(_x: float, z: float) -> float:
	return spire_top() if z > SPIRE_SOUTH-SPIRE_LEDGE else plateau_top()

static func rope_top() -> float:
	return TOP-ROPE_DROP

## The lands: [name, outline, ground, depth (its keel under its rim), seed,
## cliffs box (none: Rect2()), its rim's height].
static func lands() -> Array:
	var sp := spire_top()
	var rp := rope_top()
	return [
		["main",main_outline(),func(x: float, z: float) -> float: return main_ground(x,z),26.0,401,Rect2(-40.0,-26.0,40.0,22.0),TOP],
		["spire",spire_outline(),func(x: float, z: float) -> float: return spire_ground(x,z),60.0,402,Rect2(22.0,-34.0,16.0,17.0),sp],
		["rope",rope_outline(),func(_x: float, _z: float) -> float: return rp,14.0,403,Rect2(),rp],
		["knight",knight_outline(),func(_x: float, _z: float) -> float: return TOP,18.0,404,Rect2(),TOP],
	]

## Land `spec` (a row of `lands`) built: a KitLand island, its sides collided.
static func build_land(spec: Array) -> Node3D:
	var cliffs: Rect2 = spec[5]
	var d := {"outline":spec[1],"seed":int(spec[4]),"ground":spec[2],"top":float(spec[6]),
		"depth":float(spec[3]),"hang":true,"resample":[60.0,128,48],"tone":KitLook.turf(int(spec[4])),"cell":2.0,
		"collide_sides":true,"name":"wreck_cluster/"+str(spec[0])}
	if cliffs.size != Vector2.ZERO: d["cliffs"] = cliffs
	var node := KitLand.island(d)
	node.name = "Land_"+str(spec[0]).capitalize()
	return node

# --- What stands --------------------------------------------------------------------

## The kit pieces: [layout name, kit piece, seed, weathered, world foot,
## yaw (deg)], each colliding as the kit built it.
static func pieces() -> Array:
	return [
		["fallen_pier","fallen_pier",411,0.5,Vector3(-37.0,TOP,-3.5),20.0],
		["plane_wall","wall",418,0.6,Vector3(-35.5,TOP,0.2),0.0],
		["plane_pier","pier",419,0.5,Vector3(-33.5,TOP,-2.0),0.0],
		["wall","wall",412,0.3,Vector3(2.0,TOP,-6.0),0.0],
		["tier_wall","wall",413,0.55,Vector3(-12.0,TOP+TIER_A_RISE,-15.5),90.0],
		["rope_wall","wall",414,0.45,Vector3(rope_east()-8.4,rope_top(),-3.0),15.0],
		["chest","tomb_chest",415,0.4,Vector3(27.5,TOP,47.0),-30.0],
		["knight_pier","fallen_pier",416,0.6,Vector3(19.0,TOP,44.0),70.0],
	]

## The tower shell on the spire, its door (front, +Z) toward the main.
static func tower() -> Node3D:
	var t := RuinKitTower.tower_shell(417,0.35,TOWER_HEIGHT)
	t.name = "TowerShell"
	return t

static func tower_foot() -> Vector3:
	return Vector3(TOWER_AT.x,plateau_top(),TOWER_AT.y)

## The swing ropes' frames: [layout name, middle's foot, lintel way (x, z)].
## Run into the rope through the frame: west off the main, east back.
static func rope_frames() -> Array:
	return [
		["rope_out",Vector3(-44.0,TOP,2.5),Vector2(0.0,1.0)],
		["rope_back",Vector3(rope_east()-3.0,rope_top(),2.5),Vector2(0.0,1.0)],
	]

## A frame's lintel underside over its foot: the rope's knot at the
## walker's hands (SwingRope KNOT).
static func frame_height() -> float:
	return SwingRope.LENGTH+SwingRope.KNOT

## The air ring over tier A (flat: it throws him straight up its POP) and
## the floating perch beside its throw.
const RING_AT := Vector3(-10.0,TOP+1.6+1.3,-11.0)
const PERCH := {"name":"perch","at":Vector3(-7.3,TOP+1.6+5.7,-11.0),"size":Vector3(2.4,0.7,2.2),"yaw":0.2,"kind":"block"}

## The knight's line (scripts/enemies/rune_knight.gd `setup`): along the
## causeway from the main's end (local x along world +z), its deck the turf.
static func knight_line() -> Dictionary:
	var xf := Transform3D(Basis(Vector3(0.0,0.0,1.0),Vector3.UP,Vector3(-1.0,0.0,0.0)),Vector3(CAUSEWAY_X,0.0,CAUSEWAY_FROM))
	return {"xf":xf,"head":0.8,"snap":CAUSEWAY_TO-CAUSEWAY_FROM-0.5,"deck":TOP,"half":CAUSEWAY_HALF+0.4}

# --- The part spots -----------------------------------------------------------------

## The candidate spots for the plane's six parts: [mass, what it asks, world
## point (x, a height over what it rests on, z)]. Named
## `wreck_cluster/part_spot_NN` (NN from 01 in this order) for the world
## view; the deal settles each onto what's under it.
static func spots() -> Array:
	var a := TOP+TIER_A_RISE
	var b := a+TIER_B_RISE
	var sp := spire_top()
	var pl := plateau_top()
	var rp := rope_top()
	return [
		["main","by the plane",Vector3(-38.5,TOP,-7.0)],
		["main","tier A (jump-catch)",Vector3(-31.0,a,-10.0)],
		["main","tier B (chained catch)",Vector3(-22.0,b,-16.0)],
		["main","on the broken wall",Vector3(2.0,TOP+2.6,-6.0)],
		["main","the perch (air ring)",Vector3(-7.3,TOP+1.6+5.7,-11.0)],
		["main","east rim by the spire",Vector3(40.0,TOP,-9.0)],
		["main","south rim by the causeway",Vector3(14.0,TOP,14.0)],
		["spire","the spire's landing (jump-catch)",Vector3(31.5,sp,-19.6)],
		["spire","before the tower door (crag)",Vector3(28.0,pl,-22.0)],
		["spire","behind the tower",Vector3(30.0,pl,-29.8)],
		["spire","tower coping (wall-kick top)",Vector3(TOWER_AT.x+RuinKitTower.KICK_GAP*0.5+RuinKitTower.WALL*0.5,pl+TOWER_HEIGHT,TOWER_AT.y)],
		["rope","rope islet middle",Vector3(rope_east()-7.4,rp,1.0)],
		["rope","on the islet's wall",Vector3(rope_east()-8.4,rp+2.6,-3.0)],
		["rope","rope islet far lip",Vector3(rope_east()-12.9,rp,3.0)],
		["knight","the causeway (his deck)",Vector3(CAUSEWAY_X,TOP,28.0)],
		["knight","behind him on the islet",Vector3(24.0,TOP,45.0)],
		["knight","on the carved chest",Vector3(27.5,TOP+1.1,47.0)],
	]

static func spot_name(i: int) -> String:
	return "wreck_cluster/part_spot_%02d" % (i+1)
