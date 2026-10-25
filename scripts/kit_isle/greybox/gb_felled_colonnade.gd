extends "res://scripts/kit_isle/motif_greybox.gd"
## The Felled Colonnade, a place of the underground Olmec
## city: two isles split down a fault too wide to jump, and on the near
## one the last standing drum column at the brink. Lure the Olmec into it
## and the side he hits decides how it falls: east, a bridge across; west,
## a wall-walk up to the gallery.
##
##   the near isle (west, the arrival)  the forecourt (0), the colonnade
##       terrace (4.8) with the column at its east rim and the stubs of its
##       fallen row behind, the gallery (12) along the north, its bastion
##       beside the column's fall line. The drum floor in the forecourt.
##   the far isle (east)  shelf A (4.8) straight across from the column,
##       shut by the plug-stone's gate wall; the gate ramp up to the upper
##       walk (12); the epic stair up to the crown (26.4: the beacon, a
##       head, the rim out). The east terraces (0 to 12) south of the upper
##       walk, and the pier (0) cut off from them by the mouse run's wall.
##   between them  the causeway (forecourt to pier), the chocked slab
##       (gallery to upper walk), and, once felled east, the column.
##
## Routes (rim in on the forecourt's south edge, rim out on the crown's
## north-east edge):
##   the bridge  east steps onto the terrace by the gap, lure him into the
##               column from the west (peek out, then hide behind it):
##               it falls east onto shelf A; over, lure him into the plug,
##               through the gate, up the ramp, the upper walk, the stair.
##   the ramp    felled west, the drums lie along the terrace beside the
##               bastion: plinth, stub, spall, the crown of the drums, up
##               onto the gallery; north to the chocked slab, slam its
##               plate, cross onto the upper walk, the stair.
##   the long way  the causeway to the pier, the mouse run (he can't
##               follow), the east terraces' seven set-offs, the upper
##               walk, the stair.
##
## Threat: the Feller, a whole Olmec on the terrace (chase and chase routes
## on; a STAND-IN beat west of the column); the column's fall and its
## rolling drums; the chocked slab's landing; the drum floor under his
## landing; an inhaler head on the crown over the stair, its body coming up
## the cliffs. The breakables hub is every Olmec's breaker.
##
## Everything is one LAYOUT table; the land is two height functions over it.
const OlmecPlaces = preload("res://scripts/enemies/olmec_places.gd")
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const CityBreaks = preload("res://scripts/city_kit_breaks.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Breakables = preload("res://scripts/breaks/breakables.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const Underground = preload("res://scripts/underground/underground.gd")

const SEED := 7700
const SO := CityKit.SET_OFF
const COURSE := CityKit.COURSE
## The heights (m): the terrace and shelf A a course up, the gallery and
## the upper walk 1.2 m over the felled drums' crown (5.58 m over the
## terrace: a hop and a grab from the drums' shoulder), the crown the
## stair's three courses over the upper walk.
const TERRACE := COURSE
const GALLERY := 11.6
const CROWN := GALLERY+CityKit.STAIR_FLIGHTS*COURSE
## The keel's depth under each isle's top (m).
const KEEL := 40.0

# --- The layout: one table ----------------------------------------------------------------
## The frame: the arrival on the near isle's south edge looking north (-z);
## the fault runs north-south between x 0.3 (the near rim) and x 13 (the
## far). Points are (x, z).
const LAYOUT := {
	# The near isle's outline (its east edge the fault's west rim).
	"near":[Vector2(-62,50),Vector2(-40,55),Vector2(-18,54),Vector2(-3,48),Vector2(-1,44),Vector2(-1,35),Vector2(-4,30),
		Vector2(-3,22),Vector2(-1,16),Vector2(0.3,13),Vector2(1.0,9),Vector2(1.9,5),Vector2(1.9,-7),Vector2(0.6,-11),Vector2(-0.4,-20),Vector2(0.0,-30),Vector2(-0.8,-40),
		Vector2(0.0,-44),Vector2(0.0,-58),Vector2(-6,-64),Vector2(-24,-67),Vector2(-46,-61),Vector2(-62,-47),Vector2(-70,-26),
		Vector2(-66,-6),Vector2(-72,12),Vector2(-70,34)],
	# The far isle's: shelf A's west rim (x 13), the upper walk, the crown,
	# the east terraces, the pier (the mouse run's neck x 102-128), back up
	# the cleft between the terraces and shelf A.
	"far":[Vector2(20,18.5),Vector2(13.0,10),Vector2(13.0,-10),Vector2(12.8,-20),Vector2(13.2,-30),Vector2(13.6,-40),
		Vector2(13.2,-44),Vector2(13.2,-58),Vector2(16,-66),Vector2(19,-84),Vector2(17,-100),Vector2(21,-122),Vector2(32,-140),
		Vector2(56,-146),Vector2(72,-136),Vector2(78,-114),Vector2(96,-104),Vector2(122,-96),Vector2(134,-70),Vector2(132,-40),
		Vector2(137,-16),Vector2(134,4),Vector2(130,12),Vector2(128.4,16.5),Vector2(128.4,27.5),Vector2(135,32),Vector2(139,46),
		Vector2(132,62),Vector2(114,67),Vector2(102,60),Vector2(100.5,48),Vector2(100.5,34),Vector2(96,30),Vector2(102.4,27.5),
		Vector2(102.4,16.5),Vector2(90,8),Vector2(70,4),Vector2(50,-2),Vector2(48,-17.5),Vector2(38,-17.5),Vector2(38,4),Vector2(34,14),Vector2(27,18.5)],
	# The near isle's ground: the terrace's south cliff (z), its east and west
	# steps (x ranges), the gallery's face (z) by x band, the drum floor's pit.
	"terrace_edge":8.0,
	"terrace_apron":Vector2(-15.0,13.0),
	"east_steps":Vector2(-8.0,-1.5),
	"west_steps":Vector2(-58.0,-46.0),
	"gallery_face":[[-11.0,-8.0],[-21.0,-4.8],[-24.0,-11.0]],
	# The column (its middle, x z; falls along x), the bed-stones on the far
	# rim cut for its end.
	"column":Vector2(-6.0,-2.0),
	"beds":[[Vector2(14.4,-6.2),Vector3(2.4,1.1,1.6)],[Vector2(14.4,2.2),Vector3(2.4,1.1,1.6)]],
	# The drum floor (its middle, 5 x 5 slabs), its north side the terrace's
	# cliff (he comes down onto it), and the launch stump beside it (its
	# middle, drums, its top under the launch's reach, over a jump's).
	"drum_floor":Vector2(-27.0,18.5),
	"stump":{"at":Vector2(-13.3,25.0),"drums":2,"base":0.6},
	# Fallen courses at the gate wall's foot (x z, size, turn deg, tilt deg).
	"wall_rubble":[[Vector2(14.8,-12.6),Vector3(2.2,1.1,1.6),20.0,6.0],[Vector2(17.0,-11.9),Vector3(1.4,0.8,1.2),-35.0,-10.0],
		[Vector2(14.0,-10.6),Vector3(1.0,0.6,0.9),50.0,12.0],[Vector2(35.4,-12.6),Vector3(2.6,1.2,1.8),-12.0,-5.0],
		[Vector2(37.0,-11.2),Vector3(1.6,0.9,1.3),30.0,9.0],[Vector2(33.8,-10.8),Vector3(1.1,0.6,1.0),70.0,0.0]],
	# The east steps' cover (x z, size over the ground there, turn deg): the
	# broken screen on the terrace's lip west of the steps (out of his
	# beat's sight), the lip along the void beside the steps and the apron.
	"step_cover":[[Vector2(-9.8,11.9),Vector3(2.6,3.6,1.2),6.0],[Vector2(-12.4,11.6),Vector3(2.4,2.6,1.1),-4.0],[Vector2(-14.3,11.5),Vector3(1.6,1.5,1.0),15.0],[Vector2(-11.4,14.6),Vector3(2.2,0.9,1.4),25.0],
		[Vector2(-2.1,14.5),Vector3(0.7,1.4,2.6),4.0],[Vector2(-2.7,17.6),Vector3(0.7,1.5,2.4),-6.0],
		[Vector2(-3.4,20.4),Vector3(0.7,1.3,2.8),-18.0],[Vector2(-4.0,23.3),Vector3(0.7,1.2,2.6),-7.0],
		[Vector2(0.0,9.6),Vector3(0.7,1.2,3.0),-8.0],[Vector2(0.7,6.4),Vector3(0.7,1.0,2.0),3.0]],
	# The chocked slab: its near rim's middle on the gallery's east edge.
	"chock":Vector2(0.0,-51.0),
	# The plug: its middle on shelf A's north (the wall along x).
	"plug":Vector2(25.5,-18.0),
	# The ridge the gate is sunk in: its rock face's place before the wall's
	# south face (m), the west shoulder (crest m, how far north it falls m),
	# the east rise (crest, how far north, x where it has fallen away).
	"gate_hill":{"front":0.8,"west":Vector2(29.0,16.0),"east":Vector3(29.4,20.0,54.0)},
	# The causeway: its west end (x) and line (z), its spans.
	"causeway":{"from":-3.0,"line":40.0,"spans":4,"wear":0.6},
	# The mouse run: its middle (x z), the wall along x.
	"mouserun":Vector2(115.4,22.0),
	# The epic stair: its foot (x z) on the upper walk, climbing north; by
	# the gate ramp's head and the slab's landing, far from the terraces.
	"stair":{"foot":Vector2(36.0,-50.0),"wear":0.55},
	# The beacon on the crown, lit (the exit's light, seen from the arrival).
	"beacon":{"at":Vector2(52.0,-128.0),"lit":true},
	# The Feller's beat on the terrace, west of the column, his first look.
	"feller":{"beat":[Vector2(-34.0,4.0),Vector2(-28.0,-1.0),Vector2(-33.0,-6.0)],"face":Vector2(1.0,0.0)},
	# The head on the crown, at the stair's head, looking down it.
	"head":{"at":Vector2(36.0,-111.0),"face":Vector2(0.0,1.0)},
	# The stubs of the fallen row on the terrace's line (x z, drums standing).
	"stubs":[[Vector2(-40.0,-2.0),2],[Vector2(-52.0,-1.0),1]],
	# Old fallen drums (x z, turn deg, on): cover and the row's story.
	"fallen":[[Vector2(-56.0,-6.0),70.0,"near"],[Vector2(-49.0,-9.0),55.0,"near"],[Vector2(-44.0,38.0),20.0,"near"],
		[Vector2(-37.0,42.0),-15.0,"near"],[Vector2(-58.0,22.0),80.0,"near"],
		[Vector2(80.0,-70.0),10.0,"far"],[Vector2(86.0,-62.0),-40.0,"far"],[Vector2(122.0,52.0),30.0,"far"]],
	# Alone (the yard): far pillars in the haze [x, z, crown (courses), apothem].
	"far_pillars":[[-300.0,-220.0,4,30.0],[260.0,-330.0,10,26.0],[360.0,-60.0,2,34.0],[-360.0,80.0,-2,38.0],[60.0,-520.0,16,32.0],[-200.0,-470.0,12,28.0]],
}

# --- The land --------------------------------------------------------------------------------

## The near isle's ground (x, z).
static func near_ground(x: float, z: float) -> float:
	var y := 0.0
	var edge := float(LAYOUT.terrace_edge)
	# By the column the terrace runs out further south (his room round the
	# plinth's south side); west of it the cliff wanders.
	var apron: Vector2 = LAYOUT.terrace_apron
	if x > apron.x: edge = apron.y
	elif x < apron.x-2.0: edge += 1.6*sin(x*0.17+0.4)+0.9*sin(x*0.41)
	else: edge = lerpf(edge+1.6*sin((apron.x-2.0)*0.17+0.4)+0.9*sin((apron.x-2.0)*0.41),apron.y,(x-apron.x+2.0)/2.0)
	var ws: Vector2 = LAYOUT.west_steps
	var es: Vector2 = LAYOUT.east_steps
	if z < edge: y = TERRACE
	elif x > ws.x and x < ws.y and z < edge+8.0: y = SO*(2.0 if z < edge+4.0 else 1.0)
	elif x > es.x and x < es.y and z < edge+6.0: y = SO*(2.0 if z < edge+3.0 else 1.0)
	if z < gallery_face(x): y = GALLERY
	# The drum floor's pit (its slabs' tops at 0 cover it).
	var d: Vector2 = LAYOUT.drum_floor
	var half := CityBreaks.SLAB*2.5-0.2
	if absf(x-d.x) < half and absf(z-d.y) < half: y = -2.4
	# A hair under the causeway's end and the chock's abutment.
	var cw: Dictionary = LAYOUT.causeway
	if x > float(cw.from)-2.0 and absf(z-float(cw.line)) < CityKit.DECK*0.5+0.6: y = -0.15
	var ch: Vector2 = LAYOUT.chock
	if x > ch.x-CityKit.CELL-0.3 and absf(z-ch.y) < chock_half()+0.3: y = GALLERY-0.15
	return y

## The gallery's south face (z) at x: back of the plinth by the rim, the
## bastion by the drums' rest (3 m off the line), back past the rollers.
static func gallery_face(x: float) -> float:
	var bands: Array = LAYOUT.gallery_face
	if x > float(bands[0][0]): return float(bands[0][1])
	if x > float(bands[1][0]): return float(bands[1][1])
	if x > float(bands[2][0]): return lerpf(float(bands[2][1]),float(bands[1][1]),(x-float(bands[2][0]))/(float(bands[1][0])-float(bands[2][0])))
	return float(bands[2][1])-2.5*(1.0+sin(x*0.09+1.0))

## The far isle's ground (x, z).
static func far_ground(x: float, z: float) -> float:
	var y := GALLERY
	if z > -17.5 and x < 40.0: y = TERRACE
	elif z > -17.5:
		# The east terraces: set-offs north from the pier's level, then an
		# easy rise onto the upper walk.
		var zz := z+1.2*sin(x*0.15)+0.6*sin(x*0.37+1.0)
		if zz >= 10.0: y = 0.0
		elif zz > -14.0: y = SO*minf(7.0,ceilf((10.0-zz)/4.0))
		else: y = lerpf(7.0*SO,GALLERY,clampf((-14.0-z)/3.5,0.0,1.0))
	elif x < 38.0 and z > -44.0:
		var t := clampf((-21.0-z)/20.0,0.0,1.0)
		y = TERRACE+(GALLERY-TERRACE)*t*t*(3.0-2.0*t)
	elif z < stair_summit_z(): y = CROWN
	y = maxf(y,gate_hill(x,z))
	var ch: Vector2 = LAYOUT.chock
	var far_rim := ch.x+gap_chock()
	if x < far_rim+CityKit.CELL+0.3 and absf(z-ch.y) < chock_half()+0.3: y = GALLERY-0.15
	var cw: Dictionary = LAYOUT.causeway
	if x < causeway_end()+2.0 and absf(z-float(cw.line)) < CityKit.DECK*0.5+0.6: y = -0.15
	return y

## The ridge the plug's gate wall is sunk in (polish round 1): rock
## shoulders stand in front of the wall's jambs, so from the shelf only the
## gate's own masonry frame shows, set back in a cliff; behind, the gate ramp
## runs up a cutting between two grassy slopes falling to the upper walk.
## The west shoulder a narrow one along the fault, the east a broad rise
## falling away over the cleft. The rock's face is the barrier the wall was:
## at least BARRIER over the shelf the whole width of the wall (past his
## climb); within FRAME of the lane the ground steps up inside the wall's
## stone (1 m behind its face); never in the lane (his way and the heap's).
## -INF where none.
const BARRIER := 23.6
const FRAME := 1.8
static func gate_hill(x: float, z: float) -> float:
	var pl: Vector2 = LAYOUT.plug
	var gh: Dictionary = LAYOUT.gate_hill
	var half := CityKit.LANE*0.5
	var wall_half := half+2.0*CityKit.CELL
	var face := pl.y+CityKit.CELL*0.5
	var off := absf(x-pl.x)
	var south := -17.5
	if off <= half+FRAME: south = face-1.0
	elif off <= wall_half: south = face+float(gh.front)
	if z > south: return -INF
	# The cutting: the lane, its sides wandering back as it climbs (never
	# into the lane).
	var back := maxf(0.0,(pl.y-CityKit.CELL*0.5)-z)
	var ragged := 0.4+0.12*back+0.5*(0.5+0.5*sin(z*0.45+x*0.1))
	if off < half+ragged: return -INF
	var crest: float
	var f: float
	var zz := z+1.6*sin(x*0.31+0.7)
	var top := face-2.0*CityKit.CELL
	if x < pl.x:
		var w: Vector2 = gh.west
		crest = w.x+0.6*sin(z*0.5+1.3)+0.5*sin(x*0.9)
		f = smoothstep(top-w.y,top,zz)
	else:
		var e: Vector3 = gh.east
		crest = e.x+0.8*sin(x*0.21+z*0.13)+0.5*sin(x*0.63+2.0)
		f = smoothstep(top-e.y,top,zz)*(1.0-smoothstep(pl.x+wall_half,e.z,x+2.0*sin(z*0.27)))
	var y := lerpf(GALLERY,crest,f) if f > 0.0 else -INF
	# The face over the shelf: past his climb along the wall's whole width.
	# Past the gate's frame its brow breaks up unevenly (a rough skyline, the
	# east shoulder the higher); in the frame it stays under the wall's head.
	if off <= wall_half and z > face-CityKit.CELL-1.0:
		var brow := 0.4*sin(x*0.7)
		if off > half+FRAME:
			var o := (off-half-FRAME)/(wall_half-half-FRAME)
			brow += sin(PI*minf(o*1.3,1.0))*(1.6+1.4*sin(x*0.55+z*0.4))+(1.4 if x > pl.x else 0.0)*o
		y = maxf(y,TERRACE+BARRIER+brow)
	return y

static func gap_chock() -> float:
	return load("res://scripts/city_breaks/chocked_slab.gd").gap()

## Half the chock's abutments' width (m, along the rim).
static func chock_half() -> float:
	return (load("res://scripts/city_breaks/chocked_slab.gd").SLAB.x+CityKit.CELL)*0.5

static func stair_length() -> float:
	return CityKit.STAIR_FLIGHTS*CityKit.STAIR_STEPS*CityKit.TREAD+CityKit.STAIR_FLIGHTS*CityKit.LANDING

static func stair_summit_z() -> float:
	return float(LAYOUT.stair.foot.y)-stair_length()

static func causeway_end() -> float:
	return float(LAYOUT.causeway.from)+int(LAYOUT.causeway.spans)*CityKit.SPAN

## A point on the near (or far) ground at (x, z), `up` m over it.
static func on_near(p: Vector2, up := 0.0) -> Vector3:
	return Vector3(p.x,near_ground(p.x,p.y)+up,p.y)

static func on_far(p: Vector2, up := 0.0) -> Vector3:
	return Vector3(p.x,far_ground(p.x,p.y)+up,p.y)

# --- The motif's face -------------------------------------------------------------------

func slug() -> String:
	return "felled_colonnade"

func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Felled Colonnade"

func epithet() -> String:
	return "They set their columns at the edge, so that one day someone would knock them over."

func brief() -> String:
	return "Lure the Olmec into the last column: hit from the west it bridges the gap; from the gap side it falls along the terrace, up to the gallery and the chocked slab.\nThe long way: the causeway and the mouse run. Over the gap, only he can break the plug."

func start() -> Vector3:
	return on_near(Vector2(-10.0,45.0))

## In on the forecourt's south edge; out on the crown's north-east edge.
func rims() -> Array:
	var n := Vector3(0.53,0.0,-0.85).normalized()
	return [
		{"name":"forecourt","at":on_near(Vector2(-10.0,49.8)),"face":Vector3(0.0,0.0,1.0),"run_up":14.0,"lip":1.0},
		{"name":"crown","at":on_far(Vector2(63.2,-139.7)),"face":n,"run_up":12.0,"lip":1.0},
	]

## The generator's spots, and the collectibles' for the next round: runes
## along the routes ("rune_line"), tempting exposed detours ("rune_risk"),
## and the rare finds ("rare": behind a break, top of a ride, a hard jump).
func spots() -> Array:
	var out: Array = [
		{"kind":"arena","name":"drum_floor","at":on_near(LAYOUT.drum_floor),"room":10.0},
		{"kind":"arena","name":"colonnade_terrace","at":on_near(Vector2(-26.0,2.0)),"room":7.0},
		{"kind":"cover","name":"stub_row","at":on_near(Vector2(-40.0,3.5)),"room":3.0},
		{"kind":"cover","name":"fallen_drums","at":on_near(Vector2(-37.0,38.0)),"room":3.0},
		{"kind":"perch","name":"launch_stump","at":stump_top(),"room":2.0},
		{"kind":"perch","name":"gallery_end","at":on_near(Vector2(-52.0,-50.0)),"room":4.0},
	]
	# Runes along the routes: the forecourt, the steps, the causeway (few: the
	# long way is poor), the east terraces, the upper walk, the stair.
	for p: Vector2 in [Vector2(-28.0,42.0),Vector2(-14.0,40.0),Vector2(-52.0,14.0),Vector2(-46.0,4.0),Vector2(-18.0,4.0),Vector2(-4.0,12.0)]:
		out.append({"kind":"rune_line","name":"near_%d_%d" % [int(p.x),int(p.y)],"at":on_near(p,0.6),"room":1.0})
	for p: Vector2 in [Vector2(36.0,40.0),Vector2(116.0,6.0),Vector2(90.0,-30.0),Vector2(28.0,-36.0),Vector2(36.0,-66.0),Vector2(36.0,-88.0)]:
		var on_deck := absf(p.y-float(LAYOUT.causeway.line)) < 1.0 and p.x < causeway_end()
		out.append({"kind":"rune_line","name":"far_%d_%d" % [int(p.x),int(p.y)],"at":Vector3(p.x,0.6,p.y) if on_deck else on_far(p,0.6),"room":1.0})
	# Tempting and exposed: between the column and the gap (where you stand
	# to lure him), shelf A's tip over the void, the chocked slab's far socket
	# (where it lands), the drum floor's middle (where he lands), the
	# gallery's bastion over the fall line.
	var c: Vector2 = LAYOUT.column
	var ch: Vector2 = LAYOUT.chock
	for r: Array in [["column_rim",on_near(Vector2(-0.9,c.y+4.0),0.6)],["shelf_tip",on_far(Vector2(24.0,15.0),0.6)],
			["slab_socket",on_far(Vector2(ch.x+gap_chock()+1.5,ch.y),0.6)],["drum_middle",on_near(LAYOUT.drum_floor,0.6)],
			["bastion_lip",on_near(Vector2(-16.0,-6.0),0.6)]]:
		out.append({"kind":"rune_risk","name":r[0],"at":r[1],"room":1.0})
	# The rare: on the launch stump (only the drum floor's launch reaches it),
	# on shelf A by the bed-stones (only over the felled bridge, or behind the
	# plug from the far side), the gallery's far end (only by the drums of a
	# west fall), and atop the crown's beacon (its giant steps, in the head's sight).
	out.append({"kind":"rare","name":"launch_stump","at":stump_top()+Vector3.UP*0.6,"room":1.0})
	out.append({"kind":"rare","name":"shelf_beds","at":on_far(Vector2(17.0,9.0),0.6),"room":1.0})
	out.append({"kind":"rare","name":"gallery_end","at":on_near(Vector2(-54.0,-52.0),0.6),"room":1.0})
	out.append({"kind":"rare","name":"beacon_top","at":on_far(LAYOUT.beacon.at,CityFires.size()*3.0),"room":1.0})
	return out

static func stump_top() -> Vector3:
	var s: Dictionary = LAYOUT.stump
	return on_near(s.at,float(s.base)+int(s.drums)*CityBreaks.DRUM_H)

## The solids for the occupancy, the footprint and the bodies' cliffs: the
## two isles' ground as strips (CELL m bands along z, runs of one height
## along x) down to their keels, and the big stone (the causeway's deck, the
## mouse run's wall, the plug's wall, the stair as a ramp, the chock's
## abutments, the column standing).
func parts() -> Array:
	var out: Array = []
	for which: String in ["near","far"]:
		var poly := PackedVector2Array(LAYOUT[which])
		var box := Rect2(poly[0],Vector2.ZERO)
		for p: Vector2 in poly: box = box.expand(p)
		var step := 4.0
		var z := box.position.y+step*0.5
		while z < box.end.y:
			var run_x := NAN
			var run_y := 0.0
			var x := box.position.x+step*0.5
			while x < box.end.x+step:
				var inside := x < box.end.x and Geometry2D.is_point_in_polygon(Vector2(x,z),poly)
				var y := (near_ground(x,z) if which == "near" else far_ground(x,z)) if inside else NAN
				if not is_nan(run_x) and (is_nan(y) or absf(y-run_y) > 0.01):
					out.append(["box",Rect2(run_x,z-step*0.5,x-step*0.5-run_x,step),run_y-KEEL*0.5,run_y,"grey"])
					run_x = NAN
				if is_nan(run_x) and not is_nan(y):
					run_x = x-step*0.5
					run_y = y
				x += step
			z += step
	var cw: Dictionary = LAYOUT.causeway
	out.append(["box",Rect2(float(cw.from),float(cw.line)-CityKit.DECK*0.5,causeway_end()-float(cw.from),CityKit.DECK),-CityKit.DECK_THICK,0.0,"grey"])
	var mr: Vector2 = LAYOUT.mouserun
	out.append(["box",Rect2(mr.x-15.3,mr.y-4.5,30.6,9.0),-KEEL*0.5,24.75,"grey"])
	var pl: Vector2 = LAYOUT.plug
	out.append(["box",Rect2(pl.x-13.2,pl.y-2.2,26.4,4.4),TERRACE,TERRACE+24.0,"grey"])
	var foot: Vector2 = LAYOUT.stair.foot
	out.append(["ramp",Vector3(foot.x,GALLERY,foot.y+CityKit.HEAD_LENGTH),Vector3(foot.x,CROWN,stair_summit_z()),CityKit.LANE+2.0*(CityKit.CHEEK+CityKit.FLANK),"grey"])
	var c: Vector2 = LAYOUT.column
	out.append(["cyl",c,CityBreaks.DRUM_R,TERRACE,TERRACE+CityBreaks.column_h(),"grey"])
	return out

func heads() -> Array:
	var h: Dictionary = LAYOUT.head
	var at := on_far(h.at)
	return [{"name":"crown","at":at,"face":h.face,"knobs":{"route":[Vector3(at.x,0.0,at.z)]}}]

# --- The land and the stone ------------------------------------------------------------

## The plants' rays run from over the crown down past the drum floor's pit:
## the Site's default stops 8 m under its top, which left every turf under
## 22 m (the forecourt, the terrace, the gallery, shelf A, the upper walk)
## bare olive with not one blade.
func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(CROWN+4.0,KitLand.wear_of(paths()))
	site.ray = Vector2(CROWN+60.0,-6.0)
	# The isles are big (about 30k m² of turf): a thinner drift than the
	# small kit isles' keeps the instanced grass near the Sundered Gorge's
	# per isle-in-view, the turf still green from the arrival.
	site.tufts = 2.8
	return site

func flora_seed() -> int:
	return SEED+9

## The worn ways: the arrival to the east steps and to the west steps, the
## forecourt to the causeway; on the far isle the terraces' line and the
## upper walk to the stair.
static func paths() -> Array:
	var s := Vector2(-10.0,45.0)
	return [[s,Vector2(-14.0,38.0),Vector2(-5.0,16.0)],[s,Vector2(-44.0,30.0),Vector2(-52.0,14.0),Vector2(-40.0,4.0),Vector2(-14.0,2.0)],
		[s,Vector2(-6.0,40.0)],[Vector2(117.0,14.0),Vector2(110.0,-14.0),Vector2(70.0,-36.0),Vector2(38.0,-44.0)],[Vector2(28.0,-40.0),Vector2(36.0,-44.0)],[Vector2(20.0,-51.0),Vector2(32.0,-48.0)]]

## Butterflies and the wind's bits under the sky; none in the abyss.
func life_script() -> Script:
	return null if Underground.on() else KitLife

func warm() -> void:
	warm_look()
	CityStone.warm()
	for k: String in CityStone.WEAR: CityStone.wear(k)
	GiantStone.warm()
	_computed()

func build_cost() -> int:
	return 900

## The pieces, by name, once built (for `live`'s dresser and checks).
var pieces := {}

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "FelledColonnade"
	into.add_child(root)
	pieces.clear()
	var wear := KitLand.wear_of(paths())
	var near := KitLand.island({"outline":LAYOUT.near,"seed":SEED+1,"ground":func(x: float, z: float) -> float: return near_ground(x,z),
		"top":GALLERY,"depth":KEEL,"hang":true,"cliffs":Rect2(-75.0,-70.0,78.0,128.0),"cell":2.5,"fine":2.0,"cliff_drop":1.0,
		"resample":[100.0,170,60],"tone":KitLook.turf(SEED+1,wear)})
	near.name = "NearIsle"
	root.add_child(near)
	turf(near)
	var far := KitLand.island({"outline":LAYOUT.far,"seed":SEED+2,"ground":func(x: float, z: float) -> float: return far_ground(x,z),
		"top":CROWN,"depth":KEEL+14.0,"hang":true,"cliffs":Rect2(10.0,-150.0,132.0,222.0),"cell":2.5,"fine":2.0,"cliff_drop":1.0,
		"resample":[100.0,260,60],"tone":KitLook.turf(SEED+2,wear)})
	far.name = "FarIsle"
	root.add_child(far)
	turf(far)
	# The epic stair from the upper walk to the crown.
	var sd: Dictionary = LAYOUT.stair
	var stair := CityKit.stair(SEED+8,float(sd.wear),{"fault":0})
	stair.name = "EpicStair"
	stair.position = Vector3(sd.foot.x,GALLERY,sd.foot.y)
	root.add_child(stair)
	pieces.stair = stair
	# The causeway, the forecourt to the pier (its local -z turned to +x).
	var cd: Dictionary = LAYOUT.causeway
	var cw := CityKit.causeway(SEED+9,float(cd.wear),{"spans":int(cd.spans),"bay":-1,"drop":30.0})
	cw.name = "Causeway"
	cw.transform = Transform3D(Basis(Vector3.UP,-PI/2.0),Vector3(float(cd.from),0.0,float(cd.line)))
	root.add_child(cw)
	pieces.causeway = cw
	# The mouse run's wall across the pier's neck.
	var mr: Vector2 = LAYOUT.mouserun
	var run := CityKit.stand("city_mouserun",root,Transform3D(Basis.IDENTITY,Vector3(mr.x,0.0,mr.y)),SEED+10)
	run.name = "MouseRun"
	_stone(root)
	root.set_meta("triangles",_triangles())
	built_ms = Time.get_ticks_msec()-began

## The dressing in the giant's stone: the stubs of the fallen row, the old
## fallen drums, the launch stump, the bed-stones cut for the column's end.
func _stone(root: Node3D) -> void:
	var g: RefCounted = GiantStone.mesher()
	var solids := StaticBody3D.new()
	solids.name = "Dressing"
	var r := CityBreaks.DRUM_R
	var h := CityBreaks.DRUM_H
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+50
	# Standing: the stubs, the launch stump (each on a low base, its top drum
	# broken a little off true).
	# The stubs' bases sunk to a hand's height in the turf (no plinth boxes);
	# the stump keeps its base (its top is the launch's reach).
	var stands: Array = []
	for s: Array in LAYOUT.stubs: stands.append([s[0],s[1],0.2,r*2.0+0.7])
	stands.append([LAYOUT.stump.at,int(LAYOUT.stump.drums),float(LAYOUT.stump.base),r*2.0+1.6])
	for s: Array in stands:
		var at := on_near(s[0])
		var base := float(s[2])
		var foot := float(s[3])
		g.box(Transform3D(Basis(Vector3.UP,rng.randf_range(-0.5,0.5)),at+Vector3.UP*(base*0.5-0.2)),Vector3(foot,base+0.4,foot),0.15,at.y-0.3,0.85)
		_collide_box(solids,Transform3D(Basis.IDENTITY,at+Vector3.UP*(base*0.5-0.2)),Vector3(foot,base+0.4,foot))
		for k in int(s[1]):
			var lean := Basis(Vector3(1.0,0.0,0.3).normalized(),0.025*k)*Basis(Vector3.UP,rng.randf_range(0.0,TAU))
			var xf := Transform3D(lean,at+Vector3.UP*(base+h*(k+0.5)))
			g.cylinder(xf,r,h,14,0.18,NAN,rng.randf_range(0.85,1.05))
			var c := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = r
			shape.height = h
			c.shape = shape
			c.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*(base+h*(k+0.5)))
			solids.add_child(c)
	# Lying: old drums sunk a little into the turf.
	for f: Array in LAYOUT.fallen:
		var p: Vector2 = f[0]
		var at := on_near(p) if str(f[2]) == "near" else on_far(p)
		var turn := Basis(Vector3.UP,deg_to_rad(float(f[1])))*Basis(Vector3.FORWARD,PI/2.0)
		var xf := Transform3D(turn,at+Vector3.UP*(r-0.35))
		g.cylinder(xf,r,h,14,0.18,at.y-0.3,rng.randf_range(0.8,1.0))
		var c := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = h
		c.shape = shape
		c.transform = xf
		solids.add_child(c)
	# The bed-stones on shelf A's rim, square to the column's line: pale cut
	# faces with a carved band, the place its end will lie between.
	for b: Array in LAYOUT.beds:
		var size: Vector3 = b[1]
		var at := on_far(b[0])
		var xf := Transform3D(Basis.IDENTITY,at+Vector3.UP*(size.y*0.5-0.15))
		g.box(xf,size,0.12,at.y-0.3,1.25)
		var z_face := -signf((b[0] as Vector2).y-float(LAYOUT.column.y))
		g.runes(at+Vector3(-size.x*0.5+0.2,size.y*0.6,z_face*size.z*0.5),at+Vector3(size.x*0.5-0.2,size.y*0.6,z_face*size.z*0.5),Vector3.UP,Vector3(0.0,0.0,z_face),float(SEED)+at.z)
		_collide_box(solids,xf,size)
	# Fallen courses at the gate wall's foot, either side of the lane: low
	# (under his climb's margin: the wall above stays past his reach), half
	# in the turf, tumbled.
	for b: Array in LAYOUT.wall_rubble:
		var p: Vector2 = b[0]
		var size: Vector3 = b[1]
		var at := on_far(p)
		var turn := Basis(Vector3.UP,deg_to_rad(float(b[2])))*Basis(Vector3.RIGHT,deg_to_rad(float(b[3])))
		var xf := Transform3D(turn,at+Vector3.UP*(size.y*0.5-0.35))
		g.box(xf,size,0.22,at.y-0.3,rng.randf_range(0.8,1.0))
		_collide_box(solids,xf,size)
	# The east steps' cover (rule 2): a broken screen on the terrace's lip
	# west of the steps, hiding them from his beat (his draw needs a clear
	# line to your chest), and a low lip along the void at the steps' and
	# the apron's east edge (a stumble or a swat stops on it, not off the
	# rim). The column's own rim, between it and the gap, stays open.
	for b: Array in LAYOUT.step_cover:
		var p: Vector2 = b[0]
		var size: Vector3 = b[1]
		var base := near_ground(p.x,p.y)
		var xf := Transform3D(Basis(Vector3.UP,deg_to_rad(float(b[2]))),Vector3(p.x,base+(size.y-0.4)*0.5,p.y))
		g.box(xf,size+Vector3(0.0,0.4,0.0),0.18,base-0.3,rng.randf_range(0.85,1.05))
		_collide_box(solids,xf,size+Vector3(0.0,0.4,0.0))
	var mesh := MeshInstance3D.new()
	mesh.name = "DressingMesh"
	mesh.mesh = GiantStone.mesh_of(g)
	root.add_child(mesh)
	root.add_child(solids)
	pieces.dressing = mesh

static func _collide_box(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	c.shape = shape
	c.transform = xf
	body.add_child(c)

func _triangles() -> int:
	var n := 0
	for p: Node3D in pieces.values(): n += int(p.get_meta("triangles",0))
	return n

# --- What moves --------------------------------------------------------------------------

## Live, once built: every piece the Olmec's power works on, his breaker
## hub, the Feller and his beat, the fires, the yard's far pillars, and (in
## the abyss) the grass on the stone's walked tops.
var live_parts := {}

func live(g: Node) -> void:
	live_parts.clear()
	var hub: Node3D = Breakables.new()
	hub.field = g.stage.enemies
	g.add_child(hub)
	live_parts.hub = hub
	var host := Node3D.new()
	host.name = "FelledColonnadeLive"
	g.add_child(host)
	# The column at the near rim, falling along x.
	var c: Vector2 = LAYOUT.column
	live_parts.column = CityKit.stand("maker_felled",host,Transform3D(Basis.IDENTITY,g.w(Vector3(c.x,TERRACE,c.y))),SEED+20,0.55)
	# The chocked slab: its near rim on the gallery's east edge, its gap +x.
	var ch: Vector2 = LAYOUT.chock
	live_parts.chock = CityKit.stand("maker_chock",host,Transform3D(Basis(Vector3.UP,PI/2.0),g.w(Vector3(ch.x,GALLERY,ch.y))),SEED+21,0.5)
	# The plug in its gate wall across shelf A's north.
	var pl: Vector2 = LAYOUT.plug
	live_parts.plug = CityKit.stand("colossus_plug",host,Transform3D(Basis.IDENTITY,g.w(Vector3(pl.x,TERRACE,pl.y))),SEED+22,0.5)
	# The drum floor in the forecourt's pit.
	var d: Vector2 = LAYOUT.drum_floor
	live_parts.drum = CityKit.stand("colossus_drum",host,Transform3D(Basis(Vector3.UP,0.0),g.w(Vector3(d.x,0.0,d.y))),SEED+23,0.4)
	# The fire: the crown's beacon (lit long since).
	var fires := Node3D.new()
	fires.name = "Fires"
	g.add_child(fires)
	var bc: Dictionary = LAYOUT.beacon
	CityFires.tower(fires,Transform3D(Basis(Vector3.UP,0.5),g.w(on_far(bc.at))),{"seed":SEED+30,"name":"CrownBeacon","lit":bool(bc.lit)})
	# The Feller: a whole Olmec on the terrace, chase and its routes on.
	# In a generated layer the roaming Olmec comes instead (olmec-threat-
	# round1.md; `--knob=olmecs=places` brings the Feller back).
	if OlmecPlaces.keepers(g):
		var fd: Dictionary = LAYOUT.feller
		var beat: Array[Vector3] = []
		for p: Vector2 in fd.beat: beat.append(g.w(on_near(p)))
		var post: Vector3 = beat[0]
		var body: Node3D = g.enemy(HeadlessBody,post+Vector3.UP*0.1,fd.face,{"chase":1,"chase_routes":1,"step":CityBreaks.OLMEC_STEP,"seed":SEED})
		var head: Node3D = g.enemy(InhalerHead,post+Vector3.UP*0.1,fd.face,{})
		var feller := Feller.new()
		feller.name = "Feller_STANDIN"
		feller.beat = beat
		feller.post = post
		feller.field = g.stage.enemies
		feller.hub = hub
		feller.wear(body,head)
		g.add_child(feller)
		live_parts.feller = feller
	if str(g.stage.study.get_script().resource_path).ends_with("motif_yard.gd"): _far(g)
	if Underground.on():
		var dresser := Dresser.new()
		dresser.name = "Dresser"
		dresser.motif = self
		g.add_child(dresser)

## Alone in the yard: far pillars in the haze, their crowns lit (drawn only;
## in a layer the other isles are the distance).
func _far(g: Node) -> void:
	var far := Node3D.new()
	far.name = "FarLayers"
	g.add_child(far)
	var k := 0
	for f: Array in LAYOUT.far_pillars:
		var crown := float(f[2])*COURSE
		var at: Vector3 = g.w(Vector3(float(f[0]),crown,float(f[1])))
		var p := CityKit.pillar(SEED+60+k,0.7,{"apothem":float(f[3]),"courses":2,"climb":-1,"crown":"paved","depth":crown+110.0})
		p.position = at
		for n: Node in p.find_children("*","CollisionObject3D",true,false): (n as CollisionObject3D).collision_layer = 0
		far.add_child(p)
		CityFires.tower(far,Transform3D(Basis(Vector3.UP,k*1.3),at+Vector3(float(f[3])*0.3,2.0*SO,0.0)),{"tiers":2,"base":9.0,"steps":false,"lit":true,"seed":SEED+70+k,"name":"FarTower%d" % k,"beam":3.0})
		k += 1

## STAND-IN: the Feller's rounds (the Stacked Court's Keeper). A whole Olmec
## unaware roams any way; this turns him, while he listens or roams and
## isn't hunting, toward the next point of his beat on the terrace, back and
## forth. It holds him at his post till the ground under him stands, puts
## his head back after the yard's reset, and hands every Olmec the hub.
class Feller extends Node:
	var beat: Array[Vector3] = []
	var post := Vector3.ZERO
	var field: Node = null
	var hub: Node3D = null
	var body: Node3D = null
	var head: Node3D = null
	var leg := 1
	var dir := 1
	var landed := false
	var turns := 0
	var steered := 0
	## Off: the beat lets him be (a check's setup steers him itself).
	var on := true

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
		if not on or not body.whole or body.hunting: return
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

## The abyss's ground cover on the stone's walked tops once they stand: the
## stair's landings, summit and flank tiers, the causeway's deck.
class Dresser extends Node:
	const ON := ["landing","summit","deck","tier"]
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
		for key: String in ["stair","causeway"]:
			var p: Node3D = pieces.get(key)
			if p == null: continue
			for a: Dictionary in p.get_meta("walk_areas",[]):
				if not String(a.kind) in ON: continue
				if GroundCover.cover(p,a.poly,kind,float(a.y),SEED+k,{}) != null: laid += 1
				k += 1
		# The gate wall's head, grown over: tufts against the haze along its
		# top (the plug's frame: the wall along x, its head at WALL_H).
		var plug: Node3D = (motif.get("live_parts") as Dictionary).get("plug")
		if plug != null and is_instance_valid(plug):
			var P := load("res://scripts/city_breaks/plug_stone.gd")
			var half := CityKit.LANE*0.5+float(P.JAMB)
			if GroundCover.cover(plug,Rect2(-half,-float(P.THICK)*0.5,half*2.0,float(P.THICK)),kind,float(P.WALL_H),SEED+40,{"tufts":1.6,"fade":0.9}) != null: laid += 1
		print("felled colonnade: ground %s on %d tops" % [kind,laid])
		set_physics_process(false)
