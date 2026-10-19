extends RefCounted
## The hand-flown landing: no F, no sequence flying it in. The pilot finds a
## spot and puts the plane (scripts/sky_plane.gd) on it however they like:
## slow and tidy, or hot and hard and then drift it to a stop like a kart.
## Almost every touch sticks; only stopped can the pilot get out, and only
## by asking (Exit). The landing study (studies/landing_study.gd) and the
## game under `--manual-landing` (scripts/wanderer_eye.gd) both run it;
## plain state and maths over the plane, so tests can step it.
## docs/design/manual-landing.md (round 2: the drift; round 3: the slam,
## backing up and steering the slide).
##
## Its phases:
##   AIR      flying as ever (SkyPlane `step`). Each step the wheels are
##            watched: the first step the plane rides the land (SkyGlide
##            `skimming`, over ground the `floor` has) is the touch, graded
##            on the air step before it (`grade`). Near the land, rising air
##            is calmed (CALM_LOW to CALM_HIGH m), so a slow approach is not
##            held up off the ground by ridge lift or a gust.
##   ROLL     on its wheels, sliding or gripping (below). Boost opens the
##            throttle (ROLL_PUSH, up to ROLL_TOP), the stick steers. Under
##            power the tail comes up off the grass; rolling straight past
##            ROTATE_FROM with Boost held, the stick pulled back brings the
##            nose up on the main wheels, and nose up at LIFT_SPEED the
##            wheels let go (`events.lifted`). Off them it is heavy a
##            while (the unstick, below). Rolled or slid
##            off the land's edge it is flying again too, its slide carried on as the air drift's slip,
##            and first it dips (`dipping`): it falls, the nose eases down
##            to DIP_NOSE, and only once the dive (DIP_GAIN of the fall
##            along it, Boost's PUSH) has it up to FLY_SPEED do the wings
##            catch it (`events.wings`). Off slow it dips deep; nose held up
##            it dips on; after DIP_MAX s the wings catch it anyway.
##   STOPPED  stood still, the brakes holding, the engine ticking over. Boost
##            rolls it off again; Exit gets out. Brake and Boost held, the
##            stick near centre, runs it up on the brakes (`strain` builds
##            over SPOOL_TIME, `events.spool`); let the brake go and it
##            lunges (`events.let_go`), the push SURGE over at full strain,
##            easing off over SURGE_TIME: a short-field takeoff. Brake held REVERSE_DELAY s
##            backs it up (`reversing`, in ROLL: below); Brake, a blip of
##            Boost and the stick pivot it on the spot (SPOT_TURN).
##   EXIT     the engine spins down (SPIN) and the pilot hops out (HOP_TIME,
##            `hop` 0 to 1), then OUT: the caller parks it and walks.
##
## The touch (`grade`): a "greaser" is slower than TOUCH_FAST along the
## ground, sinking under GREASE_SINK, wings within GREASE_BANK and the nose
## no lower than GREASE_NOSE, not drifting (the air drift's slip under
## GREASE_SLIP): it settles with two small hops and rolls out straight and
## tidy. Within round 1's limits (TOUCH_FAST, TOUCH_SINK, TOUCH_BANK,
## TOUCH_NOSE) it is "firm", the same with a firmer settle. Faster is
## "hot", sinking harder or nose first is "hard", a wing low (past
## TOUCH_BANK, a knife edge too) is "wingtip": all of them stick. The plane
## takes the hit: a squash and a little hop that stays on the wheels
## (`events.thump`, its strength `k` for the caller's thump, dust, shake
## and pad pulse), a little speed lost to the sink (THUMP_SCRUB), and
## LOOSE_TIME of loose wheels that slide at less provocation. A wingtip
## first touch also kicks the nose round (WINGTIP_KICK) into a slide. Three
## touches don't stick: mid barrel roll ("tumble"), onto land steeper than
## TOUCH_SLOPE ("rough"), or flown straight into the ground ("slam": the
## dive's path steeper than SLAM_ANGLE, or its sink, the speed down the
## nose's line, over SLAM_SINK). Those hop: a thump, kicked up at BOUNCE_UP
## plus BOUNCE_GIVE of the sink (at most BOUNCE_TOP), the wings put level,
## the nose up to BOUNCE_NOSE, BOUNCE_GRACE s before the wheels count
## again. Never a crash. The slam is judged on the dive remembered over the
## last moments (`dive`, `dive_sink`), which forget only at DIVE_FORGET
## rad/s and SINK_FORGET m/s², a little slower than the stick can pull the
## nose up: so a flare must be flown, and a flick of the nose on the last
## frame (the mouse can) lands as the dive it came out of. The sink every
## grade reads is remembered the same way. Speed alone never hops: a hot,
## shallow touch sticks and slides.
##
## On the wheels it is a kart. Gripping, the tail wheel steers it
## (TAXI_TURN, less slow) and the wheels hold the way it points, the
## brakes slowing it straight (ROLL_DRAG, WHEEL_BRAKE). It breaks loose and
## slides when it asks more of the wheels than they have (the turn's rate
## times the speed over GRIP m/s², less with loose wheels), when the
## knife-edge lean (Q E, LB RB: the air drift's button) is held with a real
## turn of the stick (over DRIFT_ONSET), when it is braked and steered at
## once (a power-slide), or when it already points well off its way (over
## SLIDE_SLIP: a crab, a drift carried down from the air). Sliding, the
## nose swings to an angle off its track that the stick asks for:
## SLIDE_ANGLE for a drift (PIVOT rad/s), BRAKE_ANGLE braked (BRAKE_PIVOT),
## and with the throttle opened too the prop's wash on the tail swings it
## right round to POWER_ANGLE (POWER_PIVOT): a power-slide, pivoting on its
## wheels; a blip of it is enough, the brakes holding the tail where it
## swung. The more sideways it goes the more it scrubs (SCRUB m/s² fully
## sideways, the brakes' along the wheels, whichever is more), so a
## power-slide stops shorter than a straight brake. Its path bends towards
## the nose at SLIDE_BEND rad/s (less braked): a drift curves round. Let
## the stick go and the nose swings back to its track; within CATCH it
## grips again. The throttle without the brake pushes along the nose, to
## power out of a drift.
##
## Steering the slide, as a kart's drift: the slide keeps the side the
## nose went out to (`drift_side`). Full stick into it is round 2's line;
## easing the stick off bends the line wider by LINE_STEER rad/s per whole
## stick, and steering against it (counter-steer) wider still (twice
## LINE_STEER at full), the nose kept out at DRIFT_COUNTER of the angle, as
## the air drift's turn against the lean does. The lean (Q E, LB RB: the
## air drift's button) held bends it tighter by LINE_STEER more. Only the
## stick let go swings the nose back and grips again. LINE_STEER scales
## with the plane's `drift_strength` (`--drift`). The scrub is the slip's,
## so a counter-steered slide stops no shorter.
##
## Backing up: stopped, Brake held REVERSE_DELAY s rolls it backwards
## (`reversing`) up to REVERSE_SPEED, and the stick turns it as a car
## backs (stick right, the tail goes right) at up to REVERSE_TURN. Let the
## brake go and it stops; Boost stops it and rolls on forwards. It never
## backs off the land: with no land REVERSE_LOOK m behind it, it stops
## there ("edge_behind"). Stopped, Brake, Boost and the stick pivot it on
## its wheels (SPOT_TURN), and rolling, an open throttle turns it at the
## full TAXI_TURN even stood still (the prop's wash on the rudder): so a
## plane nosed into stone can turn away. Into something (`blocked`), it is
## stopped short; already in it (a slide's swing, a pivot), any move that
## heads out (clear ESCAPE_REACH m on) goes, so it never sticks there.
##
## It counts what the study measures (`stats`): every touch (speed, sink,
## bank, its grade), greasers, hops (`bounces`), go-arounds (low over the
## land, under LOW_PASS m, then back up over GO_AROUND m without stopping),
## the rollout from the touch to the stop (m), the time to the stop,
## touch-and-gos, rolls off the edge, Exit asked before the stop, and the
## slide: metres slid, the peak slip (radians, nose off its track) and the
## stop's margin to the edge (m on along the way it was going).

const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")
const PlaneLanding = preload("res://scripts/plane_landing.gd")

enum {AIR,ROLL,STOPPED,EXIT,OUT}
const NAMES := ["air","roll","stopped","exit","out"]

## Round 1's good touch, now the firm one: the most speed along the ground
## (m/s), sink (m/s), bank (radians), nose down (radians), and slope of the
## land (m per m; steeper hops).
const TOUCH_FAST := 10.5
const TOUCH_SINK := 2.4
const TOUCH_BANK := 0.35
const TOUCH_NOSE := -0.4
const TOUCH_SLOPE := 0.4
## A greaser, within TOUCH_FAST: the most sink (m/s), bank and nose down
## (radians), and the air drift's slip (radians; a crab in the wind is not
## the pilot's and doesn't count).
const GREASE_SINK := 1.2
const GREASE_BANK := 0.2
const GREASE_NOSE := -0.2
const GREASE_SLIP := 0.12
## The slam: a dive whose path is steeper than SLAM_ANGLE (radians, nose
## down), or whose sink down the nose's line is over SLAM_SINK (m/s), hops
## instead of sticking. The hardest flown touch the bots make sinks about
## 3.3 m/s at 18 degrees; a hot touch nosed down at cruise (the kit isle's
## test) about 5 m/s at 21. The dive and the sink are remembered, forgetting
## at DIVE_FORGET rad/s and SINK_FORGET m/s² (the stick pulls the nose up at
## SkyPlane.PITCH_SPEED, 1.4 rad/s), so a last-frame flare can't hide one.
const SLAM_ANGLE := 0.55
const SLAM_SINK := 9.0
const DIVE_FORGET := 1.0
const SINK_FORGET := 12.0
## The grades that don't stick, and hop.
const HOPS := ["tumble","rough","slam"]
## A hard touch's hit: full at THUMP_SINK m/s of sink, THUMP_FAST m/s over
## TOUCH_FAST, or a wing right down; the speed it loses per m/s of sink;
## the squash (m down over SQUASH_TIME s) and the hop after it that stays on
## the wheels (m up over HOP_TIME s); the loose wheels after it (s, and the
## grip they lose at the hit's full); the nose kicked round by a wingtip
## first (radians at a full knife edge).
const THUMP_SINK := 6.0
const THUMP_FAST := 10.0
const THUMP_SCRUB := 0.25
const SQUASH := 0.16
const SQUASH_TIME := 0.1
const HOP := 0.3
const HOP_TIME := 0.34
const LOOSE_TIME := 0.6
const LOOSE_GRIP := 0.6
const WINGTIP_KICK := 0.6
## A hop: the kick up (m/s) and the share of the sink it gives back, at
## most BOUNCE_TOP (about 1.4 m of kick: "no, try again", not a launch),
## the pull that brings the kick down (m/s²), the nose it throws up to
## (radians), the speed it scrubs (m/s) and the seconds before the wheels
## count again (after a touch-and-go too).
const BOUNCE_UP := 3.2
const BOUNCE_GIVE := 0.5
const BOUNCE_TOP := 5.0
const BOUNCE_PULL := 9.0
const BOUNCE_NOSE := 0.3
const BOUNCE_SCRUB := 1.0
const BOUNCE_GRACE := 0.7
## On the wheels, gripping: the slowing rolling with the throttle closed
## (m/s²), the wheel brakes' most (m/s²), the throttle's push (m/s², the
## takeoff's), how hard a slope pulls (m/s² per m per m), the tail wheel's
## turn (radians a second at full stick, at TAXI_FULL m/s and over; a
## quarter of it stopped), and the speed at which it lifts off with Boost
## held.
const ROLL_DRAG := 0.9
const WHEEL_BRAKE := 4.2
const PUSH := PlaneLanding.PUSH
const SLOPE_PULL := 7.0
const TAXI_TURN := 0.9
const TAXI_FULL := 3.0
const LIFT_SPEED := PlaneLanding.LIFT_SPEED
## The throttle's push rolling (m/s²): harder than the sequence's, so a
## small isle has room to reach LIFT_SPEED.
const ROLL_PUSH := 6.0
## Lifting off the land: under power the tail comes up between TAIL_FROM
## and TAIL_FULL m/s (over TAIL_TIME s), the nose down to TAIL_NOSE
## (radians); the stick pulled back past ROTATE_PULL (or the mouse pulling
## up) from ROTATE_FROM m/s brings the nose up on the mains at ROTATE_RATE
## rad/s, and at ROTATE_NOSE, at LIFT_SPEED or more, the wheels let go.
const TAIL_FROM := 2.0
const TAIL_FULL := 6.0
const TAIL_TIME := 0.5
const TAIL_NOSE := 0.04
const ROTATE_PULL := 0.3
const ROTATE_FROM := 8.0
const ROTATE_RATE := 0.35
const ROTATE_NOSE := 0.22
## The unstick: UNSTICK_TIME s off the wheels it is heavy. It climbs only
## UNSTICK_FLOAT of what its nose asks at first (hanging over the grass),
## the whole of it by the end; its speed builds at no more than
## UNSTICK_PUSH m/s²; the nose comes up no faster than UNSTICK_NOSE rad/s
## over where it left the wheels. All of it eases out, so nothing snaps.
const UNSTICK_TIME := 1.6
const UNSTICK_FLOAT := 0.15
const UNSTICK_PUSH := 2.5
const UNSTICK_NOSE := 0.18
## The run-up on the brakes (s to full strain), and the let-go's lunge: the
## push SURGE over at full strain, easing off over SURGE_TIME s.
const SPOOL_TIME := 1.0
const SURGE := 1.0
const SURGE_TIME := 0.6
## The fastest the throttle rolls it on the wheels (m/s), under FLY_SPEED,
## so every takeoff off an edge dips. The dip: the speed the wings catch
## it at (m/s), the nose it eases to with the stick let go (radians, down
## negative) and how fast (s), the pull along the dive (m/s² per sine of
## it; a nose held up loses speed), and the longest it lasts (s).
const ROLL_TOP := 11.0
const FLY_SPEED := 12.5
const DIP_NOSE := -0.35
const EASE_DIP := 0.3
const DIP_GAIN := 9.0
const DIP_MAX := 3.0
## The slide: the wheels' grip (m/s² sideways before they let go), the
## slowest it slides (m/s; a power-slide from POWER_MIN), the stick that
## starts a drift with the lean held, the nose already off its track that
## slides by itself, and that grips again (radians).
const GRIP := 7.0
const SLIDE_MIN := 2.0
const POWER_MIN := 1.5
const DRIFT_ONSET := 0.3
const SLIDE_SLIP := 0.35
const CATCH := 0.12
## Sliding: the nose's angle off its track at full stick (radians) and how
## fast it swings there (rad/s): a drift, braked, braked with the throttle
## open (the power-slide); the scrub fully sideways (m/s²); how fast its
## path bends towards the nose (rad/s; braked, by BRAKE_BEND's share less;
## the lean held, by LEAN_BEND's more).
const SLIDE_ANGLE := 0.6
const PIVOT := 2.6
const BRAKE_ANGLE := 0.95
const BRAKE_PIVOT := 2.8
const POWER_ANGLE := 1.45
const POWER_PIVOT := 5.5
const SCRUB := 8.5
const SLIDE_BEND := 1.1
const BRAKE_BEND := 0.8
const LEAN_BEND := 0.4
## Steering the slide: the line bent by the stick (rad/s for each whole
## stick off full into the slide, not lessened by the brake): full into it
## round 2's line, less wider, against it wider again (twice LINE_STEER at
## full counter-steer), and the lean held tighter by as much again; against
## it the nose holds DRIFT_COUNTER of its angle (the air drift's).
const LINE_STEER := 0.3
const DRIFT_COUNTER := SkyPlane.DRIFT_COUNTER
## Backing up: Brake held stopped this long (s) backs it up, to at most
## REVERSE_SPEED (m/s, under SLIDE_MIN so it never slides), gaining it at
## REVERSE_PUSH and losing it with the brake let go at REVERSE_STOP (m/s²);
## the stick turns it at up to REVERSE_TURN (rad/s, at REVERSE_SPEED; a
## quarter of it barely moving); it looks REVERSE_LOOK m behind its middle
## for the land's edge (the tail's over it).
const REVERSE_DELAY := 0.4
const REVERSE_SPEED := 1.6
const REVERSE_PUSH := 2.5
const REVERSE_STOP := 4.0
const REVERSE_TURN := 0.8
const REVERSE_LOOK := 1.2
## Pivoting: stopped, Brake, Boost and the stick turn it on its wheels at
## SPOT_TURN rad/s; rolling with the throttle open (WASH_FULL of it is
## enough) the tail wheel turns it at the full TAXI_TURN however slow. Into something, a hit under HIT_FELT
## m/s (pushing on it) is not felt; already in it, a move clear
## ESCAPE_REACH m on is heading out and goes.
const SPOT_TURN := 0.9
const WASH_FULL := 0.3
const HIT_FELT := 1.0
const ESCAPE_REACH := 0.5
## The grit thrown off the wheels (`grit` 0 to 1): full sliding sideways at
## SPRAY_FULL m/s, and braking straight at most SPRAY_BRAKE of it (full at
## SPRAY_BRAKE_AT m/s); how fast it follows (s).
const SPRAY_FULL := 7.0
const SPRAY_BRAKE := 0.3
const SPRAY_BRAKE_AT := 14.0
const EASE_GRIT := 0.08
## The bank it leans out of a slide by, per radian of slip, and the
## seconds the tail takes to come down after the touch.
const SLIDE_LEAN := 0.12
const TAIL_DOWN := 1.2
## Stopped: slower than STOP_SPEED for STOP_HOLD seconds.
const STOP_SPEED := 0.25
const STOP_HOLD := 0.25
## The touch's settle: a small hop or two on the wheels (heights m, lengths
## s), as the scripted landing's.
const SETTLE := Vector2(0.09,0.025)
const SETTLE_TIME := Vector2(0.26,0.16)
## Go-arounds: low over the land under LOW_PASS m, then back over GO_AROUND.
const LOW_PASS := 3.0
const GO_AROUND := 8.0
## Rising air is calmed near the land: none under CALM_LOW m over it, all
## of it from CALM_HIGH m.
const CALM_LOW := 1.0
const CALM_HIGH := 5.0
## How far on the stop's margin to the edge is looked for (m).
const MARGIN_REACH := 80.0

var plane: RefCounted
var phase := AIR
## Seconds in this phase, and since `begin`.
var time := 0.0
var elapsed := 0.0
## The engine running (0 to 1) and the throttle (-1 to 1), for the hum and
## the propeller; the pilot's hop out (0 in, 1 out).
var engine := 1.0
var throttle := 0.0
var hop := 0.0
## What the last touch was ("" none yet; its grade).
var last_touch := ""
## On the wheels: sliding or not, the nose off its track now (radians,
## heading less track), power-sliding (braked and steered) now, and the grit
## thrown off the wheels (0 to 1, for the caller's spray and hiss).
var sliding := false
var slip := 0.0
var power := false
var grit := 0.0
## The side the slide's nose is out to (1 or -1, 0 not sliding), and
## backing up now.
var drift_side := 0.0
var reversing := false
## In the air: the dive remembered (radians, nose down; and its sink down
## the nose's line, m/s), and the sink remembered (m/s), as `grade` reads
## them at the touch.
var dive := 0.0
var dive_sink := 0.0
var sink_seen := 0.0
## The numbers (see the header).
var stats := {}
## Seconds left before the wheels count, and the hop's kick still lifting
## (m/s).
var _grace := 0.0
var _kick := 0.0
## Off an edge, not yet flying: the speed it has (m/s) and seconds dipping
## (negative: not dipping).
var _dip_speed := 0.0
var _dip_time := -1.0
## The air step's velocity before the wheels met the land, and its pose.
var _air_velocity := Vector3.ZERO
var _air_pitch := 0.0
var _air_bank := 0.0
var _air_rolling := false
var _air_slip := 0.0
## On the wheels: the velocity over the ground (global XZ, m/s), the touch's
## pitch and hit (0 to 1), seconds since the touch, seconds of loose wheels
## left, seconds slow, where it touched (for the rollout), the land's height
## last seen under it, and the way it last went (for the stop's margin).
var _v := Vector2.ZERO
var _touch_pitch := 0.0
var _thump_k := 0.0
var _since_touch := 0.0
var _loose := 0.0
var _slow_for := 0.0
var _touch_at := Vector3.ZERO
var _land_y := NAN
var _way := Vector2(0.0,-1.0)
## Low over the land since the last go-around; in a power-slide (for its
## count).
var _low := false
var _in_power := false
## Stopped: seconds Brake has been held (to back up); backing up, stopped
## at the land's edge behind (said once).
var _brake_held := 0.0
var _at_edge := false
## The run-up on the brakes: how hard it strains (0 to 1, for the caller's
## rumble and shake), and the let-go's lunge left (0 to 1, easing off).
var strain := 0.0
var _surge := 0.0
## Taking off: the tail up (0 to 1), the nose brought up on the mains (0 to
## 1 of the way to ROTATE_NOSE), and seconds into the unstick (-1: none),
## its speed and nose at the let-go.
var _tail := 0.0
var _rot := 0.0
var _unstick := -1.0
var _unstick_speed := 0.0
var _unstick_nose := 0.0
## Its height through the unstick, kept here: the plane's skim would pop it
## up to SKIM over the grass the moment it flies.
var _unstick_y := 0.0
## A load hung under it (set from outside each frame, e.g. by scripts/
## carry/carry_host.gd from carry_weights.gd LOAD; none by default): the
## share of the rolling push it loses, m/s more it needs to lift off the
## wheels, times longer the unstick hangs, m/s more the wings need off an
## edge, the most the throttle rolls it (m/s), and too heavy to fly (it
## won't lift off, and stops at the land's edge rather than roll off it:
## `held_by_load` while it is held there).
var load_roll := 0.0
var load_top := INF
var load_lift := 0.0
var load_unstick := 1.0
var load_dip := 0.0
var too_heavy := false
var held_by_load := false

## Takes charge of `on_plane`: in the air (`on_ground` false, flying as it
## is), or stood stopped where it is (`on_ground`, as a parked plane boarded
## without the takeoff sequence).
func begin(on_plane: RefCounted, on_ground := false) -> void:
	plane = on_plane
	phase = STOPPED if on_ground else AIR
	strain = 0.0
	_surge = 0.0
	_tail = 0.0
	_rot = 0.0
	_unstick = -1.0
	time = 0.0
	elapsed = 0.0
	engine = 1.0
	throttle = 0.0
	hop = 0.0
	last_touch = ""
	_grace = 0.0
	_kick = 0.0
	_dip_time = -1.0
	_air_velocity = plane.velocity
	_air_pitch = float(plane.pitch)
	_air_bank = float(plane.bank)
	_air_slip = 0.0
	_v = Vector2.ZERO
	_loose = 0.0
	_thump_k = 0.0
	sliding = false
	slip = 0.0
	power = false
	grit = 0.0
	drift_side = 0.0
	reversing = false
	dive = 0.0
	dive_sink = 0.0
	sink_seen = 0.0
	_brake_held = 0.0
	_low = false
	stats = {"touches":[],"bounces":0,"go_arounds":0,"touch_and_gos":0,"off_edge":0,"early_exits":0,
		"rollout":NAN,"time_to_stop":NAN,"stopped":false,"bounce_reasons":{},"greasers":0,
		"slide_distance":0.0,"peak_slip":0.0,"power_slides":0,"stop_margin":NAN,"stop_grade":"","reverses":0,"lift_offs":0}

## Off an edge and falling, the wings not yet carrying it.
func dipping() -> bool:
	return phase == AIR and _dip_time >= 0.0

func flying() -> bool:
	return phase == AIR

func on_ground() -> bool:
	return phase in [ROLL,STOPPED,EXIT]

## True stood still with the pilot still in: Exit gets out.
func can_exit() -> bool:
	return phase == STOPPED

func done() -> bool:
	return phase == OUT

## What a touch like this one is (see the header): "greaser", "firm",
## "hot", "hard" or "wingtip", which stick, or "tumble", "rough" or "slam",
## which hop. `slip` is the air drift's (SkyPlane `slip`); `dive` and
## `dive_sink` the dive (radians nose down, and m/s down the nose's line;
## by default the nose's and the sink).
static func grade(speed: float, sink: float, bank: float, pitch: float, slope: float, rolling := false, drift_slip := 0.0, dive_now := NAN, dive_sink_now := NAN) -> String:
	if rolling: return "tumble"
	if slope > TOUCH_SLOPE: return "rough"
	if slams(maxf(0.0,-pitch) if is_nan(dive_now) else dive_now,sink if is_nan(dive_sink_now) else dive_sink_now): return "slam"
	if absf(bank) > TOUCH_BANK: return "wingtip"
	if sink > TOUCH_SINK or pitch < TOUCH_NOSE: return "hard"
	if speed > TOUCH_FAST: return "hot"
	if sink <= GREASE_SINK and absf(bank) <= GREASE_BANK and pitch >= GREASE_NOSE and absf(drift_slip) <= GREASE_SLIP: return "greaser"
	return "firm"

## Whether a dive this steep (radians nose down) or sinking this hard down
## its line (m/s) is flown straight into the ground.
static func slams(dive_now: float, dive_sink_now: float) -> bool:
	return dive_now > SLAM_ANGLE or dive_sink_now > SLAM_SINK

## Whether a touch of this grade stays on the wheels.
static func sticks(touch_grade: String) -> bool:
	return not touch_grade in HOPS

## How hard a touch hits, 0 (a greaser's) to 1.
static func thump(speed: float, sink: float, bank: float) -> float:
	var k := maxf((sink-GREASE_SINK)/(THUMP_SINK-GREASE_SINK),(speed-TOUCH_FAST)/THUMP_FAST)
	k = maxf(k,(absf(bank)-TOUCH_BANK)/(PI*0.5-TOUCH_BANK))
	return clampf(k,0.0,1.0)

## What a touch now would be, as `grade` reads the plane at the touch,
## the dive and sink remembered ("" not flying).
func grade_now(floor_at: Callable) -> String:
	if phase != AIR or plane == null: return ""
	var v: Vector3 = plane.velocity
	var at := Vector2(plane.position.x,plane.position.z)
	var now := _dive_now()
	return grade(Vector2(v.x,v.z).length(),maxf(sink_seen,maxf(0.0,-v.y-_kick)),float(plane.bank),float(plane.pitch),_slope(floor_at,at,v),
		bool(plane.get("rolling")),float(plane.get("slip")),maxf(dive,now.x),maxf(dive_sink,now.y))

## Whether a touch now would be a greaser (for a landing mark).
func would_grease(floor_at: Callable) -> bool:
	return grade_now(floor_at) == "greaser"

## One step. `input` is the plane's (SkyPlane `step`), plus `exit` (true on
## the frame Exit is asked for). `ground` is the flight's solids (SkyGlide
## `step`), `floor_at` Callable(Vector2) -> float, the land's height under a
## global XZ point (NAN off the land: the wheels' ground); `air` as the
## flight's. `blocked`, if given, Callable(Vector3) -> bool, true where
## something stands in the way of the wheels. Returns what happened:
##   touch {speed, sink, bank, grade, ...}, settled {grade, k} (it stuck),
##   greaser, thump {k} (a hard one), bounce {reason, sink, speed} (a hop),
##   slide (it broke loose), caught (it gripped again), stopped {margin},
##   off_edge {speed}, wings {speed} (the dip over, flying), go_around, not_yet (Exit
##   before the stop), hit (slid into something), out (the pilot is out).
func step(delta: float, input: Dictionary, ground: Callable, floor_at: Callable, air := Callable(), blocked := Callable()) -> Dictionary:
	var out := {}
	time += delta
	elapsed += delta
	if bool(input.get("exit",false)) and phase in [AIR,ROLL]:
		out["not_yet"] = true
		stats.early_exits += 1
	match phase:
		AIR: _fly(delta,input,ground,floor_at,air,out)
		ROLL: _roll(delta,input,floor_at,blocked,out)
		STOPPED: _stopped(delta,input,floor_at,out)
		EXIT:
			engine = maxf(0.0,engine-delta/PlaneLanding.SPIN)
			throttle = -1.0
			hop = clampf((time-PlaneLanding.BEAT_TIME)/PlaneLanding.HOP_TIME,0.0,1.0)
			_hold(floor_at)
			if time >= PlaneLanding.BEAT_TIME+PlaneLanding.HOP_TIME:
				engine = 0.0
				hop = 1.0
				_enter(OUT)
				out["out"] = true
		OUT: _hold(floor_at)
	return out

func _enter(next: int) -> void:
	phase = next
	time = 0.0

## Stood still: Boost (no brake) rolls it off; Brake, Boost and the stick
## pivot it where it stands; Brake held a moment backs it up; Exit gets
## out.
func _stopped(delta: float, input: Dictionary, floor_at: Callable, out: Dictionary) -> void:
	engine = 1.0
	throttle = -0.3
	grit = 0.0
	_hold(floor_at)
	var boost := clampf(float(input.get("boost",0.0)),0.0,1.0)
	var brake := clampf(float(input.get("brake",0.0)),0.0,1.0)
	var turn := clampf(float(input.get("turn",0.0)),-1.0,1.0)
	if boost <= 0.0 or absf(turn) > DRIFT_ONSET: strain = maxf(0.0,strain-delta*2.0)
	_brake_held = _brake_held+delta if brake > 0.3 and boost <= 0.0 else 0.0
	_at_edge = false
	if boost > 0.0 and brake <= 0.3:
		if strain > 0.0:
			out["let_go"] = {"strain":strain}
			_surge = strain
		strain = 0.0
		_enter(ROLL)
		_v = Vector2.ZERO
		sliding = false
		reversing = false
		_since_touch = INF
	elif boost > 0.0 and brake > 0.3 and absf(turn) <= DRIFT_ONSET:
		# Run up on the brakes: full power, held, straining.
		throttle = boost
		strain = minf(1.0,strain+delta/SPOOL_TIME)
		out["spool"] = {"strain":strain}
	elif boost > 0.0 and absf(turn) > DRIFT_ONSET:
		# The prop's wash on the rudder, the brakes holding: round on the spot.
		throttle = boost-brake
		plane.heading = float(plane.heading)-turn*SPOT_TURN*delta
	elif _brake_held >= REVERSE_DELAY:
		_enter(ROLL)
		_v = Vector2.ZERO
		sliding = false
		reversing = true
		_since_touch = INF
		stats.reverses += 1
		out["reverse"] = true
	elif bool(input.get("exit",false)): _enter(EXIT)

# --- In the air ----------------------------------------------------------------------

func _fly(delta: float, input: Dictionary, ground: Callable, floor_at: Callable, air: Callable, out: Dictionary) -> void:
	engine = 1.0
	grit = 0.0
	var calm := air
	if air.is_valid(): calm = func(p: Vector3) -> Dictionary: return calmed(air.call(p),p,floor_at)
	# Dipping, the fall holds at its full until the wings catch it.
	if _dip_time >= 0.0: plane.airborne = minf(float(plane.airborne),SkyPlane.FALL_TIME)
	var nose_was := float(plane.pitch)
	plane.step(delta,input,ground,calm)
	throttle = float(plane.throttle)
	if _unstick >= 0.0: _heavy(delta,nose_was)
	if _dip_time >= 0.0: _dip(delta,input,out)
	# A hop's kick, lifting it clear and dying away.
	if _kick > 0.0:
		plane.position.y += _kick*delta
		_kick = maxf(0.0,_kick-BOUNCE_PULL*delta)
	_grace = maxf(0.0,_grace-delta)
	var at := Vector2(plane.position.x,plane.position.z)
	var land := float(floor_at.call(at))
	if not is_nan(land): _land_y = land
	_watch_go_around(land,out)
	var on_land: bool = not is_nan(land) and plane.skimming and plane.position.y <= land+SkyPlane.SKIM+0.05
	if on_land and _grace <= 0.0:
		_touch(at,land,floor_at,out)
		return
	_remember(delta,on_land)
	# Riding the land during the grace counts as no sink: graded then on
	# its speed alone (and on what is remembered).
	_air_velocity = plane.velocity
	_air_pitch = float(plane.pitch)
	_air_bank = float(plane.bank)
	_air_rolling = bool(plane.rolling)
	_air_slip = float(plane.slip)

## One step of the dip: the nose eased down (the stick let go), the speed
## gained down the dive and from the throttle, lost climbing; at FLY_SPEED
## (or after DIP_MAX s) the wings catch it and the fall eases away.
func _dip(delta: float, input: Dictionary, out: Dictionary) -> void:
	_dip_time += delta
	var look: Vector2 = input.get("look",Vector2.ZERO)
	if is_zero_approx(float(input.get("pitch",0.0))) and is_zero_approx(look.y):
		plane.pitch = lerpf(float(plane.pitch),DIP_NOSE,1.0-exp(-delta/EASE_DIP))
	var boost := clampf(float(input.get("boost",0.0)),0.0,1.0)
	_dip_speed = clampf(_dip_speed+(-DIP_GAIN*sin(float(plane.pitch))+boost*PUSH)*delta,0.0,SkyPlane.FAST)
	plane.speed = maxf(_dip_speed,SkyPlane.SLOW)
	if _dip_speed >= FLY_SPEED+load_dip or _dip_time >= DIP_MAX:
		_dip_time = -1.0
		plane.speed = maxf(_dip_speed,FLY_SPEED+load_dip)
		out["wings"] = {"speed":_dip_speed}

## The dive now: Vector2(radians nose down, m/s down the nose's line).
func _dive_now() -> Vector2:
	var nose := maxf(0.0,-float(plane.pitch))
	return Vector2(nose,float(plane.speed)*sin(nose))

## The dive and the sink remembered: each the larger of now and the last
## forgetting at its rate; riding the land (a hop's grace) nothing is
## forgotten, so a slam can't be ridden out on the ground.
func _remember(delta: float, riding: bool) -> void:
	var now := _dive_now()
	var sink := maxf(0.0,-float(plane.velocity.y)-_kick)
	var keep := 0.0 if riding else 1.0
	dive = maxf(now.x,dive-DIVE_FORGET*delta*keep)
	dive_sink = maxf(now.y,dive_sink-SINK_FORGET*delta*keep)
	sink_seen = maxf(sink,sink_seen-SINK_FORGET*delta*keep)

## The air at `p` (`here`, the flight's) with its rising part calmed near
## the land (CALM_LOW to CALM_HIGH m over it).
static func calmed(here: Dictionary, p: Vector3, floor_at: Callable) -> Dictionary:
	var wind: Vector3 = here.get("wind",Vector3.ZERO)
	if wind.y <= 0.0: return here
	var land := float(floor_at.call(Vector2(p.x,p.z)))
	if is_nan(land): return here
	var out := here.duplicate()
	wind.y *= smoothstep(CALM_LOW,CALM_HIGH,p.y-land)
	out["wind"] = wind
	return out

## Low over the land, then back up high without stopping: a go-around.
func _watch_go_around(land: float, out: Dictionary) -> void:
	var over := float(plane.position.y)-(land if not is_nan(land) else _land_y)
	if is_nan(over): return
	if over < LOW_PASS and not is_nan(land): _low = true
	elif _low and over > GO_AROUND:
		_low = false
		stats.go_arounds += 1
		out["go_around"] = true

## The wheels meet the land: graded on the air step before.
func _touch(at: Vector2, land: float, floor_at: Callable, out: Dictionary) -> void:
	_dip_time = -1.0
	var v := _air_velocity
	var speed := Vector2(v.x,v.z).length()
	var sink := maxf(maxf(0.0,-v.y),sink_seen)
	var slope := _slope(floor_at,at,v)
	var kind := grade(speed,sink,_air_bank,_air_pitch,slope,_air_rolling,_air_slip,dive,dive_sink)
	last_touch = kind
	var touch := {"t":elapsed,"speed":speed,"sink":sink,"bank":_air_bank,"pitch":_air_pitch,"slope":slope,"grade":kind,"result":kind,
		"dive":dive,"dive_sink":dive_sink}
	dive = 0.0
	dive_sink = 0.0
	sink_seen = 0.0
	(stats.touches as Array).append(touch)
	out["touch"] = touch
	_low = true
	if not sticks(kind):
		_bounce(kind,sink,speed,out)
		return
	_enter(ROLL)
	reversing = false
	drift_side = 0.0
	_thump_k = 0.0 if kind == "greaser" else thump(speed,sink,_air_bank)
	_v = Vector2(v.x,v.z)
	if _thump_k > 0.0:
		_v = _v.normalized()*maxf(0.0,speed-THUMP_SCRUB*sink) if speed > 0.01 else Vector2.ZERO
		_loose = LOOSE_TIME*_thump_k
		out["thump"] = {"k":_thump_k}
	else:
		_loose = 0.0
	if kind == "greaser":
		stats.greasers += 1
		out["greaser"] = true
	# A wingtip first drags that side and kicks the nose round.
	if kind == "wingtip": plane.heading = float(plane.heading)-signf(_air_bank)*WINGTIP_KICK*clampf(absf(_air_bank)/(PI*0.5),0.0,1.0)
	slip = _slip_now()
	sliding = absf(slip) > SLIDE_SLIP and _v.length() > SLIDE_MIN
	if sliding: out["slide"] = true
	_touch_pitch = clampf(_air_pitch,-0.1,0.35)
	_since_touch = 0.0
	_slow_for = 0.0
	_touch_at = plane.position
	plane.rolling = false
	plane.spin = 0.0
	plane.knife = 0.0
	out["settled"] = {"grade":kind,"k":_thump_k}
	_place_on(land,floor_at,0.0)

## Back up into the air, never down: kicked up, the wings put level and the
## nose thrown up.
func _bounce(reason: String, sink: float, speed: float, out: Dictionary) -> void:
	stats.bounces += 1
	var reasons: Dictionary = stats.bounce_reasons
	reasons[reason] = int(reasons.get(reason,0))+1
	_kick = minf(BOUNCE_UP+BOUNCE_GIVE*sink,BOUNCE_TOP)
	_grace = BOUNCE_GRACE
	plane.pitch = maxf(float(plane.pitch),BOUNCE_NOSE)
	plane.speed = maxf(float(plane.speed)-BOUNCE_SCRUB,SkyPlane.FLAP_SLOW)
	plane.rolling = false
	plane.spin = 0.0
	plane.bank = 0.0
	plane.knife = 0.0
	# Its own bank's memory too, so the wings come up level, not just drawn so.
	plane.set("_free_bank",0.0)
	plane.set("_lean",0.0)
	plane.set("drift",0.0)
	plane.set("slip",0.0)
	plane.position.y += 0.15
	if plane.velocity.y < 0.0: plane.velocity.y = 0.0
	dive = 0.0
	dive_sink = 0.0
	sink_seen = 0.0
	out["bounce"] = {"reason":reason,"sink":sink,"speed":speed}

# --- On the wheels -------------------------------------------------------------------

## The nose off the way it goes (radians, heading less track; 0 slow).
func _slip_now() -> float:
	if _v.length() < 0.3: return 0.0
	return angle_difference(atan2(-_v.x,-_v.y),float(plane.heading))

func _roll(delta: float, input: Dictionary, floor_at: Callable, blocked: Callable, out: Dictionary) -> void:
	engine = 1.0
	_since_touch += delta
	_loose = maxf(0.0,_loose-delta)
	var boost := clampf(float(input.get("boost",0.0)),0.0,1.0)
	var brake := clampf(float(input.get("brake",0.0)),0.0,1.0)
	var turn := clampf(float(input.get("turn",0.0)),-1.0,1.0)
	var lean := clampf(float(input.get("lean",0.0)),-1.0,1.0)
	var look: Vector2 = input.get("look",Vector2.ZERO)
	var pull := float(input.get("pitch",0.0)) > ROTATE_PULL or look.y > 0.002
	throttle = boost-brake if boost > 0.0 else -1.0
	_surge *= exp(-delta/SURGE_TIME)
	var rotate := false
	var at := Vector2(plane.position.x,plane.position.z)
	var heading := float(plane.heading)
	# The slope pulls it, any way it leans.
	_v -= _gradient(floor_at,at)*SLOPE_PULL*delta
	var speed := _v.length()
	var track := atan2(-_v.x,-_v.y) if speed > 0.3 else heading
	# Backing up: Boost calls it off (it stops, then rolls on forwards).
	if reversing and boost > 0.0 and _v.dot(Vector2(-sin(heading),-cos(heading))) > -STOP_SPEED: reversing = false
	power = brake > 0.3 and absf(turn) > DRIFT_ONSET and speed > POWER_MIN and not reversing
	var grip := GRIP*(1.0-LOOSE_GRIP*clampf(_loose/LOOSE_TIME,0.0,1.0))
	# The tail wheel turns it more the faster it goes, and at its full with
	# the throttle open (the prop's wash on the rudder), stood still or not.
	var steer := -turn*TAXI_TURN*lerpf(0.25,1.0,clampf(maxf(speed/TAXI_FULL,boost/WASH_FULL),0.0,1.0))
	var beta := angle_difference(track,heading)
	if reversing:
		sliding = false
	elif not sliding and speed > SLIDE_MIN:
		# Asked more than the wheels hold, the drift's lean, a power-slide,
		# or already well off its way: it breaks loose.
		var drift_asked := absf(lean) > 0.5 and absf(turn) > DRIFT_ONSET
		if power or drift_asked or absf(steer)*speed > grip or absf(beta) > SLIDE_SLIP:
			sliding = true
			drift_side = 0.0
			out["slide"] = true
	if reversing:
		_in_power = false
		drift_side = 0.0
		# Backing up as a car backs: the stick turns the nose the other way
		# (stick right, the tail goes right); the brake held keeps it going.
		var fwd := Vector2(-sin(heading),-cos(heading))
		var along := minf(_v.dot(fwd),0.0)
		heading += turn*REVERSE_TURN*lerpf(0.25,1.0,clampf(-along/REVERSE_SPEED,0.0,1.0))*delta
		fwd = Vector2(-sin(heading),-cos(heading))
		if brake > 0.3 and boost <= 0.0: along = move_toward(along,-REVERSE_SPEED*brake,REVERSE_PUSH*delta)
		else: along = move_toward(along,0.0,REVERSE_STOP*delta)
		_v = fwd*along
		beta = 0.0
	elif sliding:
		# The slide keeps the side its nose went out to; the stick into it or
		# against it (counter-steer) is how far it holds it out.
		if drift_side == 0.0 or absf(beta) < CATCH and absf(turn) < DRIFT_ONSET:
			drift_side = signf(beta) if absf(beta) > CATCH*0.5 else signf(-turn)
		var into := -turn*drift_side
		# The nose swings to the angle the stick asks; braked, further; with
		# the throttle open too, right round on its wheels.
		var angle := SLIDE_ANGLE
		var rate := PIVOT
		if power:
			angle = lerpf(BRAKE_ANGLE,POWER_ANGLE,boost)
			rate = lerpf(BRAKE_PIVOT,POWER_PIVOT,boost)
		var want := drift_side*angle*(into if into >= 0.0 else -into*DRIFT_COUNTER)
		# Braked, the tail stays where a blip of throttle swung it (never past
		# POWER_ANGLE, however the line is steered away from the nose).
		if power and signf(beta) == signf(want) and absf(beta) > absf(want): want = signf(beta)*minf(absf(beta),POWER_ANGLE)
		var next := move_toward(beta,want,rate*delta)
		heading += next-beta
		beta = next
		# The scrub: the more sideways, the more; the brakes along the wheels.
		var side := sin(beta)
		var loss := ROLL_DRAG*(1.0-boost)+maxf(WHEEL_BRAKE*brake*absf(cos(beta)),SCRUB*side*side)
		var push := boost*ROLL_PUSH*(1.0-load_roll)*(1.0-brake)*cos(beta) if speed < minf(ROLL_TOP,load_top) else 0.0
		speed = maxf(0.0,speed+(push-loss)*delta)
		# The path bends towards the nose, and the stick bends the line:
		# into the slide tighter, against it wider.
		var bend := SLIDE_BEND*(1.0-BRAKE_BEND*brake)*(1.0+LEAN_BEND*absf(lean))
		track += clampf(beta,-bend*delta,bend*delta)
		if speed > SLIDE_MIN: track += drift_side*(into-1.0+absf(lean))*LINE_STEER*_drift_strength()*delta
		beta = angle_difference(track,heading)
		_v = Vector2(-sin(track),-cos(track))*speed
		stats.slide_distance += speed*delta
		if speed > SLIDE_MIN: stats.peak_slip = maxf(float(stats.peak_slip),absf(beta))
		if power and not _in_power: stats.power_slides += 1
		_in_power = power
		if absf(beta) < CATCH and absf(turn) < DRIFT_ONSET or speed < SLIDE_MIN and not power:
			sliding = false
			drift_side = 0.0
			out["caught"] = true
	else:
		_in_power = false
		drift_side = 0.0
		# Gripping: the tail wheel steers and the wheels hold the way it
		# points; slowed straight by the drag and the brakes.
		heading += steer*delta
		var fwd := Vector2(-sin(heading),-cos(heading))
		var along := _v.dot(fwd)
		along = move_toward(along,0.0,(ROLL_DRAG*(1.0-boost)+WHEEL_BRAKE*brake)*delta)
		if along < minf(ROLL_TOP,load_top): along = minf(along+boost*ROLL_PUSH*(1.0-load_roll)*(1.0+SURGE*_surge)*(1.0-brake)*delta,maxf(along,minf(ROLL_TOP,load_top)))
		_v = fwd*along
		beta = 0.0
		# Fast enough, Boost held and the stick back: the nose comes up.
		rotate = boost > 0.0 and brake <= 0.3 and along >= ROTATE_FROM and pull
	plane.heading = heading
	slip = beta
	speed = _v.length()
	if speed > 0.3: _way = _v.normalized()
	var want_grit := clampf(speed*absf(sin(beta))/SPRAY_FULL,0.0,1.0) if sliding else 0.0
	want_grit = maxf(want_grit,SPRAY_BRAKE*brake*clampf(speed/SPRAY_BRAKE_AT,0.0,1.0))
	grit = lerpf(grit,want_grit,1.0-exp(-delta/EASE_GRIT))
	var next_at := at+_v*delta
	if blocked.is_valid() and speed > 0.0 and _blocks(blocked,at,next_at):
		# Into something: stopped short with a thump, never through it.
		if speed >= HIT_FELT: out["hit"] = {"speed":speed}
		_v = Vector2.ZERO
		speed = 0.0
		sliding = false
		next_at = at
	if reversing and speed > 0.0:
		# Backing up never takes it off the land: stopped with its tail at
		# the edge.
		var back := _v.normalized()
		if is_nan(float(floor_at.call(next_at))) or is_nan(float(floor_at.call(next_at+back*REVERSE_LOOK))):
			if not _at_edge: out["edge_behind"] = true
			_at_edge = true
			_v = Vector2.ZERO
			speed = 0.0
			next_at = at
		else: _at_edge = false
	held_by_load = false
	if too_heavy and not reversing and speed > 0.0 and is_nan(float(floor_at.call(next_at+_v.normalized()*REVERSE_LOOK))):
		# Too heavy to fly: the load holds it back at the edge (it won't
		# roll off into a fall it can't climb out of).
		if not _at_edge: out["too_heavy"] = true
		_at_edge = true
		held_by_load = true
		_v = Vector2.ZERO
		speed = 0.0
		next_at = at
	var land := float(floor_at.call(next_at))
	if is_nan(land):
		# Off the land's edge: flying again with the speed it had, a dip
		# first, the slide carried on as the drift's slip.
		stats.off_edge += 1
		out["off_edge"] = {"speed":speed}
		plane.position = Vector3(next_at.x,plane.position.y,next_at.y)
		_lift(speed,0.0,true)
		_dip_speed = speed
		_dip_time = 0.0
		plane.slip = -clampf(beta,-1.2,1.2)
		return
	plane.carry(Vector3(next_at.x,plane.position.y,next_at.y),Vector3(_v.x,0.0,_v.y),speed)
	_place_on(land,floor_at,smoothstep(0.0,TAIL_DOWN,_since_touch))
	# Under power the tail comes up and it rolls on its mains; pulled back,
	# the nose comes up on them; nose up and fast enough, the wheels let go.
	var powering := boost > 0.0 and brake <= 0.3 and not sliding and not reversing
	_tail = move_toward(_tail,smoothstep(TAIL_FROM,TAIL_FULL,speed) if powering else 0.0,delta/TAIL_TIME)
	if not rotate: _rot = move_toward(_rot,0.0,2.0*ROTATE_RATE/ROTATE_NOSE*delta)
	if _tail > 0.0 or _rot > 0.0:
		var was := float(plane.pitch)
		var level := lerpf(was,TAIL_NOSE,_tail)
		if rotate: _rot = minf(1.0,_rot+ROTATE_RATE/maxf(ROTATE_NOSE-level,0.05)*delta)
		var nose := lerpf(level,maxf(ROTATE_NOSE,level),_rot)
		plane.pitch = nose
		plane.position.y += PlaneStrip.contact(nose)-PlaneStrip.contact(was)
	if rotate and _rot >= 1.0 and speed >= LIFT_SPEED+load_lift and not too_heavy:
		stats.lift_offs += 1
		out["lifted"] = {"speed":speed}
		_surge = 0.0
		var nose := float(plane.pitch)
		_lift(speed,nose,false)
		_unstick = 0.0
		_unstick_speed = speed
		_unstick_nose = nose
		_unstick_y = float(plane.position.y)
		return
	# Stopped: slow with the throttle shut or the brakes on; backing up, once
	# the brake is let go.
	var held := (brake <= 0.3 and boost <= 0.0) if reversing else (boost <= 0.0 or brake > 0.3)
	_slow_for = _slow_for+delta if speed < STOP_SPEED and held else 0.0
	if _slow_for >= STOP_HOLD:
		_v = Vector2.ZERO
		plane.set_pace(0.0)
		sliding = false
		slip = 0.0
		grit = 0.0
		var margin := edge_margin(floor_at,Vector2(plane.position.x,plane.position.z),_way)
		if not bool(stats.stopped):
			stats.stopped = true
			stats.time_to_stop = elapsed
			stats.rollout = Vector2(plane.position.x-_touch_at.x,plane.position.z-_touch_at.z).length()
			stats.stop_margin = margin
			stats.stop_grade = last_touch
		reversing = false
		drift_side = 0.0
		_brake_held = 0.0
		_enter(STOPPED)
		out["stopped"] = {"margin":margin}

## Whether the move from `at` to `to` (global XZ) runs into what `blocked`
## finds: in the way there and clear here; or, already in it (a swing of
## the nose, a pivot), going further in: not clear ESCAPE_REACH m on, and
## clear as far back. Deep in either way, it goes, so it never sticks.
func _blocks(blocked: Callable, at: Vector2, to: Vector2) -> bool:
	var y := float(plane.position.y)
	if not bool(blocked.call(Vector3(to.x,y,to.y))): return false
	if not bool(blocked.call(Vector3(at.x,y,at.y))): return true
	var way := (to-at).normalized()
	var on := at+way*ESCAPE_REACH
	if not bool(blocked.call(Vector3(on.x,y,on.y))): return false
	var back := at-way*ESCAPE_REACH
	return not bool(blocked.call(Vector3(back.x,y,back.y)))

## The plane's drift strength (SkyPlane `drift_strength`, `--drift`; 1 for
## a plane without one).
func _drift_strength() -> float:
	var strength: Variant = plane.get("drift_strength")
	return 1.0 if strength == null else float(strength)

## How far on from `at` along `way` the land goes before its edge (m, up to
## MARGIN_REACH).
static func edge_margin(floor_at: Callable, at: Vector2, way: Vector2) -> float:
	var d := 0.0
	while d < MARGIN_REACH:
		if is_nan(float(floor_at.call(at+way*(d+0.25)))): return d
		d += 0.25
	return MARGIN_REACH

## The land's rise (m per m) along x and z under `at`.
static func _gradient(floor_at: Callable, at: Vector2) -> Vector2:
	var here := float(floor_at.call(at))
	if is_nan(here): return Vector2.ZERO
	var g := Vector2.ZERO
	var x := float(floor_at.call(at+Vector2(0.5,0.0)))
	var z := float(floor_at.call(at+Vector2(0.0,0.5)))
	if not is_nan(x): g.x = (x-here)/0.5
	if not is_nan(z): g.y = (z-here)/0.5
	return g

## Sat on its wheels on the land at `land` under it: the tail coming down
## as it rolls on (`settle` 0 at the touch to 1 settled), the touch's hops
## or its squash, a lean out of a slide.
func _place_on(land: float, floor_at: Callable, settle: float) -> void:
	var at := Vector2(plane.position.x,plane.position.z)
	var rest := PlaneStrip.rest(func(p: Vector2) -> float:
		var h := float(floor_at.call(p))
		return land if is_nan(h) else h,at,float(plane.heading))
	var pitch := lerpf(_touch_pitch,rest.y,settle)
	var hops := _hops(_since_touch)
	plane.pitch = pitch-hops*0.6
	plane.bank = lerpf(float(plane.bank),rest.z*settle+SLIDE_LEAN*slip,0.2)
	plane.position.y = rest.w+PlaneStrip.contact(pitch)+hops

## The touch's give, `t` s after it: a greaser's two small hops, or a hard
## one's squash and the little hop after (by its hit), then the settle's.
func _hops(t: float) -> float:
	if _thump_k > 0.0:
		if t < SQUASH_TIME: return -SQUASH*_thump_k*sin(PI*t/SQUASH_TIME)
		t -= SQUASH_TIME
		if t < HOP_TIME: return HOP*_thump_k*sin(PI*t/HOP_TIME)
		t -= HOP_TIME
	if t < SETTLE_TIME.x: return SETTLE.x*sin(PI*t/SETTLE_TIME.x)
	t -= SETTLE_TIME.x
	if t < SETTLE_TIME.y: return SETTLE.y*sin(PI*t/SETTLE_TIME.y)
	return 0.0

## Stood still where it is, on its wheels and tail skid.
func _hold(floor_at: Callable) -> void:
	_v = Vector2.ZERO
	plane.set_pace(0.0)
	slip = 0.0
	var at := Vector2(plane.position.x,plane.position.z)
	var land := float(floor_at.call(at))
	if is_nan(land): return
	_since_touch = INF
	_place_on(land,floor_at,1.0)

## Just off the wheels, heavy: the climb held back and let out, the speed
## slow to build, the nose slow to answer (the unstick's constants).
func _heavy(delta: float, nose_was: float) -> void:
	_unstick += delta
	var u := clampf(_unstick/(UNSTICK_TIME*load_unstick),0.0,1.0)
	var most := _unstick_nose+UNSTICK_NOSE*_unstick
	if float(plane.pitch) > maxf(most,nose_was): plane.pitch = maxf(most,nose_was)
	plane.speed = minf(float(plane.speed),_unstick_speed+UNSTICK_PUSH/load_unstick*_unstick)
	var share := lerpf(UNSTICK_FLOAT,1.0,smoothstep(0.0,1.0,u))
	var climb := float(plane.speed)*sin(float(plane.pitch))
	plane.velocity.y = climb*share if climb > 0.0 else climb
	_unstick_y += float(plane.velocity.y)*delta
	plane.position.y = maxf(_unstick_y,float(plane.position.y)) if u >= 1.0 else _unstick_y
	# Hanging low over the grass, the wheels don't count as a touch.
	_grace = maxf(_grace,0.1)
	if u >= 1.0: _unstick = -1.0

## Off the wheels and flying: at `pace` m/s, the nose at `nose`; off an
## edge (`drop`) it falls a moment before the air catches it.
func _lift(pace: float, nose: float, drop: bool) -> void:
	plane.resume(maxf(pace,SkyPlane.SLOW),nose)
	if drop: plane.airborne = 0.0
	_grace = BOUNCE_GRACE
	_tail = 0.0
	_rot = 0.0
	_unstick = -1.0
	_kick = 0.0
	sliding = false
	reversing = false
	drift_side = 0.0
	slip = 0.0
	grit = 0.0
	_in_power = false
	dive = 0.0
	dive_sink = 0.0
	sink_seen = 0.0
	_enter(AIR)

## The land's steepest slope under `at` (m per m), along the way `v` and
## across it.
static func _slope(floor_at: Callable, at: Vector2, v: Vector3) -> float:
	var way := Vector2(v.x,v.z)
	way = way.normalized() if way.length() > 0.01 else Vector2(0.0,-1.0)
	var side := Vector2(-way.y,way.x)
	var here := float(floor_at.call(at))
	if is_nan(here): return 0.0
	var most := 0.0
	for d: Vector2 in [way,-way,side,-side]:
		var h := float(floor_at.call(at+d*0.6))
		if not is_nan(h): most = maxf(most,absf(h-here)/0.6)
	return most

## Where the wheels set down (global), for the rollout.
func touched_at() -> Vector3:
	return _touch_at

## The speed over the ground while rolling (m/s).
func roll_speed() -> float:
	return _v.length()
