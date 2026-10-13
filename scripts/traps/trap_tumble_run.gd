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
##   gap    the hop in, as a share of a RUNNING small hop's reach at that rise
##   rise   the top's height over the last top, in small jumps; over `HOP_UP`
##          shares it is a CLIMB (he jumps for the lip and hangs, then climbs)
##   phase  the rhythm's delay, in rests (it rests that long before its first
##          tip), so the blocks don't lurch together
##   tempo  the rhythm's pace (1.0 as the single block's, scaled to its size)
##   knobs  any Tumbling Block knob (dir -1 turns it the other way, ...)
## So the gaps and heights come from `pilot()` and the heights, never metres.
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

const BLOCKS := [
	{"size":6.0,"x":-2.8,"gap":0.5,"rise":0.5,"phase":1.0,"tempo":1.0},
	{"size":5.2,"side":1,"ahead":4.5,"gap":0.4,"rise":0.0,"phase":3.0,"tempo":1.2,"prize":false},
	{"size":7.0,"side":-1,"ahead":4.9,"gap":0.35,"rise":1.7,"phase":2.6,"tempo":1.0},
	{"size":5.6,"side":1,"ahead":4.6,"gap":0.8,"rise":-1.0,"phase":5.4,"tempo":0.9,"knobs":{"dir":-1.0},"prize":false},
	{"size":6.4,"side":-1,"ahead":4.9,"gap":0.7,"rise":0.4,"phase":6.4,"tempo":1.1,"prize":false},
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

## The route laid out: rows of {size, x (middle), z (middle, negative on),
## top, gap (the hop in, m), dy (the rise into it), climb, key}, and the
## way out ("exit": gap, dy) and the length. `blocks` is the data list.
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
	for i in range(rows.size()):
		var b: Dictionary = rows[i]
		var size: float = float(b.size)*h
		var dy: float = float(b.rise)*jump
		var gap: float = float(b.gap)*reach(p,dy)
		if i == 0:
			x = float(b.x)*h
			z = -(gap+size*0.5)
		else:
			x += float(b.side)*((size_before+size)*0.5+gap)
			z -= float(b.ahead)*h
		top += dy
		out.append({"size":size,"x":x,"z":z,"top":top,"gap":gap,"dy":dy,"climb":dy > jump*HOP_UP,"row":b})
		size_before = size
		far = z-size*0.5
	var exit_dy := -top
	var exit_gap := EXIT_GAP*reach(p,exit_dy)
	return {"rows":out,"exit_gap":exit_gap,"exit_dy":exit_dy,"length":-far+exit_gap}

## True if blocks `a` and `b` (plan rows) can't swing into each other: apart
## across x, or their middles a swing apart in the yz plane.
static func clear_of(a: Dictionary, b: Dictionary) -> bool:
	var across := absf(float(a.x)-float(b.x))-(float(a.size)+float(b.size))*0.5
	if across > 0.0: return true
	var d := Vector2(float(a.z)-float(b.z),float(a.top)-float(a.size)*0.5-(float(b.top)-float(b.size)*0.5)).length()
	return d >= SWING*(float(a.size)+float(b.size))

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
	for r: Dictionary in plan_rows:
		var row: Dictionary = r.row
		var scale := float(r.size)/float(base.size)
		var tempo := float(row.get("tempo",1.0))
		var knobs := {"size":r.size,"gap":0.0,"top":r.top,
			"rest":float(base.rest)*scale/tempo,"tip_time":float(base.tip_time)*scale/tempo,
			"prize":bool(row.get("prize",true))}
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
