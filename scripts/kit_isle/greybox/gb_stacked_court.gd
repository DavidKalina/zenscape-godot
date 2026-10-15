extends "res://scripts/kit_isle/motif_greybox.gd"
## The Stacked Court (card: docs/design/roguelike/brainstorm/round3-olmec-
## city/motif-stacked-court.md), a place of the underground Olmec city built
## from the city kit (scripts/city_kit.gd, its fires): basalt pillar-isles
## stacked a course-set apart, each layer further back and higher, round a
## court of air. You arrive on the lowest and look up at the lit crowns.
##
##   F  the forecourt (crown 0): the arrival, a KitLand turf crown on a bare
##      pillar. The serpent stair climbs north from it to M; beside the
##      stair a beacon tower stands with its back to M's face.
##   M  the well (crown 3 courses up): the drum stair wound down its well, a
##      great cresset unlit on its core floor. The stair lands on its south
##      ring; the Keeper walks its north ring.
##   U, T  the west and east pillars (crowns 6 courses up), set flush (a
##      seam) to M's north-west and north-east faces, collared three courses
##      down to M's crown, their prism chains facing M. The causeway runs
##      from U's crown to T's behind the well, its two middle piers standing
##      on M's north ring, its breakable bay over the Keeper's beat. T bears
##      the summit's beacon tower (9 courses up) and the way out.
##   the needle  a lone pillar far behind, higher than all, its tower lit:
##      the layer above.
## Alone (the motif yard) a few far pillars with lit crowns stand off in the
## haze, the layers in the distance; in a layer the other isles are those.
##
## Routes (rim in on F's south edge, rim out on T's far edge):
##   the court   the serpent stair, west round M's ring past the well, U's
##               collar chain, U's crown, the causeway east, T's crown.
##   the tower   F's beacon tower (its giant steps; your torch lights its
##               crown, and every Olmec near turns to it), across the seam
##               onto M's ring, east round it, T's collar chain to its crown.
## The well is the way down and the Keeper's home, not a way up: the drum
## stair has no door out of its core (city-kit-round1.md, Limits).
##
## Threat: the Keeper (a whole Olmec, chase on) walks M's north ring (a
## STAND-IN beat), under the causeway's bay; an inhaler head holds T's crown
## at the causeway's end, its headless body coming up the cliffs; the
## breakables hub is every Olmec's breaker (the bay, the stair's fault, the
## cressets). The unlit cressets (F's tower, M's ring, the well's core, the
## forecourt) call them when lit; the lit ones have burned too long to.
##
## Everything is one LAYOUT table; where the pillars stand is solved from it
## in `place_of`.
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const Underground = preload("res://scripts/underground/underground.gd")

const COURSE := CityKit.COURSE
const SEED := 7300

# --- The layout: one table ----------------------------------------------------------------
## Heights in courses (COURSE, 4.8 m: a collar, a flight, a drum turn).
## Apothems in m (centre to a flat face). `seam`: the gap left between two
## pillars set face to face (m: a step across, never stone in stone).
## The frame: M's centre at x z 0, F to the south (+z), the arrival on F
## looking north (-z). Offsets (x, z) are from their pillar's centre.
const LAYOUT := {
	"seam":0.5,
	# The shafts all fade to this depth (m) into the haze.
	"floor":-70.0,
	# Each turfed crown's cap: a KitLand turf island on the bare crown, its
	# ragged edge grown out past the stone up to `grow` m (hanging earth and
	# roots) but for the `keep` faces, tucked inside the lip (a seam to a
	# neighbour, or a climb face whose lip is grabbed).
	"forecourt":{"apothem":40.0,"crown":0,"wear":0.6,"cap":{"grow":4.0,"keep":[3],"seed":SEED+1},
		# Its turf's west terraces, each a set-off up (grabbable cliffs), their
		# edges (local x) wandering; clear of the stair's flank (x -14.6).
		"terraces":[-19.0,-30.0]},
	"well":{"apothem":CityKit.DRUM_RADIUS+CityKit.LANDING,"crown":3,"wear":0.5},
	# U and T: the face of M each is set to (hex_dir), their size.
	"west":{"apothem":16.0,"crown":8,"courses":5,"on_face":4,"climb":1,"wear":0.7,"cap":{"grow":2.6,"keep":[1],"seed":SEED+11}},
	"east":{"apothem":16.0,"crown":8,"courses":5,"on_face":2,"climb":5,"wear":0.45,"cap":{"grow":2.6,"keep":[5],"seed":SEED+12}},
	"needle":{"at":Vector2(-24.0,-124.0),"apothem":12.0,"crown":24,"courses":4,"wear":0.8,"cap":{"grow":3.0,"keep":[],"seed":SEED+13}},
	# The serpent stair: its fault landing (1-based).
	"stair":{"fault":1,"wear":0.55},
	# The causeway: its spans, the breakable bay, its line (z m) over M's
	# north ring (its middle piers stand on the ring there).
	"causeway":{"spans":3,"bay":1,"line":-32.0,"wear":0.6},
	# The beacon towers: F's beside the stair, its back to M (unlit: the
	# tower route); T's on its crown (lit: the summit); the needle's (lit).
	"towers":{"forecourt":{"at":Vector2(19.0,0.0),"base":7.2,"lit":false},"summit":{"at":Vector2(5.0,-2.0),"lit":true},"needle":{"lit":true}},
	# The cressets: [on (a pillar), offset (x, z), level over its crown
	# (courses), size, lit].
	"cressets":[
		["well",Vector2(0.0,0.0),-2,"great",false],     # the drum's core floor
		["well",Vector2(-28.6,16.5),0,"cresset",false], # M's south-west ring
		["well",Vector2(28.6,16.5),0,"cresset",false],  # M's south-east ring
		["west",Vector2(-5.0,6.0),0,"cresset",true],    # U's crown, off the causeway's end
		["forecourt",Vector2(-24.0,20.0),0,"great",false], # the forecourt, west of the stair's foot
	],
	# The Keeper's beat on M's north ring (offsets from M), his first look.
	"keeper":{"beat":[Vector2(-12.0,-31.0),Vector2(0.0,-33.0),Vector2(12.0,-31.0)],"face":Vector2(0.0,1.0)},
	# The inhaler head on T's crown at the causeway's end, facing down it.
	"head":{"at":Vector2(-8.0,-1.0),"face":Vector2(-1.0,0.0)},
	# Fallen drums on the forecourt (offset, radius, length, turn deg): cover.
	"drums":[[Vector2(-26.0,-12.0),1.7,5.4,20.0],[Vector2(-20.0,14.0),1.5,4.2,-35.0],[Vector2(30.0,-4.0),1.9,3.2,70.0]],
	# Alone (the yard): far pillars in the haze [x, z, crown (courses), apothem].
	"far":[[-290.0,-250.0,20,30.0],[250.0,-360.0,30,26.0],[350.0,-70.0,10,34.0],[-370.0,50.0,2,38.0],[70.0,-560.0,42,32.0],[-190.0,-510.0,34,28.0]],
	# Small fires lit since forever (draw no Olmec): on M's crown corners
	# (hex corner f, between faces f and f+1) and on the causeway's parapets
	# over its piers.
	"lamps":{"well_corners":[5,0,2,3],"causeway":true},
}

## Where the pillars stand (x z centres, crowns y), solved from LAYOUT:
## F due south of M (a seam of GAP: the stair spans it); U and T each set
## to one of M's faces (`on_face`) a `seam` off, their lowest collar level
## with M's crown, so a step crosses from M's ring onto it.
static func place_of(key: String) -> Vector3:
	var a_m := float(LAYOUT.well.apothem)
	match key:
		"well": return Vector3(0.0,float(LAYOUT.well.crown)*COURSE,0.0)
		"forecourt": return Vector3(0.0,float(LAYOUT.forecourt.crown)*COURSE,a_m+CityKit.GAP+float(LAYOUT.forecourt.apothem))
		"west","east":
			var p: Dictionary = LAYOUT[key]
			var r := float(p.apothem)+int(p.courses)*CityKit.LEDGE
			var c := CityKit.hex_dir(int(p.on_face))*(a_m+float(LAYOUT.seam)+r)
			return Vector3(c.x,float(p.crown)*COURSE,c.z)
		"needle":
			var n: Dictionary = LAYOUT.needle
			return Vector3(n.at.x,float(n.crown)*COURSE,n.at.y)
	return Vector3.ZERO

## A point `off` (x, z) from pillar `key`'s centre, `up` courses over its crown.
static func on(key: String, off: Vector2, up := 0.0) -> Vector3:
	var p := place_of(key)
	return Vector3(p.x+off.x,p.y+up*COURSE,p.z+off.y)

## The stair's foot (its summit edge on M's south face).
static func stair_foot() -> Vector3:
	return Vector3(0.0,place_of("forecourt").y,float(LAYOUT.well.apothem)+stair_length())

static func stair_length() -> float:
	return CityKit.STAIR_FLIGHTS*CityKit.STAIR_STEPS*CityKit.TREAD+CityKit.STAIR_FLIGHTS*CityKit.LANDING

## The causeway's ends (x): centred on M, U's end to T's.
static func causeway_ends() -> Vector2:
	var half := int(LAYOUT.causeway.spans)*CityKit.SPAN*0.5
	return Vector2(-half,half)

## F's beacon tower: its foot's middle, its giant steps on its local +z
## (south, toward the arrival), its back a seam off M's south face.
static func forecourt_tower() -> Transform3D:
	var base := float(LAYOUT.towers.forecourt.base)*CityFires.size()
	var at: Vector2 = LAYOUT.towers.forecourt.at
	var z := float(LAYOUT.well.apothem)+CityKit.GAP+0.3+base*0.5
	return Transform3D(Basis.IDENTITY,Vector3(at.x,place_of("forecourt").y,z))

## F's turf (local x, z from F's centre): flat by the stair, the tower and
## the ways; west of each terrace edge a set-off up, the edges wandering.
static func forecourt_ground(x: float, z: float) -> float:
	var y := 0.0
	var k := 0
	for edge: float in LAYOUT.forecourt.terraces:
		var wander := 2.2*sin(z*0.11+k*1.7)+1.3*sin(z*0.29+0.6+k)
		if x < edge+wander: y += CityKit.SET_OFF
		k += 1
	return y

## A turfed crown's ground (local): flat, but a hair under the causeway's
## deck where its end rests on the crown (so the turf never shows through).
static func crown_ground(key: String, x: float, z: float) -> float:
	if not key in ["west","east"]: return 0.0
	var p := place_of(key)
	var wx := p.x+x
	var wz := p.z+z
	var end := causeway_ends().y
	var under := absf(wz-float(LAYOUT.causeway.line)) < CityKit.DECK*0.5+0.6 and absf(wx) < end+0.6
	return -0.18 if under else 0.0

## A crown cap's outline (local x, z): the hex of `apothem`, each face
## grown out a ragged `grow` m (the `keep` faces tucked 1.4 inside, as
## CityKit `crown_outline`).
static func cap_outline(apothem: float, cap: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cap.seed)
	var grow := float(cap.grow)
	var keep: Array = cap.keep
	var r := apothem/cos(PI/6.0)
	var out: Array = []
	for f in 6:
		var n := CityKit.hex_dir(f)
		var a0 := TAU*(f-1)/6.0+PI/6.0
		var a1 := TAU*f/6.0+PI/6.0
		var c0 := Vector2(sin(a0),cos(a0))*r
		var c1 := Vector2(sin(a1),cos(a1))*r
		var kept := f in keep
		var kept_prev := ((f+5)%6) in keep
		for i in 6:
			var t := i/6.0
			var off := -1.4 if kept else grow*(0.35+0.65*rng.randf())
			if i == 0:
				# The corner: tucked if either face is, else out along both.
				off = -1.4 if (kept or kept_prev) else grow*0.6
				var bis := Vector2(sin(a0),cos(a0))
				out.append(c0+bis*off/cos(PI/6.0))
				continue
			out.append(c0.lerp(c1,t)+Vector2(n.x,n.z)*off)
	return out

# --- The motif's face -------------------------------------------------------------------

func slug() -> String:
	return "stacked_court"

func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Stacked Court"

func epithet() -> String:
	return "Every crown was lit for someone climbing. Someone still keeps the well."

func brief() -> String:
	return "Up: the serpent stair, round the well, the west pillar's collars and the causeway; or the beacon tower, round the well, the east pillar's collars.\nThe Keeper walks the well's far ring; a head holds the summit. Light a fire and they come to it."

func start() -> Vector3:
	return on("forecourt",Vector2(6.0,float(LAYOUT.forecourt.apothem)-6.0))

## In on F's south edge; out on T's far (north-east) edge.
func rims() -> Array:
	var n := CityKit.hex_dir(int(LAYOUT.east.on_face))
	var out := on("east",Vector2(n.x,n.z)*(float(LAYOUT.east.apothem)-1.4))
	return [
		{"name":"forecourt","at":on("forecourt",Vector2(6.0,float(LAYOUT.forecourt.apothem)-1.5)),"face":Vector3(0.0,0.0,1.0),"run_up":14.0,"lip":1.0},
		{"name":"summit","at":out,"face":n,"run_up":10.0,"lip":1.0},
	]

func spots() -> Array:
	var s: Vector2 = LAYOUT.towers.summit.at
	return [
		{"kind":"arena","name":"forecourt","at":on("forecourt",Vector2(-12.0,8.0)),"room":12.0},
		{"kind":"arena","name":"keepers_ring","at":on("well",Vector2(0.0,-33.0)),"room":4.0},
		{"kind":"cover","name":"under_the_causeway","at":on("well",Vector2(-6.0,float(LAYOUT.causeway.line)+3.0)),"room":3.0},
		{"kind":"perch","name":"summit_tower","at":on("east",s,3.0),"room":1.5},
		{"kind":"perch","name":"west_crown","at":on("west",Vector2(-6.0,4.0)),"room":3.0},
	]

## The solids for the occupancy, the footprint and the bodies' cliffs (the
## generator reads these, never the build): each pillar's crown and collar
## rings as hexes in axis strips (inside the real faces, so a cliff found
## on them fits the real face), M's crown round its well and the drum's
## turns in it, the stair as a ramp, the causeway's deck, the towers.
func parts() -> Array:
	var out: Array = []
	var floor_y := float(LAYOUT.floor)
	for key: String in ["forecourt","well","west","east","needle"]:
		var p := place_of(key)
		var d: Dictionary = LAYOUT[key]
		var courses := int(d.get("courses",0))
		var well := CityKit.DRUM_RADIUS if key == "well" else 0.0
		for k in range(courses,-1,-1):
			_hex_strips(out,Vector2(p.x,p.z),float(d.apothem)+k*CityKit.LEDGE,floor_y,p.y-k*COURSE,well if k == 0 else 0.0)
		if well > 0.0:
			_hex_strips(out,Vector2(p.x,p.z),well*cos(PI/6.0),floor_y,p.y-COURSE,0.0)
	var foot := stair_foot()
	out.append(["ramp",foot+Vector3(0.0,0.0,CityKit.HEAD_LENGTH),foot+Vector3(0.0,CityKit.STAIR_FLIGHTS*COURSE,-stair_length()),CityKit.LANE+2.0*(CityKit.CHEEK+CityKit.FLANK),"grey"])
	var ends := causeway_ends()
	var line := float(LAYOUT.causeway.line)
	var deck := place_of("east").y
	out.append(["box",Rect2(ends.x,line-CityKit.DECK*0.5,ends.y-ends.x,CityKit.DECK),deck-CityKit.DECK_THICK,deck,"grey"])
	# (The beacon towers stand on these crowns; left out, so the bodies'
	# cliffs are the crowns' and collars' edges, not a tower's shelf.)
	return out

## A hex of apothem `a` round `c` (faces to +-z) as axis boxes in bands of
## RuinKit.BAY along z, each its band's narrowest (inside the faces); a
## round hole of radius `hole` cut from the middle.
static func _hex_strips(out: Array, c: Vector2, a: float, bottom: float, top: float, hole: float) -> void:
	var band := CityKit.CELL
	var z := -a
	while z < a-0.01:
		var z1 := minf(z+band,a)
		var zm := maxf(absf(z),absf(z1))
		var hw := (a-0.5*zm)/cos(PI/6.0)
		var zn := minf(absf(z),absf(z1)) if z*z1 > 0.0 else 0.0
		if hole > 0.0 and zn < hole:
			var hx := sqrt(hole*hole-zn*zn)
			if hw > hx:
				out.append(["box",Rect2(c.x-hw,c.y+z,hw-hx,z1-z),bottom,top,"grey"])
				out.append(["box",Rect2(c.x+hx,c.y+z,hw-hx,z1-z),bottom,top,"grey"])
		elif hw > 0.0:
			out.append(["box",Rect2(c.x-hw,c.y+z,hw*2.0,z1-z),bottom,top,"grey"])
		z = z1

func heads() -> Array:
	var h: Dictionary = LAYOUT.head
	var at := on("east",h.at)
	return [{"name":"summit","at":at,"face":h.face,"knobs":{"route":[Vector3(at.x,0.0,at.z)]}}]

# --- The land and the stone ------------------------------------------------------------

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top(),KitLand.wear_of(paths()))

func flora_seed() -> int:
	return SEED+9

## The worn ways on F (the motif's frame): the arrival to the stair's foot,
## and to the tower's steps.
static func paths() -> Array:
	var s := on("forecourt",Vector2(6.0,float(LAYOUT.forecourt.apothem)-6.0))
	var foot := stair_foot()
	var tw := forecourt_tower().origin
	return [[Vector2(s.x,s.z),Vector2(foot.x,foot.z+6.0)],[Vector2(s.x,s.z),Vector2(tw.x,tw.z+12.0),Vector2(tw.x,tw.z+5.0)]]

## Butterflies and the wind's bits under the sky; none in the abyss.
func life_script() -> Script:
	return null if Underground.on() else KitLife

func warm() -> void:
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	CityStone.warm()
	for k: String in CityStone.WEAR: CityStone.wear(k)
	GiantStone.warm()
	_computed()

## Measured headless on the Mac (the build alone, `built_ms`: 483 ms).
func build_cost() -> int:
	return 500

## The pieces, by name, once built (for `live`'s dresser and checks).
var pieces := {}

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "StackedCourt"
	into.add_child(root)
	pieces.clear()
	var floor_y := float(LAYOUT.floor)
	# F: a bare crown, the KitLand turf on it (its west terraces).
	var fd: Dictionary = LAYOUT.forecourt
	var fp := place_of("forecourt")
	var f := CityKit.pillar(SEED+2,float(fd.wear),{"apothem":fd.apothem,"courses":0,"climb":-1,"crown":"bare","depth":fp.y-floor_y})
	f.name = "Forecourt"
	f.position = fp
	root.add_child(f)
	pieces.forecourt = f
	var a_f := float(fd.apothem)
	_turf_cap(root,"forecourt",{"ground":func(x: float, z: float) -> float: return forecourt_ground(x,z),"cliffs":Rect2(-a_f*1.2,-a_f*1.2,a_f*1.2,a_f*2.4),
		"tone":KitLook.turf(int(fd.cap.seed),KitLand.wear_of(_local(paths(),fp)))})
	# M: the well and its drum stair.
	var md: Dictionary = LAYOUT.well
	var mp := place_of("well")
	var m := CityKit.pillar(SEED+3,float(md.wear),{"apothem":md.apothem,"courses":0,"climb":-1,"crown":"flat","well":CityKit.DRUM_RADIUS,"depth":mp.y-floor_y})
	m.name = "Well"
	m.position = mp
	root.add_child(m)
	pieces.well = m
	var drum := CityKit.drum_stair(SEED+4,float(md.wear),{"rim":false})
	drum.name = "Drum"
	drum.position = mp
	root.add_child(drum)
	pieces.drum = drum
	# U and T on M's faces; the needle behind.
	var k := 0
	for key: String in ["west","east","needle"]:
		var d: Dictionary = LAYOUT[key]
		var p := place_of(key)
		var n := CityKit.pillar(SEED+5+k,float(d.wear),{"apothem":d.apothem,"courses":d.courses,"climb":int(d.get("climb",-1)),"crown":"bare","depth":p.y-floor_y})
		n.name = key.capitalize()
		n.position = p
		root.add_child(n)
		pieces[key] = n
		var g_key := key
		_turf_cap(root,key,{"ground":func(x: float, z: float) -> float: return crown_ground(g_key,x,z)})
		k += 1
	# The serpent stair from F to M's south face.
	var sd: Dictionary = LAYOUT.stair
	var stair := CityKit.stair(SEED+8,float(sd.wear),{"fault":int(sd.fault)})
	stair.name = "SerpentStair"
	stair.position = stair_foot()
	root.add_child(stair)
	pieces.stair = stair
	# The causeway from U's crown to T's: its local -z turned to +x, its
	# middle piers stopped a GAP over M's ring (CityKit's rule).
	var cd: Dictionary = LAYOUT.causeway
	var ends := causeway_ends()
	var deck_y := place_of("east").y
	var cw := CityKit.causeway(SEED+9,float(cd.wear),{"spans":int(cd.spans),"bay":int(cd.bay),"drop":deck_y-mp.y-CityKit.GAP})
	cw.name = "Causeway"
	cw.transform = Transform3D(Basis(Vector3.UP,-PI/2.0),Vector3(ends.x,deck_y,float(cd.line)))
	root.add_child(cw)
	pieces.causeway = cw
	_drums(root)
	root.set_meta("triangles",_triangles())
	built_ms = Time.get_ticks_msec()-began

## A turf cap on pillar `key`'s bare crown (KitLand, CityKit `crown_outline`'s
## way, its edge ragged past the stone: `cap_outline`), registered as turf.
## `spec` adds to the island's (ground, cliffs, tone).
func _turf_cap(root: Node3D, key: String, spec: Dictionary) -> void:
	var d: Dictionary = LAYOUT[key]
	var cap: Dictionary = d.cap
	var island := {"outline":cap_outline(float(d.apothem),cap),"seed":int(cap.seed),"ground":func(_x: float, _z: float) -> float: return 0.0,
		"top":0.0,"depth":CityKit.COURSE*0.6,"hang":true,"resample":[60.0,120,48],"tone":KitLook.turf(int(cap.seed)),"cell":2.5}
	island.merge(spec,true)
	var land := KitLand.island(island)
	land.name = "Turf_"+key
	land.position = place_of(key)
	root.add_child(land)
	turf(land)

## Where F's ground is at an offset from its centre (on its terraces).
static func on_forecourt(off: Vector2) -> Vector3:
	return on("forecourt",off)+Vector3.UP*forecourt_ground(off.x,off.y)

## Fallen column drums on the forecourt (cover; the makers' stone).
func _drums(root: Node3D) -> void:
	var g: RefCounted = GiantStone.mesher()
	var solids := StaticBody3D.new()
	solids.name = "Drums"
	for d: Array in LAYOUT.drums:
		var r := float(d[1])
		var length := float(d[2])
		var at := on_forecourt(d[0])
		var turn := Basis(Vector3.UP,deg_to_rad(float(d[3])))*Basis(Vector3.FORWARD,PI/2.0)
		var xf := Transform3D(turn,at+Vector3.UP*(r-0.25))
		g.cylinder(xf,r,length,12,0.2,at.y-0.3,0.9)
		var c := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = length
		c.shape = shape
		c.transform = xf
		solids.add_child(c)
	var mesh := MeshInstance3D.new()
	mesh.name = "DrumsMesh"
	mesh.mesh = GiantStone.mesh_of(g)
	root.add_child(mesh)
	root.add_child(solids)

static func _local(lines: Array, at: Vector3) -> Array:
	var out: Array = []
	for line: Array in lines:
		var l: Array = []
		for q: Vector2 in line: l.append(q-Vector2(at.x,at.z))
		out.append(l)
	return out

func _triangles() -> int:
	var n := 0
	for p: Node3D in pieces.values(): n += int(p.get_meta("triangles",0))
	return n

# --- What moves --------------------------------------------------------------------------

## The fires, the breakables hub, the Keeper and his beat, the yard's far
## pillars, and (in the abyss) the grass on the stone tops once they stand.
func live(g: Node) -> void:
	var fires := Node3D.new()
	fires.name = "Fires"
	g.add_child(fires)
	var tw: Dictionary = LAYOUT.towers
	var ft := forecourt_tower()
	ft.origin = g.w(ft.origin)
	CityFires.tower(fires,ft,{"seed":SEED+20,"name":"ForecourtTower","lit":bool(tw.forecourt.lit),"base":float(tw.forecourt.base)})
	var summit: Node3D = CityFires.tower(fires,Transform3D(Basis(Vector3.UP,-PI/2.0),g.w(on("east",tw.summit.at))),{"seed":SEED+21,"name":"SummitTower","lit":bool(tw.summit.lit)})
	_still(summit)
	var needle: Node3D = CityFires.tower(fires,Transform3D(Basis(Vector3.UP,0.4),g.w(place_of("needle"))),{"seed":SEED+22,"name":"NeedleTower","lit":bool(tw.needle.lit),"steps":false,"base":9.0,"beam":3.0})
	_still(needle)
	var k := 0
	for c: Array in LAYOUT.cressets:
		var lit := bool(c[4])
		var at := on_forecourt(c[1]) if str(c[0]) == "forecourt" else on(str(c[0]),c[1],float(c[2]))
		CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),{"size":c[3],"seed":SEED+30+k,"name":"Cresset%d_%s" % [k,str(c[0])],"lit":lit,"draw":1.0 if lit else 0.0})
		k += 1
	for at: Vector3 in lamp_points():
		CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),{"size":"crown","seed":SEED+40+k,"name":"Lamp%d" % k,"lit":true,"draw":1.0,"barge":false})
		k += 1
	# The hub: every Olmec's breaker (the bay, the fault, the cressets).
	var hub: Node3D = Breakables.new()
	hub.field = g.stage.enemies
	g.add_child(hub)
	# The Keeper: a whole Olmec on M's north ring, chase on, his routes.
	var kd: Dictionary = LAYOUT.keeper
	var beat: Array[Vector3] = []
	for p: Vector2 in kd.beat: beat.append(g.w(on("well",p)))
	var post: Vector3 = beat[1]
	var body: Node3D = g.enemy(HeadlessBody,post+Vector3.UP*0.1,kd.face,{"chase":1,"chase_routes":1,"seed":SEED})
	var head: Node3D = g.enemy(InhalerHead,post+Vector3.UP*0.1,kd.face,{})
	var keeper := Keeper.new()
	keeper.name = "Keeper_STANDIN"
	keeper.beat = beat
	keeper.post = post
	keeper.field = g.stage.enemies
	keeper.hub = hub
	keeper.wear(body,head)
	g.add_child(keeper)
	if str(g.stage.study.get_script().resource_path).ends_with("motif_yard.gd"): _far(g)
	if Underground.on():
		var dresser := Dresser.new()
		dresser.name = "Dresser"
		dresser.motif = self
		g.add_child(dresser)

## The small lit lamps (the motif's frame): M's crown corners (the kit's
## own cresset mounts, CityKit `pillar`) and the causeway's parapets over
## its middle piers (CityKit `causeway`'s mounts, turned as it stands).
static func lamp_points() -> Array:
	var out: Array = []
	var m := place_of("well")
	var a := float(LAYOUT.well.apothem)
	for f: int in LAYOUT.lamps.well_corners:
		var corner := (CityKit.hex_dir(f)+CityKit.hex_dir(f+1)).normalized()*(a-3.0)/cos(PI/6.0)
		out.append(m+corner)
	if bool(LAYOUT.lamps.causeway):
		var ends := causeway_ends()
		var xf := Transform3D(Basis(Vector3.UP,-PI/2.0),Vector3(ends.x,place_of("east").y,float(LAYOUT.causeway.line)))
		for s in range(1,int(LAYOUT.causeway.spans)):
			for side: float in [-1.0,1.0]:
				out.append(xf*Vector3(side*(CityKit.DECK*0.5-CityKit.PARAPET.x*0.5),CityKit.PARAPET.y,-s*CityKit.SPAN))
	return out

## A tower's crown (or a cresset) lit since the city emptied: its beacon
## draws no Olmec here (`draw` 1, as the fires yard's far towers).
static func _still(fire: Node) -> void:
	var c: Object = fire.get("crown")
	if c == null: c = fire
	var b: Object = c.get("beacon")
	if b != null: b.set("draw",1.0)

## Alone in the yard: far pillars in the haze, their crowns lit (drawn
## only; the layers in the distance a layer's own isles are).
func _far(g: Node) -> void:
	var far := Node3D.new()
	far.name = "FarLayers"
	g.add_child(far)
	var k := 0
	for f: Array in LAYOUT.far:
		var crown := float(f[2])*COURSE
		var at: Vector3 = g.w(Vector3(float(f[0]),crown,float(f[1])))
		var p := CityKit.pillar(SEED+60+k,0.7,{"apothem":float(f[3]),"courses":2,"climb":-1,"crown":"paved","depth":crown-float(LAYOUT.floor)-40.0})
		p.position = at
		for n: Node in p.find_children("*","CollisionObject3D",true,false): (n as CollisionObject3D).collision_layer = 0
		far.add_child(p)
		var t: Node3D = CityFires.tower(far,Transform3D(Basis(Vector3.UP,k*1.3),at+Vector3(float(f[3])*0.3,2.0*CityKit.SET_OFF,0.0)),{"tiers":2,"base":9.0,"steps":false,"lit":true,"seed":SEED+70+k,"name":"FarTower%d" % k,"beam":3.0})
		_still(t)
		k += 1

## STAND-IN: the Keeper's rounds. A whole Olmec unaware roams any way; this
## turns him, while he listens or roams and isn't hunting, toward the next
## point of his beat on M's north ring, back and forth (gb_rootbound_cut's
## Patrol). It holds him at his post till the stone under him stands (a
## rendered yard builds the art on a worker after the stage), puts his head
## back after the yard's reset, and hands every Olmec the breakables hub.
class Keeper extends Node:
	var beat: Array[Vector3] = []
	var post := Vector3.ZERO
	var field: Node = null
	var hub: Node3D = null
	var body: Node3D = null
	var head: Node3D = null
	var leg := 1
	var dir := 1
	var landed := false
	## Counted, for checks.
	var turns := 0
	var steered := 0

	func wear(b: Node3D, h: Node3D) -> void:
		body = b
		head = h
		if body != null and head != null: body.make_whole(head)

	func _physics_process(_delta: float) -> void:
		if field != null:
			for e in field.enemies:
				if is_instance_valid(e) and e.has_method("world_changed") and e.get("breaker") == null: e.breaker = hub
		if body == null or not is_instance_valid(body) or head == null or not is_instance_valid(head):
			_refind()
			return
		if not landed:
			var stone: StaticBody3D = body.body
			landed = field.floor_under(post,2.0,6.0,stone.get_rid() if stone != null else RID()) > -INF
			if not landed:
				body.position = post
				body.vel = Vector3.ZERO
				return
		if not body.whole or body.hunting: return
		if not (str(body.state) in ["listen","roam"]): return
		var to: Vector3 = beat[leg]
		var flat := Vector2(to.x-body.position.x,to.z-body.position.z)
		if flat.length() < 3.0:
			if leg+dir < 0 or leg+dir >= beat.size(): dir = -dir
			leg += dir
			turns += 1
			to = beat[leg]
			flat = Vector2(to.x-body.position.x,to.z-body.position.z)
		body._heading = PilotMotor.facing_of(flat.normalized())
		steered += 1

	func _refind() -> void:
		if field == null: return
		body = null
		head = null
		for e: Node3D in field.enemies:
			if not is_instance_valid(e): continue
			if e.has_method("make_whole") and e.position.distance_to(post) < 6.0: body = e
			elif e.has_method("mouth") and e.position.distance_to(post) < 12.0: head = e
		if body != null and head != null:
			body.make_whole(head)
			landed = false
			leg = 1
			dir = 1

## The abyss's ground cover (GroundCover `asked`: grass unless --ground=
## says) on the stone's walked tops once they stand: M's crown ring, U's,
## T's and the needle's crowns and collars, the stair's landings, summit and
## flank tiers, the causeway's deck (not the bay or the fault: a cover would
## hang where they were; nor the drum's turns: its coil reads as bare stone).
class Dresser extends Node:
	const ON := ["crown","landing","summit","deck","tier","collar"]
	var motif: RefCounted
	var laid := 0

	func _physics_process(_delta: float) -> void:
		var art: Node3D = motif.get("art")
		if art == null or not art.is_inside_tree(): return
		var pieces: Dictionary = motif.get("pieces")
		if pieces.is_empty(): return
		var kind := GroundCover.asked()
		if kind == "":
			set_physics_process(false)
			return
		for key: String in pieces:
			var p: Node3D = pieces[key]
			if not is_instance_valid(p) or not p.is_inside_tree(): return
		var k := 0
		for key: String in pieces:
			if key in ["forecourt","drum"]: continue
			var p: Node3D = pieces[key]
			for a: Dictionary in p.get_meta("walk_areas",[]):
				if not String(a.kind) in ON: continue
				var opts := {"tufts":0.5,"under":0.3} if String(a.kind) == "collar" else {}
				if GroundCover.cover(p,a.poly,kind,float(a.y),SEED+k,opts) != null: laid += 1
				k += 1
		print("stacked court: ground %s on %d tops" % [kind,laid])
		set_physics_process(false)
