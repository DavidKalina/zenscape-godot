extends "res://scripts/traps/trap.gd"
## The Tumble Run (docs/design/roguelike/tumble-run.md): a few Tumbling
## Blocks (scripts/traps/trap_tumble.gd, one instance each, set by its
## knobs, nothing forked) hung over open void between the start deck (A) and
## the far deck (B), staggered into a platforming route: each block off to
## the left or right of the one before, a little further on, higher or lower.
##
## The route is DATA (`BLOCKS`), in the pilot's units, so another can be laid
## by a generator the same way. Each entry, from the one before (or the start
## deck for the first):
##   size   the cube's side, in his heights
##   side   -1 / +1: which way the next block lies along x (not the first)
##   x      the first block's place across the route, in his heights
##   ahead  how far on its middle is from the last one's, in his heights
##   gap    the hop in AT ITS WORST (the two blocks moved apart, the rise at
##          its highest), as a share of a RUNNING small hop's reach there;
##          the plan lays the middles closer by what the blocks move
##   rise   the top's height over the last top, in small jumps; over `HOP_UP`
##          shares it is a CLIMB (he jumps for the lip and hangs, then climbs)
##   phase  the rhythm's delay, in rests (it rests that long before its first
##          tip), so the blocks don't lurch together
##   tempo  the rhythm's pace (1.0 as the single block's, scaled to its size)
##   knobs  any Tumbling Block knob (dir -1 turns it the other way, ...)
## Round 2, its personality (each optional, off by default):
##   steep  the tip, a share from the motor's SLOPE_SLOW to SLIDE_AUTO (0.5)
##   snap   the lurch's speed (x; the lurch takes 1/snap as long)
##   ramp   how fast the pace ramps as he rides (x the single block's)
##   wake   it wakes when he lands: the rest cut to this many tells
##   feint  a fake-out shudder this many tells long mid-rest
##   double quarter turns chained onto each lurch
##   dip    the slam's drop, in small jumps
##   shudder the tell's shake (x)
##   bob    up and down, in small jumps; drift along x, in his heights;
##          sway a yaw wobble, in degrees (their periods are knobs)
## So the gaps and heights come from `pilot()` and the heights, never metres.
## The worst case of the motion is in the plan (`wide`, `narrow`, `dy_worst`
## per row): every hop is made at its widest and highest, and no two blocks
## meet at their closest.
##
## Two blocks that share x must keep apart in z: a cube swings corners
## 0.707 of its side from its middle, so a block's neighbour is on the other
## side of it (the x ranges don't meet, the gap is across x: a hop sideways
## and on) and the one after it is a body-length further on. `clear_of` is the
## check.
##
## Carrying: every block carries him only while he is on it (`riding`, which is
## about that block's own outside), so landing on the next carries him with the
## next, and the field steps this trap once; this steps its blocks.
const Ground = preload("res://scripts/pilot_physics_ground.gd")
const Tumble = preload("res://scripts/traps/trap_tumble.gd")

## A rise up to this share of a small jump is a hop; more is a climb.
const HOP_UP := 0.75
## The cube's swing: its corners' distance from its middle, in sides.
const SWING := 0.7071
## The hop out to the far deck (a share of a running hop's reach).
const EXIT_GAP := 0.55

## The line builds from A to B: 1 the waker (breathes, wakes when he
## lands), 2 the jitter (quick, startles awake, feints, a nervous sway), 3 the slammer (big,
## heavy, steep, a double lurch and a slam that drops it), 4 the drifter
## (turns the other way, slides along its axis so its gaps open and close,
## wakes), 5 the finale (fast, steepest bar the slammer, bobs, wakes,
## feints, ramps hardest).
const BLOCKS := [
	{"size":6.0,"x":-2.8,"gap":0.5,"rise":0.45,"phase":1.0,"tempo":1.1,
		"steep":0.6,"snap":1.2,"ramp":2.0,"wake":1.5,"bob":0.25,"knobs":{"throw":1.1,"glow":0.4}},
	{"size":5.2,"side":1,"ahead":4.5,"gap":0.45,"rise":0.0,"phase":3.0,"tempo":1.6,"prize":false,
		"steep":0.65,"snap":1.4,"ramp":2.5,"wake":1.0,"feint":0.6,"sway":4.0,"knobs":{"throw":1.1,"sway_time":1.6,"glow":0.4}},
	{"size":7.0,"side":-1,"ahead":5.3,"gap":0.55,"rise":1.7,"phase":2.6,"tempo":0.85,
		"steep":0.75,"snap":1.6,"ramp":2.0,"double":1,"dip":0.5,"shudder":2.0,"knobs":{"throw":1.4,"jolt":0.6,"glow":0.7}},
	{"size":5.6,"side":1,"ahead":4.6,"gap":0.75,"rise":-1.0,"phase":5.4,"tempo":0.95,"prize":false,
		"steep":0.6,"snap":1.3,"ramp":2.0,"wake":1.5,"drift":0.35,"knobs":{"dir":-1.0,"throw":1.1,"glow":0.5}},
	{"size":6.4,"side":-1,"ahead":5.5,"gap":0.7,"rise":0.3,"phase":6.4,"tempo":1.3,"prize":false,
		"steep":0.7,"snap":1.5,"ramp":3.0,"wake":1.2,"feint":0.5,"bob":0.3,"knobs":{"throw":1.3,"ramp_top":2.0,"glow":0.7}},
]

var blocks: Array = []
var plan_rows: Array = []

func _init() -> void:
	super()
	trap_name = "tumble_run"
	cost = 4
	under = "void"
	verbs = PackedStringArray(["jump","walk","climb"])

func defaults() -> Dictionary:
	return {"blocks":BLOCKS}

## The airtime (s) of a small jump that ends `dy` over where it left.
static func air(p: PilotMotor, dy: float) -> float:
	var apex := float(p.jumps[0])
	var up := sqrt(2.0*apex/p.gravity)
	return up+sqrt(2.0*maxf(apex-dy,0.0)/(p.gravity*p.fall))

## A running small hop's reach (m) at a rise of `dy`.
static func reach(p: PilotMotor, dy: float) -> float:
	return p.run*air(p,dy)

## How far a block of `size` (m) moves (m): `mx` sideways and on (its
## drift and the corners its sway swings out), `up` and `down` (its bob, and
## the slam's dip).
static func moves(b: Dictionary, size: float) -> Dictionary:
	var p := pilot()
	var h: float = Ground.HEAD*WorldScale.wanderer
	var jump := float(p.jumps[0])
	var sway := deg_to_rad(float(b.get("sway",0.0)))
	var bob := float(b.get("bob",0.0))*jump
	return {"mx":float(b.get("drift",0.0))*h+size*0.5*(cos(sway)+sin(sway)-1.0),
		"up":bob,"down":bob+float(b.get("dip",0.0))*jump}

## The route laid out: rows of {size, x (middle), z (middle, negative on),
## top, gap (the hop in, m, as laid: the blocks at rest), dy (the rise into
## it), climb, wide and narrow (the gap at the motion's worst and closest),
## dy_worst (the rise at its highest), move, row}, and the way out (exit_gap
## as laid, exit_wide, exit_dy, exit_dy_worst) and the length. `rows` is the
## data list.
static func plan(rows: Array) -> Dictionary:
	var p := pilot()
	var h: float = Ground.HEAD*WorldScale.wanderer
	var jump := float(p.jumps[0])
	var out := []
	var top := 0.0
	var x := 0.0
	var z := 0.0
	var size_before := 0.0
	var far := 0.0
	var before := {"mx":0.0,"up":0.0,"down":0.0}
	for i in range(rows.size()):
		var b: Dictionary = rows[i]
		var size: float = float(b.size)*h
		var mv := moves(b,size)
		var dy: float = float(b.rise)*jump
		var dy_worst: float = dy+float(before.down)+float(mv.up)
		var spread: float = float(before.mx)+float(mv.mx)
		var wide: float = float(b.gap)*reach(p,dy_worst)
		var gap: float = wide-spread
		if i == 0:
			x = float(b.x)*h
			z = -(gap+size*0.5)
		else:
			x += float(b.side)*((size_before+size)*0.5+gap)
			z -= float(b.ahead)*h
		top += dy
		out.append({"size":size,"x":x,"z":z,"top":top,"gap":gap,"dy":dy,"climb":dy_worst > jump*HOP_UP,
			"wide":wide,"narrow":gap-spread,"dy_worst":dy_worst,"move":mv,"row":b})
		size_before = size
		far = z-size*0.5
		before = mv
	var exit_dy := -top
	var exit_dy_worst: float = exit_dy+float(before.down)
	var exit_wide := EXIT_GAP*reach(p,exit_dy_worst)
	var exit_gap: float = exit_wide-float(before.mx)
	return {"rows":out,"exit_gap":exit_gap,"exit_wide":exit_wide,"exit_dy":exit_dy,"exit_dy_worst":exit_dy_worst,"length":-far+exit_gap}

## True if blocks `a` and `b` (plan rows) can't swing into each other: apart
## across x, or their middles a swing apart in the yz plane.
## Counts what they move: their drift and sway across, their bob and dip.
static func clear_of(a: Dictionary, b: Dictionary) -> bool:
	var ma: Dictionary = a.get("move",{"mx":0.0,"up":0.0,"down":0.0})
	var mb: Dictionary = b.get("move",{"mx":0.0,"up":0.0,"down":0.0})
	var across := absf(float(a.x)-float(b.x))-(float(a.size)+float(b.size))*0.5-float(ma.mx)-float(mb.mx)
	if across > 0.0: return true
	var d := Vector2(float(a.z)-float(b.z),float(a.top)-float(a.size)*0.5-(float(b.top)-float(b.size)*0.5)).length()
	return d-float(ma.mx)-float(mb.mx)-maxf(float(ma.up),float(ma.down))-maxf(float(mb.up),float(mb.down)) >= SWING*(float(a.size)+float(b.size))

func length() -> float:
	return float(plan(knob("blocks")).length)

func footprint() -> Rect2:
	var lo := INF
	var hi := -INF
	for r: Dictionary in plan(knob("blocks")).rows:
		lo = minf(lo,float(r.x)-float(r.size)*0.5)
		hi = maxf(hi,float(r.x)+float(r.size)*0.5)
	return Rect2(lo,-length(),hi-lo,length())

## No floor under it: a fall is the void.
func open_below() -> bool:
	return true

func build() -> void:
	var laid := plan(knob("blocks"))
	plan_rows = laid.rows
	var base := Tumble.new().defaults()
	var p := pilot()
	var jump := float(p.jumps[0])
	var h: float = Ground.HEAD*WorldScale.wanderer
	for r: Dictionary in plan_rows:
		var row: Dictionary = r.row
		var scale := float(r.size)/float(base.size)
		var tempo := float(row.get("tempo",1.0))
		var tell := float(base.tell)
		var knobs := {"size":r.size,"gap":0.0,"top":r.top,
			"rest":float(base.rest)*scale/tempo,"tip_time":float(base.tip_time)*scale/tempo,
			"prize":bool(row.get("prize",true)),
			"tip":deg_to_rad(lerpf(PilotMotor.SLOPE_SLOW,PilotMotor.SLIDE_AUTO,float(row.get("steep",0.5)))),
			"lurch":float(base.lurch)/maxf(float(row.get("snap",1.0)),0.1),
			"ramp":float(base.ramp)*float(row.get("ramp",1.0)),
			"wake":float(row.get("wake",0.0))*tell,"feint":float(row.get("feint",0.0))*tell,
			"double":int(row.get("double",0)),"dip":float(row.get("dip",0.0))*jump,
			"bob":float(row.get("bob",0.0))*jump,"drift":float(row.get("drift",0.0))*h,
			"sway":deg_to_rad(float(row.get("sway",0.0))),
			"bob_time":float(base.bob_time)*scale/tempo,"drift_time":float(base.drift_time)*scale,
			"sway_time":float(base.sway_time)*scale/tempo,"motion_phase":float(row.get("phase",0.0))*0.13,
			"shake":float(base.shake)*float(row.get("shudder",1.0))}
		knobs.merge(row.get("knobs",{}),true)
		var block: Node3D = Tumble.new()
		block.configure(knobs)
		block.position = Vector3(r.x,0.0,float(r.z)+float(r.size)*0.5)
		block.sounded.connect(tell_sound)
		add_child(block)
		blocks.append(block)
	_phase()

## The rhythm's delays: each block rests `phase` rests longer first.
func _phase() -> void:
	for i in range(blocks.size()):
		var b: Node3D = blocks[i]
		b.phase_t = -float(plan_rows[i].row.get("phase",0.0))*float(b.knob("rest"))

func before(delta: float) -> void:
	for b: Node3D in blocks:
		b.motor = motor
		b.before(delta)

func after(delta: float, events: Dictionary) -> void:
	for b: Node3D in blocks: b.after(delta,events)

func reset() -> void:
	super()
	for b: Node3D in blocks: b.reset()
	_phase()

## The block he is on (or hangs from), or null.
func riding_block() -> Node3D:
	for b: Node3D in blocks:
		if b.riding(): return b
	return null
