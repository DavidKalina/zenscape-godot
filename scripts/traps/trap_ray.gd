extends "res://scripts/traps/trap.gd"
## The Sky Ray (the user's idea, a Mario Sunshine sand bird; docs/design/
## roguelike/traps-round4-giants.md; built to the contract in scripts/traps/
## trap.gd): a broad flat creature, greybox, that flies a ride through the
## sky from A to B. It waits beside the start deck (a stop), flies a long
## authored `path` (a closed list of waypoints, local to the trap: climbs,
## swings out east, comes back down) to the far deck, slows and waits beside
## that (the next stop), then flies the rest of the loop round and back to
## the start and does it again. The player doesn't steer it: the whole job
## is to stay on. Board from the start deck's east edge while it waits, get
## off at the far deck's while it waits there.
##
## Riding it is a fight to stay on. On its back he is carried with its full
## transform delta (`motor.carry`, his facing turned with it) and he slides
## on its smooth hide: the trap keeps his slide (`slip`, m/s across the
## back) and moves him by it through `carry`, as a moving surface does. The
## slide is pushed by gravity along the tilted back and by the swing of its
## flight (the acceleration of the point under his feet, taken out: a turn
## throws him outward, a climb presses him down, a dive goes light), and
## held by friction, `grip` times how hard he is pressed onto the back. He
## grips harder leaning: walking uphill (`lean` more at `lean_pace`).
## Crouching is no grip here: on any slope over the motor's SLIDE_FROM a
## crouch is its boot-surf, down the back and off. The raised ridges on its
## back stop a slide into them (cover on the low side).
## Slid past the rim fast (over the motor's CATCH_PACE) and not leaning in,
## he is thrown off with the speed he had (`motor.toss`); slower, or leaning
## back in, the motor's own step-off catch takes the rim and he hangs from
## it, carried, to climb back up. Where its back drops away faster than he
## would fall (a dive's plunge) he lifts off (`toss` with its velocity) and
## floats till it pulls up under him. Leaving its back any way, he keeps its
## velocity; landing on it, his own run is taken relative to it.
## Stunned (the motor's "tumble", docs/design/roguelike/stun-round1.md) he
## rides it as a body: down on its back he is carried and slid, shed and
## thrown off as ever, but grabs no rail; teched onto it (the stun tech, a
## press just before the touch) he latches onto the nearest rail (`_latch`).
##
## The moves sit along the path (`moves`, or laid from `pattern` over each
## leg between stops, a calm run each end): "L"/"R" a roll that drops that
## wing (a bank), "D" a climb then a dive, "V" the big roll. Banks grow from
## (1-`ramp`) x `max_bank` on a leg's first to `max_bank` on its last. Tells,
## keyed to where the move comes on the path, `tell` s ahead at its pace: the
## wing that will rise lifts and warms to orange before a bank, with a
## `whoosh`; the head dips before a dive's plunge, with a `screech`. `shake`
## (rad) is a wobble about its length that tries to shed a rider.
##
## The big roll ("V", the sand bird's): `big_tell` s ahead a long screech,
## the whole body shudders and the high wing lifts high and glows; then it
## rolls onto its side (`big_tilt`, 90 degrees) over `big_roll` s, holds
## there `big_hold` s, and rolls back level. The tilt cap below gives way for
## it. Its back carries `rails` handholds (raised rails along it with a
## bright lip, rows across it) that light up through it. Holding the stick
## toward the high wing (moving that way at `grab_pace`) with a rail within
## `grab_reach` that way, he catches the nearest: the trap holds him (the
## motor's `rider`), crouched gripping it while the back is gentle, hanging
## from it (the motor's ledge hang) past `hang_from`, carried with the ray;
## the stick along the rail shimmies him, held away (the motor's DROP_HOLD)
## lets go. Rolled back under `stand_tilt` he is set on his feet beside it.
## Not holding one, past the motor's SLIDE_AUTO the motor surfs him down the
## back, and past `shed_tilt` he is shed off it (no standing on a wall); a
## rim hang is shaken off past `hang_from`.
##
## Sizes from the pilot: the back `width` 6 of his heights, `long` 8,
## `speed` his run, the path in his heights, `height` the dive's climb, the
## ridges his first jump x 0.7 high and his body's width thick, the rails
## his body's radius high, the plunge his fall's acceleration x `dive`.
## Outside the big roll the tilt is held under the motor's own slide angle
## (SLIDE_AUTO, past which the motor surfs him itself). Cost 4, over the
## void 5.
const Ground = preload("res://scripts/pilot_physics_ground.gd")
const SKIN := Color(0.42,0.41,0.4)
const RIDGE := Color(0.5,0.46,0.4)
const RAIL := Color(0.4,0.38,0.36)
const RAIL_LIP := Color(0.95,0.85,0.45)
const WING := Color(0.36,0.4,0.46)
const HEAD_COLOUR := Color(0.33,0.36,0.4)
const REACH_SHARE := 0.45
## Under SLIDE_AUTO by this (degrees): the steepest the back tilts outside
## the big roll.
const TILT_MARGIN := 2.0
## The path's table: samples per waypoint span.
const SAMPLES := 24

var body: StaticBody3D
var head: MeshInstance3D
var wing_l: MeshInstance3D
var wing_r: MeshInstance3D
var wing_mats: Array[StandardMaterial3D] = []
var rail_mat: StandardMaterial3D
## Distance along the loop (m, 0 at the start stop), the bank and pitch now
## (rad), the clock (s since the start stop's wait began, unwrapped).
var s := 0.0
var bank := 0.0
var pitch := 0.0
var clock := 0.0
## His slide across the back (m/s, the back's x z), and the last friction
## share and normal load (m/s²) worked out.
var slip := Vector2.ZERO
var last_grip := 0.0
var last_load := 0.0
## Ridges: [Rect2 (x z on the back), top] in the back's frame.
var ridges: Array = []
## The handholds: x of each rail on the back (its frame), all `rail_half`
## either side of the middle along it.
var rails: Array = []
var rail_half := 0.0
var riding_time := 0.0
## Counted for tests and tuning: lift-offs (a dive), throws off the rim,
## handholds caught (and of them latched by a stun tech), set back on his
## feet off one, shed off the steep back.
var floats := 0
var throws := 0
var grabs := 0
var latches := 0
var set_ons := 0
var sheds := 0
## The handhold he holds (an index into `rails`, -1 none), where along it
## (z, its frame), the high side (+1: the back's +x up), his shimmy (m/s).
var grip_rail := -1
var grip_z := 0.0
var grip_side := 1.0
var _grip_shimmy := 0.0
var _grip_snap := Vector3.ZERO
var _grip_away := 0.0
var _grip_hang := false
var _whoosh_ready := true
var _screech_ready := true
var _big_ready := true
var _was_riding := false
var _tossed := false
var _v_point := Vector3.ZERO
var _air_high := -INF
var _meshes: Array = []
## The path's table (samples, the distance to each), where each waypoint
## falls on it, the legs between stops, the beats and the dive's numbers,
## laid from the knobs (`replan`).
var _pts := PackedVector3Array()
var _cum := PackedFloat64Array()
var _way_d: Array = []
var _legs: Array = []
var _plan: Array = []
var _dive := {}

func _init() -> void:
	super()
	trap_name = "ray"
	cost = 4
	under = "void"
	verbs = PackedStringArray(["jump","balance","hang"])

func defaults() -> Dictionary:
	var p := pilot()
	var height: float = Ground.HEAD*WorldScale.wanderer
	var reach := p.run*2.0*sqrt(2.0*p.jumps[0]/p.gravity)
	var body_r: float = Ground.RADIUS*WorldScale.wanderer
	return {
		"width":height*6.0,"long":height*8.0,"thick":0.8,
		# The hide at the rim (m thick); the thick body starts his hang and
		# his body's width in from it.
		"hide":0.2,"inset":p.hang_out+body_r*2.0,
		# The ride: A (the start deck's middle, `board_z`) to B (`deck_in`
		# past `ride`: the far deck's middle). `path` (local waypoints,
		# closed) and `stops` (indices of it where it waits) laid by default
		# from these (`default_path`); its pace, the ease into and out of a
		# stop, the wait there.
		"ride":height*100.0,"board_z":run_up()*0.5+2.0,"deck_in":4.0,
		"path":[],"stops":[],
		"speed":p.run,"ease":1.5,"dwell":4.0,"radius":height*7.5,
		# The moves: given (`moves`: [kind, at (share of the loop), size
		# (rad, a bank's; optional)]), or laid from `pattern` over each leg
		# (`calm` m clear at each end), the leg's last `big` banks the big
		# roll, its wing kept low.
		"moves":[],"pattern":"RDLDR","big":1,"calm":height*8.0,
		"max_bank":0.72,"ramp":0.7,"turn_bank":0.0,
		"roll":0.5,"hold":1.0,"height":height*7.0,"climb":2.0,
		"dive":1.4,"plunge":0.35,"max_pitch":0.25,
		"shake":0.04,"shake_rate":4.0,"tell":1.0,
		# The big roll: how far (rad), the roll each way, the hold on its
		# side, the tell ahead (s).
		"big_tilt":PI*0.5,"big_roll":1.2,"big_hold":2.0,"big_tell":1.5,
		# The handholds: rows across the back (`rails`, `rail_gap` apart),
		# their share of its length, height and thickness; the grab: moving
		# toward the high wing at `grab_pace`, a rail within `grab_reach`
		# that way; hung from past `hang_from`, set on his feet under
		# `stand_tilt` as it rolls back; not holding, shed past `shed_tilt`
		# (down the back at `shed_slide` or the slide he had, pushed off it at
		# `shed_push`).
		"rails":3,"rail_gap":height*1.2,"rail_long":0.6,"rail_high":body_r*0.55,"rail_thick":body_r*0.8,
		"grab_pace":p.walk*0.25,"grab_reach":p.hang_out+body_r*2.0,
		"hang_from":0.7,"stand_tilt":0.35,"shed_tilt":deg_to_rad(PilotMotor.SLIDE_AUTO+6.0),"shed_push":2.0,"shed_slide":p.walk,
		# His footing: friction standing, more leaning in (at lean_pace
		# uphill, his walk x 0.5), gravity's and the swing's shares, and the
		# rim's catch pace (the motor's).
		"grip":0.3,"lean":0.8,"lean_pace":p.walk*0.5,"pull":1.0,"swing":1.0,
		"catch_pace":PilotMotor.CATCH_PACE,
		"edge_x":5.0,"gap":reach*REACH_SHARE,
		"arrive":3.0,
	}

## The route's length: the far deck is this far along -z.
func length() -> float:
	return float(knob("ride"))

## Room the path takes to the east of the lane (m past the deck's edge),
## for a yard that lays lanes side by side.
func lane_extra() -> float:
	var most := line_x()
	for w: Vector3 in _waypoints(): most = maxf(most,w.x)
	return most+float(knob("width"))*0.6-float(knob("edge_x"))

# ---- the path ----

## x of the ray's middle beside the decks.
func line_x() -> float:
	return float(knob("edge_x"))+float(knob("gap"))+float(knob("width"))*0.5

## The default ride (local, closed): from beside the start deck (A) out along
## -z, climbing and swinging east, down to beside the far deck (B), on past
## it, round east and back north high, round west and down to A.
func default_path() -> Array:
	var h: float = Ground.HEAD*WorldScale.wanderer
	var x0 := line_x()
	var r := float(knob("radius"))
	var l := float(knob("ride"))
	var za := float(knob("board_z"))
	var zb := -(l+float(knob("deck_in")))
	return [
		Vector3(x0,0.0,za),Vector3(x0,0.0,za-12.0),
		Vector3(x0+h*5.0,h*2.0,-l*0.25),Vector3(x0+h*12.0,h*5.0,-l*0.5),Vector3(x0+h*7.0,h*3.0,-l*0.75),
		Vector3(x0,0.0,zb+12.0),Vector3(x0,0.0,zb),Vector3(x0,0.0,zb-12.0),
		Vector3(x0+r,h,zb-12.0-r),Vector3(x0+2.0*r,h*2.0,zb-12.0),Vector3(x0+2.0*r+h*3.0,h*4.0,-l*0.5),
		Vector3(x0+2.0*r,h*2.0,za+12.0),Vector3(x0+r,h,za+12.0+r),Vector3(x0,0.0,za+12.0),
	]

func _waypoints() -> Array:
	var given: Array = knob("path")
	return given if given.size() >= 3 else default_path()

func _stops() -> Array:
	var given: Array = knob("stops")
	return given if not given.is_empty() else ([0,6] if (knob("path") as Array).size() < 3 else [0])

## The path's table: a closed Catmull-Rom through the waypoints, sampled.
func _lay_path() -> void:
	var w := _waypoints()
	var n := w.size()
	_pts = PackedVector3Array()
	_cum = PackedFloat64Array()
	_way_d = []
	var total := 0.0
	for i in range(n):
		var p0: Vector3 = w[(i-1+n)%n]
		var p1: Vector3 = w[i]
		var p2: Vector3 = w[(i+1)%n]
		var p3: Vector3 = w[(i+2)%n]
		for k in range(SAMPLES):
			var t := float(k)/float(SAMPLES)
			var q := 0.5*(2.0*p1+(p2-p0)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t)
			if not _pts.is_empty(): total += q.distance_to(_pts[_pts.size()-1])
			if k == 0: _way_d.append(total)
			_pts.append(q)
			_cum.append(total)
	total += (w[0] as Vector3).distance_to(_pts[_pts.size()-1])
	_pts.append(w[0])
	_cum.append(total)
	# The legs between stops, timed: eased out of a stop, at its pace, eased
	# into the next; a wait at each.
	_legs = []
	var stops := _stops()
	var v := float(knob("speed"))
	var t0 := 0.0
	for k in range(stops.size()):
		var a: float = _way_d[int(stops[k])%n]
		var b: float = _way_d[int(stops[(k+1)%stops.size()])%n]
		var len_k := fposmod(b-a,total)
		if len_k <= 0.0: len_k = total
		var e := minf(float(knob("ease")),len_k/v)
		var tk := len_k/v+e
		_legs.append({"from":a,"long":len_k,"ease":e,"time":tk,"start":t0})
		t0 += float(knob("dwell"))+tk

func loop_length() -> float:
	if _cum.is_empty(): _lay_path()
	return _cum[_cum.size()-1]

## One trip round (s): every leg and every wait.
func cycle() -> float:
	if _legs.is_empty(): _lay_path()
	var last: Dictionary = _legs[_legs.size()-1]
	return float(last.start)+float(knob("dwell"))+float(last.time)

## Where along the loop (m) its stops are, in order.
func stop_at(k: int) -> float:
	if _legs.is_empty(): _lay_path()
	return float(_legs[k%_legs.size()].from)

## The far stop (B) and its leg's length.
func far_stop() -> float:
	return stop_at(1)

## Distance along the loop at clock `t` (s).
func d_at(t: float) -> float:
	if _legs.is_empty(): _lay_path()
	var c := fposmod(t,cycle())
	var dwell := float(knob("dwell"))
	var v := float(knob("speed"))
	for leg: Dictionary in _legs:
		var from: float = leg.from
		if c < dwell: return from
		c -= dwell
		if c < float(leg.time):
			var e: float = leg.ease
			var tk: float = leg.time
			var lk: float = leg.long
			var l := 0.0
			if c < e: l = 0.5*v/e*c*c
			elif c < tk-e: l = v*e*0.5+v*(c-e)
			else: l = lk-0.5*v/e*(tk-c)*(tk-c)
			return fposmod(from+l,loop_length())
		c -= float(leg.time)
	return 0.0

## The clock (s, in the first trip) when it is at `d` moving (the wait
## before it if at a stop).
func time_of(d: float) -> float:
	if _legs.is_empty(): _lay_path()
	d = fposmod(d,loop_length())
	var v := float(knob("speed"))
	for leg: Dictionary in _legs:
		var l := fposmod(d-float(leg.from),loop_length())
		if l >= float(leg.long): continue
		var e: float = leg.ease
		var tk: float = leg.time
		var lk: float = leg.long
		var t := 0.0
		if l < v*e*0.5: t = sqrt(2.0*l*e/v)
		elif l <= lk-v*e*0.5: t = e+(l-v*e*0.5)/v
		else: t = tk-sqrt(2.0*(lk-l)*e/v)
		return float(leg.start)+float(knob("dwell"))+t
	return 0.0

## Set at `d` along the loop, moving (tests and tuning).
func set_at(d: float) -> void:
	clock = time_of(d)
	s = d_at(clock)
	_pose()

## Position on the path at `d` (local), the dives' height not in it.
func _path_point(d: float) -> Vector3:
	if _cum.is_empty(): _lay_path()
	d = fposmod(d,loop_length())
	var lo := 0
	var hi := _cum.size()-1
	while hi-lo > 1:
		var mid := (lo+hi)/2
		if _cum[mid] <= d: lo = mid
		else: hi = mid
	var span := _cum[hi]-_cum[lo]
	var k := (d-_cum[lo])/span if span > 1e-6 else 0.0
	return _pts[lo].lerp(_pts[hi],k)

## Position at `d` (local; y with the dives').
func path_at(d: float) -> Vector3:
	var out := _path_point(d)
	out.y += _dive_y(fposmod(d,loop_length()))
	return out

## The path's way at `d` (unit, x y z).
func _tangent(d: float) -> Vector3:
	var t := _path_point(d+0.5)-_path_point(d-0.5)
	return t.normalized() if t.length() > 1e-5 else Vector3(0.0,0.0,-1.0)

func heading_at(d: float) -> float:
	var t := _tangent(d)
	return atan2(-t.x,-t.z)

## Turn rate of the heading at `d` (rad/m, + left).
func curvature_at(d: float) -> float:
	return wrapf(heading_at(d+1.0)-heading_at(d-1.0),-PI,PI)*0.5

# ---- the moves ----

## The moves in order: {kind "L"/"R"/"D"/"V", low (a big roll's low wing),
## at (m along the loop it starts), size (rad, a bank), long (m it lasts),
## plunge (m along it the dive's plunge starts)}.
func beats() -> Array:
	if _plan.is_empty(): _plan = _lay_beats()
	return _plan

func _beat_long(kind: String) -> float:
	var v := float(knob("speed"))
	if kind == "D":
		var dive := _dive_numbers()
		return (float(knob("climb"))+dive.plunge+dive.out)*v
	if kind == "V": return (2.0*float(knob("big_roll"))+float(knob("big_hold")))*v
	return (2.0*float(knob("roll"))+float(knob("hold")))*v

func _beat(kind: String, low: String, at: float, size: float) -> Dictionary:
	var beat := {"kind":kind,"low":low,"at":at,"size":size,"long":_beat_long(kind)}
	if kind == "D": beat["plunge"] = float(knob("climb"))*float(knob("speed"))
	return beat

func _lay_beats() -> Array:
	var out: Array = []
	var given: Array = knob("moves")
	var loop := loop_length()
	if not given.is_empty():
		for m: Array in given:
			var kind := String(m[0])
			var low := kind.substr(1,1) if kind.begins_with("V") else kind
			var size := float(m[2]) if m.size() > 2 else float(knob("max_bank"))
			out.append(_beat(kind.substr(0,1),low,float(m[1])*loop,size))
		return out
	var pattern := String(knob("pattern"))
	if pattern.is_empty(): return out
	# The leg's last `big` banks are big rolls, their wing kept low.
	var kinds: Array = []
	for c in pattern: kinds.append(c)
	var left := int(knob("big"))
	for i in range(kinds.size()-1,-1,-1):
		if left <= 0: break
		if kinds[i] == "L" or kinds[i] == "R":
			kinds[i] = "V"+String(kinds[i])
			left -= 1
	var banks := 0
	for k: String in kinds: if k == "L" or k == "R": banks += 1
	var calm := float(knob("calm"))
	for leg: Dictionary in _legs:
		var from: float = float(leg.from)+calm
		var room: float = float(leg.long)-2.0*calm
		var used := 0.0
		for k: String in kinds: used += _beat_long(k.substr(0,1))
		var gap := (room-used)/float(maxi(kinds.size()-1,1))
		var at := from
		var bank_i := 0
		for k: String in kinds:
			var kind := k.substr(0,1)
			var size := float(knob("max_bank"))
			if kind == "L" or kind == "R":
				var share := 1.0-float(knob("ramp"))*(1.0-(float(bank_i)/float(banks-1) if banks > 1 else 1.0))
				size *= share
				bank_i += 1
			out.append(_beat(kind,k.substr(k.length()-1,1),fposmod(at,loop),size))
			at += _beat_long(kind)+gap
	return out

## The dive: climb `height`, then down at A (his fall's acceleration x
## dive) for `plunge` s, then pulled out at B to level where it began.
func _dive_numbers() -> Dictionary:
	if not _dive.is_empty(): return _dive
	var p := pilot()
	var a := p.gravity*p.fall*float(knob("dive"))
	var tp := float(knob("plunge"))
	var v1 := a*tp
	var d1 := 0.5*a*tp*tp
	var rest := maxf(float(knob("height"))-d1,0.1)
	var b := v1*v1/(2.0*rest)
	_dive = {"a":a,"plunge":tp,"v1":v1,"d1":d1,"b":b,"out":v1/b}
	return _dive

## How far into a beat starting at `at` the loop's `d` is (s at its pace).
func _into(d: float, at: float) -> float:
	var loop := loop_length()
	return wrapf(d-at,-loop*0.5,loop*0.5)/float(knob("speed"))

## Height (m) of the dives at `d` (0 level).
func _dive_y(d: float) -> float:
	var y := 0.0
	for beat: Dictionary in beats():
		if beat.kind != "D": continue
		var t := _into(d,float(beat.at))
		var dv := _dive_numbers()
		var tc := float(knob("climb"))
		var h := float(knob("height"))
		if t <= 0.0 or t >= tc+dv.plunge+dv.out: continue
		if t < tc: y += h*smoothstep(0.0,1.0,t/tc)
		elif t < tc+dv.plunge:
			var u: float = t-tc
			y += h-0.5*dv.a*u*u
		else:
			var u: float = t-tc-dv.plunge
			y += h-dv.d1-(dv.v1*u-0.5*dv.b*u*u)
	return y

## The pitch the dives give at `d` (+ nose up): up through the climb, down
## through the plunge and the pull-out, each a smooth swell to max_pitch
## (the path's own slope is far steeper: a back that followed it would be
## a wall).
func _dive_pitch(d: float) -> float:
	var tc := float(knob("climb"))
	var most := float(knob("max_pitch"))
	var out := 0.0
	for beat: Dictionary in beats():
		if beat.kind != "D": continue
		var dv := _dive_numbers()
		var t := _into(d,float(beat.at))
		var down: float = dv.plunge+dv.out
		if t <= 0.0 or t >= tc+down: continue
		if t < tc: out += most*sin(PI*t/tc)
		else: out -= most*sin(PI*(t-tc)/down)
	return out

## The bank the banks ask at `d` (+ right wing up, left low).
func _beat_bank(d: float) -> float:
	var roll := maxf(float(knob("roll")),0.05)
	var hold := float(knob("hold"))
	var out := 0.0
	for beat: Dictionary in beats():
		if beat.kind != "L" and beat.kind != "R": continue
		var t := _into(d,float(beat.at))
		if t <= 0.0 or t >= 2.0*roll+hold: continue
		var k := smoothstep(0.0,1.0,t/roll)*(1.0-smoothstep(0.0,1.0,(t-roll-hold)/roll))
		out += k*float(beat.size)*(1.0 if beat.kind == "L" else -1.0)
	return out

## The big rolls' bank at `d`.
func _big_bank(d: float) -> float:
	var roll := maxf(float(knob("big_roll")),0.05)
	var hold := float(knob("big_hold"))
	var out := 0.0
	for beat: Dictionary in beats():
		if beat.kind != "V": continue
		var t := _into(d,float(beat.at))
		if t <= 0.0 or t >= 2.0*roll+hold: continue
		var k := smoothstep(0.0,1.0,t/roll)*(1.0-smoothstep(0.0,1.0,(t-roll-hold)/roll))
		out += k*float(knob("big_tilt"))*(1.0 if beat.low == "L" else -1.0)
	return out

## The big roll at `d`: {beat, phase ("tell", "in", "hold", "out"), t (s
## from its start)}, or {}.
func big_at(d := NAN) -> Dictionary:
	if is_nan(d): d = s
	var roll := float(knob("big_roll"))
	var hold := float(knob("big_hold"))
	for beat: Dictionary in beats():
		if beat.kind != "V": continue
		var t := _into(d,float(beat.at))
		if t < -float(knob("big_tell")) or t >= 2.0*roll+hold: continue
		var phase := "tell" if t < 0.0 else ("in" if t < roll else ("hold" if t < roll+hold else "out"))
		return {"beat":beat,"phase":phase,"t":t}
	return {}

## Banked into the turns by `turn_bank` (rad per rad/m of turn).
func _turn_bank(d: float) -> float:
	var tb := float(knob("turn_bank"))
	if tb == 0.0: return 0.0
	return tb*curvature_at(d)*float(knob("radius"))

## The ray's frame (local to the trap) at `d` (m along the loop).
func pose_at(d: float) -> Transform3D:
	var loop := loop_length()
	var dw := fposmod(d,loop)
	var p := path_at(dw)
	var t := _tangent(dw)
	var climb := clampf(atan2(t.y,Vector2(t.x,t.z).length()),-float(knob("max_pitch")),float(knob("max_pitch")))
	var ptch := _dive_pitch(dw)+climb
	# The wobble a whole number of times round the loop, so it meets itself.
	var waves := maxf(roundf(loop*float(knob("shake_rate"))/(TAU*float(knob("speed")))),1.0)
	var wobble := float(knob("shake"))*sin(TAU*waves*dw/loop)
	var bk := _beat_bank(dw)+_turn_bank(dw)+wobble
	# Held under the motor's own slide angle, but for the big roll.
	var steepest := deg_to_rad(PilotMotor.SLIDE_AUTO-TILT_MARGIN)
	var most := acos(clampf(cos(steepest)/cos(ptch),-1.0,1.0))
	bk = clampf(bk,-most,most)+_big_bank(dw)
	var basis := Basis(Vector3.UP,heading_at(dw))*Basis(Vector3.RIGHT,ptch)*Basis(Vector3(0.0,0.0,1.0),bk)
	return Transform3D(basis,p)

## The path, moves and timing laid afresh from the knobs (after changing
## them).
func replan() -> void:
	_plan = []
	_dive = {}
	_lay_path()

func build() -> void:
	replan()
	var w := float(knob("width"))
	var l := float(knob("long"))
	var th := float(knob("thick"))
	body = StaticBody3D.new()
	add_child(body)
	_meshes = []
	# A thin hide out to the rim over a thick body inset from it, as a
	# ray's wings thin to their edge: slid past the rim there is nothing
	# under his feet to stand on, only the lip to catch.
	var hide := float(knob("hide"))
	var inset := float(knob("inset"))
	_add(Vector3(0.0,-hide*0.5,0.0),Vector3(w,hide,l),paint(SKIN),true)
	_add(Vector3(0.0,-hide-(th-hide)*0.5,0.0),Vector3(w-2.0*inset,th-hide,l-2.0*inset),paint(SKIN),true)
	# Ridges on its back: two along it, near each rim, the left one forward
	# and the right one aft with open back between (cover from a bank's
	# slide, if he gets behind the right one in time), two across it (from
	# a pitch's).
	var rh: float = pilot().jumps[0]*0.7
	var rt: float = Ground.RADIUS*2.0*WorldScale.wanderer
	ridges = []
	for r: Array in [[-w*0.3,-l*0.25,rt,l*0.3],[w*0.3,l*0.25,rt,l*0.3],[w*0.12,-l*0.38,w*0.3,rt],[-w*0.12,l*0.38,w*0.3,rt]]:
		_add(Vector3(r[0],rh*0.5,r[1]),Vector3(r[2],rh,r[3]),paint(RIDGE),true)
		ridges.append([Rect2(r[0]-r[2]*0.5,r[1]-r[3]*0.5,r[2],r[3]),rh])
	# The handholds: low rails along its length, rows across it, each with a
	# bright lip that lights up through a big roll.
	rails = []
	rail_half = l*float(knob("rail_long"))*0.5
	rail_mat = paint(RAIL_LIP)
	var n := int(knob("rails"))
	var ah := float(knob("rail_high"))
	var at := float(knob("rail_thick"))
	for i in range(n):
		var x := (float(i)-float(n-1)*0.5)*float(knob("rail_gap"))
		rails.append(x)
		_add(Vector3(x,ah*0.5,0.0),Vector3(at,ah,rail_half*2.0),paint(RAIL),true)
		_add(Vector3(x,ah+0.02,0.0),Vector3(at*1.15,0.05,rail_half*2.0),rail_mat,false)
	# The head (it dips), a tail, and the wing edges (they lift).
	head = _add(Vector3(0.0,-th*0.5,-l*0.5-0.9),Vector3(w*0.3,th*0.8,1.8),paint(HEAD_COLOUR),false)
	_add(Vector3(0.0,-th*0.5,l*0.5+1.4),Vector3(0.4,th*0.5,2.8),paint(HEAD_COLOUR),false)
	for side in [-1.0,1.0]:
		var m := paint(WING)
		wing_mats.append(m)
		var wing := _add(Vector3(side*(w*0.5+0.5),-th*0.5,0.0),Vector3(1.0,th*0.4,l*0.8),m,false)
		if side < 0.0: wing_l = wing
		else: wing_r = wing
	clock = cycle()-float(knob("arrive"))
	s = d_at(clock)
	_pose()

## A box of the creature: with collision if `solid`.
func _add(at: Vector3, size: Vector3, mat: StandardMaterial3D, solid: bool) -> MeshInstance3D:
	if solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = at
		body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.position = at
	mesh.material_override = mat
	body.add_child(mesh)
	_meshes.append([mesh,at])
	return mesh

func _pose() -> void:
	if body == null: return
	body.transform = pose_at(s)
	# Straight to the physics server: a node's move reaches it only when the
	# tree flushes its transform notifications, after this frame's step, so
	# the motor's ground rays would read the back where it was a frame ago.
	if body.is_inside_tree(): PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,body.global_transform)
	var b := body.transform.basis
	pitch = asin(clampf(b.z.y*-1.0,-1.0,1.0))
	bank = atan2(b.x.y,b.y.y)

## Is `feet` (world) on its back (grounded there)?
func on_back(feet: Vector3) -> bool:
	var l := local_of(feet)
	return absf(l.x) <= float(knob("width"))*0.5+0.1 and absf(l.z) <= float(knob("long"))*0.5+0.1 and l.y >= -0.3 and l.y <= pilot().jumps[0]*0.7+0.4

## `p` (world) in the back's frame (its top at y 0).
func local_of(p: Vector3) -> Vector3:
	return body.transform.affine_inverse()*to_local(p)

## The back's frame point `local` in the world.
func world_of(local: Vector3) -> Vector3:
	return to_global(body.transform*local)

## Is he holding its rim (catching, hanging, climbing onto it)?
func holds_rim() -> bool:
	if motor == null or not motor.on_ledge() or holds_rail(): return false
	var l := local_of(motor.lip)
	return absf(l.x) <= float(knob("width"))*0.5+0.3 and absf(l.z) <= float(knob("long"))*0.5+0.3 and absf(l.y) <= 0.4

## Is he holding a handhold (the trap holding him)?
func holds_rail() -> bool:
	return grip_rail >= 0 and motor != null and motor.rider == self

## The back's tilt from level (rad).
func tilt() -> float:
	return acos(clampf(normal().y,-1.0,1.0))

## The world point that is `local` (the back's frame) at clock `t`.
func _point(t: float, local: Vector3) -> Vector3:
	return global_transform*(pose_at(d_at(t))*local)

## The velocity (m/s) and acceleration (m/s²) of the back's point `local`,
## at clock `t` (now if NAN).
func velocity_of(local: Vector3, t := NAN) -> Vector3:
	if is_nan(t): t = clock
	var e := 1.0/60.0
	return (_point(t+e,local)-_point(t-e,local))/(2.0*e)

func acceleration_of(local: Vector3, t := NAN) -> Vector3:
	if is_nan(t): t = clock
	var e := 1.0/60.0
	return (_point(t+e,local)-2.0*_point(t,local)+_point(t-e,local))/(e*e)

## The back's up (world).
func normal() -> Vector3:
	return (global_transform.basis*body.transform.basis*Vector3.UP).normalized()

func before(delta: float) -> void:
	if body == null or delta <= 0.0: return
	if grip_rail >= 0 and not holds_rail(): grip_rail = -1
	var gripping := holds_rail()
	# A stunned body down on its back rides it as a body does (carried,
	# slid, shed or thrown off), never grabbing a rail itself.
	var riding := gripping or (motor != null and motor.rider == null and not motor.swimming and not motor.seized() \
		and ((motor.grounded and on_back(motor.feet)) or holds_rim()))
	_was_riding = riding
	_tossed = false
	var was := body.transform
	var was_t := clock
	var was_d := s
	# Where he is on its back, before it moves.
	var lp := Vector3.ZERO
	if riding: lp = local_of(motor.lip if motor.on_ledge() else motor.feet)
	clock += delta
	s = d_at(clock)
	_pose()
	if not riding:
		slip = Vector2.ZERO
		_tells()
		return
	riding_time += delta
	# Its velocity under him as the frame begins: what he keeps leaving it.
	_v_point = velocity_of(lp,was_t)
	var moved := global_transform*(body.transform*was.affine_inverse())*global_transform.affine_inverse()
	var turn := wrapf(heading_at(s)-heading_at(was_d),-PI,PI)
	var big := big_at()
	var steep := tilt()
	if gripping:
		# Held on a handhold: carried, then posed by `ride` in his step.
		motor.carry(moved,turn)
		_tells()
		return
	if motor.on_ledge() and not big.is_empty() and steep > float(knob("hang_from")):
		# Hanging from the motor's catch through a big roll: a rail is taken
		# over as a handhold; the rim (a hang the roll turns under the body)
		# is shaken off.
		var rail := _rail_of(local_of(motor.lip))
		if rail >= 0 and motor.hold == "hang":
			motor.carry(moved,turn)
			_grab(rail,local_of(motor.lip).z,_high_side(big.beat))
		else:
			sheds += 1
			_off(_v_point+normal()*float(knob("shed_push")),true)
		_tells()
		return
	# On his feet: lifted off, slid, or thrown over the rim, worked out
	# before the carry (off, he flies on from where he was at its velocity
	# as the frame began, as it moves on under him).
	var to := lp
	if motor.grounded:
		if not big.is_empty() and big.phase != "out" and motor.move != "tumble" and _try_grab(lp,big.beat,moved,turn):
			_tells()
			return
		if steep > float(knob("shed_tilt")):
			# Too steep to be on: off it (no standing on a wall), pushed clear.
			sheds += 1
			var n := normal()
			var down := (Vector3.DOWN-Vector3.DOWN.dot(n)*n).normalized()
			var slid := global_transform.basis*(body.transform.basis*Vector3(slip.x,0.0,slip.y))
			_off(_v_point+down*maxf(slid.dot(down),float(knob("shed_slide")))+n*float(knob("shed_push")),true)
			_tells()
			return
		to = _slide(delta,lp,was_t)
		if _tossed:
			_tells()
			return
	else:
		# Off a rail's step his slide runs on; properly off it, it is gone.
		_air_high = maxf(_air_high,lp.y)
		if lp.y > float(knob("rail_high"))+0.3: slip = Vector2.ZERO
	motor.carry(moved,turn)
	if to != lp: motor.carry(Transform3D(Basis.IDENTITY,global_transform.basis*(body.transform.basis*(to-lp))),0.0)
	_tells()

## The high side of a big roll (+1: the back's +x goes up).
func _high_side(beat: Dictionary) -> float:
	return 1.0 if beat.low == "L" else -1.0

## The rail whose top `l` (its frame) is on, or -1.
func _rail_of(l: Vector3) -> int:
	var at := float(knob("rail_thick"))
	for i in range(rails.size()):
		if absf(l.x-float(rails[i])) <= at*0.5+0.15 and absf(l.y-float(knob("rail_high"))) <= 0.2 and absf(l.z) <= rail_half+0.1: return i
	return -1

## The grab: moving toward the high wing with a rail in reach that way (or
## just passed), the nearest is caught. Carried first. Whether he caught.
func _try_grab(lp: Vector3, beat: Dictionary, moved: Transform3D, turn: float) -> bool:
	var hs := _high_side(beat)
	var to_back := (global_transform.basis*body.transform.basis).inverse()
	var hl := to_back*Vector3(motor.velocity.x,0.0,motor.velocity.z)
	if hl.x*hs < float(knob("grab_pace")) or absf(lp.z) > rail_half: return false
	var behind := float(knob("rail_thick"))*0.5+Ground.RADIUS*WorldScale.wanderer+0.05
	var best := -1
	var near := INF
	for i in range(rails.size()):
		var dx := (float(rails[i])-lp.x)*hs
		if dx < -behind or dx > float(knob("grab_reach")): continue
		if absf(dx) < near:
			near = absf(dx)
			best = i
	if best < 0: return false
	motor.carry(moved,turn)
	_grab(best,lp.z,hs)
	return true

## Caught rail `i` at `z` along it, `hs` the high side: the trap holds him.
func _grab(i: int, z: float, hs: float) -> void:
	grip_rail = i
	grip_z = clampf(z,-rail_half+0.2,rail_half-0.2)
	grip_side = hs
	_grip_shimmy = 0.0
	_grip_away = 0.0
	slip = Vector2.ZERO
	grabs += 1
	motor.rider = self
	motor.velocity = Vector3.ZERO
	motor.skidding = false
	motor.chain = 0
	motor.sail.rest()
	var g := _grip_pose()
	_grip_hang = g.hang
	_grip_snap = motor.feet-(g.feet as Vector3)
	_apply_grip(g,0.0)

## Where he is held now: {hang, feet (world), lip, out (x z, away from the
## back), face (x z, the way he faces)}. Crouched gripping it, below the
## rail on the low side, while the back is gentle; hanging from its lip
## (its top's corner on the high side) past `hang_from`, the motor's hang
## under it, kept clear of the back.
func _grip_pose() -> Dictionary:
	var xr := float(rails[grip_rail])
	var hs := grip_side
	var at := float(knob("rail_thick"))
	var r: float = Ground.RADIUS*WorldScale.wanderer
	var n := normal()
	if tilt() < float(knob("hang_from")):
		var feet := world_of(Vector3(xr-hs*(at*0.5+r),0.0,grip_z))
		var hw := global_transform.basis*body.transform.basis*Vector3(hs,0.0,0.0)
		var face := Vector2(hw.x,hw.z)
		if face.length() < 0.1: face = PilotMotor.forward(motor.facing)
		return {"hang":false,"feet":feet,"face":face.normalized(),"out":-face.normalized()}
	var lip := world_of(Vector3(xr+hs*at*0.5,float(knob("rail_high")),grip_z))
	var nh := Vector3(n.x,0.0,n.z).normalized()
	var feet := lip+nh*motor.hang_out+Vector3.DOWN*motor.hang_drop
	var lf := local_of(feet)
	if lf.y < 0.05:
		lf.y = 0.05
		feet = world_of(lf)
	return {"hang":true,"feet":feet,"lip":feet+Vector3.UP*motor.hang_drop-nh*motor.hang_out,"out":Vector2(nh.x,nh.z),"face":-Vector2(nh.x,nh.z)}

func _apply_grip(g: Dictionary, delta: float) -> void:
	if g.hang != _grip_hang:
		# Crouched to hanging (or back): eased over from where he was.
		_grip_snap = motor.feet-(g.feet as Vector3)
		_grip_hang = g.hang
	if delta > 0.0: _grip_snap = _grip_snap.lerp(Vector3.ZERO,1.0-exp(-delta/(PilotMotor.GRAB_SNAP*0.35)))
	motor.feet = (g.feet as Vector3)+_grip_snap
	var face := PilotMotor.facing_of(g.face)
	motor.facing = face if delta <= 0.0 else rotate_toward(motor.facing,face,PilotMotor.HANG_TURN*delta)
	motor.shimmy = _grip_shimmy
	if g.hang:
		motor.hold = "hang"
		motor.grounded = false
		motor.move = ""
		motor.lip = (g.lip as Vector3)+_grip_snap
		motor.lip_out = g.out
	else:
		motor.hold = ""
		motor.grounded = true
		motor.move = "crouch"
		motor.ground_y = motor.feet.y

## One step held on a handhold (the motor's rider): the stick along the
## rail shimmies him; held away from it (DROP_HOLD) he lets go; rolled back
## under `stand_tilt` he is set on his feet beside it. Jump does nothing
## (he can't climb a wall; the roll brings him back up).
func ride(walker: PilotMotor, delta: float, want: Vector2, _pressed: bool) -> Dictionary:
	var out := {}
	var along := global_transform.basis*body.transform.basis*Vector3(0.0,0.0,1.0)
	var way := Vector2(along.x,along.z)
	way = way.normalized() if way.length() > 1e-3 else Vector2.ZERO
	var a := want.dot(way)
	var goal := signf(a)*PilotMotor.SHIMMY*minf(absf(a)/0.9,1.0) if absf(a) > 0.3 else 0.0
	_grip_shimmy = move_toward(_grip_shimmy,goal,PilotMotor.SHIMMY_ACCEL*delta)
	grip_z += _grip_shimmy*delta
	var end := rail_half-0.2
	if absf(grip_z) > end:
		grip_z = clampf(grip_z,-end,end)
		_grip_shimmy = 0.0
	var g := _grip_pose()
	var away: Vector2 = g.out
	_grip_away = _grip_away+delta if want.dot(away) > PilotMotor.PUSH and absf(a) < want.dot(away) else 0.0
	if _grip_away >= PilotMotor.DROP_HOLD:
		out["let_go"] = true
		if g.hang:
			_release()
			_tossed = true
			walker.toss(_v_point+Vector3(away.x,0.0,away.y)*0.6)
		else: _set_on(walker)
		return out
	var big := big_at()
	if tilt() <= float(knob("stand_tilt")) and (big.is_empty() or big.phase == "out"):
		_set_on(walker)
		set_ons += 1
		out["climbed"] = true
		return out
	_apply_grip(g,delta)
	walker.velocity = Vector3(along.x,0.0,along.z).normalized()*_grip_shimmy if way != Vector2.ZERO else Vector3.ZERO
	return out

func _release() -> void:
	grip_rail = -1
	_grip_shimmy = 0.0
	_grip_snap = Vector3.ZERO

## Set on his feet beside the rail he held, on its low side.
func _set_on(walker: PilotMotor) -> void:
	var xr := float(rails[grip_rail])
	var at := float(knob("rail_thick"))
	var r: float = Ground.RADIUS*WorldScale.wanderer
	var feet := world_of(Vector3(xr-grip_side*(at*0.5+r+0.05),0.0,grip_z))
	_release()
	walker.rider = null
	walker.hold = ""
	walker.shimmy = 0.0
	walker.move = ""
	walker.grounded = true
	walker.velocity = Vector3.ZERO
	walker.feet = feet
	walker.ground_y = feet.y
	slip = Vector2.ZERO

## On its back at `lp` (its frame): lifted off where it drops away faster
## than he falls, else slid by gravity along the back and the swing of its
## flight, held by friction, stopped by the ridges; over the rim fast,
## thrown, slower left to the motor's catch. Where he slides to (its frame).
func _slide(delta: float, lp: Vector3, was_t: float) -> Vector3:
	var on := Vector3(lp.x,0.0,lp.z)
	var a := acceleration_of(on,was_t+delta*0.5)
	var n := normal()
	var g_air: float = motor.gravity*(motor.fall if _v_point.y <= 0.0 else 1.0)
	if (a-Vector3.DOWN*g_air).dot(n) < 0.0:
		# Lighter than nothing: off it, floating with its way.
		_off(_v_point,false)
		return lp
	if motor.move == "slide":
		# Surfing (crouched on a slope, or too steep to stand): the motor
		# slides him itself.
		slip = Vector2.ZERO
		return lp
	var g := Vector3.DOWN*motor.gravity
	var load := (a-g).dot(n)
	last_load = load
	var along := float(knob("pull"))*(g-g.dot(n)*n)-float(knob("swing"))*(a-a.dot(n)*n)
	var to_back := (global_transform.basis*body.transform.basis).inverse()
	var pl := to_back*along
	var pull := Vector2(pl.x,pl.z)
	var hl := to_back*Vector3(motor.velocity.x,0.0,motor.velocity.z)
	var walk := Vector2(hl.x,hl.z)
	var lean := 0.0
	if pull.length() > 1e-3: lean = clampf(walk.dot(-pull.normalized())/maxf(float(knob("lean_pace")),0.01),0.0,1.0)
	var mu := float(knob("grip"))+float(knob("lean"))*lean
	last_grip = mu
	var cap := mu*maxf(load,0.0)
	if slip.length() < 0.05 and pull.length() <= cap:
		slip = Vector2.ZERO
	else:
		slip += pull*delta
		var pace := maxf(slip.length()-cap*delta,0.0)
		slip = slip.normalized()*pace if slip.length() > 1e-5 else Vector2.ZERO
	if slip == Vector2.ZERO: return lp
	var to := lp+Vector3(slip.x,0.0,slip.y)*delta
	to = _ridged(lp,to,lp.y)
	var w := float(knob("width"))*0.5
	var l := float(knob("long"))*0.5
	if (absf(to.x) > w or absf(to.z) > l) and slip.length() > float(knob("catch_pace")) and lean < 0.3:
		# Over the rim too fast to take it: thrown off.
		throws += 1
		_off(_v_point+global_transform.basis*(body.transform.basis*Vector3(slip.x,0.0,slip.y)),true)
		return lp
	return to

## A slide from `from` to `to` (the back's frame) stopped by the ridges:
## his body (its radius) kept out of them, the slide into one ended.
func _ridged(from: Vector3, to: Vector3, y: float) -> Vector3:
	var rad: float = Ground.RADIUS*WorldScale.wanderer
	for r: Array in ridges:
		if y > float(r[1])-0.1: continue
		var box: Rect2 = (r[0] as Rect2).grow(rad)
		var p := Vector2(to.x,to.z)
		if not box.has_point(p): continue
		var was := Vector2(from.x,from.z)
		if was.x <= box.position.x or was.x >= box.end.x:
			to.x = box.position.x-0.001 if was.x <= box.position.x else box.end.x+0.001
			slip.x = 0.0
		elif was.y <= box.position.y or was.y >= box.end.y:
			to.z = box.position.y-0.001 if was.y <= box.position.y else box.end.y+0.001
			slip.y = 0.0
	return to

## Off its back at `v` (world, m/s) with his own run on it, facing kept.
func _off(v: Vector3, thrown: bool) -> void:
	if not thrown: floats += 1
	var face: float = motor.facing
	motor.toss(v+Vector3(motor.velocity.x,0.0,motor.velocity.z))
	motor.facing = face
	slip = Vector2.ZERO
	_tossed = true

## After his step: off its back by his own doing (a jump, a step off, let
## go), he keeps its velocity; landed on it, his run is taken relative to it.
func after(_delta: float, events: Dictionary) -> void:
	if body == null or motor == null or holds_rail(): return
	if _was_riding and not _tossed and not motor.grounded and not motor.on_ledge() and not motor.swimming:
		motor.velocity += _v_point
	if events.has("landed") and motor.grounded and on_back(motor.feet):
		var v := velocity_of(local_of(motor.feet))
		motor.velocity.x -= v.x
		motor.velocity.z -= v.z
		# Down off a rail's step, the slide runs on.
		if _air_high > float(knob("rail_high"))+0.3 or not _was_riding: slip = Vector2.ZERO
		# Teched onto its back (the motor's stun tech, a press just before
		# the touch): latched onto the nearest rail, held by it.
		if events.get("teched","") == "land": _latch()
	if motor.grounded: _air_high = -INF

## A stunned pilot teched onto its back: the nearest rail (within
## `grab_reach` and a body's width) is caught, from the side he is on.
## Whether he latched.
func _latch() -> bool:
	if rails.is_empty() or motor.rider != null: return false
	var lp := local_of(motor.feet)
	if absf(lp.z) > rail_half+0.2: return false
	var best := -1
	var near := INF
	for i in range(rails.size()):
		var dx := absf(float(rails[i])-lp.x)
		if dx < near:
			near = dx
			best = i
	if best < 0 or near > float(knob("grab_reach"))+Ground.RADIUS*WorldScale.wanderer*2.0: return false
	var hs := signf(float(rails[best])-lp.x)
	if hs == 0.0: hs = 1.0
	_grab(best,lp.z,hs)
	latches += 1
	return true

## The beat coming (or under way, for a roll), and how far off: {beat, lead
## (s to its moment: a roll's start, a dive's plunge)}, or {}.
func next_beat() -> Dictionary:
	var best := {}
	for beat: Dictionary in beats():
		var moment: float = float(beat.at)+(float(beat.plunge) if beat.kind == "D" else 0.0)
		var lead := -_into(s,moment)
		var after_by := 0.0
		if beat.kind == "V": after_by = 2.0*float(knob("big_roll"))+float(knob("big_hold"))
		elif beat.kind != "D": after_by = float(knob("roll"))
		if lead < -after_by: continue
		if best.is_empty() or lead < float(best.lead): best = {"beat":beat,"lead":lead}
	return best

## Head down before a dive, the wing that will rise up before a bank; before
## a big roll the high wing lifts high and glows, the body shudders and the
## handholds light up, with a long screech.
func _tells() -> void:
	var dive := 0.0
	var lift := 0.0
	var big := 0.0
	var rising: MeshInstance3D = null
	var coming := next_beat()
	if not coming.is_empty():
		var beat: Dictionary = coming.beat
		var tell := maxf(float(knob("big_tell") if beat.kind == "V" else knob("tell")),0.05)
		var amount := clampf(1.0-float(coming.lead)/tell,0.0,1.0)
		if beat.kind == "D": dive = amount
		else:
			lift = amount
			var low: String = beat.low if beat.kind == "V" else beat.kind
			rising = wing_l if low == "R" else wing_r
			if beat.kind == "V": big = amount
	head.rotation.x = -dive*0.6
	head.position.y = -float(knob("thick"))*0.5-dive*0.5
	for wing: MeshInstance3D in [wing_l,wing_r]:
		var up := lift*(1.8 if big > 0.0 else 1.0) if wing == rising else 0.0
		wing.rotation.z = up*0.5*(1.0 if wing == wing_r else -1.0)
		wing.position.y = -float(knob("thick"))*0.5+up*0.5
	for i in range(2):
		var m := wing_mats[i]
		var on := lift if rising == (wing_l if i == 0 else wing_r) else 0.0
		m.albedo_color = WING.lerp(TELL,on)
		m.emission_enabled = big > 0.0 and on > 0.0
		m.emission = TELL
		m.emission_energy_multiplier = big*2.0
	# The whole body shudders through the big roll's tell (the drawn boxes
	# only: the back he stands on keeps still).
	var shudder := big*(1.0 if big < 1.0 else 0.0)
	for pair: Array in _meshes:
		var mesh: MeshInstance3D = pair[0]
		var base: Vector3 = pair[1]
		if mesh == head or mesh == wing_l or mesh == wing_r: continue
		mesh.position = base+Vector3(sin(clock*61.0),sin(clock*47.0+1.0),0.0)*0.04*shudder
	rail_mat.emission_enabled = big > 0.0
	rail_mat.emission = RAIL_LIP
	rail_mat.emission_energy_multiplier = big*3.0
	if lift > 0.05 and big > 0.0 and _big_ready:
		_big_ready = false
		_whoosh_ready = false
		tell_sound(&"screech_long",to_global(body.position))
	elif lift > 0.05 and big == 0.0 and _whoosh_ready:
		_whoosh_ready = false
		tell_sound(&"whoosh",to_global(body.position))
	elif lift == 0.0:
		_whoosh_ready = true
		_big_ready = true
	if dive > 0.05 and _screech_ready:
		_screech_ready = false
		tell_sound(&"screech",to_global(body.position))
	elif dive == 0.0: _screech_ready = true
	tell_sight(maxf(lift,dive))

func reset() -> void:
	super()
	replan()
	# Coming in to the start deck, stopped there `arrive` s from now.
	if motor != null and holds_rail():
		motor.rider = null
		motor.hold = ""
	clock = cycle()-float(knob("arrive"))
	s = d_at(clock)
	slip = Vector2.ZERO
	riding_time = 0.0
	floats = 0
	throws = 0
	grabs = 0
	latches = 0
	set_ons = 0
	sheds = 0
	grip_rail = -1
	_whoosh_ready = true
	_screech_ready = true
	_big_ready = true
	_was_riding = false
	_tossed = false
	_pose()
