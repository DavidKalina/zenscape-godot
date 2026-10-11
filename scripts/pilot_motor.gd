extends RefCounted
## The pilot on foot, moved like a platformer's hero: the stick asks for a
## way and a pace (in the world, the camera's way already taken out), and
## the pilot turns to face it and runs up to speed, quick at a walk and
## wider at a run; thrown hard the other way at a run he skids to a stop
## first and turns on the spot. Let go, he slows to a stand.
##
## Jumps go as high as the button is held: let go on the way up and he
## falls sooner, and he falls faster than he rose. The arc is worked out
## exactly for each step's gravity (to the top, and past it), so the heights
## set are the heights reached at any frame rate. Pressed a moment before
## landing (BUFFER) the jump is kept for the touch; pressed a moment after
## running off a ledge (COYOTE) it still jumps. Jumped again within
## CHAIN_WINDOW of landing (the buffer before it counting too), it is the
## pump: higher (JUMPS), and every timed jump after it stays that high. In
## the air he keeps his run and steers only a little.
##
## Momentum: pace over his run (from a long jump, a slide, a kick, a slope)
## is not cut back to the run as he lands or steers. On the ground it bleeds
## away at CARRY_HOLD with the stick held on along his way, faster
## (CARRY_DECAY) with it pointing elsewhere; let go, he brakes as ever. In
## the air it is all kept.
##
## Crouching (`crouch` held on the ground) at a stand he stays where he
## stands (CROUCH_BRAKE); at a run (over LONG_PACE) he drops into a slide
## on his boots (move "slide", as the surf below) that runs on along the
## flat, slowing at SLIDE_RUNOUT and the air's SLIDE_AIR, not steered.
## Jumped crouched at a run or sliding on the flat, it is the long jump: low
## (LONG_HEIGHT), on its own lighter gravity, the hold of the button not
## cutting it, at his pace and never under LONG_SPEED. Long-jumped again
## within LONG_CHAIN of landing one (crouch held, Jump pressed on the touch
## or in the BUFFER before it) it adds LONG_ADD to his pace, up to LONG_TOP:
## a string of them, each timed, goes faster and further; late, the slide
## has eaten some pace and nothing is added.
##
## Walls (`wall`, or the ground's own rise where none is given): in the air,
## against one standing WALL_TALL over the feet, the stick held into it and
## not rising faster than WALL_RISE, he slides down it with a hand on it, no
## faster than WALL_SLIDE; the stick let go of or pulled away (WALL_LET), the
## wall ending or the ground reached, he leaves it. Jump on it, or just
## after touching one in the air (WALL_TOUCH), kicks him up (WALL_JUMP) and
## out (WALL_KICK), turned round, the stick not steering for WALL_LOCK, so he
## can kick up between two walls facing each other.
##
## The twirl: `twirl` pressed in the air (anywhere in it, at any moment)
## spins him round with his arms out, kicked up to at least TWIRL_RISE and
## then, for TWIRL_TIME, on a share of his gravity (TWIRL_GRAVITY) and
## falling no faster than TWIRL_FALL: a little more airtime to reach a ledge
## or fix a landing. His pace is kept through it, pushed on TWIRL_PUSH along
## the stick (never past TWIRL_TOP by it), and steered at TWIRL_STEER, so a
## twirl at the end of a long jump stretches it. With the stick held back
## against his way (TWIRL_BACK) it turns him round to it, his pace kept:
## twirled back towards a wall just kicked off (the kick's lock lifted),
## he comes back to it to slide and kick again, or to a ledge over it. Once an airtime; landing, taking hold of a ledge,
## or swimming gives it back (a wall kick doesn't: one twirl back to the
## wall, one more kick, then he falls away). Crouch does nothing in the air: held
## from the ground (for the long jump, or the slide), or pressed there, it
## is the slide on landing.
##
## The slide hop: in the air out of a slide (a long jump, a slide jump) the
## stick across his way bends his run round without losing it (HOP_TURN,
## radians a second, at full stick across) and adds to it (HOP_STRAFE, m/s²
## by the stick's share across), up to HOP_TOP: weaving left and right he
## builds speed. Landed crouched he slides, and the slide's drag eats his
## pace fast; hopped again within LONG_CHAIN of the touch (the long jump,
## or the slide jump on a slope) it is the chain, kept at his pace on the
## touch (the long jump's LONG_ADD on it, to LONG_TOP): a string of timed
## hops, weaving, runs past anything the ground gives on the flat.
##
## The wall run: in the air at WALLRUN_PACE or more, with a wall along his
## way (met at a glance: its face within WALLRUN_GLANCE of his run) and
## the stick not pulled off it, he runs along it (move "wallrun"): hopped
## up to WALLRUN_RISE, then for WALLRUN_TIME on a share of his gravity
## (WALLRUN_GRAVITY) and falling no faster than WALLRUN_FALL, his pace kept
## along the wall. The wall ending, the time up or the stick pulled away
## from it, he drops off; Jump kicks him off it, up (WALLRUN_JUMP) and out
## (WALLRUN_KICK) with his pace along it kept. Once an airtime, as the
## twirl: landing, taking hold of a ledge, or swimming gives it back. A hop
## out of the water never starts one.
##
## Slopes (the ground's own fall, `_gradient`, read from heights around the
## feet, so a step's edge is no slope): running up one steeper than
## SLOPE_SLOW he slows, to SLOPE_SLOWEST of his pace at SLIDE_AUTO. On one
## steeper than SLIDE_AUTO he can't stand: he boot-surfs down it (move
## "slide"), as he does on any steeper than SLIDE_FROM with `crouch` held
## (pressed there, or landed on it with it held). Surfing, standing on his
## boots, the slope pulls him down its fall line (SLIDE_PULL by the slope's
## sine, less SLIDE_DRAG and the air's SLIDE_AIR by his pace squared, so the
## steeper the faster he gains and the faster he can go), the stick steering
## across it (SLIDE_STEER) or braking against it (SLIDE_BRAKE), never faster
## than SLIDE_TOP. Onto flat ground (under SLIDE_END) he slides on, slowing
## at SLIDE_RUNOUT and the air's drag, running on again at his run's pace
## (held crouched, sliding to a crouch). Jump surfing on a slope, or
## uncrouched on the flat, is the slide jump: SLIDE_JUMP high with all the
## slide's pace; crouched on the flat it is the long jump.
##
## The side flip: Jump while skidding round (or SIDE_GRACE after it) flips
## him high (SIDE_FLIP, higher than the pump) the way the stick now points,
## slowly along (SIDE_SPEED), the button's hold not cutting it: up onto a
## ledge rather than across a gap.
##
## Every gain has its cap: nothing adds pace but a slope (to SLIDE_TOP), a
## timed long jump (to LONG_TOP), the twirl (to TWIRL_TOP, once an
## airtime) and the slide hop's weave (to HOP_TOP); no pace turns into
## height.
##
## Pressed again in the air on the way up, or falling from high enough
## (FLY_CLEAR), with no wall at hand, it asks to fly (`step` returns "fly").
##
## Ledges (`ledge`, a lip finder as scripts/pilot_ledge.gd's `find`): falling
## past a lip he faces, hands come down to it, he catches it; stepping off
## an edge carefully (under CATCH_PACE, or the stick let go or pulled back)
## he turns, lowers himself over it and hangs (pushed out over it at a run,
## he goes). Hanging, the stick along the lip shimmies him hand over hand,
## following its curve and turning to stay facing the wall, stopping where
## it bends too sharply, steps or ends; held towards the wall (CLIMB_HOLD) or
## Jump, he climbs up onto it; held away (DROP_HOLD) he lets go and falls.
## Only a lip with a top to stand on is caught (`_stand_on`): CLIMB_IN in
## from its edge, or the middle of a narrower top, with room for the body
## over it; so whatever he hangs from, he can climb.
##
## Walls are anything `wall` answers: it takes the feet, a way and a reach
## and gives back the way off a wall standing at least WALL_TALL over the
## feet within that reach (x, z), or Vector2.ZERO. Without one, the ground's
## own rise is the wall (`heightfield_wall`: ground over WALL_TALL above the
## feet WALL_PROBE ahead, its way off down the ground's slope).
##
## Ground is anything `ground` answers, a height for a point of the frame;
## running off ground that drops away by more than SNAP he falls. Moving
## through the world goes through `slide`, which takes the feet and a step
## and gives back where they come to, round whatever stands in the way. Both
## in one frame: the plate's terrain or an islet's.
##
## Water is anything `water` answers, a depth of water over the ground for a
## point of the frame (none: all dry). Measured on his body (about 1.1 m
## tall: the knees about 0.2 m up, the jacket's hem and hips about 0.4, the
## shoulders about 0.7): wading, he is slowed by the depth over his boots,
## past WADE_FROM, up to WADE_SLOW of his pace lost at SWIM_IN, chest deep;
## any deeper and he swims. Swimming he floats SWIM_DRAFT under the surface
## (his head and shoulders out), bobbing on a spring as he goes in, slower and
## floatier than on foot, drifting on as he turns; where it grows shallower
## than SWIM_OUT he stands and walks out. Jump while swimming hops him out of
## the water (SWIM_HOP), onto a bank or back in with a splash; that hop never
## asks to fly. Never drowning, never hurt.

## Speeds, metres a second, and how fast they are reached and lost.
const WALK := 2.4
const RUN := 4.8
const ACCEL := 17.0
const BRAKE := 18.0
const AIR_ACCEL := 6.0
## Radians a second he turns towards the stick: at a stand, at a full run,
## in the air.
const TURN := 16.0
const TURN_RUN := 7.0
const AIR_TURN := 4.0
## Thrown back against a run faster than this, he skids, braking at
## SKID_BRAKE: from a full run a slide of about 0.3 s and 0.6 m, long enough
## to read.
const SKID_SPEED := 3.4
const SKID_BRAKE := 15.0
## Gravity rising, the share more falling, and the share more rising with
## the button let go; the fastest fall.
const GRAVITY := 26.0
const FALL := 1.5
const CUT := 2.8
const TERMINAL := 18.0
## The jump's height and the pump's, metres.
const JUMPS := [0.8,1.5]
## Seconds after a landing a jump is the pump (a press up to BUFFER before
## the landing counts too).
const CHAIN_WINDOW := 0.3
const COYOTE := 0.1
const BUFFER := 0.15
## Ground falling away more than this under a step (plus the step's own
## run) is a ledge to fall from; ground rising more than STEP_UP in a step
## is a wall.
const SNAP := 0.3
const STEP_UP := 0.45
## Over this, metres above the ground, a press falling asks to fly.
const FLY_CLEAR := 1.6
## Carried pace over the run, bleeding away on the ground (m/s²): with the
## stick held on along his way (within about 25°), and without; and more
## (m/s² a m/s over the run), so a big carry (a slide hop chain's end) falls
## off fast and a small one lingers. Held on, from a 10 m/s landing about
## 1.2 s back to the run, from 13 m/s about 1.6 s; turned, about 0.5 s.
const CARRY_HOLD := 2.5
const CARRY_DECAY := 8.0
const CARRY_EXCESS := 0.8
## Crouching: how fast he stops crouched under LONG_PACE (m/s²). The long
## jump: the least pace (m/s) it, and the flat slide, are taken from; its
## height (m), its least pace along (m/s) and its gravity (m/s², rising and
## falling alike). Level, from a run, it goes
## LONG_SPEED*2*sqrt(2*LONG_HEIGHT/LONG_GRAVITY), 4.2 m (it was 3.3);
## onto a top level with the takeoff a little more, as a landing steps up
## onto a top up to STEP_UP over the feet. Chained: the seconds after a long
## jump's landing another is chained, the pace it adds (m/s) and the most
## it adds to (m/s): about 7.6, 9, 10.4, 11.8, 12 m/s down a string, 4.2 m
## a jump to 6.7.
const CROUCH_BRAKE := 7.0
const LONG_PACE := 3.0
const LONG_HEIGHT := 0.7
const LONG_SPEED := 7.6
const LONG_GRAVITY := 18.0
const LONG_CHAIN := 0.2
const LONG_ADD := 1.4
const LONG_TOP := 12.0
## Walls: the least height one stands over the feet to be slid down or
## kicked from, and how far ahead (m, from the feet) one is felt; the feet's
## least height over the ground to take hold; the stick's share into it that
## holds on; the fastest rise (m/s) it is taken at; a fall caught to at
## most WALL_CATCH (m/s) as the hand goes on, then gathering at WALL_GRAVITY
## (m/s²) up to the slide's fastest, WALL_SLIDE; seconds the stick may be
## off it before he lets go; seconds after touching one in the air a press
## still kicks off it.
const WALL_TALL := 1.2
const WALL_PROBE := 0.45
const WALL_CLEAR := 0.5
const WALL_HOLD := 0.3
const WALL_RISE := 1.5
const WALL_CATCH := 0.5
const WALL_GRAVITY := 8.0
const WALL_SLIDE := 1.8
const WALL_LET := 0.12
const WALL_TOUCH := 0.1
## The wall jump: its height (m), its pace out from the wall (m/s), seconds
## the stick does not steer after it. Between walls 2.8 m apart it gains
## about a metre a kick.
const WALL_JUMP := 1.4
const WALL_KICK := 5.2
const WALL_LOCK := 0.28
## The twirl: the least rise it kicks him to (m/s), its seconds, the share
## of gravity he rises and falls on through it, and its fastest fall (m/s).
## Pressed at a jump's top it gives about 0.4 s more in the air. Its push
## along the stick (m/s), the pace the push stops at (m/s; faster, he keeps
## his own) and its air steer (m/s²).
const TWIRL_RISE := 2.8
const TWIRL_TIME := 0.45
const TWIRL_GRAVITY := 0.5
const TWIRL_FALL := 2.0
const TWIRL_PUSH := 2.0
const TWIRL_TOP := 9.0
const TWIRL_STEER := 12.0
## The twirl turns him round to the stick held back against his way past
## this (the cosine between them: about 115° and more).
const TWIRL_BACK := -0.4
## The slide hop: its turn (rad/s) and its gain (m/s²) at full stick across
## his way, and the pace the gain stops at (m/s). Weaving a long jump's
## 0.56 s at full stick across gains about 1.7 m/s and turns about 70°.
const HOP_TURN := 2.2
const HOP_STRAFE := 3.0
const HOP_TOP := 13.0
## The wall run: the least pace (m/s) it starts at; how glancing the wall
## must be (the cosine between his way and its face's way out: under 0.6,
## within about 37° of running along it); how far beside him it is felt
## (m); the rise it starts with (m/s), its seconds, its share of gravity
## and fastest fall (m/s); its kick's height (m) and pace out (m/s). At a
## run's 4.8 m/s it goes about 3.4 m along.
const WALLRUN_PACE := 4.0
const WALLRUN_GLANCE := 0.6
const WALLRUN_REACH := 0.6
const WALLRUN_RISE := 2.0
const WALLRUN_TIME := 0.7
const WALLRUN_GRAVITY := 0.35
const WALLRUN_FALL := 2.0
const WALLRUN_JUMP := 1.1
const WALLRUN_KICK := 4.0
## Slopes, degrees: from SLOPE_SLOW up he runs up slower, to SLOPE_SLOWEST
## of his pace at SLIDE_AUTO, past which he can't stand and surfs down; from
## SLIDE_FROM a crouch surfs; under SLIDE_END is flat. Surfing: the pull
## down the fall line (m/s² on a sheer drop, by the slope's sine), the drag
## against it, the stick's steer across it and brake against it (m/s²), the
## fastest ever (m/s), the slowing on flat ground (m/s²), the air's drag
## (m/s² by the pace squared, on slopes and flat alike) and the pace under
## which a crouched surf stops (m/s); the slide jump's height (m). The air's
## drag gives each slope its own top: about 15.6 m/s on 32°, 16.3 on 35°,
## 19 on 50°, all under SLIDE_TOP (it was a flat 11 on any slope).
const SLOPE_SLOW := 22.0
const SLOPE_SLOWEST := 0.45
const SLIDE_AUTO := 44.0
const SLIDE_FROM := 10.0
const SLIDE_END := 6.0
const SLIDE_PULL := 18.0
const SLIDE_DRAG := 1.0
const SLIDE_STEER := 7.0
const SLIDE_BRAKE := 4.0
const SLIDE_TOP := 20.0
const SLIDE_RUNOUT := 2.4
const SLIDE_AIR := 0.035
const SLIDE_STOP := 0.8
const SLIDE_JUMP := 0.9
## The pace (m/s) at which a slide throws its fullest spray (the old top
## surf); faster surfs throw no more.
const SPRAY_FULL := 11.0
## The side flip: its height (m), its pace along (m/s), and the seconds
## after a skid it is still taken.
const SIDE_FLIP := 1.9
const SIDE_SPEED := 3.0
const SIDE_GRACE := 0.12
## How far either side of the feet the ground is read for its slope (m),
## near and further, and how far up and down it a slope too steep to stand
## on must go on.
const SLOPE_NEAR := 0.05
const SLOPE_PROBE := 0.2
const SLOPE_FAR := 1.0
## The ledge, as art/blender/pilot/pilot_build.py made the clips: hanging,
## the lip's top HANG_DROP over the feet and its edge HANG_OUT ahead; the
## climb (CLIMB_TIME s, Mario quick) ends stood CLIMB_IN in from the edge;
## the shimmy's pace, m/s along the lip.
const HANG_DROP := 0.825
const HANG_OUT := 0.22
const CLIMB_IN := 0.3
const CLIMB_TIME := 0.4
const SHIMMY := 0.7
## Seconds turning round on the edge before lowering over it, and the
## lowering (the climb played back, a little slower).
const CATCH_TURN := 0.15
const LOWER_TIME := 0.5
## Stepping off an edge under this pace (m/s), or pushing out over it less
## than CATCH_PUSH of the stick, he catches it.
const CATCH_PACE := 2.6
const CATCH_PUSH := 0.35
## Catching a lip in the air: looked for GRAB_REACH m ahead; the hands
## (HANG_DROP over the feet) within GRAB_LOW under it to GRAB_HIGH over it;
## facing it within acos(GRAB_FACING); not rising faster than GRAB_RISE m/s.
## The body is drawn onto the hang over GRAB_SNAP s.
const GRAB_REACH := 0.45
const GRAB_LOW := 0.25
const GRAB_HIGH := 0.35
const GRAB_FACING := 0.5
const GRAB_RISE := 1.0
const GRAB_SNAP := 0.1
## Hanging: seconds before a climb is taken (a press in them is kept for
## it); the stick's share towards or away that counts, and seconds it is
## held to climb or to let go; seconds
## after letting go before another catch; the shimmy's pick-up (m/s²), the
## turn following the lip (radians a second), the sharpest bend it follows
## (radians a metre) and the steepest step along it.
const HANG_SETTLE := 0.08
const PUSH := 0.5
const CLIMB_HOLD := 0.08
const DROP_HOLD := 0.12
const REGRAB := 0.4
const SHIMMY_ACCEL := 6.0
const HANG_TURN := 8.0
const CURL_MOST := 2.5
const SHIMMY_SLOPE := 1.0
## Water: the depth (m) over the boots from which a wade slows him, the
## share of his pace it takes at SWIM_IN; deeper than SWIM_IN (chest deep)
## at his feet he swims, shallower than SWIM_OUT he stands again. Swimming:
## the feet SWIM_DRAFT under the surface (the shoulders just out); his pace
## (m/s), pick-up and coast to a stop (m/s²) and turn (radians a second); the
## float's spring (Hz, damping) and the share of a fall's speed kept going
## in; the hop out (m).
const WADE_FROM := 0.08
const WADE_SLOW := 0.67
const SWIM_IN := 0.55
const SWIM_OUT := 0.45
const SWIM_DRAFT := 0.58
const SWIM := 1.2
const SWIM_ACCEL := 2.6
const SWIM_DRAG := 1.4
const SWIM_TURN := 3.2
const SWIM_SPRING := 1.1
const SWIM_DAMP := 0.6
const SWIM_ENTRY := 0.35
const SWIM_HOP := 0.9

## The feel, this motor's own: each starts as its constant above, which the
## game keeps; a study (studies/character_study.gd) may turn them live. The
## constants stay what other scripts read.
var walk := WALK
var run := RUN
var accel := ACCEL
var brake := BRAKE
var air_accel := AIR_ACCEL
var turn := TURN
var turn_run := TURN_RUN
var air_turn := AIR_TURN
var gravity := GRAVITY
var fall := FALL
var cut := CUT
var terminal := TERMINAL
var jumps: Array = JUMPS.duplicate()
var skid_speed := SKID_SPEED
var skid_brake := SKID_BRAKE
var coyote := COYOTE
var buffer := BUFFER
var chain_window := CHAIN_WINDOW
var carry_hold := CARRY_HOLD
var carry_decay := CARRY_DECAY
var carry_excess := CARRY_EXCESS
var long_pace := LONG_PACE
var long_height := LONG_HEIGHT
var long_speed := LONG_SPEED
var long_gravity := LONG_GRAVITY
var long_chain := LONG_CHAIN
var long_add := LONG_ADD
var long_top := LONG_TOP
var wall_slide := WALL_SLIDE
var wall_jump := WALL_JUMP
var wall_kick := WALL_KICK
var wall_lock := WALL_LOCK
var twirl_rise := TWIRL_RISE
var twirl_time := TWIRL_TIME
var twirl_gravity := TWIRL_GRAVITY
var twirl_push := TWIRL_PUSH
var twirl_top := TWIRL_TOP
var twirl_steer := TWIRL_STEER
var hop_turn := HOP_TURN
var wallrun_pace := WALLRUN_PACE
var wallrun_time := WALLRUN_TIME
var wallrun_gravity := WALLRUN_GRAVITY
var wallrun_rise := WALLRUN_RISE
var wallrun_jump := WALLRUN_JUMP
var wallrun_kick := WALLRUN_KICK
var hop_strafe := HOP_STRAFE
var hop_top := HOP_TOP
var slide_auto := SLIDE_AUTO
var slide_pull := SLIDE_PULL
var slide_top := SLIDE_TOP
var slide_runout := SLIDE_RUNOUT
var slide_air := SLIDE_AIR
var slide_jump := SLIDE_JUMP
var side_flip := SIDE_FLIP
var side_speed := SIDE_SPEED
var climb_time := CLIMB_TIME

## The feet, in the frame.
var feet := Vector3.ZERO
var velocity := Vector3.ZERO
## The way he faces: down -Z turned by `facing` about up.
var facing := 0.0
var grounded := true
var skidding := false
## The jump in the chain he is in (1 the jump, 2 the pump), 0 on the ground
## or in any other leap.
var chain := 0
## What he is doing beyond running and jumping: "" (nothing), "jump",
## "pump", "long" (the long jump), "kick" (off a wall), "wall" (sliding down
## one), "crouch", "twirl", "slide" (boot-surfing down a slope), "flip" (the
## side flip), "wallrun" (running along one).
var move := ""
## Held by the caller: the crouch button, and the twirl's.
var crouch := false
var twirl := false
## The ground's slope under the feet, its rise a metre (x, z), as last read
## standing on it.
var slope := Vector2.ZERO
## A wall's answer (see above), or none (the ground's rise).
var wall := Callable()
## Sliding down a wall: the way off it (x, z).
var wall_out := Vector2.ZERO
## The ground under the feet last step.
var ground_y := 0.0
## On a ledge: "" (not), "catch" (turning round on the edge), "lower"
## (lowering over it), "hang", "climb". `hold_t` is the climb's place in its
## clip, 0 hanging to 1 stood on top (the lowering runs it back); `shimmy`
## the pace along the lip, m/s to his right; `lip` the edge on its top's
## height and `lip_out` the way off it.
var hold := ""
var hold_t := 0.0
var shimmy := 0.0
var lip := Vector3.ZERO
var lip_out := Vector2.ZERO
var _hang_feet := Vector3.ZERO
var _correct := Vector3.ZERO
var _snap := Vector3.ZERO
var _hold_time := 0.0
var _toward := 0.0
var _away := 0.0
var _regrab := 0.0
var _last_chain := 0
var _since_land := 99.0
var _since_ground := 0.0
var _buffer := 0.0
var _held := false
var _jumped := false
## The arc's own: no cut for letting go (a long jump, a wall jump), and the
## long jump's gravity.
var _no_cut := false
var _light := false
## Walls: seconds since one was touched in the air and its way off; seconds
## the stick has been off the wall slid down; seconds left not steering.
var _wall_since := 99.0
var _wall_seen := Vector2.ZERO
var _wall_off := 0.0
var _lock := 0.0
## The twirl button last step; the twirl's seconds left, and whether this
## airtime's is spent; seconds left after a skid that a jump is the side
## flip; a press hanging, kept for the climb.
var _twirl_was := false
var _twirl := 0.0
var _twirled := false
## The wall run's seconds left, and whether this airtime's is spent.
var _wallrun := 0.0
var _wallran := false
var _skid_left := 0.0
var _hang_press := false
## In the air out of a slide (a long jump, a slide jump: the slide hop);
## landed from one (for the chain), and his pace on the touch.
var _hop_air := false
var _hop_landed := false
var _land_pace := 0.0
## Water (see above): its depth for a frame point, or none; swimming; the
## water over the feet (m, 0 dry) and its top (the frame's height, -INF dry).
var water := Callable()
var swimming := false
var wade := 0.0
var surface := -INF
var _from_water := false

## Stood at `at`, facing `towards`, moving `speed` the way it faces.
func reset(at: Vector3, towards: float, speed := 0.0) -> void:
	feet = at
	ground_y = at.y
	facing = towards
	var f := forward(towards)
	velocity = Vector3(f.x,0.0,f.y)*speed
	grounded = true
	skidding = false
	chain = 0
	move = ""
	wall_out = Vector2.ZERO
	_no_cut = false
	_light = false
	_wall_since = 99.0
	_wall_off = 0.0
	_lock = 0.0
	_last_chain = 0
	_since_land = 99.0
	_since_ground = 0.0
	_buffer = 0.0
	_jumped = false
	hold = ""
	hold_t = 0.0
	shimmy = 0.0
	_regrab = 0.0
	slope = Vector2.ZERO
	_twirl = 0.0
	_twirled = false
	_wallrun = 0.0
	_wallran = false
	_skid_left = 0.0
	_hang_press = false
	_hop_air = false
	_hop_landed = false
	_land_pace = 0.0
	swimming = false
	wade = 0.0
	surface = -INF
	_from_water = false

## Carried by what he stands on or hangs from, between steps (a moving
## body: studies/serpent_ride.gd's serpent): every place he keeps (the feet,
## a lip and his hang under it) moved by `by`, and every way he keeps (his
## facing, his pace, a lip's or a wall's way off, the slope's fall) turned
## `turn` radians about up, so he stays upright. Nothing else calls it, and
## his feel is untouched: the step after it runs as ever, on the ground as
## it is now.
func carry(by: Transform3D, turn: float) -> void:
	var was := feet
	feet = by*feet
	ground_y += feet.y-was.y
	if is_finite(surface): surface += feet.y-was.y
	lip = by*lip
	_hang_feet = by*_hang_feet
	_snap = _snap.rotated(Vector3.UP,turn)
	_correct = _correct.rotated(Vector3.UP,turn)
	velocity = velocity.rotated(Vector3.UP,turn)
	facing = wrapf(facing+turn,-PI,PI)
	lip_out = _turned(lip_out,turn)
	wall_out = _turned(wall_out,turn)
	_wall_seen = _turned(_wall_seen,turn)
	slope = _turned(slope,turn)

## `way` (x, z) turned `turn` radians about up.
static func _turned(way: Vector2, turn: float) -> Vector2:
	var v := Vector3(way.x,0.0,way.y).rotated(Vector3.UP,turn)
	return Vector2(v.x,v.z)

## The way `towards` faces, in the frame's plane (x, z).
static func forward(towards: float) -> Vector2:
	return Vector2(-sin(towards),-cos(towards))

## The facing that looks along `way` (x, z).
static func facing_of(way: Vector2) -> float:
	return atan2(-way.x,-way.y)

func speed() -> float:
	return Vector2(velocity.x,velocity.z).length()

## One step. `want` is the way asked, at most 1 long; `top` the pace it
## asks for at full stick; `jump` whether the jump is held (and `crouch`,
## set before, whether the crouch is). `ground` takes a point (x, z) and
## gives its height; `slide` takes the feet and a step (x, z) and gives back
## the feet moved. Returns what happened: "jumped" (1 a jump, 2 the pump),
## with "long", "wall_jump", "slide_jump" or "side_flip" for those, "twirl",
## "slide" (true onto a surf, false off it), "landed" (how hard, metres a
## second), "fly", "wall" (true onto a wall, false off it); on a ledge
## (`ledge`: a point (x, z) and a height near the lip, giving {"at", "out"}
## or {}), "grabbed" ("air" or "step"), "hung", "climbed", "let_go",
## "stopped" (a shimmy that can't go on); in water (`water`), "swam" (gone in
## deep enough to swim, how hard he fell in, m/s), "stood" (out of a swim
## onto his feet), "hopped" (out of the water).
func step(delta: float, want: Vector2, top: float, jump: bool, ground: Callable, slide: Callable, ledge := Callable()) -> Dictionary:
	var out := {}
	if want.length() > 1.0: want = want.normalized()
	var pressed := jump and not _held
	_held = jump
	var twirl_pressed := twirl and not _twirl_was
	_twirl_was = twirl
	_regrab = maxf(0.0,_regrab-delta)
	if hold != "": return _hold_step(delta,want,pressed,ground,slide,ledge)
	if swimming: return _swim_step(delta,want,pressed,ground,slide)
	_wet_at(Vector2(feet.x,feet.z),ground)
	if grounded and wade > SWIM_IN:
		# Waded in chest deep: afloat.
		_float_in(0.0,out)
		return _swim_step(delta,want,false,ground,slide,out)
	# Wading, slowed by the water over the boots.
	if grounded: top *= 1.0-WADE_SLOW*clampf((wade-WADE_FROM)/(SWIM_IN-WADE_FROM),0.0,1.0)
	_buffer = buffer if pressed else maxf(0.0,_buffer-delta)
	_since_land += delta
	_wall_since += delta
	_lock = maxf(0.0,_lock-delta)
	if grounded: _since_ground = 0.0
	else: _since_ground += delta
	if _since_land > chain_window: _last_chain = 0
	var crouched := grounded and crouch and wade < SWIM_IN*0.5
	var surfing := false
	var surfed := move == "slide"
	if grounded:
		slope = _gradient(ground,Vector2(feet.x,feet.z))
		surfing = _surfing(crouched,ground)
		move = "slide" if surfing else ("crouch" if crouched else "")
		_skid_left = SIDE_GRACE if skidding else maxf(0.0,_skid_left-delta)
	var h := Vector2(velocity.x,velocity.z)
	if grounded:
		if surfing: h = _surf(h,want,top,delta)
		elif crouched: h = _crouch_slide(h,want,delta)
		else: h = _run(h,want,top,delta)
		surfing = move == "slide"
		if surfing != surfed: out["slide"] = surfing
	elif move == "wallrun": pass
	elif move != "wall" and _hop_air and _lock <= 0.0: h = _strafe(h,want,top,delta,twirl_steer if move == "twirl" else air_accel)
	elif move != "wall": h = _steer(h,Vector2.ZERO if _lock > 0.0 else want,side_speed if move == "flip" else top,delta,twirl_steer if move == "twirl" else air_accel)
	# The jump: from the ground, or just off it; out of a skid, the side flip;
	# surfing, the slide jump; from a crouch at a run, the long jump; off a
	# wall.
	if _buffer > 0.0 and (grounded or (_since_ground < coyote and not _jumped)):
		if grounded and (skidding or _skid_left > 0.0) and not crouched and not surfing:
			var way := want.normalized() if want.length() > 0.2 else (-h.normalized() if h.length() > 0.1 else forward(facing))
			chain = 0
			move = "flip"
			_light = false
			_no_cut = true
			velocity.y = sqrt(2.0*gravity*side_flip)
			h = way*side_speed
			facing = facing_of(way)
			_skid_left = 0.0
			_hop_air = false
			out["side_flip"] = true
			out["jumped"] = 1
		elif crouched and h.length() >= long_pace and steepness() < SLIDE_FROM:
			# Chained on the touch of the last, at its pace and faster; else
			# at his pace.
			var pace := maxf(long_speed,h.length())
			if _chained(): pace = maxf(maxf(pace,_land_pace),minf(_land_pace+long_add,long_top))
			chain = 0
			move = "long"
			_light = true
			_no_cut = true
			_hop_air = true
			velocity.y = sqrt(2.0*long_gravity*long_height)
			h = h.normalized()*pace
			facing = facing_of(h)
			if surfing: out["slide"] = false
			out["long"] = true
			out["jumped"] = 1
		elif surfing:
			chain = 1
			move = "jump"
			_light = false
			_no_cut = false
			if _chained() and h.length() > 0.3: h = h.normalized()*maxf(h.length(),_land_pace)
			_hop_air = true
			velocity.y = sqrt(2.0*gravity*slide_jump)
			if h.length() > 0.3: facing = facing_of(h)
			out["slide"] = false
			out["slide_jump"] = true
			out["jumped"] = 1
		else:
			_hop_air = false
			chain = mini(_last_chain+1,jumps.size()) if _last_chain > 0 else 1
			move = "pump" if chain > 1 else "jump"
			_light = false
			_no_cut = false
			velocity.y = sqrt(2.0*gravity*float(jumps[chain-1]))
			out["jumped"] = chain
		grounded = false
		skidding = false
		_jumped = true
		_buffer = 0.0
	elif _buffer > 0.0 and not grounded and move == "wallrun":
		h = _wallrun_kick(h,out)
	elif _buffer > 0.0 and not grounded and (move == "wall" or _wall_since <= WALL_TOUCH):
		h = _kick_off(out)
	elif pressed and not grounded and not _from_water and (velocity.y > 0.0 or feet.y-ground_y > FLY_CLEAR) \
			and _wall_near(want,h,ground,WALL_PROBE+0.8) == Vector2.ZERO:
		_buffer = 0.0
		out["fly"] = true
	# The twirl: its button pressed anywhere in the air, once an airtime.
	if twirl_pressed and not grounded and not _twirled and move != "wall":
		_twirled = true
		_twirl = twirl_time
		move = "twirl"
		_light = false
		_no_cut = true
		velocity.y = maxf(velocity.y,twirl_rise)
		# The stick back against his way: turned round to it, his pace
		# kept (back to a wall just kicked off, the kick's lock lifted).
		# Pushed on along the stick (or the way he goes), his own pace kept
		# past TWIRL_TOP.
		var on := want.normalized() if want.length() > 0.2 else (h.normalized() if h.length() > 0.3 else forward(facing))
		var pace := h.length()
		if want.length() > 0.2 and pace > 0.3 and h.normalized().dot(on) < TWIRL_BACK: h = on*pace
		h = (h+on*twirl_push).limit_length(maxf(pace,twirl_top))
		_lock = 0.0
		if h.length() > 0.3: facing = facing_of(h)
		out["twirl"] = true
	# The wall run: begun along a wall met at a glance, or run on.
	if not grounded:
		if move == "wallrun": h = _wallrun_step(delta,want,h,ground,out)
		elif not _wallran and move != "wall" and move != "flip": h = _wallrun_start(want,h,ground,out)
	var moved: Vector3 = slide.call(feet,h*delta)
	var under: float = ground.call(Vector2(moved.x,moved.z))
	if grounded and under > feet.y+STEP_UP:
		# A wall: stood against it.
		h = Vector2.ZERO
		moved = feet
		under = ground.call(Vector2(feet.x,feet.z))
	if grounded:
		# Down a slope the ground falls away faster than the run goes.
		if under < feet.y-SNAP-h.length()*delta*maxf(1.0,slope.length()*1.3):
			if ledge.is_valid() and not crouched and not surfing and _careful(h,want) and _catch(ledge,ground,slide):
				out["grabbed"] = "step"
				return out
			# Off a ledge: falling, the run kept.
			if surfing: out["slide"] = false
			grounded = false
			_jumped = false
			_light = false
			_no_cut = false
			move = ""
			velocity.y = 0.0
			feet = Vector3(moved.x,feet.y,moved.z)
		else:
			feet = Vector3(moved.x,under,moved.z)
			ground_y = under
	else:
		if _twirl > 0.0:
			_twirl = maxf(0.0,_twirl-delta)
			if _twirl <= 0.0 and move == "twirl": move = ""
		var going := h
		if under > feet.y+STEP_UP:
			# A wall in the air: stopped against it.
			h = Vector2.ZERO
			under = ground.call(Vector2(feet.x,feet.z))
			moved = feet
		if move != "wallrun": h = _on_wall(delta,want,h,going,ground,under,out)
		if move == "wall":
			moved = feet
			under = ground.call(Vector2(feet.x,feet.z))
		var y := feet.y+_arc(delta,jump)
		ground_y = under
		var deep := _depth(Vector2(moved.x,moved.z))
		if deep > SWIM_IN and is_finite(under) and velocity.y <= 0.0 and y <= under+deep-SWIM_DRAFT:
			# Fallen into deep water: in with a splash, afloat.
			feet = Vector3(moved.x,y,moved.z)
			velocity.x = h.x
			velocity.z = h.y
			_float_in(-velocity.y,out)
			velocity.y *= SWIM_ENTRY
			_wet_at(Vector2(feet.x,feet.z),ground)
			return out
		if y <= under and velocity.y <= 0.0:
			out["landed"] = -velocity.y
			if move == "wall": out["wall"] = false
			if move == "wallrun": out["wallrun"] = false
			y = under
			grounded = true
			velocity.y = 0.0
			_last_chain = chain
			_hop_landed = _hop_air
			_hop_air = false
			_land_pace = h.length()
			chain = 0
			move = ""
			_light = false
			_no_cut = false
			_lock = 0.0
			_since_land = 0.0
			_jumped = false
			_from_water = false
			_twirl = 0.0
			_twirled = false
			_wallrun = 0.0
			_wallran = false
		elif y < under:
			y = under
		feet = Vector3(moved.x,y,moved.z)
		if not grounded and ledge.is_valid() and _grab(ledge,ground,slide):
			if move == "wall": out["wall"] = false
			out["grabbed"] = "air"
			return out
	velocity.x = h.x
	velocity.z = h.y
	return out

## The rise or the fall over `delta` (m, up), velocity.y carried on: worked
## out exactly for each part of the step's own gravity (rising, then past
## the top falling; the long jump's lighter one throughout; a wall slide's
## gentle one, to its pace; a twirl's, to its slow fall), so a jump peaks
## at its height at any frame rate.
func _arc(delta: float, jump: bool) -> float:
	var dy := 0.0
	var left := delta
	for i in range(4):
		if left <= 0.0: break
		var v := velocity.y
		var low := -wall_slide if move == "wall" else (-TWIRL_FALL if move == "twirl" else (-WALLRUN_FALL if move == "wallrun" else -terminal))
		if v < low:
			# Faster down than it may go: held to it.
			velocity.y = low
			continue
		var g := gravity
		if move == "wall": g = WALL_GRAVITY
		elif move == "twirl": g *= twirl_gravity
		elif move == "wallrun": g *= wallrun_gravity
		elif _light: g = long_gravity
		elif v <= 0.0: g *= fall
		elif not jump and not _no_cut: g *= cut
		var t := left
		if v > 0.0: t = minf(t,v/g)
		if v-g*t < low: t = minf(t,(v-low)/g)
		dy += v*t-0.5*g*t*t
		velocity.y = v-g*t
		left -= t
		if velocity.y <= low+1e-6:
			velocity.y = maxf(velocity.y,low)
			dy += velocity.y*left
			left = 0.0
	return dy

## A wall beside him along his way, met at a glance, fast enough and the
## stick not pulled off it: the wall run begun, his run turned along it.
## The run's new pace.
func _wallrun_start(want: Vector2, h: Vector2, ground: Callable, out: Dictionary) -> Vector2:
	var pace := h.length()
	if pace < wallrun_pace or _from_water or feet.y-ground_y < WALL_CLEAR or velocity.y < -WALLRUN_FALL*2.0: return h
	var way := h/pace
	for side: float in [1.0,-1.0]:
		var beside := Vector2(-way.y,way.x)*side
		# Felt to the side, then ahead and to the side, so a wall met at a
		# glance is found.
		var n := _wall_at(beside,ground,WALLRUN_REACH)
		if n == Vector2.ZERO: n = _wall_at((beside+way).normalized(),ground,WALLRUN_REACH)
		if n == Vector2.ZERO or absf(way.dot(n)) > WALLRUN_GLANCE or n.dot(beside) > -0.3: continue
		if want.length() > 0.2 and want.normalized().dot(n) > 0.5: continue
		var along := (way-n*way.dot(n)).normalized()
		move = "wallrun"
		wall_out = n
		chain = 0
		_wallran = true
		_wallrun = wallrun_time
		_twirl = 0.0
		_light = false
		_no_cut = true
		_hop_air = false
		velocity.y = maxf(velocity.y,wallrun_rise)
		facing = facing_of(along)
		out["wallrun"] = true
		return along*pace
	return h

## Running along a wall: kept to it, his pace along it; off it as the time
## runs out, the wall ends, or the stick pulls away. The run's new pace.
func _wallrun_step(delta: float, want: Vector2, h: Vector2, ground: Callable, out: Dictionary) -> Vector2:
	_wallrun -= delta
	var n := _wall_at(-wall_out,ground,WALLRUN_REACH)
	var away := want.length() > 0.2 and want.normalized().dot(wall_out) > 0.7
	if n == Vector2.ZERO or _wallrun <= 0.0 or away:
		move = ""
		_no_cut = false
		out["wallrun"] = false
		return h+wall_out*0.6
	wall_out = n
	var along := h-n*h.dot(n)
	if along.length() > 0.3: facing = rotate_toward(facing,facing_of(along),TURN*delta)
	return along.normalized()*h.length() if along.length() > 1e-4 else h

## Jumped off a wall run: up and out, his pace along the wall kept. The
## run's new pace.
func _wallrun_kick(h: Vector2, out: Dictionary) -> Vector2:
	out["wallrun"] = false
	move = "kick"
	chain = 0
	_light = false
	_no_cut = true
	_jumped = true
	_buffer = 0.0
	_wallrun = 0.0
	_lock = wall_lock*0.5
	velocity.y = sqrt(2.0*gravity*wallrun_jump)
	h += wall_out*wallrun_kick
	facing = facing_of(h)
	out["jumped"] = 1
	out["wall_jump"] = true
	out["wallrun_jump"] = true
	return h

## Off a wall (slid down, or just touched): up and out, turned round, the
## stick not steering a while. The run's new pace.
func _kick_off(out: Dictionary) -> Vector2:
	var away := wall_out if move == "wall" else _wall_seen
	if move == "wall": out["wall"] = false
	move = "kick"
	chain = 0
	_light = false
	_no_cut = true
	_jumped = true
	_buffer = 0.0
	_wall_since = 99.0
	_lock = wall_lock
	_twirl = 0.0
	_hop_air = false
	velocity.y = sqrt(2.0*gravity*wall_jump)
	facing = facing_of(away)
	out["jumped"] = 1
	out["wall_jump"] = true
	return away*wall_kick

## The way off a tall wall within `reach` of the feet, the way looked being
## the stick's (pushed; the run's while it does not steer), else the run's,
## else the facing; Vector2.ZERO if none.
func _wall_near(want: Vector2, h: Vector2, ground: Callable, reach := WALL_PROBE) -> Vector2:
	var way := forward(facing)
	if _lock > 0.0 and h.length() > 0.5: way = h.normalized()
	elif want.length() > WALL_HOLD: way = want.normalized()
	elif h.length() > 0.5: way = h.normalized()
	var n := _wall_at(way,ground,reach)
	return n if n.dot(way) < -0.3 else Vector2.ZERO

## The way off a tall wall `reach` along `way` from the feet: `wall`'s
## answer, or the ground's rise.
func _wall_at(way: Vector2, ground: Callable, reach: float) -> Vector2:
	if wall.is_valid(): return wall.call(feet,way,reach)
	return heightfield_wall(ground,feet,way,reach)

## A wall from heights alone: the ground `reach` along `way` from `at`'s
## feet standing over WALL_TALL above them; its way off, down the ground's
## slope there, read at its edge (walked back towards the feet from deep
## inside it, where the top is flat), or the way back along `way` where
## the slope is still flat or falls away from it.
static func heightfield_wall(ground: Callable, at: Vector3, way: Vector2, reach: float) -> Vector2:
	var p := Vector2(at.x,at.z)+way*reach
	var h := float(ground.call(p))
	if not is_finite(h) or h < at.y+WALL_TALL: return Vector2.ZERO
	for k in range(12):
		var back := p-way*reach/12.0
		var under := float(ground.call(back))
		if not is_finite(under) or under < at.y+WALL_TALL: break
		p = back
	var heights := []
	for d: Vector2 in [Vector2(0.15,0.0),Vector2(-0.15,0.0),Vector2(0.0,0.15),Vector2(0.0,-0.15)]:
		var s := float(ground.call(p+d))
		heights.append(s if is_finite(s) else at.y)
	var slope := Vector2(heights[0]-heights[1],heights[2]-heights[3])
	if slope.length() < 0.01 or slope.normalized().dot(way) <= 0.0: return -way
	return -slope.normalized()

## In the air by a wall: touched (for a kick), taken hold of and slid down,
## or let go of. `going` is the run's pace before a wall stopped it, `h`
## after. The run's pace (none on the wall, pressed to it).
func _on_wall(delta: float, want: Vector2, h: Vector2, going: Vector2, ground: Callable, under: float, out: Dictionary) -> Vector2:
	if move == "wall":
		var still := _wall_at(-wall_out,ground,WALL_PROBE)
		var into := want.dot(-wall_out)
		_wall_off = _wall_off+delta if into < WALL_HOLD*0.5 else 0.0
		if still == Vector2.ZERO or _wall_off >= WALL_LET or feet.y-under < 0.05:
			# Let go of, or run out: dropping off it, a touch out.
			move = ""
			out["wall"] = false
			_wall_since = 0.0 if still != Vector2.ZERO else 99.0
			return wall_out*0.6
		wall_out = still
		facing = rotate_toward(facing,facing_of(-wall_out),TURN*delta)
		return Vector2.ZERO
	var n := _wall_near(want,going,ground)
	if n == Vector2.ZERO: return h
	_wall_since = 0.0
	_wall_seen = n
	var kicked := _lock > 0.0 and going.dot(-n) > 1.0
	if (want.dot(-n) > WALL_HOLD or kicked) and velocity.y < WALL_RISE and feet.y-under > WALL_CLEAR:
		# Arriving from a kick, a beat longer to turn the stick round.
		move = "wall"
		wall_out = n
		chain = 0
		_twirl = 0.0
		velocity.y = maxf(velocity.y,-WALL_CATCH)
		_light = false
		_lock = 0.0
		_wall_off = -WALL_LET if kicked else 0.0
		out["wall"] = true
		return Vector2.ZERO
	return h

## Whether he is on a ledge (catching, hanging, climbing).
func on_ledge() -> bool:
	return hold != ""

## Where the drawn body's origin goes (scripts/pilot_figure.gd): the feet,
## but lowering and climbing the hang's, carried over to where the climb
## really ends as it goes, as the clip moves the body itself.
func origin() -> Vector3:
	return _hang_feet+_correct*hold_t if hold == "lower" or hold == "climb" else feet

## The feet climbing or lowering: from the hang to the top along the clip's
## way, about.
func _climbing_feet() -> Vector3:
	return origin()+(_top_of(_hang_feet)-_hang_feet)*smoothstep(0.0,1.0,hold_t)

## Going over an edge at `h` (m/s, x z), the stick at `want`: carefully?
func _careful(h: Vector2, want: Vector2) -> bool:
	if h.length() <= CATCH_PACE: return true
	return want.dot(h.normalized()) <= CATCH_PUSH

## Stepping off the lip at the feet: turned round to face it, to lower over
## it. False if there is no lip there with room to hang under.
func _catch(ledge: Callable, ground: Callable, slide: Callable) -> bool:
	if _regrab > 0.0: return false
	var found: Dictionary = ledge.call(Vector2(feet.x,feet.z),feet.y)
	if found.is_empty() or absf(found.at.y-feet.y) > SNAP+0.1: return false
	if not _room_under(found,ground) or _deep_under(found): return false
	if not _stand_on(found,ground,slide).is_finite(): return false
	lip = found.at
	lip_out = found.out
	hold = "catch"
	_hold_time = 0.0
	facing = facing_of(-lip_out)
	_still()
	return true

## Falling past a lip ahead, the hands coming down to it: caught, if there
## is room to hang under it and to climb onto it. Looked for at arm's reach,
## and nearer (a top too narrow to find past its edge).
func _grab(ledge: Callable, ground: Callable, slide: Callable) -> bool:
	if _regrab > 0.0 or velocity.y > GRAB_RISE: return false
	var f := forward(facing)
	var at := Vector2(feet.x,feet.z)
	for reach: float in [GRAB_REACH,HANG_OUT]:
		var found: Dictionary = ledge.call(at+f*reach,feet.y+HANG_DROP)
		if found.is_empty() or not _grabbable(found,at,f,ground,slide): continue
		var was := feet
		_hang_on(found)
		_snap = was-feet
		feet = was
		return true
	return false

## Whether the lip `found` is in reach of the hands of feet at `at` facing
## `f`, faced, with room to hang under it and to climb onto it.
func _grabbable(found: Dictionary, at: Vector2, f: Vector2, ground: Callable, slide: Callable) -> bool:
	var hands: float = found.at.y-feet.y-HANG_DROP
	if hands < -GRAB_LOW or hands > GRAB_HIGH: return false
	var out_way: Vector2 = found.out
	if f.dot(-out_way) < GRAB_FACING: return false
	var off := (at-Vector2(found.at.x,found.at.z)).dot(out_way)
	if off < -0.15 or off > GRAB_REACH+0.15: return false
	# Only a lip in reach of the hands, not one round a corner.
	var hang := Vector2(found.at.x,found.at.z)+out_way*HANG_OUT
	if hang.distance_to(at) > GRAB_REACH: return false
	if not _room_under(found,ground) or _deep_under(found): return false
	return _stand_on(found,ground,slide).is_finite()

## Whether a body hangs under `found` clear of the ground below it.
func _room_under(found: Dictionary, ground: Callable) -> bool:
	var hang := Vector2(found.at.x,found.at.z)+(found.out as Vector2)*HANG_OUT
	return float(ground.call(hang)) < found.at.y-HANG_DROP*0.8

## Whether deep water stands under `found`'s hang: he goes in, not over.
func _deep_under(found: Dictionary) -> bool:
	return _depth(Vector2(found.at.x,found.at.z)+(found.out as Vector2)*HANG_OUT) > SWIM_IN

## Hanging from `found`.
func _hang_on(found: Dictionary) -> void:
	lip = found.at
	lip_out = found.out
	hold = "hang"
	hold_t = 0.0
	_hold_time = 0.0
	_toward = 0.0
	_away = 0.0
	_snap = Vector3.ZERO
	facing = facing_of(-lip_out)
	_still()
	feet = _hang_at()

## Where the feet hang under the lip.
func _hang_at() -> Vector3:
	return Vector3(lip.x+lip_out.x*HANG_OUT,lip.y-HANG_DROP,lip.z+lip_out.y*HANG_OUT)

## Where the climb's clip stands him, from the hang at `hang`.
func _top_of(hang: Vector3) -> Vector3:
	return hang+Vector3(-lip_out.x,0.0,-lip_out.y)*(HANG_OUT+CLIMB_IN)+Vector3.UP*HANG_DROP

func _still() -> void:
	velocity = Vector3.ZERO
	grounded = false
	skidding = false
	chain = 0
	move = ""
	shimmy = 0.0
	_twirl = 0.0
	_twirled = false
	_wallrun = 0.0
	_wallran = false
	_hang_press = false
	_hop_air = false

## One step on a ledge.
func _hold_step(delta: float, want: Vector2, pressed: bool, ground: Callable, slide: Callable, ledge: Callable) -> Dictionary:
	var out := {}
	_hold_time += delta
	match hold:
		"catch":
			if _hold_time >= CATCH_TURN:
				# Lowered by the climb played back, from where he stands.
				_hang_feet = _hang_at()
				_correct = feet-_top_of(_hang_feet)
				hold = "lower"
				hold_t = 1.0
				feet = _climbing_feet()
		"lower":
			hold_t = maxf(0.0,hold_t-delta/LOWER_TIME)
			feet = _climbing_feet()
			if hold_t <= 0.0:
				hold = "hang"
				_hold_time = 0.0
				_toward = 0.0
				_away = 0.0
				out["hung"] = true
		"climb":
			hold_t = minf(1.0,hold_t+delta/climb_time)
			feet = _climbing_feet()
			if hold_t >= 1.0:
				hold = ""
				grounded = true
				ground_y = feet.y
				facing = facing_of(-lip_out)
				velocity = Vector3.ZERO
				_since_land = 99.0
				_jumped = false
				out["climbed"] = true
		"hang":
			_hang_step(delta,want,pressed,ground,slide,ledge,out)
	return out

func _hang_step(delta: float, want: Vector2, pressed: bool, ground: Callable, slide: Callable, ledge: Callable, out: Dictionary) -> void:
	var toward := -lip_out
	var right := Vector2(-toward.y,toward.x)
	var along := want.dot(right)
	var push := want.dot(toward)
	_toward = _toward+delta if push > PUSH and absf(along) < push else 0.0
	_away = _away+delta if -push > PUSH and absf(along) < -push else 0.0
	if pressed: _hang_press = true
	if _hold_time >= HANG_SETTLE and (_hang_press or _toward >= CLIMB_HOLD) and _climb(ground,slide):
		return
	_hang_press = _hang_press and _hold_time < HANG_SETTLE
	if _away >= DROP_HOLD:
		# Let go: falling, a touch out from the wall.
		hold = ""
		grounded = false
		velocity = Vector3(lip_out.x,0.0,lip_out.y)*0.6
		_regrab = REGRAB
		_jumped = true
		_since_ground = coyote
		out["let_go"] = true
		return
	var goal := 0.0
	if absf(along) > 0.3 and absf(along) >= absf(push)*0.8: goal = signf(along)*SHIMMY*minf(absf(along)/0.9,1.0)
	shimmy = move_toward(shimmy,goal,SHIMMY_ACCEL*delta)
	var go := right*shimmy*delta
	if go.length() > 0.0001 and ledge.is_valid():
		var next := Vector2(lip.x,lip.z)+go
		var found: Dictionary = ledge.call(next,lip.y)
		var ok := not found.is_empty()
		if ok:
			var to := Vector2(found.at.x,found.at.z)
			var moved := to.distance_to(Vector2(lip.x,lip.z))
			var bend := absf((found.out as Vector2).angle_to(lip_out))
			ok = to.distance_to(next) < 0.05 and moved > 0.0 and moved < go.length()*2.0+0.005 and bend/maxf(moved,0.01) < CURL_MOST 				and absf(float(found.at.y)-lip.y)/maxf(moved,0.01) < SHIMMY_SLOPE and _room_under(found,ground)
		if ok:
			lip = found.at
			lip_out = found.out
		else:
			shimmy = 0.0
			out["stopped"] = true
	facing = rotate_toward(facing,facing_of(-lip_out),HANG_TURN*delta)
	var r := Vector2(lip_out.y,-lip_out.x)
	velocity = Vector3(r.x,0.0,r.y)*shimmy
	# Drawn in from where he caught it.
	_snap = _snap.lerp(Vector3.ZERO,1.0-exp(-delta/(GRAB_SNAP*0.35)))
	feet = _hang_at()+_snap

## Up onto the lip, if there is room to stand on it.
func _climb(ground: Callable, slide: Callable) -> bool:
	var stand := _stand_on({"at":lip,"out":lip_out},ground,slide)
	if not stand.is_finite(): return false
	_hang_feet = _hang_at()
	_correct = stand-_top_of(_hang_feet)
	hold = "climb"
	hold_t = 0.0
	shimmy = 0.0
	_hang_press = false
	velocity = Vector3.ZERO
	_snap = Vector3.ZERO
	return true

## Where a climb onto `found` stands him: CLIMB_IN in from its edge, or the
## middle of a top narrower than twice that (a beam), where the top's height
## is within 0.5 m of the lip's and the body goes in over the edge to it;
## Vector3.INF if there is no such place. The ground is looked at as from
## the top (the feet held at the lip's height while it is asked: a ground
## answered from the feet, as scripts/pilot_physics_ground.gd's, would see
## under a bridge's deck from a hang under it).
func _stand_on(found: Dictionary, ground: Callable, slide: Callable) -> Vector3:
	var edge := Vector2(found.at.x,found.at.z)
	var out_way: Vector2 = found.out
	var y: float = found.at.y
	var was := feet
	feet.y = y
	var deep := CLIMB_IN*2.0
	for k in range(1,7):
		var d := CLIMB_IN*2.0*k/6.0
		var h := float(ground.call(edge-out_way*d))
		if not is_finite(h) or absf(h-y) > 0.3:
			deep = d-CLIMB_IN/6.0
			break
	var stand := edge-out_way*minf(CLIMB_IN,deep*0.5)
	var h := float(ground.call(stand))
	var on := edge-out_way*0.05
	var reached: Vector3 = slide.call(Vector3(on.x,y,on.y),stand-on)
	feet = was
	if deep < 0.15 or not is_finite(h) or absf(h-y) > 0.5: return Vector3.INF
	if Vector2(reached.x,reached.z).distance_to(stand) > 0.1: return Vector3.INF
	return Vector3(stand.x,h,stand.y)

## The water's depth at a frame point (0 without `water`).
func _depth(p: Vector2) -> float:
	if not water.is_valid(): return 0.0
	var d := float(water.call(p))
	return d if is_finite(d) and d > 0.0 else 0.0

## The water at frame point `p` (the feet's place): its top and its depth
## over the feet.
func _wet_at(p: Vector2, ground: Callable) -> void:
	var d := _depth(p)
	if d <= 0.0:
		wade = 0.0
		surface = -INF
		return
	surface = float(ground.call(p))+d
	wade = maxf(0.0,surface-feet.y) if is_finite(surface) else 0.0

## Into a swim, coming in at `hard` m/s.
func _float_in(hard: float, out: Dictionary) -> void:
	swimming = true
	grounded = false
	skidding = false
	chain = 0
	move = ""
	_twirl = 0.0
	_twirled = false
	_wallrun = 0.0
	_wallran = false
	_hop_air = false
	_jumped = false
	_from_water = false
	_buffer = 0.0
	out["swam"] = hard

## One step afloat: the stick paddles him its way, slower and floatier than
## on foot, his way drifting after his turn; the float bobs him to
## SWIM_DRAFT under the surface on its spring. Shallow enough, he stands;
## Jump hops him out.
func _swim_step(delta: float, want: Vector2, pressed: bool, ground: Callable, slide: Callable, out := {}) -> Dictionary:
	var h := Vector2(velocity.x,velocity.z)
	if want != Vector2.ZERO:
		var way := want.normalized()
		facing = rotate_toward(facing,facing_of(way),SWIM_TURN*delta)
		var f := forward(facing)
		h = h.move_toward(f*want.length()*SWIM*(0.4+0.6*maxf(f.dot(way),0.0)),SWIM_ACCEL*delta)
	else:
		h = h.move_toward(Vector2.ZERO,SWIM_DRAG*delta)
	var moved: Vector3 = slide.call(feet,h*delta)
	var at := Vector2(moved.x,moved.z)
	var bed := float(ground.call(at))
	if not is_finite(bed) or bed > feet.y+STEP_UP:
		# A bank too steep to wade up, or the island's rim: held off it.
		h = Vector2.ZERO
		moved = feet
		at = Vector2(feet.x,feet.z)
		bed = float(ground.call(at))
	var d := _depth(at)
	if pressed:
		# Up out of the water.
		swimming = false
		grounded = false
		chain = 1
		move = "jump"
		_light = false
		_no_cut = false
		_jumped = true
		_from_water = true
		_since_ground = coyote
		feet = Vector3(moved.x,maxf(feet.y,bed),moved.z)
		velocity = Vector3(h.x,sqrt(2.0*gravity*SWIM_HOP),h.y)
		ground_y = bed
		_wet_at(at,ground)
		out["jumped"] = 1
		out["hopped"] = true
		return out
	if d < SWIM_OUT:
		# Shallow enough to stand: on his feet, walking out.
		swimming = false
		grounded = true
		feet = Vector3(moved.x,bed,moved.z)
		ground_y = bed
		velocity = Vector3(h.x,0.0,h.y)
		_since_land = 99.0
		_wet_at(at,ground)
		out["stood"] = true
		return out
	# Afloat on the float's spring.
	var goal := maxf(bed+d-SWIM_DRAFT,bed)
	var w := TAU*SWIM_SPRING
	velocity.y += (w*w*(goal-feet.y)-2.0*SWIM_DAMP*w*velocity.y)*delta
	var y := feet.y+velocity.y*delta
	if y < bed:
		y = bed
		velocity.y = maxf(velocity.y,0.0)
	feet = Vector3(moved.x,y,moved.z)
	ground_y = bed
	velocity.x = h.x
	velocity.z = h.y
	_wet_at(at,ground)
	return out

## Crouched on the ground: no running, a run slid to a stop; standing, he
## still turns to the stick.
func _crouch_slide(h: Vector2, want: Vector2, delta: float) -> Vector2:
	skidding = false
	var pace := move_toward(h.length(),0.0,CROUCH_BRAKE*delta)
	if pace < 0.3 and want != Vector2.ZERO: facing = rotate_toward(facing,facing_of(want.normalized()),turn*delta)
	return h.normalized()*pace if h != Vector2.ZERO else Vector2.ZERO

## On the ground: turn to the stick and run up to its pace, or skid.
func _run(h: Vector2, want: Vector2, top: float, delta: float) -> Vector2:
	var pace := h.length()
	if want == Vector2.ZERO:
		skidding = false
		pace = move_toward(pace,0.0,brake*delta)
		return h.normalized()*pace if h != Vector2.ZERO else Vector2.ZERO
	var way := want.normalized()
	if pace > skid_speed and h.normalized().dot(way) < -0.6: skidding = true
	if skidding:
		pace = move_toward(pace,0.0,skid_brake*delta)
		if pace < 0.4:
			skidding = false
			facing = facing_of(way)
		return h.normalized()*pace if h != Vector2.ZERO else Vector2.ZERO
	var rate := lerpf(turn,turn_run,clampf(pace/run,0.0,1.0))
	facing = rotate_toward(facing,facing_of(way),rate*delta)
	var f := forward(facing)
	var goal := want.length()*top*(0.5+0.5*maxf(f.dot(way),0.0))*_uphill(f)
	if pace > top and pace > goal and wade < WADE_FROM:
		# Carried pace over the run (dry: wading slows as ever): bleeding
		# away, slower held on.
		var on := want.length() > 0.7 and f.dot(way) > 0.9
		pace = maxf(pace-((carry_hold if on else carry_decay)+carry_excess*(pace-top))*delta,maxf(goal,top))
	else:
		pace = move_toward(pace,goal,(accel if pace < goal else brake)*delta)
	return f*pace

## The share of his pace kept running along `f` up the slope underfoot.
func _uphill(f: Vector2) -> float:
	var rise := slope.length()
	if rise < 1e-4: return 1.0
	var up := maxf(f.dot(slope/rise),0.0)
	return 1.0-(1.0-SLOPE_SLOWEST)*clampf((steepness()-SLOPE_SLOW)/(slide_auto-SLOPE_SLOW),0.0,1.0)*up

## The ground's slope at frame point `p`, its rise a metre (x, z): along
## each axis the gentlest of its rise either side of `p`, near (SLOPE_NEAR)
## and further (SLOPE_PROBE) (none where they rise opposite ways or any is
## missing), so a plane is its slope, and a step's edge, a stair's tread, a
## ridge or a gully is flat.
func _gradient(ground: Callable, p: Vector2) -> Vector2:
	var c := float(ground.call(p))
	if not is_finite(c): return Vector2.ZERO
	var g := Vector2.ZERO
	for axis in range(2):
		var rises := []
		for reach: float in [SLOPE_NEAR,SLOPE_PROBE]:
			var d := Vector2(reach,0.0) if axis == 0 else Vector2(0.0,reach)
			rises.append((float(ground.call(p+d))-c)/reach)
			rises.append((c-float(ground.call(p-d)))/reach)
		var least: float = rises[0]
		for r: float in rises:
			if not is_finite(r) or r*least <= 0.0:
				least = 0.0
				break
			if absf(r) < absf(least): least = r
		g[axis] = least
	return g

## The slope underfoot, degrees.
func steepness() -> float:
	return rad_to_deg(atan(slope.length()))

## Whether he surfs this step: already surfing (`_surf` ends it), crouched
## on a slope over SLIDE_FROM or at a run (over long_pace: the flat slide,
## not out of a crouch already stopped), or on one too steep to stand on that goes on
## SLOPE_FAR either way down its fall line (a short steep patch, a stair's
## foot on a rough bank, is climbed).
func _surfing(crouched: bool, ground: Callable) -> bool:
	if wade > SWIM_IN*0.5: return false
	var steep := steepness()
	if move == "slide" or (crouched and steep >= SLIDE_FROM): return true
	if crouched and move != "crouch" and Vector2(velocity.x,velocity.z).length() >= long_pace: return true
	if steep <= slide_auto: return false
	var p := Vector2(feet.x,feet.z)
	var fall := -slope.normalized()
	var up := (float(ground.call(p-fall*SLOPE_FAR))-feet.y)/SLOPE_FAR
	var down := (feet.y-float(ground.call(p+fall*SLOPE_FAR)))/SLOPE_FAR
	return is_finite(up) and is_finite(down) and rad_to_deg(atan(minf(up,down))) > slide_auto

## Boot-surfing: pulled down the fall line, steered across it (on the flat
## only uncrouched: the crouched slide runs straight), braked against it,
## slowed by the air, no faster than slide_top, turning to face the way he
## goes; on flat ground slowing, and once down to the pace the stick asks (crouched,
## to a stop) on his feet again; stopped on a slope he can stand on, too.
## The run's new pace.
func _surf(h: Vector2, want: Vector2, top: float, delta: float) -> Vector2:
	skidding = false
	var rise := slope.length()
	var steep := steepness()
	var fall := -slope/rise if rise > 1e-4 else Vector2.ZERO
	h += fall*slide_pull*sin(atan(rise))*delta
	var way := h.normalized() if h.length() > 0.3 else (fall if fall != Vector2.ZERO else forward(facing))
	var side := Vector2(-way.y,way.x)
	if steep >= SLIDE_END or not crouch: h += side*want.dot(side)*SLIDE_STEER*delta
	var drag := (SLIDE_DRAG if steep >= SLIDE_END else slide_runout)+slide_air*h.length_squared()
	if want.dot(way) < -0.5: drag += SLIDE_BRAKE
	var pace := minf(move_toward(h.length(),0.0,drag*delta),slide_top)
	h = h.normalized()*pace if h.length() > 1e-4 else Vector2.ZERO
	if pace > 0.3: facing = rotate_toward(facing,facing_of(h),TURN_RUN*1.5*delta)
	if steep > slide_auto: return h
	var flat := steep < SLIDE_END
	var done := (flat and pace <= SLIDE_STOP) if crouch else pace <= (maxf(top*want.length(),SLIDE_STOP) if flat else SLIDE_STOP)
	if done: move = "crouch" if crouch else ""
	return h

## Whether a jump now chains on a slide hop's touch.
func _chained() -> bool:
	return _hop_landed and _since_land <= long_chain

## In the air out of a slide: the stick across his way bends the run round,
## its pace kept, and adds to it up to hop_top; pulled back, or slower than
## the run, steered as ever (at `rate`).
func _strafe(h: Vector2, want: Vector2, top: float, delta: float, rate: float) -> Vector2:
	if want.length() < 0.2 or h.length() < top: return _steer(h,want,top,delta,rate)
	var way := h.normalized()
	var to := want.normalized()
	if way.dot(to) < -0.3: return _steer(h,want,top,delta,rate)
	var across := absf(way.cross(to))*minf(want.length(),1.0)
	var limit := hop_turn*delta
	var pace := h.length()
	if pace < hop_top: pace = minf(pace+hop_strafe*across*delta,hop_top)
	h = way.rotated(clampf(way.angle_to(to),-limit,limit))*pace
	facing = rotate_toward(facing,facing_of(h),hop_turn*2.0*delta)
	return h

## In the air: the run kept, steered a little (at `rate`, m/s²).
func _steer(h: Vector2, want: Vector2, top: float, delta: float, rate: float) -> Vector2:
	if want == Vector2.ZERO: return h
	facing = rotate_toward(facing,facing_of(want.normalized()),air_turn*delta)
	var goal := want*maxf(top,h.length())
	return h.move_toward(goal,rate*delta)
