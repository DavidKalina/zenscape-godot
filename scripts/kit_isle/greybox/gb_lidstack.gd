extends "res://scripts/kit_isle/motif_greybox.gd"
## Lidstack in the generator: studies/greybox/lidstack.gd's layout, the same
## geometry in the same frame, so its climb and its chains keep the study's
## numbers. A necropolis stacked upward: six square terraces round a hollow
## colossus column (the chimney), a voussoir gallery on terrace 3, the
## tumbling lid on terrace 4's south strip, a summit cannon.
##
## Changes from the study:
##  - THE PIT CANNON (the real catch)
##    replaces the study's two stand-ins on combo 1, the terrace-2 grate vent
##    and the CatchCannon on its plinth: a real cannon stands on terrace 2's
##    floor under row B (terrace 3's false lid), barrel up steep. A body the
##    lid knocks south lands on row B, the slab drops, and he falls straight
##    into the mouth: caught (stunned in, stunned out), fired out to the exit
##    isle. Walk onto row B on purpose and you fall into it too. The plinth
##    is gone.
##  - The exit isle (the study's stand-in "next isle", PORT out) is part of
##    the motif, moved in to where the pit cannon can reach (its shot is
##    capped by the motor's terminal speed, about 30 m); the summit cannon
##    aims at it too, solved in code as the study does. The rim out is its
##    far (south) edge.
##  - The rim in is terrace 1's south-west edge, by the study's start.
##
## Turf pass (motif-turf skill, as the Sunken Giant's): the landing ring
## (terrace 1) and the exit isle are KitLand islands, flat at the greybox
## heights, turf and flora on top, hanging rock and a keel under. The stack
## itself (terraces 2-6, the colossus column and its chimney, the stairs,
## the lid ladder) is built masonry in the Olmec basalt (giant_stone.gd),
## every block collided as its greybox walk box, so the chains keep their
## numbers to the centimetre; a lit rune band rings the summit (whoever died
## last is at the top). A carved chest on the summit pad. `--lidstack-grey`
## builds the grey boxes instead (A/B checks).
const Tumble = preload("res://scripts/traps/trap_tumble.gd")
const Voussoirs = preload("res://scripts/traps/trap_voussoirs.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")

# --- The study's numbers, verbatim (studies/greybox/lidstack.gd) -------------------------
const UNDER := -20.0
const RISE := 7.2
const RISER := 0.4
const MASS := {
	"name":"lidstack",
	"tiers":[["T1 landing ring",22.0,0.0],["T2",16.0,7.2],["T3",14.0,14.4],["T4",12.0,21.6],["T5",7.5,28.8],["T6 summit",5.5,36.0]],
	"core":{"outer":Rect2(-2.4,-4.0,4.8,8.0),"wall":1.0,"top":36.0},
	"openings":[
		["door","S",-0.8,0.8,0.0,2.6],
		["T3 window","W",-1.2,1.2,14.4,17.4],
		["T4 vent window (faces the lid)","S",-1.2,1.2,21.6,26.0],
		["T5 window","E",-1.2,1.2,28.8,31.8],
	],
	"cuts":[
		["door corridor",Rect2(-2.5,4.0,5.0,12.0),1,3.6],
		["T3 window passage (west)",Rect2(-12.5,-2.5,10.1,5.0),3,3.6],
		["T4 vent passage (south, onto the lid)",Rect2(-2.5,4.0,5.0,1.4),4,4.6],
		["T5 window passage (east)",Rect2(2.4,-2.5,3.1,5.0),5,3.6],
	],
}
const STAIRS := [
	["S1 ring -> T2","x",17.0,2.0,3.0,13.0,0.0,7.2],
	["S2 T2 -> T3","z",15.0,2.0,12.0,0.0,7.2,14.4],
	["S3 T3 -> T4","x",-13.0,2.0,2.0,-12.0,14.4,21.6],
	["S4 T4 -> T5 (from the south strip)","z",8.5,2.0,6.0,-6.0,21.6,28.8],
]
const LADDERS := [["lid ladder T5 -> T6","x",5.5,7.5,7.5,2.5,4,1.6,28.8]]
## The study's BOXES less the catching cannon's plinth (the pit cannon took its job).
const BOXES := [
	["S2 deck (T3 level)",Rect2(14.0,-14.0,2.0,14.0),7.2,14.4,"grey"],
	["summit chest (pad)",Rect2(-4.8,-1.0,2.0,2.0),36.0,36.8,"pad"],
]
const TUMBLE := {"axis":Vector3(0.0,21.6,8.67),"yaw":0.0,"knobs":{"size":4.5},"cut":[3,4],"clear":0.15}
const VOUSSOIRS := [
	{"name":"row A: T3 gallery","at":Vector3(14.0,14.4,-13.0),"yaw":90.0,"knobs":{"count":10,"width":2.0},"cut":Rect2(2.0,-14.0,12.0,2.0),"tiers":[2,2]},
	{"name":"row B: the false lid under the heavy lid","at":Vector3(0.0,14.4,15.5),"yaw":0.0,"knobs":{"count":5,"width":4.8},"cut":Rect2(-2.4,9.5,4.8,6.0),"tiers":[2,2]},
]
## The study's T4 window vent (STAND-IN updraft: kick up the chimney into it,
## thrown onto the lid's top). The T2 grate vent is gone (the pit cannon).
const VENTS := [
	{"name":"T4 window vent (combo 2)","at":Vector3(0.0,23.0,2.0),"size":Vector3(2.6,3.6,2.0),"to":"lid","apex":1.2,"grounded":false,"cool":1.2},
]
## The exit isle (PORT out): its middle (top) and width. The study's sat at
## z 46; in here to the pit cannon's reach. Both cannons are aimed at it.
const EXIT := {"centre":Vector3(0.0,2.0,38.0),"wide":8.0}
const CANNONS := [{"at":Vector3(3.9,36.0,3.9),"aim":"exit"}]
const KEGS := [Vector3(-4.0,36.0,-3.4),Vector3(-4.0,36.0,3.2)]
## THE PIT CANNON (real catch): its base on terrace 2's floor under row B,
## its pitch the steepest that still reaches the exit isle (a body falling
## plumb comes in within the catch cone).
const PIT := {"at":Vector3(0.0,7.2,11.2),"pitch":60.0}
const START_AT := Vector3(-9.0,0.0,19.0)
const LABELS := [
	[Vector3(-9.0,2.5,15.0),"BEAT 1  arrive: terrace 1, a wide low catch"],
	[Vector3(-4.0,4.0,16.5),"BEAT 2  the pointed door -> the chimney (wall-kick up, 2.8 m between walls)"],
	[Vector3(10.0,9.5,17.0),"BEAT 2' outside: stairs S1..S4 round the faces"],
	[Vector3(14.0,17.0,-8.0),"BEAT 3  row A, the voussoir gallery: RUN (first slab only tests)"],
	[Vector3(0.0,25.5,11.5),"BEAT 4  the tumbling lid, crossed along its axis: late and it KNOCKS you south, down the stack (COMBO 1)"],
	[Vector3(0.0,17.5,15.0),"row B: terrace 3's false lid over the pit cannon (a knocked body lands here; the slab drops it in)"],
	[Vector3(0.0,12.0,17.0),"THE PIT CANNON: fall in, get fired out to the exit isle"],
	[Vector3(0.0,27.0,5.0),"BEAT 4b  T4 window: STAND-IN updraft vent. Kick up the chimney into it: thrown onto the lid's top"],
	[Vector3(-12.0,17.5,0.0),"T3 window passage: leave the chimney here onto the terrace-3 ring"],
	[Vector3(5.0,33.5,6.5),"T5 lid ladder (orange lips, 1.6 m each = SET_OFF)"],
	[Vector3(-3.5,38.5,0.0),"summit: chest pad (green) . the chimney's open top is a rim to hang from"],
	[Vector3(4.0,39.0,4.0),"COMBO 3  cannon: climb in (Y), A launches: aimed at the exit isle"],
]

func slug() -> String:
	return "lidstack"

func isle_name() -> String:
	return "Lidstack"

func epithet() -> String:
	return "Each lid says: lay one more above me."

func brief() -> String:
	return "Climb the stack: stairs round the faces, or the door and the chimney (wall-kick). Run row A, cross the tumbling lid east on terrace 4.\nLate on the lid and it knocks you down onto the false lid, into the pit cannon: fired out. Or fire yourself from the summit cannon."

func start() -> Vector3:
	return START_AT

## The void under the lid's sweep (x, z), as the study's `lane_rect`.
static func lane_rect() -> Rect2:
	var s := float(TUMBLE.knobs.size)
	var clear := float(TUMBLE.clear)
	var along := s*0.5+clear
	var across := s*sqrt(0.5)+clear
	var a: Vector3 = TUMBLE.axis
	var axis := Basis(Vector3.UP,deg_to_rad(float(TUMBLE.yaw)))*Vector3.RIGHT
	if absf(axis.x) > 0.5: return Rect2(a.x-along,a.z-across,along*2.0,across*2.0)
	return Rect2(a.x-across,a.z-along,across*2.0,along*2.0)

static func exit_rect() -> Rect2:
	var mid: Vector3 = EXIT.centre
	var w := float(EXIT.wide)
	return Rect2(mid.x-w*0.5,mid.z-w*0.5,w,w)

func parts() -> Array:
	var extra: Array = [["tumble lane",lane_rect(),int(TUMBLE.cut[0]),0.0,int(TUMBLE.cut[1])]]
	for v: Dictionary in VOUSSOIRS: extra.append([v.name,v.cut,int(v.tiers[0]),0.0,int(v.tiers[1])])
	var out := structure(extra)
	var mid: Vector3 = EXIT.centre
	out.append(["box",exit_rect(),mid.y-3.0,mid.y,"pad"])
	for l: Array in LABELS: out.append(["label",l[0],l[1]])
	out.append(["label",mid+Vector3.UP*1.5,"EXIT ISLE: both cannons land you here; the way on leaves its far (south) edge"])
	return out

## In on terrace 1's south-west (the study's start), out off the exit isle's far edge.
func rims() -> Array:
	var e := exit_rect()
	return [
		{"name":"landing","at":Vector3(-21.0,0.0,19.0),"face":Vector3(-1.0,0.0,0.0),"run_up":12.0,"lip":1.0},
		{"name":"exit","at":Vector3(e.get_center().x,float(EXIT.centre.y),e.end.y-1.0),"face":Vector3(0.0,0.0,1.0),"run_up":7.0,"lip":1.0},
	]

func spots() -> Array:
	return [
		{"kind":"arena","name":"landing_ring","at":Vector3(0.0,0.0,-19.0),"room":3.0},
		{"kind":"cover","name":"t2_corner","at":Vector3(-15.0,7.2,-15.0),"room":1.0},
		{"kind":"perch","name":"t3_corner","at":Vector3(-13.0,14.4,-13.0),"room":1.0},
		{"kind":"perch","name":"summit","at":Vector3(-4.0,36.0,3.0),"room":2.0},
	]

# --- The study's structure builder, as statics -------------------------------------------

static func _cut_on(c: Array, i: int) -> bool:
	if float(c[3]) > 0.0: return i == int(c[2])
	return i >= int(c[2]) and i <= (int(c[4]) if c.size() > 4 else 99)

## Each tier a layer (the tier below's top to its own) over its square, less the open cuts
## on it; a roofed passage starting on it leaves its roof (ceiling to top) standing.
static func structure(extra_cuts: Array) -> Array:
	var parts := []
	var tiers: Array = MASS.tiers
	var core_rect: Rect2 = MASS.core.outer
	var cuts: Array = MASS.cuts.duplicate()
	cuts.append_array(extra_cuts)
	for i in tiers.size():
		var half := float(tiers[i][1])
		var top := float(tiers[i][2])
		var bottom := UNDER if i == 0 else float(tiers[i-1][2])
		var colour := "floor" if i%2 == 0 else "wall"
		var room := Rect2(-half,-half,half*2.0,half*2.0)
		var open: Array[Rect2] = [core_rect]
		var holes: Array[Rect2] = [core_rect]
		var roofs: Array = []
		for c: Array in cuts:
			if not _cut_on(c,i): continue
			var r: Rect2 = (c[1] as Rect2).intersection(room)
			if r.size.x <= 0.0 or r.size.y <= 0.0: continue
			holes.append(r)
			if float(c[3]) <= 0.0: open.append(r)
			elif i == int(c[2]): roofs.append([r,bottom+float(c[3])])
		for rect: Rect2 in floor_rects(room,holes): parts.append(["box",rect,bottom,top,colour])
		for rf: Array in roofs:
			if top <= float(rf[1]): continue
			for rect: Rect2 in floor_rects(rf[0] as Rect2,open): parts.append(["box",rect,float(rf[1]),top,colour])
	parts.append(["box",core_rect,UNDER,0.0,"floor"])
	parts.append_array(_core_walls())
	for s: Array in STAIRS: parts.append_array(_stairs(s))
	for l: Array in LADDERS: parts.append_array(_ladder(l))
	for b: Array in BOXES: if float(b[3]) > float(b[2]): parts.append(["box",b[1],b[2],b[3],b[4]])
	return parts

## character_study.gd's `_floor_rects`, verbatim: `room` less the holes, as rects.
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

static func _core_walls() -> Array:
	var out := []
	var o: Rect2 = MASS.core.outer
	var w := float(MASS.core.wall)
	var top := float(MASS.core.top)
	var walls := {
		"N":Rect2(o.position.x,o.position.y,o.size.x,w),
		"S":Rect2(o.position.x,o.end.y-w,o.size.x,w),
		"W":Rect2(o.position.x,o.position.y+w,w,o.size.y-2.0*w),
		"E":Rect2(o.end.x-w,o.position.y+w,w,o.size.y-2.0*w),
	}
	for k: String in walls:
		var r: Rect2 = walls[k]
		var along := k == "N" or k == "S"
		var lo: float = r.position.x if along else r.position.y
		var hi: float = r.end.x if along else r.end.y
		var ops := []
		var marks := [lo,hi]
		for op: Array in MASS.openings:
			if op[1] != k: continue
			ops.append(op)
			marks.append(clampf(float(op[2]),lo,hi))
			marks.append(clampf(float(op[3]),lo,hi))
		marks.sort()
		for m in range(marks.size()-1):
			var p: float = marks[m]
			var q: float = marks[m+1]
			if q-p < 0.001: continue
			var ranges := [Vector2(0.0,top)]
			for op: Array in ops:
				if float(op[2]) <= (p+q)*0.5 and (p+q)*0.5 <= float(op[3]):
					var cut := Vector2(float(op[4]),float(op[5]))
					var kept := []
					for yr: Vector2 in ranges:
						if cut.y <= yr.x or cut.x >= yr.y:
							kept.append(yr)
							continue
						if cut.x > yr.x: kept.append(Vector2(yr.x,cut.x))
						if cut.y < yr.y: kept.append(Vector2(cut.y,yr.y))
					ranges = kept
			for yr: Vector2 in ranges:
				if yr.y-yr.x < 0.001: continue
				var seg := Rect2(p,r.position.y,q-p,r.size.y) if along else Rect2(r.position.x,p,r.size.x,q-p)
				out.append(["box",seg,yr.x,yr.y,"lip" if yr.y >= top else "wall"])
	return out

static func _stairs(s: Array) -> Array:
	var out := []
	var n := int(round(absf(float(s[7])-float(s[6]))/RISER))
	var a0 := float(s[4])
	var a1 := float(s[5])
	var d := (a1-a0)/float(n)
	var half := float(s[3])*0.5
	var line := float(s[2])
	for i in n:
		var p := minf(a0+d*i,a0+d*(i+1))
		var q := maxf(a0+d*i,a0+d*(i+1))
		var top := float(s[6])+(float(s[7])-float(s[6]))*float(i+1)/float(n)
		var rect := Rect2(p,line-half,q-p,half*2.0) if s[1] == "x" else Rect2(line-half,p,half*2.0,q-p)
		out.append(["box",rect,float(s[6]),top,"grey"])
	return out

static func _ladder(l: Array) -> Array:
	var out := []
	var n := int(l[6])
	var a0 := float(l[4])
	var d := (float(l[5])-a0)/float(n)
	for i in n:
		var p := minf(a0+d*i,a0+d*(i+1))
		var q := maxf(a0+d*i,a0+d*(i+1))
		var rect := Rect2(p,float(l[2]),q-p,float(l[3])-float(l[2])) if l[1] == "x" else Rect2(float(l[2]),p,float(l[3])-float(l[2]),q-p)
		out.append(["box",rect,float(l[8]),float(l[8])+float(l[7])*float(i+1),"lip"])
	return out

# --- Aiming (the study's `aim_at`, with a preferred pitch) ---------------------------------

## A default cannon at `base` aimed to land on `target`: its heading, pitch
## and power notch, among the aims within 0.25 m the one nearest `prefer` (rad).
static func aim_at(base: Vector3, target: Vector3, prefer: float) -> Dictionary:
	var k := Cannon.defaults()
	var p := Cannon.pilot()
	var heading := PilotMotor.facing_of(Vector2(target.x-base.x,target.z-base.z))
	var f := PilotMotor.forward(heading)
	var best := {"heading":heading,"pitch_rest":float(k.pitch_rest),"power_rest":int(k.power_rest),"err":INF}
	var best_score := INF
	for notch in range((k.power_notches as Array).size()):
		var speed: float = float(k.speed_max)*float(k.power_notches[notch])
		var pitch: float = float(k.pitch_min)
		while pitch <= float(k.pitch_max):
			var dir := Vector3(f.x*cos(pitch),sin(pitch),f.y*cos(pitch))
			var mouth: Vector3 = base+Vector3.UP*float(k.base_height)+dir*float(k.barrel_length)
			var vy := speed*sin(pitch)
			var top := mouth.y+vy*vy/(2.0*p.gravity)
			if top >= target.y:
				var t := vy/p.gravity+_fall_time(top-target.y,p)
				var err := absf(speed*cos(pitch)*t-Vector2(target.x-mouth.x,target.z-mouth.z).length())
				var score := err+(0.0 if err < 0.25 else 100.0)+absf(pitch-prefer)
				if score < best_score:
					best_score = score
					best = {"heading":heading,"pitch_rest":pitch,"power_rest":notch,"err":err}
			pitch += deg_to_rad(0.25)
	return best

static func _fall_time(h: float, p: PilotMotor) -> float:
	var g := p.gravity*p.fall
	var d1 := p.terminal*p.terminal/(2.0*g)
	if h <= d1: return sqrt(2.0*maxf(h,0.0)/g)
	return p.terminal/g+(h-d1)/p.terminal

# --- Live ---------------------------------------------------------------------------------

## The traps as the study's `_build_room` makes them (voussoirs, the lid, the
## T4 window vent, the study's own Vent class), the summit cannon and its
## kegs, and the pit cannon, all in the stage's CannonField (`g.cannons()`),
## which catches a body falling into a mouth.
func live(g: Node) -> void:
	var study: GDScript = load(study_path())
	for row: Dictionary in VOUSSOIRS:
		var v: Node3D = Voussoirs.new().configure(row.knobs)
		v.position = g.w(row.at)
		v.rotation_degrees.y = float(row.yaw)
		g.trap(v)
	var tumble: Node3D = Tumble.new().configure(TUMBLE.knobs)
	var basis := Basis(Vector3.UP,deg_to_rad(float(TUMBLE.yaw)))
	var c: Vector3 = tumble.centre()
	tumble.position = g.w(TUMBLE.axis)-basis*Vector3(0.0,0.0,c.z)
	tumble.rotation_degrees.y = float(TUMBLE.yaw)
	g.trap(tumble)
	for vd: Dictionary in VENTS:
		var d := vd.duplicate()
		d.at = g.w(vd.at)
		var vt: Node3D = study.Vent.new()
		vt.setup(d)
		g.trap(vt)
		if String(vd.get("to","")) == "lid": vt.target = tumble.top_point()
		if not grey():
			# On turf the vent's blue box fades to a breath (the giant's updraft).
			for mesh: Node in vt.find_children("*","MeshInstance3D",true,false):
				var mat := (mesh as MeshInstance3D).material_override as StandardMaterial3D
				if mat != null: mat.albedo_color = Color(0.8,0.9,1.0,0.06)
	# The stage makes its CannonField after the greybox hosts (layer_stage.gd
	# `setup`), so the cannons go in once it stands.
	_cannons.call_deferred(g)

## The summit cannon and its kegs, and the pit cannon, in the stage's CannonField.
static func _cannons(g: Node) -> void:
	if not is_instance_valid(g): return
	var field: Node3D = g.cannons()
	if field == null:
		push_warning("lidstack: no CannonField on the stage")
		return
	var exit: Vector3 = g.w(EXIT.centre)
	for cd: Dictionary in CANNONS:
		var at: Vector3 = g.w(cd.at)
		var aim := aim_at(at,exit,deg_to_rad(40.0))
		field.add_cannon(at,float(aim.heading),{"pitch_rest":float(aim.pitch_rest),"power_rest":int(aim.power_rest)})
	for k: Vector3 in KEGS: field.add_keg(g.w(k))
	var pit: Vector3 = g.w(PIT.at)
	var pit_aim := aim_at(pit,exit,deg_to_rad(float(PIT.pitch)))
	var pc: Node3D = field.add_cannon(pit,float(pit_aim.heading),{"pitch_rest":float(pit_aim.pitch_rest),"power_rest":int(pit_aim.power_rest)})
	pc.name = "PitCannon"
	print("lidstack: pit cannon at %s pitch %.1f notch %d (err %.2f m), mouth %s" % [str(pit),rad_to_deg(float(pit_aim.pitch_rest)),int(pit_aim.power_rest),float(pit_aim.err),str(pc.mouth())])

# --- Turf pass: the land and the masonry -------------------------------------------------

const TURF_SEED := 5200
## The landing ring's keel and the exit isle's (m under their tops), and how
## far a keel's spurs can hang under top-depth (the giant's KEEL_REACH).
const LANDING_DEPTH := 20.0
const EXIT_DEPTH := 7.0
const KEEL_REACH := 1.4
## The summit's rune band (y), under the top tier's lip.
const RUNE_Y := 34.6

static func grey() -> bool:
	return preload("res://scripts/launch_args.gd").user_args().has("--lidstack-grey")

## Terrace 1, the landing ring: the T1 square, corners cut.
static func landing_outline() -> Array:
	var h := float(MASS.tiers[0][1])
	return _rounded(Rect2(-h,-h,h*2.0,h*2.0),2.4)

static func exit_outline() -> Array:
	return _rounded(exit_rect(),1.4)

static func _rounded(r: Rect2, cut: float) -> Array:
	var a := r.position
	var b := r.end
	return [Vector2(a.x+cut,a.y),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),Vector2(b.x,b.y-cut),
		Vector2(b.x-cut,b.y),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),Vector2(a.x,a.y+cut)]

## The worn ways: the landing rim round to the door and S1's foot, and
## across the exit isle.
static func paths() -> Array:
	var e := exit_rect()
	return [[Vector2(-20.5,19.0),Vector2(-6.0,18.5),Vector2(0.0,17.0)],[Vector2(0.0,18.0),Vector2(2.5,19.0),Vector2(3.0,17.0)],
		[Vector2(0.0,e.position.y+1.0),Vector2(0.0,e.end.y-1.0)]]

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

## The greybox's solids and the two keels' spurs, so the occupancy keeps the
## generator off the hanging rock.
func _solids() -> Array:
	var out := super._solids()
	if grey(): return out
	for keel: Array in [[landing_outline(),0.0,LANDING_DEPTH],[exit_outline(),float(EXIT.centre.y),EXIT_DEPTH]]:
		var ring: Array = keel[0]
		var box := Rect2(ring[0],Vector2.ZERO)
		for q: Vector2 in ring: box = box.expand(q)
		out.append([box.grow(-1.0),float(keel[1])-float(keel[2])*KEEL_REACH,float(keel[1]),null])
	return out

## Measured headless (the turf build, 2026-10-14).
func build_cost() -> int:
	return 0 if grey() else 520

## Whether a greybox part is ground (the islands take it): terrace 1's layer
## and the column's floor under it, and the exit isle's box.
static func _is_ground(p: Array) -> bool:
	if p[0] != "box": return false
	if float(p[2]) <= UNDER+0.001: return true
	return (p[1] as Rect2).is_equal_approx(exit_rect())

## Turf on the landing ring and the exit isle, the stack in stone.
func build(into: Node3D) -> void:
	if grey():
		super.build(into)
		return
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "Lidstack"
	into.add_child(root)
	var tone := KitLook.turf(TURF_SEED,KitLand.wear_of(paths()))
	var landing := KitLand.island({"outline":landing_outline(),"seed":TURF_SEED,"ground":func(_x: float, _z: float) -> float: return 0.0,
		"top":0.0,"depth":LANDING_DEPTH,"hang":true,"resample":[60.0,120,32],"tone":tone})
	landing.name = "Landing"
	var exit_y := float(EXIT.centre.y)
	var exit := KitLand.island({"outline":exit_outline(),"seed":TURF_SEED+1,"ground":func(_x: float, _z: float) -> float: return exit_y,
		"top":exit_y,"depth":EXIT_DEPTH,"hang":true,"resample":[40.0,48,28],"tone":tone})
	exit.name = "ExitIsle"
	for land: Node3D in [landing,exit]:
		_collide_sides(land)
		root.add_child(land)
		turf(land)
	_masonry(root)
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

## The stack: every greybox box but the ground drawn as a chamfered block of
## the basalt and collided as its walk box; the summit pad a carved chest.
func _masonry(root: Node3D) -> void:
	var m: RefCounted = GiantStone.mesher()
	var solids := Node3D.new()
	solids.name = "Walk"
	root.add_child(solids)
	for p: Array in parts():
		if p[0] != "box" or _is_ground(p): continue
		var r: Rect2 = p[1]
		var bottom := float(p[2])
		var high := float(p[3])
		var colour: String = p[4]
		var place := Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,(bottom+high)*0.5,r.get_center().y))
		var size := Vector3(r.size.x,high-bottom,r.size.y)
		_walk_shape(solids,place,size)
		if colour == "pad": continue
		# The tone: older (darker) low down; lips a fresher cut. Thin
		# blocks (steps, lid rungs, walls) take a small chamfer.
		var tone := 0.86+0.05*clampf(high/RISE,0.0,5.0)
		if colour == "lip": tone *= 1.12
		if size.y >= 3.0 and maxf(size.x,size.z) >= 4.0:
			_courses(m,r,bottom,high,tone)
			continue
		var bevel := 0.35
		if size.y < 1.7 or minf(size.x,size.z) < 1.2: bevel = 0.08
		m.box(place,size,bevel,maxf(bottom,0.0),tone)
	# The summit's rune band round the top tier (the south face's east end
	# is behind the lid ladder).
	var h := float(MASS.tiers[5][1])
	m.runes(Vector3(-h,RUNE_Y,-h),Vector3(h,RUNE_Y,-h),Vector3.UP,Vector3(0,0,-1),1.0)
	m.runes(Vector3(h,RUNE_Y,-h),Vector3(h,RUNE_Y,h),Vector3.UP,Vector3(1,0,0),2.0)
	m.runes(Vector3(-h,RUNE_Y,h),Vector3(-h,RUNE_Y,-h),Vector3.UP,Vector3(-1,0,0),3.0)
	m.runes(Vector3(2.4,RUNE_Y,h),Vector3(-h,RUNE_Y,h),Vector3.UP,Vector3(0,0,1),4.0)
	var body := MeshInstance3D.new()
	body.name = "Stack"
	body.mesh = GiantStone.mesh_of(m)
	root.add_child(body)
	root.set_meta("stone_triangles",m.triangles())
	for b: Array in BOXES:
		if b[4] != "pad": continue
		var r: Rect2 = b[1]
		var chest: Node3D = RuinKit.piece("tomb_chest",TURF_SEED+20,0.3)
		chest.position = Vector3(r.get_center().x,float(b[2]),r.get_center().y)
		root.add_child(chest)

## A big block laid as masonry: courses COURSE m tall, each of slabs about
## SLAB m long along the block's long side, the joints staggered course to
## course, each slab its own tone. Drawn only (the walk box is the block).
const COURSE := 2.4
const SLAB := 4.6
static func _courses(m: RefCounted, r: Rect2, bottom: float, high: float, tone: float) -> void:
	var n := maxi(1,int(round((high-bottom)/COURSE)))
	var ch := (high-bottom)/float(n)
	var along_x := r.size.x >= r.size.y
	var length := r.size.x if along_x else r.size.y
	var start := r.position.x if along_x else r.position.y
	for k in n:
		var y0 := bottom+ch*k
		var cuts: Array[float] = [start]
		var a := start+(SLAB*0.5 if k%2 == 1 else SLAB)
		while a < start+length-SLAB*0.45:
			cuts.append(a)
			a += SLAB
		cuts.append(start+length)
		for i in range(cuts.size()-1):
			var s := Rect2(cuts[i],r.position.y,cuts[i+1]-cuts[i],r.size.y) if along_x else Rect2(r.position.x,cuts[i],r.size.x,cuts[i+1]-cuts[i])
			var mid := Vector3(s.get_center().x,y0+ch*0.5,s.get_center().y)
			var jitter := 0.94+0.12*fposmod(sin(mid.x*12.9898+mid.y*78.233+mid.z*37.719)*43758.5453,1.0)
			m.box(Transform3D(Basis.IDENTITY,mid),Vector3(s.size.x,ch,s.size.y),0.14,maxf(bottom,0.0),tone*jitter)

static func _walk_shape(solids: Node3D, place: Transform3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.transform = place
	var c := CollisionShape3D.new()
	c.shape = _box_shape(size)
	body.add_child(c)
	solids.add_child(body)
