extends "res://scripts/kit_isle/motif_greybox.gd"
## The Procession, a place of the underground Olmec city: a gulf
## between a high arrival headland and a low far isle with a lit gate. The
## old causeway that joined them has fallen; only its piers stand, broken off
## in the haze. Eleven headless bodies were walking it when it went. They lie
## face-down along its line, all facing the gate, each with its hands braced
## on the back of the one in front. Their backs are the bridge.
##
##   A  the arrival headland: turf rising west from the terrace at its tip
##      (0 m) in a long slope and a broken rock band, knolls on it. The
##      tip's lip is the causeway's abutment, rune-cut; the first body's
##      heels lie against it, 1.6 m down. The perch is a broken pier on the
##      terrace, a fallen block its step.
##   the line  eleven lying bodies (STAND-IN: maker_toppled, posed from the
##      real headless body's mesh), each tilted head-up TILT, the next one's
##      heels tucked under its chest, the line bending north as it goes (so
##      the terrace sees it side-on, a sawtooth of backs). At a braced joint
##      its arms reach down onto the next one's back (a rail each). At a gap
##      joint (`gaps`) its hands reach into the air over a broken pier and
##      the next lies a jump further on and lower.
##   the road  the old causeway's piers under every joint, their heads the
##      bodies' supports; off their south faces the deck's broken stubs.
##   F  the far isle (about 13 m down): turf rising in two rock steps to the
##      gate yard, the makers' corbel gate (maker_corbel) in the saddle
##      between two knolls, one lit great cresset by it, the rim out in the
##      gate's far mouth.
##
## Routes (rim in on A's west edge, rim out in the gate's east mouth):
##   the backs   (quiet) walk each back up to its neck stump; at a braced
##               joint walk down an arm or drop off the stump onto the next
##               back; at a gap joint a running jump (the third near his reach).
##   the road    off the terrace's south lip onto the first stub; stub to
##               stub under the bodies' south flanks, a running jump at each
##               break; up onto F's south-west spit.
## The threat: the sixth body breathes. STAND-IN: the real headless body
## (scripts/enemies/headless_body.gd: no lying or rouse state yet) asleep
## on its own pier under the sixth's chest, north of the line, its ears low
## (`hear_noise`): a hard landing near it, or standing on the sixth's back a
## while, wakes it, and it goes to the noise (climbing, leaping, its
## landings' shockwaves).
const OlmecPlaces = preload("res://scripts/enemies/olmec_places.gd")
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const CityBreaks2 = preload("res://scripts/city_kit_breaks2.gd")
const Corbel = preload("res://scripts/city_breaks/corbel_vault.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const Look = preload("res://scripts/enemies/headless_body_look.gd")
const HeadLook = preload("res://scripts/enemies/inhaler_head_look.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const Ground = preload("res://scripts/pilot_physics_ground.gd")
const Trap = preload("res://scripts/traps/trap.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const SC = preload("res://scripts/kit_isle/greybox/gb_stacked_court.gd")

const SO := CityKit.SET_OFF
const SEED := 8200

## Round 4 polish (broken shores, weathered stumps, growth on the bodies,
## roots). `--procession-plain` builds the plain round-4 place for an A/B:
## same routes, the smooth discs and square posts.
static func polish() -> bool:
	return not preload("res://scripts/launch_args.gd").user_args().has("--procession-plain")

## The polish: slumps [x, z, radius, depth] and extra knolls [x, z, radius,
## high] on A (west of its terrace) and on F (x, z from its lip, off the
## ways walked); the edges' noses and bays (m out and in, two passes); the
## roots hung from the shores' lips (count per shore, length m).
const POLISH := {
	"a_slumps":[[-30.0,-13.0,7.0,-1.2],[-44.0,15.0,8.0,-1.4],[-56.0,-15.0,7.0,-1.1],[-21.0,17.0,6.0,-1.0],[-8.0,-18.0,5.0,-0.8]],
	"a_knolls":[[-38.0,-21.0,8.0,1.7],[-40.0,22.0,7.0,1.5],[-64.0,-12.0,7.0,1.4],[-13.0,-22.0,5.0,1.0]],
	"f_bumps":[[8.0,19.0,5.5,1.3],[11.0,-19.0,6.0,1.5],[22.0,20.0,5.0,-0.9],[19.0,-15.0,4.0,-0.7],[30.0,-23.0,5.0,1.3],[2.0,-22.0,4.0,0.9]],
	"bay":[3.4,1.4],"roots":[46,40],
	# The line bowed further (first heading, turn per body: deg), so the
	# terrace sees it at three-quarters, each back in profile. The body
	# whose arms hang into the gulf (1-based).
	"heading":[46.0,-7.0],"hang":8,
	# The gate's shoulders banked in turf (knolls [x, z, radius, high] from
	# F's lip, over the hall's flanks) and fallen stone on its roof.
	"gate_knolls":[[37.0,-10.5,12.5,18.0],[37.0,10.5,12.5,18.0]],
	"lamps":[Vector2(9.0,10.0),Vector2(33.5,-3.2)],
	# More fallen stone, sunk (the `stones` rows): kept off the ways walked.
	"stones":[
		["a","block",-6.5,10.5,Vector3(2.6,1.2,1.8),35.0,6.0,-8.0,0.7],["a","drum",-19.0,10.0,1.1,3.0,-20.0,0.55],
		["a","block",-12.0,-16.0,Vector3(2.2,1.0,1.6),-15.0,-9.0,10.0,0.6],["a","block",-52.0,12.0,Vector3(3.0,1.5,2.0),20.0,-8.0,9.0,0.8],
		["a","drum",-62.0,-14.0,1.3,3.2,55.0,0.6],["a","block",-28.0,-18.0,Vector3(1.0,3.6,0.9),-25.0,9.0,-12.0,1.1],
		["f","block",3.0,15.0,Vector3(2.4,1.2,1.7),-25.0,7.0,8.0,0.6],["f","drum",18.0,-14.0,1.2,2.8,35.0,0.55],
		["f","block",33.0,-14.0,Vector3(1.0,3.4,0.8),12.0,-8.0,10.0,1.0],["f","block",31.0,15.0,Vector3(2.8,1.3,2.0),-40.0,6.0,-9.0,0.6],
	],
}

# --- The layout: one table ----------------------------------------------------------------
## Frame: x east (toward the gate), z south; the line leaves A's tip at x z
## 0 heading east and bends north. A's terrace y 0. Body numbers are the
## model's own (its head height Look.HH), times `body_k`; the gaps are
## shares of the pilot's reach (`reach`).
const LAYOUT := {
	"floor":-90.0,
	# The line: bodies, the live one (1-based), the tilt (deg, head up), the
	# first body's heading and each next one's turn (deg, + toward north),
	# the joints after which the next body lies a gap on [joint, share of
	# the jump's reach, "plain" | "long"], a body's own turn and roll (deg,
	# +-, by seed) so the line isn't a row.
	# `scale`: the bodies drawn this times headless_body's real size, so
	# they read colossal from the rim (the live one stays real size).
	"bodies":11,"live":6,"tilt":15.0,"heading":22.0,"turn":-3.5,"scale":1.45,
	# (A long jump can't be taken off a back: PilotMotor takes it only off
	# ground under SLIDE_FROM, 10 deg, and the backs tilt more. The far one
	# is a plain jump near its reach: a twirl or a pump is the margin.)
	"gaps":[[3,0.7,"plain"],[6,0.8,"plain"],[9,0.9,"plain"]],
	"wobble":Vector2(4.0,4.0),
	# A braced joint: the next heels `slot` m (flat, from the motor: under
	# a walk's carry off the stump) past this neck, `joint_v` model m down
	# in this one's frame: a dark slot, the arms bridging it onto the
	# next one's thighs.
	"slot":0.5,"joint_v":-2.4,
	# A gap joint: the next origin this far down in this one's frame.
	"gap_v":-2.9,
	# The poses: arm angle (deg forward from hanging), drawn in (deg).
	"poses":{"braced":[169.0,9.0],"reach":[132.0,4.0],"hang":[92.0,14.0]},
	# Body 1's heels: tucked under A's lip, its back there 1.6 m under it.
	"first":Vector2(0.15,-1.6),
	# A: outline (x, z), its terrace flat east of `flat`, the slope west of
	# it (m a m), the rock band [x, set-offs, wander], knolls [x, z, radius,
	# high], keel.
	"arrival":{"outline":[Vector2(-66.0,-24.0),Vector2(-52.0,-33.0),Vector2(-36.0,-30.0),Vector2(-22.0,-22.0),Vector2(-12.0,-14.0),Vector2(-5.0,-8.0),
		Vector2(0.0,-5.0),Vector2(0.5,0.0),Vector2(0.0,3.2),Vector2(-3.5,4.5),Vector2(-4.0,9.0),Vector2(-8.0,15.0),Vector2(-16.0,21.0),
		Vector2(-30.0,27.0),Vector2(-46.0,28.0),Vector2(-60.0,22.0),Vector2(-70.0,10.0),Vector2(-73.0,-8.0)],
		"flat":-12.0,"slope":0.12,"band":[-34.0,1.0,5.0],
		"knolls":[[-26.0,17.0,9.0,2.4],[-50.0,-18.0,12.0,3.0],[-58.0,12.0,10.0,1.8],[-18.0,-14.0,6.0,1.2]],
		"depth":34.0,"seed":SEED+1,
		# The abutment at the tip (x0, x1, z0, z1, down).
		"abutment":[-5.0,0.0,-5.0,3.2,12.0],
		# The perch: a broken pier on the terrace [x, z, half x, half z, tall],
		# a fallen block its step [x, z, size, yaw]; the terrace's south lip
		# a set-off lower here (the road's way down) [x0, x1, z from].
		"perch":[-9.0,-10.0,1.6,1.6,2.0*SO],"perch_step":[-9.5,-6.7,Vector3(3.0,SO,2.6),12.0],
		# Where the procession set out: rune-cut steps sunk in the turf up
		# the slope [x from, x to, half width, tread], a broken balustrade
		# along the south lip [from, to (x, z)], two stelae [x, z, yaw, lean].
		"treads":[-24.0,-9.0,3.0,1.8],"balustrade":[Vector2(-15.0,19.2),Vector2(-5.0,8.4)],
		"stelae":[[-3.2,-4.4,10.0,4.0],[-3.4,3.7,-14.0,-9.0]]},
	# F: outline (x, z from its lip, where a twelfth body's heels would lie),
	# its rock steps up east [x from the lip], keel; the gate (x from the
	# lip of its middle, its floor two set-offs up), the knolls either side
	# of it [x, z, radius, high], the cresset.
	"far":{"outline":[Vector2(-3.5,3.0),Vector2(-3.0,10.0),Vector2(3.0,17.0),Vector2(12.0,24.0),Vector2(26.0,28.0),Vector2(38.0,26.0),
		Vector2(46.0,18.0),Vector2(47.5,9.5),Vector2(43.5,8.5),Vector2(43.5,-8.5),Vector2(47.5,-9.5),Vector2(46.0,-19.0),Vector2(38.0,-27.0),
		Vector2(24.0,-30.0),Vector2(12.0,-26.0),Vector2(4.0,-18.0),Vector2(-3.0,-13.5),Vector2(-3.6,-6.5),Vector2(0.4,0.0)],
		"steps":[13.0,21.0],"depth":34.0,"seed":SEED+2,
		"gate":37.0,"knolls":[[37.0,-19.0,15.0,11.0],[37.0,19.0,15.0,11.0],[20.0,-22.0,9.0,2.5]],"cresset":Vector2(27.0,-8.5),
		# Lit lamps on the way up (x, z from the lip), a stair cut into each
		# rock step [z from, z to], stelae flanking the gate [x, z, yaw, lean].
		"lamps":[Vector2(3.0,-6.0),Vector2(15.0,6.5),Vector2(23.5,-5.0)],"stair":[-7.5,-2.5],
		"stelae":[[29.0,-6.8,8.0,3.0],[29.0,6.8,-6.0,-5.0]]},
	# The old road: its deck fallen in slabs, slumped from stump to stump
	# along the line's north side, well under the backs: `off` m off the line (+- `wander`), slab
	# lengths and the gaps between their ends (m, by seed; the gaps under a
	# run's jump at a small drop, `reach`), half widths, its start (x, y
	# under A's south lip) and its end under F's spit (m under F's lip).
	"road":{"off":-9.0,"wander":0.6,"long":Vector2(8.0,12.0),"gap":Vector2(0.9,1.4),"half":Vector2(1.7,2.2),"start":Vector2(-1.5,-4.4),"end_down":1.0,"props":0.55},
	# Stumps of the causeway with nothing on them, off the line [x, z from
	# the line, top (m under A's terrace), half]; every stump leans (deg, +-)
	# and is broken off this far down (m, by seed).
	"free_stumps":[[24.0,-9.0,-3.0,1.6],[52.0,-12.0,-12.5,1.9],[70.0,13.0,-7.0,1.5],[96.0,-8.0,-16.0,1.7]],
	"lean":5.0,"stump_deep":Vector2(12.0,34.0),
	# The sleeper's pier under the sixth (u along the sixth, across m), its
	# feet under the sixth's heels (model m), its ears and its feel (s).
	"sleeper":{"u":4.0,"w":7.0,"down":5.0,"hear_noise":0.6,"feel":4.0},
	# Fallen stone on the shores: [on, "block", x, z, size, yaw, pitch, roll,
	# sunk] on A ("a") or F ("f", x z from F's lip), [on, "drum", x, z,
	# radius, length, yaw, sunk].
	"stones":[
		["a","block",-15.0,8.0,Vector3(4.6,2.0,3.0),24.0,8.0,-6.0,0.8],["a","block",-11.0,12.0,Vector3(2.0,1.3,1.6),-30.0,-12.0,16.0,0.5],
		["a","drum",-24.0,-11.0,1.5,4.0,70.0,0.6],["a","drum",-28.5,-15.0,1.4,2.2,40.0,0.7],
		["a","block",-44.0,16.0,Vector3(1.4,5.0,1.0),15.0,-6.0,12.0,1.3],["a","block",-34.0,18.0,Vector3(3.4,1.6,2.4),-20.0,10.0,8.0,0.6],
		["f","block",6.0,-10.0,Vector3(3.6,1.8,2.6),30.0,12.0,-8.0,0.7],["f","drum",9.0,13.0,1.4,3.4,-25.0,0.6],
		["f","block",15.0,16.0,Vector3(1.2,4.4,0.9),-10.0,8.0,-14.0,1.2],["f","block",30.0,11.5,Vector3(3.0,1.5,2.2),45.0,-10.0,12.0,0.6],
	],
}

# --- Solved from the table -------------------------------------------------------------------

## The bodies' scale: the walker's head times the body's own `head_size`
## (3) over the model's head (headless_body.gd `hh`, enemy_field `numbers`).
static func body_k() -> float:
	var unit := maxf(Ground.HEAD*WorldScale.wanderer,Ground.BODY_LOW+0.3)
	return 3.0*unit/Look.HH*float(LAYOUT.scale)

## How far (m, flat) the pilot carries off a ledge `drop` m over the landing
## at a run: a plain jump (his first, rising on GRAVITY, falling FALL times
## as hard) or a long one (LONG_HEIGHT, LONG_GRAVITY both ways, at
## LONG_SPEED). From the motor's own numbers (Trap.pilot()).
static func reach(kind: String, drop: float) -> float:
	var p: PilotMotor = Trap.pilot()
	if kind == "long":
		var up := sqrt(2.0*PilotMotor.LONG_HEIGHT/PilotMotor.LONG_GRAVITY)
		var down := sqrt(2.0*maxf(PilotMotor.LONG_HEIGHT+drop,0.0)/PilotMotor.LONG_GRAVITY)
		return PilotMotor.LONG_SPEED*(up+down)
	var h := float(p.jumps[0])
	var g := PilotMotor.GRAVITY
	return p.run*(sqrt(2.0*h/g)+sqrt(2.0*maxf(h+drop,0.0)/(g*PilotMotor.FALL)))

static func tilt() -> float:
	return deg_to_rad(float(LAYOUT.tilt))

## Body j's heading (0-based; rad, + toward north).
static func heading(j: int) -> float:
	if polish(): return deg_to_rad(float(POLISH.heading[0])+float(POLISH.heading[1])*j)
	return deg_to_rad(float(LAYOUT.heading)+float(LAYOUT.turn)*j)

## Body j's frame: u along it (head-up TILT), v up off its back, w across
## (its right: south at heading 0).
static func frame_of(j: int) -> Basis:
	var a := tilt()
	return Basis(Vector3.UP,heading(j))*Basis(Vector3(cos(a),sin(a),0.0),Vector3(-sin(a),cos(a),0.0),Vector3(0.0,0.0,1.0))

## A point of body j's frame (u, v model m; w m) in the motif's.
static func on_body(j: int, u: float, v: float, w := 0.0) -> Vector3:
	var k := body_k()
	return (origins()[j] as Vector3)+frame_of(j)*Vector3(u*k,v*k,w)

## The neck end's top (model m): where a back ends; the heels' top, where
## the next one begins (the profile's, `LEGS`, `TORSO`).
const NECK_U := 6.9
const NECK_V := 0.9
const HEEL_V := 0.72

static func gap_of(j: int) -> Array:
	for gp: Array in LAYOUT.gaps:
		if int(gp[0]) == j: return gp
	return []

## The bodies' origins (their heels' line on the front plane), and one
## more past the last: where a twelfth's heels would lie (F's lip). Solved
## once.
static var _origins: Array = []
static func origins() -> Array:
	if not _origins.is_empty(): return _origins
	var k := body_k()
	var a := tilt()
	var first: Vector2 = LAYOUT.first
	var o := Vector3(first.x,first.y-HEEL_V*k*cos(a),0.0)
	var out: Array = [o]
	for j in range(int(LAYOUT.bodies)):
		var b := Basis(Vector3.UP,heading(j))*Basis(Vector3(cos(a),sin(a),0.0),Vector3(-sin(a),cos(a),0.0),Vector3(0.0,0.0,1.0))
		var gp := gap_of(j+1)
		if gp.is_empty():
			var bv := float(LAYOUT.joint_v)*k
			var bdv := bv+(HEEL_V-NECK_V)*k
			o = o+b*Vector3(NECK_U*k+(float(LAYOUT.slot)+bdv*sin(a))/cos(a),bv,0.0)
		else:
			# The next heels `want` m (flat) past this neck's end, `gap_v`
			# down in this frame: the drop and the reach solved together.
			var v := float(LAYOUT.gap_v)*k
			var dv := v+(HEEL_V-NECK_V)*k
			var want := 0.0
			var du := 0.0
			for it in 4:
				var drop := -(du*sin(a)+dv*cos(a))
				want = reach(str(gp[2]),drop)*float(gp[1])
				du = (want+dv*sin(a))/cos(a)
			o = o+b*Vector3(NECK_U*k+du,v,0.0)
		out.append(o)
	_origins = out
	return out

## The joint after body j (1-based): "braced" or "reach" (a gap, or the last
## with its hands on F).
static func pose_of(j: int) -> String:
	if j >= int(LAYOUT.bodies): return "reach"
	if polish() and j == int(POLISH.hang) and gap_of(j).is_empty(): return "hang"
	return "braced" if gap_of(j).is_empty() else "reach"

## F's lip (x, z) and ground: where a twelfth body's heels would lie.
static func far_at() -> Vector3:
	var os := origins()
	var o: Vector3 = os[os.size()-1]
	return Vector3(o.x,o.y+HEEL_V*body_k()*cos(tilt()),o.z)

static func far_y() -> float:
	return far_at().y

## The line's z at x (its heels' line, between the origins).
static func line_z(x: float) -> float:
	var os := origins()
	if x <= (os[0] as Vector3).x: return (os[0] as Vector3).z
	for i in range(os.size()-1):
		var a: Vector3 = os[i]
		var b: Vector3 = os[i+1]
		if x <= b.x: return lerpf(a.z,b.z,(x-a.x)/maxf(b.x-a.x,0.01))
	return (os[os.size()-1] as Vector3).z

## The old road's slabs, from under A's south lip to under F's spit:
## [{a, b (the top's ends, middles), half (across)}]. By seed: lengths,
## gaps, the ends' heights about the straight fall (each gap a step down or
## a hop up under a jump), the wander off the line.
static var _road: Array = []
static func road() -> Array:
	if not _road.is_empty(): return _road
	var rd: Dictionary = LAYOUT.road
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+21
	var st: Vector2 = rd.start
	var f := far_at()
	var x0 := st.x
	var y0 := st.y
	var x1 := f.x-4.5
	var y1 := f.y-float(rd.end_down)
	var lg: Vector2 = rd.long
	var gp: Vector2 = rd.gap
	var hw: Vector2 = rd.half
	var off := float(rd.off)
	var wander := float(rd.wander)
	var fall := func(x: float) -> float: return lerpf(y0,y1,clampf((x-x0)/(x1-x0),0.0,1.0))
	var x := x0
	var last_y := y0
	while x < x1-0.5:
		var length := rng.randf_range(lg.x,lg.y)
		if x+length > x1-4.0: length = x1-x
		var ay := minf(float(fall.call(x))+rng.randf_range(0.0,0.4),last_y+0.3)
		if _road.is_empty(): ay = y0
		var by := float(fall.call(x+length))-rng.randf_range(0.0,0.4)
		if x+length >= x1-0.01: by = y1
		var a := Vector3(x,ay,line_z(x)+off+rng.randf_range(-wander,wander))
		var b := Vector3(x+length,by,line_z(x+length)+off+rng.randf_range(-wander,wander))
		_road.append({"a":a,"b":b,"half":rng.randf_range(hw.x,hw.y)})
		last_y = by
		x += length+rng.randf_range(gp.x,gp.y)
	return _road

## The causeway's stumps: under each road slab's lower end, under each gap
## body's chest (crushed, a rubble wedge on it), and the free ones: [{top
## (its broken top's middle), half (x, z), lean (Basis), deep, kind}].
static var _stumps: Array = []
static func stumps() -> Array:
	if not _stumps.is_empty(): return _stumps
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+22
	var lean := deg_to_rad(float(LAYOUT.lean))
	var dp: Vector2 = LAYOUT.stump_deep
	var add := func(top: Vector3, half: Vector2, kind: String) -> void:
		var bb := Basis.from_euler(Vector3(rng.randf_range(-lean,lean),rng.randf_range(-0.5,0.5),rng.randf_range(-lean,lean)))
		_stumps.append({"top":top,"half":half,"lean":bb,"deep":rng.randf_range(dp.x,dp.y),"kind":kind})
	var ri := 0
	for r: Dictionary in road():
		ri += 1
		# Some slabs lie on their neighbours' ends and a stump; the rest on
		# a stump at their lower end only.
		if ri > 1 and rng.randf() > float(LAYOUT.road.props): continue
		var t := rng.randf_range(0.7,0.95)
		var p: Vector3 = (r.a as Vector3).lerp(r.b,t)
		add.call(p-Vector3.UP*1.0,Vector2(rng.randf_range(1.3,1.9),rng.randf_range(1.3,1.8)),"road")
	var k := body_k()
	for j in int(LAYOUT.bodies):
		if gap_of(j+1).is_empty(): continue
		add.call(on_body(j,5.6,-1.55)-Vector3.UP*1.1*k,Vector2(1.6,1.8),"crushed")
	for fs: Array in LAYOUT.free_stumps:
		var x := float(fs[0])
		add.call(Vector3(x,float(fs[2]),line_z(x)+float(fs[1])),Vector2(float(fs[3]),float(fs[3])*rng.randf_range(0.8,1.2)),"free")
	return _stumps

## A's ground: the terrace flat at its tip; west of it a long slope, a
## broken rock band, knolls.
static func arrival_ground(x: float, z: float) -> float:
	var ad: Dictionary = LAYOUT.arrival
	var flat := float(ad.flat)+1.5*sin(z*0.21)
	var y := maxf(flat-x,0.0)*float(ad.slope)
	var band: Array = ad.band
	var wander := float(band[2])*(0.6*sin(z*0.11+0.7)+0.4*sin(z*0.27+2.1))
	if x < float(band[0])+wander: y += SO*float(band[1])
	for kn: Array in ad.knolls:
		var d := Vector2(x-float(kn[0]),z-float(kn[1])).length()/float(kn[2])
		if d < 1.0: y += float(kn[3])*pow(1.0-d*d,2.0)
	if polish():
		# Held to the terrace's west: a swell and slumps, knolls, none on the
		# way in (z about 0) or the tip.
		var away := smoothstep(-14.0,-22.0,x)
		y += away*0.45*sin(x*0.17+z*0.11)*sin(z*0.23-x*0.07)
		for kn: Array in POLISH.a_knolls+POLISH.a_slumps:
			var d := Vector2(x-float(kn[0]),z-float(kn[1])).length()/float(kn[2])
			if d < 1.0: y += float(kn[3])*pow(1.0-d*d,2.0)
	return y

## F's ground: its lip's, two rock steps up east (wandering) to the gate
## yard; the knolls either side of the gate; the gate's hall kept level
## through the saddle.
static func far_ground(x: float, z: float) -> float:
	var f := far_at()
	var fd: Dictionary = LAYOUT.far
	var lx := x-f.x
	var lz := z-f.z
	var y := f.y
	var kk := 0
	for edge: float in fd.steps:
		var wander := 1.8*sin(lz*0.17+kk*1.3)+0.9*sin(lz*0.37+0.8+kk)
		if lx > edge+wander: y += SO
		kk += 1
	var floor_y := f.y+2.0*SO
	var gx := float(fd.gate)
	if absf(lz) < Corbel.HALF+0.2 and lx > gx-Corbel.BAY_L-2.0: return floor_y
	for kn: Array in fd.knolls:
		var d := Vector2(lx-float(kn[0]),lz-float(kn[1])).length()/float(kn[2])
		if d < 1.0: y = maxf(y,floor_y+float(kn[3])*pow(1.0-d*d,1.5)) if absf(float(kn[1])) > 12.0 else y+float(kn[3])*pow(1.0-d*d,2.0)
	if polish():
		for kn: Array in POLISH.f_bumps:
			var d := Vector2(lx-float(kn[0]),lz-float(kn[1])).length()/float(kn[2])
			if d < 1.0: y += float(kn[3])*pow(1.0-d*d,2.0)
		for kn: Array in POLISH.gate_knolls:
			var d := Vector2(lx-float(kn[0]),lz-float(kn[1])).length()/float(kn[2])
			if d < 1.0: y = maxf(y,floor_y+float(kn[3])*pow(1.0-d*d,1.5))
	return y

static func far_outline() -> Array:
	var f := far_at()
	var out: Array = []
	for p: Vector2 in LAYOUT.far.outline: out.append(p+Vector2(f.x,f.z))
	if polish(): out = ragged(out,SEED+3,func(q: Vector2) -> bool: return q.x > f.x+4.0)
	return out

## An outline with noses and bays: each edge gets a midpoint pushed out or
## in (two passes, the second finer), only where `free` is true of both
## ends (the tip, the lip the line leaves and the road's way are kept).
static func ragged(poly: Array, seed_value: int, free: Callable) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var area := 0.0
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i+1)%poly.size()]
		area += a.x*b.y-b.x*a.y
	var orient := 1.0 if area > 0.0 else -1.0
	var out := poly
	var amp := Vector2(float(POLISH.bay[0]),float(POLISH.bay[1]))
	for pass_i in 2:
		var next: Array = []
		for i in out.size():
			var a: Vector2 = out[i]
			var b: Vector2 = out[(i+1)%out.size()]
			next.append(a)
			if a.distance_to(b) < 4.0 or not (free.call(a) and free.call(b)): continue
			var n := Vector2(b.y-a.y,-(b.x-a.x)).normalized()*orient
			var push := rng.randf_range(0.4,1.0)*(1.0 if rng.randf() < 0.5 else -1.0)*(amp.x if pass_i == 0 else amp.y)*(a.distance_to(b)/10.0 if pass_i == 0 else 1.0)
			next.append((a+b)*0.5+n*clampf(push,-4.5,4.5))
		out = next
	return out

## The gate's floor middle.
static func gate_at() -> Vector3:
	var f := far_at()
	return Vector3(f.x+float(LAYOUT.far.gate),f.y+2.0*SO,f.z)

# --- The motif's face ----------------------------------------------------------------------

func slug() -> String:
	return "procession"

func role() -> String:
	return "hero"

func isle_name() -> String:
	return "The Procession"

func epithet() -> String:
	return "They were halfway over when the road went out from under them."

func brief() -> String:
	return "Cross on their backs, quietly: down each one's arms, or jump where the hands found only air.\nOr the old road's stubs along their south side. The sixth one is breathing."

func start() -> Vector3:
	return Vector3(-62.0,arrival_ground(-62.0,0.0),0.0)

func rims() -> Array:
	var g := gate_at()
	return [
		{"name":"arrival","at":Vector3(-71.0,arrival_ground(-71.0,0.0),0.0),"face":Vector3(-1.0,0.0,0.0),"run_up":14.0,"lip":1.5},
		{"name":"gate","at":Vector3(g.x+Corbel.BAY_L-1.0,g.y,g.z),"face":Vector3(1.0,0.0,0.0),"run_up":12.0,"lip":1.0},
	]

func spots() -> Array:
	var live_i := int(LAYOUT.live)-1
	var g := gate_at()
	var pc: Array = LAYOUT.arrival.perch
	var out: Array = [
		{"kind":"arena","name":"arrival_terrace","at":Vector3(-8.0,0.0,1.0),"room":7.0},
		{"kind":"arena","name":"gate_yard","at":Vector3(g.x-14.0,far_ground(g.x-14.0,g.z),g.z),"room":7.0},
		{"kind":"cover","name":"the_road","at":_stub_top(4),"room":2.0},
		{"kind":"perch","name":"broken_pier","at":Vector3(float(pc[0]),float(pc[4]),float(pc[1])),"room":1.2},
		{"kind":"rune_risk","name":"sixth_back","at":on_body(live_i,4.5,1.3),"room":1.0},
	]
	for j in int(LAYOUT.bodies):
		out.append({"kind":"rune_line","name":"back_%d" % (j+1),"at":on_body(j,3.0,1.4),"room":1.0})
	return out

## Road slab i's top's middle.
func _stub_top(i: int) -> Vector3:
	var rd := road()
	var r: Dictionary = rd[mini(i,rd.size()-1)]
	return ((r.a as Vector3)+(r.b as Vector3))*0.5

## Solids for the occupancy and the bodies' cliffs.
func parts() -> Array:
	var out: Array = []
	var box := func(r: Rect2, lo: float, hi: float) -> void: out.append(["box",r,lo,hi,"grey"])
	box.call(Rect2(-73.0,-33.0,73.5,61.0),-float(LAYOUT.arrival.depth),0.0)
	box.call(Rect2(-73.0,-33.0,61.0,61.0),0.0,4.0)
	box.call(Rect2(-73.0,-33.0,37.0,61.0),4.0,9.0)
	var f := far_at()
	box.call(Rect2(f.x-3.5,f.z-30.0,51.0,58.0),f.y-float(LAYOUT.far.depth),f.y)
	box.call(Rect2(f.x+13.0,f.z-30.0,35.0,58.0),f.y,f.y+2.0*SO)
	for s: float in [-1.0,1.0]:
		box.call(Rect2(f.x+22.0,f.z+(9.0 if s > 0.0 else -28.0),25.0,19.0),f.y+2.0*SO,f.y+2.0*SO+10.0)
	var k := body_k()
	for j in int(LAYOUT.bodies):
		var r := Rect2()
		var lo := INF
		var hi := -INF
		var n := 0
		for u: float in [0.0,NECK_U]:
			for v: float in [-1.5,1.3]:
				for w: float in [-2.4*k,2.4*k]:
					var p := on_body(j,u,v,w)
					r = Rect2(p.x,p.z,0.0,0.0) if n == 0 else r.expand(Vector2(p.x,p.z))
					lo = minf(lo,p.y)
					hi = maxf(hi,p.y)
					n += 1
		box.call(r,lo,hi)
	for r: Dictionary in road():
		var a: Vector3 = r.a
		var b: Vector3 = r.b
		var h := float(r.half)
		box.call(Rect2(minf(a.x,b.x),minf(a.z,b.z)-h,absf(b.x-a.x),absf(b.z-a.z)+h*2.0),minf(a.y,b.y)-1.0,maxf(a.y,b.y))
	for st: Dictionary in stumps():
		var t: Vector3 = st.top
		var hh: Vector2 = st.half
		box.call(Rect2(t.x-hh.x,t.z-hh.y,hh.x*2.0,hh.y*2.0),t.y-20.0,t.y)
	return out

# --- The land and the stone ----------------------------------------------------------------

func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(top(),KitLand.wear_of(paths()))
	site.ray = Vector2(top()+30.0,far_y()-10.0)
	return site

func flora_seed() -> int:
	return SEED+9

## The worn ways: the rim in down the slope to the line's foot (and to the
## road's way down); F's lip up through the gate yard to the gate.
static func paths() -> Array:
	var f := far_at()
	var g := gate_at()
	return [[Vector2(-70.0,0.0),Vector2(-52.0,-2.0),Vector2(-34.0,1.0),Vector2(-16.0,0.5),Vector2(-2.0,0.0)],
		[Vector2(-16.0,0.5),Vector2(-5.0,4.0)],
		[Vector2(f.x+1.0,f.z),Vector2(f.x+12.0,f.z-1.0),Vector2(g.x-8.0,g.z),Vector2(g.x+6.0,g.z)],
		[Vector2(f.x-1.0,f.z+6.0),Vector2(f.x+8.0,f.z+3.0)]]

func life_script() -> Script:
	return null if Underground.on() else KitLife

func warm() -> void:
	warm_look()
	CityStone.warm()
	for kk: String in CityStone.WEAR: CityStone.wear(kk)
	GiantStone.warm()
	HeadLook.stone_material()
	cut_material()
	origins()
	road()
	stumps()
	for pose: String in LAYOUT.poses: lying_mesh(pose)
	lying_mesh("mantle")
	if polish(): lying_mesh("growth")
	_computed()

## Measured headless on the Mac (the build alone, the lying meshes warm).
func build_cost() -> int:
	return 400

var pieces := {}

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "Procession"
	into.add_child(root)
	pieces.clear()
	# A: the arrival headland.
	var ad: Dictionary = LAYOUT.arrival
	var pol := polish()
	var a_outline: Array = ad.outline
	if pol: a_outline = ragged(a_outline,SEED+4,func(q: Vector2) -> bool: return q.x < -9.0)
	var a_spec := {"outline":a_outline,"seed":int(ad.seed),"ground":func(x: float, z: float) -> float: return arrival_ground(x,z),
		"top":0.0,"depth":float(ad.depth),"cliffs":Rect2(-78.0,-38.0,82.0,70.0),"hang":true,"resample":[60.0,220,48],"cell":2.0,
		"tone":KitLook.turf(int(ad.seed),KitLand.wear_of(paths()))}
	# F: the far isle.
	var fd: Dictionary = LAYOUT.far
	var f := far_at()
	var f_spec := {"outline":far_outline(),"seed":int(fd.seed),"ground":func(x: float, z: float) -> float: return far_ground(x,z),
		"top":f.y,"depth":float(fd.depth),"cliffs":Rect2(f.x-8.0,f.z-34.0,60.0,66.0),"hang":true,"resample":[60.0,220,48],"cell":2.0,
		"tone":KitLook.turf(int(fd.seed),KitLand.wear_of(paths()))}
	if pol:
		# The broken-hillside kit options (the Lamplighters'): turf-rounded
		# lips, finer cliff faces, the cut's steps kept small.
		a_spec.cliffs = Rect2(-81.0,-41.0,88.0,76.0)
		f_spec.cliffs = Rect2(f.x-11.0,f.z-37.0,66.0,72.0)
		for sp: Dictionary in [a_spec,f_spec]:
			sp["stable"] = true
			sp["cliff_drop"] = 0.55
			sp["fine"] = 1.2
	for sp: Dictionary in [a_spec,f_spec]: sp["collide_sides"] = true
	var a_land := KitLand.island(a_spec)
	a_land.name = "Arrival"
	var f_land := KitLand.island(f_spec)
	f_land.name = "FarIsle"
	for land: Node3D in [a_land,f_land]:
		root.add_child(land)
		turf(land)
	pieces.arrival = a_land
	pieces.far = f_land
	_roots.clear()
	_bodies(root)
	_stone(root)
	_stones(root)
	if pol: _hang_roots(root,a_outline,far_outline())
	root.set_meta("triangles",_triangles())
	built_ms = Time.get_ticks_msec()-began

## The causeway's stone: the abutment at A's tip, the piers under the
## joints (broken off in the haze), the deck's stubs off their south faces,
## the perch's broken pier and its step. One piece in the city's basalt.
func _stone(root: Node3D) -> void:
	var b := CityKit.Piece.new("CausewayRuin",SEED+20,0.7)
	# The abutment: its top flush with the terrace, stepped out under it in
	# courses, a glyph band on its face.
	var ab: Array = LAYOUT.arrival.abutment
	var x0 := float(ab[0])
	var x1 := float(ab[1])
	var z0 := float(ab[2])
	var z1 := float(ab[3])
	var down := float(ab[4])
	for c in 4:
		var top := -c*SO*1.6
		var out := 0.5*c
		var h := Vector3((x1-x0)*0.5+out*0.5,SO*0.8,(z1-z0)*0.5+out*0.3)
		b.block(CityStone.box(Transform3D(Basis.IDENTITY,Vector3((x0+x1)*0.5+out*0.5,top-h.y,(z0+z1)*0.5)),h,0.08),c == 0,null,1.0)
	b.block(CityStone.box(Transform3D(Basis.IDENTITY,Vector3((x0+x1)*0.5+1.0,-down*0.5-4.0,(z0+z1)*0.5)),Vector3((x1-x0)*0.5+1.0,down*0.5,(z1-z0)*0.5+0.6),0.1),false,null,0.6)
	b.runes(Vector3(x1+0.02,-0.8,z0+0.6),Vector3(x1+0.02,-0.8,z1-0.6),Vector3.UP,Vector3.RIGHT,1.0)
	# The stumps: battered shafts leaning, broken off at a slant at their
	# tops and their feet (the haze hides the feet), no caps; a crushed one
	# under each gap body's chest with a wedge of rubble jammed on it.
	for st: Dictionary in stumps():
		var top: Vector3 = st.top
		var hh: Vector2 = st.half
		var lb: Basis = st.lean
		var deep := float(st.deep)
		var xf := Transform3D(lb,top-lb.y*deep*0.5)
		var planes := CityStone.box(xf,Vector3(hh.x,deep*0.5,hh.y),0.18)
		var cut := (lb*Vector3(b.rng.randf_range(-0.35,0.35),1.0,b.rng.randf_range(-0.35,0.35))).normalized()
		planes.append(Plane(cut,cut.dot(top)))
		if polish():
			# Broken: three corners of the crown sheared off at steep slants,
			# one deep (a split), so no square post is left.
			var pr := RandomNumberGenerator.new()
			pr.seed = SEED+80+int(top.x*5.0+top.z*3.0)
			for ci in 3:
				var ca := pr.randf()*TAU
				var cn := (lb*Vector3(cos(ca)*pr.randf_range(0.6,1.1),pr.randf_range(0.45,0.9),sin(ca)*pr.randf_range(0.6,1.1))).normalized()
				var cd := pr.randf_range(0.5,1.6) if ci < 2 else pr.randf_range(1.8,3.2)
				planes.append(Plane(cn,cn.dot(top+lb*Vector3(cos(ca)*hh.x*0.5,-cd,sin(ca)*hh.y*0.5))))
		var foot := (lb*Vector3(b.rng.randf_range(-0.7,0.7),-1.0,b.rng.randf_range(-0.7,0.7))).normalized()
		planes.append(Plane(foot,foot.dot(top-lb.y*deep*0.8)))
		b.block(planes,true,null,4.0 if polish() else 2.4)
		if polish(): _break_crown(b,st)
		# A course line or two up its face, a glyph band on the free ones.
		if st.kind == "free": b.runes(top+lb*Vector3(-hh.x*0.8,-1.6,hh.y+0.02),top+lb*Vector3(hh.x*0.8,-1.6,hh.y+0.02),lb.y,lb.z,0.9)
		if st.kind == "crushed":
			for r in 4:
				var sz := Vector3(b.rng.randf_range(1.2,2.4),b.rng.randf_range(0.7,1.3),b.rng.randf_range(1.0,2.0))
				var at := top+Vector3(b.rng.randf_range(-1.4,1.4),sz.y*0.4+0.2*r,b.rng.randf_range(-1.4,1.4))
				var rb := Basis.from_euler(Vector3(b.rng.randf_range(-0.5,0.5),b.rng.randf_range(-1.5,1.5),b.rng.randf_range(-0.5,0.5)))
				b.block(CityStone.box(Transform3D(rb,at),sz*0.5,0.1),false,null,2.0)
	# The old road: its deck in slabs slumped between the stumps, ends
	# snapped off at a slant, a hand-high curb left on some outer edges.
	for r: Dictionary in road():
		var ra: Vector3 = r.a
		var rb: Vector3 = r.b
		var half := float(r.half)
		var along := rb-ra
		var dir := along.normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var up := side.cross(dir).normalized()
		var basis := Basis(side,up,dir)
		var bxf := Transform3D(basis,(ra+rb)*0.5-up*0.55)
		var bh := Vector3(half,0.55,along.length()*0.5)
		var bplanes := CityStone.box(bxf,bh,0.08)
		for e: float in [-1.0,1.0]:
			var nl := (basis*Vector3(b.rng.randf_range(-0.5,0.5),b.rng.randf_range(-0.3,0.3),e)).normalized()
			bplanes.append(Plane(nl,nl.dot(bxf.origin+dir*e*bh.z*0.97)))
		b.block(bplanes,true,null,2.0)
		b.runes(ra-up*0.6-side*half,rb-up*0.6-side*half,up,-side,0.6)
		if b.rng.randf() < 0.55:
			var cl := along.length()*b.rng.randf_range(0.3,0.6)
			var c0 := b.rng.randf_range(0.1,0.9-cl/along.length())
			b.block(CityStone.box(Transform3D(basis,ra+along*(c0+cl/along.length()*0.5)+up*0.15+side*(half-0.2)),Vector3(0.2,0.15,cl*0.5),0.03),false,null,0.6)
	# The perch: a broken pier on the terrace, a fallen block its step.
	var pc: Array = LAYOUT.arrival.perch
	var tall_p := float(pc[4])
	var py := arrival_ground(float(pc[0]),float(pc[1]))
	var pp := CityStone.box(Transform3D(Basis(Vector3.UP,0.2),Vector3(float(pc[0]),py+tall_p*0.5-0.4,float(pc[1]))),Vector3(float(pc[2]),tall_p*0.5+0.4,float(pc[3])),0.12)
	if polish():
		# Broken at the crown, leaning a little, rubble banked at its foot.
		var pr := RandomNumberGenerator.new()
		pr.seed = SEED+90
		for ci in 3:
			var ca := pr.randf()*TAU
			var cn := Vector3(cos(ca)*pr.randf_range(0.7,1.1),pr.randf_range(0.35,0.7),sin(ca)*pr.randf_range(0.7,1.1)).normalized()
			pp.append(Plane(cn,cn.dot(Vector3(float(pc[0])+cos(ca)*float(pc[2])*0.5,py+tall_p-pr.randf_range(0.5,(1.0 if ci < 2 else 2.2)),float(pc[1])+sin(ca)*float(pc[3])*0.5))))
		for ri in 5:
			var ra := pr.randf()*TAU
			var rs := Vector3(pr.randf_range(0.5,1.1),pr.randf_range(0.35,0.7),pr.randf_range(0.5,1.0))
			var rp := Vector3(float(pc[0])+cos(ra)*pr.randf_range(1.6,2.6),0.0,float(pc[1])+sin(ra)*pr.randf_range(1.6,2.6))
			rp.y = arrival_ground(rp.x,rp.z)+rs.y*0.2
			b.block(CityStone.box(Transform3D(Basis.from_euler(Vector3(pr.randf_range(-0.5,0.5),pr.randf_range(-1.5,1.5),pr.randf_range(-0.5,0.5))),rp),rs*0.5,0.07),false,null,1.2)
	b.block(pp,true,null,3.0 if polish() else 1.4)
	var cap_xf := Transform3D(Basis.from_euler(Vector3(0.06,0.5,-0.08)),Vector3(float(pc[0])+0.3,py+tall_p+0.25,float(pc[1])-0.2))
	if not polish(): b.block(CityStone.box(cap_xf,Vector3(float(pc[2])*0.9,0.25,float(pc[3])*0.8),0.05),false,null,1.0)
	else: b.block(CityStone.box(Transform3D(Basis.from_euler(Vector3(0.3,0.9,0.25)),Vector3(float(pc[0])+1.9,py+0.3,float(pc[1])+1.4)),Vector3(float(pc[2])*0.9,0.25,float(pc[3])*0.8),0.05),false,null,1.0)
	var ps: Array = LAYOUT.arrival.perch_step
	var size: Vector3 = ps[2]
	b.block(CityStone.box(Transform3D(Basis(Vector3.UP,deg_to_rad(float(ps[3]))),Vector3(float(ps[0]),py+size.y*0.5-0.1,float(ps[1]))),size*0.5,0.12),true,null,1.4)
	_dress(b)
	var piece := b.finish()
	root.add_child(piece)
	pieces.causeway = piece

## A stump's crown broken and grown: chunks fallen on it and down its
## flank, and roots hung from its top edge into the haze.
func _break_crown(b: CityKit.Piece, st: Dictionary) -> void:
	var top: Vector3 = st.top
	var hh: Vector2 = st.half
	var lb: Basis = st.lean
	var pr := RandomNumberGenerator.new()
	pr.seed = SEED+61+int(top.x*7.0+top.z*3.0)
	for i in pr.randi_range(2,4):
		var sz := Vector3(pr.randf_range(0.4,1.0),pr.randf_range(0.3,0.7),pr.randf_range(0.4,0.9))
		var at := top+lb*Vector3(pr.randf_range(-hh.x,hh.x)*0.8,pr.randf_range(-0.35,0.15),pr.randf_range(-hh.y,hh.y)*0.8)
		var rb := Basis.from_euler(Vector3(pr.randf_range(-0.7,0.7),pr.randf_range(-1.5,1.5),pr.randf_range(-0.7,0.7)))
		b.block(CityStone.box(Transform3D(rb,at),sz*0.5,0.08),false,null,1.2)
	for i in pr.randi_range(3,6):
		var a := pr.randf()*TAU
		var out := Vector3(cos(a),0.0,sin(a))
		var edge := (top+lb*Vector3(cos(a)*hh.x*0.98,-0.25-pr.randf()*0.5,sin(a)*hh.y*0.98))+out*0.12
		_roots.append([edge,pr.randf_range(3.0,9.0),pr.randf_range(0.4,0.7),atan2(out.x,out.z)])

## Where the procession set out, and where it was going: rune-cut steps
## sunk in A's slope, a broken balustrade on its north lip, two stelae at
## the tip; F's stairs cut into its rock steps, its kerb at the lip, the
## gate's stelae.
func _dress(b: CityKit.Piece) -> void:
	var pol := polish()
	var ad: Dictionary = LAYOUT.arrival
	var tr: Array = ad.treads
	var x := float(tr[0])
	var w := float(tr[2])
	while x < float(tr[1]):
		var d := float(tr[3])
		if b.rng.randf() < (0.72 if pol else 0.85):
			var gy := minf(arrival_ground(x,0.0),arrival_ground(x+d,0.0))
			var tb := Basis(Vector3.UP,b.rng.randf_range(-0.04,0.04))
			# Seated: sunk below the turf, a little askew, no loose slate.
			if pol: tb = Basis.from_euler(Vector3(b.rng.randf_range(-0.05,0.05),b.rng.randf_range(-0.09,0.09),b.rng.randf_range(-0.05,0.05)))
			if pol: gy -= b.rng.randf_range(0.05,0.2)
			var ww := w-b.rng.randf_range(0.0,1.6)
			for half in 2:
				var hz := ww*0.5*b.rng.randf_range(0.85,1.0)
				var cz := (hz+0.04)*(1.0 if half == 0 else -1.0)+b.rng.randf_range(-0.2,0.2)
				b.block(CityStone.box(Transform3D(tb,Vector3(x+d*0.5,gy+0.06-0.6,cz)),Vector3(d*0.5-0.08,0.6,hz),0.12),true,null,2.0)
			if not pol: b.runes(Vector3(x+0.02,gy+0.05,-ww+0.4),Vector3(x+0.02,gy+0.05,ww-0.4),Vector3.UP,Vector3.LEFT,0.25)
		x += d
	# The balustrade: posts a stride apart, a rail on them, broken.
	var bl: Array = ad.balustrade
	var p0: Vector2 = bl[0]
	var p1: Vector2 = bl[1]
	var n := int(p0.distance_to(p1)/1.5)
	var yaw := atan2(-(p1.y-p0.y),p1.x-p0.x)
	for i in n+1:
		var q := p0.lerp(p1,float(i)/n)
		var gy := arrival_ground(q.x,q.y)
		if b.rng.randf() < 0.25:
			# Fallen: lying in the turf.
			b.block(CityStone.box(Transform3D(Basis(Vector3.UP,b.rng.randf_range(0.0,3.0))*Basis(Vector3.RIGHT,PI*0.5),Vector3(q.x+0.5,gy+0.15,q.y+0.8)),Vector3(0.3,0.55,0.3),0.06),false,null,1.0)
			continue
		var tall := 1.1 if b.rng.randf() < 0.8 else b.rng.randf_range(0.4,0.8)
		b.block(CityStone.box(Transform3D(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.08,0.08)),Vector3(q.x,gy+tall*0.5-0.1,q.y)),Vector3(0.28,tall*0.5,0.28),0.05),true,null,1.0)
		if i < n and tall > 1.0 and b.rng.randf() < 0.6:
			var q2 := p0.lerp(p1,float(i+1)/n)
			var mid := (q+q2)*0.5
			b.block(CityStone.box(Transform3D(Basis(Vector3.UP,yaw),Vector3(mid.x,gy+1.1,mid.y)),Vector3(q.distance_to(q2)*0.5,0.14,0.22),0.03),false,null,1.0)
	for sd: Array in ad.stelae: _stela(b,Vector3(float(sd[0]),arrival_ground(float(sd[0]),float(sd[1])),float(sd[1])),float(sd[2]),float(sd[3]),5.2)
	# F: a stair cut into each rock step, a kerb at the lip, the gate's stelae.
	var fd: Dictionary = LAYOUT.far
	var f := far_at()
	var sz: Array = fd.stair
	var lvl := 0
	for e: float in fd.steps:
		for i in 4:
			var tx := f.x+e-1.8+0.6*i
			var top := f.y+SO*lvl+0.4*(i+1)
			b.block(CityStone.box(Transform3D(Basis.IDENTITY,Vector3(tx+1.4,top-1.0,f.z+(float(sz[0])+float(sz[1]))*0.5)),Vector3(1.7-0.3*i,1.0,(float(sz[1])-float(sz[0]))*0.5),0.06),true,null,1.0)
		lvl += 1
	for zz: float in [-4.5,-1.5,1.5,4.5]:
		var gy := far_ground(f.x+0.6,f.z+zz)
		b.block(CityStone.box(Transform3D(Basis(Vector3.UP,b.rng.randf_range(-0.1,0.1)),Vector3(f.x+0.6,gy-0.45,f.z+zz)),Vector3(0.8,0.5,1.4),0.08),true,null,1.2)
	for sd: Array in fd.stelae:
		var sx := f.x+float(sd[0])
		var sz2 := f.z+float(sd[1])
		_stela(b,Vector3(sx,far_ground(sx,sz2),sz2),float(sd[2]),float(sd[3]),6.0)

## A stela: a tall slab sunk at its foot, leaning, glyphs down its face.
func _stela(b: CityKit.Piece, foot: Vector3, yaw: float, lean: float, tall: float) -> void:
	var sb := Basis(Vector3.UP,deg_to_rad(yaw))*Basis(Vector3.BACK,deg_to_rad(lean))
	var xf := Transform3D(sb,foot+sb.y*(tall*0.5-0.6))
	var sp := CityStone.box(xf,Vector3(1.2,tall*0.5,0.6),0.15)
	if polish():
		# Snapped at the crown on a slant.
		var sn := (sb*Vector3(0.55 if int(foot.x) % 2 == 0 else -0.55,1.0,0.25)).normalized()
		sp.append(Plane(sn,sn.dot(xf*Vector3(0.0,tall*0.5-0.9,0.0))))
	b.block(sp,true,null,3.0 if polish() else 2.2)
	for k in 3:
		var y := tall*0.5-1.0-k*1.3
		b.runes(xf*Vector3(-0.7,y,0.47),xf*Vector3(0.7,y,0.47),sb.y,sb.z,0.8)


var _roots: Array = []

## Roots hung from both shores' lips down into the abyss (and, collected in
## `_roots`, from the stumps' tops): one batch of the sky forest's root
## strand. Those off F's lip that faces the line reach longest.
func _hang_roots(root: Node3D, a_outline: Array, f_outline: Array) -> void:
	var f := far_at()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+70
	var count: Array = POLISH.roots
	var sets := [[a_outline,int(count[0]),false],[f_outline,int(count[1]),true]]
	for sd: Array in sets:
		var poly: Array = sd[0]
		var per := 0.0
		for i in poly.size(): per += (poly[i] as Vector2).distance_to(poly[(i+1)%poly.size()])
		var step := per/maxf(float(sd[1]),1.0)
		var carry := rng.randf()*step
		for i in poly.size():
			var a: Vector2 = poly[i]
			var bq: Vector2 = poly[(i+1)%poly.size()]
			var seg := a.distance_to(bq)
			var along := carry
			while along < seg:
				var q := a.lerp(bq,along/seg)
				along += step*rng.randf_range(0.6,1.4)
				var out := Vector2(bq.y-a.y,-(bq.x-a.x)).normalized()
				var centre := Vector2(f.x+22.0,f.z) if sd[2] else Vector2(-30.0,0.0)
				if out.dot(q-centre) < 0.0: out = -out
				# Not over the tip or the lip the line leaves.
				if (not sd[2] and q.x > -7.0) or (sd[2] and q.x < f.x+1.0 and absf(q.y-f.z) < 16.0): continue
				var y := far_ground(q.x,q.y) if sd[2] else arrival_ground(q.x,q.y)
				var near: bool = sd[2] and q.x < f.x+8.0
				var length := rng.randf_range(8.0,16.0) if near else rng.randf_range(3.0,11.0)
				_roots.append([Vector3(q.x+out.x*0.3,y-0.45,q.y+out.y*0.3),length,rng.randf_range(0.45,0.8),atan2(out.x,out.y)+rng.randf_range(-0.4,0.4)])
			carry = along-seg
	if _roots.is_empty(): return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = preload("res://scripts/sky_forest_isles.gd")._make_root()
	mm.instance_count = _roots.size()
	for i in _roots.size():
		var r: Array = _roots[i]
		var basis := Basis(Vector3.UP,float(r[3])).scaled(Vector3(float(r[2]),float(r[1]),float(r[2])))
		mm.set_instance_transform(i,Transform3D(basis,r[0] as Vector3))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Roots"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.set_meta("triangles",_roots.size()*70)
	pieces.roots = mi

## Fallen stone half sunk in both shores (the Lamplighters' `stones`).
func _stones(root: Node3D) -> void:
	var g: RefCounted = GiantStone.mesher()
	var body := StaticBody3D.new()
	body.name = "SunkStoneSolid"
	var f := far_at()
	for st: Array in (LAYOUT.stones+POLISH.stones if polish() else LAYOUT.stones):
		var on_far: bool = st[0] == "f"
		var x := float(st[2])+(f.x if on_far else 0.0)
		var z := float(st[3])+(f.z if on_far else 0.0)
		var y := far_ground(x,z) if on_far else arrival_ground(x,z)
		var c := CollisionShape3D.new()
		if st[1] == "block":
			var size: Vector3 = st[4]
			var tilt_k := 1.0
			var sunk := float(st[8])
			var bev := clampf(minf(size.x,minf(size.y,size.z))*0.12,0.06,0.3)
			if polish():
				# Sunk deeper, tipped further and chipped: seated in the turf.
				tilt_k = 1.7
				sunk = minf(sunk*1.8,size.y*0.6)
				bev = clampf(minf(size.x,minf(size.y,size.z))*0.22,0.12,0.5)
			var bb := Basis.from_euler(Vector3(deg_to_rad(float(st[6])*tilt_k),deg_to_rad(float(st[5])),deg_to_rad(float(st[7])*tilt_k)),EULER_ORDER_YXZ)
			var xf := Transform3D(bb,Vector3(x,y+size.y*0.5-sunk,z))
			g.box(xf,size,bev,y-0.4,0.9+0.2*fmod(absf(x*0.37+z*0.11),1.0))
			var shape := BoxShape3D.new()
			shape.size = size
			c.shape = shape
			c.transform = xf
		else:
			var r := float(st[4])
			var length := float(st[5])
			var bb := Basis(Vector3.UP,deg_to_rad(float(st[6])))*Basis(Vector3.BACK,PI*0.5)
			var xf := Transform3D(bb,Vector3(x,y+r-float(st[7]),z))
			g.cylinder(xf,r,length,14,0.14,y-0.4,0.95)
			var shape := CylinderShape3D.new()
			shape.radius = r
			shape.height = length
			c.shape = shape
			c.transform = xf
		body.add_child(c)
	if polish():
		# The gate's roof: its lintel fallen askew along it and blocks slid
		# off its shoulders, all half-banked in turf.
		var gt := gate_at()
		var roof := gt.y+Corbel.roof()
		for gs: Array in [[Vector3(1.0,-0.3,5.0),Vector3(9.0,1.6,2.8),12.0,5.0,-9.0],[Vector3(-4.0,-0.4,-5.2),Vector3(3.2,1.8,2.4),-35.0,-8.0,14.0],[Vector3(7.0,-0.5,-5.0),Vector3(2.6,1.4,2.2),55.0,10.0,-6.0],[Vector3(5.5,-0.6,6.0),Vector3(2.2,1.2,1.8),20.0,-12.0,9.0]]:
			var at: Vector3 = gs[0]
			var sz: Vector3 = gs[1]
			var gbb := Basis.from_euler(Vector3(deg_to_rad(float(gs[3])),deg_to_rad(float(gs[2])),deg_to_rad(float(gs[4]))),EULER_ORDER_YXZ)
			var gxf := Transform3D(gbb,Vector3(gt.x+at.x,roof+at.y,gt.z+at.z))
			g.box(gxf,sz,0.3,roof-0.6,0.95)
			_roots.append([gxf.origin+Vector3(sz.x*0.4,-sz.y*0.4,sz.z*0.5),3.0,0.5,0.0])
	var mesh := MeshInstance3D.new()
	mesh.name = "SunkStone"
	mesh.mesh = GiantStone.mesh_of(g)
	mesh.set_meta("triangles",g.triangles())
	root.add_child(mesh)
	root.add_child(body)
	pieces.sunk_stone = mesh

# --- The bodies ----------------------------------------------------------------------------

## STAND-IN: maker_toppled. The real headless body's mesh (assets/models/
## headless_body.glb), its arms posed (`poses`) and skinned by hand once,
## turned to lie face-down (its length +x, its back +y, across +z), then
## dressed as the body is (HeadLook `_dressed`: the kit's stone by facing,
## its baked occlusion, moss on what faces up: now its back), its LODs made
## again. One static mesh a pose, shared by every body: no skeleton.
static var _lying := {}
static var _lying_lock := Mutex.new()
static var _cut_mat: StandardMaterial3D = null

static func lying_mesh(pose: String) -> ArrayMesh:
	_lying_lock.lock()
	if not _lying.has(pose): _lying[pose] = _make_mantle() if pose == "mantle" else (_make_growth() if pose == "growth" else _make_lying(pose))
	var m: ArrayMesh = _lying[pose]
	_lying_lock.unlock()
	return m

## The stump's raw cut (the body's own colour, no glow: they are asleep).
static func cut_material() -> StandardMaterial3D:
	if _cut_mat == null:
		_cut_mat = StandardMaterial3D.new()
		_cut_mat.albedo_color = Look.CUT
		_cut_mat.roughness = 1.0
		_cut_mat.vertex_color_use_as_albedo = true
	return _cut_mat

static func _make_lying(pose: String) -> ArrayMesh:
	var model: Node3D = (load(Look.MODEL) as PackedScene).instantiate()
	var sk: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
	var mi: MeshInstance3D = sk.find_children("*","MeshInstance3D",true,false)[0]
	var pa: Array = LAYOUT.poses[pose]
	var glob: Array = []
	for i in sk.get_bone_count(): glob.append(sk.get_bone_global_rest(i))
	for side: String in ["L","R"]:
		var arm := sk.find_bone("upper_arm."+side)
		var s := -1.0 if side == "L" else 1.0
		var r := Basis(Vector3.RIGHT,deg_to_rad(float(pa[0])))*Basis(Vector3.FORWARD,deg_to_rad(float(pa[1])*s))
		var piv: Vector3 = (glob[arm] as Transform3D).origin
		var rot := Transform3D(r,piv-r*piv)
		for i in sk.get_bone_count():
			var j := i
			while j >= 0 and j != arm: j = sk.get_bone_parent(j)
			if j == arm: glob[i] = rot*(glob[i] as Transform3D)
	var binds: Array = []
	for i in mi.skin.get_bind_count():
		var bn := mi.skin.get_bind_bone(i)
		if bn < 0: bn = sk.find_bone(mi.skin.get_bind_name(i))
		binds.append((glob[bn] as Transform3D)*mi.skin.get_bind_pose(i))
	# Lying: model y (its length) to +x, model z (its back) to +y, model x
	# (across) to +z.
	var lie := Basis(Vector3(0.0,0.0,1.0),Vector3(1.0,0.0,0.0),Vector3(0.0,1.0,0.0))
	var out := ArrayMesh.new()
	for sidx in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(sidx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per := bones.size()/maxi(verts.size(),1)
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		nv.resize(verts.size())
		nn.resize(verts.size())
		for v in verts.size():
			var p := Vector3.ZERO
			var n := Vector3.ZERO
			for kk in per:
				var w := weights[v*per+kk]
				if w <= 0.0: continue
				var xf: Transform3D = binds[bones[v*per+kk]]
				p += (xf*verts[v])*w
				n += (xf.basis*normals[v])*w
			nv[v] = lie*p
			nn[v] = (lie*n).normalized()
		arrays[Mesh.ARRAY_VERTEX] = nv
		arrays[Mesh.ARRAY_NORMAL] = nn
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	model.free()
	var stone := Style.stone_of(7) if Style.ruled() else Color("5a5d63")
	return HeadLook._dressed(out,stone,Vector3.ZERO)

## STAND-IN polish: the back as one mass. The model's back is laid in
## blocks, which from the rim read as cobbles; over its torso a carved
## mantle (lying frame, model m): a rounded whaleback from the hips to the
## shoulders, a spine groove down it, the shoulder blades standing up, its
## underside sunk in the body. Dressed as the body is (`_dressed`).
## MANTLE: [u, half width, top] along it; the groove (deep, half width);
## the blades (u, across, high, radius).
const MANTLE := [[1.5,1.7,0.9],[2.2,1.95,1.22],[3.2,2.05,1.3],[4.4,2.2,1.38],[5.4,2.35,1.5],[6.2,2.2,1.42],[6.75,1.5,1.05]]
const GROOVE := Vector2(0.16,0.32)
const BLADES := [5.2,1.05,0.16,0.75]

static func _make_mantle() -> ArrayMesh:
	var nu := 28
	var nw := 26
	var base := 0.15
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u0 := float(MANTLE[0][0])
	var u1 := float(MANTLE[MANTLE.size()-1][0])
	var at := func(u: float) -> Vector2:
		for i in range(MANTLE.size()-1):
			var a: Array = MANTLE[i]
			var b: Array = MANTLE[i+1]
			if u <= float(b[0]):
				var t := smoothstep(0.0,1.0,(u-float(a[0]))/(float(b[0])-float(a[0])))
				return Vector2(lerpf(float(a[1]),float(b[1]),t),lerpf(float(a[2]),float(b[2]),t))
		return Vector2(float(MANTLE[MANTLE.size()-1][1]),float(MANTLE[MANTLE.size()-1][2]))
	var grid: Array = []
	for i in nu+1:
		var u := lerpf(u0,u1,float(i)/nu)
		var wh: Vector2 = at.call(u)
		var row: Array = []
		for j in nw+1:
			# Round the section: w over [-1, 1], the sides falling to the base.
			var t := -1.0+2.0*float(j)/nw
			var w := t*wh.x
			var r := pow(maxf(1.0-pow(absf(t),2.6),0.0),1.0/2.6)
			var v := base+(wh.y-base)*r
			v -= GROOVE.x*exp(-pow(w/GROOVE.y,2.0))*r
			for side: float in [-1.0,1.0]:
				var d := Vector2(u-float(BLADES[0]),w-side*float(BLADES[1])).length()/float(BLADES[3])
				if d < 1.0: v += float(BLADES[2])*pow(1.0-d*d,2.0)*r
			row.append(Vector3(u,v,w))
		grid.append(row)
	for i in nu:
		for j in nw:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i+1][j]
			var c: Vector3 = grid[i+1][j+1]
			var d: Vector3 = grid[i][j+1]
			for q: Vector3 in [a,b,c,a,c,d]: st.add_vertex(q)
	st.generate_normals()
	var mesh := st.commit()
	var stone := Style.stone_of(7) if Style.ruled() else Color("5a5d63")
	return HeadLook._dressed(mesh,stone,Vector3.ZERO)

## Polish: what grew on the backs, as one mesh in the lying frame (model m),
## laid over the mantle: moss cushions in the spine groove and the hollows
## between and beside the shoulder blades, pale lichen on the blades and in
## specks down the back. [u, across, radius, height, "moss" | "lichen"].
const GROWTH := [
	[4.7,0.0,0.55,0.2,"moss"],[5.65,0.05,0.45,0.18,"moss"],[4.0,0.5,0.4,0.14,"moss"],[4.15,-0.55,0.42,0.15,"moss"],
	[5.2,1.8,0.5,0.15,"moss"],[5.2,-1.75,0.5,0.14,"moss"],[1.9,1.0,0.5,0.14,"moss"],[2.3,-1.1,0.42,0.12,"moss"],
	[6.3,0.0,0.4,0.12,"moss"],[3.1,0.3,0.36,0.1,"moss"],[0.9,0.4,0.4,0.1,"moss"],
	[5.2,1.05,1.0,0.09,"lichen"],[5.2,-1.05,1.0,0.09,"lichen"],[5.45,1.2,0.38,0.06,"lichen"],[4.9,-1.3,0.34,0.06,"lichen"],
	[3.6,1.4,0.36,0.05,"lichen"],[2.6,-1.3,0.32,0.05,"lichen"],[6.35,-0.75,0.3,0.05,"lichen"],[1.6,1.35,0.3,0.05,"lichen"],
]

const FERNS := [[6.2,1.5],[6.2,-1.5],[6.65,0.6],[0.3,1.1],[0.3,-1.1],[1.1,1.6],[1.1,-1.6]]

## The mantle's top (model m) at u, across w.
static func _mantle_at(u: float, w: float) -> float:
	var wh := Vector2(float(MANTLE[MANTLE.size()-1][1]),float(MANTLE[MANTLE.size()-1][2]))
	for i in range(MANTLE.size()-1):
		var a: Array = MANTLE[i]
		var b: Array = MANTLE[i+1]
		if u <= float(b[0]):
			var t := smoothstep(0.0,1.0,(maxf(u,float(a[0]))-float(a[0]))/(float(b[0])-float(a[0])))
			wh = Vector2(lerpf(float(a[1]),float(b[1]),t),lerpf(float(a[2]),float(b[2]),t))
			break
	var tt := clampf(w/wh.x,-1.0,1.0)
	var r := pow(maxf(1.0-pow(absf(tt),2.6),0.0),1.0/2.6)
	return 0.15+(wh.y-0.15)*r-GROOVE.x*exp(-pow(w/GROOVE.y,2.0))*r

static func _make_growth() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 17
	noise.frequency = 2.2
	var lon := 9
	var rings := 3
	var moss := HeadLook.MOSS.srgb_to_linear()
	var moss_light := HeadLook.MOSS_LIGHT.srgb_to_linear()
	var lichen := Color("c9cbb0").srgb_to_linear()
	var n := 0
	for g: Array in GROWTH:
		var cu := float(g[0])
		var cw := float(g[1])
		var rad := float(g[2])
		var hgt := float(g[3])
		var base := _mantle_at(cu,cw)-0.06
		var grid: Array = []
		for ri in rings+1:
			var row: Array = []
			var t := float(ri)/rings
			for li in lon:
				var a := TAU*li/lon
				var wob := 1.0+0.22*sin(a*3.0+n*1.7)
				var rr := rad*wob*cos(t*PI*0.5)
				var u := cu+cos(a)*rr
				var w := cw+sin(a)*rr
				row.append(Vector3(u,_mantle_at(u,w)-0.06+hgt*sin(t*PI*0.5)*(1.0 if t > 0.0 else 0.0)+(0.0 if t > 0.0 else 0.0),w))
			grid.append(row)
		var tone := noise.get_noise_2d(cu*3.0,cw*3.0)*0.5+0.5
		var colour := lichen.lerp(lichen*0.8,tone) if g[4] == "lichen" else moss.lerp(moss_light,tone)
		for ri in rings:
			for li in lon:
				var a: Vector3 = grid[ri][li]
				var b: Vector3 = grid[ri][(li+1)%lon]
				var c: Vector3 = grid[ri+1][(li+1)%lon]
				var d: Vector3 = grid[ri+1][li]
				for q: Vector3 in [a,c,b,a,d,c]:
					st.set_color(Color(colour.r,colour.g,colour.b,1.0))
					st.set_uv(Vector2(q.x,q.y))
					st.set_uv2(Vector2(q.z,0.0))
					st.add_vertex(q)
		n += 1
		# The cap (the last ring's middle).
		var top := Vector3(cu,_mantle_at(cu,cw)-0.06+hgt,cw)
		var last: Array = grid[rings]
		for li in lon:
			for q: Vector3 in [last[li],last[(li+1)%lon],top]:
				st.set_color(Color(colour.r,colour.g,colour.b,1.0))
				st.set_uv(Vector2(q.x,q.y))
				st.set_uv2(Vector2(q.z,0.0))
				st.add_vertex(q)
	# Ferns in the joints: clumps of arching fronds at the shoulders and the
	# heels, where one body ends and the next begins (two-sided strips).
	var fr := RandomNumberGenerator.new()
	fr.seed = 5
	var root_c := Color("3f5d26").srgb_to_linear()
	var tip_c := Color("78a043").srgb_to_linear()
	for fc: Array in FERNS:
		for fi in 8:
			var a0 := fr.randf()*TAU
			var base := Vector3(float(fc[0])+fr.randf_range(-0.2,0.2),0.0,float(fc[1])+fr.randf_range(-0.2,0.2))
			base.y = _mantle_at(base.x,base.z)-0.08
			var flen := fr.randf_range(0.55,0.95)
			var out := Vector3(cos(a0),0.0,sin(a0))
			var side := Vector3(-out.z,0.0,out.x)
			var pts: Array = []
			for k in 4:
				var t := float(k)/3.0
				pts.append(base+out*flen*t*0.85+Vector3.UP*flen*(1.3*t-0.95*t*t))
			for k in 3:
				var w0 := 0.1*(1.0-float(k)/3.0)
				var w1 := 0.1*(1.0-float(k+1)/3.0)
				var q0: Vector3 = pts[k]
				var q1: Vector3 = pts[k+1]
				var verts := [q0-side*w0,q0+side*w0,q1+side*w1,q0-side*w0,q1+side*w1,q1-side*w1]
				var cols := [float(k)/3.0,float(k)/3.0,float(k+1)/3.0,float(k)/3.0,float(k+1)/3.0,float(k+1)/3.0]
				for dir in 2:
					for vi in 6:
						var vv: Vector3 = verts[vi if dir == 0 else 5-vi]
						var cc := root_c.lerp(tip_c,float(cols[vi if dir == 0 else 5-vi]))
						st.set_color(Color(cc.r,cc.g,cc.b,1.0))
						st.set_uv(Vector2(vv.x,vv.y))
						st.set_uv2(Vector2(vv.z,0.0))
						st.add_vertex(vv)
	st.generate_normals()
	return st.commit()

## The back's clean walk shapes in a body's frame (model m; u along, v up,
## w across): each a hull over the front (FRONT) under a top polyline [u,
## v] (concave down), half `w` across. Read off the lying mesh
## (scratch/proc_pose.gd): calves 0.72-0.77 to the hips, the buttocks 1.1,
## the torso 1.13-1.26 to the shoulders, the stump 0.9 at the neck.
const LEGS := {"top":[[-0.2,0.6],[0.2,0.76],[1.9,0.8]],"w":1.85}
const TORSO := {"top":[[1.9,1.0],[3.0,1.3],[5.4,1.45],[6.4,1.4],[6.9,0.9]],"w":2.2}
const FRONT := -1.45
## An arm (braced): from the shoulder to the hand on the next back (u, v
## (its top); across, model m, this body's frame), half its section.
const ARM_FROM := Vector3(6.1,0.7,2.5)
const ARM_TO := Vector3(9.7,-0.6,1.9)
const ARM_HALF := Vector2(0.5,0.45)

## The bodies: each a mesh of its pose and a body of clean hulls.
func _bodies(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "Bodies"
	root.add_child(holder)
	var k := body_k()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED+30
	var wob: Vector2 = LAYOUT.wobble
	var made: Array = []
	var n := int(LAYOUT.bodies)
	var os := origins()
	for j in n:
		var o: Vector3 = os[j]
		var pose := pose_of(j+1)
		var turn := deg_to_rad(rng.randf_range(-wob.x,wob.x))
		var roll := deg_to_rad(rng.randf_range(-wob.y,wob.y))
		var basis := frame_of(j)*Basis(Vector3.UP,turn)*Basis(Vector3.RIGHT,roll)
		var mi := MeshInstance3D.new()
		mi.name = "Toppled%d_STANDIN" % (j+1)
		mi.mesh = lying_mesh(pose)
		mi.set_surface_override_material(0,HeadLook.stone_material())
		if mi.mesh.get_surface_count() > 1: mi.set_surface_override_material(1,cut_material())
		mi.transform = Transform3D(basis.scaled(Vector3.ONE*k),o)
		holder.add_child(mi)
		var mantle := MeshInstance3D.new()
		mantle.name = "Mantle%d_STANDIN" % (j+1)
		mantle.mesh = lying_mesh("mantle")
		mantle.material_override = HeadLook.stone_material()
		mi.add_child(mantle)
		if polish():
			var growth := MeshInstance3D.new()
			growth.name = "Growth%d_STANDIN" % (j+1)
			growth.mesh = lying_mesh("growth")
			growth.material_override = HeadLook.stone_material()
			mi.add_child(growth)
		var sb := StaticBody3D.new()
		sb.name = "Back%d" % (j+1)
		var xf := Transform3D(basis,o)
		for part: Dictionary in [LEGS,TORSO]: _hull(sb,xf,k,part.top,FRONT,float(part.w))
		if pose == "braced" and j+1 < n:
			# The arms: a rail each from the shoulder down to the hand on the
			# next back.
			for s: float in [-1.0,1.0]:
				var a := xf*(Vector3(ARM_FROM.x*k,ARM_FROM.y*k,s*ARM_FROM.z*k))
				var hand := xf*(Vector3(ARM_TO.x*k,ARM_TO.y*k,s*ARM_TO.z*k))
				_rail(sb,a,hand,ARM_HALF*k)
		holder.add_child(sb)
		made.append(mi)
	pieces.bodies = holder
	pieces.lying = made

## A clean hull: under the top polyline `top` ([u, v] model m), down to the
## front `lo`, +-`half` across, in a body's frame `xf`.
static func _hull(sb: StaticBody3D, xf: Transform3D, k: float, top: Array, lo: float, half: float) -> void:
	var pts := PackedVector3Array()
	for q: Array in top:
		for w: float in [-half,half]:
			pts.append(xf*Vector3(float(q[0])*k,float(q[1])*k,w*k))
	for u: float in [float(top[0][0]),float(top[top.size()-1][0])]:
		for w: float in [-half,half]:
			pts.append(xf*Vector3(u*k,lo*k,w*k))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = shape
	sb.add_child(cs)

## A rail (a box from `a` to `b`, `half` (across, up) its section; its top
## through the line a-b).
static func _rail(sb: StaticBody3D, a: Vector3, b: Vector3, half: Vector2) -> void:
	var along := b-a
	var dir := along.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	var shape := BoxShape3D.new()
	shape.size = Vector3(half.x*2.0,half.y*2.0,along.length())
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(Basis(side,up,dir),(a+b)*0.5-up*half.y)
	sb.add_child(cs)

## Its stone's triangles (the lying meshes at full LOD, each body).
func _triangles() -> int:
	var n := 0
	for p: Variant in pieces.values():
		if p is Node3D: n += int((p as Node3D).get_meta("triangles",0))
	for mi: MeshInstance3D in pieces.get("lying",[]): n += mi.mesh.get_faces().size()/3
	return n

# --- What moves --------------------------------------------------------------------------

## The gate and its fire, the breakables hub, the sixth's breath, the
## sleeper (STAND-IN).
func live(g: Node) -> void:
	var fires := Node3D.new()
	fires.name = "Fires"
	g.add_child(fires)
	var ga := gate_at()
	var fd: Dictionary = LAYOUT.far
	var cp: Vector2 = fd.cresset
	var f := far_at()
	var cat := Vector3(f.x+cp.x,0.0,f.z+cp.y)
	cat.y = far_ground(cat.x,cat.z)
	var lamp: Node3D = CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(cat)),{"size":"great","seed":SEED+40,"name":"GateFire","lit":true,"draw":0.0,"beam":2.5})
	SC._still(lamp)
	# Lamps lit on the way up to it: the one warm place in the haze.
	var li := 0
	for lp: Vector2 in (fd.lamps+POLISH.lamps if polish() else fd.lamps):
		var at := Vector3(f.x+lp.x,0.0,f.z+lp.y)
		at.y = far_ground(at.x,at.z)
		var l: Node3D = CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),{"size":"crown","seed":SEED+42+li,"name":"FarLamp%d" % li,"lit":true,"barge":false,"draw":0.0,"beam":2.0})
		SC._still(l)
		li += 1
	# The gate: the makers' corbel vault, its hall along x, its cracked bay
	# toward the line.
	var gate := CityBreaks2.piece("maker_corbel",SEED+41,0.6)
	gate.name = "FarGate"
	gate.transform = Transform3D(Basis(Vector3.UP,PI*0.5),g.w(ga))
	g.add_child(gate)
	var hub: Node3D = Breakables.new()
	hub.field = g.stage.enemies
	g.add_child(hub)
	# The sixth's breath (the card's tell): its back rises and falls.
	var lying: Array = pieces.get("lying",[])
	var live_i := int(LAYOUT.live)-1
	if live_i < lying.size():
		var breath := Breath.new()
		breath.name = "SixthBreath_STANDIN"
		breath.mesh = lying[live_i]
		breath.rest = (lying[live_i] as Node3D).position
		breath.up = frame_of(live_i).y*0.07*body_k()
		g.add_child(breath)
	# The sleeper (STAND-IN for the sixth rousing): a real headless body on
	# its pier under the sixth's chest, held asleep till it hears or feels.
	if not preload("res://scripts/launch_args.gd").user_args().has("--no-sleeper"):
		var sd: Dictionary = LAYOUT.sleeper
		var post := on_body(live_i,float(sd.u),0.0,float(sd.w))
		post.y = (origins()[live_i] as Vector3).y-float(sd.down)*body_k()
		# In a generated layer the roaming Olmec comes instead (olmec-threat-
		# round1.md; `--knob=olmecs=places` brings the sleeper back). The
		# pier stays.
		if OlmecPlaces.keepers(g):
			var body: Node3D = g.enemy(HeadlessBody,g.w(post)+Vector3.UP*0.1,Vector2(cos(heading(live_i)),-sin(heading(live_i))),{"hear_noise":float(sd.hear_noise),"seed":SEED})
			var sleeper := Sleeper.new()
			sleeper.name = "Sleeper_STANDIN"
			sleeper.post = g.w(post)
			sleeper.field = g.stage.enemies
			sleeper.hub = hub
			sleeper.body = body
			sleeper.study = g.stage.study
			sleeper.feel_for = float(sd.feel)
			var q: Array = []
			for c: Vector2 in [Vector2(0.0,-2.4),Vector2(NECK_U,-2.4),Vector2(NECK_U,2.4),Vector2(0.0,2.4)]:
				var p: Vector3 = g.w(on_body(live_i,c.x,0.0,c.y*body_k()))
				q.append(Vector2(p.x,p.z))
			sleeper.back = PackedVector2Array(q)
			g.add_child(sleeper)
		# Its pier: a broken shaft under its feet.
		var b := CityKit.Piece.new("SleeperPier",SEED+50,0.7)
		var turn := Basis(Vector3.UP,heading(live_i))
		b.block(CityStone.box(Transform3D(turn,post-Vector3.UP*SO*0.5),Vector3(3.4,SO*0.5,3.0),0.12),true,null,1.4)
		var tall := 16.0
		var planes := CityStone.box(Transform3D(turn,post-Vector3.UP*(SO+tall*0.5)),Vector3(2.6,tall*0.5,2.3),0.15)
		planes.append(Plane(Vector3(0.3,-1.0,0.2).normalized(),Vector3(0.3,-1.0,0.2).normalized().dot(post-Vector3.UP*(SO+tall*0.8))))
		b.block(planes,false,null,1.6)
		var piece := b.finish()
		piece.position = g.w(Vector3.ZERO)
		g.add_child(piece)

## The sixth's back breathing: its mesh eased up and down `up` m, slowly.
class Breath extends Node:
	var mesh: Node3D
	var rest := Vector3.ZERO
	var up := Vector3.ZERO
	var t := 0.0
	func _process(delta: float) -> void:
		if mesh == null or not is_instance_valid(mesh): return
		t += delta
		mesh.position = rest+up*(sin(t*TAU/5.5)*0.5+0.5)

## STAND-IN: the sixth rousing. Holds the body at its post (asleep) till its
## ears take a noise (its hearing's `heard`), or the walker has stood on the
## sixth's back (`back`, world x z) `feel_for` s; then lets it go (to the
## noise, or to where he stood). Hands it the breakables hub. Finds it again
## after a reset.
class Sleeper extends Node:
	var post := Vector3.ZERO
	var field: Node = null
	var hub: Node3D = null
	var body: Node3D = null
	var study: Node = null
	var back := PackedVector2Array()
	var feel_for := 4.0
	var awake := false
	var felt := 0.0
	## Counted, for checks: frames held, why it woke.
	var held := 0
	var woke_by := ""

	func _physics_process(delta: float) -> void:
		if body == null or not is_instance_valid(body):
			_refind()
			return
		if body.get("breaker") == null: body.breaker = hub
		if awake: return
		var motor: Variant = study.get("motor") if study != null else null
		if motor != null:
			var fp: Vector3 = motor.feet
			if Geometry2D.is_point_in_polygon(Vector2(fp.x,fp.z),back) and bool(motor.grounded): felt += delta
			else: felt = maxf(felt-delta*0.5,0.0)
		var hearing: Variant = body.get("hearing")
		if hearing != null and int(hearing.heard) > 0:
			_wake("heard")
			return
		if felt >= feel_for:
			_wake("felt")
			return
		held += 1
		body.position = post
		body.vel = Vector3.ZERO

	func _wake(why: String) -> void:
		awake = true
		woke_by = why
		if why == "felt" and study != null:
			var motor: Variant = study.get("motor")
			if motor != null: NoiseBus.make(study,motor.feet,30.0,&"procession_felt")

	func _refind() -> void:
		if field == null: return
		body = null
		for e in field.enemies:
			if is_instance_valid(e) and (e as Node3D).has_method("make_whole") and (e as Node3D).position.distance_to(post) < 8.0: body = e
		if body != null:
			awake = false
			felt = 0.0
