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
## Each expands into world-space solids (`solids`): {"kind":"box","middle",
## "size","basis"} or {"kind":"cyl","middle","radius","height"}, which the
## study draws and gives colliders on the ruins' layer (scripts/ruin_bump.gd
## LAYER), so the plane bumps off them as it does off the Sundered hall's
## stone: never a crash, a share of its speed lost. The floor is the plane's
## ground (it skims along it). Signed distances to the solids (`distance`)
## give the room round the line.

const PlaneFigure = preload("res://scripts/plane_figure.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const Lines = preload("res://scripts/collectible_lines.gd")

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
const REACH := Lines.PLANE_REACH+0.5*1.2
## The token drawn (m across), as the game's air tokens.
const TOKEN_SIZE := 1.2
## The plane's wingspan (scripts/plane_figure.gd).
const SPAN := PlaneFigure.SPAN
## Bumped into: the collision layer (the ruins', as RuinBump reads it).
const LAYER := RuinBump.LAYER
## Bumped into the data format or the reach: older runs keep their own hash.
const VERSION := 1

const STATIONS := [
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
	{"id":"sundered","key":9,"name":"Sundered hall (gate, cloister, slit, apse)","intent":"hard","parts":[
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
]

## The station with `id`, or {}.
static func station(id: String) -> Dictionary:
	for s: Dictionary in STATIONS:
		if s.id == id: return s
	return {}

static func station_by_key(key: int) -> Dictionary:
	for s: Dictionary in STATIONS:
		if int(s.key) == key: return s
	return {}

static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for s: Dictionary in STATIONS: out.append(s.id)
	return out

## Where station `s` stands in the world: its entry point.
static func origin(s: Dictionary) -> Vector3:
	return Vector3(float(STATIONS.find(s))*SPACING,ALT,0.0)

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
	return var_to_str([VERSION,REACH,s.parts,s.tokens]).md5_text().substr(0,12)

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
				out.append_array(_bay(at+(part[1] as Vector3),float(part[2]),part[3]))
	return out

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
##           knife-edge slit (KNIFE) through it
##   torn    1 the bay line torn (columns snapped, no beam), 2 the far end
##           torn; either way the bay's walls stand low
##   beam    false: no roof beam at the bay line (an open bay after an
##           open bay)
##   last    the bay closes the piece: a column line at x BAY too
## Simplified from the real bay: plain boxes and drums, no gables, lancets,
## doors, buttresses, fallen beams, rubble or parapets; one height for
## torn and open walls.
static func _bay(at: Vector3, yaw: float, plan: Dictionary) -> Array:
	var turn := Basis(Vector3.UP,yaw+PI*0.5)
	var out := []
	var put := func(middle: Vector3, size: Vector3) -> void: out.append(_box(at+turn*middle,size,turn))
	var bay := Hall.BAY
	var torn := int(plan.get("torn",0))
	var roof: String = plan.get("roof","whole")
	var soffit := Hall.COLUMN_H+Hall.BEAM.x
	# The floor: the podium's top at y 0.
	put.call(Vector3(bay*0.5,-1.0,0.0),Vector3(bay,2.0,2.0*Hall.WALL_Z+Hall.WALL_THICK))
	# The column lines, each with its roof beam across, wall to wall.
	var lines := [0.0]
	if bool(plan.get("last",false)): lines.append(bay)
	for x: float in lines:
		var snapped := (x == 0.0 and torn & 1 != 0) or (x > 0.0 and torn & 2 != 0)
		var h := TORN_SNAP if snapped else Hall.COLUMN_H
		var zs: Array = [-Hall.ROW_Z,Hall.ROW_Z]
		if x == 0.0: zs.append_array(plan.get("inner",[]))
		for z: float in zs:
			out.append({"kind":"cyl","middle":at+turn*Vector3(x,h*0.5,z),"radius":Hall.COLUMN_R,"height":h})
		if not snapped and (x > 0.0 or bool(plan.get("beam",true))):
			put.call(Vector3(x,Hall.COLUMN_H+Hall.BEAM.x*0.5,0.0),Vector3(Hall.BEAM.y*2.0,Hall.BEAM.x,2.0*Hall.WALL_Z))
	# The tie across the nave at the bay line.
	var tie: String = plan.get("tie","")
	if tie != "":
		var tie_y := Hall.TIE_LOW if tie == "low" else Hall.TIE_HIGH
		put.call(Vector3(0.0,tie_y+Hall.TIE_DEPTH*0.5,0.0),Vector3(Hall.BEAM.y*2.0,Hall.TIE_DEPTH,2.0*Hall.ROW_Z))
	# The architraves along the rows and the roof's six strips.
	if roof != "open" and torn == 0:
		for k: float in [-1.0,1.0]:
			put.call(Vector3(bay*0.5,Hall.COLUMN_H+Hall.BEAM.x*0.5,k*Hall.ROW_Z),Vector3(bay,Hall.BEAM.x,Hall.BEAM.y*2.0))
		var edges := [-Hall.WALL_Z-0.5,-Hall.ROW_Z,-Hall.ROW_Z*0.5,0.0,Hall.ROW_Z*0.5,Hall.ROW_Z,Hall.WALL_Z+0.5]
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
		var z := side*Hall.WALL_Z
		var size := Vector3(bay,high,Hall.WALL_THICK)
		if kind == "arch":
			var w := Hall.ARCH.x
			var top := Hall.ARCH.z
			var jamb := (bay-w)*0.5
			put.call(Vector3(jamb*0.5,high*0.5,z),Vector3(jamb,high,Hall.WALL_THICK))
			put.call(Vector3(bay-jamb*0.5,high*0.5,z),Vector3(jamb,high,Hall.WALL_THICK))
			put.call(Vector3(bay*0.5,(top+high)*0.5,z),Vector3(w,high-top,Hall.WALL_THICK))
		else:
			put.call(Vector3(bay*0.5,high*0.5,z),size)
	# The screen across the left of the nave, its knife-edge slit.
	if bool(plan.get("screen",false)):
		var z := -(Hall.ROW_Z+Hall.INNER_Z)*0.5
		var span := (Hall.ROW_Z-Hall.INNER_Z)*0.5-Hall.COLUMN_R+0.06
		var high := (Hall.TIE_LOW if tie == "low" else (Hall.TIE_HIGH if tie == "high" else 7.0))-0.02
		var half := Hall.KNIFE.x*0.5
		var head := Hall.KNIFE.y+Hall.KNIFE.z
		var thick := 0.9
		put.call(Vector3(0.0,high*0.5,(z-span+z-half)*0.5),Vector3(thick,high,span-half))
		put.call(Vector3(0.0,high*0.5,(z+half+z+span)*0.5),Vector3(thick,high,span-half))
		put.call(Vector3(0.0,Hall.KNIFE.y*0.5,z),Vector3(thick,Hall.KNIFE.y,Hall.KNIFE.x))
		put.call(Vector3(0.0,(head+high)*0.5,z),Vector3(thick,high-head,Hall.KNIFE.x))
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
## `material` (a Callable(kind) -> Material) they are drawn too.
static func build(s: Dictionary, parent: Node3D, material := Callable()) -> Node3D:
	var root := Node3D.new()
	root.name = "Station_"+str(s.id)
	parent.add_child(root)
	for solid: Dictionary in solids(s):
		var body := StaticBody3D.new()
		body.collision_layer = LAYER
		body.collision_mask = 0
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
## by the token's reach.
static func rooms(s: Dictionary, line: Array) -> Array:
	var all := solids(s)
	var least := []
	least.resize(int(s.tokens.size()))
	least.fill(INF)
	for sample: Dictionary in line:
		var g := int(sample.gap)
		if g < 0 or g >= least.size(): continue
		least[g] = minf(float(least[g]),clearance(all,sample.p)-SPAN*0.5)
	var out := []
	for g in range(least.size()):
		out.append({"clearance":least[g],"room":minf(REACH,float(least[g]))})
	return out
