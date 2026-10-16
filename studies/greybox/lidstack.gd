extends "res://studies/character_study.gd"
## LIDSTACK greybox:
## a tall stack of terraces round a hollow colossus column, played with the real pilot
## and the real traps (voussoirs, tumble, cannon). Grey is structure, orange the lips to
## hang from, green a pad. The whole layout is the const table below; the code only
## builds from it (so a later pass can swap the boxes for KitLand tiers).
## Opus pass: the south face is the fall face. The tumbling lid lies on terrace 4's south
## strip, crossed along its axis, and throws south; under it is terrace 3's false lid
## (row B), under that the terrace-2 vent grate, which throws the body to the catching
## cannon on its plinth before the door, which fires it out to the exit isle.
##   1..9, 0, -, =   stations (see STATIONS_TABLE)
##   R               back to the start, the traps rebuilt     F1 numbers
##   godot --path . res://studies/greybox/lidstack.tscn -- --no-title
const Trap = preload("res://scripts/traps/trap.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const Voussoirs = preload("res://scripts/traps/trap_voussoirs.gd")
const Tumble = preload("res://scripts/traps/trap_tumble.gd")
const CannonField = preload("res://scripts/cannon/cannon_field.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")

# --- THE LAYOUT TABLE (x east, z south, y up; metres) -------------------------------------
const UNDER := -20.0
const RISE := 7.2
const RISER := 0.4
## ONE terrain mass: nested square tiers about the origin ([name, half width, top]), the
## colossus column's hollow core through all of them, and the cuts through the tiers.
## Each tier is a layer from the tier below's top to its own. A cut: [name, rect (x,z),
## first tier, roof, last tier (optional, else all above)]. Roof 0 = open: the layer is
## gone there, down to the tier below's top; roof > 0 = a roofed passage in the first
## tier's layer (floor = the tier below's top, ceiling = floor + roof).
const MASS := {
	"name":"lidstack",
	"tiers":[["T1 landing ring",22.0,0.0],["T2",16.0,7.2],["T3",14.0,14.4],["T4",12.0,21.6],["T5",7.5,28.8],["T6 summit",5.5,36.0]],
	"core":{"outer":Rect2(-2.4,-4.0,4.8,8.0),"wall":1.0,"top":36.0},
	## [name, wall (N S W E), from, to (along the wall), sill y, head y]
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
## Stairs: [name, axis (the way they run), line (the other coordinate), width, from, to,
## base y, top y]. Each one runs along the face of the next tier up.
const STAIRS := [
	["S1 ring -> T2","x",17.0,2.0,3.0,13.0,0.0,7.2],
	["S2 T2 -> T3","z",15.0,2.0,12.0,0.0,7.2,14.4],
	["S3 T3 -> T4","x",-13.0,2.0,2.0,-12.0,14.4,21.6],
	["S4 T4 -> T5 (from the south strip)","z",8.5,2.0,6.0,-6.0,21.6,28.8],
]
## Lid ladders (the card's "niche wall" stand-in): [name, axis, other-range lo, hi, from, to,
## count, rise each, base y]. Orange: hang from them.
const LADDERS := [["lid ladder T5 -> T6","x",5.5,7.5,7.5,2.5,4,1.6,28.8]]
## Extra boxes: [name, rect, bottom, top, colour].
const BOXES := [
	["S2 deck (T3 level)",Rect2(14.0,-14.0,2.0,14.0),7.2,14.4,"grey"],
	["summit chest (pad)",Rect2(-4.8,-1.0,2.0,2.0),36.0,36.8,"pad"],
	["catching cannon's plinth (STAND-IN cannon plinth)",Rect2(-1.5,18.5,3.0,3.0),0.0,4.8,"grey"],
]
## The tumbling lid (real): its axis (the middle of its flat top at rest: x, top y, z),
## its yaw (0: it turns about x and throws toward +z, south), knobs, the tiers its lane
## cuts (open void under its sweep) and the clearance round the sweep. Crossed ALONG its
## axis (west to east on terrace 4's south strip), so every knock goes off its south
## side, over terrace 4's edge, down into the pit over row B.
const TUMBLE := {"axis":Vector3(0.0,21.6,8.67),"yaw":0.0,"knobs":{"size":4.5},"cut":[3,4],"clear":0.15}
## Real voussoir rows: [name, at (the way in), yaw, knobs, cut (its void), cut tiers].
## Row A: terrace 3's north gallery to run (combo 2a). Row B: terrace 3's lid under the
## heavy lid (combo 1): a 4.8 m wide row run north from the south edge, so its tester slab
## (slab 0) is at the south end, away from where a knocked body lands.
const VOUSSOIRS := [
	{"name":"row A: T3 gallery","at":Vector3(14.0,14.4,-13.0),"yaw":90.0,"knobs":{"count":10,"width":2.0},"cut":Rect2(2.0,-14.0,12.0,2.0),"tiers":[2,2]},
	{"name":"row B: the false lid under the heavy lid","at":Vector3(0.0,14.4,15.5),"yaw":0.0,"knobs":{"count":5,"width":4.8},"cut":Rect2(-2.4,9.5,4.8,6.0),"tiers":[2,2]},
]
## STAND-IN updraft vents: zone centre and size; what they throw to ("lid": the tumble's
## top, "catch": the catching cannon's barrel) and the apex over the higher end (m), or a
## fixed "toss"; "grounded": only a body on the grate (on its feet or laid down) sets it
## off; cooldown (s).
const VENTS := [
	{"name":"T4 window vent (combo 2)","at":Vector3(0.0,23.0,2.0),"size":Vector3(2.6,3.6,2.0),"to":"lid","apex":1.2,"grounded":false,"cool":1.2},
	{"name":"T2 grate vent (combo 1)","at":Vector3(0.0,7.8,12.5),"size":Vector3(4.8,1.2,6.0),"to":"catch","apex":2.0,"grounded":true,"cool":1.0},
]
## The exit rim isle (PORT out): its middle (top) and width. Both cannons are aimed at it.
const EXIT := {"centre":Vector3(0.0,2.0,46.0),"wide":8.0}
## The summit cannon (real, on foot: Y climbs in, A fires).
const CANNONS := [{"at":Vector3(3.9,36.0,3.9),"aim":"exit"}]
const KEGS := [Vector3(-4.0,36.0,-3.4),Vector3(-4.0,36.0,3.2)]
## STAND-IN catching cannon (the engine's cannon can't take a thrown body): a real cannon
## on the plinth before the door; a stunned body in its zone is held `fuse` s and fired.
const CATCH := {"at":Vector3(0.0,4.8,20.0),"zone":Vector3(3.4,3.2,3.4),"fuse":0.5,"aim":"exit"}
const START_AT := Vector3(-9.0,0.0,19.0)
const LOST_Y := -30.0
## Stations: [key, name, spawn, face (x,z), sign height].
const STATIONS_TABLE := [
	[1,"T1 start: the landing ring",Vector3(-9.0,0.0,19.0),Vector2(0.6,-0.8),5.0],
	[2,"T2 (up S1): the ring to S2",Vector3(10.0,7.2,15.0),Vector2(1.0,0.0),5.0],
	[3,"T3 COMBO 2a: run the voussoir row (north gallery)",Vector3(15.0,14.4,-4.0),Vector2(0.0,-1.0),5.0],
	[4,"T4 COMBO 1: cross the tumbling lid east (late = knocked down the stack)",Vector3(-4.5,21.6,8.9),Vector2(1.0,0.0),5.0],
	[5,"T5: S4 top, to the lid ladder",Vector3(6.5,28.8,-5.0),Vector2(0.0,1.0),5.0],
	[6,"T6 summit",Vector3(-4.0,36.0,3.0),Vector2(1.0,0.0),5.0],
	[7,"COMBO 2b: the chimney door (kick up)",Vector3(0.0,0.0,12.0),Vector2(0.0,-1.0),5.0],
	[8,"COMBO 2b: the T4 window (the vent onto the lid)",Vector3(0.0,21.6,4.6),Vector2(0.0,-1.0),4.0],
	[9,"COMBO 3: the summit cannon",Vector3(3.0,36.0,2.0),Vector2(0.0,1.0),4.0],
	[10,"T4 far deck: past the lid, S4 foot",Vector3(5.0,21.6,9.75),Vector2(-1.0,0.0),4.0],
	[11,"T2 pit mouth: the vent grate under row B",Vector3(0.0,7.2,15.8),Vector2(0.0,-1.0),4.0],
	[12,"T1: watch the catching cannon",Vector3(-6.0,0.0,16.8),Vector2(0.8,0.6),4.0],
]
## Floating labels: [position, text].
const LABELS := [
	[Vector3(-9.0,2.5,15.0),"BEAT 1  arrive: terrace 1, a wide low catch (PORT in: a thrown body lands on this ring)"],
	[Vector3(-4.0,4.0,16.5),"BEAT 2  the pointed door -> the chimney (wall-kick up, 2.8 m between walls)"],
	[Vector3(10.0,9.5,17.0),"BEAT 2' outside: stairs S1..S4 round the faces"],
	[Vector3(14.0,17.0,-8.0),"BEAT 3  row A, the voussoir gallery: RUN (first slab only tests)"],
	[Vector3(0.0,25.5,11.5),"BEAT 4  the tumbling lid, crossed along its axis: late and it KNOCKS you south, down the stack (COMBO 1)"],
	[Vector3(0.0,17.5,15.0),"row B: terrace 3's false lid under the heavy lid (a knocked body lands here; slabs drop it to the grate)"],
	[Vector3(0.0,10.5,17.0),"STAND-IN vent grate (terrace 2): a body on it is thrown to the cannon's barrel"],
	[Vector3(0.0,8.5,21.0),"STAND-IN catching cannon: a stunned body is caught and fired out to the exit isle"],
	[Vector3(0.0,27.0,5.0),"BEAT 4b  T4 window: STAND-IN updraft vent. Kick up the chimney into it: thrown onto the lid's top"],
	[Vector3(-12.0,17.5,0.0),"T3 window passage: leave the chimney here onto the terrace-3 ring"],
	[Vector3(5.0,33.5,6.5),"T5 lid ladder (orange lips, 1.6 m each = SET_OFF)"],
	[Vector3(-3.5,38.5,0.0),"summit: chest pad (green) . the chimney's open top is a rim to hang from"],
	[Vector3(4.0,39.0,4.0),"COMBO 3  cannon: climb in (Y), A launches: aimed at the exit isle"],
	[Vector3(0.0,16.0,-10.0),"STAND-IN: no niche wall piece (lid ladder boxes), no terrace-ring piece (square tiers), no Olmec face, no root ropes"],
]

# --- Pieces made here -----------------------------------------------------------------------

## Several foot pieces in the one `foot_pieces` slot.
class Fan extends Node:
	var parts: Array = []
	func before(delta: float) -> void:
		for p: Node in parts: p.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		for p: Node in parts: p.after(delta,events)
	func pose(figure: Node3D) -> void:
		for p: Node in parts: p.pose(figure)
	func frame(camera: Camera3D, delta: float) -> void:
		for p: Node in parts:
			if p.has_method("frame"): p.frame(camera,delta)
	func reset() -> void:
		for p: Node in parts: p.reset()


## A default cannon standing at `base` aimed to land on `target`: its heading, and the
## pitch and power notch (nearest the rest pitch among those within 0.25 m).
static func aim_at(base: Vector3, target: Vector3) -> Dictionary:
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
				var t := vy/p.gravity+Vent.fall_time(top-target.y,p)
				var err := absf(speed*cos(pitch)*t-Vector2(target.x-mouth.x,target.z-mouth.z).length())
				var score := err+(0.0 if err < 0.25 else 100.0)+absf(pitch-float(k.pitch_rest))
				if score < best_score:
					best_score = score
					best = {"heading":heading,"pitch_rest":pitch,"power_rest":notch,"err":err}
			pitch += deg_to_rad(0.25)
	return best

## STAND-IN updraft vent: a zone that throws the pilot to a mark when he is in it
## (`grounded`: only on its grate, standing or laid down).
class Vent extends "res://scripts/traps/trap.gd":
	var zone := AABB()
	var launch := Vector3.ZERO
	var target := Vector3.INF
	var apex := 1.0
	var grounded_only := false
	var cool := 1.0
	var cooling := 0.0
	var fires := 0
	var stunned_fires := 0
	var last_push := Vector3.ZERO
	func _init() -> void:
		super()
		trap_name = "vent"
		cost = 2
	## Seconds to fall `h` m from rest at the motor's falling gravity, to its terminal.
	static func fall_time(h: float, p: PilotMotor) -> float:
		var g := p.gravity*p.fall
		var d1 := p.terminal*p.terminal/(2.0*g)
		if h <= d1: return sqrt(2.0*maxf(h,0.0)/g)
		return p.terminal/g+(h-d1)/p.terminal
	## The throw from `from` that comes down on `to`, peaking `apex` m over the higher
	## end: the motor's own arc (rising at gravity, falling FALL times as hard, to terminal).
	static func toss_to(from: Vector3, to: Vector3, apex: float, p: PilotMotor) -> Vector3:
		var top := maxf(from.y,to.y)+apex
		var vy := sqrt(2.0*p.gravity*(top-from.y))
		var t := vy/p.gravity+fall_time(top-to.y,p)
		var flat := Vector2(to.x-from.x,to.z-from.z)/t
		return Vector3(flat.x,vy,flat.y)
	func setup(v: Dictionary) -> void:
		zone = AABB(v.at-v.size*0.5,v.size)
		launch = v.get("toss",Vector3.ZERO)
		apex = float(v.get("apex",1.0))
		grounded_only = bool(v.get("grounded",false))
		cool = float(v.cool)
	func build() -> void:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = zone.size
		m.mesh = b
		m.position = zone.get_center()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5,0.85,1.0,0.25)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	func before(delta: float) -> void:
		cooling = maxf(0.0,cooling-delta)
		if cooling > 0.0 or motor == null or motor.rider != null: return
		if grounded_only and not motor.grounded: return
		if not zone.has_point(motor.feet+Vector3.UP*0.6): return
		last_push = launch if target == Vector3.INF else Vent.toss_to(motor.feet,target,apex,motor)
		motor.toss(last_push)
		cooling = cool
		fires += 1
		if motor.move == "tumble": stunned_fires += 1
		tell_sound(&"vent",motor.feet)
	func reset() -> void:
		super()
		cooling = 0.0
		fires = 0
		stunned_fires = 0

## STAND-IN catching cannon: a real cannon (its aim, power and launch) that takes a
## stunned body into its barrel (the motor's rider) and fires it after `fuse` s; the
## launch is a `toss`, so the body flies on still stunned.
class CatchCannon extends "res://scripts/traps/trap.gd":
	var cannon: Node3D
	var zone_size := Vector3.ONE
	var fuse := 0.5
	var holding := -1.0
	var catches := 0
	var fired := 0
	var fired_stunned := 0
	func _init() -> void:
		super()
		trap_name = "catch_cannon"
		cost = 2
	func zone() -> AABB:
		return AABB(cannon.pivot()-zone_size*0.5,zone_size)
	func before(delta: float) -> void:
		if motor == null or cannon == null: return
		if holding >= 0.0:
			holding += delta
			if holding >= fuse: _fire()
			return
		if motor.rider != null or motor.move != "tumble": return
		if not zone().has_point(motor.feet+Vector3.UP*0.6): return
		motor.rider = self
		motor.grounded = false
		motor.velocity = Vector3.ZERO
		motor.feet = cannon.pivot()
		holding = 0.0
		catches += 1
		tell_sound(&"catch",cannon.pivot())
	## The motor's rider contract: held in the barrel.
	func ride(m: PilotMotor, _delta: float, _want: Vector2, _pressed: bool) -> Dictionary:
		m.feet = cannon.pivot()
		m.velocity = Vector3.ZERO
		return {}
	func _fire() -> void:
		holding = -1.0
		var v: Vector3 = cannon.fire()
		motor.rider = null
		motor.grounded = false
		motor.feet = cannon.mouth()
		motor.toss(v)
		fired += 1
		if motor.move == "tumble": fired_stunned += 1
	func reset() -> void:
		super()
		if motor != null and motor.rider == self: motor.rider = null
		holding = -1.0
		catches = 0
		fired = 0
		fired_stunned = 0
		if cannon != null: cannon.reset()

var traps: Node3D
var cannons: Node3D
var fan: Node
var voussoirs: Array = []
var _rows: Array = []
var tumble: Node3D
var vent: Node3D
var vents: Array = []
var catcher: Node3D
var exit_isle := Rect2()
var exit_top := 0.0
var _aims: Array = []
var _catch_aim := {}
var _parts: Array = []
var _labels: Array = []

func _ready() -> void:
	pack = "lidstack"
	super._ready()

func _load_pack() -> void:
	# The tumble first: its size sets the lane's cut.
	tumble = Tumble.new().configure(TUMBLE.knobs)
	var extra: Array = [["tumble lane",lane_rect(),int(TUMBLE.cut[0]),0.0,int(TUMBLE.cut[1])]]
	_rows = []
	for v: Dictionary in VOUSSOIRS:
		extra.append([v.name,v.cut,int(v.tiers[0]),0.0,int(v.tiers[1])])
		_rows.append(v)
	_parts = _structure(extra)
	_labels = LABELS.duplicate()
	# The exit isle, and both cannons aimed at it.
	var mid: Vector3 = EXIT.centre
	var w := float(EXIT.wide)
	exit_top = mid.y
	exit_isle = Rect2(mid.x-w*0.5,mid.z-w*0.5,w,w)
	_parts.append(["box",exit_isle,mid.y-3.0,mid.y,"pad"])
	_labels.append([mid+Vector3.UP*1.5,"EXIT RIM (4) / next isle: both cannons are aimed here (PORT out)"])
	_aims = []
	for c: Dictionary in CANNONS: _aims.append(aim_at(c.at,mid))
	_catch_aim = aim_at(CATCH.at,mid)
	start = START_AT
	start_face = Vector2(0.6,-0.8).normalized()
	lost = LOST_Y
	_last_stood = start
	stations = []
	for s: Array in STATIONS_TABLE:
		var spawn: Vector3 = s[2]
		stations.append({"key":s[0],"name":s[1],"spawn":spawn,"face":s[3],"sign":spawn+Vector3(0.0,float(s[4]),0.0),"parts":[]})
	stations[0].parts = _parts+_label_parts()

## The void under the lid's sweep (x, z): its width along the axis, its sweep across.
func lane_rect() -> Rect2:
	var s := float(tumble.knob("size"))
	var clear := float(TUMBLE.clear)
	var along := s*0.5+clear
	var across := s*sqrt(0.5)+clear
	var a: Vector3 = TUMBLE.axis
	var axis := Basis(Vector3.UP,deg_to_rad(float(TUMBLE.yaw)))*Vector3.RIGHT
	if absf(axis.x) > 0.5: return Rect2(a.x-along,a.z-across,along*2.0,across*2.0)
	return Rect2(a.x-across,a.z-along,across*2.0,along*2.0)

func _label_parts() -> Array:
	var out := []
	for l: Array in _labels: out.append(["label",l[0],l[1]])
	return out

## The mass, the core, the stairs and the rest, as character-study parts.
func tiers_top(i: int) -> float:
	return float(MASS.tiers[i][2])

func _cut_on(c: Array, i: int) -> bool:
	if float(c[3]) > 0.0: return i == int(c[2])
	return i >= int(c[2]) and i <= (int(c[4]) if c.size() > 4 else 99)

## Each tier a layer (the tier below's top to its own) over its square, less the open cuts
## on it; a roofed passage starting on it leaves its roof (ceiling to top) standing.
func _structure(extra_cuts: Array) -> Array:
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
		for rect: Rect2 in _floor_rects(room,holes): parts.append(["box",rect,bottom,top,colour])
		for rf: Array in roofs:
			if top <= float(rf[1]): continue
			for rect: Rect2 in _floor_rects(rf[0],open): parts.append(["box",rect,float(rf[1]),top,colour])
	parts.append(["box",core_rect,UNDER,0.0,"floor"])
	parts.append_array(_core_walls())
	for s: Array in STAIRS: parts.append_array(_stairs(s))
	for l: Array in LADDERS: parts.append_array(_ladder(l))
	for b: Array in BOXES: if float(b[3]) > float(b[2]): parts.append(["box",b[1],b[2],b[3],b[4]])
	return parts

## The column's walls with the table's openings cut through them.
func _core_walls() -> Array:
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
			# The wall's height less every opening over this stretch.
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

func _stairs(s: Array) -> Array:
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

func _ladder(l: Array) -> Array:
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

func _build_room() -> void:
	super._build_room()
	traps = TrapField.new()
	add_child(traps)
	traps.attach(self)
	cannons = CannonField.new()
	add_child(cannons)
	cannons.attach(self)
	for row: Dictionary in _rows:
		var v := Voussoirs.new().configure(row.knobs)
		v.position = row.at
		v.rotation_degrees.y = float(row.yaw)
		voussoirs.append(traps.add(v))
	# The lid: its flat top's middle on the table's axis point.
	var basis := Basis(Vector3.UP,deg_to_rad(float(TUMBLE.yaw)))
	var c: Vector3 = tumble.centre()
	tumble.position = (TUMBLE.axis as Vector3)-basis*Vector3(0.0,0.0,c.z)
	tumble.rotation_degrees.y = float(TUMBLE.yaw)
	traps.add(tumble)
	# The catching cannon (before the vents: the grate throws to its barrel).
	catcher = CatchCannon.new()
	catcher.position = CATCH.at
	catcher.zone_size = CATCH.zone
	catcher.fuse = float(CATCH.fuse)
	var cc: Node3D = Cannon.new()
	cc.configure({"pitch_rest":float(_catch_aim.pitch_rest),"power_rest":int(_catch_aim.power_rest)})
	cc.rotation.y = float(_catch_aim.heading)
	catcher.add_child(cc)
	catcher.cannon = cc
	traps.add(catcher)
	vents = []
	for vd: Dictionary in VENTS:
		var vt := Vent.new()
		vt.setup(vd)
		match String(vd.get("to","")):
			"lid": vt.target = tumble.top_point()
			"catch": vt.target = cc.pivot()
		vents.append(traps.add(vt))
	vent = vents[0]
	for i in CANNONS.size():
		var cd: Dictionary = CANNONS[i]
		var aim: Dictionary = _aims[i]
		cannons.add_cannon(cd.at,float(aim.heading),{"pitch_rest":float(aim.pitch_rest),"power_rest":int(aim.power_rest)})
	for k: Vector3 in KEGS: cannons.add_keg(k)
	fan = Fan.new()
	fan.parts = [traps,cannons]
	add_child(fan)
	foot_pieces = fan

## Set down anywhere: the traps and the cannon as built.
func place(at: Vector3, face: Vector2) -> void:
	if fan != null: fan.reset()
	super.place(at,face)

func _hint_text() -> String:
	return "LIDSTACK: number keys = stations (1-9, 0, -, =) . stairs round the faces, or the door and the chimney (wall-kick) . R start . F1 numbers . Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or traps == null: return
	var fallen := 0
	var total := 0
	for v: Node3D in voussoirs:
		total += v.slabs.size()
		for s: Dictionary in v.slabs:
			if s.state == Voussoirs.GONE or s.state == Voussoirs.FALLING: fallen += 1
	_hud.text = "%s

lid %s (put off '%s' x%d) . voussoirs fallen %d/%d . vents %d/%d . catch %d fired %d . cannon '%s'" % [_hud.text,tumble.phase,tumble.put_off,tumble.thrown,fallen,total,vents[0].fires,vents[1].fires,catcher.catches,catcher.fired,cannons.mode]
