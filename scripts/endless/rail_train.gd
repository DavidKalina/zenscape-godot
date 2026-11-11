extends Node3D
## A box train on a rail path (docs/design/endless-flight/spec-railroad.md, lane
## `train`): an engine, its tender and a string of cars, each a plain block, run
## along `path` (the rail path contract: `length`, `pose(s, track)`, `kind`) on
## one track by its timetable (rail_timetable.gd). Each car drawn by its model
## (rail_train_look.gd: assets/models/train/<kind>.glb, its wheels and rods turned
## with the train's run, the smash car's plugs thrown and put back), its solid the
## blocks here, which follow the models (`_parts`, the engine's ENGINE); with
## --train-greybox, or a kind with no model, the blocks are drawn instead. Nobody
## aboard.
##
## Built only near the plane (RailTrains makes and frees it): its look within
## RailTrains' LOOK_NEAR, its solid (below) only within SOLID_NEAR (`set_solid`).
##
## Its solid, as the pirate ship's: each car one record in LandArches `loose`
## (`xf`, `inv` its whole frame, the bed's grade too), rewritten each frame
## (`before`), so plane_ground, _blocked and the camera read it where it is now;
## and a StaticBody on layer 1 a car for the wing rays. The ship gets away with
## that because she moves 0.15 m a frame, inside the pad her solids are grown by.
## A train moves 0.53 m a frame at 32 m/s, and a car that moves onto the plane
## would leave its middle inside the car's solid, which SkyGlide can only lift
## out of, onto the car's roof (a pop of up to 9 m). So before the plane's move
## (`keep_out`) the plane is held out of every car the way the car came at it, in
## the car's own frame: onto the face it crossed (the car's motion seen from the
## plane), never further than the car moved, so it is neither carried nor flung.
## A car that ran into the plane is a touch like any other (`after` makes it the
## plane's `contact`), and every touch of a car is graded by the speed into it
## relative to the car (`relative`, from FlightContact): a plane level with a car
## that drifts onto its side scrapes it; the engine run into nose first crashes.
##
## Its frame for each car: origin on the bed at the car's middle, -z forward
## (the way the train runs), x to the right, y up. Cars sit between two bogies
## BOGIE m in from each end, each on the path, so a car on a curve cuts its chord.
##
## The cars (CARS: a mixed train, 24 cars) alternate tall and low, so flying the
## length is a rhythm: pop over a boxcar, dip over a flatcar or an open wagon.
## The specials are openings in the car's frame (`holes`, for the camera and the
## drivers), each with the way it is flown (`way`), and sized for that way at
## cruise relative to the moving car:
## - "slide": across, angled from alongside so the plane keeps the train's pace
##   (cruise, about 30 degrees off the track): a straight slide through, so the
##   opening along the car is its toy width's (WorldScale.opening).
## - "square": straight across at cruise. The car runs on SPEED/CRUISE of the
##   width crossed while the plane crosses it, so the opening along the car is the
##   toy width's plus that drift (`square`).
## - "along": down the car's length from behind, creeping up at cruise or on
##   Boost: a corridor, its cross section the toy widths'.
## The openings:
## - the doors car, a boxcar with both doors slid open, its doorway (`door_wide`
##   x `door_high`, of TOY_DOOR, TOY_DOOR_HIGH) a slot across the car under its
##   roof: slide.
## - the stock car: the doors car's doorway in a slatted cattle car: slide.
## - the gate car: the doors car's doorway, its doors sliding shut and open again
##   on the train's clock (`gate_open`), each leaf a solid of its own that moves
##   with it (`movers`): slide, through while they're open.
## - the log car: two bundles on a flat, the gap between them (`log_gap`, of
##   TOY_THREAD) open above: square.
## - the truss: a bridge truss section on a flat, the middle panel of either side
##   truss open (`door_wide` x `truss_high`), the end panels closed: slide.
## - the crane's idler: the crane car's boom slung back over the flat behind it,
##   `boom_low` over the bed: square, under the boom.
## - the coaches' gap: each coach's ends open platforms under its roof's hoods,
##   so two coaches coupled leave a doorway between their end walls (`platform`
##   each, door_wide in all), over the railings, under the hoods (`door_high`):
##   slide.
## - the run: two open-ended boxcars and a culvert car between them, their
##   corridors (`smash_wide` x `smash_high`, end to end and past their ends to
##   the coupling) lined up: along, the three cars in one.
## - the smash car, in the pirate ship's manner: a hollow car, the run's
##   corridor, shut at each end by a cracked plate, each its own record in
##   `loose` with a `strike` (SurgeSmash `_hit`). A surge roll breaks the plate
##   it meets; while the plane is in the corridor the surge is held hot
##   (`_smash_step`), so the far plate breaks on the way out. The plates come
##   back once the plane is RESEAL_FAR m off (`_reseal`).
## In a corridor (the run's and the smash car's: `inner`) a touch of the walls,
## roof or floor glances (`way_off`, read by FlightContact), but by a smash
## plate still shut it is graded as anywhere.
##
## Its place is a pure function of the clock: its timetable's `at(time)`, the
## nose's odometer `d` (m along its own track) and s (`head`); each car's bogies
## so many metres of its own track behind the nose (`place`). A clock that jumps
## moves it at once, with no push on the plane (`before`).
##
## Knobs: --train-speed=<m/s> (SPEED), --train-keep=0 (no keep-out: the A/B of
## what it fixes), --full-meter (the meter filled again each time the smash car's
## plates come back, as the pirate ship's).

const WorldScale = preload("res://scripts/world_scale.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const TestPath = preload("res://scripts/endless/rail_test_path.gd")
const Timetable = preload("res://scripts/endless/rail_timetable.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const Look = preload("res://scripts/endless/rail_train_look.gd")

## A bit under the plane's cruise (36.75): at cruise it creeps up the train a car
## at a time, Boost runs it up to the engine.
const SPEED := 32.0
## The plane's cruise in the endless game (m/s: SkyPlane `cruise()` there), what
## a square crossing's drift is sized by (`square`).
const CRUISE := 36.75
## Every car's width (no wider than the path's CAR_WIDTH: the tracks' gap is the
## path's, `track_gap`), and its floor over the bed (m): over the wheels.
const WIDE := 6.0
const FLOOR := 1.4
## How far a car's underframe reaches under the bed (m): down into it, so
## nothing flies under a car where the bed stands off the land or the water.
const UNDER := 2.0
## The gap between two cars (m, coupler to coupler) and each bogie's way in
## from its car's end.
const GAP := 1.6
const BOGIE := 3.0
## The train, front to back: [kind, length, height over the bed] (m): a mixed
## train, freight, then two coaches and the caboose, 549 m (the stations'
## platforms are as long). Easy and hard by turns, low between tall: a square
## log gap, the gate's timed doorway, the stock car's doorway; the run (open-ended
## boxcar, culvert, open-ended boxcar: 70 m along inside) with two low cars
## ahead of it to climb out over (as the smash car's) and a flat behind to drop
## onto; a dip, the truss, the crane's boom over its idler, a doorway,
## the second log gap; two flats, the smash car, a flat; the coaches' gap. The
## smash car has low cars either side: in over the flat behind it, out over the
## two ahead (a surge runs up the train at 40 m/s or more: one flat's length is
## half a second to pull up over the car past it, two give a second).
const CARS := [
	["engine",22.0,9.0],["tender",12.0,6.0],
	["box",24.0,9.0],["logs",22.0,6.5],["gate",24.0,9.0],["stock",24.0,9.0],
	["open",20.0,4.2],["flat",20.0,2.6],["thru",24.0,9.0],["culvert",20.0,9.0],
	["thru",24.0,9.0],["flat",20.0,2.6],["truss",24.0,8.5],["crane",20.0,9.0],
	["flat",20.0,2.6],["doors",24.0,9.0],["logs",22.0,6.5],["flat",20.0,2.6],
	["flat",20.0,2.6],["smash",24.0,9.0],["flat",20.0,2.6],["coach",24.0,8.5],
	["coach",24.0,8.5],["van",14.0,7.5]]
## The kinds with a corridor down their length (`inner`): the run's and the
## smash car's, all the same cross section, so lined up they are one.
const CORRIDOR := ["thru","culvert","smash"]
## The culvert car's load: CULVERTS concrete box sections end to end on a well
## flat, CULVERT_GAP m apart, CULVERT_IN m in from the car's ends, their walls
## out to CULVERT_SIDE m off the middle (the corridor's walls inside them).
const CULVERTS := 3
const CULVERT_GAP := 1.0
const CULVERT_IN := 0.2
const CULVERT_SIDE := 2.95
## The gate car's door leaves: LEAF m thick on the car's sides, DOOR_OVER m over
## the doorway's head and their rollers ROLLERS m over that; open GATE_OPEN s, sliding shut over GATE_SLIDE s, shut
## GATE_SHUT s, sliding open again over GATE_SLIDE s, by the train's clock.
const LEAF := 0.15
const DOOR_OVER := 0.3
const ROLLERS := 0.25
const GATE_OPEN := 3.2
const GATE_SLIDE := 1.2
const GATE_SHUT := 1.0
## A flatcar's deck (m over the bed): its height, and what the log bundles and
## the crane stand on.
const DECK := 2.6
## The open wagon's load heaped over its sides (m), inset from them by HEAP_IN of
## its width and length.
const HEAP := 0.8
const HEAP_IN := 0.7
## The doors car's doorway: toy widths (WorldScale.opening; 10 m along the car
## and 6 m high at the defaults), and the least of the car's wall either side and
## of its roof over the doorway (m).
const TOY_DOOR := 5.0
const TOY_DOOR_HIGH := 3.0
const JAMB_LEAST := 2.0
const HEAD_LEAST := 0.6
## The stock car's slats: the dark gaps between them, every SLAT m up its walls
## (drawn only: the walls are solid, not flown between the slats).
const SLAT := 0.75
## The log car's gap between its two bundles, along the car, flown square: the
## thread's toy width (WorldScale.opening: 7 m at the defaults) and the drift
## over the car's width (`square`: 12.2 m in all), each bundle at least
## BUNDLE_LEAST m long and LOG_IN m in from the car's ends.
const TOY_THREAD := 3.5
const BUNDLE_LEAST := 3.0
const LOG_IN := 0.3
## The truss on its flat: each side truss TRUSS_SIDE m thick in from the car's
## side and TRUSS_IN m in from its ends, its chords CHORD m deep. Its middle panel
## (door_wide along, `truss_high` up from the deck to the top chord) is open
## either side; the end panels are closed (a lattice too fine to fly, drawn as a
## plate with its braces). Its flat's deck is lowered to fit the opening under
## the car's top (`truss_floor`), at least TRUSS_DECK_LEAST over the floor.
const TRUSS_SIDE := 0.5
const TRUSS_IN := 0.6
const CHORD := 0.4
const TRUSS_DECK_LEAST := 0.3
## The wrecking crane: its boom BOOM_WIDE across, slung back from its gantry over
## the car behind (its idler) BOOM_OVER m past the crane's end, under the car's
## top; under it over the idler's deck at least the door's height clear
## (`boom_low`), and at least BOOM_LEAST m of boom.
const BOOM_WIDE := 1.6
const BOOM_OVER := 14.0
const BOOM_LEAST := 0.3
## The coaches: each end an open platform (`platform` m, so two coupled leave
## door_wide between their end walls), under a hood of the roof HOOD m deep; its
## railings RAIL_BAR m thick, their top the opening's floor (`coach_rail`).
const HOOD := 0.4
const RAIL_BAR := 0.15
## The smash car's corridor: toy widths (5.2 m wide, 7 m high at the defaults),
## the least of its walls (m), its plates' thickness (m), how near a plate still
## shut a touch is the plate's (graded, not glanced; m), and how far off the plane
## is when the plates come back (m).
const TOY_SMASH_WIDE := 2.6
const TOY_SMASH_HIGH := 3.5
const WALL_LEAST := 0.2
const PLATE := 0.6
const END_ROOM := 2.0
const RESEAL_FAR := 150.0
## The keep-out: a car is asked only with the plane within its half length plus
## NEAR m of its middle; a plane already inside (its roll grew its reach by a
## car's side) is put out the nearest way if that is under KEEP_MOST m, else left
## to SkyGlide; EASE m more than the face, so the next test is clear.
const NEAR := 12.0
const KEEP_MOST := 1.2
const EASE := 0.02
## A car that runs into the plane: its speed into the plane given to the plane's
## own (when the face is at least CATCH_ALONG ahead of its way) or as a shove,
## at most CATCH_MOST m/s (more is a crash anyway).
const CATCH_ALONG := 0.25
const CATCH_MOST := 12.0
## A touch (of stone) is a car's if its point is within this of the car's solid
## (m): FlightContact's point for a face it turned the plane off is 0.8 m in from
## the plane's middle, which a move the face blocked leaves up to the wingtip's
## reach and a frame's step at the speed relative to the car (0.7 m at 43) off it.
const TOUCH := 1.8
## The test: where the plane starts by the train (--train-test): this far behind
## the last car's end, in the middle of the gap between the tracks (track 1's
## train comes down it: RailTrains), this high over the bed.
const START_BACK := 30.0
const START_UP := 4.0
## The test train's nose at the start (m along the test path).
const TEST_HEAD := 700.0

## The engine's solid over its underframe: its model's parts
## (art/blender/train/train_build.py build_engine, its numbers; Godot's frame,
## the 22 m engine's), each [x0, y0, z0, x1, y1, z1, look], so what is seen is
## what is hit (the build proves its every vertex inside them). Front to back:
## the pilot raked down to its tip in three steps (from UNDER under the bed, so
## nothing flies under it), the buffer beam with it; the cylinders and the deck
## before the smokebox, the running boards (the rods, drivers and springs inside
## them); the boiler and smokebox (its door, handrails, pipes and the splashers in
## the lower block); the bell, sand dome, steam dome with its safety valves, and
## the whistle; the balloon stack flaring in three steps to its lip and mesh; the
## headlamp's lantern and its chimney; the air pump; the low cab under its arched
## roof (over the cab's front and back by its overhang), the arch in three steps
## up to its ventilator.
const ENGINE := [
	[-2.72,-2.0,-11.15, 2.72,2.45,-10.4,"iron"], [-2.4,-2.0,-11.6, 2.4,2.2,-11.15,"iron"],
	[-1.4,-2.0,-12.2, 1.4,1.65,-11.6,"iron"],
	[-2.54,1.4,-10.4, 2.54,3.3,-6.1,"iron"], [-2.43,1.4,-6.1, 2.43,3.3,4.2,"iron"],
	[-1.78,3.3,-10.3, 1.78,5.45,4.2,"iron"], [-1.4,5.45,-10.1, 1.4,6.2,4.2,"iron"],
	[-0.62,6.2,-6.1, 0.62,7.08,-5.1,"iron"], [-0.71,6.2,-4.1, 0.71,6.98,-2.7,"iron"],
	[-0.85,6.2,-1.65, 0.85,7.45,0.05,"iron"], [-0.18,6.2,3.6, 0.18,6.8,4.2,"iron"],
	[-0.78,6.0,-8.98, 0.78,7.15,-7.42,"iron"], [-1.05,7.15,-9.25, 1.05,7.75,-7.15,"iron"],
	[-1.34,7.75,-9.54, 1.34,9.0,-6.86,"iron"],
	[-0.85,6.0,-10.85, 0.85,7.95,-9.25,"iron"], [-0.26,7.95,-10.3, 0.26,8.45,-9.8,"iron"],
	[1.55,3.3,2.8, 2.38,5.2,3.7,"iron"],
	[-2.6,1.4,3.85, 2.6,6.95,11.0,"cab"], [-2.75,6.95,3.85, 2.75,7.2,10.95,"roof"],
	[-2.2,7.2,3.85, 2.2,7.45,10.95,"roof"], [-1.4,7.45,3.85, 1.4,7.82,10.95,"roof"]]

## The share of a block's colour it shows in shade (greybox sky fill).
const FILL := 0.35
const LOOKS := {
	"under":Color(0.12,0.12,0.13), "iron":Color(0.26,0.27,0.3), "cab":Color(0.3,0.12,0.1),
	"box":Color(0.55,0.25,0.17), "flat":Color(0.45,0.37,0.28), "van":Color(0.62,0.2,0.14),
	"load":Color(0.2,0.19,0.18), "open":Color(0.35,0.3,0.24), "door":Color(0.42,0.18,0.12),
	"inside":Color(0.22,0.16,0.11), "culvert":Color(0.62,0.6,0.56), "smash":Color(0.6,0.52,0.4), "plate":Color(0.72,0.67,0.56),
	"crack":Color(1.0,0.45,0.1), "stock":Color(0.5,0.27,0.16), "slat":Color(0.12,0.08,0.06),
	"logs":Color(0.58,0.42,0.26), "bark":Color(0.3,0.2,0.12), "stake":Color(0.36,0.28,0.2),
	"truss":Color(0.3,0.33,0.34), "brace":Color(0.18,0.2,0.21), "crane":Color(0.24,0.2,0.18),
	"boom":Color(0.62,0.5,0.22), "coach":Color(0.13,0.34,0.2), "gold":Color(0.85,0.65,0.22),
	"roof":Color(0.17,0.16,0.16), "window":Color(0.08,0.09,0.1)}
## The looks that glow (their emission, over FILL's): the cracks, as the ship's.
const GLOW := {"crack":2.5}

var game: Node3D
var path: RefCounted
var track := 0
## +1 runs +s along the path (track 0), -1 the other way (track 1).
var way := 1.0
var timetable: RefCounted
## Its speed now (m/s along its track), the nose's odometer and its s (`head`),
## the clock time it was placed at, and its timetable's stop it waits at (-1 running).
var speed := 0.0
var d := 0.0
var head := 0.0
var time := 0.0
var stop := -1
var label := "rail/train"
var keep := true
## Its solid is built (records in LandArches `loose`, a StaticBody a car).
var solid := false
## Frames its clock jumped further than it can run (moved with no push).
var jumps := 0
## Each car: {kind, long, tall, front (m from the nose to its front), node, body,
## record, records (its own, its plates' and its movers'), boxes (its solid but
## its plates and movers), all (and its plates still shut, and its movers where
## they are now), plates ([{box, record, shape, look, open}]), movers (the gate
## car's door leaves: [{box (shut), slide (local offset open), off (now), record,
## shape, look}]), slid (the gate's doors: 0 shut, 1 open), inner (a corridor:
## Vector3(half width, floor, roof), else absent), holes (its openings: [{box
## (local AABB), roofed (a roof or boom over it), way (slide, square, along)}]),
## half (the most its solid reaches from its middle along it: the crane's boom
## reaches over the car behind), xf, inv, was (last frame's xf), was_inv}.
var cars: Array[Dictionary] = []
## The smash car's plates broken and put back (counted, for the drivers).
var bursts := 0
var reseals := 0
var refill := false
## The touch a car made running into the plane this frame: {normal, at, car}, or {}.
var rammed := {}
## How many frames a car has run into the plane, and the most it moved it (m).
var rams := 0
var ram_most := 0.0
## The plane rides one of its cars (scripts/endless/rail_ride.gd): no keep-out.
var ridden := false
## The models on the cars (rail_train_look.gd), or null: the greybox blocks
## (--train-greybox).
var look: RefCounted = null
var _dt := 1.0/60.0
static var _mats := {}

static func test_wanted() -> bool:
	return "--train-test" in LaunchArgs.user_args()

## The test path in `field` (rail_test_path.gd: on the sea north-east of the start).
static func test_path(field: RefCounted) -> RefCounted:
	var sea: float = preload("res://scripts/endless/land_field.gd").SEA_Y
	var h := func(x: float, z: float) -> float: return maxf(float(field.height(x,z)),sea)+TestPath.BED
	return TestPath.new(h)

static func length_of() -> float:
	var n := 0.0
	for c: Array in CARS: n += float(c[1])
	return n+GAP*(CARS.size()-1)

## Where the plane starts on the test (--train-test): {at (XZ), heading, alt
## (over the sea)}, behind the test train's last car, flying its way, the
## train on its right, in the middle of the gap between the tracks.
static func test_start(p: RefCounted) -> Dictionary:
	var x: Transform3D = p.pose(test_start_s(),0)
	var at := x.origin-x.basis.x*0.5*float(p.track_gap())
	var f := -x.basis.z
	var sea: float = preload("res://scripts/endless/land_field.gd").SEA_Y
	return {"at":Vector2(at.x,at.z),"heading":atan2(-f.x,-f.z),"alt":at.y-sea+START_UP}

## The plane's start on the test, m along the path.
static func test_start_s() -> float:
	return TEST_HEAD-length_of()-START_BACK

static func speed_flag(otherwise := SPEED) -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--train-speed="): return maxf(0.0,a.trim_prefix("--train-speed=").to_float())
	return otherwise

## The train on `rail_path`'s track `on_track` by `table` (rail_timetable.gd, on
## the same path and track), placed at clock `at_time`: its look only; its solid
## comes with `set_solid`.
func setup(g: Node3D, rail_path: RefCounted, on_track: int, table: RefCounted, at_time: float, handle := "rail/train") -> void:
	game = g
	path = rail_path
	track = on_track
	timetable = table
	# Each track's train runs the way its pose faces: track 1's -s.
	way = 1.0 if on_track == 0 else -1.0
	label = handle
	name = "RailTrain"
	keep = not ("--train-keep=0" in LaunchArgs.user_args())
	refill = "--full-meter" in LaunchArgs.user_args()
	if Look.wanted(): look = Look.new()
	var front := 0.0
	for i in range(CARS.size()):
		var spec: Array = CARS[i]
		var car := {"kind":str(spec[0]),"long":float(spec[1]),"tall":float(spec[2]),"front":front,"records":[],"plates":[]}
		front += float(spec[1])+GAP
		_build(car,i)
		cars.append(car)
	place(at_time)
	_settle()

## One frame, before the plane's move (after the study's `solid_pad` is set): the
## train to its place at clock `at_time`, and the plane held out of the cars that
## came at it. A clock that jumped further than the train can run (a skip, a
## stall) moves it with no push: the cars were never between.
func before(delta: float, at_time: float) -> void:
	_dt = maxf(delta,0.0001)
	rammed = {}
	for car: Dictionary in cars:
		car.was = car.xf
		car.was_inv = car.inv
	var was_d := d
	place(at_time)
	if look != null: _look_step(delta)
	var ran := absf(fposmod(d-was_d+0.5*float(timetable.lap()),float(timetable.lap()))-0.5*float(timetable.lap()))
	if ran > float(timetable.speed)*maxf(delta,1.0/30.0)*2.0+1.0:
		jumps += 1
		_settle()
		return
	if not solid: return
	if keep: keep_out()
	_smash_step()

## Last frame's place taken as now's: no motion seen.
func _settle() -> void:
	for car: Dictionary in cars:
		car.was = car.xf
		car.was_inv = car.inv

## One frame, after the plane's move and before FlightContact: a car that ran
## into the plane gives it the speed it came at it by, along the face (so the
## same face doesn't catch it again next frame, and the plane is pushed once,
## not carried), and is the plane's touch if its own move made none.
func after(_delta: float) -> void:
	if rammed.is_empty(): return
	var plane = game.plane
	var n: Vector3 = rammed.normal
	var v: Vector3 = plane.velocity
	var into := -(v-velocity_at(rammed.car,rammed.at)).dot(n)
	if into > 0.0:
		var along := v.normalized().dot(n) if v.length() > 1.0 else 0.0
		if along > CATCH_ALONG: plane.speed = float(plane.speed)+minf(into/along,CATCH_MOST)
		else: plane.bump = (plane.bump as Vector3)+n*minf(into,CATCH_MOST)
	if not (plane.contact as Dictionary).is_empty(): return
	plane.contact = {"kind":"brush","velocity":v,"normal":n}

# --- The smash car ----------------------------------------------------------

## The surge held hot while the plane is in a smash car's corridor with a plate
## broken (so the far plate breaks on the way out); the plates back once it is
## RESEAL_FAR m off.
func _smash_step() -> void:
	var p: Vector3 = game.plane.position
	var smash = game.get("smash")
	for car: Dictionary in cars:
		if (car.plates as Array).is_empty(): continue
		var broken := false
		for plate: Dictionary in car.plates: broken = broken or bool(plate.open)
		if not broken: continue
		var xf: Transform3D = car.xf
		if xf.origin.distance_to(p) > RESEAL_FAR:
			_reseal(car)
			continue
		if smash != null and bool(smash.hot) and _in_corridor(car,(car.inv as Transform3D)*p,12.0): smash.keep_hot(0.3)

## The way off a smash car's nearest wall, roof or floor at world `p` (the plane's
## middle), for FlightContact: a touch in its corridor is glanced off, never a
## crash. ZERO outside every corridor, or within END_ROOM of a plate still shut.
func way_off(p: Vector3, _what := "") -> Vector3:
	var pad := float(game.solid_pad)
	for car: Dictionary in cars:
		if not car.has("inner"): continue
		if (car.xf as Transform3D).origin.distance_to(p) > float(car.long)*0.5+NEAR: continue
		var l: Vector3 = (car.inv as Transform3D)*p
		# Past its ends as far as a face there stops the plane: the wingtip's reach
		# (the arches' pad, `_blocked`) and a frame's step.
		if not _in_corridor(car,l,maxf(pad,WorldScale.span*0.5)+1.0) or _by_shut_plate(car,l): continue
		var c: Vector3 = car.inner
		var best := Vector4(l.x+c.x,1.0,0.0,0.0)
		for g: Vector4 in [Vector4(c.x-l.x,-1.0,0.0,0.0),Vector4(c.z-l.y,0.0,-1.0,0.0),Vector4(l.y-c.y,0.0,1.0,0.0)]:
			if g.x < best.x: best = g
		return ((car.xf as Transform3D).basis*Vector3(best.y,best.z,best.w)).normalized()
	return Vector3.ZERO

## Local `l` in smash car `car`'s corridor: between its walls, over its floor and
## under the middle of its roof, and between its ends or `pad` m past them.
static func _in_corridor(car: Dictionary, l: Vector3, pad: float) -> bool:
	var c: Vector3 = car.inner
	return absf(l.x) < c.x and l.y > c.y-0.5 and l.y < (c.z+float(car.tall))*0.5 and absf(l.z) < float(car.long)*0.5+pad

## Within END_ROOM of a plate of `car` still shut (local `l`): a touch there is
## the plate's, graded as anywhere.
static func _by_shut_plate(car: Dictionary, l: Vector3) -> bool:
	for plate: Dictionary in car.plates:
		if bool(plate.open): continue
		if absf(l.z-(plate.box as AABB).get_center().z) < END_ROOM+PLATE*0.5: return true
	return false

## The plane's breaking plate record `r` (SurgeSmash `_hit`, its `strike`): gone
## till the plates come back, and the surge held hot to the far end.
func _strike(r: Dictionary, q: Vector3) -> void:
	var car: Dictionary = cars[int(r.car_i)]
	var plate: Dictionary = car.plates[int(r.plate_i)]
	if bool(plate.open): return
	plate.open = true
	game.arches.loose.erase(r)
	GroundNative.bump_loose()
	(plate.shape as CollisionShape3D).disabled = true
	_plate_burst(car,plate,q)
	_refresh(car)
	var smash = game.get("smash")
	if smash != null: smash.keep_hot(float(car.long)/maxf((game.plane.velocity as Vector3).length()-speed,10.0)+0.5)
	bursts += 1

## Smash car `car`'s plates put back.
func _reseal(car: Dictionary) -> void:
	for plate: Dictionary in car.plates:
		if not bool(plate.open): continue
		plate.open = false
		game.arches.loose.push_front(plate.record)
		(plate.shape as CollisionShape3D).disabled = false
		_plate_shut(plate)
	GroundNative.bump_loose()
	_refresh(car)
	reseals += 1
	if refill: game.near.meter = 1.0

## Plate `plate` of `car` broken by the plane at world `q`: its model's shards
## thrown (rail_train_look.gd), or its block hidden.
func _plate_burst(car: Dictionary, plate: Dictionary, q: Vector3) -> void:
	if not plate.has("plug"):
		(plate.look as Node3D).visible = false
		return
	var inv: Transform3D = car.inv
	var v: Vector3 = (game.plane.velocity as Vector3)-velocity_at(car,q)
	look.burst(car,plate.plug,inv*q,inv.basis*v)

func _plate_shut(plate: Dictionary) -> void:
	if plate.has("plug"): look.shut(plate.plug)
	else: (plate.look as Node3D).visible = true

## The models' running gear turned to the odometer near the camera, and the thrown
## shards on (rail_train_look.gd).
func _look_step(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = cam.global_position if cam != null else (game.plane.position as Vector3)
	look.step(delta,cars,d,eye,Vector3(smash_wide()*0.5,FLOOR,FLOOR+smash_high()),DECK)

## `v` (a touch's velocity at world `at`) less the velocity of the car `at` is
## on, if any: what FlightContact grades a touch of a car by.
func relative(at: Vector3, v: Vector3) -> Vector3:
	var m: Variant = motion_at(at,TOUCH)
	return v if m == null else v-(m as Vector3)

## A scrape off a car (FlightContact, after grading it by `relative`), done in
## the car's frame: the plane's speed into the face taken off relative to the car,
## not the world, then `keep` of what's left and a `kick` off it (SkyPlane
## `scrape`). Creeping up into a car's back end at cruise it drops back behind
## it on its own heading; in the world's frame the scrape would turn its path
## round off a face it was only 5 m/s into. False if `at` is on no car.
func scrape(plane: RefCounted, n: Vector3, at: Vector3, keep: float, kick: float) -> bool:
	var m: Variant = motion_at(at,TOUCH)
	if m == null: return false
	var vc: Vector3 = m
	var path: Vector3 = plane.path_now()
	var rel := path*float(plane.speed)-vc
	var into := -rel.dot(n)
	if into > 0.0: rel += n*into
	# `keep` of the speed relative to the car, not of the world's: a car's side
	# brushed creeping up it costs a share of the creep, not of cruise. Of the
	# world's, each scrape took the plane down to the train's pace, and one held
	# against a curving car's side stayed by that one car, scraping (rail_collide
	# curve: 13 scrapes in 15 s by the doors car). Never more than a still face's
	# scrape would take: a train brushed head on (70 m/s by it) took a quarter.
	var w := vc+rel*keep
	if w.length() < 0.1: return false
	var plane_speed := maxf(float(plane.speed),0.1)
	plane.scrape(n,maxf(w.length(),plane_speed*keep)/plane_speed,kick,w.normalized().dot(n)+SkyPlane.SCRAPE_OUT)
	return true

## The way out of the car nearest world `p` (the plane's middle), within `reach`
## m of its solid, from the nearest point of it: a corner's is round, as the
## arches' pad (FlightContact, as a Peak tower's `face`). Without it a car touched
## by its corner took the land's slope there for its face (a brush's normal where
## the slope is steep), which reads the corner as a cliff at 45 degrees: a wing
## caught by the next car's end as the plane threaded two trains crashed at 66
## m/s across it. ZERO if no car is that near.
func face(p: Vector3, reach: float) -> Vector3:
	var best := INF
	var got := Vector3.ZERO
	for car: Dictionary in cars:
		var xf: Transform3D = car.xf
		if xf.origin.distance_to(p) > float(car.half)+NEAR+reach: continue
		var l: Vector3 = (car.inv as Transform3D)*p
		for b: AABB in car.all:
			var c := l.clamp(b.position,b.end)
			var d := l.distance_to(c)
			if d > reach or d >= best: continue
			var n := l-c
			if d < 0.0001:
				# Inside: out the nearest face.
				var ways := [Vector4(l.x-b.position.x,-1.0,0.0,0.0),Vector4(b.end.x-l.x,1.0,0.0,0.0),Vector4(l.y-b.position.y,0.0,-1.0,0.0),
					Vector4(b.end.y-l.y,0.0,1.0,0.0),Vector4(l.z-b.position.z,0.0,0.0,-1.0),Vector4(b.end.z-l.z,0.0,0.0,1.0)]
				var near := Vector4(INF,0.0,0.0,0.0)
				for w: Vector4 in ways:
					if w.x < near.x: near = w
				n = Vector3(near.y,near.z,near.w)
			best = d
			got = (xf.basis*n).normalized()
	return got

## The velocity (m/s) of the car whose solid is nearest world `at`, within
## `reach` m of it, or null: what a near miss by a car is scored relative to
## (NearMiss `_by`) and a touch of one graded by (`relative`).
func motion_at(at: Vector3, reach: float) -> Variant:
	var near := nearest(at,reach)
	return null if near.is_empty() else near.velocity

## The car whose solid is nearest world `at`, within `reach` m: {d (m off its
## solid), velocity (of its point at `at`)}, or {} (RailTrains asks each train).
func nearest(at: Vector3, reach: float) -> Dictionary:
	var best := INF
	var got := {}
	for car: Dictionary in cars:
		if (car.xf as Transform3D).origin.distance_to(at) > float(car.half)+NEAR+reach: continue
		var l: Vector3 = (car.inv as Transform3D)*at
		for b: AABB in car.all:
			var d := Vector3(maxf(0.0,maxf(b.position.x-l.x,l.x-b.end.x)),maxf(0.0,maxf(b.position.y-l.y,l.y-b.end.y)),
				maxf(0.0,maxf(b.position.z-l.z,l.z-b.end.z))).length()
			if d <= reach and d < best:
				best = d
				got = car
	if got.is_empty(): return {}
	return {"d":best,"velocity":velocity_at(got,at)}

# --- The chase camera --------------------------------------------------------

## The share of the way from `from` to `to` clear of the cars (their solid and the
## plates still shut, grown by `pad` m; 1: clear all the way), for the chase
## camera's `sight` (the study's `_sight`). Exact, the segment against each box in
## its car's frame: the study's march looks at ten points along the way, a metre or
## so apart, and steps over a part as thin as the roof over the smash car's
## corridor (0.6 m; rail_sight: 70 of 1200 segments up through it seen clear), so
## the eye could swing through it. A box the plane's end (`from`) is in already is
## passed over: the eye can't help that.
func sight(from: Vector3, to: Vector3, pad := 0.0) -> float:
	var got := 1.0
	var mid := (from+to)*0.5
	var half := from.distance_to(to)*0.5
	for car: Dictionary in cars:
		if (car.xf as Transform3D).origin.distance_to(mid) > float(car.half)+NEAR+half+pad: continue
		var inv: Transform3D = car.inv
		var a := inv*from
		var b := inv*to
		for box: AABB in car.all:
			got = minf(got,_entry(a,b,box.grow(pad)))
	return got

## Where the segment `a`..`b` first enters `box`, as a share of the way (0..1), or 1
## if it never does or `a` is inside it already.
static func _entry(a: Vector3, b: Vector3, box: AABB) -> float:
	if box.has_point(a): return 1.0
	var d := b-a
	var t0 := 0.0
	var t1 := 1.0
	for k in range(3):
		var lo := box.position[k]
		var hi := box.end[k]
		if absf(d[k]) < 0.000001:
			if a[k] < lo or a[k] > hi: return 1.0
			continue
		var u := (lo-a[k])/d[k]
		var v := (hi-a[k])/d[k]
		t0 = maxf(t0,minf(u,v))
		t1 = minf(t1,maxf(u,v))
		if t0 > t1: return 1.0
	return t0

## The plane at world `p` in a car's hollow: the smash car's corridor (out to NEAR m
## past its ends) or an opening across with something over it (a doorway, the
## coaches' gap, under the crane's boom: `holes` roofed, out to NEAR m past the
## car's sides). The chase camera is `tight` there, as in a bore (GlideCamera: it
## checks the way it is easing round too, and may draw in to TIGHT_NEAR of
## `near`): a hollow's roof and walls are nearer than `near`, the least it
## otherwise draws in to, so with no clear way round it sat in them (the smash
## car's roof lip, climbing out of the corridor 2.2 m off its middle).
func tight(p: Vector3) -> bool:
	for car: Dictionary in cars:
		if not car.has("inner") and (car.holes as Array).is_empty(): continue
		if (car.xf as Transform3D).origin.distance_to(p) > float(car.half)+NEAR*2.0: continue
		var l: Vector3 = (car.inv as Transform3D)*p
		if car.has("inner") and _in_corridor(car,l,NEAR): return true
		for hole: Dictionary in car.holes:
			if not bool(hole.roofed): continue
			var b: AABB = hole.box
			if l.z > b.position.z and l.z < b.end.z and l.y > b.position.y-0.5 and l.y < b.end.y \
				and absf(l.x) < WIDE*0.5+NEAR: return true
	return false

## The velocity (m/s) of the point of `car` now at world `at`.
func velocity_at(car: Dictionary, at: Vector3) -> Vector3:
	var then: Vector3 = (car.was as Transform3D)*((car.inv as Transform3D)*at)
	return (at-then)/_dt

## The plane held out of every car near it the way the car came at it (above).
func keep_out() -> void:
	if ridden: return
	var plane = game.plane
	var p: Vector3 = plane.position
	var pad := float(game.solid_pad)
	for car: Dictionary in cars:
		var xf: Transform3D = car.xf
		if xf.origin.distance_to(p) > float(car.half)+NEAR: continue
		var l: Vector3 = (car.inv as Transform3D)*p
		var lw: Vector3 = (car.was_inv as Transform3D)*p
		var out := l
		for _again in range(2):
			for b: AABB in car.all:
				var r := _out_of(b,out,lw,pad)
				if r.is_empty(): continue
				out = r.at
				var n: Vector3 = xf.basis*(r.normal as Vector3)
				rammed = {"normal":n.normalized(),"at":xf*out,"car":car}
		if out == l: continue
		var moved := (xf*out).distance_to(p)
		rams += 1
		ram_most = maxf(ram_most,moved)
		p = xf*out
	if p != plane.position: plane.position = p

## Local `l` put out of box `b` grown by `pad` round (in XZ, under its top), by
## the face the plane's way from `lw` (where it was in the car last frame) crossed,
## or, already inside, the nearest side under KEEP_MOST: {at, normal} (local), or
## {} if `l` is clear of it. Over the box's top is SkyGlide's to ride.
static func _out_of(b: AABB, l: Vector3, lw: Vector3, pad: float) -> Dictionary:
	if l.y < b.position.y or l.y > b.end.y: return {}
	var dx := maxf(0.0,maxf(b.position.x-l.x,l.x-b.end.x))
	var dz := maxf(0.0,maxf(b.position.z-l.z,l.z-b.end.z))
	if dx*dx+dz*dz > pad*pad: return {}
	# In a corner's round (off both faces): out from the corner, as the arches'
	# pad rounds it. By the face crossed, a wing a hair over a passing car's side
	# line was put out ahead of the next car's end, square to it, and crashed.
	if dx > 0.0 and dz > 0.0:
		var c := Vector2(clampf(l.x,b.position.x,b.end.x),clampf(l.z,b.position.z,b.end.z))
		var dir := (Vector2(l.x,l.z)-c).normalized()
		var to := c+dir*(pad+EASE)
		return {"at":Vector3(to.x,l.y,to.y),"normal":Vector3(dir.x,0.0,dir.y)}
	var lo := Vector2(b.position.x-pad,b.position.z-pad)
	var hi := Vector2(b.end.x+pad,b.end.z+pad)
	# The faces crossed, and when on the way from `lw` to `l` (the latest is the one).
	var best := -1.0
	var face := Vector3.ZERO
	var at := l
	var d := l-lw
	if lw.x < lo.x and d.x > 0.0:
		var f := (lo.x-lw.x)/d.x
		if f > best:
			best = f
			face = Vector3(-1.0,0.0,0.0)
			at = Vector3(lo.x-EASE,l.y,l.z)
	if lw.x > hi.x and d.x < 0.0:
		var f := (hi.x-lw.x)/d.x
		if f > best:
			best = f
			face = Vector3(1.0,0.0,0.0)
			at = Vector3(hi.x+EASE,l.y,l.z)
	if lw.z < lo.y and d.z > 0.0:
		var f := (lo.y-lw.z)/d.z
		if f > best:
			best = f
			face = Vector3(0.0,0.0,-1.0)
			at = Vector3(l.x,l.y,lo.y-EASE)
	if lw.z > hi.y and d.z < 0.0:
		var f := (hi.y-lw.z)/d.z
		if f > best:
			best = f
			face = Vector3(0.0,0.0,1.0)
			at = Vector3(l.x,l.y,hi.y+EASE)
	if best >= 0.0: return {"at":at,"normal":face}
	# Inside already: the nearest side, if near.
	var ways := [Vector4(l.x-lo.x,-1.0,0.0,lo.x-EASE),Vector4(hi.x-l.x,1.0,0.0,hi.x+EASE),Vector4(l.z-lo.y,0.0,-1.0,lo.y-EASE),Vector4(hi.y-l.z,0.0,1.0,hi.y+EASE)]
	var near := Vector4(INF,0.0,0.0,0.0)
	for w: Vector4 in ways:
		if w.x < near.x: near = w
	if near.x > KEEP_MOST: return {}
	if near.y != 0.0: return {"at":Vector3(near.w,l.y,l.z),"normal":Vector3(near.y,0.0,0.0)}
	return {"at":Vector3(l.x,l.y,near.w),"normal":Vector3(0.0,0.0,near.z)}

## Every car where the train is at clock `at_time`: between its bogies on its
## track, each so many metres of the track behind the nose.
func place(at_time: float) -> void:
	time = at_time
	var now: Dictionary = timetable.at(at_time)
	d = float(now.d)
	head = float(now.s)
	speed = float(now.v)
	stop = int(now.stop)
	for car: Dictionary in cars:
		var a: Transform3D = path.pose(timetable.s_of(d-float(car.front)-BOGIE),track)
		var b: Transform3D = path.pose(timetable.s_of(d-float(car.front)-float(car.long)+BOGIE),track)
		var f := (a.origin-b.origin).normalized()
		var up := (a.basis.y+b.basis.y).normalized()
		up = (up-f*f.dot(up)).normalized()
		var z := -f
		var xf := Transform3D(Basis(up.cross(z),up,z),(a.origin+b.origin)*0.5)
		car.xf = xf
		# The track's way at each bogie, for the model's trucks.
		car.ta = -a.basis.z
		car.tb = -b.basis.z
		car.inv = xf.affine_inverse()
		(car.node as Node3D).transform = xf
		if not (car.movers as Array).is_empty(): _slide(car,gate_open(at_time))
		if not solid: continue
		# The body told now, not at the tree's next flush: the wing rays this
		# frame (NearMiss) meet the car where it is, not 0.53 m back.
		if is_inside_tree(): (car.body as Node3D).force_update_transform()
		_tell(car)
	if solid: GroundNative.bump_loose()

## The gate car's doors at the train's clock `t`: 0 shut, 1 open (GATE_OPEN,
## GATE_SLIDE, GATE_SHUT), eased at each end of a slide.
static func gate_open(t: float) -> float:
	var u := fposmod(t,GATE_OPEN+GATE_SHUT+2.0*GATE_SLIDE)
	if u < GATE_OPEN: return 1.0
	u -= GATE_OPEN
	if u < GATE_SLIDE: return 1.0-smoothstep(0.0,1.0,u/GATE_SLIDE)
	u -= GATE_SLIDE+GATE_SHUT
	if u < 0.0: return 0.0
	return smoothstep(0.0,1.0,u/GATE_SLIDE)

## Car `car`'s movers (the gate's door leaves) slid `open` of the way open: each
## its offset, its shape and block where it is now, `all` told.
func _slide(car: Dictionary, open: float) -> void:
	if is_equal_approx(float(car.get("slid",-1.0)),open): return
	car.slid = open
	for m: Dictionary in car.movers:
		var off: Vector3 = (m.slide as Vector3)*open
		m.off = off
		if m.has("shape"): (m.shape as Node3D).position = (m.box as AABB).get_center()+off
		if m.has("look"): (m.look as Node3D).position = off
	_refresh(car)

## Car `car`'s records in `loose` told its frame (a mover's record its own,
## moved by its offset).
static func _tell(car: Dictionary) -> void:
	var xf: Transform3D = car.xf
	var f := -xf.basis.z
	var yaw := atan2(-f.x,-f.z)
	for r: Dictionary in car.records:
		r.cos = cos(yaw)
		r.sin = sin(yaw)
		if r.has("mover"):
			var mx := xf.translated_local((r.mover as Dictionary).off)
			r.pos = mx.origin
			r.xf = mx
			r.inv = mx.affine_inverse()
			continue
		r.pos = xf.origin
		r.xf = xf
		r.inv = car.inv

## Car `car` (number `i`): its look, its blocks drawn as one mesh (shared by
## every train: `_looks`), and the smash car's plates' looks; its boxes for the
## solid (`set_solid`).
func _build(car: Dictionary, i: int) -> void:
	var node := Node3D.new()
	node.name = "Car%d" % i
	add_child(node)
	car.node = node
	var kind := str(car.kind)
	var parts := _parts(kind,float(car.long),float(car.tall))
	var boxes: Array[AABB] = []
	var half := float(car.long)*0.5
	for part: Array in parts.solid:
		var b: AABB = part[0]
		boxes.append(b)
		half = maxf(half,maxf(-b.position.z,b.end.z))
	car.boxes = boxes
	car.half = half
	car.holes = parts.holes
	if not (parts.movers as Array).is_empty(): car.door_slide = door_wide(float(car.long))*0.5
	var dressed: bool = look != null and look.dress(car)
	if not dressed:
		var mi := MeshInstance3D.new()
		mi.name = "Look"
		mi.mesh = _look_of(car,parts)
		node.add_child(mi)
	var plates: Array[Dictionary] = []
	var ends: Array = parts.plates
	for k in range(ends.size()):
		var box: AABB = ends[k]
		var plate := {"box":box,"open":false,"k":k}
		var plug: Dictionary = look.plug(car,k) if dressed else {}
		if not plug.is_empty(): plate.plug = plug
		else:
			var pl := MeshInstance3D.new()
			pl.name = "Plate%d" % k
			pl.mesh = _plate_mesh(box)
			node.add_child(pl)
			plate.look = pl
		plates.append(plate)
	car.plates = plates
	var movers: Array[Dictionary] = []
	for m: Dictionary in parts.movers:
		var mover := {"box":m.box,"slide":m.slide,"off":Vector3.ZERO,"k":movers.size()}
		if not dressed:
			var ml := MeshInstance3D.new()
			ml.name = "Leaf%d" % movers.size()
			ml.mesh = _leaf_mesh(m.box)
			node.add_child(ml)
			mover.look = ml
		movers.append(mover)
	car.movers = movers
	if kind in CORRIDOR: car.inner = Vector3(smash_wide()*0.5,FLOOR,FLOOR+smash_high(float(car.tall)))
	_refresh(car)

## The solid on or off: each car its StaticBody on layer 1 (the wing rays) and
## its record in LandArches `loose`, the smash car's plates each a record of its
## own, first in `loose` (so a strike near a jamb finds the plate), and a shape.
## Off, the plates are put back whole.
func set_solid(on: bool) -> void:
	if on == solid: return
	solid = on
	for i in range(cars.size()):
		var car: Dictionary = cars[i]
		if on: _solidify(car,i)
		else:
			for r: Dictionary in car.records: game.arches.loose.erase(r)
			car.records = []
			(car.body as Node).queue_free()
			car.erase("body")
			for plate: Dictionary in car.plates:
				plate.open = false
				_plate_shut(plate)
				plate.erase("shape")
				plate.erase("record")
			for m: Dictionary in car.movers:
				m.erase("shape")
				m.erase("record")
			_refresh(car)
	_settle()
	GroundNative.bump_loose()

func _solidify(car: Dictionary, i: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in car.boxes: body.add_child(_shape(box))
	(car.node as Node3D).add_child(body)
	car.body = body
	var reach := float(car.half)+BoxSolid.grow_most()+2.0
	var record := {"name":"%s/car%d" % [label,i],"kind":"train","node":car.node,"pos":Vector3.ZERO,"cos":1.0,"sin":0.0,
		"xf":Transform3D.IDENTITY,"inv":Transform3D.IDENTITY,"solid":_solid_of(car.boxes),
		"reach":reach,"spec":{},"no_break":true,"adopted":0}
	car.record = record
	car.records = [record]
	game.arches.loose.append(record)
	for plate: Dictionary in car.plates:
		var k := int(plate.k)
		var box: AABB = plate.box
		var cs := _shape(box)
		body.add_child(cs)
		var pr := {"name":"%s/car%d/plate%d" % [label,i,k],"kind":"train","node":car.node,"pos":Vector3.ZERO,"cos":1.0,"sin":0.0,
			"xf":Transform3D.IDENTITY,"inv":Transform3D.IDENTITY,"solid":_solid_of([box]),
			"reach":reach,"spec":{},"no_break":true,"adopted":0,
			"strike":Callable(self,"_strike"),"car_i":i,"plate_i":k}
		(car.records as Array).append(pr)
		game.arches.loose.push_front(pr)
		plate.record = pr
		plate.shape = cs
	# The gate's leaves: each a record of its own, in its own frame (the car's
	# moved by its offset: `_tell`), its shape moved with it (`_slide`).
	for m: Dictionary in car.movers:
		var box: AABB = m.box
		var cs := _shape(box)
		cs.position = box.get_center()+(m.off as Vector3)
		body.add_child(cs)
		var mr := {"name":"%s/car%d/leaf%d" % [label,i,int(m.k)],"kind":"train","node":car.node,"pos":Vector3.ZERO,"cos":1.0,"sin":0.0,
			"xf":Transform3D.IDENTITY,"inv":Transform3D.IDENTITY,"solid":_solid_of([box]),
			"reach":reach,"spec":{},"no_break":true,"adopted":0,"mover":m}
		(car.records as Array).append(mr)
		game.arches.loose.append(mr)
		m.record = mr
		m.shape = cs
	if is_inside_tree(): body.force_update_transform()
	_tell(car)

## BoxSolid's build of `boxes`, made once a car kind (every train's cars alike).
static var _solids := {}

static func _solid_of(boxes: Array) -> Variant:
	var key := str(boxes)
	if not _solids.has(key):
		var typed: Array[AABB] = []
		for b: AABB in boxes: typed.append(b)
		_solids[key] = BoxSolid.build(typed)
	return _solids[key]

## A car's look and a plate's, made once a kind and size (every train's alike).
static var _looks := {}

func _look_of(car: Dictionary, parts: Dictionary) -> ArrayMesh:
	var key := "%s/%s/%s" % [car.kind,car.long,car.tall]
	if not _looks.has(key):
		var looks: Array = []
		for part: Array in parts.solid:
			if str(part[1]) != "": looks.append(part)
		looks.append_array(parts.dress)
		_looks[key] = _merged(looks)
	return _looks[key]

func _plate_mesh(box: AABB) -> ArrayMesh:
	var key := "plate/%s" % box
	if not _looks.has(key): _looks[key] = _merged(_plate_look(box))
	return _looks[key]

## A gate leaf's greybox block, drawn where it is shut (its node moved by its offset).
func _leaf_mesh(box: AABB) -> ArrayMesh:
	var key := "leaf/%s" % box
	if not _looks.has(key): _looks[key] = _merged([[box,"door"]])
	return _looks[key]

static func _shape(box: AABB) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	cs.position = box.get_center()
	return cs

## `car.all`: its solid and its plates still shut.
func _refresh(car: Dictionary) -> void:
	var all: Array[AABB] = []
	all.append_array(car.boxes)
	for plate: Dictionary in car.plates:
		if not bool(plate.open): all.append(plate.box)
	for m: Dictionary in car.get("movers",[]):
		var b: AABB = m.box
		all.append(AABB(b.position+(m.off as Vector3),b.size))
	car.all = all

## The doors car's doorway (m): along the car, and up from its floor.
static func door_wide(long := 24.0) -> float:
	return minf(WorldScale.opening(TOY_DOOR),long-2.0*JAMB_LEAST)

static func door_high(tall := 9.0) -> float:
	return minf(WorldScale.opening(TOY_DOOR_HIGH),tall-FLOOR-HEAD_LEAST)

## The smash car's corridor (m): across, and up from its floor.
static func smash_wide() -> float:
	return minf(WorldScale.opening(TOY_SMASH_WIDE),WIDE-2.0*WALL_LEAST)

static func smash_high(tall := 9.0) -> float:
	return minf(WorldScale.opening(TOY_SMASH_HIGH),tall-FLOOR-HEAD_LEAST)

## An opening flown square across a car at cruise (m, along the car): its toy
## width's opening and the car's run under the plane while it crosses `depth` m.
static func square(toy: float, depth := WIDE) -> float:
	return WorldScale.opening(toy)+depth*SPEED/CRUISE

## The log car's gap between its bundles (m, along the car): square.
static func log_gap(long := 22.0) -> float:
	return minf(square(TOY_THREAD),long-2.0*(BUNDLE_LEAST+LOG_IN))

## The truss car's deck (m over the bed: its opening's floor), and the opening's
## height up to the top chord.
static func truss_floor(tall := 8.5) -> float:
	return maxf(FLOOR+TRUSS_DECK_LEAST,tall-CHORD-WorldScale.opening(TOY_DOOR_HIGH))

static func truss_high(tall := 8.5) -> float:
	return tall-CHORD-truss_floor(tall)

## The crane's boom's underside (m over the bed): the door's height over the
## idler's deck, under the car's top.
static func boom_low(tall := 9.0) -> float:
	return minf(DECK+WorldScale.opening(TOY_DOOR_HIGH),tall-BOOM_LEAST)

## A coach's end platform (m along it), and its railings' top (m over the bed):
## two coaches' platforms and the gap between them are the door's width, the
## railings' top the door's height under the hoods.
static func platform(long := 24.0) -> float:
	return clampf((WorldScale.opening(TOY_DOOR)-GAP)*0.5,1.0,long*0.3)

static func coach_rail(tall := 8.5) -> float:
	return maxf(FLOOR+TRUSS_DECK_LEAST,tall-HOOD-WorldScale.opening(TOY_DOOR_HIGH))

## A car's blocks in its frame: {solid: [[AABB, look ("" not drawn)]], dress:
## [[AABB or Transform3D of a unit box, look]] drawn only, plates: [AABB] (the
## smash car's, front then back), holes: [{box, roofed}] (its openings flown
## across, as the car's `holes`)}. Every car has its underframe from UNDER under
## the bed to its floor; on it the kind's body. The underframe is drawn narrower
## than the car but is solid its whole width: a body standing out over it would be
## an overhang, and a plane flying low beside the car (its middle under the floor,
## skimming the sea by the causeway) would be under it, lifted onto the roof (a
## pop of 8 m) the moment a curve swung the car in.
static func _parts(kind: String, long: float, tall: float) -> Dictionary:
	var h := long*0.5
	var w := WIDE*0.5
	var out: Array = [[_box(-w,-UNDER,-h,w,FLOOR,h),""]]
	var dress: Array = [[_box(-w*0.9,-UNDER,-h,w*0.9,FLOOR,h),"under"]]
	var plates: Array = []
	var holes: Array = []
	var movers: Array = []
	match kind:
		"engine":
			# The 4-4-0's model, block for block (ENGINE).
			for b: Array in ENGINE: out.append([_box(b[0],b[1],b[2],b[3],b[4],b[5]),str(b[6])])
		"tender":
			out.append([_box(-w,FLOOR,-h,w,tall,h),"iron"])
		"box":
			out.append([_box(-w,FLOOR,-h,w,tall,h),"box"])
		"flat":
			out.append([_box(-w,FLOOR,-h,w,tall,h),"flat"])
		"open":
			out.append([_box(-w,FLOOR,-h,w,tall,h),"open"])
			out.append([_box(-w*HEAP_IN,tall,-h*HEAP_IN,w*HEAP_IN,tall+HEAP,h*HEAP_IN),"load"])
		"van":
			out.append([_box(-w*0.9,FLOOR,-h,w*0.9,tall-1.8,h),"van"])
			out.append([_box(-w*0.55,tall-1.8,-2.0,w*0.55,tall,2.0),"van"])
		"doors":
			holes.append(_doorway(out,dress,long,tall,"box"))
		"gate":
			# The doors car's doorway, each side's two leaves sliding shut over it
			# (meeting in its middle) and open again over the walls fore and aft:
			# each a mover, its block where it is shut, `slide` its way open.
			var hole := _doorway(out,dress,long,tall,"box")
			hole.gate = true
			holes.append(hole)
			var d := door_wide(long)*0.5
			var top := FLOOR+door_high(tall)+DOOR_OVER+ROLLERS
			for sx: float in [-1.0,1.0]:
				var x0 := w-LEAF if sx > 0.0 else -w
				var x1 := w if sx > 0.0 else -w+LEAF
				movers.append({"box":_box(x0,FLOOR,-d,x1,top,0.0),"slide":Vector3(0.0,0.0,-d)})
				movers.append({"box":_box(x0,FLOOR,0.0,x1,top,d),"slide":Vector3(0.0,0.0,d)})
		"thru":
			# An open-ended boxcar: the smash car's corridor, its ends open, lined up
			# with the culvert car's and the next one's (the run).
			_corridor(out,dress,holes,long,tall,"box")
		"culvert":
			# Concrete box culverts end to end on a well flat: each section's walls
			# and roof round the corridor (its floor the underframe's top), CULVERT_GAP
			# between them.
			var iw := smash_wide()*0.5
			var lid := FLOOR+smash_high(tall)
			var run := long-2.0*CULVERT_IN
			var sec := (run-float(CULVERTS-1)*CULVERT_GAP)/float(CULVERTS)
			for k in range(CULVERTS):
				var z0 := -h+CULVERT_IN+float(k)*(sec+CULVERT_GAP)
				out.append([_box(-CULVERT_SIDE,FLOOR,z0,-iw,tall,z0+sec),"culvert"])
				out.append([_box(iw,FLOOR,z0,CULVERT_SIDE,tall,z0+sec),"culvert"])
				out.append([_box(-iw,lid,z0,iw,tall,z0+sec),"culvert"])
			holes.append({"box":_box(-iw,FLOOR,-h-GAP*0.5,iw,lid,h+GAP*0.5),"roofed":true,"way":"along"})
		"stock":
			# The doors car's doorway in a slatted car: the gaps between the slats
			# drawn dark down both sides, over the doors slid open too.
			holes.append(_doorway(out,dress,long,tall,"stock"))
			var d := door_wide(long)*0.5
			var y := FLOOR+SLAT
			while y < tall-0.5:
				for sx: float in [-1.0,1.0]:
					var x0 := minf(sx*(w+0.04),sx*(w+0.07))
					var x1 := maxf(sx*(w+0.04),sx*(w+0.07))
					dress.append([_box(x0,y,-h,x1,y+0.14,-d),"slat"])
					dress.append([_box(x0,y,d,x1,y+0.14,h),"slat"])
				for sz: float in [-1.0,1.0]:
					dress.append([_box(-w,y,sz*(h+0.02)-0.01,w,y+0.14,sz*(h+0.02)+0.01),"slat"])
				y += SLAT
		"logs":
			# Two bundles chained on a flat, the gap between them open above: each
			# solid its whole width (the stakes at its corners), the logs drawn
			# inset, their rows lined dark, their ends pale on dark, chains over the top.
			var g := log_gap(long)*0.5
			out.append([_box(-w,FLOOR,-h,w,DECK,h),"flat"])
			for zs: Vector2 in [Vector2(-h+LOG_IN,-g),Vector2(g,h-LOG_IN)]:
				out.append([_box(-w,DECK,zs.x,w,tall,zs.y),""])
				var lw := w*0.92
				dress.append([_box(-lw,DECK,zs.x,lw,tall-0.12,zs.y),"logs"])
				var rows := 3
				for k in range(1,rows):
					var ry := DECK+(tall-0.12-DECK)*float(k)/float(rows)
					dress.append([_box(-lw-0.03,ry-0.07,zs.x,lw+0.03,ry+0.07,zs.y),"bark"])
				# Each end dark, the logs' ends on it pale, four across, three up.
				for ends: Vector2 in [Vector2(zs.x,-1.0),Vector2(zs.y,1.0)]:
					var ez := ends.x+ends.y*0.02
					dress.append([_box(-lw,DECK,ez-0.01,lw,tall-0.12,ez+0.01),"bark"])
					var cell := Vector2(2.0*lw/4.0,(tall-0.12-DECK)/float(rows))
					for kx in range(4):
						for ky in range(rows):
							var at := Vector2(-lw+cell.x*(float(kx)+0.5),DECK+cell.y*(float(ky)+0.5))
							var off := 0.0 if ky % 2 == 0 else cell.x*0.12
							var ez2 := ez+ends.y*0.02
							dress.append([_box(at.x+off-cell.x*0.38,at.y-cell.y*0.38,ez2-0.01,at.x+off+cell.x*0.38,at.y+cell.y*0.38,ez2+0.01),"logs"])
				for sx: float in [-1.0,1.0]:
					for sz: float in [zs.x+0.35,zs.y-0.35]:
						dress.append([_box(minf(sx*(w-0.26),sx*(w+0.02)),DECK,sz-0.18,maxf(sx*(w-0.26),sx*(w+0.02)),tall,sz+0.18),"stake"])
				for t: float in [0.3,0.7]:
					var cz := lerpf(zs.x,zs.y,t)
					dress.append([_box(-lw,tall-0.14,cz-0.08,lw,tall,cz+0.08),"slat"])
			holes.append({"box":_box(-w,DECK,-g,w,tall,g),"roofed":false,"way":"square"})
		"truss":
			# A bridge truss section on a heavy flat (its deck lowered to fit the
			# opening under the car's top): two side trusses, each a top chord over
			# its end panels, closed, and its middle panel open; struts across the
			# top over the middle panel's ends and the truss's ends.
			var y0 := truss_floor(tall)
			var top := tall-CHORD
			var d := door_wide(long)*0.5
			var tl := h-TRUSS_IN
			out.append([_box(-w,FLOOR,-h,w,y0,h),"flat"])
			for sx: float in [-1.0,1.0]:
				var x0 := w-TRUSS_SIDE if sx > 0.0 else -w
				var x1 := w if sx > 0.0 else -w+TRUSS_SIDE
				out.append([_box(x0,top,-tl,x1,tall,tl),"truss"])
				out.append([_box(x0,y0,-tl,x1,top,-d),"truss"])
				out.append([_box(x0,y0,d,x1,top,tl),"truss"])
				# Its bottom chord along the deck's edge, and each end panel's posts
				# and braces on both faces.
				var fx := sx*(w+0.03)
				dress.append([_box(minf(fx,sx*(w-TRUSS_SIDE-0.03)),y0-0.35,-tl,maxf(fx,sx*(w-TRUSS_SIDE-0.03)),y0+0.02,tl),"brace"])
				for face: float in [sx*(w+0.03),sx*(w-TRUSS_SIDE-0.03)]:
					for zs: Vector2 in [Vector2(-tl,-d),Vector2(d,tl)]:
						for pz: float in [zs.x,zs.y]:
							dress.append([_box(face-0.02,y0,clampf(pz-0.2,zs.x,zs.y-0.4),face+0.02,top,clampf(pz+0.2,zs.x+0.4,zs.y)),"brace"])
						var mid := Vector3(face,(y0+top)*0.5,(zs.x+zs.y)*0.5)
						for up: float in [-1.0,1.0]:
							var run := Vector3(0.0,(top-y0)*up,zs.y-zs.x)
							var along := run.normalized()
							var across := Vector3(0.0,along.z,-along.y)
							dress.append([Transform3D(Basis(Vector3(0.04,0.0,0.0),across*0.35,along*run.length()),mid),"brace"])
			for zs: Vector2 in [Vector2(-d-0.4,-d),Vector2(d,d+0.4),Vector2(-tl,-tl+0.4),Vector2(tl-0.4,tl)]:
				out.append([_box(-w+TRUSS_SIDE,top,zs.x,w-TRUSS_SIDE,tall,zs.y),"truss"])
			holes.append({"box":_box(-w,y0,-d,w,top,d),"roofed":false,"way":"slide"})
		"crane":
			# A wrecking crane on a flat: its house, its stack, and over the house's
			# back its gantry, the boom's foot between its posts, the boom slung
			# back over the car behind (its idler), under the car's top.
			var low := boom_low(tall)
			var house := 7.2
			var tip := h+GAP*0.5+BOOM_OVER
			var bw := BOOM_WIDE*0.5
			out.append([_box(-w,FLOOR,-h,w,DECK,h),"flat"])
			out.append([_box(-w*0.85,DECK,-h+1.0,w*0.85,house,h-3.2),"crane"])
			out.append([_box(-0.4,house,-h+2.2,0.4,house+1.2,-h+3.0),"iron"])
			out.append([_box(-bw-0.7,house,h-4.2,-bw,tall,h-3.4),"iron"])
			out.append([_box(bw,house,h-4.2,bw+0.7,tall,h-3.4),"iron"])
			out.append([_box(-bw,house,h-4.2,bw,low,h-3.4),"iron"])
			out.append([_box(-bw,low,h-4.2,bw,tall,tip),"boom"])
			# The boom's lattice drawn dark along its sides, the house's windows.
			var z := h-3.0
			while z < tip-0.6:
				for sx: float in [-1.0,1.0]:
					dress.append([_box(sx*bw-0.02,low+0.06,z,sx*bw+0.02,tall-0.06,z+0.25),"brace"])
				z += 1.4
			for sx: float in [-1.0,1.0]:
				dress.append([_box(sx*w*0.85-0.02,house-2.4,-h+2.0,sx*w*0.85+0.02,house-0.8,-h+4.5),"window"])
				dress.append([_box(sx*w*0.85-0.02,house-2.4,h-6.6,sx*w*0.85+0.02,house-0.8,h-4.6),"window"])
				dress.append([_box(sx*w*0.85-0.02,DECK,-1.2,sx*w*0.85+0.02,house-1.0,1.2),"inside"])
			holes.append({"box":_box(-w,DECK,h-3.2,w,low,tip),"roofed":true,"way":"square"})
		"coach":
			# A passenger coach, its ends open platforms under the hoods of its roof,
			# railed round to the railings' top (the opening's floor); its belt line
			# gold, its windows and end doors dark.
			var pl := platform(long)
			var rail := coach_rail(tall)
			var eave := tall-HOOD
			out.append([_box(-w,FLOOR,-h+pl,w,tall,h-pl),"coach"])
			for e: float in [-1.0,1.0]:
				var za := -h if e < 0.0 else h-pl
				var zb := -h+pl if e < 0.0 else h
				out.append([_box(-w,eave,za,w,tall,zb),"roof"])
				out.append([_box(-w,FLOOR,za,-w+RAIL_BAR,rail,zb),"iron"])
				out.append([_box(w-RAIL_BAR,FLOOR,za,w,rail,zb),"iron"])
				var ze := -h if e < 0.0 else h-RAIL_BAR
				out.append([_box(-w+RAIL_BAR,FLOOR,ze,w-RAIL_BAR,rail,ze+RAIL_BAR),"iron"])
				dress.append([_box(-w,FLOOR-0.2,za,w,FLOOR+0.01,zb),"flat"])
				var wall := -h+pl if e < 0.0 else h-pl
				dress.append([_box(-0.9,FLOOR,wall-0.03,0.9,FLOOR+5.0,wall+0.03),"inside"])
				var coupled := -h-GAP*0.5 if e < 0.0 else h+GAP*0.5
				holes.append({"box":_box(-w,rail,minf(za,coupled),w,eave,maxf(zb,coupled)),"roofed":true,"way":"slide"})
			dress.append([_box(-w-0.02,eave,-h+pl,w+0.02,tall+0.02,h-pl),"roof"])
			dress.append([_box(-w-0.03,3.3,-h+pl,w+0.03,3.5,h-pl),"gold"])
			dress.append([_box(-w-0.03,7.1,-h+pl,w+0.03,7.2,h-pl),"gold"])
			var n := 6
			var run := long-2.0*pl
			for sx: float in [-1.0,1.0]:
				for k in range(n):
					var cz := -run*0.5+run*(float(k)+0.5)/float(n)
					dress.append([_box(sx*w-0.03,4.3,cz-0.65,sx*w+0.03,6.6,cz+0.65),"window"])
		"smash":
			# A corridor down its length: its walls and roof, the floor its
			# underframe's top, a plate at each end (records of their own).
			var iw := smash_wide()*0.5
			var lid := FLOOR+smash_high(tall)
			_corridor(out,dress,holes,long,tall,"smash")
			plates.append(_box(-iw,FLOOR,-h,iw,lid,-h+PLATE))
			plates.append(_box(-iw,FLOOR,h-PLATE,iw,lid,h))
			# Cracks down each side, so it is told from the boxcars beside it.
			for sx: float in [-1.0,1.0]:
				for c: Array in SIDE_CRACKS:
					var at := Vector3(sx*(w+0.04),FLOOR+(tall-FLOOR)*(0.5+float(c[1])),float(c[0])*h)
					dress.append([Transform3D(Basis(Vector3.RIGHT,float(c[3]))*Basis.from_scale(Vector3(0.12,float(c[2])*(tall-FLOOR),0.35)),at),"crack"])
	return {"solid":out,"dress":dress,"plates":plates,"holes":holes,"movers":movers}

## A corridor down a car's length (the run's open-ended boxcar, the smash car), its
## walls in `look`, into `out`, `dress` and `holes` (`_parts`): its walls and roof
## round the corridor (`smash_wide` x `smash_high`, the floor its underframe's
## top), lined dark. Its hole, along, out past its ends to the coupling's middle.
static func _corridor(out: Array, dress: Array, holes: Array, long: float, tall: float, look: String) -> void:
	var h := long*0.5
	var w := WIDE*0.5
	var iw := smash_wide()*0.5
	var lid := FLOOR+smash_high(tall)
	out.append([_box(-w,FLOOR,-h,-iw,tall,h),look])
	out.append([_box(iw,FLOOR,-h,w,tall,h),look])
	out.append([_box(-iw,lid,-h,iw,tall,h),look])
	dress.append([_box(-iw,FLOOR,-h,-iw+0.03,lid,h),"inside"])
	dress.append([_box(iw-0.03,FLOOR,-h,iw,lid,h),"inside"])
	dress.append([_box(-iw,lid-0.03,-h,iw,lid,h),"inside"])
	holes.append({"box":_box(-iw,FLOOR,-h-GAP*0.5,iw,lid,h+GAP*0.5),"roofed":true,"way":"along"})

## A boxcar with both side doors slid open (the doors car, the stock car), its
## walls in `look`, into `out` and `dress` (`_parts`): a slot across the car
## under its roof, its walls fore and aft of the doorway, its roof over it, the
## floor its underframe's top. Its hole, roofed.
static func _doorway(out: Array, dress: Array, long: float, tall: float, look: String) -> Dictionary:
	var h := long*0.5
	var w := WIDE*0.5
	var d := door_wide(long)*0.5
	var top := FLOOR+door_high(tall)
	out.append([_box(-w,FLOOR,-h,w,tall,-d),look])
	out.append([_box(-w,FLOOR,d,w,tall,h),look])
	out.append([_box(-w,top,-d,w,tall,d),look])
	# Each side's doors slid open over the walls, a hair proud of them; the
	# doorway's jambs and head lined dark, so it reads as the inside.
	for sx: float in [-1.0,1.0]:
		var x0 := w-0.1 if sx > 0.0 else -w-0.04
		var x1 := w+0.04 if sx > 0.0 else -w+0.1
		dress.append([_box(x0,FLOOR,-d-minf(d,h-d-0.5),x1,top+0.3,-d),"door"])
		dress.append([_box(x0,FLOOR,d,x1,top+0.3,d+minf(d,h-d-0.5)),"door"])
	dress.append([_box(-w,FLOOR,-d,w,top,-d+0.03),"inside"])
	dress.append([_box(-w,FLOOR,d-0.03,w,top,d),"inside"])
	dress.append([_box(-w,top-0.03,-d,w,top,d),"inside"])
	return {"box":_box(-w,FLOOR,-d,w,top,d),"roofed":true,"way":"slide"}

## A crack's strokes: [across (share of the half width or length), up (share of
## the height, off the middle), long (share of the height), turn (rad)].
const CRACKS := [[0.0,0.0,0.9,0.25],[-0.05,0.3,0.45,-0.6],[0.06,-0.28,0.5,0.7],[-0.2,-0.12,0.45,1.15],
	[0.22,0.12,0.5,-1.2],[0.12,0.34,0.3,0.9],[-0.14,-0.36,0.3,-0.9]]
const SIDE_CRACKS := [[0.0,0.0,0.7,0.35],[-0.12,0.22,0.35,-0.7],[0.1,-0.2,0.4,0.8],[-0.25,-0.1,0.3,1.2],[0.28,0.1,0.35,-1.1]]

## A plate's look: the plate, its cracks on both faces.
static func _plate_look(box: AABB) -> Array:
	var out: Array = [[box,"plate"]]
	var c := box.get_center()
	var w := box.size.x
	var hh := box.size.y
	for z: float in [box.position.z-0.05,box.end.z+0.05]:
		for s: Array in CRACKS:
			var xf := Transform3D(Basis(Vector3.BACK,float(s[3]))*Basis.from_scale(Vector3(0.35,float(s[2])*hh,0.1)),
				Vector3(c.x+float(s[0])*w,c.y+float(s[1])*hh,z))
			out.append([xf,"crack"])
	return out

## Blocks as one mesh, a surface a look: each [AABB, look] or [Transform3D of a
## unit box, look].
func _merged(parts: Array) -> ArrayMesh:
	if _unit == null: _unit = BoxMesh.new()
	var by := {}
	for part: Array in parts:
		var key := str(part[1])
		if not by.has(key): by[key] = []
		var xf: Transform3D
		if part[0] is AABB:
			var b: AABB = part[0]
			xf = Transform3D(Basis.from_scale(b.size),b.get_center())
		else: xf = part[0]
		(by[key] as Array).append(xf)
	var mesh := ArrayMesh.new()
	for key: String in by:
		var st := SurfaceTool.new()
		for xf: Transform3D in by[key]: st.append_from(_unit,0,xf)
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count()-1,_mat(key))
	return mesh

static var _unit: BoxMesh

static func _box(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> AABB:
	return AABB(Vector3(x0,y0,z0),Vector3(x1-x0,y1-y0,z1-z0))

## Which of the train's shared materials (assets/models/train/<name>.tres) a
## block's look is made of: what the models' own surfaces are, weathered the same.
const SURFACE := {
	"under":"iron", "iron":"iron", "roof":"metal", "brace":"metal", "truss":"metal",
	"crane":"metal", "boom":"metal", "window":"glass", "culvert":"concrete",
	"inside":"dark", "slat":"dark", "gold":"brass",
}

func _mat(key: String) -> Material:
	if _mats.has(key): return _mats[key]
	var c: Color = LOOKS.get(key,Color.MAGENTA)
	var shared := "res://assets/models/train/%s.tres" % str(SURFACE.get(key,"wood"))
	if GLOW.has(key) or not ResourceLoader.exists(shared):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		# A sky fill of its own: the land's shaders bring theirs, a plain material
		# none, and a car's shaded side went black.
		m.emission_enabled = true
		m.emission = c*FILL
		if GLOW.has(key):
			m.emission = c
			m.emission_energy_multiplier = float(GLOW[key])
		_mats[key] = m
		return m
	# The models' own shader, the block's colour its `tint`: a block carries no
	# vertex colours, so it is weathered as the cars are, not left clean.
	var sm := (load(shared) as ShaderMaterial).duplicate() as ShaderMaterial
	sm.set_shader_parameter(&"tint",c)
	_mats[key] = sm
	return sm

func _exit_tree() -> void:
	if game == null or not is_instance_valid(game.arches): return
	for car: Dictionary in cars:
		for r: Dictionary in car.records: game.arches.loose.erase(r)
	GroundNative.bump_loose()
