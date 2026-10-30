extends "res://scripts/sky_glide.gd"
## The little plane: how the wanderer flies (scripts/wanderer_eye.gd), a
## toy prop plane in the spirit of an island
## flyover rather than a flight sim. It keeps the glide's rules and its
## shape, so the chase camera, the vapour, the sky and the landing read it
## the same: no stamina, no crashing (it skims the ground, slides under an
## island and is turned aside by its sides, as the glide is), always a way
## up, and the cloud cushion under the floor.
##
## It always has its engine. It cruises at a steady CRUISE_SPEED, quicker
## than the glide, so an island goes by in a few seconds; Boost (held) opens
## the throttle and Brake (held) closes it, never below SLOW, so it never
## stalls. Left and right roll it into a bank and the bank turns it, so a
## turn leans in first and comes round after; let go, it rolls level by
## itself. Up and down pitch it, and let go the nose eases back level.
## Climbing costs a little speed and diving gains some, but the engine
## always pulls it back to the throttle's speed.
##
## Holding a lean (`lean`: -1 left, 1 right) tips it up on a wingtip,
## KNIFE_BANK over, to slip through a gap narrower than its wings; the knife
## edge does not turn it, so it flies on straight, and let go it rolls back
## to its bank.
##
## Turn while on the knife edge and it drifts: the turn comes round
## DRIFT_TURN more again than a banked one, the nose swings in ahead of its
## path (a slip of up to DRIFT_SLIP seconds of turn), and the drift bleeds
## DRIFT_BLEED m/s² off its speed as the price. A small stick (under
## DRIFT_ONSET) is only a correction and doesn't drift, so threading a slit
## stays steady; turning against the lean drifts DRIFT_COUNTER as hard.
## Coming out of a drift held DRIFT_MIN seconds or more gives back up to
## DRIFT_BOOST m/s (full after DRIFT_CHARGE seconds), which the engine
## eases away again. `--drift=<x>` scales all of it (`drift_strength`,
## 1 by default, 0 off). docs/design/knife-drift.md.
##
## A barrel roll (`roll`: -1 left, 1 right, on the frame it is asked for)
## turns it a whole way round its length over ROLL_TIME seconds, with a
## little hop sideways, and it comes out level on the heading it went in
## on. The roll is its own angle (`spin`), on top of the bank: the plane
## is drawn turned by both, while the camera leans only with the bank, so
## the view never spins with it. Each roll counts as a flap, for the whoosh.
##
## Coming in to land (`approach`) it throttles back to LANDING_SPEED and
## comes down as the glide does; a touch slow enough lands, and Boost, a
## lean or a roll calls it off. The wanderer's F lands it by its own sequence
## instead (scripts/plane_landing.gd), which flies it from outside and
## hands it back with `resume`; `engine` spins down when it is parked.
##
## Flaps (`flaps`, 0 up to 1 down; only the hand-flown landing,
## scripts/manual_landing.gd, lowers them) let it fly slower than SLOW for a
## short field: the throttle's speed comes down to FLAP_SPEED, the floor to
## FLAP_SLOW, and it sinks FLAP_SINK m/s more, so an approach with flaps is
## slower and steeper. Boost overrides them, for a go-around.

## Speeds along the path, in metres a second: the cruise the engine holds,
## Boost's and Brake's, the floor it never drops below, the cap a long dive
## reaches, and the speed it comes in to land at.
const CRUISE_SPEED := 14.0
const BOOST_SPEED := 22.0
const BRAKE_SPEED := 8.0
const SLOW := 7.0
const FAST := 30.0
const LANDING_SPEED := 8.0
## The game's plane flies GAME_SPEED times those (cruise, boost and brake
## only; landing, flap and stall speeds stay): the speed the user found had
## "a great sense of speed" at the 2x plane (docs/design/flight-camera.md).
## Its turn rate grows with it (`turn_scale`), so its turn radius stays the
## toy's: the isles' lines were laid for that radius. The game (studies/
## kit_isle.gd) sets it with `use_game_speed`; a bare SkyPlane (the flight
## study, its pinned benches) flies at 1 unless `--plane-speed=` says.
const GAME_SPEED := 1.15
## Endless flight's plane (studies/endless_flight.gd `use_flight_speed`)
## flies FLIGHT_SPEED times the toy's cruise and boost (about 29 and 46
## m/s): the land is wide open, nothing to thread. Its brake comes down to
## FLIGHT_BRAKE of its cruise (never above the toy's scaled brake), its
## dive's cap rises with the speed (FAST times FLIGHT_SPEED over
## GAME_SPEED), and it turns FLIGHT_TURN times the toy's rate (a wider turn
## than the toy's radius: at the full scale the roll would snap round).
## Landing, flap and stall speeds stay, so a hand landing comes in as ever.
const FLIGHT_SPEED := 2.1
const FLIGHT_BRAKE := 0.45
const FLIGHT_TURN := 1.3
## Flaps down: the speed the engine holds, the floor it never drops below
## (m/s), and the extra sink (m/s).
const FLAP_SPEED := 5.5
const FLAP_SLOW := 5.0
const FLAP_SINK := 0.5
## How the speed answers the pitch (m/s² at straight down), and how fast
## the engine brings it back to the throttle's speed (per second).
const SWING := 6.0
const THROTTLE := 0.8
## The bank: the most a held turn leans it (radians), the most it ever
## leans in a turn, and how fast it rolls in and out (seconds). The turn,
## radians a second at a full held bank, follows the bank.
const BANK_HELD := 1.0
const BANK_TOP := 1.2
const EASE_ROLL_IN := 0.16
const TURN_RATE := 1.6
## The mouse turns it directly, and banks it by MOUSE_BANK radians per
## radian a second of turn.
const MOUSE_BANK := 0.35
## The pitch: radians a second at full stick, its limits, and how fast it
## eases level when let go (seconds).
const PITCH_SPEED := 1.4
const PITCH_LIMIT := Vector2(-1.3,1.2)
const EASE_LEVEL := 1.4
## Weight (`--heavy[=<x>]`, `heavy` 0 off to 1, the prototype's; 0 by
## default): the toy flown with mass. Its path swings after the nose rather
## than with it (HEAVY_LAG s at cruise, longer slow), so a pull-up mushes
## and a turn skids before it carries; the dive gains and the climb costs
## HEAVY_SWING more, the engine pulling it back to the throttle's speed
## HEAVY_THROTTLE less hard, so it carries speed out of a dive; the stick
## builds the pitch's rate over HEAVY_PITCH s and the bank comes in
## HEAVY_ROLL slower; a bank sinks it HEAVY_SAG m/s at a right angle (by
## 1 - cos of the bank, the knife edge's tip not counted) unless pulled.
## Never a stall, never a crash: still the toy.
const HEAVY_LAG := 0.32
const HEAVY_SWING := 0.8
const HEAVY_THROTTLE := 0.5
const HEAVY_PITCH := 0.18
const HEAVY_ROLL := 1.0
const HEAVY_SAG := 3.0
## The weight presets (`--weight=`, `use_weight`; scripts/flight_weight.gd):
## the roll on a spring, the turn a beat after the bank, the path bending
## after the nose, the bleed and the mush when slow. `off`, the default
## for a bare SkyPlane, is the flight as it was (the `--heavy` prototype
## above still answers then); endless flight starts on medium.
const FlightWeight = preload("res://scripts/flight_weight.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
## In a weighted preset the drawn bank follows the lean over this (s),
## ahead of the turn's rate, so the plane leans in before it comes round.
const WEIGHT_BANK_EASE := 0.03
## The knife edge: how far over a held lean tips it (radians) and how fast
## it tips in and out (seconds).
const KNIFE_BANK := PI*0.5
const EASE_KNIFE := 0.12
## The drift (a turn on the knife edge): the turn rate's extra share at a
## full drift, the stick it starts at and is full by, how hard a turn against
## the lean drifts, the speed it bleeds (m/s²), the nose's lead over its
## path (seconds of turn), how fast it comes and goes (seconds), and the
## release: the boost (m/s), the hold before any and the hold to the full.
const DRIFT_TURN := 0.5
const DRIFT_ONSET := 0.3
const DRIFT_FULL := 0.8
const DRIFT_COUNTER := 0.5
const DRIFT_BLEED := 1.6
const DRIFT_SLIP := 0.12
const EASE_DRIFT := 0.15
const DRIFT_BOOST := 2.5
const DRIFT_MIN := 0.4
const DRIFT_CHARGE := 1.2
## The barrel roll: seconds round, and the sideways hop (m/s at its middle).
const ROLL_TIME := 0.7
const JINK := 3.0
## Over CEILING the nose is held down to level by CEILING_FADE metres more.
const CEILING_NOSE := -0.05
## Thin air (`use_thin`): over `thin_from` the climb is work. By `thin`, 0
## there to 1 at the preset's top (`top_y`), climbing costs up to
## THIN_SWING times more speed (by the square root of `thin`, so it is
## soon felt), the engine pulls back to its speed THIN_PULL less, and slow (under SOFT_SPAN over the floor) it sinks THIN_MUSH m/s
## more. The nose comes up no further than the climb the engine holds best
## there (the path's rise of target speed x pull / (2 x the climb's cost):
## steep low in the band, a few degrees at the top, eased over THIN_NOSE_EASE
## s), so full back is the best climb, at about half the speed. Over the
## band's last TOP_FALL the climb fades from TOP_CLIMB m/s to nothing at the
## top. The dive is as ever. Under `thin_from` nothing changes.
const THIN_SWING := 12.0
const THIN_PULL := 0.6
const THIN_MUSH := 3.0
const TOP_FALL := 0.15
const TOP_CLIMB := 10.0
const THIN_NOSE_EASE := 0.4

## The barrel roll's own angle (radians, right positive like the bank),
## whether one is under way, and which way.
var spin := 0.0
var rolling := false
var roll_dir := 0.0
## How far it is tipped up on a wingtip, -1 left to 1 right.
var knife := 0.0
## The drift's strength (`--drift=<x>`, 0 off), how far into one it is now
## (0 to 1), the nose's lead over its path (radians, the travel is at
## heading+slip), and how long this one has been held (seconds).
var drift_strength := drift_flag(preload("res://scripts/launch_args.gd").user_args())
## The weight (`--heavy`), the path it flies (a unit vector swinging after
## the nose), the pitch's rate built by the stick (rad/s), and the
## velocity the last step left (set from outside since: the path starts
## again along it).
var heavy := heavy_flag(preload("res://scripts/launch_args.gd").user_args())
## The share of its climb it keeps (1, all of it; a load hung under it
## lowers it from outside, scripts/carry/carry_weights.gd LOAD): only the
## climb, so level flight and the dive are as they were.
var climb_share := 1.0
## Where the air starts to thin and the top of the thin band (world y; INF:
## no thin air, as on the isles), and how far into it the plane is (0 to 1).
var thin_from := INF
var thin_top := INF
var thin := 0.0
var _thin_nose := PITCH_LIMIT.y
## The engine's pull, 1 to 0 (scripts/carry/plane_strain.gd: a part torn
## off in flight kills it): at 0 Boost does nothing, it settles to
## DEAD_GLIDE of cruise, can't climb and sinks DEAD_SINK m/s, so it must
## put down. `sputter` (1 running) shows the engine labouring: the
## propeller and hum (studies/kit_isle.gd multiplies `engine` by it).
var power := 1.0
var sputter := 1.0
const DEAD_GLIDE := 0.75
const DEAD_SINK := 1.6
var _path := Vector3.ZERO
var _pitch_rate := 0.0
## The weight preset's name and knobs (FlightWeight), and whether it is on.
var weight_name := FlightWeight.flag("off")
var weight: Dictionary = FlightWeight.knobs(weight_name)
var weighted := weight_name != "off"
## Read out in a weighted preset, for the rumble and the HUD: the load (g,
## 1 flying straight: speed times the path's turn rate over G, plus one),
## the nose's pitch over the path's (radians; up while it sinks through a
## pull-out), and how soft the controls are (0 to 1, slow).
var g_load := 1.0
var aoa := 0.0
var soft := 0.0
## Near the land (weighted, FlightWeight `low_spans`): how deep into the low
## zone this step flew, 0 over it to 1 at LOW_FULL spans (the square root of
## the share of the way down, so it bites from the zone's top; 0 slow), and the belly's
## clearance over what is under it there (m: the height over it less SKIM;
## INF over nothing or under a span).
var low := 0.0
var low_clear := INF
## Set from outside each frame: true under a roof the ground can't tell
## (a tunnel's bore, studies/endless_flight.gd), where it is never low.
var roofed := false
## What this step's move ran into (weighted only; {} nothing): "kind" ride
## (onto the top of what is under it), brush (a face, turned aside), under
## (an underside) or water; "velocity" the way it was going into it;
## "normal" out of a brushed face. Graded by scripts/endless/flight_contact.gd.
var contact := {}
## Over water (set from outside each frame, scripts/endless/water_contact.gd
## `feel`): the cushion's lift and shudder (m/s up) and its drag (m/s²).
var cushion := 0.0
var cushion_drag := 0.0
## A shove off a scrape (m/s, `scrape`), dying away over BUMP_FADE s.
var bump := Vector3.ZERO
const BUMP_FADE := 0.3
## A scrape turns the path off the surface to this much of the way out.
const SCRAPE_OUT := 0.08
## The surge (0 to 1, set from outside each frame: scripts/endless/
## near_miss.gd's meter spent): the speed driven to SURGE_OVER times Boost's,
## SURGE_PULL times harder than the throttle pulls, the cap lifted to it and
## falling back CAP_FALL m/s² after.
var surge := 0.0
const SURGE_OVER := 1.3
const SURGE_PULL := 2.5
const CAP_FALL := 6.0
var _cap := 0.0
var _buffet_t := 0.0
## The weighted path's heading and pitch (NAN: started again along the
## nose), the lean's rate on its spring (rad/s) and the turn's rate
## following the bank (rad/s).
var _path_h := NAN
var _path_p := 0.0
var _roll_v := 0.0
var _turn := 0.0
var _left := Vector3.INF
## `--plane-speed=<x>` (1 by default, GAME_SPEED in the game): times the
## cruise, boost and brake speeds only; landing, flap and stall speeds stay
## as they are. `--plane-turn=<x>` times the turn rate (by default the same
## as the speed's, so the turn radius stays the toy's; `=1` keeps the old
## rate, a wider turn).
var speed_scale := speed_flag(preload("res://scripts/launch_args.gd").user_args())
var turn_scale := turn_flag(preload("res://scripts/launch_args.gd").user_args(),speed_scale)
## Brake's speed (m/s; 0: BRAKE_SPEED times `speed_scale`) and the cap a
## dive reaches (m/s), set by `use_flight_speed`.
var brake_pace := 0.0
var top := FAST
## The pace (scripts/flight_pace.gd, `use_pace`): times the cruise, Boost,
## the dive's cap (`top`) and the surge; Brake, the floor, flaps, landing
## and takeoff speeds stay. 1 as it was.
var pace_scale := 1.0
var drift := 0.0
var slip := 0.0
var drift_held := 0.0
## The throttle held now: 1 boosting, -1 braking, 0 cruising (for the
## figure's propeller and the hum).
var throttle := 0.0
## The engine running, 0 to 1: the propeller and the hum spin down to
## nothing when it is parked (scripts/plane_landing.gd).
var engine := 1.0
## The lean the keys and stick hold (radians), which turns it, and the
## mouse's and the approach's turn rate, which only lean it.
var _lean := 0.0
var _mouse_rate := 0.0
var _roll_time := 0.0
## The bank the turn alone would give it, under the knife edge.
var _free_bank := 0.0

func launch(from: Vector3, towards: float, pace: float, drop := true) -> void:
	super.launch(from,towards,pace,drop)
	speed = clampf(maxf(pace,CRUISE_SPEED*0.8),SLOW,top_speed())
	pitch = 0.0
	spin = 0.0
	rolling = false
	roll_dir = 0.0
	throttle = 0.0
	engine = 1.0
	_roll_time = 0.0
	_lean = 0.0
	_mouse_rate = 0.0
	knife = 0.0
	drift = 0.0
	slip = 0.0
	drift_held = 0.0
	_free_bank = 0.0
	_weight_reset()
	velocity = forward()*speed

## Flying on from a pose set from outside (a landing called off, a
## takeoff's lift; scripts/plane_landing.gd): at `pace` m/s, the nose at
## `nose`, level, the engine on, nothing turning it.
func resume(pace: float, nose: float) -> void:
	speed = clampf(pace,SLOW,top_speed())
	pitch = clampf(nose,PITCH_LIMIT.x,PITCH_LIMIT.y)
	spin = 0.0
	rolling = false
	roll_dir = 0.0
	approach = false
	airborne = FALL_TIME+CATCH
	engine = 1.0
	_lean = 0.0
	_mouse_rate = 0.0
	knife = 0.0
	drift = 0.0
	slip = 0.0
	drift_held = 0.0
	_free_bank = 0.0
	_roll_time = 0.0
	_weight_reset()
	velocity = forward()*speed

## Parked at `at` on its wheels: nose on `towards`, sat at `nose` and
## `lean` (PlaneStrip `rest`'s pitch and bank), stopped, the engine off,
## everything else as launch leaves it (the parked plane boarded, studies/
## kit_isle.gd `board_parked`).
func park(at: Vector3, towards: float, nose: float, lean: float) -> void:
	launch(at,towards,SLOW,false)
	rest_on(at,nose,lean)
	engine = 0.0

## Sat still on its wheels at `at`, `nose` and `lean` (its heading kept):
## stopped, velocity nothing. A landing's stop (scripts/plane_landing.gd).
func rest_on(at: Vector3, nose: float, lean: float) -> void:
	position = at
	pitch = nose
	bank = lean
	set_pace(0.0)

## Carried along a path from outside (a landing's or takeoff's scripted
## run, a ground roll; scripts/plane_landing.gd, scripts/manual_landing.gd):
## at `at`, moving at `moving` (m/s, the path's, not the nose's: on the
## wheels or flown in, the nose need not point the way it goes) and `pace`
## m/s along the path. Its attitude (heading, pitch, bank) is the caller's.
## The one setter that does not keep velocity along the nose.
func carry(at: Vector3, moving: Vector3, pace: float) -> void:
	position = at
	velocity = moving
	speed = pace

## Flies with the weight preset `preset` (FlightWeight NAMES; off the
## flight as it was). Mid-flight the path starts again along the nose and
## the turn goes on at the rate it had.
func use_weight(preset: String) -> void:
	weight_name = preset if preset in FlightWeight.NAMES else "off"
	weight = FlightWeight.knobs(weight_name)
	weighted = weight_name != "off"
	_path_h = NAN
	_roll_v = 0.0
	_turn = -_lean/BANK_HELD*TURN_RATE*turn_scale
	g_load = 1.0
	aoa = 0.0
	soft = 0.0

## Thin air from `from_y` up to `top_y_at` (world y): the preset's top is its
## FlightWeight `ceiling` share of the way up (`top_y()`).
func use_thin(from_y: float, top_y_at: float) -> void:
	thin_from = from_y
	thin_top = top_y_at

## The highest the plane climbs to in this preset (world y; INF without
## thin air).
func top_y() -> float:
	if not is_finite(thin_from) or not is_finite(thin_top): return INF
	return thin_from+(thin_top-thin_from)*float(weight.get("ceiling",1.0))

func _weight_reset() -> void:
	low = 0.0
	low_clear = INF
	contact = {}
	bump = Vector3.ZERO
	_path_h = NAN
	_roll_v = 0.0
	_turn = 0.0
	_pitch_rate = 0.0 if weighted else _pitch_rate
	g_load = 1.0
	aoa = 0.0

## The weight asked for on the command line: `--heavy` 1, `--heavy=<x>`
## that (0 to 1), else 0.
static func heavy_flag(args: PackedStringArray) -> float:
	for arg in args:
		if arg == "--heavy": return 1.0
		if arg.begins_with("--heavy="): return clampf(float(arg.substr(8)),0.0,1.0)
	return 0.0

## The drift strength asked for on the command line (`--drift=<x>`), else 1.
static func drift_flag(args: PackedStringArray) -> float:
	for arg in args:
		if arg.begins_with("--drift="): return maxf(0.0,float(arg.substr(8)))
	return 1.0

static func speed_flag(args: PackedStringArray, otherwise := 1.0) -> float:
	for arg in args:
		if arg.begins_with("--plane-speed="): return maxf(0.1,float(arg.substr(14)))
	return otherwise

static func turn_flag(args: PackedStringArray, speed: float) -> float:
	for arg in args:
		if arg.begins_with("--plane-turn="): return maxf(0.1,float(arg.substr(13)))
	return speed

## The game's speed: `--plane-speed=` or GAME_SPEED.
static func game_speed() -> float:
	return speed_flag(preload("res://scripts/launch_args.gd").user_args(),GAME_SPEED)

## Flies at the game's speed (and turns to match, unless `--plane-turn=`).
func use_game_speed() -> void:
	speed_scale = game_speed()
	turn_scale = turn_flag(preload("res://scripts/launch_args.gd").user_args(),speed_scale)

## Flies at endless flight's speed (FLIGHT_SPEED, or `--plane-speed=`):
## brake, cap and turn to match (`--plane-turn=` still wins).
func use_flight_speed() -> void:
	var args: PackedStringArray = preload("res://scripts/launch_args.gd").user_args()
	speed_scale = speed_flag(args,FLIGHT_SPEED)
	turn_scale = turn_flag(args,minf(speed_scale,FLIGHT_TURN))
	brake_pace = minf(BRAKE_SPEED*speed_scale,maxf(BRAKE_SPEED*GAME_SPEED,CRUISE_SPEED*speed_scale*FLIGHT_BRAKE))
	top = maxf(FAST,FAST*speed_scale/GAME_SPEED)

## Flies at the pace `scale` (scripts/flight_pace.gd): the cruise, Boost,
## the dive's cap and the surge times it. Brake keeps its speed (it was set
## from the unpaced cruise), as do the floor, flaps and landing. Mid-flight
## the speed eases to the new throttle's as ever.
func use_pace(scale: float) -> void:
	pace_scale = maxf(scale,0.1)

## The speed the engine holds with the throttle let be (m/s).
func cruise() -> float:
	return CRUISE_SPEED*speed_scale*pace_scale

## The speeds Boost and Brake hold (m/s).
func boost_speed() -> float:
	return BOOST_SPEED*speed_scale*pace_scale

## The cap a long dive reaches (m/s): `top` at the pace.
func top_speed() -> float:
	return top*pace_scale

func brake_speed() -> float:
	return brake_pace if brake_pace > 0.0 else BRAKE_SPEED*speed_scale

## The direction it travels: the nose's, swung back by the drift's slip.
func travel() -> Vector3:
	var h := heading+slip
	return Vector3(-sin(h)*cos(pitch),sin(pitch),-cos(h)*cos(pitch))

## One step. `input` holds:
##   turn, pitch: -1..1 held rates (keys, stick), right and nose-up positive;
##   look: Vector2 of radians to turn and pitch directly (the mouse);
##   boost, brake: bools (or 0..1 for triggers);
##   lean: -1..1 held, a knife edge to that side;
##   roll: -1 or 1 on the frame a barrel roll is asked for, else 0;
##   flaps: 0 up to 1 down (absent: up).
## `ground` and `air` are as for the glide.
func step(delta: float, input: Dictionary, ground: Callable, air := Callable()) -> void:
	airborne += delta
	# Set from outside since the last step (launched, resumed, carried,
	# turned aside): the heavy path starts again along it.
	if _left == Vector3.INF or not velocity.is_equal_approx(_left):
		_path = Vector3.ZERO
		_path_h = NAN
	var here: Dictionary = air.call(position) if air.is_valid() else {}
	wind = here.get("wind",Vector3.ZERO)
	in_jet = float(here.get("jet",0.0))
	in_thermal = float(here.get("thermal",0.0))
	# A gust's shove on the airframe (rad/s; the dragon's blast, scripts/
	# dragon_gale.gd `plane_gust`): it swings the nose and tips the wings
	# and pitch, and the plane's own easing brings it back.
	var shove: Vector3 = here.get("shove",Vector3.ZERO)
	var look: Vector2 = input.get("look",Vector2.ZERO)
	var deep := clampf((floor_y-position.y)/CATCH_DEPTH,0.0,1.0)
	var boost := clampf(float(input.get("boost",0.0)),0.0,1.0)*power
	var brake := clampf(float(input.get("brake",0.0)),0.0,1.0)
	throttle = boost-brake
	var turn := clampf(float(input.get("turn",0.0)),-1.0,1.0)
	var steer := clampf(float(input.get("pitch",0.0)),-1.0,1.0)
	var asked := signf(float(input.get("roll",0.0)))
	if approach and (boost > 0.0 or asked != 0.0 or float(input.get("lean",0.0)) != 0.0): approach = false
	# The barrel roll: once round, eased in and out, then level again.
	if asked != 0.0 and not rolling:
		rolling = true
		roll_dir = asked
		_roll_time = 0.0
		flaps += 1
	var hop := 0.0
	if rolling:
		_roll_time += delta
		var t := clampf(_roll_time/ROLL_TIME,0.0,1.0)
		spin = roll_dir*TAU*smoothstep(0.0,1.0,t)
		hop = roll_dir*JINK*sin(PI*t)
		if t >= 1.0:
			rolling = false
			spin = 0.0
	# Roll to turn: the keys and stick lean it over and the lean turns it;
	# the mouse turns it directly and leans it a little; coming in to land
	# it turns itself to the target.
	var aim := _aim(delta) if approach and is_zero_approx(turn) and is_zero_approx(look.x) else 0.0
	# Weighted: slow (flaps up) the stick goes soft; the lean rides a spring.
	var firm := 1.0
	if weighted:
		var flaps_in := clampf(float(input.get("flaps",0.0)),0.0,1.0)*(1.0-boost)
		var floor_speed := lerpf(SLOW,FLAP_SLOW,flaps_in)
		soft = (1.0-smoothstep(floor_speed,floor_speed+FlightWeight.SOFT_SPAN,speed))*(1.0-flaps_in)
		firm = lerpf(1.0,float(weight.soft_keep),soft)
		_roll_spring(turn*firm*BANK_HELD,delta)
	else:
		_lean = lerpf(_lean,turn*BANK_HELD,_ease(EASE_ROLL_IN*(1.0+HEAVY_ROLL*heavy),delta))
	# On the knife edge a real turn of the stick drifts: tighter, nose in.
	var lean_in := clampf(float(input.get("lean",0.0)),-1.0,1.0)
	var want := 0.0
	if drift_strength > 0.0 and absf(knife) > 0.5 and absf(lean_in) > 0.5 and not rolling:
		want = smoothstep(DRIFT_ONSET,DRIFT_FULL,absf(turn))
		if signf(turn) != signf(knife): want *= DRIFT_COUNTER
	drift = lerpf(drift,want,_ease(EASE_DRIFT,delta))
	var rate := -_lean/BANK_HELD*TURN_RATE*turn_scale*(1.0+DRIFT_TURN*drift_strength*drift)
	# Weighted, the turn comes round a beat after the bank.
	if weighted:
		_turn = lerpf(_turn,rate,_ease(maxf(float(weight.turn_lag),0.0001),delta))
		rate = _turn
	heading += rate*delta-look.x+aim+shove.y*delta
	slip = lerpf(slip,-rate*DRIFT_SLIP*drift,_ease(EASE_DRIFT,delta))
	var boost_out := 0.0
	if want > 0.25: drift_held += delta
	elif drift_held > 0.0:
		if drift_held >= DRIFT_MIN: boost_out = DRIFT_BOOST*drift_strength*clampf(drift_held/DRIFT_CHARGE,0.0,1.0)
		drift_held = 0.0
	_mouse_rate = lerpf(_mouse_rate,(look.x-aim)/maxf(delta,0.0001),_ease(EASE_TURN,delta))
	_free_bank = lerpf(_free_bank,clampf(_lean+_mouse_rate*MOUSE_BANK,-BANK_TOP,BANK_TOP),_ease(WEIGHT_BANK_EASE if weighted else EASE_TURN,delta))
	if shove != Vector3.ZERO: _free_bank = clampf(_free_bank+shove.z*delta,-BANK_TOP,BANK_TOP)
	# The knife edge tips it up on a wingtip over the turn's bank.
	knife = lerpf(knife,clampf(float(input.get("lean",0.0)),-1.0,1.0),_ease(EASE_KNIFE,delta))
	bank = lerpf(_free_bank,signf(knife)*KNIFE_BANK,absf(knife))
	# Weighted, low and fast over the land the helping hand lets go.
	if weighted: _low_zone(ground)
	# Pitch: the stick and mouse steer it; let go, it eases level, or down
	# the approach's slope (low and fast, weighted: down a touch, so it
	# settles); under the floor the cushion lifts the nose.
	# Heavy, the stick builds the pitch's rate rather than setting it.
	if weighted: _pitch_rate = lerpf(_pitch_rate,steer*firm*PITCH_SPEED,_ease(maxf(float(weight.pitch_build),0.0001),delta))
	else: _pitch_rate = lerpf(_pitch_rate,steer*PITCH_SPEED,_ease(HEAVY_PITCH*heavy,delta)) if heavy > 0.0 else steer*PITCH_SPEED
	pitch += look.y+_pitch_rate*delta
	if is_zero_approx(steer) and is_zero_approx(look.y):
		var rest := approach_pitch(ground) if approach else 0.0
		# Over the pace, so the settle sinks as many m/s at any pace.
		if low > 0.0 and not approach: rest = lerpf(rest,float(weight.settle_pitch)/pace_scale,low)
		pitch = lerpf(pitch,rest,_ease(EASE_LEVEL,delta))
	pitch += shove.x*delta
	if deep > 0.0: pitch = lerpf(pitch,CUSHION_PITCH,_ease(0.5,delta)*deep)
	# Thin air: the climb costs more speed and the engine pulls back weaker;
	# the nose comes up only as far as the best climb there.
	var tops := top_y()
	thin = clampf((position.y-thin_from)/maxf(tops-thin_from,1.0),0.0,1.0) if is_finite(tops) else 0.0
	var pull := THROTTLE*(1.0-THIN_PULL*thin)
	var nose_top := lerpf(PITCH_LIMIT.y,CEILING_NOSE,clampf((position.y-ceiling_y)/CEILING_FADE,0.0,1.0))
	if thin > 0.0:
		var cost := SWING*(1.0+THIN_SWING*sqrt(thin))*(1.0 if weighted else 1.0+HEAVY_SWING*heavy)
		var pulls := pull*(1.0+SURGE_PULL*surge if weighted else 1.0-HEAVY_THROTTLE*heavy)
		var best := (cruise()+boost*(boost_speed()-cruise()))*pulls/(2.0*cost)
		_thin_nose = lerpf(_thin_nose,asin(minf(best,1.0)),_ease(THIN_NOSE_EASE,delta))
		nose_top = minf(nose_top,_thin_nose)
	else: _thin_nose = PITCH_LIMIT.y
	pitch = clampf(pitch,PITCH_LIMIT.x,nose_top)
	# Speed: the engine pulls it to the throttle's speed; the climb and the
	# dive swing it either side.
	var target := cruise()+boost*(boost_speed()-cruise())-brake*(cruise()-brake_speed())
	if power < 1.0: target = lerpf(CRUISE_SPEED*DEAD_GLIDE*speed_scale,target,power)
	if approach: target = minf(target,LANDING_SPEED)
	# Flaps down slow it and lower its floor; Boost takes them over.
	var flap := clampf(float(input.get("flaps",0.0)),0.0,1.0)*(1.0-boost)
	target = lerpf(target,minf(target,FLAP_SPEED),flap)
	# The surge drives it past Boost, flaps or not.
	if surge > 0.0: target = lerpf(target,boost_speed()*SURGE_OVER,surge)
	var slow := lerpf(SLOW,FLAP_SLOW,flap)
	# Heavy, the climb and dive are the path's, not the nose's.
	var path: Vector3
	var climb: float
	var bleed := 0.0
	if weighted:
		path = _weight_path(delta)
		climb = path.y
		# Pulling and turning bleed it: a g past one costs `bleed` m/s².
		bleed = float(weight.bleed)*(g_load-1.0)
		var swing := SWING*(1.0+THIN_SWING*sqrt(thin)) if climb > 0.0 else SWING
		speed += (-swing*climb-pull*(1.0+SURGE_PULL*surge)*(speed-target)-DRIFT_BLEED*drift_strength*drift-bleed)*delta+boost_out
	else:
		path = _heavy_path(delta) if heavy > 0.0 else travel()
		climb = path.y if heavy > 0.0 else sin(pitch)
		var swing := SWING*(1.0+THIN_SWING*sqrt(thin)) if climb > 0.0 else SWING
		speed += (-swing*(1.0+HEAVY_SWING*heavy)*climb-pull*(1.0-HEAVY_THROTTLE*heavy)*(speed-target)-DRIFT_BLEED*drift_strength*drift)*delta+boost_out
	if surge > 0.0: _cap = maxf(_cap,boost_speed()*SURGE_OVER)
	_cap = maxf(top_speed(),_cap-CAP_FALL*delta)
	speed = clampf(speed-cushion_drag*delta,slow,_cap)
	lift = clampf((floor_y-position.y)*CUSHION,0.0,CUSHION_MAX)
	var fall := FALL*minf(airborne,FALL_TIME)*(1.0-smoothstep(FALL_TIME,FALL_TIME+CATCH,airborne))
	var drop := approach_drop(ground) if approach else 0.0
	var side := Vector3(cos(heading),0.0,-sin(heading))
	var sag := HEAVY_SAG*heavy*(1.0-cos(_free_bank))
	# Weighted: the bank's sag, and slow it mushes down.
	if weighted: sag = float(weight.sag)*(1.0-cos(_free_bank))+float(weight.mush)*soft
	# Thin air: slow, it mushes down more.
	if thin > 0.0: sag += THIN_MUSH*thin*(1.0-smoothstep(slow,slow+FlightWeight.SOFT_SPAN,speed))
	# Low and fast (weighted): it settles toward the land, and the air there
	# buffets it.
	var shake := 0.0
	if low > 0.0:
		sag += float(weight.settle)*low
		_buffet_t += delta
		var bt := _buffet_t*TAU
		shake = float(weight.buffet)*low*clampf(speed/cruise(),0.5,1.6)*(sin(bt*5.3)*0.6+sin(bt*8.9+1.3)*0.4)
	var along := path*speed
	if climb_share*power < 1.0 and along.y > 0.0: along.y *= climb_share*power
	# Near the top the climb fades to nothing.
	if thin > 1.0-TOP_FALL and along.y > 0.0: along.y = minf(along.y,TOP_CLIMB*(1.0-thin)/TOP_FALL)
	# The guard in a tight place (SkyGlide `guide`).
	var push := _guard(delta)
	velocity = along+side*hop+Vector3.UP*(lift-fall-drop-FLAP_SINK*flap-sag-DEAD_SINK*(1.0-power)+shake+cushion)+wind+push
	if bump != Vector3.ZERO:
		velocity += bump
		bump *= exp(-delta/BUMP_FADE)
		if bump.length() < 0.05: bump = Vector3.ZERO
	var was := position
	var moved := velocity
	position += velocity*delta
	if keep.is_valid(): position = keep.call(position)
	_skim(delta,ground,was)
	var dry := position.y
	_water(delta)
	if weighted: _note_contact(moved,position.y > dry)
	speed = maxf(speed,slow)
	_left = velocity

## The low zone this step (weighted): the belly's clearance over what is
## under it (`low_clear`) and how deep into the zone that is (`low`), fast
## only. Under a span or a roof it is never low.
func _low_zone(ground: Callable) -> void:
	low = 0.0
	low_clear = INF
	if roofed: return
	var body := _solid(ground,position)
	var top := water
	if body != Vector2.INF:
		if position.y < body.y: return
		top = maxf(top,body.x)
	if top == -INF: return
	low_clear = position.y-top-SKIM
	var spans := float(weight.low_spans)*WorldScale.span
	if spans <= 0.0: return
	var slow_end := FlightWeight.LOW_SLOW
	var fast := smoothstep(slow_end,maxf(cruise()*FlightWeight.LOW_FAST,slow_end+1.0),speed)
	var full := FlightWeight.LOW_FULL*WorldScale.span
	low = sqrt(clampf((spans-low_clear)/maxf(spans-full,0.01),0.0,1.0))*fast

## What this step's move ran into (`contact`), from what the skim did.
func _note_contact(moved: Vector3, wet: bool) -> void:
	contact = {}
	if wet: contact = {"kind":"water","velocity":moved}
	elif brushing: contact = {"kind":"brush","velocity":moved,"normal":brush_normal}
	elif under_rock: contact = {"kind":"under","velocity":moved}
	elif skimming: contact = {"kind":"ride","velocity":moved}

## The way it travels now: the weighted path's, else the nose's.
func path_now() -> Vector3:
	if weighted and not is_nan(_path_h): return Vector3(-sin(_path_h)*cos(_path_p),sin(_path_p),-cos(_path_h)*cos(_path_p))
	return travel()

## Scraped along a surface (`normal` out of it; scripts/endless/
## flight_contact.gd): `keep` of the speed kept, the path turned off the
## surface (SCRAPE_OUT of the way out), the nose with it where it pointed in,
## and a shove of `kick` m/s out of it dying away (`bump`). `out` in place of
## SCRAPE_OUT: a knife slot's glance (KnifeGlance) turns it only along.
func scrape(normal: Vector3, keep: float, kick: float, out := SCRAPE_OUT) -> void:
	speed = maxf(SLOW,speed*keep)
	var path := path_now()
	var into := path.dot(normal)
	if into < out: path = (path+normal*(out-into)).normalized()
	if Vector2(path.x,path.z).length() > 0.01: _path_h = atan2(-path.x,-path.z)
	else: _path_h = heading+slip
	_path_p = asin(clampf(path.y,-1.0,1.0))
	if forward().dot(normal) < 0.0:
		if normal.y > 0.5: pitch = maxf(pitch,_path_p)
		elif normal.y < -0.5: pitch = minf(pitch,_path_p)
		else: heading = _path_h-slip
	bump = normal*kick
	velocity = path*speed+bump
	_left = velocity

## Through a tree it knocked down (scripts/endless/tree_knock.gd): `keep`
## of the speed kept, the nose and path turned `yaw` rad and flying on that
## way, and a shove of `shove` m/s dying away (`bump`).
func knock(keep: float, shove: Vector3, yaw: float) -> void:
	speed = maxf(SLOW,speed*keep)
	heading += yaw
	if not is_nan(_path_h): _path_h += yaw
	bump = shove
	velocity = path_now()*speed+bump
	_left = velocity

## The lean on its spring (critically damped, `roll_hz`), towards `goal`
## radians: the roll's rate builds and settles. Stepped finer than a frame.
func _roll_spring(goal: float, delta: float) -> void:
	var w := float(weight.roll_hz)
	if w <= 0.0:
		_lean = goal
		_roll_v = 0.0
		return
	var n := maxi(1,ceili(delta*w/0.12))
	var h := delta/n
	for i in n:
		_roll_v += ((goal-_lean)*w*w-_roll_v*2.0*w)*h
		_lean += _roll_v*h

## The weighted path: its heading bends after the nose's (`travel`, with
## the drift's slip) over `yaw_lag` s and its pitch over `pitch_lag` s, at
## cruise, longer slower (FlightWeight LAG_SCALE); started again along the
## nose. Sets `g_load` from how fast the path turns, and `aoa`.
func _weight_path(delta: float) -> Vector3:
	var nose_h := heading+slip
	if is_nan(_path_h):
		_path_h = nose_h
		_path_p = pitch
	var was := Vector3(-sin(_path_h)*cos(_path_p),sin(_path_p),-cos(_path_h)*cos(_path_p))
	var scale := clampf(cruise()/maxf(speed,SLOW),FlightWeight.LAG_SCALE.x,FlightWeight.LAG_SCALE.y)
	_path_h += angle_difference(_path_h,nose_h)*_ease(maxf(float(weight.yaw_lag)*scale,0.0001),delta)
	_path_p = lerpf(_path_p,pitch,_ease(maxf(float(weight.pitch_lag)*scale,0.0001),delta))
	var path := Vector3(-sin(_path_h)*cos(_path_p),sin(_path_p),-cos(_path_h)*cos(_path_p))
	var bend := was.angle_to(path)/delta if delta > 0.0 else 0.0
	g_load = 1.0+speed*bend/FlightWeight.G
	aoa = pitch-_path_p
	return path

## The heavy path: swung after the nose (`travel`) over HEAVY_LAG s at
## cruise, longer the slower it goes; started again along the nose.
func _heavy_path(delta: float) -> Vector3:
	var nose := travel()
	if _path == Vector3.ZERO: _path = nose
	var lag := HEAVY_LAG*heavy*clampf(CRUISE_SPEED*speed_scale/maxf(speed,SLOW),0.6,2.0)
	_path = _path.slerp(nose,_ease(lag,delta)).normalized()
	return _path
