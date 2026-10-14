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
## - The seesaw on the south terrace is the real trap_seesaw_drop.
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
	[Vector3(7.5,-1.0,33.0),"CHAIN 3 · seesaw_drop on the south terrace"],
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
	return "Two wind horns, one bellows: a run in their sight, a jump or a splash wakes them. Creep, or hide under the arcade roofs.\nOr ride the blast: hop on the north apron to be blown into the tower's kick shaft (kick up to the sill), or by the fallen NE corner to be blown out to the far satellite."

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
