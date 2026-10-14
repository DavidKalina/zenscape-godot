extends "res://scripts/kit_isle/motif_greybox.gd"
## The Vigil of the Bellows in the generator: studies/greybox/vigil_bellows.gd's
## LAYOUT (card: docs/design/roguelike/brainstorm/round1/motif-m3-the-vigil-
## of-the-bellows.md, its "Greybox (Opus pass)"), the same geometry in the
## same frame, so its gust lines keep the study's numbers. A cloister garth
## round a still pool, the star tower on the north side (its kick shaft up
## to the sill under the tower horn), a gate tower on the south range with
## the second horn, four arcade ranges of roofed bays, the fallen NE corner.
##
## Changes from the study:
## - The horns are the real ward (scripts/wind_horn.gd `watch`, docs/design/
##   roguelike/wind-horn-blows.md), not the study's stand-in: they sweep,
##   wake on a run in sight, a jump or a splash, draw breath and fire the
##   gust arrows' ball (the default shot). Their arcs and reaches are the
##   study's; the shared bellows is `may_draw` (one breath at a time). The
##   tower horn keeps the dressing pitch (PITCH_DOWN 0.3), as in the study,
##   so "under its lip" (the sill, the shaft) stays out of its reach and the
##   pool stays the gate horn's (the deeper ward pitch let the tower horn
##   take chain 1 and throw it the wrong way).
## - Satellite 1 (the study's stand-in for the next isle, where chain 4 and
##   the sill's slab bridge land) is part of the motif; the rim out is its
##   east edge. The rim in is satellite 2's west edge (the study's start).
## - The seesaw on the south terrace is the real trap_seesaw_drop. The
##   study's chain 3 (the gate horn gusting the seesaw's throw on, mid-air)
##   does not hold with the horn's ball (it leads flat pace only, so it
##   misses a ballistic body: wind-horn-blows.md), so a catching cannon
##   (CANNON) now takes the throw where it comes down in the south apron
##   and fires it out through the fallen corner onto satellite 1: seesaw,
##   cannon, the rim out. Climbed into by hand it is also a way out.
## - Turfed (below): kit land, cut stone, still water; `--vigil-grey` for
##   the grey boxes.
## - The tech stays the motor's default (off): chain 2 from the north apron
##   skids him into the shaft without it.

# --- The study's numbers, verbatim (studies/greybox/vigil_bellows.gd) ------------------
const ISLE_BOTTOM := -6.0
const ISLES := [
	{"name":"garth","rect":Rect2(-22.0,-18.0,44.0,36.0),"top":0.0,"holes":[Rect2(-15.0,-12.0,12.0,13.0)]},
	{"name":"lavabo isle","rect":Rect2(-11.0,-7.5,4.0,4.0),"top":0.4},
	{"name":"star tower","rect":Rect2(-6.0,-28.0,12.0,16.0),"tiers":[
		[Rect2(-6.0,-28.0,4.6,16.0),6.0,"lip"],
		[Rect2(1.4,-28.0,4.6,16.0),9.0,"grey"],
		[Rect2(-1.4,-28.0,2.8,10.0),9.0,"grey"],
	]},
	{"name":"sill walk (behind the tower)","rect":Rect2(-6.0,-32.0,12.0,4.0),"top":6.0},
	{"name":"satellite 2 (W, the way in)","rect":Rect2(-40.0,0.0,12.0,12.0),"top":0.0},
	{"name":"bridge W","rect":Rect2(-28.0,5.0,6.0,2.0),"top":0.0},
	{"name":"satellite 1 (NE; the way out leaves its east edge)","rect":Rect2(26.0,-34.0,14.0,42.0),"top":0.0},
	{"name":"NE bridge head (wide landing)","rect":Rect2(22.0,-18.0,4.0,26.0),"top":0.0},
	{"name":"satellite 3 (S terrace, seesaw)","rect":Rect2(-22.0,18.0,44.0,16.0),"top":-3.0},
	{"name":"NE scree (catch)","rect":Rect2(12.0,-30.0,14.0,12.0),"top":-1.2},
]
const POOL := {"rect":Rect2(-15.0,-12.0,12.0,13.0),"bed":-0.9,"surface":-0.3}
const RAMPS := [
	["pool beach N",Vector3(-9.0,0.0,-12.0),Vector3(-9.0,-0.9,-9.6),12.0,"grey"],
	["pool beach S",Vector3(-9.0,0.0,1.0),Vector3(-9.0,-0.9,-1.4),12.0,"grey"],
	["terrace stair to the wall-walk",Vector3(-14.0,-3.0,30.0),Vector3(-14.0,2.4,18.0),2.4,"grey"],
	["sill exit (slab bridge)",Vector3(26.0,0.0,-31.0),Vector3(6.0,6.0,-31.0),2.0,"grey"],
]
const BOXES := [
	["south wall-walk",Rect2(-22.0,16.0,44.0,2.0),0.0,2.4,"lip"],
	["west wall N",Rect2(-22.0,-18.0,2.0,22.0),0.0,4.5,"wall"],
	["west wall S",Rect2(-22.0,8.0,2.0,8.0),0.0,4.5,"wall"],
	["east wall",Rect2(20.0,-1.0,2.0,17.0),0.0,4.5,"wall"],
	["north wall W",Rect2(-22.0,-18.0,16.0,2.0),0.0,4.5,"wall"],
	["north wall E",Rect2(6.0,-18.0,6.0,2.0),0.0,4.5,"wall"],
	["gate tower",Rect2(-2.5,12.0,5.0,6.0),0.0,7.0,"wall"],
	["tower corbel",Rect2(-6.0,-28.0,7.4,8.0),8.6,9.1,"wall"],
	["sill parapet",Rect2(-6.0,-12.6,4.6,0.6),6.0,7.8,"wall"],
	["shaft lintel",Rect2(-1.4,-12.6,2.8,0.6),2.2,9.0,"wall"],
	["stone E",Rect2(-5.9,-6.3,1.6,1.6),-0.9,0.0,"grey"],
	["lavabo prize",Rect2(-9.5,-5.0,1.0,1.0),0.4,0.5,"pad"],
	["lavabo roof",Rect2(-10.6,-7.1,3.2,3.2),2.7,3.0,"wall"],
]
const POSTS := [
	[Vector2(-9.0,-6.2),0.3,0.4,2.7],
]
const ARCADE_ROOF := Vector2(1.7,2.4)
const ARCADE_GAP := 1.6
const PIER_R := 0.35
const RANGES := [
	{"name":"south range W","rect":Rect2(-20.0,12.0,17.5,4.0),"bays":3},
	{"name":"south range E","rect":Rect2(2.5,12.0,17.5,4.0),"bays":3},
	{"name":"west range","rect":Rect2(-20.0,-12.0,4.0,24.0),"bays":4},
	{"name":"east range","rect":Rect2(16.0,-1.0,4.0,13.0),"bays":3},
	{"name":"north range W","rect":Rect2(-20.0,-16.0,14.0,4.0),"bays":3},
	{"name":"north range E","rect":Rect2(6.0,-16.0,6.0,4.0),"bays":1},
]
## The horns: the study's foot, yaw (deg, 0 faces south), seed, arc (deg
## either side), range (m: the ward's `reach`), and the tower's pitch kept
## at the dressing PITCH_DOWN ("pitch", see the header).
const HORNS := [
	{"id":"tower","pos":Vector3(-3.5,9.1,-22.0),"yaw":0.0,"seed":3,"arc":32.0,"range":32.0,"pitch":0.3},
	{"id":"gate","pos":Vector3(0.0,7.0,15.0),"yaw":180.0,"seed":5,"arc":90.0,"range":36.0},
]
const TRAPS := [
	{"name":"seesaw_drop","pos":Vector3(7.5,-3.0,30.0),"yaw":0.0,"knobs":{"ledge":0.0}},
]
## The catching cannon (scripts/cannon/cannon.gd, docs/design/roguelike/
## cannon-catch.md) in the south apron, its mouth on the seesaw's throw as
## it comes down (measured: the throw peaks 17.3 m over the south range and
## falls at 18 m/s along x 7.5, 9.7 m/s north, 62 deg steep), its barrel
## laid 55 deg up toward the NE satellite, so the throw goes in along it and
## out at satellite 1 through the fallen corner. Foot, heading (deg, the
## shot's yaw: PilotMotor.forward), pitch (deg), power notch.
const CANNON := {"pos":Vector3(6.27,0.0,3.78),"heading":-54.5,"pitch":55.0,"power":4}
const LABELS := [
	[Vector3(-3.5,13.0,-22.0),"TOWER HORN (on the corbel; watches the court's middle, blows it SOUTH)"],
	[Vector3(0.0,11.5,15.0),"GATE HORN (watches the north half, blows it NORTH)"],
	[Vector3(0.0,10.0,-15.0),"STAR TOWER · kick shaft 2.8 m x 6 m (east wall is the kick wall)"],
	[Vector3(-3.8,8.2,-16.0),"SILL 6.0 m · under the tower horn, behind the parapet"],
	[Vector3(16.0,7.5,-31.0),"sill exit to satellite 1 (slab bridge)"],
	[Vector3(19.0,0.6,-24.0),"NE SCREE (catches the corner's spill)"],
	[Vector3(-9.0,3.6,-5.5),"LAVABO (prize)"],
	[Vector3(-9.0,1.4,-11.0),"POOL · a splash wakes the horns"],
	[Vector3(0.0,3.4,10.0),"SOUTH APRON · under both horns' lips (blind)"],
	[Vector3(-18.0,3.2,0.0),"WEST BAYS · roofed (cover from both)"],
	[Vector3(17.0,2.0,-12.0),"NE CORNER FALLEN · the gust line out"],
	[Vector3(-12.0,3.4,17.0),"WALL-WALK 2.4 m (the gate horn sees it past 10 m)"],
	[Vector3(7.5,-1.0,33.0),"CHAIN 3 · seesaw_drop: stand on its plate, thrown over the range"],
	[Vector3(6.3,4.6,3.8),"CANNON · catches the seesaw's throw, fires it out to satellite 1"],
	[Vector3(33.0,1.8,-20.0),"SATELLITE 1 · the way on leaves its east edge"],
	[Vector3(-12.5,1.6,-8.5),"CHAIN 1 · splash here"],
	[Vector3(0.0,1.6,-6.0),"CHAIN 2 · hop here: blown into the shaft, kick up to the sill"],
	[Vector3(15.0,1.6,-3.0),"CHAIN 4 · hop here: blown out to satellite 1"],
]
## The study's stations (for checks): name -> [spawn, face].
const STATIONS := {
	"start":[Vector3(-34.0,0.0,6.0),Vector2(1.0,0.0)],
	"west_bays":[Vector3(-18.2,0.0,8.0),Vector2(0.0,-1.0)],
	"shaft":[Vector3(0.0,0.0,-13.0),Vector2(0.0,-1.0)],
	"sill":[Vector3(-3.6,6.0,-15.0),Vector2(0.0,-1.0)],
	"chain1":[Vector3(-12.5,-0.9,-8.5),Vector2(0.0,1.0)],
	"chain2":[Vector3(0.0,0.0,-6.0),Vector2(0.0,-1.0)],
	"chain3":[Vector3(7.5,-3.0,33.0),Vector2(0.0,-1.0)],
	"chain4":[Vector3(15.0,0.0,-3.0),Vector2(0.7,-0.7)],
}

const Horn = preload("res://scripts/ruin_kit_horn.gd")
const SeesawDrop = preload("res://scripts/traps/trap_seesaw_drop.gd")

func slug() -> String:
	return "vigil_bellows"

func isle_name() -> String:
	return "The Vigil of the Bellows"

func epithet() -> String:
	return "The horn still blows at anything that moves; learn to be a stone."

func brief() -> String:
	return "Two wind horns, one bellows: a run in their sight, a jump or a splash wakes them. Creep, or hide under the arcade roofs.\nOr ride the blast: hop on the north apron to be blown into the tower's kick shaft (kick up to the sill), or by the fallen NE corner to be blown out to the far satellite. Or stand on the terrace seesaw's plate: thrown into the cannon, fired out."

func start() -> Vector3:
	return STATIONS.start[0]

func parts() -> Array:
	var out: Array = []
	for isle: Dictionary in ISLES:
		if isle.has("tiers"):
			for tier: Array in isle.tiers: out.append(["box",tier[0],ISLE_BOTTOM,tier[1],tier[2]])
		else:
			var holes: Array[Rect2] = []
			for h: Rect2 in isle.get("holes",[]): holes.append(h)
			var bottom := minf(ISLE_BOTTOM,float(isle.top)-3.0)
			for r: Rect2 in floor_rects(isle.rect,holes): out.append(["box",r,bottom,isle.top,"floor"])
	var pool: Rect2 = POOL.rect
	out.append(["box",pool,ISLE_BOTTOM,POOL.bed,"dark"])
	out.append(["water",pool,POOL.bed,POOL.surface])
	for b: Array in BOXES: out.append(["box",b[1],b[2],b[3],b[4]])
	for p: Array in POSTS: out.append(["cyl",p[0],p[1],p[2],p[3],"grey"])
	for r: Array in RAMPS: out.append(["ramp",r[1],r[2],r[3],r[4]])
	for bay: Rect2 in bays():
		out.append(["box",bay,ARCADE_ROOF.x,ARCADE_ROOF.y,"wall"])
		for px: float in [bay.position.x+PIER_R,bay.end.x-PIER_R]:
			for pz: float in [bay.position.y+PIER_R,bay.end.y-PIER_R]:
				out.append(["cyl",Vector2(px,pz),PIER_R,0.0,ARCADE_ROOF.x,"grey"])
	for l: Array in LABELS: out.append(["label",l[0],l[1]])
	return out

## In at satellite 2's west edge (the study's start, the horns' blind
## side), out off satellite 1's east edge (where chain 4 and the sill's
## slab bridge land).
func rims() -> Array:
	return [
		{"name":"west_satellite","at":Vector3(-39.0,0.0,6.0),"face":Vector3(-1.0,0.0,0.0),"run_up":10.0,"lip":1.0},
		{"name":"east_satellite","at":Vector3(39.0,0.0,-14.0),"face":Vector3(1.0,0.0,0.0),"run_up":12.0,"lip":1.0},
	]

func spots() -> Array:
	return [
		{"kind":"arena","name":"garth_apron","at":Vector3(6.0,0.0,4.0),"room":8.0},
		{"kind":"cover","name":"west_bays","at":Vector3(-18.0,0.0,0.0),"room":1.6},
		{"kind":"cover","name":"tower_door","at":Vector3(0.0,0.0,-14.0),"room":1.2},
		{"kind":"perch","name":"lavabo","at":Vector3(-9.0,0.4,-4.4),"room":1.5},
		{"kind":"perch","name":"sill","at":Vector3(-3.6,6.0,-15.0),"room":2.0},
	]

## Every bay's roof rect (x, z), from RANGES (the study's `bays`).
static func bays() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for range_row: Dictionary in RANGES:
		var r: Rect2 = range_row.rect
		var n := int(range_row.bays)
		var along_x := r.size.x >= r.size.y
		var long := r.size.x if along_x else r.size.y
		var pitch := long/n
		for i in n:
			var a := pitch*i+ARCADE_GAP*0.5
			var l := pitch-ARCADE_GAP
			if along_x: out.append(Rect2(r.position.x+a,r.position.y,l,r.size.y))
			else: out.append(Rect2(r.position.x,r.position.y+a,r.size.x,l))
	return out

## Under a bay's roof at `p` (this frame).
static func under_roof(p: Vector3) -> bool:
	for bay: Rect2 in bays():
		if bay.has_point(Vector2(p.x,p.z)) and p.y < ARCADE_ROOF.x: return true
	return false

## `room` less its holes, as rects (character_study `_floor_rects`).
static func floor_rects(room: Rect2, all_holes: Array[Rect2]) -> Array[Rect2]:
	var holes: Array[Rect2] = []
	for h in all_holes: if h.intersects(room): holes.append(h)
	var xs := [room.position.x,room.end.x]
	for h in holes: xs.append_array([h.position.x,h.end.x])
	xs.sort()
	var out: Array[Rect2] = []
	for i in range(xs.size()-1):
		var x0: float = xs[i]
		var x1: float = xs[i+1]
		if x1-x0 < 0.001: continue
		var cuts: Array = []
		for h in holes:
			if h.position.x < x1-0.001 and h.end.x > x0+0.001: cuts.append(Vector2(h.position.y,h.end.y))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var z := room.position.y
		for c: Vector2 in cuts:
			if c.x > z+0.001: out.append(Rect2(x0,z,x1-x0,c.x-z))
			z = maxf(z,c.y)
		if room.end.y > z+0.001: out.append(Rect2(x0,z,x1-x0,room.end.y-z))
	return out

## The two horns as the real ward (watching the walker, one bellows between
## them) and the seesaw on the south terrace. The horns hang off the host,
## so `g.get_meta("horns")` finds their Rigs for checks.
func live(g: Node) -> void:
	var motor: RefCounted = g.stage.study.motor
	var rigs := {}
	for row: Dictionary in HORNS:
		var node := Horn.wind_horn(int(row.seed),0.3)
		node.name = "Horn_"+str(row.id)
		node.position = g.w(row.pos)
		node.rotation_degrees.y = float(row.yaw)
		g.add_child(node)
		var rig: Node = Horn.rig(node)
		rig.yaw_arc = deg_to_rad(float(row.arc))
		rig.watch(motor,{"reach":float(row.range)})
		if row.has("pitch"): rig.pitch_down = float(row.pitch)
		rigs[row.id] = rig
	# The shared bellows: a horn draws breath only while the other is idle.
	for id: String in rigs:
		var rig: Node = rigs[id]
		var others: Array = []
		for o: String in rigs:
			if o != id: others.append(rigs[o])
		rig.may_draw = func() -> bool:
			for o: Node in others:
				if o.state != "watch": return false
			return true
	g.set_meta("horns",rigs)
	for row: Dictionary in TRAPS:
		var trap: Node3D = SeesawDrop.new()
		trap.configure(row.knobs)
		trap.position = g.w(row.pos)
		trap.rotation_degrees.y = float(row.yaw)
		g.trap(trap)
	# The stage makes its CannonField after the greybox isles' live bits
	# (scripts/roguelike/layer_stage.gd `setup`), so the cannon goes in once
	# the setup has run.
	var add_cannon := func() -> void:
		if not is_instance_valid(g) or g.cannons() == null: return
		var cannon: Node3D = g.cannons().add_cannon(g.w(CANNON.pos),deg_to_rad(float(CANNON.heading)),
			{"pitch_rest":deg_to_rad(float(CANNON.pitch)),"power_rest":int(CANNON.power)})
		g.set_meta("cannon",cannon)
	add_cannon.call_deferred()

# --- Turf pass: the land and the stone ---------------------------------------------------
## Built as kit terrain and cut stone, not grey boxes. The walked ground
## (the garth with the pool's bowl, the fallen NE corner and its scree, the
## NE bridge head and satellite 1) is one KitLand island whose ground
## function is the greybox's tiers exactly; satellite 2 (the way in) and the
## south terrace are islands of their own. Everything plumb (the ranges'
## back walls, the wall-walk, the gate tower, the star tower and its shaft,
## the sill, the corbel, the arcade bays' roofs and piers, the lavabo, the
## stepping stone, the bridges and the stair) is a walk box with the
## greybox's numbers, drawn as one mesh of chamfered stone in the kit's
## stone colour (scripts/kit_isle/greybox/giant_stone.gd's mesher), with a
## band of lit runes round the star tower (the star-watchers' carvings).
## Where the land meets a wall, its edge stands 1 m inside the wall, under
## the stone, so no leaning kit cliff shows past a plumb face. The pool is
## the kit's still water (KitWater). The LAYOUT stays the one table: the
## occupancy is still computed from parts() (plus the keels, `_solids`).
## `--vigil-grey` builds the grey boxes instead (A/B checks).

const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")

const TURF_SEED := 5300
## The stones' bottom (m): under the land, so a wall's face runs past its edge.
const FOOT := -2.5
## The keels (m under their datum) and how far a keel's spurs hang under
## top-depth (the giant's KEEL_REACH), for the occupancy.
const MAIN_DEPTH := 10.0
const WEST_DEPTH := 6.0
const TERRACE_DEPTH := 8.0
const KEEL_REACH := 1.4
## The south terrace's top and the scree's.
const TERRACE := -3.0
const SCREE := -1.2

static func grey() -> bool:
	return preload("res://scripts/launch_args.gd").user_args().has("--vigil-grey")

## The main island's ground (this frame): the garth at 0, the pool's bowl
## (bed and its north and south beaches), the scree under the fallen corner.
static func ground(x: float, z: float) -> float:
	if x >= 12.0 and x <= 26.0 and z >= -30.0 and z < -18.0: return SCREE
	var pool: Rect2 = POOL.rect
	if pool.has_point(Vector2(x,z)):
		var bed := float(POOL.bed)
		if z < -9.6: return lerpf(0.0,bed,(z+12.0)/2.4)
		if z > -1.4: return lerpf(bed,0.0,(z+1.4)/2.4)
		return bed
	return 0.0

## The main island's edge: round the garth 1 m inside its walls (round the
## tower 1 m inside its stone, the bridge W's gap in the west wall open),
## the scree, satellite 1 and its bridge head.
static func main_outline() -> Array:
	return [Vector2(-21.0,-17.0),Vector2(-5.0,-17.0),Vector2(-5.0,-31.0),Vector2(5.0,-31.0),Vector2(5.0,-17.0),
		Vector2(12.0,-17.0),Vector2(12.0,-30.0),Vector2(26.0,-30.0),Vector2(26.0,-34.0),Vector2(40.0,-34.0),
		Vector2(40.0,8.0),Vector2(21.0,8.0),Vector2(21.0,17.0),Vector2(-21.0,17.0),Vector2(-21.0,8.0),
		Vector2(-22.5,8.0),Vector2(-22.5,4.0),Vector2(-21.0,4.0)]

static func west_outline() -> Array:
	return _rounded(Rect2(-40.0,0.0,12.0,12.0),1.6)

## The south terrace, its north edge under the wall-walk.
static func terrace_outline() -> Array:
	var r := Rect2(-22.0,17.0,44.0,17.0)
	var cut := 2.0
	return [Vector2(r.position.x,r.position.y),Vector2(r.end.x,r.position.y),Vector2(r.end.x,r.end.y-cut),
		Vector2(r.end.x-cut,r.end.y),Vector2(r.position.x+cut,r.end.y),Vector2(r.position.x,r.end.y-cut)]

static func _rounded(r: Rect2, cut: float) -> Array:
	var a := r.position
	var b := r.end
	return [Vector2(a.x+cut,a.y),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),Vector2(b.x,b.y-cut),
		Vector2(b.x-cut,b.y),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),Vector2(a.x,a.y+cut)]

## The worn ways: over the bridge W into the west bays, along the south
## apron (the blind band), the north apron to the shaft's door, out by the
## fallen corner over the bridge head to the rim out.
static func paths() -> Array:
	return [[Vector2(-38.0,6.0),Vector2(-22.0,6.0),Vector2(-18.0,6.0),Vector2(-18.0,-8.0)],
		[Vector2(-16.0,9.5),Vector2(0.0,9.0),Vector2(16.0,9.5)],
		[Vector2(0.0,-5.0),Vector2(0.0,-12.6)],
		[Vector2(10.0,-5.0),Vector2(22.0,-8.0),Vector2(30.0,-14.0),Vector2(39.0,-14.0)]]

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top(),KitLand.wear_of(paths()))

func flora_seed() -> int:
	return TURF_SEED+9

func life_script() -> Script:
	return null if grey() else KitLife

func warm() -> void:
	super.warm()
	if grey(): return
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	RuinKit.materials()
	GiantStone.warm()

## The greybox's solids and the keels under the three islands (their
## spurs' reach), so the occupancy keeps the generator off the rock.
func _solids() -> Array:
	var out := super._solids()
	if grey(): return out
	for keel: Array in [[main_outline(),0.0,MAIN_DEPTH],[west_outline(),0.0,WEST_DEPTH],[terrace_outline(),TERRACE,TERRACE_DEPTH]]:
		var ring: Array = keel[0]
		var box := Rect2(ring[0],Vector2.ZERO)
		for p: Vector2 in ring: box = box.expand(p)
		out.append([box.grow(-1.0),float(keel[1])-float(keel[2])*KEEL_REACH,float(keel[1]),null])
	return out

## Measured headless on a loaded 4-core Linux box (the turf build, 2026-10-14: 958 ms).
func build_cost() -> int:
	return 0 if grey() else 950

## Turf on the ground, the cloister in stone, the pool's water.
func build(into: Node3D) -> void:
	if grey():
		super.build(into)
		return
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "VigilBellows"
	into.add_child(root)
	var pool: Rect2 = POOL.rect
	var wet := func(mid: Vector2, y: float) -> float: return 1.0 if pool.grow(0.3).has_point(mid) and y < -0.2 else 0.0
	var tone := KitLook.turf(TURF_SEED,KitLand.wear_of(paths()),wet)
	var main := KitLand.island({"outline":main_outline(),"seed":TURF_SEED,"ground":func(x: float, z: float) -> float: return ground(x,z),
		"top":0.0,"depth":MAIN_DEPTH,"cliffs":Rect2(-16.5,-31.0,43.5,33.5),"fine":1.2,"hang":true,"resample":[60.0,260,32],"tone":tone})
	main.name = "Garth"
	var west := KitLand.island({"outline":west_outline(),"seed":TURF_SEED+1,"ground":func(_x: float, _z: float) -> float: return 0.0,
		"top":0.0,"depth":WEST_DEPTH,"hang":true,"resample":[40.0,80,32],"tone":tone})
	west.name = "WestSatellite"
	var terrace := KitLand.island({"outline":terrace_outline(),"seed":TURF_SEED+2,"ground":func(_x: float, _z: float) -> float: return TERRACE,
		"top":TERRACE,"depth":TERRACE_DEPTH,"hang":true,"resample":[60.0,160,32],"tone":tone})
	terrace.name = "Terrace"
	for land: Node3D in [main,west,terrace]:
		_collide_sides(land)
		root.add_child(land)
		turf(land)
	root.add_child(KitWater.still({"name":"Pool","level":float(POOL.surface),
		"ground":func(x: float, z: float) -> float: return ground(x,z),
		"rect":pool.grow(0.6),"inside":func(_p: Vector2) -> bool: return true,"tea":0.35}))
	_stone(root)
	built_ms = Time.get_ticks_msec()-began

## An island's hanging sides collided as drawn (the giant's `_collide_sides`).
static func _collide_sides(land: Node3D) -> void:
	var sides := land.get_node_or_null("Mesh") as MeshInstance3D
	if sides == null or sides.mesh == null: return
	var body := StaticBody3D.new()
	body.name = "Sides"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(sides.mesh.get_faces())
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	land.add_child(body)

## The cloister's stone: one mesh, collided as the greybox's walk boxes.
func _stone(root: Node3D) -> void:
	var m: RefCounted = GiantStone.Mesher.new(Style.stone_of(TURF_SEED) if Style.ruled() else RuinKit.STONE.srgb_to_linear())
	var solids := Node3D.new()
	solids.name = "Walk"
	root.add_child(solids)
	# The star tower: the sill's tier, the east (kick) tier, the back wall,
	# and the sill walk behind.
	for isle: Dictionary in ISLES:
		if isle.has("tiers"):
			for tier: Array in isle.tiers: _block(m,solids,tier[0],FOOT,float(tier[1]),0.25,0.0)
		elif str(isle.name).begins_with("sill walk"): _block(m,solids,isle.rect,FOOT,float(isle.top),0.25,0.0)
		elif isle.name == "lavabo isle": _block(m,solids,isle.rect,float(POOL.bed)-0.3,float(isle.top),0.15,float(POOL.bed))
		elif str(isle.name).begins_with("bridge W"):
			var r: Rect2 = isle.rect
			_block(m,solids,Rect2(r.position.x-0.6,r.position.y,r.size.x+1.6,r.size.y),-0.7,0.0,0.12,-0.7)
	# The walls, the wall-walk (down to the terrace), the gate tower, the
	# corbel the tower horn stands on, the sill's parapet, the shaft's
	# lintel, the stepping stone, the lavabo's basin and roof.
	for b: Array in BOXES:
		var r: Rect2 = b[1]
		var bottom := float(b[2])
		var high := float(b[3])
		match str(b[0]):
			"lavabo prize":
				_walk(solids,r,bottom,high)
				m.cylinder(Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,(bottom+high)*0.5,r.get_center().y)),0.5,high-bottom,16,0.04,bottom,1.15)
			"south wall-walk": _block(m,solids,r,TERRACE-1.0,high,0.2,0.0)
			"stone E", "lavabo roof", "sill parapet", "shaft lintel", "tower corbel": _block(m,solids,r,bottom,high,0.1)
			_: _block(m,solids,r,FOOT,high,0.2,0.0)
	for p: Array in POSTS: _cyl(m,solids,p[0],float(p[1]),float(p[2]),float(p[3]))
	# The arcade: each bay's roof on its four piers.
	for bay: Rect2 in bays():
		_block(m,solids,bay,ARCADE_ROOF.x,ARCADE_ROOF.y,0.12,ARCADE_ROOF.x)
		for px: float in [bay.position.x+PIER_R,bay.end.x-PIER_R]:
			for pz: float in [bay.position.y+PIER_R,bay.end.y-PIER_R]:
				_cyl(m,solids,Vector2(px,pz),PIER_R,0.0,ARCADE_ROOF.x)
	# The stair up the terrace, the slab bridge from the sill to satellite 1.
	for ramp: Array in RAMPS:
		if str(ramp[0]).begins_with("pool"): continue
		_ramp(m,solids,ramp[1],ramp[2],float(ramp[3]))
	# The star-watchers' carvings: a band of lit runes round the tower.
	var band := 9.0-1.35
	m.runes(Vector3(6.0,band,-12.0),Vector3(1.4,band,-12.0),Vector3.UP,Vector3(0,0,1),1.0)
	m.runes(Vector3(6.0,band,-28.0),Vector3(6.0,band,-12.0),Vector3.UP,Vector3(1,0,0),2.0)
	m.runes(Vector3(-6.0,6.0-1.35,-12.0),Vector3(-6.0,6.0-1.35,-28.0),Vector3.UP,Vector3(-1,0,0),3.0)
	var body := MeshInstance3D.new()
	body.name = "Stone"
	body.mesh = GiantStone.mesh_of(m)
	root.add_child(body)
	root.set_meta("stone_triangles",m.triangles())

static func _block(m: RefCounted, solids: Node3D, r: Rect2, bottom: float, high: float, bevel: float, foot := NAN) -> void:
	_walk(solids,r,bottom,high)
	m.box(Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,(bottom+high)*0.5,r.get_center().y)),Vector3(r.size.x,high-bottom,r.size.y),bevel,foot)

static func _cyl(m: RefCounted, solids: Node3D, c: Vector2, radius: float, bottom: float, high: float) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(c.x,(bottom+high)*0.5,c.y)
	var holder := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = high-bottom
	holder.shape = shape
	body.add_child(holder)
	solids.add_child(body)
	m.cylinder(Transform3D(Basis.IDENTITY,body.position),radius,high-bottom,12,0.06,bottom)

## A ramp as the greybox's (its walked top from `low` to `high`, 0.4 thick,
## collided), drawn a slab twice as thick under it.
static func _ramp(m: RefCounted, solids: Node3D, low: Vector3, high: Vector3, width: float) -> void:
	var along := (high-low).normalized()
	var side := Vector3.UP.cross(along).normalized()
	var up := along.cross(side).normalized()
	var length := low.distance_to(high)+0.02
	var place := Transform3D(Basis(side,up,along),(low+high)*0.5-up*0.2)
	var body := StaticBody3D.new()
	body.transform = place
	var holder := CollisionShape3D.new()
	holder.shape = _box_shape(Vector3(width,0.4,length))
	body.add_child(holder)
	solids.add_child(body)
	m.box(Transform3D(place.basis,(low+high)*0.5-up*0.4),Vector3(width,0.8,length),0.1)

static func _walk(solids: Node3D, r: Rect2, bottom: float, high: float) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(r.get_center().x,(bottom+high)*0.5,r.get_center().y)
	var holder := CollisionShape3D.new()
	holder.shape = _box_shape(Vector3(r.size.x,high-bottom,r.size.y))
	body.add_child(holder)
	solids.add_child(body)
