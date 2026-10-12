extends RefCounted
## The flight study's course (studies/flight_study.gd, tools/flight_bench.gd):
## hand-placed greybox stations for the plane (scripts/sky_plane.gd), each a
## short section with a trail of tokens to fly through and a few primitive
## solids round it. A station is plain data (STATIONS), so a later round can
## generate them: an id, its key, a name, the band it was meant to land in
## (`intent`, the designer's guess, never used to judge), its parts and its
## tokens, in the station's own metres. The plane is set down at the
## station's middle (local 0, 0, 0) flying north (-Z, heading 0) at cruise.
##
## Parts, in local metres (y up, the entry's height at 0, the floor at
## -ALT):
##   ["box", middle Vector3, size Vector3, yaw]
##   ["pillar", Vector2 x z, radius]   (from the floor up to TOP)
##   ["gate", middle Vector3, width, height, yaw]   (posts, lintel and sill
##       round a width x height opening, BAR thick)
##   ["ring", middle Vector3, inner radius, yaw]   (RING_SEGMENTS boxes)
##   ["bay", at Vector3, yaw, plan Dictionary]   (one bay of the Sundered
##       hall's nave in greybox, at the real hall's dimensions,
##       scripts/ruin_kit_hall.gd: `at` is its bay line's middle on its
##       floor, the nave running north (-Z) at yaw 0; see `_bay` for the
##       plan's keys)
##   ["wall", ...], ["stack", ...], ["arch", ...]   the nature pack's
##       landforms (scripts/flight_pack_nature.gd `part_solids`)
##   ["rock", ...], ["isle", ...], ["span", ...], ["bore", ...], ["slab", ...]
##       the sky pack's floating islands (scripts/flight_pack_sky.gd
##       `solids_of`)
## Packs append their stations after these (key -1: no digit key). The
## moments pack (scripts/flight_pack_moments.gd) reuses other packs' parts
## and trails: its trail is all guides and what there is to get are its
## `moments` (free, a starter, challenge ones; `challenge` its settings).
## Each expands into world-space solids (`solids`): {"kind":"box","middle",
## "size","basis"} or {"kind":"cyl","middle","radius","height"}, which the
## study draws and gives colliders on the ruins' layer (scripts/ruin_bump.gd
## LAYER), so the plane bumps off them as it does off the Sundered hall's
## stone: never a crash, a share of its speed lost. The floor is the plane's
## ground (it skims along it). Signed distances to the solids (`distance`)
## give the room round the line.

const PlaneFigure = preload("res://scripts/plane_figure.gd")
## The toy plane's span and the game's sizes (scripts/world_scale.gd).
const WorldScale = preload("res://scripts/world_scale.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
## Station packs, appended after the hand-placed stations in this order
## (each its own file, its stations keyless: NO_KEY, a "pack" name).
const PackLines = preload("res://scripts/flight_pack_lines.gd")
const PackNature = preload("res://scripts/flight_pack_nature.gd")
const PackSky = preload("res://scripts/flight_pack_sky.gd")
const PackTokens = preload("res://scripts/flight_pack_tokens.gd")
const PackMoments = preload("res://scripts/flight_pack_moments.gd")

## The stations stand ALT metres over the floor (y 0), SPACING metres apart
## along x; pillars rise to TOP over the entry.
const ALT := 40.0
const SPACING := 260.0
const TOP := 30.0
## A greybox hall bay: how high a torn line's columns stand and a torn
## bay's walls (m over its floor: the low ends of Hall TORN_SNAP and
## TORN_WALL), an open bay's walls, a low breach's and a collapse's.
const TORN_SNAP := 3.0
const TORN_WALL := 3.0
const OPEN_WALL := 7.5
const BREACH_WALL := {"low":1.4,"collapse":0.8}
## A gate's frame and a ring's bar (m thick), the ring's segments.
const BAR := 1.0
const RING_SEGMENTS := 12
## A token's pickup reach (m from the plane's middle to the token's): the
## game's plane reach plus half an air token (scripts/collectible_lines.gd).
const REACH := 1.1+0.5*1.2
## The token drawn (m across), as the game's air tokens.
const TOKEN_SIZE := 1.2
## The plane's wingspan (scripts/plane_figure.gd).
const SPAN := WorldScale.TOY_SPAN
## Bumped into: the collision layer (the ruins', as RuinBump reads it).
const LAYER := RuinBump.LAYER
## Bumped into the data format or the reach: older runs keep their own hash.
const VERSION := 1

## The stations as laid (in the toy's hall: TOY_BAY bays); STATIONS has the
## moments pack's (the game's set pieces) moved into the game's hall
## (`_game_hall`).
const LAID := [
	{"id":"gentle_arc","key":1,"name":"Gentle arc","intent":"easy","parts":[
		["pillar",Vector2(40.0,-20.0),2.0],
		["pillar",Vector2(-14.0,-50.0),1.5],
	],"tokens":[
		Vector3(0.0,0.0,-12.0),Vector3(0.0,0.0,-22.0),Vector3(1.8,0.0,-33.0),Vector3(7.0,0.0,-43.0),
		Vector3(14.5,0.0,-51.5),Vector3(24.0,0.0,-57.5),Vector3(35.0,0.0,-61.0),Vector3(46.0,0.0,-61.5),
	]},
	{"id":"slalom","key":2,"name":"S-slalom through pillars","intent":"medium","parts":[
		["pillar",Vector2(0.0,-24.0),1.5],["pillar",Vector2(0.0,-48.0),1.5],
		["pillar",Vector2(0.0,-72.0),1.5],["pillar",Vector2(0.0,-96.0),1.5],
	],"tokens":[
		Vector3(0.0,0.0,-10.0),Vector3(4.5,0.0,-24.0),Vector3(0.0,0.0,-36.0),Vector3(-4.5,0.0,-48.0),
		Vector3(0.0,0.0,-60.0),Vector3(4.5,0.0,-72.0),Vector3(0.0,0.0,-84.0),Vector3(-4.5,0.0,-96.0),
		Vector3(0.0,0.0,-110.0),
	]},
	{"id":"hidden_turn","key":3,"name":"Hidden turn behind a block","intent":"hard","parts":[
		# A deep block west of the way, a screen east of it: a lane 8 m
		# wide up its side; past the block's far face the line hooks back
		# west behind it, out of sight until the lane's end.
		["box",Vector3(-13.0,-5.0,-54.0),Vector3(34.0,70.0,24.0),0.0],
		["box",Vector3(14.0,-5.0,-50.0),Vector3(4.0,70.0,40.0),0.0],
	],"tokens":[
		Vector3(0.0,0.0,-14.0),Vector3(3.0,0.0,-28.0),Vector3(8.0,0.0,-40.0),Vector3(8.0,0.0,-54.0),
		Vector3(8.0,0.0,-64.0),Vector3(3.0,0.0,-70.5),Vector3(-5.0,0.0,-72.0),Vector3(-13.0,0.0,-71.5),
		Vector3(-21.0,0.0,-70.5),
	]},
	{"id":"tight_slot","key":4,"name":"Tight slot (2.4 m)","intent":"medium","parts":[
		# Two walls with a 2.4 m slot between them, offset east of the way.
		["box",Vector3(-10.2,-5.0,-50.0),Vector3(30.0,70.0,8.0),0.0],
		["box",Vector3(22.2,-5.0,-50.0),Vector3(30.0,70.0,8.0),0.0],
	],"tokens":[
		Vector3(0.0,0.0,-12.0),Vector3(3.5,0.0,-25.0),Vector3(6.0,0.0,-37.0),Vector3(6.0,0.0,-50.0),
		Vector3(6.0,0.0,-62.0),Vector3(4.0,0.0,-76.0),
	]},
	{"id":"climb_rings","key":5,"name":"Climb through rings","intent":"medium","parts":[
		["ring",Vector3(0.0,0.0,-22.0),3.5,0.0],["ring",Vector3(0.0,5.0,-38.0),3.5,0.0],
		["ring",Vector3(0.0,11.0,-54.0),3.5,0.0],["ring",Vector3(0.0,17.0,-70.0),3.5,0.0],
		["ring",Vector3(0.0,21.0,-86.0),3.5,0.0],
	],"tokens":[
		Vector3(0.0,0.0,-10.0),Vector3(0.0,0.0,-22.0),Vector3(0.0,5.0,-38.0),Vector3(0.0,11.0,-54.0),
		Vector3(0.0,17.0,-70.0),Vector3(0.0,21.0,-86.0),Vector3(0.0,22.0,-100.0),
	]},
	{"id":"dive_arch","key":6,"name":"Dive under an arch","intent":"medium","parts":[
		# An arch on the floor: an 8 m wide, 5 m high opening.
		["box",Vector3(-5.0,-ALT+4.0,-64.0),Vector3(2.0,8.0,3.0),0.0],
		["box",Vector3(5.0,-ALT+4.0,-64.0),Vector3(2.0,8.0,3.0),0.0],
		["box",Vector3(0.0,-ALT+6.5,-64.0),Vector3(12.0,3.0,3.0),0.0],
	],"tokens":[
		Vector3(0.0,0.0,-12.0),Vector3(0.0,-6.0,-26.0),Vector3(0.0,-17.0,-38.0),Vector3(0.0,-29.0,-50.0),
		Vector3(0.0,-37.5,-64.0),Vector3(0.0,-34.0,-78.0),Vector3(0.0,-25.0,-90.0),
	]},
	{"id":"open_swoop","key":7,"name":"Open swoop","intent":"easy","parts":[
		["pillar",Vector2(-30.0,-40.0),2.0],["pillar",Vector2(40.0,-90.0),2.0],
	],"tokens":[
		Vector3(0.0,0.0,-14.0),Vector3(-3.0,-3.0,-30.0),Vector3(-10.0,-7.0,-45.0),Vector3(-14.0,-9.0,-62.0),
		Vector3(-11.0,-8.0,-80.0),Vector3(-2.0,-5.0,-95.0),Vector3(10.0,-1.0,-106.0),Vector3(24.0,3.0,-112.0),
	]},
	{"id":"mixed_spike","key":8,"name":"Easy trail, one hard spike","intent":"hard","parts":[
		["pillar",Vector2(-3.0,-56.0),1.2],
	],"tokens":[
		Vector3(0.0,0.0,-12.0),Vector3(0.0,0.0,-24.0),Vector3(0.0,0.0,-36.0),Vector3(0.0,0.0,-46.0),
		# The spike: 7 m east and 2 m up in 10 m, then straight back.
		Vector3(7.0,2.0,-56.0),
		Vector3(0.0,0.0,-68.0),Vector3(0.0,0.0,-80.0),Vector3(0.0,0.0,-92.0),
	]},
	# The Sundered hall (scripts/sundered_hall.gd), greyboxed: four of its
	# acts squeezed into two pieces, at the real hall's dimensions
	# (scripts/ruin_kit_hall.gd). Piece A, 8 bays: the gate's roofed mouth,
	# a low tie flown under, a high tie hopped over, shafts of broken roof,
	# then a cloister's open bays and out right between the row's columns,
	# over a low breach, past the torn end. A 22 m gap stepping down 5 m.
	# Piece B, 6 bays, 8 m right of A so the way out runs on into its lane:
	# the slit act (screens with knife-edge slits on the left, the lane open
	# on the right, a low tie under), then the apse's open roof, climbing
	# out to the sky. Each bay: ["bay", its bay line's middle on its floor,
	# yaw, plan]. A's lane (hall z LANE_MID) runs at x 0, B's at x 8.
	{"id":"sundered","key":9,"name":"Sundered hall (gate, cloister, slit, apse)","intent":"hard","ease":1.05,"parts":[
		["bay",Vector3(-6.0,-2.3,-14.0),0.0,{"roof":"whole","inner":[]}],
		["bay",Vector3(-6.0,-2.3,-22.0),0.0,{"roof":"whole","tie":"low","inner":[-2.6]}],
		["bay",Vector3(-6.0,-2.3,-30.0),0.0,{"roof":"broken","gaps":[3,4],"inner":[0.0]}],
		["bay",Vector3(-6.0,-2.3,-38.0),0.0,{"roof":"whole","tie":"high","inner":[-2.6,2.6]}],
		["bay",Vector3(-6.0,-2.3,-46.0),0.0,{"roof":"broken","gaps":[2,3],"inner":[-2.6]}],
		["bay",Vector3(-6.0,-2.3,-54.0),0.0,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(-6.0,-2.3,-62.0),0.0,{"roof":"open","inner":[-2.6],"breach":["","low"]}],
		["bay",Vector3(-6.0,-2.3,-70.0),0.0,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[]}],
		["bay",Vector3(2.0,-7.3,-100.0),0.0,{"roof":"open","torn":1,"inner":[]}],
		["bay",Vector3(2.0,-7.3,-108.0),0.0,{"roof":"whole","tie":"high","screen":true,"inner":[-2.6,2.6]}],
		["bay",Vector3(2.0,-7.3,-116.0),0.0,{"roof":"broken","gaps":[1,2],"tie":"low","inner":[0.0]}],
		["bay",Vector3(2.0,-7.3,-124.0),0.0,{"roof":"whole","tie":"high","screen":true,"inner":[-2.6,2.6]}],
		["bay",Vector3(2.0,-7.3,-132.0),0.0,{"roof":"open","inner":[-2.6]}],
		["bay",Vector3(2.0,-7.3,-140.0),0.0,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[]}],
	],"tokens":[
		# In at the gate, under the low tie, up over the high tie.
		Vector3(0.0,0.0,-10.0),Vector3(0.0,0.4,-22.0),Vector3(0.0,5.9,-38.0),
		# Down the nave under the broken roof, then out right between the
		# row's columns, over the low breach, past the torn end.
		Vector3(0.0,1.5,-52.0),Vector3(-0.8,1.0,-60.0),Vector3(3.4,2.0,-66.0),Vector3(9.0,2.0,-73.0),
		# Across the gap, stepping down into B's torn mouth.
		Vector3(8.5,-1.5,-87.0),Vector3(8.0,-4.5,-100.0),
		# Along the lane past the screens and under the low tie.
		Vector3(8.0,-5.0,-110.0),Vector3(8.0,-5.0,-120.0),Vector3(8.0,-5.0,-128.0),
		# Up out of the apse's open roof to the sky.
		Vector3(8.0,-2.0,-136.0),Vector3(8.0,3.0,-144.0),Vector3(8.0,8.0,-154.0),Vector3(8.0,11.0,-166.0),
	]},
	{"id":"sundered_flow","key":0,"name":"Sundered hall, flowing (corkscrew nave, swoop, climbing turn)","intent":"medium","parts":[
		["bay",Vector3(6.37,-2.40,-14.66),-0.3005,{"roof":"whole","inner":[]}],
		["bay",Vector3(8.73,-2.40,-22.30),-0.2278,{"roof":"whole","tie":"high","inner":[]}],
		["bay",Vector3(10.54,-2.40,-30.09),-0.1551,{"roof":"broken","gaps":[3,4],"inner":[0.0]}],
		["bay",Vector3(11.78,-2.40,-38.00),-0.0823,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(12.43,-2.40,-45.97),-0.0096,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(12.51,-2.40,-53.97),0.0631,{"roof":"broken","gaps":[2,3],"inner":[0.0]}],
		["bay",Vector3(12.01,-2.40,-61.95),0.1358,{"roof":"open","inner":[0.0],"breach":["arch",""]}],
		["bay",Vector3(10.92,-2.40,-69.87),0.2086,{"roof":"open","tie":"high","inner":[]}],
		["bay",Vector3(9.27,-2.40,-77.70),0.2813,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[0.0]}],
		["bay",Vector3(11.84,-7.40,-112.18),-0.4823,{"roof":"open","torn":1,"inner":[]}],
		["bay",Vector3(15.55,-7.40,-119.26),-0.5823,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(19.95,-7.40,-125.94),-0.6823,{"roof":"broken","gaps":[1,2],"screen":true,"inner":[-2.6]}],
		["bay",Vector3(24.99,-7.40,-132.15),-0.7823,{"roof":"whole","screen":true,"inner":[-2.6]}],
		["bay",Vector3(30.63,-7.40,-137.82),-0.8823,{"roof":"open","tie":"high","beam":false,"inner":[]}],
		["bay",Vector3(36.81,-7.40,-142.90),-0.9823,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[]}],
	],"tokens":[
		Vector3(3.10,4.50,-15.81),Vector3(8.73,6.00,-22.30),Vector3(13.94,4.50,-29.44),Vector3(15.22,1.50,-37.59),
		Vector3(12.43,0.00,-45.97),Vector3(9.05,1.50,-53.87),Vector3(8.56,4.50,-61.60),Vector3(10.92,6.00,-69.87),
		Vector3(12.63,4.50,-78.54),Vector3(10.34,1.50,-86.46),Vector3(7.46,0.52,-92.48),Vector3(5.81,0.46,-99.22),
		Vector3(5.59,-0.50,-105.89),Vector3(8.70,-3.50,-113.63),Vector3(15.55,-5.00,-119.26),Vector3(22.75,-4.22,-123.90),
		Vector3(27.57,-2.01,-129.83),Vector3(30.63,1.30,-137.82),Vector3(34.74,5.20,-145.68),Vector3(41.68,9.10,-150.31),
		Vector3(50.52,12.41,-151.09),
	]},
	# >>> sundered_mix: written by tools/flight_flow_layout.py --station mix --write
	{"id":"sundered_mix","key":10,"name":"Sundered hall, mixed moves (weave, corkscrew, knife slits, wave, climbing turn)","intent":"medium","parts":[
		["bay",Vector3(5.05,-4.50,-19.36),0.1147,{"roof":"whole","inner":[]}],
		["bay",Vector3(4.14,-4.50,-27.31),0.0004,{"roof":"broken","gaps":[2,3],"inner":[0.0,-2.6]}],
		["bay",Vector3(4.14,-4.50,-35.30),-0.1139,{"roof":"whole","tie":"high","inner":[0.0,-2.6]}],
		["bay",Vector3(5.04,-4.50,-43.24),-0.2282,{"roof":"open","inner":[]}],
		["bay",Vector3(6.85,-4.50,-51.03),-0.3425,{"roof":"broken","gaps":[3,4],"tie":"high","inner":[0.0]}],
		["bay",Vector3(9.54,-4.50,-58.56),-0.4568,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(13.06,-4.50,-65.74),-0.5710,{"roof":"whole","inner":[]}],
		["bay",Vector3(17.39,-4.50,-72.47),-0.6853,{"roof":"broken","gaps":[2,3],"inner":[]}],
		["bay",Vector3(22.45,-4.50,-78.66),-0.7996,{"roof":"whole","tie":"high","inner":[0.0,2.6]}],
		["bay",Vector3(28.18,-4.50,-84.23),-0.9139,{"roof":"open","inner":[0.0,2.6]}],
		["bay",Vector3(34.51,-4.50,-89.11),-1.0282,{"roof":"broken","gaps":[3,4],"screen":true,"inner":[-2.6],"torn":2,"last":true}],
		["bay",Vector3(38.42,-9.50,-127.14),0.2575,{"roof":"whole","inner":[],"torn":1}],
		["bay",Vector3(36.39,-9.50,-134.87),0.1432,{"roof":"broken","gaps":[2,3],"inner":[]}],
		["bay",Vector3(35.24,-9.50,-142.79),0.0290,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(35.01,-9.50,-150.78),-0.0853,{"roof":"open","inner":[]}],
		["bay",Vector3(35.69,-9.50,-158.75),-0.1996,{"roof":"broken","gaps":[3,4],"inner":[]}],
		["bay",Vector3(37.28,-9.50,-166.58),-0.3139,{"roof":"whole","tie":"high","inner":[]}],
		["bay",Vector3(39.75,-9.50,-174.19),-0.4282,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(43.07,-9.50,-181.46),-0.5425,{"roof":"broken","gaps":[2,3],"inner":[]}],
		["bay",Vector3(47.20,-9.50,-188.31),-0.6568,{"roof":"whole","tie":"high","inner":[]}],
		["bay",Vector3(52.08,-9.50,-194.64),-0.7710,{"roof":"open","inner":[]}],
		["bay",Vector3(57.65,-9.50,-200.38),-0.8853,{"roof":"broken","gaps":[3,4],"inner":[]}],
		["bay",Vector3(63.84,-9.50,-205.44),-0.9996,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(70.57,-9.50,-209.76),-1.1139,{"roof":"whole","tie":"high","inner":[0.0,2.6]}],
		["bay",Vector3(77.74,-9.50,-213.29),-1.2282,{"roof":"broken","gaps":[2,3],"screen":true,"inner":[-2.6]}],
		["bay",Vector3(85.27,-9.50,-215.97),-1.3425,{"roof":"open","tie":"high","inner":[0.0,2.6],"torn":2,"last":true}],
	],"tokens":[
		Vector3(4.82,1.13,-19.32),Vector3(7.70,0.62,-27.51),Vector3(7.97,-0.41,-35.08),Vector3(5.47,-0.90,-43.17),
		Vector3(3.84,-0.13,-51.92),Vector3(6.32,1.09,-59.92),Vector3(11.41,1.60,-66.67),Vector3(15.88,1.06,-73.56),
		Vector3(19.52,-0.04,-81.34),Vector3(24.35,-1.18,-88.65),Vector3(27.58,-1.61,-91.55),Vector3(31.13,-1.85,-94.07),
		Vector3(34.77,-1.86,-96.42),Vector3(38.63,-1.65,-98.42),Vector3(44.54,-0.55,-104.46),Vector3(47.02,0.28,-113.55),
		Vector3(45.25,-1.20,-121.49),Vector3(40.73,-4.49,-127.89),Vector3(36.54,-6.72,-134.91),Vector3(33.70,-6.81,-142.65),
		Vector3(33.26,-4.60,-150.83),Vector3(35.90,-2.02,-158.72),Vector3(39.89,-1.24,-165.90),Vector3(42.59,-2.74,-173.08),
		Vector3(42.90,-4.66,-181.55),Vector3(44.74,-5.06,-189.99),Vector3(50.84,-4.17,-195.71),Vector3(57.22,-3.96,-200.84),
		Vector3(61.96,-4.89,-208.03),Vector3(67.69,-6.15,-214.85),Vector3(71.42,-6.62,-217.08),Vector3(75.41,-6.85,-218.81),
		Vector3(79.42,-6.74,-220.48),Vector3(83.63,-6.29,-221.59),Vector3(92.57,-4.60,-220.60),Vector3(101.19,-2.35,-219.06),
	]},
	# <<< sundered_mix
]+PackLines.STATIONS+PackNature.STATIONS+PackSky.STATIONS+PackTokens.STATIONS+PackMoments.STATIONS
static var STATIONS: Array = _game_stations(LAID)

## The stations with the moments pack's moved into the game's hall: their
## stone, tokens, lines, bonus and moments laid in the toy's hall (TOY_BAY
## bays, TOY_ROW_Z rows) re-laid on the game's (Hall BAY, ROW_Z, WALL_Z) by
## `_game_hall`. At plane 1, ratio 1 the game's hall is the toy's and they
## stand as laid. The study's own stations stay in the toy's hall.
static func _game_stations(laid: Array) -> Array:
	var out := []
	for s: Dictionary in laid:
		out.append(_game_hall(s) if str(s.get("pack","")) == "moments" else s)
	return out

## Station `s` laid in the toy's hall, re-laid in the game's: its bays
## chained BAY apart (not TOY_BAY), each run of bays (a section) starting
## where the last's frame takes its start; every other point (parts, tokens,
## moments) carried in the frame of the bay it is in or nearest: along the
## nave stretched by BAY over TOY_BAY within the bay and shifted past it;
## across, the lane between the inner columns and the rows stretched to the
## game's ROW_Z and all beyond it moved out with it; heights kept. A station
## with no bays is itself.
static func _game_hall(s: Dictionary) -> Dictionary:
	var parts: Array = s.get("parts",[])
	var bays: Array[int] = []
	for i in range(parts.size()):
		if str(parts[i][0]) == "bay": bays.append(i)
	if bays.is_empty() or (is_equal_approx(Hall.BAY,Hall.TOY_BAY) and is_equal_approx(Hall.ROW_Z,TOY_ROW_Z)): return s
	var old_at: Array[Vector3] = []
	var turns: Array[Basis] = []
	for i: int in bays:
		var part: Array = parts[i]
		var turn := Basis(Vector3.UP,float(part[2])+PI*0.5)
		var tilt := float((part[3] as Dictionary).get("pitch",0.0))
		if tilt != 0.0: turn = turn*Basis(Vector3.BACK,tilt)
		old_at.append(part[1])
		turns.append(turn)
	var new_at: Array[Vector3] = []
	for k in range(bays.size()):
		if k == 0: new_at.append(old_at[0])
		elif old_at[k].distance_to(old_at[k-1]+turns[k-1]*Vector3(Hall.TOY_BAY,0.0,0.0)) < 0.5:
			new_at.append(new_at[k-1]+turns[k-1]*Vector3(Hall.BAY,0.0,0.0))
		else: new_at.append(_hall_point(old_at[k],old_at,new_at,turns,k))
	var out := s.duplicate(true)
	var moved := []
	for i in range(parts.size()):
		var part: Array = (parts[i] as Array).duplicate(true)
		var k := bays.find(i)
		if k >= 0: part[1] = new_at[k]
		elif part[1] is Vector3: part[1] = _hall_point(part[1],old_at,new_at,turns,bays.size())
		elif part[1] is Vector2:
			var p := _hall_point(Vector3((part[1] as Vector2).x,0.0,(part[1] as Vector2).y),old_at,new_at,turns,bays.size())
			part[1] = Vector2(p.x,p.z)
		moved.append(part)
	out.parts = moved
	var carry := func(points: Array) -> Array:
		var done := []
		for p: Vector3 in points: done.append(_hall_point(p,old_at,new_at,turns,bays.size()))
		return done
	if s.has("tokens"): out.tokens = carry.call(s.tokens)
	if s.has("bonus"): out.bonus = carry.call(s.bonus)
	if s.has("lines"):
		for name: String in (out.lines as Dictionary):
			out.lines[name].tokens = carry.call(s.lines[name].tokens)
	if s.has("moments"):
		for m: Dictionary in out.moments: m.at = _hall_point(m.at,old_at,new_at,turns,bays.size())
	return out

## A point of a toy-hall station in the game's hall (see `_game_hall`),
## carried by the bay (of the first `upto`) it is in or nearest.
static func _hall_point(p: Vector3, old_at: Array[Vector3], new_at: Array[Vector3], turns: Array[Basis], upto: int) -> Vector3:
	var best := -1
	var best_off := INF
	for k in range(mini(upto,old_at.size())):
		var local := turns[k].inverse()*(p-old_at[k])
		var off := maxf(0.0,maxf(-local.x,local.x-Hall.TOY_BAY))+absf(local.z)*0.001
		if off < best_off:
			best_off = off
			best = k
	var local := turns[best].inverse()*(p-old_at[best])
	var x := local.x
	if x > Hall.TOY_BAY: x += Hall.BAY-Hall.TOY_BAY
	elif x > 0.0: x *= Hall.BAY/Hall.TOY_BAY
	var a := absf(local.z)
	if a > TOY_ROW_Z: a += Hall.ROW_Z-TOY_ROW_Z
	elif a > Hall.INNER_Z: a = Hall.INNER_Z+(a-Hall.INNER_Z)*(Hall.ROW_Z-Hall.INNER_Z)/(TOY_ROW_Z-Hall.INNER_Z)
	return new_at[best]+turns[best]*Vector3(x,local.y,signf(local.z)*a)

## The station with `id`, or {}. "id@line" is station id flown on one of
## its token lines (`flown`).
static func station(id: String) -> Dictionary:
	var at := id.find(LINE_SEP)
	if at >= 0:
		var base := station(id.substr(0,at))
		return {} if base.is_empty() else flown(base,id.substr(at+1))
	for s: Dictionary in STATIONS:
		if s.id == id: return s
	return {}

## The `-` key's station key (keys 0-9 are their digits); a station with no
## key (a pack's: reached with N, --station or --pack) has NO_KEY.
const MINUS_KEY := 10
const NO_KEY := -1

## The key that jumps to station `s` in the study: its digit, "-", or "".
static func key_name(s: Dictionary) -> String:
	if int(s.key) == NO_KEY: return ""
	return "-" if int(s.key) == MINUS_KEY else str(int(s.key))

static func station_by_key(key: int) -> Dictionary:
	if key == NO_KEY: return {}
	for s: Dictionary in STATIONS:
		if int(s.key) == key: return s
	return {}

## The stations of pack `name` (their "pack"), in order; every station
## for "".
static func pack(name: String) -> Array:
	if name == "": return STATIONS.duplicate()
	return STATIONS.filter(func(s: Dictionary) -> bool: return str(s.get("pack","")) == name)

## Token lines: a station may carry more than one trail of tokens through
## the same solids. Its own `tokens` are the green line (the forgiving main
## one); `lines` holds the others, {name: {"intent", "tokens"}}, e.g. yellow
## (branches off for more threading and rejoins) and red (the tight mastery
## line). Flying one line is flying a station whose tokens are that line's
## (`flown`): its id is "id@line", so its runs, hash and band are its own.
const LINE_SEP := "@"
const GREEN := "green"

## The lines of station `s` (its base's), green first.
static func line_names(s: Dictionary) -> PackedStringArray:
	var out := PackedStringArray([GREEN])
	for name: String in (s.get("lines",{}) as Dictionary): out.append(name)
	return out

## Which line station `s` flies: green unless it is a line flown (`flown`).
static func line_of(s: Dictionary) -> String:
	return str(s.get("line",GREEN))

## The station `s` stands for: itself, or the station a line flown is of.
static func base_of(s: Dictionary) -> Dictionary:
	return station(str(s.base)) if s.has("base") else s

## Station `s` flown on its line `line`: the same station with that line's
## tokens, intent and `ease` (none unless the line has its own), id
## "id@line" (green is the station itself). {} if it has no such line.
static func flown(s: Dictionary, line: String) -> Dictionary:
	var base := base_of(s)
	if line == GREEN: return base
	var lines: Dictionary = base.get("lines",{})
	if not lines.has(line): return {}
	var out := base.duplicate()
	out.erase("lines")
	out["id"] = str(base.id)+LINE_SEP+line
	out["name"] = "%s (%s line)" % [base.name,line]
	out["intent"] = str(lines[line].get("intent",base.intent))
	out["tokens"] = lines[line].tokens
	out.erase("ease")
	if lines[line].has("ease"): out["ease"] = lines[line].ease
	out["base"] = base.id
	out["line"] = line
	return out

static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for s: Dictionary in STATIONS: out.append(s.id)
	return out

## Where station `s` stands in the world: its entry point. Its own
## `origin` if it has one (the tokens pack's row at z +1300); else its
## place in STATIONS, SPACING apart along x (a line flown stands where its
## station does).
static func origin(s: Dictionary) -> Vector3:
	if s.has("origin"): return s.origin
	var i := STATIONS.find(s)
	if i < 0 and s.has("base"): i = STATIONS.find(base_of(s))
	return Vector3(float(i)*SPACING,ALT,0.0)

## The entry: where the plane is set down and its heading (north).
static func entry(s: Dictionary) -> Dictionary:
	return {"position":origin(s),"heading":0.0}

## The tokens in the world.
static func tokens(s: Dictionary) -> Array[Vector3]:
	var at := origin(s)
	var out: Array[Vector3] = []
	for t: Vector3 in s.tokens: out.append(at+t)
	return out

## The floor's height (world y).
static func floor_y() -> float:
	return 0.0

## A git-independent fingerprint of the station's shape (its parts, tokens,
## the reach and the format), so runs of the same station accumulate across
## sessions and a changed station starts a new record.
static func station_hash(s: Dictionary) -> String:
	var shape := [VERSION,REACH,s.parts,s.tokens]
	if s.has("ease"): shape.append(s.ease)
	if s.has("miss_near"): shape.append(s.miss_near)
	if s.has("guides"): shape.append(["guides",s.guides])
	if s.has("bonus"): shape.append(["bonus",s.bonus])
	if s.has("moments"): shape.append(["moments",s.moments,s.get("challenge",{})])
	return var_to_str(shape).md5_text().substr(0,12)

## Station `s`'s guides: indices into its tokens that are not drawn or
## counted, only shaping the line (the metrics' and the bots' route).
## A moments station (`moments`) has no tokens to take: its whole line is
## guides (unless it lists its own).
static func guides(s: Dictionary) -> PackedInt32Array:
	if s.has("moments") and not s.has("guides"): return PackedInt32Array(range((s.tokens as Array).size()))
	return PackedInt32Array(s.get("guides",[]))

## Station `s`'s moments (the moments pack, scripts/flight_pack_moments.gd):
## its free collectibles, its starter and its challenge collectibles, in the
## world, in the station's order: [{"at", "role" ("free", "starter",
## "challenge"), "kind" ("fit", "react", "reach", or "" for a starter),
## "reach" (m: REACH times the moment's own `ease`, else the station's),
## "note"}].
static func moments(s: Dictionary) -> Array:
	var at := origin(s)
	var out := []
	for m: Dictionary in s.get("moments",[]):
		out.append({"at":at+(m.at as Vector3),"role":str(m.get("role","free")),"kind":str(m.get("kind","")),
			"reach":REACH*float(m.get("ease",s.get("ease",1.0))),"note":str(m.get("note",""))})
	return out

## Station `s`'s challenge settings (FlightMoments CHALLENGE's defaults
## under its own `challenge`): {"time" (s, 0 no limit), "area" (m off the
## line that counts as leaving), "mode" ("all": the starter reveals every
## challenge collectible; "chain": one at a time)}.
static func challenge(s: Dictionary) -> Dictionary:
	var out := {"time":0.0,"area":40.0,"mode":"all"}
	out.merge(s.get("challenge",{}),true)
	return out

## Station `s`'s bonus tokens in the world: optional, off the line,
## unordered, never missed.
static func bonus(s: Dictionary) -> Array[Vector3]:
	var at := origin(s)
	var out: Array[Vector3] = []
	for t: Vector3 in s.get("bonus",[]): out.append(at+t)
	return out

## Per point (world): 1 where level wings don't fit round it whichever way
## the plane flies (its clearance is under half the span, as the rooms'
## sphere), so taking a token there needs the knife edge; else 0.
static func tight(s: Dictionary, points: Array[Vector3]) -> PackedByteArray:
	var out := PackedByteArray()
	if points.is_empty(): return out
	var all := solids(s)
	for p in points: out.append(1 if clearance(all,p) < SPAN*0.5 else 0)
	return out

## Station `s`'s token reach: REACH, widened by its `ease` if it has one.
static func reach(s: Dictionary) -> float:
	return REACH*float(s.get("ease",1.0))

## Every solid of station `s`, in world space.
static func solids(s: Dictionary) -> Array:
	var at := origin(s)
	var out := []
	for part: Array in s.parts:
		match str(part[0]):
			"box":
				out.append(_box(at+(part[1] as Vector3),part[2],Basis(Vector3.UP,float(part[3]))))
			"pillar":
				var xz: Vector2 = part[1]
				var bottom := -ALT
				out.append({"kind":"cyl","middle":at+Vector3(xz.x,(bottom+TOP)*0.5,xz.y),"radius":float(part[2]),"height":TOP-bottom})
			"gate":
				var turn := Basis(Vector3.UP,float(part[4]))
				var w := float(part[2])
				var h := float(part[3])
				var mid: Vector3 = at+(part[1] as Vector3)
				for side: float in [-1.0,1.0]:
					out.append(_box(mid+turn*Vector3(side*(w+BAR)*0.5,0.0,0.0),Vector3(BAR,h+BAR*2.0,BAR*1.5),turn))
					out.append(_box(mid+turn*Vector3(0.0,side*(h+BAR)*0.5,0.0),Vector3(w,BAR,BAR*1.5),turn))
			"ring":
				var turn := Basis(Vector3.UP,float(part[3]))
				var r := float(part[2])
				var mid: Vector3 = at+(part[1] as Vector3)
				var length := 2.0*(r+BAR)*tan(PI/RING_SEGMENTS)+0.05
				for i in range(RING_SEGMENTS):
					var a := TAU*float(i)/RING_SEGMENTS
					var spin := turn*Basis(Vector3.BACK,a)
					out.append(_box(mid+spin*Vector3(r+BAR*0.5,0.0,0.0),Vector3(BAR,length,BAR),spin))
			"bay":
				# The study's stations stand in the toy's hall; the moments (the
				# game's set pieces) in the game's.
				out.append_array(_bay(at+(part[1] as Vector3),float(part[2]),part[3],str(s.get("pack","")) != "moments"))
			"wall","stack","arch":
				out.append_array(PackNature.part_solids(part,at,-ALT))
			"rock","isle","span","bore","slab":
				out.append_array(PackSky.solids_of(part,at))
	return out

## The hall the stations are laid in, as the kit built it for the toy
## plane (the study's plane is the toy, flight_course SPAN): its outer
## rows, walls, low tie, knife slit and broken arch. Frozen here: the
## stations' tokens (and the runs rated on them, their hashes pinned) were
## placed in that hall, while the game's hall (scripts/ruin_kit_hall.gd)
## widens with the game's plane. `_bay`'s `toy` off draws the game's.
const TOY_ROW_Z := 9.4
const TOY_WALL_Z := 12.4
const TOY_TIE_LOW := 4.0
const TOY_KNIFE := Vector3(1.15,1.0,3.3)
const TOY_ARCH := Vector4(5.2,0.0,5.4,1.0)

## One greybox bay of the Sundered hall's nave, in the hall's own frame
## (Hall: x along the nave from its bay line at 0 to BAY, y up from the
## floor, z across, +z the right, where the lane runs) turned so the nave
## runs north at yaw 0. The plan, every key optional:
##   roof    "whole", "broken" (whole but `gaps`) or "open" (no slabs, no
##           architraves)
##   gaps    the roof strips left out (0-5 across, as Hall's: 0 and 5 the
##           aisles, 1-4 over the nave)
##   tie     "", "low" or "high": a tie across the nave at the bay line,
##           its soffit TIE_LOW or TIE_HIGH over the floor
##   inner   the inner columns' z at the bay line
##   breach  [left, right]: "", "low", "collapse" (the wall torn down) or
##           "arch" (an ARCH opening through it)
##   screen  a screen across the left of the nave at the bay line, a
##           knife-edge slit (KNIFE) through it ("right": across the right)
##   torn    1 the bay line torn (columns snapped, no beam), 2 the far end
##           torn; either way the bay's walls stand low
##   beam    false: no roof beam at the bay line (an open bay after an
##           open bay)
##   last    the bay closes the piece: a column line at x BAY too
##   pitch   the bay tilted along the nave (rad, + rising toward its far
##           bay line), for a hall that bends up and down along its length;
##           its columns stay upright on its tilted floor
##   rows    which outer rows have a column at the bay line: -1 the left,
##           1 the right (default both; a fallen column opens a breach wide)
## Simplified from the real bay: plain boxes and drums, no gables, lancets,
## doors, buttresses, fallen beams, rubble or parapets; one height for
## torn and open walls.
static func _bay(at: Vector3, yaw: float, plan: Dictionary, toy := true) -> Array:
	var ROW_Z := TOY_ROW_Z if toy else Hall.ROW_Z
	var WALL_Z := TOY_WALL_Z if toy else Hall.WALL_Z
	var TIE_LOW := TOY_TIE_LOW if toy else Hall.TIE_LOW
	var KNIFE := TOY_KNIFE if toy else Hall.KNIFE
	var ARCH := TOY_ARCH if toy else Hall.ARCH
	var turn := Basis(Vector3.UP,yaw+PI*0.5)
	var tilt := float(plan.get("pitch",0.0))
	if tilt != 0.0: turn = turn*Basis(Vector3.BACK,tilt)
	var out := []
	var put := func(middle: Vector3, size: Vector3) -> void: out.append(_box(at+turn*middle,size,turn))
	var bay := Hall.TOY_BAY if toy else Hall.BAY
	var torn := int(plan.get("torn",0))
	var roof: String = plan.get("roof","whole")
	var soffit := Hall.COLUMN_H+Hall.BEAM.x
	# The floor: the podium's top at y 0.
	put.call(Vector3(bay*0.5,-1.0,0.0),Vector3(bay,2.0,2.0*WALL_Z+Hall.WALL_THICK))
	# The column lines, each with its roof beam across, wall to wall.
	var lines := [0.0]
	if bool(plan.get("last",false)): lines.append(bay)
	for x: float in lines:
		var snapped := (x == 0.0 and torn & 1 != 0) or (x > 0.0 and torn & 2 != 0)
		var h := TORN_SNAP if snapped else Hall.COLUMN_H
		var zs: Array = []
		for row: int in (plan.get("rows",[-1,1]) if x == 0.0 else [-1,1]): zs.append(float(row)*ROW_Z)
		if x == 0.0: zs.append_array(plan.get("inner",[]))
		for z: float in zs:
			var middle := at+turn*Vector3(x,h*0.5,z) if tilt == 0.0 else at+turn*Vector3(x,0.0,z)+Vector3.UP*h*0.5
			out.append({"kind":"cyl","middle":middle,"radius":Hall.COLUMN_R,"height":h})
		if not snapped and (x > 0.0 or bool(plan.get("beam",true))):
			put.call(Vector3(x,Hall.COLUMN_H+Hall.BEAM.x*0.5,0.0),Vector3(Hall.BEAM.y*2.0,Hall.BEAM.x,2.0*WALL_Z))
	# The tie across the nave at the bay line.
	var tie: String = plan.get("tie","")
	if tie != "":
		var tie_y := TIE_LOW if tie == "low" else Hall.TIE_HIGH
		put.call(Vector3(0.0,tie_y+Hall.TIE_DEPTH*0.5,0.0),Vector3(Hall.BEAM.y*2.0,Hall.TIE_DEPTH,2.0*ROW_Z))
	# The architraves along the rows and the roof's six strips.
	if roof != "open" and torn == 0:
		for k: float in [-1.0,1.0]:
			put.call(Vector3(bay*0.5,Hall.COLUMN_H+Hall.BEAM.x*0.5,k*ROW_Z),Vector3(bay,Hall.BEAM.x,Hall.BEAM.y*2.0))
		var edges := [-WALL_Z-0.5,-ROW_Z,-ROW_Z*0.5,0.0,ROW_Z*0.5,ROW_Z,WALL_Z+0.5]
		var gaps: Array = plan.get("gaps",[])
		for i in range(edges.size()-1):
			if i in gaps: continue
			put.call(Vector3(bay*0.5,soffit+Hall.SLAB*0.5,(float(edges[i])+float(edges[i+1]))*0.5),Vector3(bay,Hall.SLAB,float(edges[i+1])-float(edges[i])))
	# The side walls: under a roof up to its top and a parapet, open or torn
	# lower, breached to their stumps or through an arch.
	var breach: Array = plan.get("breach",["",""])
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		var kind: String = breach[k]
		var high := Hall.ROOF_TOP+1.0
		if roof == "open": high = OPEN_WALL
		if torn != 0: high = minf(high,TORN_WALL)
		if BREACH_WALL.has(kind): high = BREACH_WALL[kind]
		var z := side*WALL_Z
		var size := Vector3(bay,high,Hall.WALL_THICK)
		if kind == "arch":
			var w := ARCH.x
			var top := ARCH.z
			var jamb := (bay-w)*0.5
			put.call(Vector3(jamb*0.5,high*0.5,z),Vector3(jamb,high,Hall.WALL_THICK))
			put.call(Vector3(bay-jamb*0.5,high*0.5,z),Vector3(jamb,high,Hall.WALL_THICK))
			put.call(Vector3(bay*0.5,(top+high)*0.5,z),Vector3(w,high-top,Hall.WALL_THICK))
		else:
			put.call(Vector3(bay*0.5,high*0.5,z),size)
	# The screen across the left (or right) of the nave, its knife-edge slit.
	var screen: Variant = plan.get("screen",false)
	if screen is String or bool(screen):
		var z := (1.0 if str(screen) == "right" else -1.0)*(ROW_Z+Hall.INNER_Z)*0.5
		var span := (ROW_Z-Hall.INNER_Z)*0.5-Hall.COLUMN_R+0.06
		var high := (TIE_LOW if tie == "low" else (Hall.TIE_HIGH if tie == "high" else 7.0))-0.02
		var half := KNIFE.x*0.5
		var head := KNIFE.y+KNIFE.z
		var thick := 0.9
		put.call(Vector3(0.0,high*0.5,(z-span+z-half)*0.5),Vector3(thick,high,span-half))
		put.call(Vector3(0.0,high*0.5,(z+half+z+span)*0.5),Vector3(thick,high,span-half))
		put.call(Vector3(0.0,KNIFE.y*0.5,z),Vector3(thick,KNIFE.y,KNIFE.x))
		put.call(Vector3(0.0,(head+high)*0.5,z),Vector3(thick,high-head,KNIFE.x))
	return out

static func _box(middle: Vector3, size: Vector3, basis: Basis) -> Dictionary:
	return {"kind":"box","middle":middle,"size":size,"basis":basis}

## Signed distance (m) from `p` to solid `s`: negative inside.
static func distance(s: Dictionary, p: Vector3) -> float:
	if s.kind == "box":
		var local: Vector3 = (s.basis as Basis).transposed()*(p-(s.middle as Vector3))
		var q: Vector3 = local.abs()-(s.size as Vector3)*0.5
		return Vector3(maxf(q.x,0.0),maxf(q.y,0.0),maxf(q.z,0.0)).length()+minf(maxf(q.x,maxf(q.y,q.z)),0.0)
	var m: Vector3 = s.middle
	var d := Vector2(Vector2(p.x-m.x,p.z-m.z).length()-float(s.radius),absf(p.y-m.y)-float(s.height)*0.5)
	return Vector2(maxf(d.x,0.0),maxf(d.y,0.0)).length()+minf(maxf(d.x,d.y),0.0)

## The nearest solid's signed distance from `p` (INF with none), the floor
## counted.
static func clearance(all: Array, p: Vector3) -> float:
	var best := p.y-floor_y()
	for s: Dictionary in all: best = minf(best,distance(s,p))
	return best

## The plane's ground: the floor everywhere (it skims along it); the solids
## are bumped off through physics (RuinBump), as the game's ruins are.
static func ground(_point: Vector3) -> Variant:
	return floor_y()

## Stands station `s`'s solids under `parent` as static bodies on LAYER; with
## `material` (a Callable(kind) -> Material) they are drawn too. Each body
## carries its crash class as meta (a solid's "crash", else "stone").
static func build(s: Dictionary, parent: Node3D, material := Callable()) -> Node3D:
	var root := Node3D.new()
	root.name = "Station_"+str(s.id)
	parent.add_child(root)
	for solid: Dictionary in solids(s):
		var body := StaticBody3D.new()
		body.collision_layer = LAYER
		body.collision_mask = 0
		# Its crash class (scripts/flight_crash.gd CLASSES): "stone" unless
		# the solid says otherwise.
		body.set_meta(&"crash_class",str(solid.get("crash","stone")))
		var shape := CollisionShape3D.new()
		var mesh: Mesh
		if solid.kind == "box":
			body.transform = Transform3D(solid.basis,solid.middle)
			var box := BoxShape3D.new()
			box.size = solid.size
			shape.shape = box
			var drawn := BoxMesh.new()
			drawn.size = solid.size
			mesh = drawn
		else:
			body.transform = Transform3D(Basis.IDENTITY,solid.middle)
			var cyl := CylinderShape3D.new()
			cyl.radius = solid.radius
			cyl.height = solid.height
			shape.shape = cyl
			var drawn := CylinderMesh.new()
			drawn.top_radius = solid.radius
			drawn.bottom_radius = solid.radius
			drawn.height = solid.height
			drawn.radial_segments = 24
			mesh = drawn
		body.add_child(shape)
		if material.is_valid():
			var m := MeshInstance3D.new()
			m.mesh = mesh
			m.material_override = material.call(solid.kind)
			body.add_child(m)
		root.add_child(body)
	return root

## True if the straight line from `from` to `to` is clear of every solid
## (physics, LAYER).
static func line_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	if space == null: return true
	var query := PhysicsRayQueryParameters3D.create(from,to,LAYER)
	return space.intersect_ray(query).is_empty()

## The station's geometry per gap (the leg into each token, from the entry
## or the token before): the least clearance (m, from the line's middle to
## the nearest solid, less half the wingspan) along the smooth line through
## the tokens (FlightMetrics `line`), and the room for error: that, capped
## by the token's reach. Where level wings don't fit but the plane on a
## knife edge does (`survey`), the room is the knife edge's, and the gap is
## marked `knife`.
static func rooms(s: Dictionary, line: Array) -> Array:
	return survey(s,line).rooms

## The knife-edge zones on the line (`survey`): [{"gap", "start", "end",
## "mid" (world Vector3), "way" (unit, start to end), "length", "room"}].
static func knife_zones(s: Dictionary, line: Array) -> Array:
	return survey(s,line).zones

## The plane's half thickness (m): on a knife edge all the width it needs
## (RuinBump BODY.y, the slab it bumps with, which turns with its bank, so
## the bump already lets a plane on edge through a gap its wings would not).
const HALF_THICK := 0.15
## How many points along the wings `wing_room` tests, tip to tip.
const WING_POINTS := 5
## A sample of the line needs the knife edge where level wings don't fit
## and on edge the plane has at least KNIFE_BETTER m more room.
const KNIFE_BETTER := 0.2
static var _surveys := {}

## The room (m) round a plane at `p` with its wings along `wings` (unit):
## the least clearance of WING_POINTS points from tip to tip, less
## HALF_THICK.
static func wing_room(all: Array, p: Vector3, wings: Vector3) -> float:
	var least := INF
	for i in range(WING_POINTS):
		var k := lerpf(-SPAN*0.5,SPAN*0.5,float(i)/(WING_POINTS-1))
		least = minf(least,clearance(all,p+wings*k))
	return least-HALF_THICK

## The line surveyed, once per station and line (cached): per gap its least
## clearance and room (`rooms`), and the knife zones (`knife_zones`). A
## sample's room is the sphere's (clearance less half the span, as round 1
## measured it); where that is under 0 it is the better of level wings and
## on edge (`wing_room`), and where on edge is KNIFE_BETTER better than
## level, the sample is a knife sample. Runs of knife samples are the zones.
static func survey(s: Dictionary, line: Array) -> Dictionary:
	# The origin too: a pack's copy of a station has its hash but stands
	# elsewhere, and the zones are in world space.
	var key := station_hash(s)+":"+str(origin(s))+":"+str(line.size())
	if _surveys.has(key): return _surveys[key]
	var all := solids(s)
	var count := int(s.tokens.size())
	var least := []
	least.resize(count)
	least.fill(INF)
	var knife := []
	knife.resize(count)
	knife.fill(false)
	var zones := []
	var zone := {}
	for i in range(line.size()):
		var sample: Dictionary = line[i]
		var g := int(sample.gap)
		var p: Vector3 = sample.p
		var room := clearance(all,p)-SPAN*0.5
		var on_edge := false
		var edge_room := room
		if room < 0.0:
			var a: Vector3 = (line[maxi(i-1,0)].p as Vector3)
			var b: Vector3 = (line[mini(i+1,line.size()-1)].p as Vector3)
			var way := (b-a).normalized() if a.distance_to(b) > 0.0001 else Vector3.FORWARD
			var level := way.cross(Vector3.UP)
			level = level.normalized() if level.length() > 0.01 else Vector3.RIGHT
			var edge := level.cross(way).normalized()
			var flat := wing_room(all,p,level)
			edge_room = wing_room(all,p,edge)
			on_edge = flat < 0.0 and edge_room >= flat+KNIFE_BETTER
			room = maxf(room,maxf(flat,edge_room))
		if g >= 0 and g < count:
			least[g] = minf(float(least[g]),room)
			if on_edge: knife[g] = true
		if on_edge:
			if zone.is_empty() or i-int(zone.last) > 2:
				if not zone.is_empty(): zones.append(_zone(zone))
				zone = {"gap":g,"start":p,"end":p,"first":i,"last":i,"room":edge_room}
			zone.end = p
			zone.last = i
			zone.room = minf(float(zone.room),edge_room)
	if not zone.is_empty(): zones.append(_zone(zone))
	var out := []
	for g in range(count):
		var r := {"clearance":least[g],"room":minf(reach(s),float(least[g]))}
		if knife[g]: r["knife"] = true
		out.append(r)
	_surveys[key] = {"rooms":out,"zones":zones}
	return _surveys[key]

static func _zone(z: Dictionary) -> Dictionary:
	var a: Vector3 = z.start
	var b: Vector3 = z.end
	var way := (b-a).normalized() if a.distance_to(b) > 0.01 else Vector3.FORWARD
	return {"gap":z.gap,"start":a,"end":b,"mid":(a+b)*0.5,"way":way,"length":a.distance_to(b),"room":z.room,"first":z.first,"last":z.last}
