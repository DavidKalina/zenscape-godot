extends "res://studies/character_study.gd"
## GREYBOX, Opus pass: the Vigil of the Bellows
## (docs/design/roguelike/brainstorm/round1/motif-m3-the-vigil-of-the-bellows.md,
## its "Greybox (Opus pass)" section). A cloister garth round a still pool:
## the star-watchers' tower on the north side with a wind horn on a corbel
## over its sill, a gate tower on the south range with a second horn, and
## four arcade ranges round the garth. The two horns face each other across
## the garth and share one bellows (one breath at a time). Each watches the
## far half, under its own pitch, and blows it away from itself: the tower
## horn blows the court's middle south into the south bays, the gate horn
## blows the north half north into the north bays, the tower's kick shaft
## or out through the fallen north-east corner to satellite 1.
##   godot --path . res://studies/greybox/vigil_bellows.tscn -- --no-title
##     [--gust-out=<m>] [--gust-up=<m>]  (override the blaster's numbers)
##     [--no-tech]                       (the tech is on here: chain 2)
## Number keys (0, - also): 1 start (W satellite) · 2 west bays · 3 pool
## stones · 4 tower shaft · 5 the sill · 6 chain 1 · 7 chain 2 · 8 chain 3 ·
## 9 chain 4 · 0 the wall-walk · - the lavabo. R back to the start.
##   H  the gate horn on/off      J  the tower horn on/off
##   K  knock both horns out for 6 s (STAND-IN for the bell-style hit)
##   F1 numbers (horn states, the bellows, the last gust, his stun)
## REAL: the wind horn (RuinKitHorn.wind_horn: its Rig turns at TURN_RATE,
## pitches only PITCH_DOWN under level, draws breath, kicks), the pilot, the
## water, trap_seesaw_drop. The gust is the wind blaster's own knock:
## motor.knock(motor.knock_velocity(way, blast_out, blast_up), source) with
## the blaster's knob values read from scripts/traps/trap_wind_blaster.gd
## (delay, blast_time, rearm, blast_out, blast_up), the horn as the source.
## STAND-IN: that the horn blows at all (the Rig only dresses), its wake rule
## (sweep, view, hearing), its yaw arc, the shared bellows, the rope bridges
## (plain decks), the slab bridge, the tower's slit windows and corbel dressing.
## All of the layout is in the tables below, built from them, so a later
## turf pass reads them rather than the code.
const Horn = preload("res://scripts/ruin_kit_horn.gd")
const HornRig = preload("res://scripts/wind_horn.gd")
const Blaster = preload("res://scripts/traps/trap_wind_blaster.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const SeesawDrop = preload("res://scripts/traps/trap_seesaw_drop.gd")

# --- THE LAYOUT (metres; x east, z south, y up; north is -z) ----------------------------------
## Terrain masses. name, rect (x, z), then either `top` or `tiers` ([rect, top,
## colour] stepped heights of one mass), `holes` (rects cut out of the floor).
## All stand on a grey body down to ISLE_BOTTOM.
const ISLE_BOTTOM := -6.0
const ISLES := [
	{"name":"garth","rect":Rect2(-22.0,-18.0,44.0,36.0),"top":0.0,"holes":[Rect2(-15.0,-12.0,12.0,13.0)]},
	{"name":"lavabo isle","rect":Rect2(-11.0,-7.5,4.0,4.0),"top":0.4},
	# The star tower. West flank: the sill (6.0, a lip) and the shaft's west
	# wall. East flank and back: 9.0, the shaft's east (kick) and back walls.
	# The shaft: x -1.4..1.4 (2.8 m), z -18..-12 (6 m), open south.
	{"name":"star tower","rect":Rect2(-6.0,-28.0,12.0,16.0),"tiers":[
		[Rect2(-6.0,-28.0,4.6,16.0),6.0,"lip"],
		[Rect2(1.4,-28.0,4.6,16.0),9.0,"grey"],
		[Rect2(-1.4,-28.0,2.8,10.0),9.0,"grey"],
	]},
	{"name":"sill walk (behind the tower)","rect":Rect2(-6.0,-32.0,12.0,4.0),"top":6.0},
	{"name":"satellite 2 (W, entry)","rect":Rect2(-40.0,0.0,12.0,12.0),"top":0.0},
	{"name":"bridge W (STAND-IN rope)","rect":Rect2(-28.0,5.0,6.0,2.0),"top":0.0},
	{"name":"satellite 1 (NE, exit; its south arm is the east rim)","rect":Rect2(26.0,-34.0,14.0,42.0),"top":0.0},
	{"name":"NE bridge head (STAND-IN rope bridge, wide landing)","rect":Rect2(22.0,-18.0,4.0,26.0),"top":0.0},
	{"name":"satellite 3 (S terrace, seesaw)","rect":Rect2(-22.0,18.0,44.0,16.0),"top":-3.0},
	# Under the fallen NE corner, a step down: catches a gust that carries
	# north out of the corner; a 1.2 m step up onto satellite 1.
	{"name":"NE scree (catch)","rect":Rect2(12.0,-30.0,14.0,12.0),"top":-1.2},
]
## The pool: rect, bed, water surface (wade 0.6 m deep), beaches north and
## south (the gust's axis) so a thrown body skids out of it.
const POOL := {"rect":Rect2(-15.0,-12.0,12.0,13.0),"bed":-0.9,"surface":-0.3}
## Ramps: name, one edge's middle, the other's, width, colour.
const RAMPS := [
	["pool beach N",Vector3(-9.0,0.0,-12.0),Vector3(-9.0,-0.9,-9.6),12.0,"grey"],
	["pool beach S",Vector3(-9.0,0.0,1.0),Vector3(-9.0,-0.9,-1.4),12.0,"grey"],
	["terrace stair to the wall-walk",Vector3(-14.0,-3.0,30.0),Vector3(-14.0,2.4,18.0),2.4,"grey"],
	["sill exit (STAND-IN slab bridge)",Vector3(26.0,0.0,-31.0),Vector3(6.0,6.0,-31.0),2.0,"grey"],
]
## Small solids: name, rect, bottom, top, colour. The ranges' back walls (the
## south one is the wall-walk), the gate tower, the corbel over the sill (the
## tower horn stands on it), the sill's parapet and the shaft's lintel (they
## hide the sill and the climb from the gate horn; the door under the lintel
## is 2.2 m, the shaft floor by its back wall is out of the gate horn's sight).
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
## Posts: middle, radius, bottom, top. The lavabo canopy on one pier (four
## corner posts shadowed the chain 1 spot from the gate horn).
const POSTS := [
	[Vector2(-9.0,-6.2),0.3,0.4,2.7],
]
## The arcade ranges: rect of the bay strip (its long side the way the bays
## run), `bays` roofed bays spaced evenly with open air (ARCADE_GAP) between,
## the roof ARCADE_ROOF (bottom, top), a pier at each roof corner. The NE
## corner (x 12..22, z -18..-1) is fallen: no bays, no wall: the gust line out.
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
## Wind horns (RuinKitHorn): id, foot, yaw (deg, 0 faces south), seed, on at
## the start, `arc` (deg either side of its yaw it can turn: STAND-IN),
## `range` (m). The tower horn is on the corbel over the sill and watches
## the court's middle (its pitch can't reach nearer); the gate horn on the
## gate tower watches the north half.
const HORNS := [
	{"id":"tower","pos":Vector3(-3.5,9.1,-22.0),"yaw":0.0,"seed":3,"on":true,"arc":32.0,"range":32.0},
	{"id":"gate","pos":Vector3(0.0,7.0,15.0),"yaw":180.0,"seed":5,"on":true,"arc":90.0,"range":36.0},
]
## Traps (existing scripts): name, script, foot, yaw (deg; its route -z turned),
## knobs. The seesaw_drop catapult: stand on the far plate, the block falls,
## he is thrown north over the south range, east of the gate tower.
const TRAPS := [
	{"name":"seesaw_drop","script":SeesawDrop,"pos":Vector3(7.5,-3.0,30.0),"yaw":0.0,"knobs":{"ledge":0.0}},
]
## Floating labels: position, text.
const LABELS := [
	[Vector3(-3.5,13.0,-22.0),"TOWER HORN (on the corbel; watches the court's middle, blows it SOUTH)"],
	[Vector3(0.0,11.5,15.0),"GATE HORN (watches the north half, blows it NORTH)"],
	[Vector3(0.0,10.0,-15.0),"STAR TOWER · kick shaft 2.8 m x 6 m (east wall is the kick wall)"],
	[Vector3(-3.8,8.2,-16.0),"SILL 6.0 m · under the tower horn, behind the parapet"],
	[Vector3(16.0,7.5,-31.0),"sill exit to satellite 1 (STAND-IN slab bridge)"],
	[Vector3(19.0,0.6,-24.0),"NE SCREE (catches the corner's spill)"],
	[Vector3(-9.0,3.6,-5.5),"LAVABO (prize)"],
	[Vector3(-9.0,1.4,-11.0),"POOL · a splash wakes both horns"],
	[Vector3(0.0,3.4,10.0),"SOUTH APRON · under both horns' lips (blind)"],
	[Vector3(-18.0,3.2,0.0),"WEST BAYS · roofed (cover from both)"],
	[Vector3(17.0,2.0,-12.0),"NE CORNER FALLEN · the gust line out"],
	[Vector3(-12.0,3.4,17.0),"WALL-WALK 2.4 m (the gate horn sees it past 10 m)"],
	[Vector3(-34.0,1.8,6.0),"BEAT 1 · W satellite (arrive into the horns' blind side)"],
	[Vector3(7.5,-1.0,33.0),"CHAIN 3 · seesaw_drop on the south terrace"],
	[Vector3(33.0,1.8,-20.0),"SATELLITE 1 (exit; next motif)"],
	[Vector3(-12.5,1.6,-8.5),"CHAIN 1 · splash here"],
	[Vector3(0.0,1.6,-6.0),"CHAIN 2 · hop here, tech into the shaft"],
	[Vector3(15.0,1.6,-3.0),"CHAIN 4 · hop here: out to satellite 1"],
]
## Stations. key, name, spawn, face (x, z).
const STATION_ROWS := [
	{"key":1,"name":"Start · W satellite","spawn":Vector3(-34.0,0.0,6.0),"face":Vector2(1.0,0.0)},
	{"key":2,"name":"Beat 2 · west bays","spawn":Vector3(-18.2,0.0,8.0),"face":Vector2(0.0,-1.0)},
	{"key":3,"name":"Beat 3 · pool stones","spawn":Vector3(-1.8,0.0,-5.5),"face":Vector2(-1.0,0.0)},
	{"key":4,"name":"Beat 4 · tower shaft","spawn":Vector3(0.0,0.0,-13.0),"face":Vector2(0.0,-1.0)},
	{"key":5,"name":"Beat 4b · the sill","spawn":Vector3(-3.6,6.0,-15.0),"face":Vector2(0.0,-1.0)},
	{"key":6,"name":"CHAIN 1 · splash, gust into the NW bays","spawn":Vector3(-12.5,-0.9,-8.5),"face":Vector2(0.0,1.0)},
	{"key":7,"name":"CHAIN 2 · gate horn gust, tech, kick shaft, sill","spawn":Vector3(0.0,0.0,-6.0),"face":Vector2(0.0,-1.0)},
	{"key":8,"name":"CHAIN 3 · seesaw launch, gate horn mid-air","spawn":Vector3(7.5,-3.0,33.0),"face":Vector2(0.0,-1.0)},
	{"key":9,"name":"CHAIN 4 · gust line out the NE corner","spawn":Vector3(15.0,0.0,-3.0),"face":Vector2(0.7,-0.7)},
	{"key":10,"name":"Greedy line · the wall-walk","spawn":Vector3(-17.0,2.4,17.0),"face":Vector2(1.0,0.0)},
	{"key":11,"name":"The lavabo","spawn":Vector3(-9.0,0.4,-4.4),"face":Vector2(0.0,-1.0)},
]
# --- The horn stand-in's numbers ---------------------------------------------------------------
## The gust: the wind blaster's knock (scripts/traps/trap_wind.gd `_blast`),
## its knob values read live from trap_wind_blaster.gd: tell = `delay`,
## blow = `blast_time`, rest = `rearm`, across = `blast_out` (run x 3),
## peak = `blast_up` (run x 0.25). --gust-out / --gust-up override.
var gust_out := 0.0
var gust_up := 0.0
var tell_time := 0.5
var blow_time := 0.3
var rest_time := 2.0
## Beam half-angle that a blow at him hits (rad).
const CONE := 0.25
## A mover on the ground is seen above this pace (m/s), within VIEW (rad)
## of where the horn looks. A splash or a body in the air is heard anywhere
## in its arc ("anything in the air": it was built to ward off the dragon).
const NOTICE_PACE := 0.8
const VIEW := 0.6
## The idle sweep across its arc (rad/s) and the share of the arc it sweeps.
const SWEEP := 0.45
const SWEEP_SHARE := 0.85
## Turning on him past the tell at most this long before it blows anyway (s).
const TURN_MAX := 1.5
const KNOCKOUT := 6.0

var horns := {}
var gusts := 0
var last_gust := {}
## The shared bellows: which horn has the breath ("" free).
var bellows := ""
var traps: Node = null
var _tech := true

func _ready() -> void:
	pack = "vigil_bellows"
	var b: Node = Blaster.new()
	gust_out = float(b.knob("blast_out"))
	gust_up = float(b.knob("blast_up"))
	tell_time = float(b.knob("delay"))
	blow_time = float(b.knob("blast_time"))
	rest_time = float(b.knob("rearm"))
	b.free()
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--gust-out="): gust_out = arg.get_slice("=",1).to_float()
		elif arg.begins_with("--gust-up="): gust_up = arg.get_slice("=",1).to_float()
		elif arg == "--no-tech": _tech = false
	super._ready()
	if motor != null: motor.tech = _tech

func _load_pack() -> void:
	var first: Dictionary = STATION_ROWS[0]
	start = first.spawn
	start_face = first.face
	lost = -30.0
	_last_stood = start
	stations = []
	for i in STATION_ROWS.size():
		var row: Dictionary = STATION_ROWS[i]
		var spawn: Vector3 = row.spawn
		stations.append({"key":row.key,"name":row.name,"spawn":spawn,"face":row.face,"sign":spawn+Vector3(0.0,3.2 if i > 0 else 4.0,0.0),
			"parts":_geometry() if i == 0 else []})

## The table as station parts for the character study's builder.
func _geometry() -> Array:
	var parts := []
	for isle: Dictionary in ISLES:
		if isle.has("tiers"):
			for tier: Array in isle.tiers:
				parts.append(["box",tier[0],ISLE_BOTTOM,tier[1],tier[2]])
		else:
			var rect: Rect2 = isle.rect
			var holes: Array[Rect2] = []
			for h: Rect2 in isle.get("holes",[]): holes.append(h)
			var bottom := minf(ISLE_BOTTOM,float(isle.top)-3.0)
			for r in _floor_rects(rect,holes): parts.append(["box",r,bottom,isle.top,"floor"])
	var pool: Rect2 = POOL.rect
	parts.append(["box",pool,ISLE_BOTTOM,POOL.bed,"dark"])
	parts.append(["water",pool,POOL.bed,POOL.surface])
	for b: Array in BOXES: parts.append(["box",b[1],b[2],b[3],b[4]])
	for p: Array in POSTS: parts.append(["cyl",p[0],p[1],p[2],p[3],"grey"])
	for r: Array in RAMPS: parts.append(["ramp",r[1],r[2],r[3],r[4]])
	for bay: Rect2 in bays():
		parts.append(["box",bay,ARCADE_ROOF.x,ARCADE_ROOF.y,"wall"])
		for px: float in [bay.position.x+PIER_R,bay.end.x-PIER_R]:
			for pz: float in [bay.position.y+PIER_R,bay.end.y-PIER_R]:
				parts.append(["cyl",Vector2(px,pz),PIER_R,0.0,ARCADE_ROOF.x,"grey"])
	for l: Array in LABELS: parts.append(["label",l[0],l[1]])
	return parts

## Every bay's roof rect (x, z), from RANGES.
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

## Under a bay's roof at `p` (x, z).
static func under_roof(p: Vector3) -> bool:
	for bay: Rect2 in bays():
		if bay.has_point(Vector2(p.x,p.z)) and p.y < ARCADE_ROOF.x: return true
	return false

func _build_room() -> void:
	super._build_room()
	var field := TrapField.new()
	add_child(field)
	field.attach(self)
	for row: Dictionary in TRAPS:
		var trap: Node3D = (row.script as GDScript).new()
		trap.configure(row.knobs)
		trap.position = row.pos
		trap.rotation_degrees.y = row.yaw
		field.add(trap)
	traps = field
	for row: Dictionary in HORNS:
		var node := Horn.wind_horn(int(row.seed),0.3)
		node.position = row.pos
		node.rotation_degrees.y = row.yaw
		add_child(node)
		var excl: Array[RID] = []
		_collect(node,excl)
		horns[row.id] = {"id":row.id,"node":node,"rig":Horn.rig(node),"mouth":node.get_node("Head/Barrel/Mouth"),"on":bool(row.on),
			"state":"watch","t":0.0,"excl":excl,"fired":0,"hit":false,"arc":deg_to_rad(float(row.arc)),"range":float(row.range),
			"sweep":0.0,"sweep_dir":1.0 if int(row.seed)%2 == 1 else -1.0,"heard":""}

func _collect(n: Node, into: Array[RID]) -> void:
	if n is CollisionObject3D: into.append((n as CollisionObject3D).get_rid())
	for c in n.get_children(): _collect(c,into)

func place(at: Vector3, face: Vector2) -> void:
	if traps != null: traps.reset()
	super.place(at,face)
	bellows = ""
	for id: String in horns:
		var h: Dictionary = horns[id]
		h.state = "watch"
		h.t = 0.0
		h.hit = false
		h.rig.tell(-1.0)

func tick(delta: float) -> void:
	super.tick(delta)
	for id: String in horns: _horn(horns[id],delta)

# --- The horn stand-in ------------------------------------------------------------------------

func _chest() -> Vector3:
	return motor.feet+Vector3(0.0,0.9,0.0)

## The horn's yaw (local, about its foot) toward a world point.
func _yaw_to(h: Dictionary, point: Vector3) -> float:
	var local: Vector3 = (h.node as Node3D).to_local(point)
	return atan2(local.x,local.z)

## The horn could blow at `point`: in range, in its arc, inside its pitch
## (PITCH_DOWN under level, the real rig's: under its lip it can't reach) and
## nothing solid between.
func _can_reach(h: Dictionary, point: Vector3) -> bool:
	var from: Vector3 = (h.mouth as Node3D).global_position
	if from.distance_to(point) > float(h.range): return false
	if absf(_yaw_to(h,point)) > float(h.arc): return false
	var flat := Vector2(point.x-from.x,point.z-from.z).length()
	if atan2(from.y-point.y,maxf(flat,0.01)) > HornRig.PITCH_DOWN+CONE*0.8: return false
	var q := PhysicsRayQueryParameters3D.create(from,point,ground.mask)
	q.exclude = h.excl
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## What wakes it now: "air" (him in the air), "splash" (wading on), "seen"
## (moving faster than NOTICE_PACE inside its VIEW), or "".
func _noise(h: Dictionary) -> String:
	if motor.move == "tumble": return ""
	if not motor.grounded and not motor.on_ledge() and not motor.swimming: return "air"
	var pace := Vector2(motor.velocity.x,motor.velocity.z).length()
	if motor.swimming or motor.wade > 0.03 and pace > 0.2: return "splash"
	if pace > NOTICE_PACE and absf(angle_difference(float(h.rig.yaw),_yaw_to(h,_chest()))) < VIEW: return "seen"
	return ""

func _horn(h: Dictionary, delta: float) -> void:
	var rig: Node = h.rig
	if not h.on or rig.is_disabled():
		h.state = "watch"
		if bellows == h.id: bellows = ""
		return
	var chest := _chest()
	match h.state:
		"watch":
			_sweep(h,delta)
			if bellows == "":
				var why := _noise(h)
				if why != "" and _can_reach(h,chest):
					bellows = h.id
					h.heard = why
					h.state = "tell"
					h.t = 0.0
		"tell":
			# The blaster's `delay` runs from the trigger; the horn turns on
			# him meanwhile (TURN_RATE) and blows once the tell has run and
			# it is on him, or TURN_MAX past the tell anyway (a wasted breath:
			# the blow hits only what is in its beam then).
			_aim(h,chest,delta)
			h.t += delta
			rig.tell(minf(h.t/tell_time,1.0))
			if h.t >= tell_time and (rig.aim_error(chest) < CONE*0.6 or h.t > tell_time+TURN_MAX):
				rig.fired()
				rig.tell(-1.0)
				h.fired += 1
				h.state = "blow"
				h.t = 0.0
				h.hit = false
		"blow":
			# The blaster's blow: for blast_time, the first frame he is in
			# the mouth's beam, knocked once, the horn as the source. It
			# keeps turning on him while it blows.
			_aim(h,chest,delta)
			h.t += delta
			if not h.hit and rig.aim_error(chest) < CONE and _can_reach(h,chest):
				h.hit = true
				_gust(h)
			if h.t >= blow_time:
				if not h.hit: last_gust = {"horn":h.id,"hit":false,"err":snappedf(rig.aim_error(chest),0.01)}
				h.state = "rest"
				h.t = rest_time
		"rest":
			h.t -= delta
			if h.t <= 0.0:
				h.state = "watch"
				h.sweep = float(rig.yaw)
				bellows = ""

## The idle sweep across its arc (STAND-IN patrol), looking level.
func _sweep(h: Dictionary, delta: float) -> void:
	var span := float(h.arc)*SWEEP_SHARE
	h.sweep = float(h.sweep)+float(h.sweep_dir)*SWEEP*delta
	if absf(float(h.sweep)) > span:
		h.sweep = clampf(float(h.sweep),-span,span)
		h.sweep_dir = -float(h.sweep_dir)
	var node := h.node as Node3D
	var s := float(h.sweep)
	h.rig.aim_at(node.to_global(Vector3(sin(s)*20.0,2.2,cos(s)*20.0)),delta)

## Turn toward him (the real rig: TURN_RATE, PITCH_DOWN), kept in its arc.
func _aim(h: Dictionary, point: Vector3, delta: float) -> void:
	var rig: Node = h.rig
	rig.aim_at(point,delta)
	if absf(float(rig.yaw)) > float(h.arc):
		rig.yaw = clampf(float(rig.yaw),-float(h.arc),float(h.arc))
		rig._apply()

func _gust(h: Dictionary) -> void:
	var way: Vector3 = h.rig.facing()
	var away := Vector2(way.x,way.z)
	if away.length() < 0.05: return
	gusts += 1
	var v := motor.knock_velocity(away,gust_out,gust_up)
	last_gust = {"horn":h.id,"hit":true,"why":h.heard,"from":motor.feet.snapped(Vector3.ONE*0.1),"v":v.snapped(Vector3.ONE*0.1),"stuns":motor.stunnable(h.node)}
	motor.knock(v,h.node)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name_panel.visible:
		match (event as InputEventKey).keycode:
			KEY_H:
				horns.gate.on = not horns.gate.on
				return
			KEY_J:
				horns.tower.on = not horns.tower.on
				return
			KEY_K:
				for id: String in horns: horns[id].rig.disabled(KNOCKOUT)
				return
	super._unhandled_input(event)

# --- HUD --------------------------------------------------------------------------------------

func _hint_text() -> String:
	return "Vigil of the Bellows · two horns, one bellows · a splash or a jump wakes them, a run in their sight too · creep, or hide under stone · 1-9,0,- stations (6-9 the chains) · H gate horn · J tower horn · K knock both out · R start · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or horns.is_empty(): return
	var lines := PackedStringArray([_hud.text,""])
	for id: String in horns:
		var h: Dictionary = horns[id]
		lines.append("horn %s %s %s %.1fs · fired %d · could reach you %s" % [id,"ON" if h.on else "off",h.state,h.t,h.fired,"yes" if _can_reach(h,_chest()) else "no"])
	lines.append("bellows %s · gusts %d · tech %s · stun %s · last %s" % [bellows if bellows != "" else "free",gusts,"on" if motor.tech else "off",motor.stunned if motor.stunned != "" else "-",str(last_gust)])
	_hud.text = "\n".join(lines)
