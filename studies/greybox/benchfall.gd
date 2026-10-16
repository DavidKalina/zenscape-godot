extends "res://studies/character_study.gd"
## GREYBOX of the motif "Benchfall": four benches hung under one
## another round an
## open quarry pit, descended mostly by falling. Grey boxes for structure, the
## REAL voussoirs (scripts/traps/trap_voussoirs.gd) for the spoil slabs and the
## REAL headless body (scripts/enemies/headless_body.gd) on the benches.
## The pilot is the game's own (this extends the character study).
##   godot --path . res://studies/greybox/benchfall.tscn -- --no-title
##   number keys: 1 cap, 2 east bench, 3 west bench, 4 floor bench, 5 hoist foot,
##   6 stair head, 7 chain 1 (slab cascade), 8 chain 2 (the skip), 9 chain 3
##   (the shoved giant), 0 chute head, - rim S slab row, = the hatch row.
##   R start. F1 numbers (+ the trail of benches you have stood on, the
##   bodies, the slabs fallen). F2 feel.
##
## Opus pass: laid out so the three chains are hand-offs, each one placed
## under the last. Chain 1 is one column on the east: the cap's slab row hangs
## straight over the spoil chute (a slot through bench 2), the chute's foot
## runs out onto bench 3's hatch row, the hatch drops onto the floor bench.
## Chain 3 is one column on the north: a body baited to bench 2's north lip
## stands right under the cap's north lip. See the card's "Greybox (Opus
## pass)" section for the numbers and what held.
##
## EVERYTHING IS IN THE DATA TABLE BELOW (for the later KitLand.island pass):
## BENCHES (one entry per terrain mass: its outline, top, the cuts out of it,
## the walls on its outer edge), PIECES (stair, heaps, chute, props: the
## character study's part format), HOISTS, TRAPS, BODIES, STATIONS, LABELS.
## x east, z south (rim N is -z), y up. Metres, all sized off the pilot.
##
## Sizes come from the pilot's real numbers (Trap.pilot(): walk 2.4, run 4.8,
## jumps 0.8/1.5, a fall of 6 m stuns, the sail glides about 3.7 across per 1
## down at its pace, 2.7 braked).
const Trap = preload("res://scripts/traps/trap.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const Voussoirs = preload("res://scripts/traps/trap_voussoirs.gd")
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")

# --- The data table ---------------------------------------------------------------------

## The fall that sets him back at the nearest station: under the floor bench.
const VOID_LOST := -30.0
## Bench spacing (m): 14 is 2.33 times the stun's 6 m, past the full stun
## (2x), so a bare fall always stuns for the most; the sail avoids it.
const STEP := 14.0
## The gap in the hoist's chimney (m): the character study's wall-jump shaft.
const SHAFT_GAP := 2.8
const SHAFT_WALL := 1.2

## The pit's lips, one rect per bench (the open core of each; a narrower one
## per bench down, so a step off any pit lip lands on the bench below or the
## next one down, never the void). Bench 2's north lip (z -13) stands 3 m in
## from the cap's (z -16): the band a body is baited onto for chain 3, under
## the cap's lip.
const PIT_1 := Rect2(-16.0,-16.0,32.0,32.0)
const PIT_2 := Rect2(-8.0,-12.2,16.0,20.2)
const PIT_3 := Rect2(-3.0,-3.0,6.0,6.0)
## The hoist's shaft (its gap between the walls): a free-standing tower in
## the pit's west slot (between bench 2's west end, x -6, and the cap's west
## lip, x -16), its mouth facing south over bench 3, its top flush with the
## cap beside the cap's lip. The skip circles down the slot onto its mouth.
const SHAFT := Rect2(-14.4,-2.0,SHAFT_GAP,4.0)
## Chain 1's column (x): the cap's slab row, the chute under it and bench 3's
## hatch row all run along it, south.
const CASCADE_X := 17.8
## The spoil chute: 5 m wide, from bench 2's deck (its head, z -10) down 14 m
## at 50 deg to bench 3 (its foot); bench 2 is slotted round it.
const CHUTE_W := 5.0
const CHUTE_HEAD_Z := -10.0
const CHUTE_FOOT_Z := 1.75
const CHUTE_SLOT := Rect2(CASCADE_X-CHUTE_W*0.5,CHUTE_HEAD_Z,CHUTE_W,16.0)
## Bench 3's south-east is gone (a bite to the floor bench): its lip, the
## hatch slab, ends 2.5 m past the chute's foot, so the chute's run-out goes
## over it and drops him 14 m to the floor bench.
const BENCH3_SE := Rect2(12.0,4.25,20.0,23.75)

## The benches: each ONE terrain mass. name, top, thick (the keel under the
## top), outer (x, z), cuts (rects out of it: pit core, crescent bites, notches
## for the slab rows (added from TRAPS by `row_rect`), the chute's slot), walls (1 m rects along the outer edge, wall_h tall: the
## quarry's own cliff), colour. "tiers" is the step list in the KitLand sense:
## one tier here (a bench is one flat level; the stack of benches is the
## terrain's steps).
const BENCHES := [
	{"name":"1  CAP","top":42.0,"thick":4.0,"outer":Rect2(-32.0,-32.0,64.0,64.0),"colour":"floor",
		"tiers":[42.0],
		"cuts":[PIT_1,Rect2(-32.0,16.0,64.0,16.0)],
		"walls":[Rect2(-33.0,-33.0,66.0,1.0),Rect2(-33.0,-32.0,1.0,48.0),Rect2(32.0,-32.0,1.0,48.0)],"wall_h":3.0},
	{"name":"2  EAST BENCH","top":28.0,"thick":4.0,"outer":Rect2(-6.0,-32.0,38.0,64.0),"colour":"floor",
		"tiers":[28.0],
		"cuts":[PIT_2,CHUTE_SLOT],
		"walls":[Rect2(-6.0,-33.0,39.0,1.0),Rect2(32.0,-32.0,1.0,28.0),Rect2(32.0,4.0,1.0,28.0),Rect2(-6.0,32.0,39.0,1.0)],"wall_h":3.0},
	{"name":"3  WEST BENCH","top":14.0,"thick":4.0,"outer":Rect2(-32.0,-32.0,64.0,60.0),"colour":"floor",
		"tiers":[14.0],
		"cuts":[PIT_3,Rect2(12.0,-32.0,20.0,22.0),BENCH3_SE],
		"walls":[Rect2(-33.0,-33.0,45.0,1.0),Rect2(-33.0,-32.0,1.0,60.0),Rect2(-33.0,28.0,45.0,1.0),Rect2(32.0,-10.0,1.0,14.25)],"wall_h":3.0},
	{"name":"4  FLOOR BENCH","top":0.0,"thick":6.0,"outer":Rect2(-32.0,-32.0,64.0,56.0),"colour":"wall",
		"tiers":[0.0],
		"cuts":[],
		"walls":[Rect2(-33.0,-33.0,66.0,1.0),Rect2(-33.0,-32.0,1.0,56.0),Rect2(32.0,-32.0,1.0,56.0)],"wall_h":3.0},
]

## Everything else solid, in the character study's part format: the stair
## (two flights of 4.5 m at 28 deg, landings, stopping short 5 m over the east
## bench: UNDER the 6 m stun), the rubble heap at its foot (steps for the 1.6 m
## SET_OFF climb), the spoil chute (50 deg: past the 44 deg he can stand on,
## so he surfs it with no input), the rim E sill, the rim S platform past the
## slab row, and props. "lip" tops are orange.
const PIECES := [
	["ramp",Vector3(24.0,37.5,24.5),Vector3(24.0,42.0,16.0),3.0,"grey"],
	["box",Rect2(22.5,24.5,3.0,3.0),36.5,37.5,"grey"],
	["ramp",Vector3(14.0,33.0,26.0),Vector3(22.5,37.5,26.0),3.0,"grey"],
	["box",Rect2(11.0,24.5,3.0,3.0),32.0,33.0,"lip"],
	["box",Rect2(7.0,24.5,4.0,3.0),27.0,30.0,"grey"],
	["box",Rect2(5.0,24.5,2.0,3.0),27.0,29.0,"grey"],
	# STAND-IN: the balustrade slide (the real one is a foot piece and the foot-piece slot is taken here by the traps and the bodies).
	["ramp",Vector3(CASCADE_X,14.0,CHUTE_FOOT_Z),Vector3(CASCADE_X,28.0,CHUTE_HEAD_Z),CHUTE_W,"grey"],
	# Rim E: the adit mouth's sill, 14 m under the cap, over true void (a socket for a neighbour's catcher).
	["box",Rect2(32.0,-3.0,6.0,6.0),27.0,28.0,"pad"],
	# Rim S: the platform past the floor bench's slab row, over the void.
	["box",Rect2(-3.0,33.6,6.0,3.0),-1.0,0.0,"pad"],
	# The floor bench's props: the half-freed drum (STAND-IN for the unfinished colossus blank), a column blank lying down.
	["cyl",Vector2(-12.0,-10.0),3.5,0.0,3.2,"dark"],
	["obox",Vector3(12.0,0.9,-14.0),Vector3(1.8,1.8,8.0),25.0,"dark"],
	# STAND-IN: the derrick / gantry (kit ask): two posts and a beam on the cap.
	["box",Rect2(-22.0,-30.0,1.0,1.0),42.0,50.0,"dark"],
	["box",Rect2(-14.0,-30.0,1.0,1.0),42.0,50.0,"dark"],
	["box",Rect2(-22.0,-30.0,9.0,1.0),49.0,50.0,"dark"],
]

## The hoist: a closed-back chimney two walls SHAFT_GAP apart (the wall-kick
## shaft of the character study, STAND-IN for tower_shell), from `base` to `top`,
## open on its south face, with a resting shelf at each height in `rests`
## (none: a shelf at 28 m would be in the skip's circle).
const HOISTS := [
	{"name":"hoist","gap":SHAFT,"base":14.0,"top":42.0,"rests":[]},
]

## The traps: the REAL voussoirs. Each row starts at `at` (its top; the first
## slab's near end) and runs `along` (+x, -x or +z, the way it faces), count
## slabs; `under` "void" costs 3 (over the void), "layer" 2; `knobs` over the
## trap's own (Voussoirs.defaults). The bench plates are notched under them.
## The two chain 1 rows are SPOIL SLABS: few and big (a slab's `length` along
## the row, `width` across), no chase, no tester, falling `delay` s after the
## first touch. The voussoirs' walker-sized slabs (1.2 m) always leave a lip
## within the motor's 0.45 m catch ring (PilotLedge.RING) of a man standing
## on one, so he hangs instead of falling; a 4.8 x 3.6 spoil slab leaves him
## room to stand clear of every lip.
const TRAPS := [
	{"name":"cap spoil slabs over the chute (chain 1)","bench":0,"at":Vector3(CASCADE_X,42.0,-8.0),"along":"+z","count":2,"under":"layer",
		"knobs":{"length":4.8,"width":3.6,"delay":0.8,"chase":false,"first_tests":false}},
	{"name":"bench 3 hatch slab at the chute's foot (chain 1)","bench":2,"at":Vector3(CASCADE_X,14.0,2.0),"along":"+z","count":1,"under":"layer",
		"knobs":{"length":2.25,"width":5.6,"delay":0.6,"chase":false,"first_tests":false}},
	{"name":"rim S row (over the void)","bench":3,"at":Vector3(0.0,0.0,24.0),"along":"+z","count":8,"under":"void"},
]

## The headless body (REAL, through the slam STAND-IN below). `when` "start":
## there from the start and on R; a station key: set down when you are placed
## at that station. `knobs`: its knob overrides (the bait listens 8 s at the
## lip before it roams off).
const BODIES := [
	{"name":"floor bench patrol","at":Vector3(12.0,0.0,12.0),"face":Vector2(-1.0,0.0),"when":"start","knobs":{}},
	{"name":"bench 2 north lip bait (chain 3)","at":Vector3(0.0,28.0,-12.6),"face":Vector2(1.0,0.0),"when":9,"knobs":{"listen":8.0}},
]
## A slammed body that lands holds still this long (s): a block to stand on.
const BLOCK_HOLD := 8.0

## [key, name, spawn, face, sign]. Keys as the character study: 10 is 0, 11 -, 12 =.
const STATIONS_TABLE := [
	[1,"CAP  rim N (arrive)",Vector3(0.0,42.0,-29.0),Vector2(0.0,1.0),Vector3(0.0,46.0,-26.0)],
	[2,"EAST BENCH  rim E (adit)",Vector3(27.0,28.0,-8.0),Vector2(-1.0,0.0),Vector3(27.0,32.0,-8.0)],
	[3,"WEST BENCH",Vector3(-18.0,14.0,-14.0),Vector2(-1.0,0.0),Vector3(-18.0,18.0,-12.0)],
	[4,"FLOOR BENCH  arena",Vector3(0.0,0.0,-14.0),Vector2(0.0,1.0),Vector3(0.0,4.0,-12.0)],
	[5,"HOIST mouth (west bench)",Vector3(-13.0,14.0,6.0),Vector2(0.0,-1.0),Vector3(-16.0,18.0,6.0)],
	[6,"STAIR head (cap)",Vector3(24.0,42.0,8.0),Vector2(0.0,1.0),Vector3(24.0,46.0,10.0)],
	[7,"CHAIN 1  slab cascade",Vector3(25.0,42.0,-5.6),Vector2(-1.0,0.0),Vector3(25.0,46.0,-3.0)],
	[8,"CHAIN 2  the skip",Vector3(26.0,42.0,-26.0),Vector2(-0.7071,0.7071),Vector3(26.0,46.0,-22.0)],
	[9,"CHAIN 3  the shoved giant",Vector3(0.0,42.0,-19.0),Vector2(0.0,1.0),Vector3(3.0,46.0,-20.0)],
	[10,"CHUTE head (east bench)",Vector3(CASCADE_X,28.0,-14.0),Vector2(0.0,1.0),Vector3(CASCADE_X+3.0,32.0,-14.0)],
	[11,"RIM S  slab row over the void",Vector3(0.0,0.0,12.0),Vector2(0.0,1.0),Vector3(0.0,4.0,14.0)],
	[12,"HATCH slab (bench 3, chute foot)",Vector3(25.0,14.0,3.5),Vector2(-1.0,0.0),Vector3(25.0,18.0,1.0)],
]

## [at, text]: floating labels for the beats and chains.
const LABELS := [
	[Vector3(0.0,44.0,-8.0),"CAP 42 m: the pit. bench 2 is 14 m down, bench 3 28, the floor 42"],
	[Vector3(24.0,31.0,18.0),"STAIR: 2 flights, stops short: 5 m drop (under the 6 m stun) onto the heap"],
	[Vector3(CASCADE_X+3.0,45.0,-3.0),"CHAIN 1: two spoil slabs (REAL voussoirs, cost 2) hung over the chute. stop on one as it goes: 19 m onto the chute (stun), up and surfing, over the hatch lip, 14 m to the floor (stun)"],
	[Vector3(26.0,47.0,-26.0),"CHAIN 2 the skip: sprint SW off the cap, sail across the pit, circle down the west slot onto the hoist's mouth, wall-kick it up to the cap"],
	[Vector3(0.0,45.0,-16.0),"CHAIN 3: a headless body (REAL) listens at bench 2's lip right under this one. walk off, slam its back: it topples off and you ride it down to bench 3"],
	[Vector3(CASCADE_X+4.0,26.0,-4.0),"STAND-IN: SPOIL CHUTE = a 50 deg ramp (past the 44 deg he can stand on: he surfs it with no input). 14 m down to bench 3"],
	[Vector3(CASCADE_X+4.0,17.0,6.0),"HATCH slab (REAL voussoirs, cost 2) = bench 3's lip: the chute runs out over it, or it drops you, to the floor bench"],
	[Vector3(35.0,31.0,0.0),"RIM E: adit mouth (sill over void: a socket, not a floor)"],
	[Vector3(-13.0,17.0,4.0),"STAND-IN: HOIST = wall-kick shaft (tower_shell) in the west slot, top out beside the cap's lip"],
	[Vector3(-12.0,17.0,-10.0),"BENCH 3: its pit hole is the lip over the floor bench (14 m, stun)"],
	[Vector3(0.0,4.0,-26.0),"FLOOR BENCH: arena. the REAL headless body paces here (slam it off rim S). STAND-IN: the drum (unfinished colossus)"],
	[Vector3(0.0,4.0,20.0),"slab row 3 (REAL, over the VOID: cost 3) to RIM S, the exit"],
	[Vector3(0.0,4.0,36.0),"RIM S: exit, the only edge over void"],
	[Vector3(-18.0,52.0,-30.0),"STAND-IN: DERRICK (kit ask)"],
	[Vector3(4.0,31.0,-10.0),"STAND-IN: the body answers the slam (engine change: headless_body.gd joins the slam group)"],
]
## Where the pilot starts / looks at the start.
const START_STATION := 1

# --- The slam stand-in ------------------------------------------------------------------

## STAND-IN for an engine change to scripts/enemies/headless_body.gd: the
## REAL body, plus (1) it joins Slam.GROUP and answers `slam(at, radius,
## strength)` with the knock every enemy is meant to take (Slam.knock_way,
## measured at its back, not its feet, so a slam ON its back reaches it):
## grounded and not climbing, it is thrown off its feet, out from his feet
## and up, and falls ("fall"); (2) a body falling from a slam does not buck
## the pilot stood on its back (`bucks()` false), so he rides it down; (3)
## landed from it, it holds still BLOCK_HOLD s (its "land" held), a block.
class SlamBody extends "res://scripts/enemies/headless_body.gd":
	var slammed := false
	var topples := 0
	var _land_was := -1.0
	func setup(host: Node, at: Vector3, face: Vector2, overrides := {}) -> void:
		super.setup(host,at,face,overrides)
		add_to_group(Slam.GROUP)
	func slam(at: Vector3, radius: float, strength: float) -> void:
		if gone or not grounded or state in ["leap","fall","climb","mantle"]: return
		var v := Slam.knock_way(at,radius,strength,position+Vector3.UP*height)
		if v == Vector3.ZERO: return
		vel = v
		grounded = false
		slammed = true
		topples += 1
		if _land_was < 0.0: _land_was = float(knobs.land)
		knobs.land = BLOCK_HOLD
		_go("fall")
		field.sound(&"body_leap",position)
	func bucks() -> bool:
		return state in ["leap","fall"] and not slammed
	func _landed() -> void:
		super._landed()
		slammed = false
	func _go(to: String) -> void:
		if to != "land" and _land_was >= 0.0:
			knobs.land = _land_was
			_land_was = -1.0
		super._go(to)

# --- State ------------------------------------------------------------------------------

var traps: Node3D
var enemies: Node
var stone: Array = []
var trail: Array[String] = []
var last_fall := {}
var _arrived := -1
var _fall_from := 0.0
var _falling := false
var _rows: Array = []

## Steps the trap field and the enemy field both in the study's one slot.
## STAND-IN (`chute`, the chute's footprint and its run-out to bench 3's
## hatch lip), for the balustrade slide: on his feet there and moving (or on
## the 50 deg chute at all) the slot holds his crouch for him, so the chute
## carries him to the lip with no input. Two motor gaps it covers: (1) on a
## physics ramp past about 27 deg the motor's uphill probe
## (PilotMotor._surfing, SLOPE_FAR 1 m uphill) starts its ray inside the
## ramp, the ray skips it (scripts/pilot_physics_ground.gd height_from /
## _down, hit_from_inside off) and reads the bench under it, so he stands on
## the 50 deg chute for good instead of surfing (the motor's header says a
## slope past slide_auto, 44 deg, can't be stood on); (2) the surf drops to
## a run at the chute's foot, and an uncrouched run with the stick let go
## is "careful" (PilotMotor._careful) at any pace, so at the lip he turns,
## lowers himself and hangs. Crouched, neither happens.
class Slot extends Node:
	var fields: Array = []
	var motor: Object
	var chute := Rect2()
	var chute_top := INF
	func before(delta: float) -> void:
		if motor != null and on_chute() and (motor.steepness() > motor.slide_auto or motor.speed() > 1.0): motor.crouch = true
		for f in fields: f.before(delta)
	func on_chute() -> bool:
		return motor.grounded and not motor.downed() and motor.feet.y < chute_top and chute.has_point(Vector2(motor.feet.x,motor.feet.z))
	func after(delta: float, events: Dictionary) -> void:
		for f in fields: f.after(delta,events)
	func pose(figure: Node3D) -> void:
		for f in fields: f.pose(figure)

# --- Building ---------------------------------------------------------------------------

func _ready() -> void:
	pack = "benchfall"
	super._ready()

func _load_pack() -> void:
	lost = VOID_LOST
	stations = []
	_rows = []
	var parts: Array = []
	var pil := Trap.pilot()
	# The rows' footprints, so the benches can be notched under them.
	var notches := {}
	for t: Dictionary in TRAPS:
		var rect := row_rect(t,pil)
		_rows.append(rect)
		if not notches.has(int(t.bench)): notches[int(t.bench)] = []
		notches[int(t.bench)].append(rect)
	for i in BENCHES.size():
		var b: Dictionary = BENCHES[i]
		var cuts: Array[Rect2] = []
		for c: Rect2 in b.cuts: cuts.append(c)
		for c: Rect2 in notches.get(i,[]): cuts.append(c)
		for r in _floor_rects(b.outer,cuts):
			parts.append(["box",r,float(b.top)-float(b.thick),float(b.top),b.colour])
		for w: Rect2 in b.walls: parts.append(["box",w,float(b.top)-float(b.thick),float(b.top)+float(b.wall_h),"wall"])
	parts.append_array(PIECES)
	for h: Dictionary in HOISTS: parts.append_array(hoist_parts(h))
	for l: Array in LABELS: parts.append(["label",l[0],l[1]])
	var first := true
	for s: Array in STATIONS_TABLE:
		stations.append({"key":s[0],"name":s[1],"spawn":s[2],"face":s[3],"sign":s[4],"parts":parts if first else []})
		first = false
	start = stations[START_STATION-1].spawn
	start_face = stations[START_STATION-1].face
	_last_stood = start
	print("benchfall: fall stun at %.1f m, bench step %.1f m (%.2f x), walk %.1f run %.1f" % [pil.fall_stun_height(),STEP,STEP/pil.fall_stun_height(),pil.walk,pil.run])

## A slab row's footprint (x, z) from its table entry, off the pilot's pace.
static func row_rect(t: Dictionary, pil: Object) -> Rect2:
	var k: Dictionary = t.get("knobs",{})
	var slab_len: float = k.get("length",pil.walk*0.5)
	var wide: float = k.get("width",pil.run*0.5)
	var long := slab_len*float(t.count)
	var at: Vector3 = t.at
	match String(t.along):
		"+x": return Rect2(at.x,at.z-wide*0.5,long,wide)
		"-x": return Rect2(at.x-long,at.z-wide*0.5,long,wide)
		_: return Rect2(at.x-wide*0.5,at.z,wide,long)

## A chimney's walls (back, west, east), and a shelf at each rest.
static func hoist_parts(h: Dictionary) -> Array:
	var g: Rect2 = h.gap
	var base: float = h.base
	var top: float = h.top
	var out: Array = [
		["box",Rect2(g.position.x-SHAFT_WALL,g.position.y-SHAFT_WALL,g.size.x+SHAFT_WALL*2.0,SHAFT_WALL),base,top,"wall"],
		["box",Rect2(g.position.x-SHAFT_WALL,g.position.y,SHAFT_WALL,g.size.y),base,top,"lip"],
		["box",Rect2(g.end.x,g.position.y,SHAFT_WALL,g.size.y),base,top,"lip"],
	]
	for r in h.rests: out.append(["box",Rect2(g.position.x,g.end.y,g.size.x,3.0),float(r)-1.0,float(r),"pad"])
	return out

func _build_room() -> void:
	super._build_room()
	traps = TrapField.new()
	add_child(traps)
	traps.attach(self)
	for t: Dictionary in TRAPS:
		var trap: Node3D = Voussoirs.new()
		var k: Dictionary = {"count":t.count}
		k.merge(t.get("knobs",{}),true)
		trap.configure(k)
		trap.position = t.at
		trap.rotation.y = {"+x":-PI*0.5,"-x":PI*0.5}.get(String(t.along),PI)
		trap.under = String(t.under)
		traps.add(trap)
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	add_child(enemies)
	for b: Dictionary in BODIES:
		if b.when is String: enemies.spawn(SlamBody,b.at,b.face,b.knobs)
	var slot := Slot.new()
	slot.fields = [traps,enemies]
	slot.motor = motor
	slot.chute = Rect2(CASCADE_X-CHUTE_W*0.5,CHUTE_HEAD_Z,CHUTE_W,BENCH3_SE.position.y-CHUTE_HEAD_Z)
	slot.chute_top = BENCHES[1].top-0.5
	add_child(slot)
	foot_pieces = slot
	motor.air = traps._air

# --- Placing ----------------------------------------------------------------------------

func go_to(key: int) -> void:
	_arrived = key
	super.go_to(key)

func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if traps != null: traps.reset()
	if enemies != null:
		enemies.reset()
		for b: Dictionary in BODIES:
			if not (b.when is String) and int(b.when) == _arrived: enemies.add(SlamBody,b.at,b.face,b.knobs)
	_arrived = -1
	_falling = false
	trail.clear()

# --- Numbers ----------------------------------------------------------------------------

## The bench he stands on now (0 none): by the height of his feet.
func bench_now() -> int:
	if not motor.grounded: return 0
	for i in BENCHES.size():
		if absf(motor.feet.y-float(BENCHES[i].top)) < 1.2: return i+1
	return 0

func tick(delta: float) -> void:
	var was_air := not motor.grounded
	var y0 := motor.feet.y
	super.tick(delta)
	if was_air and not _falling and not motor.grounded:
		_falling = true
		_fall_from = y0
	if motor.grounded and _falling:
		_falling = false
	var b := bench_now()
	if b > 0:
		var tag := str(b)
		if trail.is_empty() or trail[trail.size()-1] != tag:
			trail.append(tag)
			if trail.size() > 12: trail.pop_front()

func _hint_text() -> String:
	return "Benchfall greybox: 1 cap 2 east 3 west 4 floor 5 hoist 6 stair 7 chain1 8 chain2 9 chain3 0 chute - rim S = hatch · R start · F1 numbers · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible: return
	var pil := motor
	var lines := PackedStringArray([_hud.text,""])
	lines.append("bench %s · y %.1f · trail %s" % [str(bench_now()) if bench_now() > 0 else "-",motor.feet.y," > ".join(trail)])
	lines.append("stun %s · fall stun at %.1f m · a bench drop (%.0f m) stuns %.1f s · stair drop 5 m" % ["DOWN" if motor.downed() else ("stunned" if motor.move == "tumble" else "no"),pil.fall_stun_height(),STEP,pil.fall_stun_time(STEP)])
	var fallen := 0
	for t: Node3D in traps.traps: fallen += int(t.fallen_count)
	var bodies := PackedStringArray()
	for e in enemies.enemies:
		if is_instance_valid(e): bodies.append("%s y%.0f toppled %d" % [e.state,e.position.y,int(e.topples)])
	lines.append("slabs fallen %d · bodies: %s" % [fallen,", ".join(bodies)])
	_hud.text = "\n".join(lines)
