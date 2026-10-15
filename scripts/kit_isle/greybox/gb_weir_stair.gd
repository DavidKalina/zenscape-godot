extends "res://scripts/kit_isle/motif_greybox.gd"
## The Weir Stair (card: docs/design/roguelike/brainstorm/round4-crossings/
## motif-m3-weir-stair.md), a place of the underground Olmec city: seven
## stone basins stepping down a gulf from a high cistern shelf to a low far
## isle, the water leaping tier to tier in one white zig-zag. The stair is
## the way across.
##
##   the head      (38.4) the arrival shelf, south: turf, the cistern sunk in
##                 it, its channel and gate, and the carved maw at the lip
##                 that spits the water into the first basin.
##   the rib       a spur of the head's cliff stepping north in three turf
##                 terraces, a basin sunk in each (W1-W3), its keel hanging.
##   the piers     W4-W6, tanks on tall basalt legs over the void: the gulf.
##   the far isle  (1.6) W7 on its south spur, the drowned court under it
##                 (a stair of stone heads half under water), the terrace,
##                 its beacon and lamps, the rim out, north.
## Each weir drops a course (4.8 m, under the 6 m that stuns); its spill
## notch alternates east and west, so the water reads as a zig-zag. W3 and W5
## lost their lips (the sheet pours over a broken edge, and the next tier's
## brims are broken at their back ends); W6's east brim has slumped.
##
## Routes (rim in on the head's south edge, rim out on the far isle's north):
##   dry   the west brims: walk off each brim's end onto the next (4.8 m);
##         at a lost lip long-jump the broken stub, or hang-drop onto it and
##         jump-catch the brim (1.6 m) up; off W7 onto the far terrace.
##   wet   drop into W1, wait for the gate's surge, ride it: carried to each
##         notch and flung into the next pool, seven times, into the court.
##         STAND-IN: the sluice trap's carry and fling, one trap a pool,
##         chained by a motif-local surge clock (no carried-slide rule).
## Threat: three tenders (headless bodies) set clinging under rims as you
## come near (STAND-IN spawn on approach); the warden head on the head
## shelf's lip, inhaling whoever is in the air over W1-W2.
##
## Everything is one LAYOUT table; the ground is solved from it.
const OlmecPlaces = preload("res://scripts/enemies/olmec_places.gd")
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const HeadLook = preload("res://scripts/enemies/inhaler_head_look.gd")
const Sluice = preload("res://scripts/traps/trap_sluice.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const Court = preload("res://scripts/kit_isle/greybox/gb_stacked_court.gd")
const Veil = preload("res://scripts/kit_isle/greybox/weir_stair_veil.gd")
const Hang = preload("res://scripts/city_kit_hang.gd")

## Polish (round 4): broken rims, battered legs, hanging growth, a broken
## hillside for the head and the far isle, warm votives. `--weirstair-grey`
## draws the round-3 place (clean basins, plain posts) for A/B.
static var polished := _polish_from_args()

static var ws_off: Array = _off_from_args()

static func _off_from_args() -> Array:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--ws-off="): return a.trim_prefix("--ws-off=").split(",")
	return []

static func _polish_from_args() -> bool:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a == "--weirstair-grey": return false
	return true

const SO := CityKit.SET_OFF
const COURSE := CityKit.COURSE
const SEED := 8800

# --- The layout: one table ----------------------------------------------------------------
## Frame: x east, z south; the arrival is south (+z) looking north (-z), the
## cataract runs north and down. Heights in m.
const LAYOUT := {
	# The keels fade to this (m) into the haze.
	"floor":-60.0,
	# The head shelf: its level (8 weirs' drops over the far isle's court
	# water), its outline (x, z) south of the lip (z 0), clockwise from the
	# arrival; its swells (m) held flat near what stands.
	# Its east arm runs north along the gulf, a void's width off the rib: the
	# lookout (the arrival), where the stair is seen whole across the gulf.
	"head":{"y":8.0*COURSE,"outline":[Vector2(-27.0,28.0),Vector2(-9.0,31.5),Vector2(10.0,30.5),Vector2(25.0,26.0),Vector2(34.0,18.0),
		Vector2(41.0,9.0),Vector2(48.0,1.0),Vector2(54.0,-9.0),Vector2(58.0,-18.0),Vector2(57.0,-27.0),Vector2(51.5,-31.5),Vector2(45.5,-29.0),
		Vector2(41.5,-21.0),Vector2(36.5,-12.5),Vector2(30.5,-4.0),Vector2(25.5,-0.6),Vector2(20.5,0.3)],"west":[Vector2(-27.0,2.4),Vector2(-34.0,9.0),Vector2(-34.5,19.0)],
		"rumple":0.7,"rise":[1.8,15.0,27.0]},
	# The arm: west of `x` (wandering) it is the void; north it sinks `sink` m;
	# the lookout knoll at its tip [x, z, radius, high].
	"arm":{"x":27.0,"sink":2.0*COURSE,"lean":1.4,"knoll":[50.0,-14.0,6.0,1.2]},
	# The weirs: how many, their pitch along the gulf (m north each), the
	# drop (a course: a walk off a brim lands under the stun), the first
	# basin's inner width and how much wider each next one is, the side
	# brims' width, the front wall's thickness, the brim over the pool's floor,
	# the water over the floor (a wade), the notch's width and how far off
	# the middle (east for odd weirs, west for even).
	"weirs":{"count":7,"pitch":[8.5,8.5,8.5,12.0,12.0,12.0,12.0],"drop":COURSE,"first_w":26.0,"widen":2.4,"brim":2.4,"wall":1.6,
		"kerb":0.8,"water":0.45,"notch":7.0,"notch_x":4.0},
	# The broken weirs: their front wall gone to the water across `wide` m
	# round the notch, the next tier's brims broken back `stub` m to a
	# set-off under their tops (the dry route's long jump or hang-drop).
	"lost":{"weirs":[3,5],"wide":13.0,"stub":4.4},
	# W6's east brim sagged `sag` m over its north half, over its broken leg;
	# a crack in it lets a sheet fall free into the haze (toward the lookout).
	"slump":{"weir":6,"side":1.0,"sag":1.2},
	# Which weirs stand on the rib (its terraces a set-off under their brims)
	# and which on legs over the void (`legs`: the piers' width, depth, foot).
	"rib":{"weirs":3,"margin_e":[3.5,4.6,3.0],"margin_w":[4.2,3.2,4.8]},
	# Each leg [weir, x (m off the middle), wide, deep, foot (y), batter (m
	# out a m down), broken (its foot snapped off short)].
	"legs":{"weirs":[4,5,6,7],"each":[[4,-12.0,4.4,4.6,-74.0,0.03,false],[4,11.5,3.6,3.8,-58.0,0.02,false],
		[5,-4.0,5.2,5.0,-80.0,0.035,false],[5,16.0,3.4,3.6,-50.0,0.015,false],
		[6,17.5,4.2,4.2,-4.0,0.03,true],[6,-9.0,4.6,4.4,-66.0,0.03,false],
		[7,-13.0,4.0,4.6,-60.0,0.025,false],[7,11.0,3.6,3.8,-72.0,0.02,false]]},
	# The cistern head on the shelf: its tank (rect), its floor and water,
	# its channel to the maw, the gate's place along the channel (z).
	"cistern":{"rect":Rect2(-6.0,7.0,12.0,8.0),"floor":-1.0,"water":-0.45,"channel":2.4,"gate_z":7.0},
	# The maw: a stone head in the lip, its chin's foot (x, y over W1's
	# terrace, z), its height, its jaw open.
	"maw":{"at":Vector3(0.0,0.6,1.6),"h":8.6,"open":0.55},
	# The far isle, two courses under W7's spur would have been: its
	# terrace, outline (its south edge a gap past W7's front wall: the last
	# spill falls free across it), its south-west shelf (a set-off and a
	# half over the terrace, from x and north to z: the dry way's step).
	"far":{"y":SO-3.0*COURSE,"outline":[Vector2(-27.5,-83.1),Vector2(-21.0,-83.5),Vector2(-8.0,-84.4),Vector2(10.0,-84.6),Vector2(26.0,-85.1),Vector2(36.0,-87.5),
		Vector2(45.0,-97.5),Vector2(47.0,-111.5),Vector2(41.0,-122.5),Vector2(28.0,-130.5),Vector2(8.0,-133.5),Vector2(-14.0,-131.5),
		Vector2(-33.0,-123.5),Vector2(-44.0,-110.5),Vector2(-45.0,-97.5),Vector2(-38.0,-87.5),Vector2(-31.0,-84.0)],"rumple":0.8,
		"shelf":[-18.6,-95.5,2.0*SO]},
	# The stacks: rocks in the gap under W7's west brim, each a course under
	# the last, the second against the far isle's shelf [x, z, radius, top].
	"stacks":[[-23.2,-77.4,2.6,0.0],[-26.2,-82.4,2.5,-COURSE]],
	# The drowned court on the far isle under W7's fall: its half width,
	# south and north ends, the plunge pool (deep: it catches a fall) to z,
	# its floors and water, its stair of `steps` up to the terrace over `stair` m.
	"court":{"half":17.0,"south":-84.5,"north":-108.5,"plunge":-102.5,"deep":-16.6,"floor":-16.6,"water":-14.4,"steps":9,"stair":6.0},
	# The stone heads on the court's stair, half under water [x, z, h, turn deg].
	"heads":[[-14.6,-104.0,3.4,8.0],[14.6,-103.5,3.6,-12.0],[-12.0,-107.5,3.0,-4.0],[12.4,-107.7,3.2,10.0]],
	# The warden: an inhaler head on the head shelf's lip, looking north.
	"warden":{"at":Vector3(-25.0,0.0,5.0),"face":Vector2(0.0,-1.0),"knobs":{"size":3.0}},
	# The tenders: bodies set clinging under a rim when he comes within
	# `near` m (lip (x, y, z), out (x, z)); filled in by `tenders()`.
	"tenders":{"near":26.0},
	# The surge clock (STAND-IN): the head gate's period and first opening
	# (s), its tell (s), each lower gate's tell (s), the wave's pace (runs).
	"surge":{"period":24.0,"first":8.0,"tell":2.6,"relay":0.1,"pace":3.2,
		# The gate plate: the head sluice's own plate (`trigger` "plate"), this
		# far (m) down W1's channel, a worn slab under the water.
		"plate":1.4,
		# Where a flung rider lands (m on from the lip), and how far behind
		# that (toward the outer wall) the next channel starts.
		"land":6.0,"back":3.5},
	# The lights: a dim cresset on each weir's east brim (`lamp`);
	# the far terrace's lamps and beacon.
	"far_lamps":[Vector2(-10.0,-112.5)],
	"beacon":Vector2(22.0,-121.5),
	# The stair's own lamps, few and each its own: a cresset lit on W1's east
	# brim; one in a niche cut in the head's cliff over W1's west terrace
	# [x, z, turn]; one fallen and out on W5's east brim; one lit on W7's.
	"lamps":{"lit":[1,7],"niche":[-17.6,-0.6,0.0],"fallen":5},
	# Polish: the city's stone sunk in the land. ["block", x, z, size, yaw,
	# pitch, roll (deg), sunk (m)], ["drum", x, z, radius, length, yaw, sunk].
	"stones":[
		["drum",-22.0,19.0,1.4,2.2,64.0,0.7],["drum",-18.5,16.5,1.4,2.0,72.0,0.8],["block",-25.5,22.0,Vector3(3.6,1.8,3.0),22.0,9.0,-7.0,0.8],
		["block",21.0,18.0,Vector3(1.3,5.0,0.9),14.0,-6.0,12.0,1.3],["block",23.0,20.0,Vector3(2.2,1.3,1.8),40.0,12.0,16.0,0.6],
		["block",19.0,8.0,Vector3(4.2,1.6,2.4),-18.0,6.0,-4.0,0.7],["block",-28.0,9.0,Vector3(2.6,1.6,2.2),35.0,-14.0,10.0,0.6],
		["block",-15.8,-4.0,Vector3(2.4,1.6,2.0),20.0,10.0,-12.0,0.6],["block",17.0,-12.5,Vector3(2.0,1.4,1.8),-30.0,-12.0,18.0,0.5],
		["block",-31.0,-112.5,Vector3(3.4,2.0,2.6),15.0,10.0,-8.0,0.8],["drum",28.0,-111.5,1.3,2.2,30.0,0.7],
		["block",-14.0,-125.5,Vector3(1.2,4.6,0.9),-10.0,7.0,-12.0,1.1],["block",32.0,-93.5,Vector3(2.8,1.6,2.0),50.0,-10.0,14.0,0.6],
	],
	# Blocks tumbled from the broken lips into the pools below (in the
	# corners off the surge's landing and line) [weir below, x, z, size, yaw, roll].
	"tumbled":[[4,-13.0,-27.0,Vector3(2.0,1.4,1.6),25.0,14.0],[4,-12.5,-30.2,Vector3(1.6,1.0,1.4),-30.0,-10.0],
		[6,-17.0,-52.5,Vector3(2.2,1.2,1.8),15.0,-16.0],[6,-14.0,-59.5,Vector3(1.4,1.0,1.2),40.0,8.0]],
	# The arrival (start) and the rims.
	"start":Vector2(48.0,-24.5),
	"rim_in":Vector2(54.5,-25.5),
	"rim_out":Vector2(0.0,-121.5),
	# Polish: turf taken over the stone: caps on brims and front walls
	# [weir, "e"/"w" brim or "f" front wall, from, to (z along a brim, x
	# along a front wall)], their ground the stone's top.
	"caps":[[2,"e",-15.5,-9.5],[4,"f",-17.5,-9.8],[5,"e",-44.0,-39.0],[6,"w",-60.0,-53.0],[7,"w",-72.0,-65.0],[3,"f",-16.5,-9.0]],
	# Polish (round 4). The broken hillside of the head and the far isle:
	# which outline edges get noses and bays (kept off the lookout's rim and
	# the dry route's landings), the turf-rounded lip (m down, m wide),
	# knolls [x, z, radius, high] and slumps [x, z, rx, rz, down] (held off
	# the start, the rims, the cistern, the court and the lamps).
	"hill":{"jag_head":[0,1,2,3,4,5,6,7,12,13],"jag_far":[5,6,7,8,9,10,11,12,13,14],"round":[1.1,3.2],
		"head_knolls":[[-8.0,24.0,7.0,2.4],[26.0,14.0,7.0,2.6],[-24.0,11.0,5.5,1.8],[33.5,-7.0,4.5,1.2],[0.0,17.0,4.0,1.0]],
		"head_slumps":[[-17.0,20.0,7.5,4.4,2.4,0.8],[25.0,21.0,6.5,4.2,2.2,0.8],[-6.0,28.0,5.0,2.6,1.6],[39.0,-17.0,4.2,5.2,2.0],[-31.0,14.0,4.0,7.0,2.0],[44.5,4.5,5.0,4.2,1.8],[2.0,30.0,3.5,3.0,1.6]],
		"far_knolls":[[33.0,-103.0,6.0,1.9],[-34.0,-117.0,6.5,2.1],[-5.0,-128.0,5.5,1.5],[35.0,-95.0,4.0,1.4],[16.0,-112.0,4.0,1.0]],
		"far_slumps":[[40.0,-120.0,5.0,4.5,2.2],[-40.0,-103.0,4.0,6.0,2.2],[16.0,-130.0,6.5,3.2,1.8],[-24.0,-130.0,5.0,3.0,1.6]]},
	# Warm votives on the east brims: [weir, along from the back (m), size].
	"votives":[[2,-2.5,1.0],[3,-1.5,0.8],[4,-4.0,1.2],[6,-1.8,0.9]],
	# The lookout's tower lamp [x, z] and what fell round it.
	"tower":Vector2(50.0,-16.5),
	# Silt mounds in the pools' two quiet corners (radius), grass and reeds on them.
	"silt":2.3,
	# The east brims' front ends that slumped [weirs], how far (m) and how long (m).
	"slump_e":{"weirs":[2,4,7],"sag":0.9,"len":3.4},
	# Dips worn in the east brims [weir, from the front wall (m), long (m), down (m)].
	"dips":[[1,3.6,2.6,0.6],[3,3.6,2.8,0.7],[5,2.2,3.0,0.7],[7,8.5,2.6,0.6]],
	# Polish: more stone sunk in the hills ["block"/"drum" as `stones`).
	"stones2":[
		["block",35.0,-19.5,Vector3(2.6,1.4,1.0),80.0,-8.0,10.0,0.6],["block",36.5,-21.5,Vector3(1.4,1.1,1.0),20.0,12.0,-14.0,0.4],
		["drum",12.0,24.0,1.1,2.4,-20.0,0.6],["block",8.0,26.5,Vector3(1.0,3.4,0.9),30.0,-9.0,-6.0,1.2],
		["block",-4.0,20.5,Vector3(2.0,1.2,1.6),55.0,8.0,10.0,0.5],["drum",30.0,-4.0,1.2,2.0,115.0,0.7],
		["block",-33.0,-109.0,Vector3(1.8,2.6,1.2),70.0,-10.0,8.0,0.9],["block",30.0,-122.0,Vector3(2.4,1.5,1.8),-35.0,9.0,-12.0,0.5],
		["drum",-22.0,-126.0,1.2,2.6,50.0,0.8],["block",36.0,-108.0,Vector3(1.6,1.2,1.4),-12.0,-9.0,14.0,0.4],
		["block",-27.0,-96.0,Vector3(1.6,1.0,2.2),12.0,10.0,-8.0,0.4],
	],
}

# --- The weirs' numbers --------------------------------------------------------------------

static func count() -> int:
	return int(LAYOUT.weirs.count)

static func head_y() -> float:
	return float(LAYOUT.head.y)

static func drop() -> float:
	return float(LAYOUT.weirs.drop)

## The rib's pitch (its three weirs'); `pitch_of` each weir's own (the
## legs' longer: the gulf).
static func pitch() -> float:
	return pitch_of(1)

static func pitch_of(k: int) -> float:
	return float(LAYOUT.weirs.pitch[clampi(k,1,count())-1])

## Weir k's (1..7) brim, its pool's floor and water, and the terrace beside
## it (a set-off under the brim; the rib's and the far spur's ground).
static func brim(k: int) -> float:
	return head_y()-k*drop()

static func floor_of(k: int) -> float:
	return brim(k)-float(LAYOUT.weirs.kerb)

static func water(k: int) -> float:
	return floor_of(k)+float(LAYOUT.weirs.water)

static func terrace(k: int) -> float:
	return brim(k)-SO

## Weir k's inner width (x) and its outer half width (to the brim's outside).
static func inner(k: int) -> float:
	return float(LAYOUT.weirs.first_w)+float(LAYOUT.weirs.widen)*(k-1)

static func outer(k: int) -> float:
	return inner(k)*0.5+float(LAYOUT.weirs.brim)

## Weir k's band along the gulf: its back (the last weir's front face) and
## its front (its own front wall's north face).
static func back_z(k: int) -> float:
	var z := 0.0
	for i in range(1,k): z -= pitch_of(i)
	return z

static func front_z(k: int) -> float:
	return back_z(k)-pitch_of(k)

## Polish: whether the pool's water reaches (x, z): it laps the walls
## unevenly (silt and paving showing in a ragged margin), and runs clean
## to the notch.
static func wet_edge(k: int, p: Vector2) -> bool:
	if not polished: return true
	var r := pool_rect(k)
	var d := minf(minf(p.x-r.position.x,r.end.x-p.x),minf(p.y-r.position.y,r.end.y-p.y))
	if d > 1.4: return true
	if absf(p.x-spill_mid(k)) < spill_wide(k)*0.5+1.2 and p.y < r.position.y+3.0: return true
	var m := 0.1+1.2*(0.5+0.5*sin(p.x*1.3+p.y*0.9+k*3.0))*(0.5+0.5*sin(p.x*0.37-p.y*1.1+k))
	return d > m

## The pool's water (x, z): inside the brims, from the front wall to the back.
static func pool_rect(k: int) -> Rect2:
	var half := inner(k)*0.5
	var z0 := front_z(k)+float(LAYOUT.weirs.wall)
	return Rect2(-half,z0,half*2.0,back_z(k)-z0)

## Which side weir k spills on (+1 east, -1 west) and its notch's middle x.
static func side(k: int) -> float:
	return 1.0 if k % 2 == 1 else -1.0

static func notch_x(k: int) -> float:
	return side(k)*float(LAYOUT.weirs.notch_x)

static func lost(k: int) -> bool:
	return (LAYOUT.lost.weirs as Array).has(k)

static func on_legs(k: int) -> bool:
	return (LAYOUT.legs.weirs as Array).has(k)

## The spill's span along the front wall (x from, to): the notch (or the
## broken stretch) round `notch_x`, widened to take in where the surge's
## channel crosses the wall's thickness (it comes in on a slant).
static func spill_span(k: int) -> Vector2:
	if k == count():
		var w := inner(k)*0.5-1.2
		return Vector2(-w,w)
	var half := float(LAYOUT.lost.wide if lost(k) else LAYOUT.weirs.notch)*0.5
	var nx := notch_x(k)
	var span := Vector2(nx-half,nx+half)
	var l: Array = lines()[k-1]
	var a: Vector3 = l[0]
	var wall := float(LAYOUT.weirs.wall)
	var xs := nx+(a.x-nx)*(wall/maxf(a.z-front_z(k),wall+0.1))
	return Vector2(minf(span.x,xs-1.8),maxf(span.y,xs+1.8))

static func spill_mid(k: int) -> float:
	var s := spill_span(k)
	return (s.x+s.y)*0.5

static func spill_wide(k: int) -> float:
	var s := spill_span(k)
	return s.y-s.x

## The tank's underside (legs) or the terrace it sits on (rib, far spur).
static func base_of(k: int) -> float:
	return floor_of(k)-SO if on_legs(k) else terrace(k)

## The front wall's top at x (the broken weirs' ragged edge just under the
## water; the notch cut to a sill a hand over the floor).
static func front_top(k: int, x: float) -> float:
	# W6's sagged corner goes down with its brim.
	var sl: Dictionary = LAYOUT.slump
	if k == int(sl.weir) and x*float(sl.side) > inner(k)*0.5-0.6: return brim(k)-float(sl.sag)
	var off := absf(x-spill_mid(k))
	if lost(k):
		var half := spill_wide(k)*0.5+0.9*sin(x*0.7+k)
		if off < half: return water(k)-0.12+0.1*sin(x*2.3+k*1.7)
		if off < half+2.4: return lerpf(water(k),brim(k),smoothstep(half,half+2.4,off))-0.3*absf(sin(x*1.9))
		return brim(k)
	if off < spill_wide(k)*0.5: return floor_of(k)+0.05
	# Polish: the lip worn down in two steps where the water pours (W4's wall
	# stays as it was: the careful route's hang-drop reads it).
	if polished and k < count() and not ws_off.has("ramp") and k != 4:
		var w := spill_wide(k)*0.5
		if off < w+1.0: return brim(k)-1.2
		if off < w+2.2: return brim(k)-0.55
	return brim(k)

## Weir k's east brim's low stretches [from the front wall, long, down]
## (m), in order: the slumped front end, then the worn dips.
static func east_dips(k: int) -> Array:
	var out: Array = []
	if (LAYOUT.slump_e.weirs as Array).has(k): out.append([0.0,float(LAYOUT.slump_e.len),float(LAYOUT.slump_e.sag)])
	for d: Array in LAYOUT.dips:
		if int(d[0]) == k: out.append([float(d[1]),float(d[2]),float(d[3])])
	return out

## The side brim's top at z on side `s` (the stub broken under a lost lip;
## W6's slumped east brim).
static func brim_top(k: int, s: float, z: float) -> float:
	if lost(k-1) and z > back_z(k)-float(LAYOUT.lost.stub): return brim(k)-SO
	var sl: Dictionary = LAYOUT.slump
	if k == int(sl.weir) and s*float(sl.side) > 0.0:
		var t := clampf((back_z(k)-z)/pitch_of(k),0.0,1.0)
		return brim(k)-float(sl.sag)*smoothstep(0.35,0.75,t)
	if polished and s > 0.0 and not ws_off.has("dips"):
		for d: Array in east_dips(k):
			if z >= front_z(k)+float(d[0]) and z < front_z(k)+float(d[0])+float(d[1]): return brim(k)-float(d[2])
	return brim(k)

## Weir k's lamp: on its east brim near the back (off the dry west brims
## and the surge's landings), on the brim's top.
static func lamp(k: int) -> Vector3:
	var z := back_z(k)-1.6
	return Vector3(inner(k)*0.5+float(LAYOUT.weirs.brim)*0.5,brim_top(k,1.0,z),z)

# --- The surge's line (the stand-in's channels) ---------------------------------------

## Each weir's surge channel: [from, to] (the pool's floor, world frame of
## the motif): from where the water (or a flung rider) comes into the pool
## to the spill's lip (the front wall's north face). W1 from the maw.
static var _lines: Array = []
static func lines() -> Array:
	if not _lines.is_empty(): return _lines
	var out: Array = []
	# W1's from west of the maw's spout (on a slant, as every lower one).
	var from := Vector3(float(LAYOUT.maw.at.x)-side(1)*6.0,floor_of(1),back_z(1)-2.0)
	for k in range(1,count()+1):
		var to := Vector3(notch_x(k),floor_of(k),front_z(k))
		# The last weir spills its whole width: its surge runs straight north
		# from where the rider lands, to throw him across the gap.
		if k == count():
			from.x *= 0.3
			to = Vector3(from.x,floor_of(k),front_z(k))
		out.append([from,to])
		# A rider flung off the lip lands about this far on (m), at the
		# wave's pace for a course's fall, and slides on toward the pool's
		# outer wall; the next channel starts at that wall (the zig-zag turns
		# back), so wherever he lands it is ahead of him.
		var d := Vector2(to.x-from.x,to.z-from.z).normalized()
		var land := Vector2(to.x,to.z)+d*float(LAYOUT.surge.land)
		if k < count():
			var r := pool_rect(k+1).grow(-1.0)
			var wall_x := side(k)*(inner(k+1)*0.5-0.7)
			var x := land.x+side(k)*float(LAYOUT.surge.back)
			x = minf(x,wall_x) if side(k) > 0.0 else maxf(x,wall_x)
			from = Vector3(x,floor_of(k+1),clampf(land.y,r.position.y,r.end.y))
	_lines = out
	return out

# --- The ground ------------------------------------------------------------------------

## The head and the rib (one island): the shelf south of the lip, the rib's
## terraces a course apart, each step under a front wall's middle; the
## cistern and its channel sunk in the shelf.
static func cliff_ground(x: float, z: float) -> float:
	var edge := 0.4*sin(x*0.31)+0.25*sin(x*0.83+1.0)
	var am: Dictionary = LAYOUT.arm
	if z < 2.0 and x > float(am.x)+1.2*sin(z*0.3):
		var kn: Array = am.knoll
		var d := Vector2(x-float(kn[0]),z-float(kn[1])).length()/float(kn[2])
		var knoll := float(kn[3])*pow(cos(clampf(d,0.0,1.0)*PI*0.5),2.0)
		var lean := float(am.lean)*smoothstep(8.0,0.0,x-(30.0-z*0.45))*smoothstep(2.0,-8.0,z)
		return head_y()-float(am.sink)*smoothstep(4.0,-30.0,z)-lean+knoll+0.3*sin(x*0.4+z*0.2)*smoothstep(-1.0,-8.0,z)*clampf(d-0.6,0.0,1.0)
	if z > edge:
		var y := head_y()
		var c: Dictionary = LAYOUT.cistern
		var r: Rect2 = c.rect
		if r.has_point(Vector2(x,z)): return y+float(c.floor)
		if absf(x) < float(c.channel)*0.5 and z < r.position.y and z > 0.0: return y+float(c.floor)
		var rs: Array = LAYOUT.head.rise
		return y+head_rumple(x,z)+float(rs[0])*smoothstep(float(rs[1]),float(rs[2]),z)
	var wall := float(LAYOUT.weirs.wall)
	var k := clampi(int(floor((-z+wall*0.5)/pitch()))+1,1,int(LAYOUT.rib.weirs)+1)
	return terrace(k)

## The head shelf's swells, held flat near the arrival, the cistern and
## the lip.
static func head_rumple(x: float, z: float) -> float:
	var a := float(LAYOUT.head.rumple)
	var keep := smoothstep(3.0,10.0,z)
	var s: Vector2 = LAYOUT.start
	keep = minf(keep,smoothstep(6.0,14.0,Vector2(x,z).distance_to(s)))
	var c: Rect2 = LAYOUT.cistern.rect
	keep = minf(keep,smoothstep(3.0,9.0,_rect_off(c,Vector2(x,z))))
	var n := sin(x*0.09+z*0.07)*sin(z*0.11-x*0.05)+0.5*sin(x*0.21+1.3)*sin(z*0.17)
	return a*n*keep+1.4*keep*pow(clampf(1.0-Vector2(x+24.0,z-20.0).length()/9.0,0.0,1.0),1.5)


# --- Polish: the broken hillside ----------------------------------------------------------

static var _polys := {}

## `pts` with noses and bays on the edges listed (edge i runs pts[i] to
## pts[i+1]): three points a bump out (a nose) or in (a bay), alternating.
## Edges whose middle is within 13 m of a point in `avoid` stay as they are.
static func _jagged(pts: Array, edges: Array, seed_value: int, avoid: Array) -> Array:
	var closed := PackedVector2Array(pts)
	var out: Array = []
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i+1)%pts.size()]
		out.append(a)
		if not edges.has(i) or a.distance_to(b) < 6.0: continue
		var mid := (a+b)*0.5
		var near := false
		for q: Vector2 in avoid:
			if mid.distance_to(q) < 13.0: near = true
		if near: continue
		var len := a.distance_to(b)
		var along := (b-a)/len
		var n := Vector2(along.y,-along.x)
		if Geometry2D.is_point_in_polygon(mid+n*0.6,closed): n = -n
		var h := fmod(absf(sin(float(i)*12.9898+seed_value)*43758.5453),1.0)
		var h2 := fmod(absf(sin(float(i)*78.233+seed_value*0.7)*12345.678),1.0)
		var nose := (i+seed_value)%2 == 0
		var amp := (2.4+2.6*h) if nose else -(2.0+1.5*h)
		var t := 0.3+0.25*h2
		var wide := 0.12+0.06*h
		out.append(a+along*len*(t-wide)+n*amp*0.35)
		out.append(a+along*len*t+n*amp)
		out.append(a+along*len*(t+wide)+n*amp*0.55)
		if len > 15.0:
			var t2 := minf(t+0.38,0.88)
			out.append(a+along*len*(t2-0.06)-n*amp*0.3)
			out.append(a+along*len*t2-n*amp*0.8)
			out.append(a+along*len*(t2+0.06)-n*amp*0.25)
	return out

static func _avoid() -> Array:
	return [LAYOUT.start as Vector2,LAYOUT.rim_in as Vector2,LAYOUT.rim_out as Vector2]

## The head's outline as drawn (noses and bays when polished).
static func head_outline() -> Array:
	if not polished or ws_off.has("jag"): return LAYOUT.head.outline.duplicate()
	if _polys.has("head"): return _polys.head
	var out := _jagged(LAYOUT.head.outline,LAYOUT.hill.jag_head,3,_avoid())
	_polys["head"] = out
	return out

## The far isle's outline as drawn.
static func far_outline() -> Array:
	if not polished or ws_off.has("jag"): return LAYOUT.far.outline.duplicate()
	if _polys.has("far"): return _polys.far
	var out := _jagged(LAYOUT.far.outline,LAYOUT.hill.jag_far,5,_avoid())
	_polys["far"] = out
	return out

static func _edge_dist(poly: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for i in poly.size():
		best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()])))
	return best

static func _poly_of(which: String) -> PackedVector2Array:
	if _polys.has(which+"_p"): return _polys[which+"_p"]
	var p := PackedVector2Array(cliff_outline() if which == "head" else far_outline())
	_polys[which+"_p"] = p
	return p

static func _knoll(x: float, z: float, k: Array) -> float:
	var d := Vector2(x-float(k[0]),z-float(k[1])).length()/float(k[2])
	return float(k[3])*pow(cos(clampf(d,0.0,1.0)*PI*0.5),2.0)

static func _bowl(x: float, z: float, s: Array) -> float:
	var d := Vector2((x-float(s[0]))/float(s[2]),(z-float(s[1]))/float(s[3])).length()
	return float(s[4])*smoothstep(1.0,float(s[5]) if s.size() > 5 else 0.35,d)

## The head's knolls, slumps and rounded lips (m), held flat at the start,
## the rim and the cistern.
static func hill_head(x: float, z: float) -> float:
	if not polished or ws_off.has("hill"): return 0.0
	var p := Vector2(x,z)
	var keep := smoothstep(7.0,15.0,p.distance_to(LAYOUT.start))
	keep = minf(keep,smoothstep(6.0,14.0,p.distance_to(LAYOUT.rim_in)))
	keep = minf(keep,smoothstep(3.0,9.0,_rect_off(LAYOUT.cistern.rect,p)))
	if keep <= 0.0: return 0.0
	var y := 0.0
	for k: Array in LAYOUT.hill.head_knolls: y += _knoll(x,z,k)
	for s: Array in LAYOUT.hill.head_slumps: y -= _bowl(x,z,s)
	var rd: Array = LAYOUT.hill.round
	var d := _edge_dist(_poly_of("head"),p)
	if d < float(rd[1]): y -= float(rd[0])*pow(1.0-d/float(rd[1]),2.0)
	return y*keep

## The far isle's, held off the court, the lamps, the beacon, the rim out
## and the dry way's stacks and shelf.
static func hill_far(x: float, z: float) -> float:
	if not polished or ws_off.has("hill"): return 0.0
	var p := Vector2(x,z)
	var c: Dictionary = LAYOUT.court
	var keep := smoothstep(2.0,8.0,maxf(absf(x)-float(c.half),float(c.north)-z))
	keep = minf(keep,smoothstep(5.0,11.0,p.distance_to(LAYOUT.rim_out)))
	keep = minf(keep,smoothstep(4.0,9.0,p.distance_to(LAYOUT.beacon)))
	for q: Vector2 in LAYOUT.far_lamps: keep = minf(keep,smoothstep(2.0,6.0,p.distance_to(q)))
	keep = minf(keep,smoothstep(0.0,5.0,_rect_off(Rect2(-40.0,-104.0,34.0,34.0),p)))
	if keep <= 0.0: return 0.0
	var y := 0.0
	for k: Array in LAYOUT.hill.far_knolls: y += _knoll(x,z,k)
	for s: Array in LAYOUT.hill.far_slumps: y -= _bowl(x,z,s)
	var rd: Array = LAYOUT.hill.round
	var d := _edge_dist(_poly_of("far"),p)
	if d < float(rd[1]): y -= float(rd[0])*pow(1.0-d/float(rd[1]),2.0)
	return y*keep

static func _rect_off(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x-p.x,p.x-r.end.x),0.0)
	var dz := maxf(maxf(r.position.y-p.y,p.y-r.end.y),0.0)
	return Vector2(dx,dz).length()

## The far isle: W7's spur (its terrace) south of W7's front wall's middle,
## the drowned court sunk under it with its stair north, the terrace round.
static func far_ground(x: float, z: float) -> float:
	var c: Dictionary = LAYOUT.court
	var y := float(LAYOUT.far.y)
	if absf(x) < float(c.half) and z > float(c.north):
		var stair_from := float(c.north)+float(c.stair)
		if z > float(c.plunge): return float(c.deep)
		if z > stair_from: return float(c.floor)
		var steps := int(c.steps)
		var tread := float(c.stair)/steps
		var up := clampi(int((stair_from-z)/tread)+1,0,steps)
		return float(c.floor)+(y-float(c.floor))*float(up)/steps
	var sh: Array = LAYOUT.far.shelf
	var edge := float(sh[0])+0.8*sin(z*0.5)
	if x < edge and z > float(sh[1])+1.2*sin(x*0.4): return y+float(sh[2])
	var keep := smoothstep(2.0,8.0,maxf(absf(x)-float(c.half),float(c.north)-z))
	var r: Vector2 = LAYOUT.rim_out
	keep = minf(keep,smoothstep(4.0,10.0,Vector2(x,z).distance_to(r)))
	var sw := sin(x*0.08+1.0)*sin(z*0.06)+0.4*sin(x*0.19)*sin(z*0.13+2.0)
	return y+float(LAYOUT.far.rumple)*sw*keep+hill_far(x,z)

## The head-and-rib island's outline: the head's, then down the rib's east
## side tier by tier, across its north end, up its west side.
static func cliff_outline() -> Array:
	var out: Array = []
	for p: Vector2 in head_outline(): out.append(p)
	var ribs := int(LAYOUT.rib.weirs)
	for k in range(1,ribs+1):
		var x := outer(k)+float(LAYOUT.rib.margin_e[k-1])
		out.append(Vector2(x+0.6*sin(k*1.7),back_z(k)-1.2))
		out.append(Vector2(x-0.4,front_z(k)+2.0))
	var end := front_z(ribs)-1.4
	out.append(Vector2(outer(ribs)+1.6,end))
	out.append(Vector2(3.0,end-0.6))
	out.append(Vector2(-outer(ribs)-1.2,end+0.3))
	for k in range(ribs,0,-1):
		var x := -outer(k)-float(LAYOUT.rib.margin_w[k-1])
		out.append(Vector2(x+0.5,front_z(k)+2.0))
		out.append(Vector2(x-0.5*sin(k*1.3),back_z(k)-1.2))
	for p: Vector2 in LAYOUT.head.west: out.append(p)
	return out

## A point on the ground (x, z): the head-and-rib's or the far isle's.
static func on(p: Vector2, up := 0.0) -> Vector3:
	var y := far_ground(p.x,p.y) if p.y < front_z(count()) else cliff_ground(p.x,p.y)
	return Vector3(p.x,y+up,p.y)

# --- The tenders (where they hang) -------------------------------------------------------

## [lip (on the rim), out (x, z)]: the rib's east cliff under W2's terrace,
## the rib's west cliff under W3's, W5's east leg (its brim over the void).
static func tenders() -> Array:
	var e2 := outer(2)+float(LAYOUT.rib.margin_e[1])-1.6
	var w3 := -outer(3)-float(LAYOUT.rib.margin_w[2])+1.6
	return [
		[Vector3(e2,terrace(2),(back_z(2)+front_z(2))*0.5),Vector2(1.0,0.0)],
		[Vector3(w3,terrace(3),(back_z(3)+front_z(3))*0.5),Vector2(-1.0,0.0)],
		[Vector3(outer(5)-0.6,brim(5),(back_z(5)+front_z(5))*0.5),Vector2(1.0,0.0)],
	]

# --- The motif's face -------------------------------------------------------------------

func slug() -> String:
	return "weir_stair"

func isle_name() -> String:
	return "The Weir Stair"

func epithet() -> String:
	return "Seven cisterns, one fall, and a city at the bottom that still drinks."

func brief() -> String:
	return "Down: walk the west brims and drop tier to tier (long-jump the broken lips); or wait in the first basin for the gate's surge and ride it down all seven.\nTenders climb the weir walls. The head at the lip inhales what flies."

func start() -> Vector3:
	return on(LAYOUT.start)

func rims() -> Array:
	return [
		{"name":"lookout","at":on(LAYOUT.rim_in),"face":Vector3(1.0,0.0,0.15),"run_up":12.0,"lip":1.5},
		{"name":"far_terrace","at":on(LAYOUT.rim_out),"face":Vector3(0.0,0.0,-1.0),"run_up":12.0,"lip":1.5},
	]

func heads() -> Array:
	var w: Dictionary = LAYOUT.warden
	var at := Vector3(float(w.at.x),head_y(),float(w.at.z))
	var knobs: Dictionary = (w.knobs as Dictionary).duplicate()
	knobs["route"] = [at]
	return [{"name":"warden","at":at,"face":w.face,"knobs":knobs}]

func spots() -> Array:
	var n := count()
	var out: Array = [
		{"kind":"arena","name":"head_shelf","at":on(Vector2(4.0,26.0)),"room":14.0},
		{"kind":"arena","name":"far_terrace","at":on(Vector2(0.0,-110.0)),"room":12.0},
		{"kind":"perch","name":"lookout","at":on(Vector2(47.0,-27.5)),"room":3.0},
		{"kind":"cover","name":"cistern_gate","at":on(Vector2(4.0,float(LAYOUT.cistern.gate_z)-1.5)),"room":2.0},
	]
	for k in range(1,n+1):
		if (LAYOUT.lamps.lit as Array).has(k): out.append({"kind":"perch","name":"weir%d_lamp" % k,"at":lamp(k),"room":1.0})
	# Runes along the routes: the west brims, the pools' notches.
	for k in range(1,n+1):
		out.append({"kind":"rune_line","name":"brim%d" % k,"at":Vector3(-inner(k)*0.5-1.6,brim(k)+0.6,(back_z(k)+front_z(k))*0.5),"room":1.0})
		out.append({"kind":"rune_line","name":"notch%d" % k,"at":Vector3(notch_x(k),floor_of(k)+0.6,front_z(k)+2.4),"room":1.0})
	out.append({"kind":"rune_risk","name":"maw_brow","at":Vector3(0.0,head_y()+2.6,1.0),"room":1.0})
	out.append({"kind":"rare","name":"court_heads","at":Vector3(-12.5,1.4,-84.0),"room":0.8})
	return out

## The solids for the occupancy, the footprint and the bodies' cliffs (the
## generator reads these): the head and rib in 4 m strips, the tanks, legs
## and front walls, the far isle and the water.
func parts() -> Array:
	var out: Array = []
	var floor_y := float(LAYOUT.floor)
	var poly := PackedVector2Array(cliff_outline())
	_strips(out,poly,func(x: float, z: float) -> float: return cliff_ground(x,z),floor_y)
	_strips(out,PackedVector2Array(far_outline()),func(x: float, z: float) -> float: return far_ground(x,z),floor_y)
	for k in range(1,count()+1):
		var o := outer(k)
		out.append(["box",Rect2(-o,front_z(k),o*2.0,pitch_of(k)),base_of(k),brim(k),"grey"])
		for l: Array in legs(k): out.append(["box",l[0],float(l[1]),base_of(k),"grey"])
		out.append(["water",pool_rect(k),floor_of(k),water(k)])
	var c: Dictionary = LAYOUT.court
	var h := float(c.half)
	out.append(["water",Rect2(-h,float(c.north),h*2.0,float(c.south)-float(c.north)),float(c.deep),float(c.water)])
	for st: Array in LAYOUT.stacks:
		out.append(["box",Rect2(float(st[0])-float(st[2])*0.7,float(st[1])-float(st[2])*0.7,float(st[2])*1.4,float(st[2])*1.4),float(st[3])-30.0,float(st[3]),"grey"])
	var ci: Dictionary = LAYOUT.cistern
	var cr: Rect2 = ci.rect
	out.append(["water",cr,head_y()+float(ci.floor),head_y()+float(ci.water)])
	return out

## An island's ground as 4 m strips (each its lowest), from the keel.
static func _strips(out: Array, poly: PackedVector2Array, ground: Callable, floor_y: float) -> void:
	var box := Rect2(poly[0],Vector2.ZERO)
	for p in poly: box = box.expand(p)
	var cell := 4.0
	var z := box.position.y
	while z < box.end.y:
		var x := box.position.x
		var run_x := NAN
		var run_y := NAN
		while x <= box.end.x:
			var h := NAN
			if Geometry2D.is_point_in_polygon(Vector2(x+cell*0.5,z+cell*0.5),poly):
				h = INF
				for q: Vector2 in [Vector2(0.3,0.3),Vector2(cell-0.3,0.3),Vector2(0.3,cell-0.3),Vector2(cell-0.3,cell-0.3),Vector2(cell*0.5,cell*0.5)]:
					h = minf(h,float(ground.call(x+q.x,z+q.y)))
				h = snappedf(h,0.1)
			if not is_nan(run_x) and (is_nan(h) or h != run_y):
				out.append(["box",Rect2(run_x,z,x-run_x,cell),floor_y,run_y,"grey"])
				run_x = NAN
			if not is_nan(h) and is_nan(run_x):
				run_x = x
				run_y = h
			x += cell
		if not is_nan(run_x): out.append(["box",Rect2(run_x,z,x-run_x,cell),floor_y,run_y,"grey"])
		z += cell

# --- The land and the stone ------------------------------------------------------------

func flora_site() -> KitFlora.Site:
	# The rays span the head (38.4) down past the court's terrace (1.6).
	var site := KitFlora.Site.new(top(),KitLand.wear_of(paths()))
	site.ray = Vector2(head_y()+60.0,float(LAYOUT.far.y)-8.0 if polished else -8.0)
	site.tufts = 3.0
	return site

func flora_seed() -> int:
	return SEED+9

## The worn ways: the arrival to the lip by the west brim, and to the
## cistern's gate; on the far isle, round the court to the rim out.
static func paths() -> Array:
	var s: Vector2 = LAYOUT.start
	return [[s,Vector2(44.0,-12.0),Vector2(37.0,-2.0),Vector2(31.0,8.0),Vector2(12.0,17.0),Vector2(-8.0,14.0),Vector2(-12.6,2.0)],[Vector2(12.0,17.0),Vector2(3.5,float(LAYOUT.cistern.rect.end.y)+1.0)],
		[Vector2(-21.0,-72.0),Vector2(-21.0,-96.0),Vector2(-6.0,-104.0),LAYOUT.rim_out as Vector2]]

func life_script() -> Script:
	return null if Underground.on() else KitLife

func warm() -> void:
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	CityStone.warm()
	Hang.warm()
	for k: String in CityStone.WEAR: CityStone.wear(k)
	Veil.polish = polished
	Veil.warm()
	_flame_material()
	_halo_material()
	lines()
	_computed()

func build_cost() -> int:
	return 900

var pieces := {}

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	Veil.polish = polished
	var root := Node3D.new()
	root.name = "WeirStair"
	into.add_child(root)
	pieces.clear()
	# The head and the rib.
	var poly := cliff_outline()
	var box := Rect2(poly[0],Vector2.ZERO)
	for p: Vector2 in poly: box = box.expand(p)
	var land := KitLand.island({"outline":poly,"seed":SEED+1,"ground":func(x: float, z: float) -> float: return cliff_ground(x,z),
		"top":head_y(),"depth":head_y()+8.0,"hang":true,"resample":[200.0,220,64],"cell":2.0,
		"cliffs":box.grow(2.0),"cliff_drop":0.55,"tone":KitLook.turf(SEED+1,KitLand.wear_of(paths()))})
	land.name = "HeadAndRib"
	root.add_child(land)
	_collide_sides(land)
	turf(land)
	pieces.head = land
	# The far isle.
	var fpoly: Array = far_outline()
	var fbox := Rect2(fpoly[0],Vector2.ZERO)
	for p: Vector2 in fpoly: fbox = fbox.expand(p)
	var far := KitLand.island({"outline":fpoly,"seed":SEED+4,"ground":func(x: float, z: float) -> float: return far_ground(x,z),
		"top":float(LAYOUT.far.y)+float(LAYOUT.far.shelf[2]),"depth":40.0,"hang":true,"resample":[200.0,160,48],"cell":2.0,
		"cliffs":fbox.grow(2.0),"cliff_drop":0.55,"tone":KitLook.turf(SEED+4,KitLand.wear_of(paths()))})
	far.name = "FarIsle"
	root.add_child(far)
	_collide_sides(far)
	turf(far)
	pieces.far = far
	# The stacks in the gap.
	var si := 0
	for st: Array in LAYOUT.stacks:
		var sy := float(st[3])
		var stack := KitLand.island({"outline":KitLand.blob(Vector2(float(st[0]),float(st[1])),float(st[2]),SEED+6+si),"seed":SEED+6+si,
			"ground":func(_x: float, _z: float) -> float: return sy,"top":sy,"depth":30.0,"hang":true,"resample":[24.0,30,20],"cell":1.0,"tone":KitLook.turf(SEED+6+si)})
		stack.name = "Stack%d" % si
		root.add_child(stack)
		_collide_sides(stack)
		turf(stack)
		si += 1
	_caps(root)
	# The stone: the weirs, the legs, the cistern, the court's walls, what
	# fell; one mesh in the city's basalt, one body of clean boxes.
	var m := CityStone.Mesher.new(CityStone.stone_colour(),0.9 if polished else 0.55)
	var body := StaticBody3D.new()
	body.name = "WeirStone"
	for k in range(1,count()+1): _weir(m,body,k)
	_cistern(m,body)
	_niche(m,body)
	# The gate plate under W1's water: a pale worn slab, runes round it.
	var pp := plate_point()
	var pd := plate_turn()
	m.solid(CityStone.box(Transform3D(pd,pp+Vector3.UP*0.02),Vector3(1.1,0.06,0.45),0.04),pp.y-0.2,1.25)
	_court(m,body)
	_stones(m,body)
	if polished and not ws_off.has("votive"): _votives(m,root)
	var mesh := MeshInstance3D.new()
	mesh.name = "Weirs"
	mesh.mesh = CityStone.mesh_of(m,"span")
	mesh.set_meta("triangles",m.triangles())
	root.add_child(mesh)
	root.add_child(body)
	pieces.stone = mesh
	# The maw's and the court heads' bodies (drawn in `live`: the model loads).
	var mw: Dictionary = LAYOUT.maw
	var mat: Vector3 = mw.at
	var mh := float(mw.h)
	solid_box(Rect2(mat.x-mh*0.42,mat.z-mh*0.3,mh*0.84,mh*0.62),terrace(1),head_y()+mh*0.12)
	for hd: Array in LAYOUT.heads:
		var hh := float(hd[2])
		var base := far_ground(float(hd[0]),float(hd[1]))
		solid_box(Rect2(float(hd[0])-hh*0.36,float(hd[1])-hh*0.3,hh*0.72,hh*0.6),base-0.5,base+hh*0.86)
	# The water: each pool, the court, the cistern; the spills' veils.
	for k in range(1,count()+1):
		var r := pool_rect(k)
		var f := floor_of(k)
		root.add_child(KitWater.still({"name":"Pool%d" % k,"level":water(k),"ground":func(_x: float, _z: float) -> float: return f,
			"rect":r,"inside":func(p: Vector2) -> bool: return wet_edge(k,p),"tea":0.95,"cell":0.5}))
	var c: Dictionary = LAYOUT.court
	var h := float(c.half)
	var cr := Rect2(-h,float(c.north),h*2.0,float(c.south)-float(c.north))
	root.add_child(KitWater.still({"name":"Court","level":float(c.water),"ground":func(x: float, z: float) -> float: return far_ground(x,z),
		"rect":cr,"inside":func(_p: Vector2) -> bool: return true,"tea":1.0,"cell":0.5}))
	var ci: Dictionary = LAYOUT.cistern
	var cir: Rect2 = ci.rect
	var cfl := head_y()+float(ci.floor)
	root.add_child(KitWater.still({"name":"Cistern","level":head_y()+float(ci.water),"ground":func(_x: float, _z: float) -> float: return cfl,
		"rect":cir.merge(Rect2(-float(ci.channel)*0.5,0.2,float(ci.channel),cir.position.y)),"inside":func(_p: Vector2) -> bool: return true,"tea":1.0,"cell":0.5}))
	var veils := Node3D.new()
	veils.name = "Veils"
	root.add_child(veils)
	for k in range(1,count()+1):
		var below := water(k+1) if k < count() else float(c.water)
		Veil.fall(veils,Vector3(spill_mid(k),water(k),front_z(k)),Vector3.FORWARD,spill_wide(k)*0.92,water(k)-below,1.4 if lost(k) else 2.0,SEED+k)
	# Moss beards on the tableros either side of each spill, where the
	# spray keeps them wet.
	var strands: Array = []
	var brng := RandomNumberGenerator.new()
	brng.seed = SEED+77
	for k in range(1,count()+1):
		for sd: float in [-1.0,1.0]:
			for q in 4:
				var x := spill_mid(k)+sd*(spill_wide(k)*0.5+0.3+q*0.5+brng.randf()*0.4)
				if absf(x) > outer(k)-0.4: continue
				strands.append([Vector3(x,front_top(k,x)-0.05,front_z(k)-0.02),Vector3.FORWARD,brng.randf_range(0.9,2.8),brng.randf_range(0.25,0.55)])
	Veil.beards(veils,strands,SEED+78)
	# The maw's spout into W1.
	Veil.fall(veils,Vector3(mat.x,water(1)+3.6,mat.z-mh*0.36),Vector3.FORWARD,2.2,3.6,2.6,SEED)
	# W6's crack: over its broken leg the sagged brim lets a sheet fall free
	# past the legs into the haze.
	var sl: Dictionary = LAYOUT.slump
	var sk := int(sl.weir)
	var cz := back_z(sk)-pitch_of(sk)*0.72
	Veil.fall(veils,Vector3(float(sl.side)*(outer(sk)+0.05),brim_top(sk,float(sl.side),cz)+0.05,cz),Vector3(float(sl.side),0.0,0.0),2.6,62.0,0.9,SEED+60)
	pieces.veils = veils
	if polished:
		if not ws_off.has("silt"): _silt(root)
		if not ws_off.has("dress"): _dress(root)
	root.set_meta("triangles",_triangles())
	built_ms = Time.get_ticks_msec()-began

## Polish: turf taken over the stone (LAYOUT `caps`): a thin sod on a
## brim's or a front wall's top, its edge ragged and hanging.
func _caps(root: Node3D) -> void:
	var i := 0
	for c: Array in LAYOUT.caps:
		var k := int(c[0])
		var kind := str(c[1])
		var a := float(c[2])
		var b := float(c[3])
		var r := Rect2()
		var s := 1.0
		if kind == "f":
			r = Rect2(a,front_z(k)+0.1,b-a,float(LAYOUT.weirs.wall)-0.2)
		else:
			s = 1.0 if kind == "e" else -1.0
			var x0 := inner(k)*0.5+0.1 if s > 0.0 else -outer(k)+0.1
			r = Rect2(x0,a,float(LAYOUT.weirs.brim)-0.2,b-a)
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED+500+i
		var ring: Array = []
		var n := 12
		for q in n:
			var t := float(q)/n
			var p := Vector2.ZERO
			if t < 0.25: p = r.position+Vector2(r.size.x*t*4.0,0.0)
			elif t < 0.5: p = Vector2(r.end.x,r.position.y+r.size.y*(t-0.25)*4.0)
			elif t < 0.75: p = Vector2(r.end.x-r.size.x*(t-0.5)*4.0,r.end.y)
			else: p = Vector2(r.position.x,r.end.y-r.size.y*(t-0.75)*4.0)
			ring.append(p+(r.get_center()-p).normalized()*rng.randf_range(0.0,0.5))
		var kk := k
		var ss := s
		var front := kind == "f"
		var ground := func(_x: float, z: float) -> float: return (brim(kk) if front else brim_top(kk,ss,z))+0.12
		var cap := KitLand.island({"outline":ring,"seed":SEED+500+i,"ground":ground,"top":brim(k)+0.12,"depth":0.7,"hang":true,
			"resample":[24.0,28,20],"tone":KitLook.turf(SEED+500+i),"cell":1.0})
		cap.name = "Sod%d" % i
		root.add_child(cap)
		turf(cap)
		i += 1

## Weir k: its floor, its side brims (a stub under a lost lip), its front
## wall (the notch or the broken stretch, runes on its north face), its legs.
func _weir(m: CityStone.Mesher, body: StaticBody3D, k: int) -> void:
	var wd: Dictionary = LAYOUT.weirs
	var o := outer(k)
	var half := inner(k)*0.5
	var wall := float(wd.wall)
	var z0 := front_z(k)
	var z1 := back_z(k)
	var base := base_of(k)
	var wet := 0.72
	# The floor: paving under the water.
	var pr := pool_rect(k)
	_slabs(m,body,pr,base-0.4,floor_of(k),k)
	# The side brims.
	for s: float in [-1.0,1.0]:
		var x0 := half if s > 0.0 else -o
		var stub_end := z1-float(LAYOUT.lost.stub) if lost(k-1) else z1
		# The stub (broken back), then the whole brim; each its own top.
		if stub_end < z1:
			_wall(m,body,Rect2(x0,stub_end,o-half,z1-stub_end),base,brim_top(k,s,z1-0.5),true,SEED+k*13+int(s),true)
		var sl: Dictionary = LAYOUT.slump
		if k == int(sl.weir) and s*float(sl.side) > 0.0:
			var mid := z1-pitch_of(k)*0.55
			_wall(m,body,Rect2(x0,mid,o-half,stub_end-mid),base,brim(k),false,SEED+k*13+7,false,0.7 if polished else 0.0)
			_wall(m,body,Rect2(x0,z0,o-half,mid-z0),base,brim_top(k,s,z0+0.5),false,SEED+k*13+8,true)
		elif polished and s > 0.0:
			# The east brim's slumped front end and worn dips: lower, broken
			# stretches between the chipped, mossy ones.
			var cur := z0
			var gi := 0
			for d: Array in east_dips(k):
				var za := z0+float(d[0])
				var zb := minf(za+float(d[1]),stub_end)
				if za > cur+0.05:
					_wall(m,body,Rect2(x0,cur,o-half,za-cur),base,brim(k),false,SEED+k*13+20+gi,false,0.7)
				_wall(m,body,Rect2(x0,za,o-half,zb-za),base,brim_top(k,s,za+0.1),true,SEED+k*13+9+gi,true)
				cur = zb
				gi += 1
			if stub_end > cur+0.05:
				_wall(m,body,Rect2(x0,cur,o-half,stub_end-cur),base,brim(k),false,SEED+k*13+int(s)+3,false,0.7)
		else:
			_wall(m,body,Rect2(x0,z0,o-half,stub_end-z0),base,brim(k),false,SEED+k*13+int(s)+3,false,(0.0 if (s < 0.0 and (lost(k-1) or lost(k))) else 0.3 if s < 0.0 else 0.7) if polished else 0.0)
	# The front wall: its foot the next tier's base (or the court's floor).
	var foot := base_of(k+1) if k < count() else base_of(k)
	_front(m,body,k,Rect2(-o,z0,o*2.0,wall),foot,wet)
	# The legs over the void.
	var i := 0
	for l: Array in legs(k):
		_leg(m,body,l[0],float(l[1]),base,float(l[2]),bool(l[3]),SEED+k*7+i)
		i += 1

## A wall of coursed blocks over `r` (x, z) from `y0` to `y1`, its blocks
## running along its long side; `broken`: the top course knocked about
## (blocks missing, chipped, tilted). Its collision one box (two for a
## broken top: the stub kept clean, the scatter drawn only). `pale`: fresh
## breaks.
func _wall(m: CityStone.Mesher, body: StaticBody3D, r: Rect2, y0: float, y1: float, broken: bool, seed_value: int, pale := false, chip := 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var along_x := r.size.x >= r.size.y
	var length := r.size.x if along_x else r.size.y
	var thick := r.size.y if along_x else r.size.x
	var rows := maxi(int(ceil((y1-y0)/SO-0.05)),1)
	for row in rows:
		var top := y1-row*SO
		var bot := maxf(top-SO,y0)
		if top-bot < 0.1: continue
		var u := 0.0
		while u < length-0.05:
			var bl := minf(rng.randf_range(1.6,3.4),length-u)
			if length-u-bl < 0.8: bl = length-u
			var inset := rng.randf_range(0.0,0.05)
			var c := Vector3(r.position.x+(u+bl*0.5 if along_x else thick*0.5),(top+bot)*0.5,r.position.y+(thick*0.5 if along_x else u+bl*0.5))
			var hs := Vector3((bl*0.5 if along_x else thick*0.5)-0.03-inset,(top-bot)*0.5-0.02,(thick*0.5 if along_x else bl*0.5)-0.03-inset)
			var b := Basis.IDENTITY
			var tone := rng.randf_range(0.86,1.06)*(1.0 if row > 0 else 0.92)
			if chip > 0.0 and row == 0 and not broken:
				# Polish: a chipped rim: a block now and then knocked down,
				# tilted or missing (the walked west brims only a hand).
				var roll := rng.randf()
				if chip > 0.5 and roll < 0.16:
					u += bl
					continue
				if roll < chip*0.6:
					var low := rng.randf_range(0.7,0.93) if chip > 0.5 else rng.randf_range(0.9,0.97)
					b = Basis.from_euler(Vector3(rng.randf_range(-0.05,0.05)*chip,rng.randf_range(-0.12,0.12),rng.randf_range(-0.06,0.06)*chip))
					hs.y *= low
					c.y = bot+hs.y
			if broken and row == 0:
				if rng.randf() < 0.3:
					u += bl
					continue
				b = Basis.from_euler(Vector3(rng.randf_range(-0.06,0.06),rng.randf_range(-0.1,0.1),rng.randf_range(-0.06,0.06)))
				hs.y *= rng.randf_range(0.55,0.95)
				c.y = bot+hs.y
			m.solid(CityStone.box(Transform3D(b,c),hs,0.07),y0,tone)
			u += bl
	_shape(body,r,y0,y1-(0.15 if broken else 0.2 if chip >= 0.5 else 0.0))

## The front wall of weir k: whole blocks where it stands to the brim, the
## notch (or the broken stretch) cut down; runes along its north face, its
## lip blocks wet-dark.
func _front(m: CityStone.Mesher, body: StaticBody3D, k: int, r: Rect2, foot: float, wet: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+k*31
	var x := r.position.x
	var b := brim(k)
	while x < r.end.x-0.05:
		var bl := minf(rng.randf_range(1.8,3.2),r.end.x-x)
		if r.end.x-x-bl < 0.8: bl = r.end.x-x
		var mid := x+bl*0.5
		# This column's top (the notch, the break), sampled across it.
		var top := minf(minf(front_top(k,x+0.15),front_top(k,mid)),front_top(k,x+bl-0.15))
		var y := foot
		var row := 0
		while y < top-0.05:
			var h := minf(SO,top-y)
			if h < 0.35 and row > 0:
				break
			var c := Vector3(mid,y+h*0.5,r.get_center().y)
			var hs := Vector3(bl*0.5-0.03,h*0.5-0.02,r.size.y*0.5-0.02)
			var lip := y+h >= top-0.05
			var bas := Basis.IDENTITY
			if lost(k) and lip and top < b-0.5:
				bas = Basis.from_euler(Vector3(rng.randf_range(-0.08,0.08),0.0,rng.randf_range(-0.08,0.08)))
			m.solid(CityStone.box(Transform3D(bas,c),hs,0.06 if not lip else 0.12),foot,(wet if y+h > floor_of(k)-0.2 else rng.randf_range(0.82,1.0)))
			y += h
			row += 1
		_shape(body,Rect2(x,r.position.y,bl,r.size.y),foot,top)
		x += bl
	# The day count: a band of runes along its north face, under the lip,
	# on the stretches that stand to the brim.
	var z := r.position.y
	var span := Vector2(-outer(k)+0.6,outer(k)-0.6)
	var cut := Vector2(spill_span(k).x-(2.6 if lost(k) else 0.3),spill_span(k).y+(2.6 if lost(k) else 0.3))
	for seg: Vector2 in [Vector2(span.x,cut.x),Vector2(cut.y,span.y)]:
		if seg.y-seg.x < 1.5: continue
		m.runes(Vector3(seg.y,b-1.5,z),Vector3(seg.x,b-1.5,z),Vector3.UP,Vector3.FORWARD,float(k*7+int(seg.x)))

## Weir k's legs: [rect (x, z) under the tank, foot, batter, broken].
static func legs(k: int) -> Array:
	var out: Array = []
	var zc := (back_z(k)+front_z(k))*0.5
	var o := outer(k)
	for l: Array in LAYOUT.legs.each:
		if int(l[0]) != k: continue
		var w := float(l[2])
		var x := clampf(float(l[1]),-o+w*0.5,o-w*0.5)
		out.append([Rect2(x-w*0.5,zc-float(l[3])*0.5,w,float(l[3])),float(l[4]),float(l[5]),bool(l[6])])
	return out

## A leg under a tank, down into the haze: courses of big blocks, battered
## (each course `batter` m wider a m down, set back in steps every third),
## the joints staggered; `broken`: snapped off short, its last courses
## knocked askew and half gone.
func _leg(m: CityStone.Mesher, body: StaticBody3D, r: Rect2, foot: float, top: float, batter: float, broken: bool, seed_value: int) -> void:
	if polished and not ws_off.has("legs"):
		_leg_tapered(m,body,r,foot,top,batter,broken,seed_value)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var y := top
	var row := 0
	var course := 2.0*SO
	var rows := int(ceil((top-foot)/course))
	while y > foot+0.1:
		var bot := maxf(y-course,foot)
		var rr := r.grow(minf(floorf((top-y)/(3.0*course))*3.0*course*batter,3.0))
		# A cornice band under the tank.
		if row == 0: rr = r.grow(0.35)
		if broken and row >= rows-2:
			# The snapped end: blocks askew, one side gone.
			var keep := rr.grow_individual(0.0,0.0,-rr.size.x*rng.randf_range(0.2,0.5),0.0) if row == rows-1 else rr
			var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.12,0.12),rng.randf_range(-0.2,0.2),rng.randf_range(-0.15,0.15)))
			m.solid(CityStone.box(Transform3D(tilt,Vector3(keep.get_center().x,(y+bot)*0.5,keep.get_center().y)),Vector3(keep.size.x*0.5-0.1,(y-bot)*0.5*rng.randf_range(0.6,0.9),keep.size.y*0.5-0.1),0.3),foot,1.15)
			y = bot
			row += 1
			continue
		var split := rr.position.x+rr.size.x*(0.45 if row % 2 == 0 else 0.6)
		for half: Rect2 in [Rect2(rr.position.x,rr.position.y,split-rr.position.x,rr.size.y),Rect2(split,rr.position.y,rr.end.x-split,rr.size.y)]:
			var c := Vector3(half.get_center().x,(y+bot)*0.5,half.get_center().y)
			var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.012,0.012),rng.randf_range(-0.02,0.02),rng.randf_range(-0.012,0.012)))
			c += Vector3(rng.randf_range(-0.08,0.08),0.0,rng.randf_range(-0.08,0.08))
			m.solid(CityStone.box(Transform3D(tilt,c),Vector3(half.size.x*0.5-0.04,(y-bot)*0.5-0.03,half.size.y*0.5-0.04),0.18),foot,rng.randf_range(0.78,1.0))
		y = bot
		row += 1
	_shape(body,r,foot+(course*2.0 if broken else 0.0),top)


# --- Polish: the legs, battered and weathered ---------------------------------------------

## Course rows of a leg are two SET_OFFs high; every third a ledge.
const LEDGE := 0.14
const BATTER_GAIN := 2.2
const BATTER_CAP := 3.6

## A leg's section (x, z) at `depth` m under its tank, in course `row`:
## battered out (talud), a ledge every third course, the whole leaning
## (`lean` x, z m a m down) and each course a hand off its neighbours.
static func leg_rect(r: Rect2, depth: float, batter: float, row: int, lean: Vector2, wobble: float) -> Rect2:
	var g := minf(depth*batter*BATTER_GAIN,BATTER_CAP)+float(row/3)*LEDGE
	var out := r.grow(g+wobble)
	out.position += lean*depth
	return out

static func leg_lean(seed_value: int) -> Vector2:
	var a := fmod(absf(sin(float(seed_value)*12.9898)*43758.5453),1.0)
	var b := fmod(absf(sin(float(seed_value)*78.233)*12345.678),1.0)
	return Vector2((a-0.5)*0.03,(b-0.5)*0.024)

static func leg_wobble(seed_value: int, row: int) -> float:
	return 0.09*sin(float(seed_value)*3.1+float(row)*2.3)

## A battered block: its top section `rt` at `yt`, its foot `rb` at `yb`
## (wider below), the four edges chamfered `c`.
func _frustum(m: CityStone.Mesher, rt: Rect2, rb: Rect2, yt: float, yb: float, c: float, foot: float, tone: float) -> void:
	var h := yt-yb
	var planes: Array = [Plane(Vector3.UP,yt),Plane(Vector3.DOWN,-yb)]
	# +x, -x, +z, -z faces, each leaning out toward its foot.
	var faces: Array = [[Vector3.RIGHT,rt.end.x,rb.end.x],[Vector3.LEFT,-rt.position.x,-rb.position.x],[Vector3.BACK,rt.end.y,rb.end.y],[Vector3.FORWARD,-rt.position.y,-rb.position.y]]
	for f: Array in faces:
		var d: Vector3 = f[0]
		var nt := Vector3(d.x*h,0.0,d.z*h)+Vector3.UP*(float(f[2])-float(f[1]))
		nt = nt.normalized()
		var pt := Vector3(d.x*float(f[1]),yt,d.z*float(f[1]))
		planes.append(Plane(nt,nt.dot(pt)))
	# The corners, chamfered (from the section's middle height).
	var mx := Rect2(rt.position.lerp(rb.position,0.5),rt.size.lerp(rb.size,0.5))
	for sx: float in [-1.0,1.0]:
		for sz: float in [-1.0,1.0]:
			var n := Vector3(sx,0.0,sz).normalized()
			var corner := Vector3(mx.end.x if sx > 0.0 else mx.position.x,0.0,mx.end.y if sz > 0.0 else mx.position.y)
			planes.append(Plane(n,n.dot(corner)-c*0.7071))
	m.solid(planes,foot,tone)

func _leg_tapered(m: CityStone.Mesher, body: StaticBody3D, r: Rect2, foot: float, top: float, batter: float, broken: bool, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lean := leg_lean(seed_value)
	var course := 2.0*SO
	var rows := int(ceil((top-foot)/course))
	var y := top
	var row := 0
	while y > foot+0.1:
		var bot := maxf(y-course,foot)
		var rt := leg_rect(r,top-y,batter,row,lean,leg_wobble(seed_value,row))
		var rb := leg_rect(r,top-bot,batter,row,lean,leg_wobble(seed_value,row))
		if row == 0:
			# The cornice band under the tank.
			rt = r.grow(0.4)
			rb = r.grow(0.3)
		var tone := rng.randf_range(0.74,0.98)
		if broken and row >= rows-2:
			# The snapped end: blocks askew, one side gone.
			var keep := rb.grow_individual(0.0,0.0,-rb.size.x*rng.randf_range(0.2,0.5),0.0) if row == rows-1 else rb
			var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.12,0.12),rng.randf_range(-0.2,0.2),rng.randf_range(-0.15,0.15)))
			m.solid(CityStone.box(Transform3D(tilt,Vector3(keep.get_center().x,(y+bot)*0.5,keep.get_center().y)),Vector3(keep.size.x*0.5-0.1,(y-bot)*0.5*rng.randf_range(0.6,0.9),keep.size.y*0.5-0.1),0.3),foot,1.15)
			y = bot
			row += 1
			continue
		_frustum(m,rt,rb,y,bot,0.22,foot,tone)
		y = bot
		row += 1
	if broken:
		# The snapped end's shards: broken-off blocks hanging askew from it.
		var c := Vector2(r.get_center().x+lean.x*(top-foot),r.get_center().y+lean.y*(top-foot))
		for i in 4:
			var ang := rng.randf()*TAU
			var off := Vector3(cos(ang)*r.size.x*0.3,rng.randf_range(-1.1,0.2),sin(ang)*r.size.y*0.3)
			var hs := Vector3(rng.randf_range(0.3,0.55),rng.randf_range(0.7,1.3),rng.randf_range(0.3,0.5))
			var tb := Basis.from_euler(Vector3(rng.randf_range(-0.5,0.5),rng.randf_range(-1.0,1.0),rng.randf_range(-0.5,0.5)))
			m.solid(CityStone.box(Transform3D(tb,Vector3(c.x,foot,c.y)+off),hs,0.12),foot-3.0,1.2)
	_shape(body,r,foot+(course*2.0 if broken else 0.0),top)


# --- Polish: growth, silt, votives ------------------------------------------------------

## The hanging growth of the whole stair (one mesh in the growth material):
## ivy fringes off the tanks' faces and brims, roots under the tanks and down
## the cliffs into the abyss, the water's stains and algae down the faces,
## moss cushions on the brims.
func _dress(root: Node3D) -> void:
	var p := Hang.probe(SEED+900)
	var rng := p.rng
	var course := 2.0*SO
	for k in range(1,count()+1):
		var o := outer(k)
		var zc := (back_z(k)+front_z(k))*0.5
		var base := base_of(k)
		var top := brim(k)
		Hang.block(p,Vector3(0.0,(base+top)*0.5,zc),Vector3(o,(top-base)*0.5,pitch_of(k)*0.5))
		var i := 0
		for l: Array in legs(k):
			var r: Rect2 = l[0]
			var foot := float(l[1])
			var batter := float(l[2])
			var sd := SEED+k*7+i
			var lean := leg_lean(sd)
			var rows := int(ceil((base-foot)/course))
			for row in range(mini(rows,10)):
				var rr := r.grow(0.4) if row == 0 else leg_rect(r,float(row+1)*course,batter,row,lean,leg_wobble(sd,row))
				Hang.block(p,Vector3(rr.get_center().x,base-(row+0.5)*course,rr.get_center().y),Vector3(rr.size.x*0.5,course*0.5,rr.size.y*0.5))
			i += 1
	for k in range(1,count()+1):
		var o := outer(k)
		var base := base_of(k)
		var half := inner(k)*0.5
		# The tank's faces: fringes off the brims, stains and algae below them.
		for sd: float in [-1.0,1.0]:
			var clumps := 2 if sd > 0.0 else 1
			for c in clumps:
				var z := lerpf(front_z(k)+3.0,back_z(k)-2.0,rng.randf())
				var y := brim_top(k,sd,z)-0.25
				Hang.fringe(p,Vector3(sd*(o+0.1),y,z),Vector3(0.0,0.0,1.0),2,0.45,rng.randf_range(1.6,3.0),Vector3(sd,0.0,0.0),2.5)
			for c in 3:
				var z := lerpf(front_z(k)+2.0,back_z(k)-1.5,rng.randf())
				Hang.stain(p,Vector3(sd*o,brim_top(k,sd,z)-0.05,z),rng.randf_range(1.4,brim(k)-base-0.1),rng.randf_range(0.5,1.3),Vector3(sd,0.0,0.0),Hang.STAIN if c%2 == 0 else Hang.ALGAE)
		# The spill's face: fringes and algae streaks beside the veil.
		var sm := spill_mid(k)
		var sw := spill_wide(k)*0.5
		var foot := base_of(k+1) if k < count() else base_of(k)
		for sd: float in [-1.0,1.0]:
			var x := sm+sd*(sw+1.6+rng.randf()*1.6)
			if absf(x) > o-1.5: continue
			var ft := front_top(k,x)
			Hang.fringe(p,Vector3(x,ft-0.2,front_z(k)-0.1),Vector3(1.0,0.0,0.0),2,0.45,rng.randf_range(1.5,2.8),Vector3(0.0,0.0,-1.0),2.5)
			for q in 2:
				var xx := sm+sd*(sw+0.5+q*1.1+rng.randf()*0.5)
				if absf(xx) > o-0.8: continue
				Hang.stain(p,Vector3(xx,front_top(k,xx)-0.05,front_z(k)-0.02),maxf(front_top(k,xx)-foot-0.2,0.5),rng.randf_range(0.6,1.2),Vector3(0.0,0.0,-1.0),Hang.ALGAE)
		# Moss cushions on the brim and wall tops.
		for c in 5:
			var sd := 1.0 if c < 3 else -1.0
			var z := lerpf(front_z(k)+1.0,back_z(k)-1.0,rng.randf())
			Hang.cushion(p,Vector3(sd*(half+float(LAYOUT.weirs.brim)*rng.randf_range(0.2,0.8)),brim_top(k,sd,z)+0.01,z),rng.randf_range(0.35,0.75))
		for c in 3:
			var x := rng.randf_range(-o+1.0,o-1.0)
			if absf(x-sm) < sw+2.4: continue
			Hang.cushion(p,Vector3(x,front_top(k,x)+0.01,front_z(k)+float(LAYOUT.weirs.wall)*0.5),rng.randf_range(0.3,0.65))
		# Under a tank on legs: roots hanging from its underside.
		if on_legs(k):
			for c in 3:
				var sd := 1.0 if c != 1 else -1.0
				var z := lerpf(front_z(k)+2.0,back_z(k)-2.0,rng.randf())
				Hang.root(p,Vector3(sd*(o-rng.randf_range(0.3,1.2)),base-0.05,z),rng.randf_range(7.0,16.0),rng.randf_range(0.07,0.14),Vector3(sd,0.0,0.0))
	# The legs: ivy from the cornice, roots, and the water's stains in bands
	# between the ledges.
	for k: int in LAYOUT.legs.weirs:
		var base := base_of(k)
		var i := 0
		for l: Array in legs(k):
			var r: Rect2 = l[0]
			var foot := float(l[1])
			var batter := float(l[2])
			var broken := bool(l[3])
			var sd := SEED+k*7+i
			var lean := leg_lean(sd)
			var rows := int(ceil((base-foot)/course))
			var faces: Array = [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD]
			for f: Vector3 in faces:
				var rt := leg_rect(r,course,batter,1,lean,leg_wobble(sd,1))
				var x_face := absf(f.x) > 0.5
				var along := Vector3(0.0,0.0,1.0) if x_face else Vector3(1.0,0.0,0.0)
				var span := (rt.size.y if x_face else rt.size.x)*0.5
				var centre := Vector3(rt.get_center().x,0.0,rt.get_center().y)
				var face_pt := centre+Vector3(f.x*rt.size.x*0.5,0.0,f.z*rt.size.y*0.5)
				if rng.randf() < 0.55:
					var start := face_pt+f*0.12+along*rng.randf_range(-span+0.5,span-0.5)
					start.y = base-course-0.05
					Hang.fringe(p,start,along,2,0.45,rng.randf_range(4.0,8.0),f,2.9)
				# Stains in bands of three courses (a ledge between each).
				for band in mini(int(ceil(float(rows)/3.0)),4):
					var row0 := maxi(band*3,1)
					var d0 := float(row0)*course
					var len := minf(float(3-(row0%3))*course,(base-foot)-d0-course)
					if len < 1.5: break
					for q in 2:
						if rng.randf() < 0.55: continue
						var a0 := leg_rect(r,d0,batter,row0,lean,leg_wobble(sd,row0))
						var a1 := leg_rect(r,d0+len,batter,row0,lean,leg_wobble(sd,row0))
						var lat := rng.randf_range(-0.7,0.7)*span
						var pt := Vector3(a0.get_center().x,0.0,a0.get_center().y)+Vector3(f.x*a0.size.x*0.5,0.0,f.z*a0.size.y*0.5)+along*lat
						pt.y = base-d0
						var grown := (a1.size.x-a0.size.x)*0.5+(a1.get_center().x-a0.get_center().x)*f.x if x_face else (a1.size.y-a0.size.y)*0.5+(a1.get_center().y-a0.get_center().y)*f.z
						Hang.stain(p,pt,len,rng.randf_range(1.2,2.4),f,Hang.STAIN if (band+q)%2 == 0 else Hang.ALGAE,grown/len)
			for c in 3:
				var ang := rng.randf()*TAU
				var cx := r.get_center().x+cos(ang)*r.size.x*0.45
				var cz := r.get_center().y+sin(ang)*r.size.y*0.45
				Hang.root(p,Vector3(cx,base-course-0.2,cz),rng.randf_range(10.0,24.0),rng.randf_range(0.08,0.16),Vector3(cos(ang),0.0,sin(ang)))
			if broken:
				# The snapped leg's end: roots hanging off it.
				var c := Vector3(r.get_center().x,foot+0.4,r.get_center().y)
				for q in 4:
					Hang.root(p,c+Vector3(rng.randf_range(-1.2,1.2),0.0,rng.randf_range(-1.2,1.2)),rng.randf_range(5.0,12.0),0.12,Vector3(1.0,0.0,0.0),0.95)
			i += 1
	# The cliffs' lips: roots down into the abyss, a strand of ivy now and then.
	_lip_growth(p,"head",cliff_outline(),func(x: float, z: float) -> float: return cliff_ground(x,z))
	_lip_growth(p,"far",far_outline(),func(x: float, z: float) -> float: return far_ground(x,z))
	var mesh := Hang.mesh(p,"Hang")
	if mesh != null:
		root.add_child(mesh)
		pieces.hang = mesh
	var roots := Hang.roots(p,SEED+901)
	if roots != null:
		root.add_child(roots)
		pieces.roots = roots

## Roots (and some ivy) hung every few metres off a polygon's lip.
func _lip_growth(p: Hang.Probe, which: String, outline: Array, ground: Callable) -> void:
	var poly := _poly_of(which)
	var rng := p.rng
	var rim: Vector2 = LAYOUT.rim_in
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		var len := a.distance_to(b)
		if len < 0.5: continue
		var along := (b-a)/len
		var n := Vector2(along.y,-along.x)
		if Geometry2D.is_point_in_polygon((a+b)*0.5+n*0.6,poly): n = -n
		var t := rng.randf_range(0.5,3.0)
		while t < len:
			var q := a+along*t
			if q.distance_to(rim) > 5.0:
				var y := float(ground.call(q.x-n.x*0.5,q.y-n.y*0.5))
				var out := Vector3(n.x,0.0,n.y)
				var at := Vector3(q.x+n.x*0.8,y-0.7,q.y+n.y*0.8)
				Hang.root(p,at,rng.randf_range(6.0,22.0),rng.randf_range(0.07,0.15),out)
				if rng.randf() < 0.16:
					Hang.fringe(p,at+Vector3(0.0,0.4,0.0),Vector3(along.x,0.0,along.y),2,0.45,rng.randf_range(2.5,5.0),out,2.8,true)
			t += rng.randf_range(4.5,9.0)

## Silt and reeds: a low turf mound in each pool's two quiet corners (off the
## surge's line), the water lapping it.
func _silt(root: Node3D) -> void:
	var r := float(LAYOUT.silt)
	for k in range(1,count()+1):
		var half := inner(k)*0.5
		var z0 := front_z(k)+float(LAYOUT.weirs.wall)
		var spots: Array = [Vector2(side(k)*(half-r*1.12-0.15),back_z(k)-r*1.12-0.15),Vector2(-side(k)*(half-r*1.12-0.15),z0+r*1.12+0.15)]
		var j := 0
		for c: Vector2 in spots:
			if k == count() and j == 1:
				j += 1
				continue
			var fl := floor_of(k)
			var top := water(k)+0.3
			var cc := c
			var rr := r*(0.8 if j == 1 else 1.0)
			var ground := func(x: float, z: float) -> float:
				var d := Vector2(x-cc.x,z-cc.y).length()/rr
				return lerpf(fl,top,smoothstep(1.1,0.1,d))+0.05*sin(x*2.3+z*1.7)
			var mound := KitLand.island({"outline":KitLand.blob(c,rr,SEED+300+k*3+j),"seed":SEED+300+k*3+j,"ground":ground,"top":top,"depth":1.0,"hang":true,
				"resample":[24.0,28,20],"cell":1.0,"tone":KitLook.turf(SEED+300+k*3+j)})
			mound.name = "Silt%d_%d" % [k,j]
			root.add_child(mound)
			turf(mound)
			j += 1

## Warm votives on the east brims: a bowl of the city's stone and a small
## dim flame, no light (the three cressets and the niche's are the stair's
## lamps).
func _votives(m: CityStone.Mesher, root: Node3D) -> void:
	var flames := Node3D.new()
	flames.name = "Votives"
	root.add_child(flames)
	for v: Array in LAYOUT.votives:
		var k := int(v[0])
		var sz := float(v[2])
		var z := back_z(k)+float(v[1])
		var x := inner(k)*0.5+float(LAYOUT.weirs.brim)*0.5
		var y := brim_top(k,1.0,z)
		m.solid(CityStone.drum(Transform3D(Basis.IDENTITY,Vector3(x,y,z)),8,0.4*sz,0.3*sz,0.5*sz,0.06),y,1.0)
		var q := MeshInstance3D.new()
		q.name = "Flame%d" % k
		var quad := QuadMesh.new()
		quad.size = Vector2(0.9,1.5)*sz
		quad.material = _flame_material()
		q.mesh = quad
		q.position = Vector3(x,y+0.5*sz+0.55*sz,z)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.add_child(q)
		var halo := MeshInstance3D.new()
		halo.name = "Halo%d" % k
		var hq := QuadMesh.new()
		hq.size = Vector2.ONE*3.4*sz
		hq.material = _halo_material()
		halo.mesh = hq
		halo.position = q.position
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.add_child(halo)

static var _flame: StandardMaterial3D = null
static var _halo: StandardMaterial3D = null

static func _glow_tex(inner: float, hard: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0,maxf(inner,0.01),1.0])
	g.colors = PackedColorArray([Color(1.0,0.9,0.6,1.0),Color(1.0,0.62,0.25,hard),Color(1.0,0.45,0.15,0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(1.0,0.5)
	tex.width = 64
	tex.height = 64
	return tex

static func _flame_material() -> StandardMaterial3D:
	if _flame == null:
		_flame = StandardMaterial3D.new()
		_flame.albedo_texture = _glow_tex(0.22,0.8)
		_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flame.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flame.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_flame.billboard_keep_scale = true
		_flame.albedo_color = Color(1.0,0.8,0.55,0.9)
	return _flame

static func _halo_material() -> StandardMaterial3D:
	if _halo == null:
		_halo = StandardMaterial3D.new()
		_halo.albedo_texture = _glow_tex(0.0,0.35)
		_halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_halo.billboard_keep_scale = true
		_halo.albedo_color = Color(1.0,0.7,0.4,0.28)
	return _halo

## A pool's floor: paving slabs under the water.
func _slabs(m: CityStone.Mesher, body: StaticBody3D, r: Rect2, y0: float, y1: float, k: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+k*5
	var step := 3.0
	var z := r.position.y
	while z < r.end.y-0.05:
		var dz := minf(step,r.end.y-z)
		var x := r.position.x
		while x < r.end.x-0.05:
			var dx := minf(step*rng.randf_range(0.8,1.3),r.end.x-x)
			if r.end.x-x-dx < 0.8: dx = r.end.x-x
			var sink := rng.randf_range(0.0,0.06)
			m.solid(CityStone.box(Transform3D(Basis.IDENTITY,Vector3(x+dx*0.5,(y0+y1)*0.5-sink,z+dz*0.5)),Vector3(dx*0.5-0.03,(y1-y0)*0.5,dz*0.5-0.03),0.05),y0,rng.randf_range(0.6,0.75))
			x += dx
		z += dz
	_shape(body,r,y0,y1)

## The cistern on the head shelf: its kerb, the channel's cheeks to the maw,
## the gate's jambs and lintel over the channel (STAND-IN for city_gate).
func _cistern(m: CityStone.Mesher, body: StaticBody3D) -> void:
	var ci: Dictionary = LAYOUT.cistern
	var r: Rect2 = ci.rect
	var y := head_y()
	var fl := y+float(ci.floor)
	var kerb := 0.9
	var t := 1.0
	var ch := float(ci.channel)*0.5
	# Its kerb: east, west, north; the south wall broken by the channel's mouth.
	_wall(m,body,Rect2(r.position.x-t,r.position.y,t,r.size.y),fl,y+kerb*0.5,false,SEED+201)
	_wall(m,body,Rect2(r.end.x,r.position.y,t,r.size.y),fl,y+kerb*0.5,false,SEED+202)
	_wall(m,body,Rect2(r.position.x-t,r.end.y,r.size.x+2.0*t,t),fl,y+kerb,false,SEED+203)
	_wall(m,body,Rect2(r.position.x-t,r.position.y-t,r.size.x*0.5+t-ch,t),fl,y+kerb*0.5,false,SEED+204)
	_wall(m,body,Rect2(ch,r.position.y-t,r.size.x*0.5-ch+t,t),fl,y+kerb*0.5,false,SEED+205)
	# The channel's cheeks from the cistern to the lip.
	_wall(m,body,Rect2(-ch-0.8,0.3,0.8,r.position.y-t-0.3),fl,y+0.3,false,SEED+206)
	_wall(m,body,Rect2(ch,0.3,0.8,r.position.y-t-0.3),fl,y+0.3,false,SEED+207)
	_slabs(m,body,r.merge(Rect2(-ch,0.3,ch*2.0,r.position.y)),fl-0.6,fl,30)
	# The gate: two jambs and a lintel over the channel's mouth.
	var gz := float(ci.gate_z)-t*0.5
	for s: float in [-1.0,1.0]:
		var c := Vector3(s*(ch+0.5),y+1.4,gz)
		m.solid(CityStone.box(Transform3D(Basis.IDENTITY,c),Vector3(0.5,2.4,0.55),0.08),fl,0.9)
		_shape(body,Rect2(c.x-0.5,gz-0.55,1.0,1.1),fl,y+3.8)
	m.solid(CityStone.box(Transform3D(Basis.IDENTITY,Vector3(0.0,y+4.15,gz)),Vector3(ch+1.2,0.4,0.62),0.1),fl,0.95)
	m.runes(Vector3(ch+0.9,y+3.8,gz+0.63),Vector3(-ch-0.9,y+3.8,gz+0.63),Vector3.UP,Vector3.BACK,77.0,0.6)

## The gate plate's middle (the head sluice's plate, on W1's floor) and its turn.
static func plate_point() -> Vector3:
	var l: Array = lines()[0]
	var a: Vector3 = l[0]
	var b: Vector3 = l[1]
	var d := Vector3(b.x-a.x,0.0,b.z-a.z).normalized()
	return a+d*float(LAYOUT.surge.plate)

static func plate_turn() -> Basis:
	var l: Array = lines()[0]
	var a: Vector3 = l[0]
	var b: Vector3 = l[1]
	return Basis.looking_at(Vector3(b.x-a.x,0.0,b.z-a.z).normalized(),Vector3.UP)

## The niche cut in the head's cliff over W1's west terrace, its lamp's
## (jambs, lintel, a back wall).
func _niche(m: CityStone.Mesher, body: StaticBody3D) -> void:
	var nc: Array = LAYOUT.lamps.niche
	var x := float(nc[0])
	var z := float(nc[1])
	var y := terrace(1)
	for sd: float in [-1.0,1.0]:
		var c := Vector3(x+sd*1.5,y+1.8,z+0.2)
		m.solid(CityStone.box(Transform3D(Basis.IDENTITY,c),Vector3(0.35,1.8,0.6),0.06),y,0.85)
		_shape(body,Rect2(c.x-0.35,c.z-0.6,0.7,1.2),y,y+3.6)
	m.solid(CityStone.box(Transform3D(Basis.IDENTITY,Vector3(x,y+3.85,z+0.2)),Vector3(1.95,0.3,0.7),0.08),y,0.9)
	m.solid(CityStone.box(Transform3D(Basis.IDENTITY,Vector3(x,y+1.9,z+0.75)),Vector3(1.2,1.9,0.15),0.0),y,0.6)
	m.runes(Vector3(x+1.7,y+3.6,z+0.91),Vector3(x-1.7,y+3.6,z+0.91),Vector3.UP,Vector3.FORWARD,91.0,0.5)

## Where the niche's lamp stands.
static func niche_lamp() -> Vector3:
	var nc: Array = LAYOUT.lamps.niche
	return Vector3(float(nc[0]),terrace(1),float(nc[1])-0.2)

## The drowned court's walls (east and west, a hand over the terrace) and
## the stair's cheeks.
func _court(m: CityStone.Mesher, body: StaticBody3D) -> void:
	var c: Dictionary = LAYOUT.court
	var h := float(c.half)
	var z0 := float(c.north)
	var z1 := float(c.south)
	var y := float(LAYOUT.far.y)
	for s: float in [-1.0,1.0]:
		var x0 := h if s > 0.0 else -h-1.4
		_wall(m,body,Rect2(x0,z0,1.4,z1-z0),float(c.deep)-0.4,y+0.5,s > 0.0,SEED+300+int(s))

## Polish: the city's stone sunk in the land and tumbled into the pools.
func _stones(m: CityStone.Mesher, body: StaticBody3D) -> void:
	var all: Array = LAYOUT.stones.duplicate()
	if polished: all.append_array(LAYOUT.stones2)
	for st: Array in all:
		var x := float(st[1])
		var z := float(st[2])
		var y := on(Vector2(x,z)).y
		if st[0] == "block":
			var size: Vector3 = st[3]
			var b := Basis.from_euler(Vector3(deg_to_rad(float(st[5])),deg_to_rad(float(st[4])),deg_to_rad(float(st[6]))),EULER_ORDER_YXZ)
			var xf := Transform3D(b,Vector3(x,y+size.y*0.5-float(st[7]),z))
			m.solid(CityStone.box(xf,size*0.5,clampf(minf(size.x,minf(size.y,size.z))*0.1,0.05,0.25)),y-0.4,0.9+0.15*fmod(absf(x*0.37+z*0.11),1.0))
			_oshape(body,xf,size)
		else:
			var r := float(st[3])
			var length := float(st[4])
			var b := Basis(Vector3.UP,deg_to_rad(float(st[5])))*Basis(Vector3.BACK,PI*0.5)
			var xf := Transform3D(b,Vector3(x,y+r-float(st[6]),z))
			m.solid(CityStone.drum(xf*Transform3D(Basis.IDENTITY,Vector3(0.0,-length*0.5,0.0)),12,r,r,length,0.12),y-0.4,0.95)
			var c := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = r
			cyl.height = length
			c.shape = cyl
			c.transform = xf
			body.add_child(c)
	for t: Array in LAYOUT.tumbled:
		var k := int(t[0])
		var size: Vector3 = t[3]
		var b := Basis.from_euler(Vector3(0.0,deg_to_rad(float(t[4])),deg_to_rad(float(t[5]))))
		var xf := Transform3D(b,Vector3(float(t[1]),floor_of(k)+size.y*0.35,float(t[2])))
		m.solid(CityStone.box(xf,size*0.5,0.1),floor_of(k)-0.2,0.8)
		_oshape(body,xf,size)

static func _shape(body: StaticBody3D, r: Rect2, y0: float, y1: float) -> void:
	if y1-y0 < 0.05: return
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(r.size.x,y1-y0,r.size.y)
	c.shape = s
	c.position = Vector3(r.get_center().x,(y0+y1)*0.5,r.get_center().y)
	body.add_child(c)

static func _oshape(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	c.transform = xf
	body.add_child(c)

## An island's hanging sides collided as drawn (the bodies climb them).
static func _collide_sides(land: Node3D) -> void:
	var mesh := land.get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null or mesh.mesh == null: return
	var body := StaticBody3D.new()
	body.name = "Sides"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.mesh.get_faces())
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	land.add_child(body)

func _triangles() -> int:
	var n := 0
	for p: Node3D in pieces.values(): n += int(p.get_meta("triangles",0))
	return n

# --- What moves --------------------------------------------------------------------------

## The lamps, the maw and the court's heads (drawn), the surge (a sluice a
## pool and its clock), the tenders.
func live(g: Node) -> void:
	var fires := Node3D.new()
	fires.name = "Fires"
	g.add_child(fires)
	var lm: Dictionary = LAYOUT.lamps
	for k: int in lm.lit:
		var c: Node3D = CityFires.cresset(fires,Transform3D(Basis(Vector3.UP,0.3*k),g.w(lamp(k))),{"size":"cresset","seed":SEED+40+k,"name":"WeirLamp%d" % k,"lit":true,"draw":1.0,"barge":false})
		Court._still(c)
	var nl: Node3D = CityFires.cresset(fires,Transform3D(Basis(Vector3.UP,PI),g.w(niche_lamp())),{"size":"cresset","seed":SEED+48,"name":"NicheLamp","lit":true,"draw":1.0,"barge":false})
	Court._still(nl)
	# The fallen one: tipped on its side across the brim, cold.
	var fk := int(lm.fallen)
	var fall := Transform3D(Basis(Vector3.UP,0.7)*Basis(Vector3.BACK,1.35),g.w(lamp(fk)+Vector3(0.2,0.55,0.0)))
	CityFires.cresset(fires,fall,{"size":"cresset","seed":SEED+49,"name":"FallenLamp","lit":false})
	var i := 0
	for p: Vector2 in LAYOUT.far_lamps:
		var c: Node3D = CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(on(p))),{"size":"cresset","seed":SEED+60+i,"name":"FarLamp%d" % i,"lit":true,"draw":1.0,"barge":false})
		Court._still(c)
		i += 1
	var bc: Node3D = CityFires.tower(fires,Transform3D(Basis(Vector3.UP,0.4),g.w(on(LAYOUT.beacon))),{"seed":SEED+70,"name":"FarBeacon","lit":true,"tiers":2,"beam":3.0})
	Court._still(bc)
	if polished:
		# The lookout's own lamp: a great cresset on the knoll, behind the arrival.
		var lt: Node3D = CityFires.cresset(fires,Transform3D(Basis(Vector3.UP,-0.9),g.w(on(LAYOUT.tower))),{"size":"great","seed":SEED+71,"name":"LookoutLamp","lit":true,"draw":1.0,"barge":false})
		Court._still(lt)
	# The maw (its jaw open, its eyes dead) and the court's listening heads.
	var mw: Dictionary = LAYOUT.maw
	var maw := HeadLook.new()
	maw.name = "Maw"
	g.add_child(maw)
	maw.build(float(mw.h),SEED)
	maw.position = g.w(Vector3(float(mw.at.x),terrace(1)+float(mw.at.y),float(mw.at.z)))
	maw.open(float(mw.open))
	var k := 0
	for hd: Array in LAYOUT.heads:
		var head := HeadLook.new()
		head.name = "CourtHead%d" % k
		g.add_child(head)
		head.build(float(hd[2]),SEED+k)
		var x := float(hd[0])
		var z := float(hd[1])
		head.position = g.w(Vector3(x,far_ground(x,z)-0.4,z))
		head.rotation.y = deg_to_rad(float(hd[3]))+PI
		k += 1
	# The surge: a sluice in each pool along its line (no walls: the pool is
	# its floor), its gate hidden; the clock opens the head gate and lets each
	# lower one go as the wave above spills.
	var sl: Dictionary = LAYOUT.surge
	var p := Sluice.pilot()
	var traps: Array = []
	var ls := lines()
	for n in range(ls.size()):
		var a: Vector3 = ls[n][0]
		var b: Vector3 = ls[n][1]
		var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
		var length := flat.length()
		var t: Node3D = Sluice.new()
		t.name = "Surge%d" % (n+1)
		var cover := inner(n+1)*0.5 if n == ls.size()-1 else 4.0
		t.configure({"walls":false,"length":length,"gap":0.6,"beyond":0.0,"end":"open","width":float(LAYOUT.weirs.notch),"cover":cover,
			"wave_height":0.6,"wave_length":length+6.0,"speed":p.run*float(sl.pace),"wade":p.walk,
			"tell_time":float(sl.tell) if n == 0 else float(sl.relay),"trigger":"plate" if n == 0 else "timer","plate_at":float(sl.plate),"period":1.0e9,"refuge":0,"flow":0.01})
		t.transform = Transform3D(Basis.looking_at(flat.normalized(),Vector3.UP),g.w(a))
		g.trap(t)
		for child in t.get_children():
			if child is MeshInstance3D: (child as MeshInstance3D).visible = false
		traps.append(t)
	var clock := SurgeClock.new()
	clock.name = "SurgeClock_STANDIN"
	clock.traps = traps
	for q in range(1,count()+1): clock.notches.append(g.w(Vector3(notch_x(q),floor_of(q),front_z(q))))
	clock.period = float(sl.period)
	clock.wait = float(sl.first)

	g.add_child(clock)
	# The tenders.
	var tn := Tenders.new()
	tn.name = "Tenders_STANDIN"
	tn.g = g
	tn.near = float(LAYOUT.tenders.near)
	# In a generated layer the roaming Olmec comes instead (olmec-threat-
	# round1.md; `--knob=olmecs=places` brings the tenders back).
	if OlmecPlaces.keepers(g):
		for e: Array in tenders(): tn.spots.append([g.w(e[0]),e[1]])
	g.add_child(tn)

## STAND-IN for the card's surge down the weirs (the city_gate and
## city_waterway asks): the head gate's sluice told every `period` s (its
## rattle, drain and rumble the trap's own), and each lower pool's sluice let
## go as the wave above it reaches its lip, so one surge runs all seven. A
## rider is carried and flung by the trap's own rules; the clock adds the
## funnel (a carried rider drawn across onto the channel's line, which the
## straight sluice lacks).
class SurgeClock extends Node:
	var traps: Array = []
	var period := 30.0
	var wait := 8.0
	var surges := 0
	var relays := 0
	var funneled := 0.0
	var _head_was := false
	var riding := false
	const FUNNEL := 6.0
	const NEAR := 0.0
	## Each pool's notch (its lip's middle, world).
	var notches: Array = []
	var _t := 0.0
	var _passed: Array = []
	var _spills: Array = []
	var _aboard: Array = []
	var _ride_seen := {}

	func _rides(n: int) -> int:
		return int(_ride_seen.get(n,0))

	func _physics_process(delta: float) -> void:
		if traps.is_empty(): return
		if _passed.size() != traps.size():
			_passed.resize(traps.size())
			_passed.fill(false)
		_t += delta
		# The funnel: carried, he is drawn across toward the channel's line
		# (the water runs into its notch), FUNNEL m/s at most.
		# Within NEAR m of its wall, drawn across toward the notch itself.
		for n in range(traps.size()):
			var t: Node3D = traps[n]
			if not t.carrying() or t.motor == null: continue
			var feet: Vector3 = t.motor.feet
			var by := Vector3.ZERO
			var notch: Vector3 = notches[n] if n < notches.size() else Vector3.INF
			if notch != Vector3.INF and absf(feet.z-notch.z) < NEAR:
				by.x = clampf(notch.x-feet.x,-FUNNEL*delta,FUNNEL*delta)
			else:
				var local: Vector3 = t.to_local(feet)
				by = t.global_transform.basis.x.normalized()*clampf(-local.x,-FUNNEL*delta,FUNNEL*delta)
			if by.length() > 0.0001: t.motor.carry(Transform3D(Basis.IDENTITY,by),0.0)
			funneled += by.length()
		var head: Node3D = traps[0]
		# The head gate: its plate (the trap's own), or every `period` s.
		if int(head.state) != Sluice.IDLE and not _head_was:
			surges += 1
			_t = 0.0
			wait = period
		_head_was = int(head.state) != Sluice.IDLE
		if _t >= wait and int(head.state) == Sluice.IDLE:
			head.trigger()
		if _spills.size() != traps.size():
			_spills.resize(traps.size())
			_spills.fill(0)
			_aboard.resize(traps.size())
			_aboard.fill(false)
		# A rider aboard this surge: from then on the lower gates go only
		# as he is flung (an empty surge relays on the wave's front).
		var any := false
		for t: Node3D in traps:
			if t.carrying(): riding = true
			if int(t.state) != Sluice.IDLE: any = true
		if not any: riding = false
		for n in range(traps.size()-1):
			var t: Node3D = traps[n]
			# The rider flung off this lip: the next gate goes now, so its
			# water is there as he lands.
			if int(t.spills) != int(_spills[n]) or int(t.rides) != int(_rides(n)):
				_spills[n] = int(t.spills)
				_ride_seen[n] = int(t.rides)
				_aboard[n] = false
				var below: Node3D = traps[n+1]
				if int(below.state) == Sluice.IDLE:
					below.trigger()
					relays += 1
				continue
			if int(t.state) != Sluice.FLOWING:
				_passed[n] = false
				_aboard[n] = false
				continue
			if t.carrying(): _aboard[n] = true
			if _passed[n] or _aboard[n] or riding: continue
			if float(t.clock)*float(t.knob("speed")) >= float(t.channel_length()):
				_passed[n] = true
				var nxt: Node3D = traps[n+1]
				if int(nxt.state) == Sluice.IDLE:
					nxt.trigger()
					relays += 1

## STAND-IN for the card's tenders hanging on the weir walls (the headless
## body has no "hang and wait" stance): each is set clinging under its rim
## (HeadlessBody `cling`) once he comes within `near` m of it, so it hauls
## itself over as he reaches the rim, and hunts him from there.
class Tenders extends Node:
	var g: Node = null
	var near := 26.0
	var spots: Array = []
	var bodies: Array = []
	var _done: Array = []

	func _physics_process(_delta: float) -> void:
		if g == null or spots.is_empty(): return
		if _done.size() != spots.size():
			_done.resize(spots.size())
			_done.fill(false)
		var motor: Object = g.stage.study.motor
		var feet: Vector3 = motor.feet
		for n in range(spots.size()):
			if _done[n]: continue
			var lip: Vector3 = spots[n][0]
			if Vector2(feet.x-lip.x,feet.z-lip.z).length() > near or absf(feet.y-lip.y) > 14.0: continue
			_done[n] = true
			var out: Vector2 = spots[n][1]
			var b: Node3D = g.enemy(HeadlessBody,lip+Vector3(out.x,0.0,out.y)*2.0,-out,{"seed":SEED+90+n,"chase":1,"chase_routes":1})
			if b != null and b.has_method("cling"):
				b.cling(lip,out)
				bodies.append(b)
