extends "res://studies/character_study.gd"
## Serpent ride: a greybox for running about on the back of the giant rune
## serpent (scripts/rune_serpent.gd, docs/scenic/rune-serpent.md) as it
## flies a slow loop of open sky. The serpent is the real one, with its
## look; everything round it is greybox: a grid floor far below, a start
## tower it passes close beside, a row of tall pillars it slaloms round, an
## arch it flies through, and small grey markers hung in the air along its
## way, so its speed reads.
##
## The pilot is the character study's (studies/character_study.gd, which
## this extends): the same motor (scripts/pilot_motor.gd), figure, steps,
## puffs, physics bridge, walker camera, pad, F1 numbers and F2 feel
## sliders. Only the ground is new.
##
## Its way (RIDE_ROUTE, about 2.4 km, some three and a half minutes a lap):
## north past the start tower, a 25° dive into a 22° climb, a long gentle
## curve west, a slalom round five pillars, south through the arch, a long
## gentle curve east, and back past the tower.
##
## Riding. Its skin between every two rings (and its head's, between its
## sections) is a convex hull, rebuilt from the rings each frame
## (studies/serpent_back.gd), so the bridge stands him on its back and its
## head, stops him at its flanks (to slide down and kick off) and hangs him
## from its shoulders' edges, as drawn. Each frame the serpent moves first,
## then he is carried:
##   - On it (stood, or hanging from it), he is held as a place on the body
##     (its arc back from the snout, across, up). The body's move at that
##     place since the last frame carries everything the motor keeps (his
##     feet, a lip, his pace, his facing: PilotMotor `carry`), so he goes
##     with it exactly, turned as it turns, up and down as it dives. Then
##     the motor steps as ever, on its back as it is now.
##   - In the air he keeps the velocity he left with, its carry included:
##     a frame moving at the body's velocity where he left it, so a jump
##     straight up comes down about where it left from while the body
##     turns or banks under him.
##   - Landing on it takes up its motion at once (his own pace kept), as a
##     platformer's moving ground does.
## The camera is carried with him, and takes up the body's turn over
## CAM_TURN, a boat's sway rather than a snap, while the sky, the floor,
## the pillars and the markers stream past at its speed.
##
## Falling off, more than LOST_DROP under where he left, the view fades
## softly and he is set back on its back where he last stood (or on the
## tower, if he never got on). F1 counts the falls. Ridden, it eases its
## roll (RIDE_ROLL) and now and then glances back at him over its shoulder.
##
## Keys: 1 on its neck behind the collar, 2 mid-back, 3 near the tail, 4 on
## the start tower with it coming (time the jump); R back to the start
## (the tower); F1 numbers (speed over the ground and on its back, its
## speed, what he is on, falls, the slope under him, the slide's carve); F2
## the feel's sliders; F3 the slide carving or as it was (the character
## study's: the stick across his way turns his slide rather than pushing
## him across, to follow its spine down the dive).
##
## The convoy (--convoy[=N], CONVOY serpents unless given): a line of them
## flying one way (CONVOY_ROUTE) nose to tail, each GAP m (--gap=) from its
## snout back to the tip of the tail ahead of it, kept there exactly (each
## behind the first holds the first's pace, `_advance_line`). Their way is a
## long loop of two long straight descents of DESCENT° along their backs,
## each with one gentle S, joined by climbing half turns. Sharing one way,
## the line down a descent is a long run of downhill backs with gaps in it:
## carve down one, leap off its head over the gap onto the tail of the next
## (lower, and still diving) and carve on, a string of carves. On a climb
## the downhill runs toward their tails, back down the line. He rides
## whichever he lands on; landing crouched he slides on at his pace. A
## missed leap sets him back fast, RETRY_BACK s before he left the back he
## leapt from, at the pace and on the line he had there (T, or the pad's Y,
## does the same at will: the last gap again). Only the serpents near him
## have their hulls in the world (LIVE_NEAR); the rest fly on without.
## Keys: 1, 2, 3 on the one he's on (neck, mid-back, tail), 4 on the last
## one's tail, 5 the line set at the top of the next descent with him on the
## last one's back, ready to carve down it, T the last gap again, R back to
## the start (the first descent's top; the string's counts cleared). F1 adds
## which one he's on, the string (gaps made in a row, the best), its peak
## pace, the last gap's paces, and the line's cost a frame.
## Flags, after --:
##   --girth=<x>         its girth times x (GIRTH: 1.5)
##   --ride-roll=<x>     the share of its roll kept while ridden (RIDE_ROLL)
##   --serpent-speed=<x> its pace times x
##   --weave=<x>         its slither times x (its weave shares on its way)
##   --no-glance         it never glances back at you
##   --no-carve          the slide as it was, not carving (the motor
##                       carves by default; F3 toggles it)
##   --convoy[=N]        the convoy, N serpents (CONVOY; 2 to CONVOY_MOST)
##   --gap=<m>           the convoy's gap (GAP)
##   --descent=<deg>     the slope of the convoy's descents (DESCENT)
##   ./run-serpent-ride.command
##   ./run-serpent-convoy.command
##   godot --path . res://studies/serpent_ride.tscn -- --no-title
##   godot --path . res://studies/serpent_ride.tscn -- --no-title --convoy
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const SerpentBack = preload("res://studies/serpent_back.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Variety = preload("res://scripts/seeded_variety.gd")

## Its way here: a closed cubic B-spline through these control points, each
## [point, weave share, pace share, veer share] as rune_serpent.gd's ROUTE.
## North (−z) up the east leg: level past the start tower (2), a 25° dive
## (4-8, five points in a line, so two stretches of it run straight), its
## bottom (9) and a 22° climb (10-14); a long gentle curve west (15-21,
## about 150 m round); south down the west leg in a slalom round PILLARS
## (23-27, ±36 m, so ±12 to 18 m at the curve), straight through the arch
## (30); a long gentle curve east (32-37) and home. The weave is held in by
## the tower, the pillars and the arch.
const RIDE_ROUTE := [
	[Vector3(150.0,140.0,330.0),0.3,1.0,0.0],
	[Vector3(150.0,140.0,280.0),0.1,1.0,0.0],
	[Vector3(150.0,140.0,230.0),0.1,1.0,0.0],
	[Vector3(150.0,140.0,180.0),0.1,1.0,0.0],
	[Vector3(150.0,140.0,130.0),0.4,1.0,0.0],
	[Vector3(150.0,119.0,85.0),0.5,1.0,0.0],
	[Vector3(150.0,98.0,40.0),0.5,1.0,0.0],
	[Vector3(150.0,77.0,-5.0),0.5,1.0,0.0],
	[Vector3(150.0,56.0,-50.0),0.5,1.0,0.0],
	[Vector3(150.0,49.0,-95.0),0.5,1.0,0.0],
	[Vector3(150.0,56.0,-140.0),0.5,1.0,0.0],
	[Vector3(150.0,74.0,-185.0),0.5,1.0,0.0],
	[Vector3(150.0,92.0,-230.0),0.5,1.0,0.0],
	[Vector3(150.0,110.0,-275.0),0.5,1.0,0.0],
	[Vector3(150.0,128.0,-320.0),0.5,1.0,0.0],
	[Vector3(150.0,140.0,-410.0),0.6,1.0,0.0],
	[Vector3(130.0,140.0,-485.0),0.6,1.0,0.0],
	[Vector3(75.0,140.0,-540.0),0.6,1.0,0.0],
	[Vector3(0.0,140.0,-560.0),0.6,1.0,0.0],
	[Vector3(-75.0,140.0,-540.0),0.6,1.0,0.0],
	[Vector3(-130.0,140.0,-485.0),0.6,1.0,0.0],
	[Vector3(-150.0,140.0,-410.0),0.4,1.0,0.0],
	[Vector3(-150.0,140.0,-360.0),0.25,1.0,0.0],
	[Vector3(-114.0,140.0,-300.0),0.25,1.0,0.0],
	[Vector3(-186.0,140.0,-220.0),0.25,1.0,0.0],
	[Vector3(-114.0,140.0,-140.0),0.25,1.0,0.0],
	[Vector3(-186.0,140.0,-60.0),0.25,1.0,0.0],
	[Vector3(-114.0,140.0,20.0),0.25,1.0,0.0],
	[Vector3(-150.0,140.0,90.0),0.2,1.0,0.0],
	[Vector3(-150.0,140.0,150.0),0.2,1.0,0.0],
	[Vector3(-150.0,140.0,210.0),0.2,1.0,0.0],
	[Vector3(-150.0,140.0,270.0),0.4,1.0,0.0],
	[Vector3(-150.0,140.0,330.0),0.6,1.0,0.0],
	[Vector3(-130.0,140.0,405.0),0.6,1.0,0.0],
	[Vector3(-75.0,140.0,460.0),0.6,1.0,0.0],
	[Vector3(0.0,140.0,480.0),0.6,1.0,0.0],
	[Vector3(75.0,140.0,460.0),0.6,1.0,0.0],
	[Vector3(130.0,140.0,405.0),0.6,1.0,0.0],
]
## Places on its way, by control point.
const RIDE_MARKS := {"tower":2,"dive":5,"bottom":9,"climb":11,"north":18,"pillars":23,"arch":30,"south":35}

## The floor far below: its height (m), its grid's cell (m: a line every
## cell, a stronger one every five) and its reach either way from the
## middle (m).
const FLOOR_Y := 0.0
const FLOOR_CELL := 10.0
const FLOOR_HALF := 2400.0
## The slalom's pillars (x, z), on the west leg's middle line, each inside
## a bend of the slalom; their half width and their top (m).
const PILLARS := [Vector2(-150.0,-296.7),Vector2(-150.0,-220.0),Vector2(-150.0,-140.0),Vector2(-150.0,-60.0),Vector2(-150.0,18.3)]
const PILLAR_HALF := 2.5
const PILLAR_TOP := 215.0
## The arch at its mark: the gap from its flank at its widest (and its
## weave) to each post, the posts' half width, how far over its back the
## lintel's underside is (high enough that the camera passes under it
## too), and the lintel's depth (m).
const ARCH_GAP := 5.0
const ARCH_POST := 2.5
const ARCH_CLEAR := 9.0
const ARCH_DEPTH := 5.0
## The start tower, beside its way at the tower mark: its half width, the
## gap kept from its flank at its widest and its weave as it passes, and
## how far the tower's top stands over its back's crest (m).
const TOWER_HALF := 4.0
const TOWER_GAP := 1.2
const TOWER_RISE := 1.2
## Set on the tower, the serpent's head is set down this far (m) back
## along its way from the tower: its head comes by in about five seconds,
## its middle in about eight.
const TOWER_LEAD := 60.0
## Where keys 1, 2 and 3 set him on its back (m back from the snout): just
## behind the collar on the neck, mid-back, near the tail.
const NECK_AT := 11.0
const MID_AT := 45.0
const TAIL_AT := 70.0
## Its girth, times rune_serpent.gd's (--girth=): 1.5 makes it 6 m through,
## its back's flat top 1.95 m across and 5.5 m to its shoulders' edges (1:
## 1.3 and 3.7 m; 2: 2.6 and 7.3 m). Chosen as the middle: a bot playing on
## its back (runs, jumps, long jumps, twirls) fell 3.0 times a minute at 1,
## 2.5 at 1.5, 2.25 at 2; 1.5 keeps it a slender snake, 2 reads as a road.
const GIRTH := 1.5
## The share of its roll into turns it keeps while ridden (--ride-roll=),
## and the seconds after he leaves its back it still counts as ridden. At
## 0.4 its flat top tilts at most about 9° round the loop (all of it: 20°,
## near the motor's SLOPE_SLOW, where a run up it slows), and its banks
## still show. In a bank its low shoulder (40° unbanked) passes SLIDE_AUTO
## either way: stood there, he surfs off.
const RIDE_ROLL := 0.4
const RIDDEN_AFTER := 3.0
## Falling: this far (m) under the frame he left in, he is lost. The fade
## out, the beat held, the fade in (s); its colour, the sky's horizon.
const LOST_DROP := 14.0
const FADE_OUT := 0.35
const FADE_HOLD := 0.2
const FADE_IN := 0.5
const FADE_COLOUR := Color("dfe6e4")
## The camera takes up the body's turn over this many seconds.
const CAM_TURN := 0.6
## How far the eye sees (m): the floor and the pillars across the loop.
const FAR := 5000.0
## Markers hung in the air along its way, so its speed reads: one every
## MARKER_EVERY m, either side in turn, MARKER_OFF m out (least, most) and
## up to MARKER_RISE m over or under its way; MARKER_SIZE m through; none
## within MARKER_CLEAR m of a pillar, the arch or the tower.
const MARKER_EVERY := 24.0
const MARKER_OFF := Vector2(16.0,34.0)
const MARKER_RISE := 7.0
const MARKER_SIZE := 1.2
const MARKER_CLEAR := 22.0

## The convoy: how many serpents (--convoy=N), and the most.
const CONVOY := 5
const CONVOY_MOST := 8
## The gap (m, --gap=) along their way from each one's snout back to the
## tip of the tail of the one ahead. The leap that matters is longer: from
## its head's flat top (about 4 m back from its snout) over the gap to
## where the tail ahead is wide enough to land and stay on (about 10 m in
## from its tip). A bot (tools/serpent_convoy_bot.gd, 600 s a run, three
## seeds) landed 85-86% of its leaps on the next at 2 m, 74-83% at 3,
## 73-81% at 4 (94% at 0, where the gap hardly shows).
const GAP := 2.0
## The line's girth, times rune_serpent.gd's, unless --girth= is given
## (the single serpent's is GIRTH). Their tails are where he lands: at 1.5
## the last ten metres of a tail are under a metre and a half across,
## shoulders and all, and the bot landed 51% of its leaps; at 2, 85%.
const CONVOY_GIRTH := 2.0
## Their way (`convoy_route`): two straight legs, the east north and the
## west south, each a descent at DESCENT° (--descent=) from HIGH m over
## 2*LEG_HALF m, bending BEND m out and back in one gentle S (about 1.2 km
## round at its tightest) on LEG_POINTS control points; joined by climbing
## half turns, LEG_X m round, on TURN_POINTS. Its weave share, all round
## (times --weave=).
const HIGH := 430.0
const LEG_X := 260.0
const LEG_HALF := 600.0
const DESCENT := 20.0
const BEND := 30.0
const LEG_POINTS := 12
const TURN_POINTS := 8
const CONVOY_WEAVE := 0.4
## Its marks, by control point: the tops of the two descents (a, b), their
## feet (a_low, b_low), and the middles of the turns (north, south).
const CONVOY_MARKS := {"a":0,"a_low":12,"north":16,"b":20,"b_low":32,"south":36}
## The descents in order round its way: [top, foot].
const DESCENTS := [["a","a_low"],["b","b_low"]]
## Each behind the first holds the first's pace, and LINE_PULL m/s more for
## every metre it has fallen behind its place (less, ahead of it), up to
## LINE_CATCH m/s either way: so they keep their places in the line to the
## centimetre round the loop.
const LINE_PULL := 0.5
const LINE_CATCH := 1.5
## The true length round their way is read every LINE_STEP m of its arc.
const LINE_STEP := 1.0
## Set at a descent's top (5, R): the line laid so the last one's back at
## START_AT m from its snout is START_PAST m down the descent from its top
## (its slope there about 12° on the way down).
const START_AT := 60.0
const START_PAST := 60.0
## Only these have their hulls in the world, rebuilt each frame: the one he
## is on (or last left) and any with a ring or its head within LIVE_NEAR m
## of him (the one ahead as he nears its tail, the one behind on a climb).
const LIVE_NEAR := 30.0
## A leap missed: lost LINE_DROP m under the line (where he left, carried
## on down their way's slope as he goes on along it: the next tail is
## never so far under him), the view fades quicker (out, held, in; s),
## and he is set back on the spine of the back he leapt from where he was
## RETRY_BACK s before he left it, at his pace then. His places on the
## backs are kept HISTORY s.
const LINE_DROP := 8.0
const LINE_FADE := Vector3(0.2,0.1,0.35)
const RETRY_BACK := 1.5
const HISTORY := 4.0

## The serpent, and its body as ground.
var serpent: Node3D
var back: SerpentBack
var girth := GIRTH
var _girth_given := false
var ride_roll := RIDE_ROLL
## Its slither, times the route's weave shares (--weave=).
var weave := 1.0
var glance := true
## What he is on: "serpent" (stood on it or hanging from it), "still"
## (standing ground: the tower), "air".
var riding_on := "still"
## His place on the body (arc, across, up) while on it, and the last place
## he stood on it; whether he has been on it since he was last set down.
var anchor := Vector3.ZERO
var last_on := Vector3(MID_AT,0.0,0.0)
var rode := false
## Times he has fallen off and been set back.
var falls := 0
## The frame he left in, in the air (m/s), and his feet's carry on the
## body this frame (m/s).
var air_v := Vector3.ZERO
var carry_v := Vector3.ZERO
## The start tower's top middle, the way across to its way (x, z), and
## the way he is set facing on it (toward the serpent as it comes).
var tower_top := Vector3.ZERO
var tower_out := Vector2(1.0,0.0)
var tower_face := Vector2(1.0,0.0)
## The serpent watches for these (rune_serpent.gd `watcher`): never flying.
var flying := false
var plane: Variant = null
var _air_ref := 0.0
# The frame he left in, flat (its way), and its slope (rise a metre).
var _air_way := Vector2.ZERO
var _air_slope := 0.0
var _turn_owed := 0.0
var _since_ridden := 99.0
var _fade_t := -1.0
var _set_back := false
var _fade: ColorRect
var _arch_at := Vector3.ZERO

## The convoy: how many in the line (0: the single serpent), its gap (m)
## and its descents' slope (degrees).
var convoy := 0
var gap := GAP
var descent := DESCENT
## Every serpent and its back, the first the lead (the single serpent
## alone, without the convoy); the one he is on or last left (`serpent`
## and `back` are it).
var serpents: Array[Node3D] = []
var backs: Array[SerpentBack] = []
var on_k := 0
## The string: gaps made in all, in a row (since the last fall or the
## start), the best row, his fastest on a back in this row (on its back and
## over the ground, m/s), falls; the last gap ({from, to, left, landed}:
## the serpents and his pace on the back leaving and landing).
var gaps := 0
var string := 0
var best_string := 0
var string_peak := 0.0
var string_peak_ground := 0.0
var last_gap := {}
## The line's cost the last frame (µs): the serpents' advance, the backs
## (rings read, the live ones' hulls laid); and how many backs are live.
var line_usec := 0
var hulls_usec := 0
var live_count := 0
# The true length of their way from its start to each LINE_STEP of its
# arc, and round.
var _line_true := PackedFloat32Array()
var _line_length := 0.0
# Where he has stood on the backs, the newest last: {t, k, place, rel
# (his pace along and across its way), face (his facing off its way),
# move, string}; the state to set back to for the last take-off; the
# serpent he left, in the air (-1 none) and his pace leaving.
var _history: Array[Dictionary] = []
var _retry := {}
var _left := -1
var _left_pace := 0.0
var _line_clock := 0.0

func _init() -> void:
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--girth="):
			girth = clampf(float(arg.get_slice("=",1)),0.5,3.0)
			_girth_given = true
		elif arg.begins_with("--ride-roll="): ride_roll = clampf(float(arg.get_slice("=",1)),0.0,1.0)
		elif arg.begins_with("--weave="): weave = clampf(float(arg.get_slice("=",1)),0.0,2.0)
		elif arg == "--no-glance": glance = false
		elif arg == "--convoy": convoy = CONVOY
		elif arg.begins_with("--convoy="): convoy = clampi(int(arg.get_slice("=",1)),2,CONVOY_MOST)
		elif arg.begins_with("--gap="): gap = clampf(float(arg.get_slice("=",1)),0.0,40.0)
		elif arg.begins_with("--descent="): descent = clampf(float(arg.get_slice("=",1)),4.0,30.0)
	# The floor is a backstop under everything; the fall is caught well
	# before (LOST_DROP).
	lost = FLOOR_Y+5.0

# --- The sky ------------------------------------------------------------------------

func _build_light() -> void:
	super._build_light()
	camera.far = FAR

func _build_room() -> void:
	if convoy > 0: _build_convoy()
	else: _build_serpent()
	_build_floor()
	if convoy == 0:
		_build_tower()
		for p: Vector2 in PILLARS: _box(Rect2(p.x-PILLAR_HALF,p.y-PILLAR_HALF,PILLAR_HALF*2.0,PILLAR_HALF*2.0),FLOOR_Y,PILLAR_TOP,"grey")
		_build_arch()
	_build_markers()
	_build_fade()
	# Its sound: scales, hum, breath, the ride's rumble and carves
	# (docs/design/sound-round3.md).
	preload("res://scripts/kit_isle/kit_audio_beasts.gd").attach(self)

## The real serpent on this scene's way, driven from `tick` (its own
## process off), its capsules left out (its back's hulls stand in).
func _build_serpent() -> void:
	serpent = _new_serpent(RIDE_ROUTE,RIDE_MARKS,"tower",0)
	back = SerpentBack.new(serpent,self)
	serpents = [serpent]
	backs = [back]

## A real serpent flying `way` (its weave shares times --weave=), set at
## `start`, the `k`th of a line (its own draws and clock), driven from
## `tick`.
func _new_serpent(way: Array, marks: Dictionary, start: String, k: int) -> Node3D:
	var made: Node3D = RuneSerpent.new()
	var route := []
	for point: Array in way: route.append([point[0],float(point[1])*weave,point[2],point[3]])
	made.route = route
	made.route_marks = marks
	made.start_mark = start
	made.girth = girth
	made.solid = false
	made.look_back = glance
	if k > 0:
		made.name = "RuneSerpent%d" % (k+1)
		made.rng_seed = 7741+97*k
		made.clock = 13.7*k
	add_child(made)
	made.setup(self)
	made.set_process(false)
	made.set_physics_process(false)
	return made

## The convoy's line: `convoy` serpents on its way, the first the lead,
## each its own back; the true length round their way read; laid nose to
## tail at the first descent's top.
func _build_convoy() -> void:
	if not _girth_given: girth = CONVOY_GIRTH
	var way := convoy_route(descent)
	for k in range(convoy):
		var made := _new_serpent(way,CONVOY_MARKS,"a",k)
		serpents.append(made)
		backs.append(SerpentBack.new(made,self))
	serpent = serpents[serpents.size()-1]
	back = backs[backs.size()-1]
	on_k = serpents.size()-1
	_read_line()
	_line_at("a")

## The convoy's way, its descents at `slope` degrees (`descent`): control
## points as RIDE_ROUTE's. The east leg runs north (−z) down from HIGH, a
## gentle S out to the east and back in; the north turn climbs round west
## to the west leg, which runs south down from HIGH the same; the south
## turn climbs round east to the start.
static func convoy_route(slope: float) -> Array:
	var drop := 2.0*LEG_HALF*tan(deg_to_rad(slope))
	var low := HIGH-drop
	var out := []
	for leg in range(2):
		var side := 1.0 if leg == 0 else -1.0
		for i in range(LEG_POINTS):
			var f := float(i)/LEG_POINTS
			out.append([Vector3(side*(LEG_X+BEND*sin(TAU*f)),HIGH-drop*f,side*(LEG_HALF-2.0*LEG_HALF*f)),CONVOY_WEAVE,1.0,0.0])
		for i in range(TURN_POINTS):
			var f := float(i)/TURN_POINTS
			var a := PI*f
			out.append([Vector3(side*LEG_X*cos(a),low+drop*f,-side*(LEG_HALF+LEG_X*sin(a))),CONVOY_WEAVE,1.0,0.0])
	return out

## The true length of their way (as the lead's head lays it: the weave and
## the heave in) from its start to every LINE_STEP of its arc.
func _read_line() -> void:
	var lead := serpents[0]
	var count := int(ceil(float(lead.route_length)/LINE_STEP))
	_line_true.resize(count+1)
	_line_true[0] = 0.0
	var was: Vector3 = lead._path(0.0)[0]
	for i in range(1,count+1):
		var p: Vector3 = lead._path(minf(i*LINE_STEP,float(lead.route_length)))[0]
		_line_true[i] = _line_true[i-1]+p.distance_to(was)
		was = p
	_line_length = _line_true[count]

## The true length of their way from its start to arc `at` (m).
func _true_at(at: float) -> float:
	var f := fposmod(at,float(serpents[0].route_length))/LINE_STEP
	var i := mini(floori(f),_line_true.size()-2)
	return lerpf(_line_true[i],_line_true[i+1],f-i)

## The arc `metres` of true length on along their way from arc `at` (back,
## if less than 0).
func _arc_on(at: float, metres: float) -> float:
	var want := fposmod(_true_at(at)+metres,_line_length)
	var lo := 0
	var hi := _line_true.size()-1
	while hi-lo > 1:
		var mid := (lo+hi)/2
		if _line_true[mid] <= want: lo = mid
		else: hi = mid
	return (lo+(want-_line_true[lo])/maxf(_line_true[hi]-_line_true[lo],1e-6))*LINE_STEP

## How far along their way (true m) serpent `k`'s head is from the lead's.
func _behind_lead(k: int) -> float:
	return fposmod(_true_at(serpents[0].s)-_true_at(serpents[k].s),_line_length)

## The line laid nose to tail, the lead's head at arc `lead_at`: each
## head LENGTH and the gap behind the one ahead's (place() lays a body back
## from its head by travelling on from an arc behind it, so each is set
## from the arc that travel ends at hers).
func _place_line(lead_at: float) -> void:
	var lay := RuneSerpent.LENGTH+RuneSerpent.STEP*8.0
	for k in range(serpents.size()):
		var head := _arc_on(lead_at,-k*spacing())
		serpents[k].pace_hold = -1.0
		serpents[k].place(fposmod(_arc_on(head,-lay)+lay,float(serpents[k].route_length)))
	for b: SerpentBack in backs: b.reset()

## From one head to the next (m).
func spacing() -> float:
	return RuneSerpent.LENGTH+gap

## The line set at descent `mark`'s top: the last one's back at START_AT
## from its snout START_PAST m down from the top; him there, facing its
## head.
func _line_at(mark: String) -> void:
	var spot := float(serpents[0].marks()[mark])+START_PAST
	_place_line(_arc_on(spot,START_AT+(serpents.size()-1)*spacing()))
	_history.clear()
	_retry = {}
	_left = -1

## The descent to start down (5): the one the last serpent's head is on
## now (again from its top), else the next ahead round their way.
func descent_to_start() -> String:
	var last := serpents[serpents.size()-1]
	var length := float(last.route_length)
	var best := ""
	var nearest := INF
	for d: Array in DESCENTS:
		var top := float(last.marks()[d[0]])
		if fposmod(float(last.s)-top,length) < fposmod(float(last.marks()[d[1]])-top,length): return d[0]
		var ahead := fposmod(top-float(last.s),length)
		if ahead < nearest:
			nearest = ahead
			best = d[0]
	return best

func _build_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(FLOOR_HALF*2.0,2.0,FLOOR_HALF*2.0)
	shape.shape = slab
	shape.position = Vector3(0.0,FLOOR_Y-1.0,0.0)
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(FLOOR_HALF*2.0,FLOOR_HALF*2.0)
	mesh.mesh = plane_mesh
	mesh.position = Vector3(0.0,FLOOR_Y,0.0)
	var grid := ShaderMaterial.new()
	grid.shader = GRID
	grid.set_shader_parameter("tint",COLOURS.floor)
	grid.set_shader_parameter("cell",FLOOR_CELL)
	mesh.material_override = grid
	floor_body.add_child(mesh)
	add_child(floor_body)

## Where its body passes at route arc `at`: its path with the weave (as
## its rings pass through it), the way along it and across it (flat).
func _way_at(at: float) -> Array:
	var p: Vector3 = serpent._path(at)[0]
	var way: Vector3 = serpent.route_point(at+2.0)-serpent.route_point(at-2.0)
	way = Vector3(way.x,0.0,way.z).normalized()
	return [p,way,way.cross(Vector3.UP).normalized()]

## Its body's half width at its widest (m) and its weave's reach at `at`.
func _clear_at(at: float) -> float:
	return back.half_width(MID_AT)+serpent.weave_reach()*serpent.route_shares(at).x

## The start tower beside its way, on the left as it comes, its top a lip
## a little over its back.
func _build_tower() -> void:
	var at: float = serpent.marks()["tower"]
	var w := _way_at(at)
	var p: Vector3 = w[0]
	var right: Vector3 = w[2]
	var middle := p-right*(_clear_at(at)+TOWER_GAP+TOWER_HALF)
	tower_top = Vector3(middle.x,p.y+back.top(MID_AT).z+TOWER_RISE,middle.z)
	var way: Vector3 = w[1]
	tower_out = Vector2(right.x,right.z)
	tower_face = (tower_out-Vector2(way.x,way.z)*0.8).normalized()
	_box(Rect2(middle.x-TOWER_HALF,middle.z-TOWER_HALF,TOWER_HALF*2.0,TOWER_HALF*2.0),FLOOR_Y,tower_top.y,"lip")
	_label(tower_top+Vector3(0.0,0.5,0.0)-right*2.0,"START · 4 · R",36)

## The arch at its mark: two posts either side of its way and a lintel
## across, high over its back.
func _build_arch() -> void:
	var at: float = serpent.marks()["arch"]
	var w := _way_at(at)
	var p: Vector3 = w[0]
	var right: Vector3 = w[2]
	var out := _clear_at(at)+ARCH_GAP+ARCH_POST
	var under := p.y+back.top(MID_AT).z+ARCH_CLEAR
	var lintel := ARCH_DEPTH
	var yaw := rad_to_deg(atan2(-right.z,right.x))
	for side: float in [-1.0,1.0]:
		var foot := p+right*side*out
		_obox(Vector3(foot.x,(FLOOR_Y+under+lintel)*0.5,foot.z),Vector3(ARCH_POST*2.0,under+lintel-FLOOR_Y,ARCH_POST*2.0),yaw,"grey")
	_obox(Vector3(p.x,under+lintel*0.5,p.z),Vector3((out+ARCH_POST)*2.0,lintel,ARCH_POST*2.0),yaw,"grey")
	_arch_at = Vector3(p.x,under,p.z)

## Small grey markers hung in the air along its way, either side in turn.
func _build_markers() -> void:
	var places: Array[Vector3] = []
	var keep_off: Array[Vector2] = [Vector2(tower_top.x,tower_top.z),Vector2(_arch_at.x,_arch_at.z)]
	for p: Vector2 in PILLARS: keep_off.append(p)
	var at := 0.0
	var side := 1.0
	var i := 0
	while at < serpent.route_length:
		var w := _way_at(at)
		var p: Vector3 = w[0]
		var out := lerpf(MARKER_OFF.x,MARKER_OFF.y,Variety.unit([i,3]))
		var spot: Vector3 = p+(w[2] as Vector3)*side*out+Vector3.UP*(Variety.unit([i,5])*2.0-1.0)*MARKER_RISE
		var clear := true
		for k: Vector2 in keep_off:
			if Vector2(spot.x,spot.z).distance_to(k) < MARKER_CLEAR: clear = false
		if clear: places.append(spot)
		at += MARKER_EVERY
		side = -side
		i += 1
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE*MARKER_SIZE
	multi.mesh = cube
	multi.instance_count = places.size()
	for n in range(places.size()):
		multi.set_instance_transform(n,Transform3D(Basis(Vector3.UP,Variety.unit([n,7])*TAU),places[n]))
	var markers := MultiMeshInstance3D.new()
	markers.name = "Markers"
	markers.multimesh = multi
	markers.material_override = _material("dark")
	markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(markers)

## A soft full-screen fade for a fall.
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(FADE_COLOUR,0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)

# --- Setting him down ---------------------------------------------------------------

## The start: on the tower, the serpent coming; in the convoy, the line at
## the first descent's top with him on the last one's back, the string's
## counts cleared.
func respawn() -> void:
	if convoy == 0:
		to_tower()
		return
	falls = 0
	gaps = 0
	best_string = 0
	_break_string()
	last_gap = {}
	_line_at("a")
	set_on(serpents.size()-1,START_AT)

## 1 on its neck behind the collar, 2 mid-back, 3 near the tail, 4 the
## tower. In the convoy, 1 to 3 on the one he's on, 4 on the last one's
## tail, 5 the line at the top of a descent (`descent_to_start`) with him
## on the last one's back.
func go_to(key: int) -> void:
	match key:
		1: set_on_back(NECK_AT)
		2: set_on_back(MID_AT)
		3: set_on_back(TAIL_AT)
		4:
			if convoy > 0: set_on(serpents.size()-1,TAIL_AT)
			else: to_tower()
		5:
			if convoy > 0: to_descent(descent_to_start())

## The line set at descent `mark`'s top (a, b), him on the last one's back
## at START_AT, facing its head; the string begun anew.
func to_descent(mark: String) -> void:
	_line_at(mark)
	_break_string()
	set_on(serpents.size()-1,START_AT)

## On the tower's top, facing the serpent as it comes, its head TOWER_LEAD m
## off.
func to_tower() -> void:
	serpent.place(fposmod(float(serpent.marks()["tower"])-TOWER_LEAD,serpent.route_length))
	back.reset()
	place(tower_top,tower_face)
	_still_now()
	rode = false
	_since_ridden = 99.0

## Serpent `k` (0 the lead) is the one he is on: its back his ground.
func _switch_to(k: int) -> void:
	on_k = k
	serpent = serpents[k]
	back = backs[k]
	back.set_live(true)

## On serpent `k`'s back at arc `a`, as `set_on_back`.
func set_on(k: int, a: float) -> void:
	_switch_to(k)
	set_on_back(a)

## On the middle of its back's top at arc `a`, facing its head.
func set_on_back(a: float) -> void:
	_set_on_place(back.top(a),Vector2.ZERO,0.0,"")

## On its back at place `c` (arc, across, up), his pace `rel` along its way
## toward its head and across it (m/s), facing `face` off its way, moving
## `move` ("slide": surfing on as he was).
func _set_on_place(c: Vector3, rel: Vector2, face: float, move: String) -> void:
	var a := c.x
	var at := back.place(c)
	var ahead := back.ahead(a)
	place(at,ahead)
	if rel != Vector2.ZERO or face != 0.0:
		var h := ahead*rel.x+Vector2(-ahead.y,ahead.x)*rel.y
		motor.velocity = Vector3(h.x,0.0,h.y)
		motor.facing = wrapf(PilotMotor.facing_of(ahead)+face,-PI,PI)
		_yaw = motor.facing
		if move == "slide": motor.move = "slide"
	riding_on = "serpent"
	anchor = back.locate(at,a)
	last_on = anchor
	rode = true
	_since_ridden = 0.0
	air_v = Vector3.ZERO
	var along := back.frame(a).basis.z.normalized()
	carry_v = along*float(serpent.speed())
	_turn_owed = 0.0
	_left = -1

func _still_now() -> void:
	riding_on = "still"
	air_v = Vector3.ZERO
	carry_v = Vector3.ZERO
	_turn_owed = 0.0

# --- A frame ------------------------------------------------------------------------

## The serpent moves on (in the convoy, the line); he is carried with it
## (or with the frame he left it in); then the character study's own frame
## (the motor's step over what is there now, the figure, its puffs and
## steps, the camera); then what he stands on now, and whether he has
## fallen; in the convoy, where he stood kept and the string counted.
func tick(delta: float) -> void:
	var step := minf(delta,RuneSerpent.MAX_STEP)
	if convoy > 0: _advance_line(step)
	else:
		serpent.bank_share = ride_roll if _since_ridden < RIDDEN_AFTER else 1.0
		serpent.advance(step)
		back.update()
	_carry(step)
	var carried := motor.feet
	var was_air := riding_on == "air"
	var take := _turn_owed*(1.0-exp(-delta/CAM_TURN))
	_yaw += take
	_turn_owed -= take
	super.tick(delta)
	_contact(delta)
	# In the line, the fall is measured from the line's own slope under
	# him: his own way on along the frame he left in, down (or up) its
	# slope as their way goes.
	if convoy > 0 and was_air and riding_on == "air":
		_air_ref += Vector2(motor.feet.x-carried.x,motor.feet.z-carried.z).dot(_air_way)*_air_slope
	_fall(delta)
	if convoy > 0: _keep(delta)

## The line on over `step`: the lead at its own pace, every one behind it
## held to that pace, a little more or less to keep its place exactly
## (LINE_PULL); all eased in their roll as ridden; then the backs read,
## only the live ones' hulls laid (`_choose_live`).
func _advance_line(step: float) -> void:
	var began := Time.get_ticks_usec()
	var lead := serpents[0]
	for each: Node3D in serpents: each.bank_share = ride_roll
	lead.advance(step)
	for k in range(1,serpents.size()):
		var off := _behind_lead(k)-k*spacing()
		serpents[k].pace_hold = maxf(float(lead.speed())+clampf(off*LINE_PULL,-LINE_CATCH,LINE_CATCH),0.0)
		serpents[k].advance(step)
	var laid := Time.get_ticks_usec()
	_choose_live()
	for b: SerpentBack in backs: b.update()
	hulls_usec = Time.get_ticks_usec()-laid
	line_usec = Time.get_ticks_usec()-began

## Live (hulls in the world, laid each frame): the one he is on or last
## left, and any with its head or a ring within LIVE_NEAR m of him.
func _choose_live() -> void:
	var at := motor.feet
	var near := LIVE_NEAR*LIVE_NEAR
	live_count = 0
	for k in range(serpents.size()):
		var live := k == on_k or (serpents[k].head() as Vector3).distance_squared_to(at) < near
		var rings: PackedVector3Array = serpents[k].rings()
		var i := 0
		while not live and i < rings.size():
			live = rings[i].distance_squared_to(at) < near
			i += 3
		backs[k].set_live(live)
		if live: live_count += 1

## Carried over `step`: on it, by the body's move where he is; in the air,
## by the frame he left in (slid round what stands in the way, as his own
## steps are).
func _carry(step: float) -> void:
	if step <= 0.0: return
	var was := motor.feet
	if riding_on == "serpent":
		var turn := back.turn(anchor.x)
		motor.carry(back.moved(anchor),turn)
		carry_v = (motor.feet-was)/step
		_carry_camera(was,motor.feet-was,turn)
	elif riding_on == "air" and air_v != Vector3.ZERO:
		var go := air_v*step
		var slid: Vector3 = ground.slide(was,Vector2(go.x,go.z))
		var moved := Vector3(slid.x-was.x,go.y,slid.z-was.z)
		motor.carry(Transform3D(Basis.IDENTITY,moved),0.0)
		_air_ref += go.y
		_carry_camera(was,moved,0.0)

## The camera's follow point carried with him (moved, and turned about
## him), the turn owed to its yaw, taken up over CAM_TURN.
func _carry_camera(about: Vector3, moved: Vector3, turn: float) -> void:
	var pivot := Vector3(_cam_at.x,_cam_y,_cam_at.y)
	pivot = about+moved+(pivot-about).rotated(Vector3.UP,turn)
	_cam_at = Vector2(pivot.x,pivot.z)
	_cam_y = pivot.y
	var pace := Vector3(_cam_pace.x,0.0,_cam_pace.y).rotated(Vector3.UP,turn)
	_cam_pace = Vector2(pace.x,pace.z)
	_turn_owed += turn

## What he is on after the step: its back (held as a place on it), still
## ground, or the air (leaving its back, the frame he leaves in is its
## carry).
func _contact(delta: float) -> void:
	var was := riding_on
	var was_k := on_k
	var under := -1
	if motor.on_ledge():
		under = _back_under(motor.lip-Vector3(motor.lip_out.x,0.0,motor.lip_out.y)*0.1)
		riding_on = "serpent" if under >= 0 else "still"
	elif motor.grounded:
		under = _back_under(motor.feet)
		riding_on = "serpent" if under >= 0 else "still"
	else: riding_on = "air"
	# Onto another: its back his ground from now (the line's handover).
	if under >= 0 and under != on_k: _switch_to(under)
	match riding_on:
		"serpent":
			anchor = back.locate(motor.lip if motor.on_ledge() else motor.feet,anchor.x if was == "serpent" and on_k == was_k else -1.0)
			if motor.grounded: last_on = anchor
			rode = true
			_since_ridden = 0.0
			air_v = Vector3.ZERO
			if was == "air" and convoy > 0 and not fading(): _landed()
		"air":
			if was != "air":
				air_v = carry_v if was == "serpent" else Vector3.ZERO
				_air_ref = motor.feet.y
				var flat := Vector2(air_v.x,air_v.z)
				_air_way = flat.normalized() if flat.length() > 0.1 else Vector2.ZERO
				_air_slope = air_v.y/maxf(flat.length(),0.1)
				if was == "serpent" and convoy > 0 and not fading(): _took_off()
			_since_ridden += delta
		_:
			air_v = Vector3.ZERO
			carry_v = Vector3.ZERO
			_since_ridden += delta

## Which serpent's back is right under `p` (0 the lead), or -1.
func _back_under(p: Vector3) -> int:
	var rid := _rid_under(p)
	if not rid.is_valid(): return -1
	for k in range(backs.size()):
		if backs[k].rid() == rid: return k
	return -1

## What is right under `p` (its body's RID), or none.
func _rid_under(p: Vector3) -> RID:
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.3,p-Vector3.UP*0.35,ground.mask)
	var hit := ground.space.intersect_ray(ray)
	return hit.rid if not hit.is_empty() else RID()

## Lost (LOST_DROP under the frame he left in): the view fades out, he is
## set back on its back where he last stood (on the tower if he never got
## on), and it fades in.
func _fall(delta: float) -> void:
	if _fade_t < 0.0:
		if riding_on == "air" and _air_ref-motor.feet.y > (LINE_DROP if convoy > 0 else LOST_DROP):
			falls += 1
			_fade_t = 0.0
			_set_back = false
			if convoy > 0: _break_string()
		return
	var fade := LINE_FADE if convoy > 0 else Vector3(FADE_OUT,FADE_HOLD,FADE_IN)
	_fade_t += delta
	var a := 1.0
	if _fade_t < fade.x: a = smoothstep(0.0,1.0,_fade_t/fade.x)
	elif _fade_t > fade.x+fade.y: a = 1.0-smoothstep(0.0,1.0,(_fade_t-fade.x-fade.y)/fade.z)
	if not _set_back and _fade_t >= fade.x+fade.y*0.5:
		_set_back = true
		if convoy > 0: retry_gap(false)
		elif rode: set_on_back(clampf(last_on.x,NECK_AT,TAIL_AT))
		else: to_tower()
	_fade.color = Color(FADE_COLOUR,a)
	if _fade_t >= fade.x+fade.y+fade.z:
		_fade_t = -1.0
		_fade.color = Color(FADE_COLOUR,0.0)

## Whether he is being set back after a fall.
func fading() -> bool:
	return _fade_t >= 0.0

# --- The string (the convoy) ---------------------------------------------------------

## Off a back into the air: the serpent he left and his pace, and where to
## set him back for this leap (his place RETRY_BACK s before, on this back).
func _took_off() -> void:
	_left = on_k
	_left_pace = motor.speed()
	var pick := {}
	for i in range(_history.size()-1,-1,-1):
		var was: Dictionary = _history[i]
		if int(was.k) != on_k: break
		pick = was
		if float(was.t) <= _line_clock-RETRY_BACK: break
	if not pick.is_empty(): _retry = pick

## Down on a back out of the air: onto another than he left, a gap made.
func _landed() -> void:
	if _left >= 0 and on_k != _left:
		gaps += 1
		string += 1
		best_string = maxi(best_string,string)
		last_gap = {"from":_left,"to":on_k,"left":_left_pace,"landed":motor.speed()}
	_left = -1

## Each frame on a back, where he stood kept (HISTORY s); the string's peak.
func _keep(delta: float) -> void:
	_line_clock += delta
	if riding_on == "serpent" and motor.grounded and not fading():
		var ahead := back.ahead(anchor.x)
		var h := Vector2(motor.velocity.x,motor.velocity.z)
		_history.append({"t":_line_clock,"k":on_k,"place":anchor,"rel":Vector2(h.dot(ahead),h.dot(Vector2(-ahead.y,ahead.x))),
			"face":wrapf(motor.facing-PilotMotor.facing_of(ahead),-PI,PI),"move":motor.move,"string":string})
	while not _history.is_empty() and _line_clock-float(_history[0].t) > HISTORY: _history.pop_front()
	if not fading():
		string_peak = maxf(string_peak,motor.speed())
		var over := ground_velocity()
		string_peak_ground = maxf(string_peak_ground,Vector2(over.x,over.z).length())

## A fall (or a start): the string begun again.
func _break_string() -> void:
	string = 0
	string_peak = 0.0
	string_peak_ground = 0.0

## The last leap again (T, the pad's Y, and after a fall): set back on the
## spine of the back he leapt from where he was RETRY_BACK s before he left
## it, at his pace then along its spine the way he was going, sliding if he
## was (a clean run at it, wherever across it he had drifted); the string
## as it was then (`keep`), or begun again (a fall). Before any leap, back
## where he last stood.
func retry_gap(keep := true) -> void:
	if _retry.is_empty():
		set_on(on_k,clampf(last_on.x,NECK_AT,TAIL_AT))
		return
	var r := _retry
	_switch_to(int(r.k))
	var rel: Vector2 = r.rel
	var toward := 1.0 if rel.x >= 0.0 else -1.0
	_set_on_place(back.top(float(r.place.x)),Vector2(toward*rel.length(),0.0),0.0 if toward > 0.0 else PI,str(r.move))
	if keep: string = int(r.string)
	_history.clear()

# --- Numbers ------------------------------------------------------------------------

## His velocity over the ground (m/s): his own and the frame he is in.
func ground_velocity() -> Vector3:
	var frame := carry_v if riding_on == "serpent" else (air_v if riding_on == "air" else Vector3.ZERO)
	return frame+motor.velocity

func _show_hud() -> void:
	if not _hud.visible: return
	var over := ground_velocity()
	var where := "on the tower"
	if riding_on == "serpent": where = "on its back · %.1f m from the snout, %+.2f across" % [anchor.x,anchor.y]
	elif riding_on == "air": where = "in the air · %.1f m under where he left" % maxf(_air_ref-motor.feet.y,0.0)
	if convoy > 0 and riding_on == "air": where = "in the air off %d · %.1f m under the line" % [on_k+1,maxf(_air_ref-motor.feet.y,0.0)]
	var lines := PackedStringArray()
	if convoy > 0: lines.append("serpent   %d of %d (1 the lead)" % [on_k+1,serpents.size()])
	lines.append_array([
		"on        %s" % where,
		"over the ground %.2f m/s" % Vector2(over.x,over.z).length(),
		"on its back     %.2f m/s" % motor.speed(),
		"serpent         %.2f m/s" % serpent.speed(),
		"state     %s" % state(),
		("slope     %.0f°" % motor.steepness()) if motor.grounded else "slope     -",
		"surf      %.2f m/s%s · top %.2f m/s (SLIDE_TOP %.1f)" % [motor.speed() if motor.move == "slide" else 0.0,"  (surfing)" if motor.move == "slide" else "",slide_top,motor.slide_top],
		"falls     %d" % falls,
	])
	if convoy > 0:
		lines.append("string    %d in a row · best %d · %d gaps made" % [string,best_string,gaps])
		lines.append("peak      %.2f m/s on its back · %.2f over the ground (this string)" % [string_peak,string_peak_ground])
		if not last_gap.is_empty(): lines.append("last gap  %d → %d · left at %.2f m/s, landed at %.2f on its back" % [int(last_gap.from)+1,int(last_gap.to)+1,last_gap.left,last_gap.landed])
		lines.append("line      gap %.1f m · descents %.0f° · %.2f ms a frame (hulls %.2f; %d of %d live)" % [gap,descent,line_usec/1000.0,hulls_usec/1000.0,live_count,serpents.size()])
	lines.append(carve_line())
	lines.append("girth %.1f× · roll kept %.2f while ridden (now %.2f rad) · %s" % [girth,ride_roll,serpent.spring(RuneSerpent.S_BANK),serpent.mode])
	if long_chain > 0: lines.append("long chain %d · fastest %.2f m/s" % [long_chain,long_chain_top])
	_hud.text = "\n".join(lines)

func _hint_text() -> String:
	if convoy > 0: return "WASD run · Space jump · Shift/C crouch: on a slope surf, the stick carves; Space off its head: leap to the next · X twirl (more air) · T/pad Y the last gap again · 5 top of a descent · 1 neck · 2 mid-back · 3 tail · 4 the last one's tail · R start · F1 numbers · F2 feel · F3 carve · Esc mouse"
	return "WASD run · Space jump (on landing: pump) · Shift/C crouch: at a run slide, + Space long jump; on a slope (its back in the dive) surf · X twirl · 1 neck · 2 mid-back · 3 tail · 4 the tower (time the jump) · R start · F1 numbers · F2 feel · F3 carve · Esc mouse"

func _unhandled_input(event: InputEvent) -> void:
	# No recordings here: a replay can't put the serpent back where it was.
	if event is InputEventKey and (event as InputEventKey).keycode in [KEY_F5,KEY_F6,KEY_F7,KEY_F8]: return
	if convoy > 0 and not fading():
		var again: bool = event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y
		if event is InputEventKey and event.pressed and not event.echo and not _tuning():
			again = (event as InputEventKey).keycode == KEY_T
		if again:
			retry_gap()
			return
	super._unhandled_input(event)
