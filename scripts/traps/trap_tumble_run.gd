extends "res://scripts/traps/trap.gd"
## The Tumble Run: a few Tumbling
## Blocks (scripts/traps/trap_tumble.gd, one instance each, set by its
## knobs, nothing forked) hung over open void between the start deck (A) and
## the far deck (B), staggered into a platforming route: each block off to
## the left or right of the one before, a little further on, higher or lower.
##
## Round 3, the ferries: the blocks are spread out so most hops are too far
## most of the time. Each block slides along the route (its `ferry`, back
## toward the entry and on toward the exit, holding at each end), and the
## neighbours slide against each other on one shared beat (`BEAT`): a hop
## opens when the block he is on is held ON and the next is held BACK, their
## ends then overlapping along the route by `meet` and apart across x by
## `gap`. Half a beat later the next hop opens, so he lands at a block's
## back end, rides it on through its lurch (in the air, or in the pocket),
## and goes from its front end. Outside the window the hop is a diagonal
## across the void longer than his jump (the pump, caught by the lip); the
## plan checks the window against his real reach (`leap`, the motor's own
## jumps stepped on a flat run-up).
##
## The route is DATA (`BLOCKS`), in the pilot's units, so another can be laid
## by a generator the same way. Each entry, from the one before (or the start
## deck for the first):
##   size   the cube's side, in his heights
##   side   -1 / +1: which way the next block lies along x (not the first)
##   x      the first block's place across the route, in his heights
##   gap    the hop in AT ITS WINDOW, as a share of a running small hop's
##          reach (`open_reach`) at the rise: for the first the gap along
##          the route from the deck, for the rest the gap across x (at the
##          motion's worst: the blocks drifted and swayed apart)
##   meet   how far the two ends overlap along the route at the window, in
##          his heights (the strip he hops across; not the first)
##   ferry  how far the block slides each way along the route, in his heights
##   hold   the share of the beat the ferry holds at each end (`HOLD`)
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
## Each plan row carries the window's gap (`gap`, at the motion's worst),
## the gap held shut (`shut`, at its closest), the rise's range and the
## reaches (`open_reach`, `jump_reach`, `twirl_reach`).
##
## Neighbours keep apart across x (a cube turning about x never swings out
## along x, so they can slide past each other's ends); two blocks on the
## same side are a body or more apart along the route and slide together.
## `clear_of` is the check.
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
## The hop out to the far deck at its window (a share of a running hop's
## reach).
const EXIT_GAP := 0.55
## The ferries' shared beat: one cycle (back, on, back), in the single
## cube's walk-across times (its side over his walk); and when block 1 is
## first held back (a share of the beat), the time to run up to it.
const BEAT := 3.2
const FIRST := 0.2
## The share of the beat a ferry holds at each end (a row's `hold` sets its
## own), and how it slides between: -1 lunging into its ends (quickest
## there, stopping dead), so the hops it opens and shuts are open briefly
## and shut most of the beat.
const HOLD := 0.12
const LUNGE := -0.9

## The line builds from A to B: 1 the waker (breathes, wakes when he
## lands), 2 the jitter (quick, startles awake, feints, a nervous sway), 3 the
## slammer (big, heavy, steep, a double lurch and a slam that drops it; a
## climb onto it), 4 the drifter (turns the other way, drifts across x as
## well, wakes, holds its ends for less), 5 the finale (fast, bobs, wakes,
## feints, ramps hardest; the longest ferry).
const BLOCKS := [
	{"size":6.0,"x":-2.8,"gap":0.5,"ferry":3.2,"rise":0.45,"phase":1.0,"tempo":1.1,
		"steep":0.6,"snap":1.2,"ramp":2.0,"wake":1.5,"bob":0.25,"knobs":{"throw":1.1,"glow":0.4}},
	{"size":5.2,"side":1,"gap":0.45,"meet":0.9,"ferry":2.6,"rise":0.0,"phase":3.0,"tempo":1.6,"prize":false,
		"steep":0.65,"snap":1.4,"ramp":2.5,"wake":1.0,"feint":0.6,"sway":4.0,"knobs":{"throw":1.1,"sway_time":1.6,"glow":0.4}},
	{"size":7.0,"side":-1,"gap":0.35,"meet":0.6,"ferry":2.6,"rise":1.7,"phase":2.6,"tempo":0.85,
		"steep":0.75,"snap":1.6,"ramp":2.0,"double":1,"dip":0.5,"shudder":2.0,"knobs":{"throw":1.4,"jolt":0.6,"glow":0.7}},
	{"size":5.6,"side":1,"gap":0.55,"meet":0.9,"ferry":2.6,"hold":0.1,"rise":-1.0,"phase":5.4,"tempo":0.95,"prize":false,
		"steep":0.6,"snap":1.3,"ramp":2.0,"wake":1.5,"drift":0.15,"knobs":{"dir":-1.0,"throw":1.1,"glow":0.5}},
	{"size":6.4,"side":-1,"gap":0.5,"meet":0.9,"ferry":3.0,"rise":0.3,"phase":6.4,"tempo":1.3,"prize":false,
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

## A running small hop's reach (m) at a rise of `dy` (the arc's sum).
static func reach(p: PilotMotor, dy: float) -> float:
	return p.run*air(p,dy)

static var _leaps := {}

## His real reach (m) along a running jump off an edge, onto ground `dy`
## over it, stepped through the motor (pilot() at the world's size) at
## 120 Hz: "hop" a running small hop landing on it (0 if it can't), "hop
## catch" one caught by its lip, "jump" the pump (the higher jump a timed
## hop gives) caught by the lip, "twirl" the pump with the twirl pressed at
## its best moment and caught by the lip. The long jump and the sail are
## not counted (see the handoff).
static func leap(kind: String, dy: float) -> float:
	var key := "%s %.2f" % [kind,snappedf(dy,0.05)]
	if _leaps.has(key): return float(_leaps[key])
	var best := 0.0
	var presses: Array = [-1.0]
	if kind == "twirl": presses = [0.25,0.35,0.45,0.55,0.65,0.75]
	for press: float in presses:
		best = maxf(best,_leap_once(kind,snappedf(dy,0.05),press))
	_leaps[key] = best
	return best

static func _leap_once(kind: String, dy: float, press: float) -> float:
	var m := pilot()
	if kind != "hop" and kind != "hop catch": m.jumps = [m.jumps[1],m.jumps[1]]
	var ground := func(q: Vector2) -> float: return 0.0 if q.y > 0.0 else -1000.0
	var slide := func(f: Vector3, d: Vector2) -> Vector3: return f+Vector3(d.x,0.0,d.y)
	m.reset(Vector3(0.0,0.0,m.run*1.5),0.0)
	var dt := 1.0/120.0
	var jumped := false
	var t := 0.0
	var air_t := 0.0
	var twirled := false
	var catch := kind != "hop"
	var low := dy-m.hang_drop-PilotMotor.GRAB_LOW
	var reach_to := 0.0
	# The arc's airtime to the drop to `low`, for the twirl's press.
	var apex_t := sqrt(2.0*float(m.jumps[0])/m.gravity)
	while t < 6.0:
		var jump := false
		if not jumped and m.grounded and m.feet.z < 0.02:
			jump = true
			jumped = true
		elif jumped: jump = true
		m.twirl = kind == "twirl" and jumped and not twirled and air_t >= apex_t*(0.5+press*1.5)
		if m.twirl: twirled = true
		var was := m.feet
		m.step(dt,Vector2(0.0,-1.0),m.run,jump,ground,slide)
		t += dt
		if jumped: air_t += dt
		if jumped and not catch and was.y >= dy and m.feet.y < dy: reach_to = maxf(reach_to,-lerpf(was.z,m.feet.z,(was.y-dy)/maxf(was.y-m.feet.y,1e-6)))
		if jumped and catch and was.y >= low and m.feet.y < low:
			reach_to = maxf(reach_to,-lerpf(was.z,m.feet.z,(was.y-low)/maxf(was.y-m.feet.y,1e-6))+PilotMotor.GRAB_REACH*m.size)
			break
		if m.feet.y < low-1.0: break
	return reach_to

## The hop at a window counted as open: a running small hop onto it (or,
## for a climb, caught by its lip).
static func open_reach(dy: float) -> float:
	var hop := leap("hop",dy)
	return hop if hop > 0.0 else leap("hop catch",dy)

## How far a block of `size` (m) moves (m): `mx` across (its drift and the
## corners its sway swings out), `mz` along the route (its ferry, each
## way), `up` and `down` (its bob, and the slam's dip).
static func moves(b: Dictionary, size: float) -> Dictionary:
	var p := pilot()
	var h: float = Ground.HEAD*WorldScale.wanderer
	var jump := float(p.jumps[0])
	var sway := deg_to_rad(float(b.get("sway",0.0)))
	var bob := float(b.get("bob",0.0))*jump
	return {"mx":float(b.get("drift",0.0))*h+size*0.5*(cos(sway)+sin(sway)-1.0),
		"mz":float(b.get("ferry",0.0))*h,"up":bob,"down":bob+float(b.get("dip",0.0))*jump}

## The route laid out: rows of {size, x, z (middles at the ferry's middle,
## z negative on), top, ferry (m each way), gap (the hop in at its window,
## at the motion's worst), shut (the hop held shut: the two ferried apart,
## the drift at its closest), dx (across, at the motion's worst), dy (the
## rise), dy_worst and dy_best (its highest and lowest), climb, open_reach,
## jump_reach (the pump caught by the lip, at the lowest rise) and
## twirl_reach, move, row}; the way out (exit_gap, exit_shut, exit_dy,
## exit_dy_worst, the reaches) and the length. `rows` is the data list.
static func plan(rows: Array) -> Dictionary:
	var p := pilot()
	var h: float = Ground.HEAD*WorldScale.wanderer
	var jump := float(p.jumps[0])
	var out := []
	var top := 0.0
	var x := 0.0
	var z := 0.0
	var size_before := 0.0
	var ferry_before := 0.0
	var front := 0.0
	var before := {"mx":0.0,"mz":0.0,"up":0.0,"down":0.0}
	for i in range(rows.size()):
		var b: Dictionary = rows[i]
		var size: float = float(b.size)*h
		var mv := moves(b,size)
		var ferry: float = mv.mz
		var dy: float = float(b.rise)*jump
		var dy_worst: float = dy+float(before.down)+float(mv.up)
		var dy_best: float = dy-float(before.up)-float(mv.down)
		var spread: float = float(before.mx)+float(mv.mx)
		var open := open_reach(dy_worst)
		var gap: float = float(b.gap)*open
		var dx := 0.0
		var shut := 0.0
		if i == 0:
			# From the deck straight on: held back, its back end `gap` off
			# the deck's edge; held on, two ferries further.
			x = float(b.x)*h
			z = -(gap+ferry+size*0.5)
			shut = gap+2.0*ferry
		else:
			dx = gap
			x += float(b.side)*((size_before+size)*0.5+dx-spread)
			# Held back, its back end `meet` behind the last one's front
			# held on.
			var meet: float = float(b.get("meet",1.0))*h
			z = front+meet-ferry-size*0.5
			var apart: float = 2.0*(ferry_before+ferry)-meet
			shut = Vector2(dx-2.0*spread,maxf(apart,0.0)).length()
		top += dy
		out.append({"size":size,"x":x,"z":z,"top":top,"ferry":ferry,"gap":gap,"shut":shut,"dx":dx,
			"dy":dy,"dy_worst":dy_worst,"dy_best":dy_best,"climb":dy_worst > jump*HOP_UP,
			"open_reach":open,"jump_reach":leap("jump",dy_best),"twirl_reach":leap("twirl",dy_best),"move":mv,"row":b})
		size_before = size
		ferry_before = ferry
		# Its front end, held on.
		front = z-ferry-size*0.5
		before = mv
	var exit_dy := -top
	var exit_dy_worst: float = exit_dy+float(before.down)
	var exit_dy_best: float = exit_dy-float(before.up)
	var exit_open := open_reach(exit_dy_worst)
	var exit_gap := EXIT_GAP*exit_open
	return {"rows":out,"exit_gap":exit_gap,"exit_shut":exit_gap+2.0*ferry_before,"exit_dy":exit_dy,
		"exit_dy_worst":exit_dy_worst,"exit_open_reach":exit_open,"exit_jump_reach":leap("jump",exit_dy_best),
		"exit_twirl_reach":leap("twirl",exit_dy_best),"length":-front+exit_gap}

## True if blocks `a` and `b` (plan rows) can't swing into each other: apart
## across x (a turn about x never swings out along x), or their middles a
## swing apart in the yz plane with all they move counted (the ferries
## each way, drift and sway across, bob and dip).
static func clear_of(a: Dictionary, b: Dictionary) -> bool:
	var ma: Dictionary = a.get("move",{"mx":0.0,"mz":0.0,"up":0.0,"down":0.0})
	var mb: Dictionary = b.get("move",{"mx":0.0,"mz":0.0,"up":0.0,"down":0.0})
	var across := absf(float(a.x)-float(b.x))-(float(a.size)+float(b.size))*0.5-float(ma.mx)-float(mb.mx)
	if across > 0.0: return true
	var d := Vector2(float(a.z)-float(b.z),float(a.top)-float(a.size)*0.5-(float(b.top)-float(b.size)*0.5)).length()
	return d-float(ma.mx)-float(mb.mx)-float(ma.get("mz",0.0))-float(mb.get("mz",0.0))-maxf(float(ma.up),float(ma.down))-maxf(float(mb.up),float(mb.down)) >= SWING*(float(a.size)+float(b.size))

## The beat (s): BEAT of the single cube's walk-across times.
static func beat() -> float:
	var p := pilot()
	return BEAT*float(Tumble.new().defaults().size)/p.walk

func length() -> float:
	return float(plan(knob("blocks")).length)

func footprint() -> Rect2:
	var lo := INF
	var hi := -INF
	for r: Dictionary in plan(knob("blocks")).rows:
		lo = minf(lo,float(r.x)-float(r.size)*0.5-float(r.move.mx))
		hi = maxf(hi,float(r.x)+float(r.size)*0.5+float(r.move.mx))
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
	for i in range(plan_rows.size()):
		var r: Dictionary = plan_rows[i]
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
			"shuttle":r.ferry,"shuttle_time":beat(),"shuttle_hold":float(row.get("hold",HOLD)),"shuttle_ease":LUNGE,
			"shuttle_phase":-(FIRST+0.5*float(i)),
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

## Hop `i` as the blocks lie now (0 the start deck to block 1, n the last
## block to the far deck): {gap, dx, dz, dy}, the nearest the two tops come
## in the trap's frame (x, z) and the rise there (the tops' heights where
## they meet along the route, their tips counted).
func hop_now(i: int) -> Dictionary:
	if i == 0:
		var t: Dictionary = blocks[0].top_span()
		return {"gap":maxf(-float(t.z1),0.0),"dx":0.0,"dz":maxf(-float(t.z1),0.0),"dy":float(t.y1)}
	if i >= blocks.size():
		var s: Dictionary = blocks[blocks.size()-1].top_span()
		var dz := maxf(float(s.z0)+length(),0.0)
		return {"gap":dz,"dx":0.0,"dz":dz,"dy":-float(s.y0)}
	var a: Dictionary = blocks[i-1].top_span()
	var b: Dictionary = blocks[i].top_span()
	var dx := maxf(maxf(float(b.x0)-float(a.x1),float(a.x0)-float(b.x1)),0.0)
	var lo := maxf(float(a.z0),float(b.z0))
	var hi := minf(float(a.z1),float(b.z1))
	var dz := maxf(lo-hi,0.0)
	# Where they meet along the route: the overlap's middle, or the two
	# nearest ends.
	var za := (lo+hi)*0.5 if hi >= lo else (float(a.z0) if float(a.z0) > float(b.z1) else float(a.z1))
	var zb := (lo+hi)*0.5 if hi >= lo else (float(b.z1) if float(a.z0) > float(b.z1) else float(b.z0))
	return {"gap":Vector2(dx,dz).length(),"dx":dx,"dz":dz,"dy":_y_at(b,zb)-_y_at(a,za)}

static func _y_at(t: Dictionary, z: float) -> float:
	var span := float(t.z1)-float(t.z0)
	if span < 0.001: return maxf(float(t.y0),float(t.y1))
	return lerpf(float(t.y0),float(t.y1),clampf((z-float(t.z0))/span,0.0,1.0))
