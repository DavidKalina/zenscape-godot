extends "res://studies/crossings/crossing.gd"
## The Broken Viaduct (docs/design/roguelike/crossing-viaduct-round1.md):
## a ruined aqueduct curving up about 15 m from the start rim to the far
## rim, a pure-skill crossing on the pilot's own moves (scripts/
## pilot_motor.gd). Everything hangs DROP m over the void
## (docs/design/roguelike/crossing-viaduct-heights.md), its stone ending
## ROOTS under the walk, broken off over the sky: fallen past the void's
## floor he is lost (the yard sends him back to the start rim). Knocked
## off, he may sail out (PilotMotor `knock_sail`) and ride an updraft
## (`updrafts`) back up to the start rim or the turn platform.
##
## The beats, each sized from the walker's moves (a motor fitted to his
## size, `walker()`), never from copied numbers:
## 1. The run-up: RUN_SPANS aqueduct spans (RuinKitAqueduct `span`, real
##    stone and colliders), tilted RUN_DEG up, their channel the deck;
##    the next span fallen, and its far neighbour FALL_DROP lower. The gap
##    `fall_gap` is FALL_SPARE past the furthest a plain running long jump
##    (LONG_SPEED) taken at the lip can still catch the far lip: a chain of
##    two (LONG_ADD on) catches it, a chain of three lands on the deck.
##    (A plain jump twirled at its peak also lands: the twirl is the save.)
## 2. The piers: from a turn platform the route bends TURN_B right, over
##    PIERS standing piers: the first a plain jump up (FIRST_RISE under the
##    jump), each after PIER_RISE higher (the pump's height less
##    PUMP_SPARE). Spaced so a pump taken anywhere in the chain window on
##    one top lands on the next (`pier_gap`). Then the slot's plinth.
##    The safe line: a crumbling stair (RuinKit `stairs`, `safe_flights`
##    flights with rests between) up beside them on the inside of the bend.
## 3. The chimney slot: `slot_piece` (ONE function: the swap to the real
##    tower is one line in it), SLOT_HEIGHT tall, turned SLOT_YAW_DEG, its
##    +Z doorway facing back down the piers at its foot on the plinth.
## 4. The launch: off the slot's east wall head (its local +X) a slab
##    tilted SLAB_DEG down SLAB_RUN, a flat lip LIP_RUN, then `far_gap` to
##    the far rim FAR_DROP under the lip: a slide down it, the long jump
##    off the lip at the slide's pace, and only a twirl carries him to the
##    far rim (or its ledge). Sized by stepping the motor itself over the
##    launch (`launch_reach`).
## The optional wall-run line that skips the chimney is not built (a wall
## run gains at most about a metre; see the doc).
## The hazard (docs/design/roguelike/crossing-viaduct-arrows.md): gust
## arrows (studies/crossings/gust_arrows.gd) from a perch off the pier
## field's left, low (`archer_at`): the piers are in the open to it, and
## they stand between it and the safe stair on their right, so the slow
## line is the covered one.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const RuinKitTower = preload("res://scripts/ruin_kit_tower.gd")
const GustArrows = preload("res://studies/crossings/gust_arrows.gd")
const HornStandIn = preload("res://studies/crossings/horn_stand_in.gd")
const HornPerch = preload("res://studies/crossings/horn_perch.gd")
const RuinKitHorn = preload("res://scripts/ruin_kit_horn.gd")
const Slam = preload("res://scripts/slam.gd")
const ViaductArt = preload("res://studies/crossings/viaduct_art.gd")
const PocketSail = preload("res://scripts/pocket_sail.gd")

const SEED := 4107
## Weathering of the stone (0 new to 1 ruin).
const WEATHERED := 0.35

## The void under the walk top (m): falling past it is a fall to his death.
## The stone (piers, spans, stair) reaches ROOTS under the walk top and
## ends there, broken off over the sky (deeper than the aqueduct's deck
## over its springing, so its spans stand whole).
const DROP := 100.0
const ROOTS := 26.0
## The updrafts (thermals, scripts/sky_currents.gd): their radius (m), and
## how far their tops stand over the landing each serves (m: a ridden sail
## settles about 6 m under a thermal's top, as its lift fades, so it hovers
## a few metres over the landing and glides onto it).
const UPDRAFT_RADIUS := 6.0
const UPDRAFT_OVER := 10.0
## Where: the start rim's, left of the run-up (x, z local: the deck's perch
## throws to the left); the turn platform's, left of the piers' foot and
## right past the platform and the safe stair (along the piers, aside).
const UPDRAFT_START := Vector2(-12.0,1.0)
const UPDRAFT_TURN_LEFT := Vector2(6.0,-11.0)
const UPDRAFT_TURN_RIGHT := Vector2(2.0,14.0)
## The start rim: across and deep (m).
const RIM := Vector2(12.0,12.0)
## 1. The run-up: spans, their tilt end to end (degrees: under the
## motor's SLIDE_END, so it is flat ground to the slide and long jump),
## the fallen span's far side under the lip (m: deep enough that a faster
## long jump's longer reach outgrows a slower one's catch by more than
## where a chain's last takeoff falls), and how far past a plain jump's
## furthest catch the far deck starts (m).
const RUN_SPANS := 3
const RUN_DEG := 4.5
const FALL_DROP := 4.0
const FALL_SPARE := 0.5
## The turn platform past the far deck: along, across, and how far right
## of the pier line it reaches (for the safe stair).
const TURN_PAD := Vector2(6.0,6.0)
const TURN_PAD_RIGHT := 7.0
## 2. The piers: the bend, how many, their tops (across, along), the first
## one's rise under the plain jump, and how much under the pump each rise
## is kept.
const TURN_B := 55.0
const PIERS := 10
const PIER_TOP := Vector2(2.4,2.0)
const FIRST_SPARE := 0.3
const PUMP_SPARE := 0.6
## The safe stair: how far right of the pier line (its flights: as many
## as climb to the plinth, `safe_flights`).
const SAFE_ASIDE := 4.6
## 3. THE CHIMNEY SLOT. Its plinth's half size round it (room for a piece
## up to 8 x 8 m and its rubble), the turn (degrees about up: its +Z front
## faces back down the piers), its height. Its middle: `slot_at()`.
const SLOT_PLINTH := 4.6
const SLOT_YAW_DEG := -TURN_B
const SLOT_HEIGHT := 12.0
## 4. The launch: off the slot's east head (heading TURN_B+90), the slab's
## tilt (degrees), horizontal run and width, the flat lip, the far rim's
## drop under the lip and its size (along, across).
const SLAB_DEG := 28.0
const SLAB_RUN := 7.5
const SLAB_WIDE := 2.6
const LIP_RUN := 2.0
const FAR_DROP := 0.5
## How far past the bare launch's furthest catch the far rim starts (m):
## the twirl's landing reaches about 0.75 m past that catch.
const LAUNCH_SPARE := 0.3
const FAR_RIM := Vector2(12.0,14.0)

## The stand-in's numbers: the real piece's (RuinKitTower.tower_shell):
## footprint half extents (x, z), the shaft's half clear (x, z: kicked
## between its east and west walls), the doorway (width, height) in the
## front wall, the front and back walls' heads under the rims.
const STAND_HALF := Vector2(2.39,2.70)
const STAND_SHAFT := Vector2(0.99,1.3)
const STAND_DOOR := Vector2(1.3,2.6)
const STAND_LOW := 1.0

## The gust arrows' left perch stands at the end of its route (`routes`,
## LEFT_*), its mouth ARCHER_CLEAR over its top (the stand-in horn's). The
## zone it fires on: the piers' line from the turn platform's edge to
## ARCHER_TO of the way to the plinth, ARCHER_ZONE.x to their left and the
## safe stair's line plus ARCHER_ZONE.y to their right (m), from the turn
## platform's top up; and its own route.
const ARCHER_CLEAR := RuinKitHorn.PED_H+RuinKitHorn.AXIS
const ARCHER_ZONE := Vector2(3.0,2.0)
## The far side's perch stands at the end of its route off the plinth
## (FAR_TURN). It fires on the piers and the safe stair from FAR_ARCHER_FROM
## of the way on (the stair is covered from the left perch only), and on its
## route.
const FAR_ARCHER_FROM := 0.45
## The deck's perch: along the run-up (share of the way to the lip), right
## of it (m), over the deck there (m: over the parapets), and how far
## either side of the deck's line it fires on (m).
const DECK_ARCHER_ALONG := 0.55
const DECK_ARCHER_ASIDE := 16.0
const DECK_ARCHER_UP := 2.5
const DECK_ARCHER_ZONE := 3.0
## The left perch fires on the field up to this share of the way to the
## plinth (the last piers are the far perch's; docs/design/roguelike/
## crossing-viaduct-perches.md).
const ARCHER_TO := 0.7

## THE PERCHES (docs/design/roguelike/crossing-viaduct-perches.md): each a
## wind horn (`perch_piece`: ONE function, the stand-in now, the stone horn
## later) on a ruin-kit pillar (RuinKitAqueduct `pillar`) whose top, PERCH_TOP m square, he can stand
## on and slam to disable it (GustArrows DISABLE_TIME). The horn stands
## HORN_BACK m back of the top's middle, away from his way in. Its mouth is
## the horn's (its "Mouth" marker), ARCHER_CLEAR over the top in the stand-in.
const PERCH_TOP := 3.2
const HORN_BACK := 0.9
## A perch's route out (`_route`): from a departure on the line, a gap a
## plain long jump can't make but a jump and the sail can (the first stone
## ROUTE_DROP m down, SAIL_SPARE m past the plain long jump's reach to it),
## then a plain floating stone, a sinking one (scripts/interactables/
## sink_slab.gd), a plain one, STEP_GAP apart (a running hop); the last
## stands `slam_over` (the slam's least air plus a pump's height) over the perch's
## top, PERCH_STEP m off its edge: off it, Shift/C in the air slams the top.
const ROUTE_DROP := 1.5
const SAIL_SPARE := 1.5
const STONE := Vector3(2.4,0.7,2.2)
const STEP_GAP := 1.4
const PERCH_STEP := 0.6
## The route's stones stand ROUTE_ASIDE m off the sightline from the
## departure to the horn (the last one steps in beside the perch's top),
## on the side LEFT_SIDE / FAR_SIDE (1 right, -1 left): the horn in plain
## view past them, the way out a curve to it.
const ROUTE_ASIDE := 4.8
const LEFT_SIDE := -1.0
const FAR_SIDE := 1.0
## The left perch's route: off pier LEFT_FROM, LEFT_TURN degrees left of
## the piers' heading. The far perch's: off the slot's plinth, FAR_TURN
## degrees right of the piers' heading.
const LEFT_FROM := 3
const LEFT_TURN := 70.0
const FAR_TURN := 125.0
## A perch fires on its own route too (a detour under fire): ROUTE_ZONE m
## either side of it, from ROUTE_UNDER under the departure to over it.
const ROUTE_ZONE := 3.0
const ROUTE_UNDER := 8.0
## The way back: an updraft just past each routed perch (PERCH_DRAFT_RADIUS
## round), topping out so a ridden sail glides back to the departure: the
## sail settles DRAFT_SETTLE m under a thermal's top, and loses a metre in
## PocketSail PACE/SINK on the way back, DRAFT_SPARE m to spare.
const PERCH_DRAFT_RADIUS := 4.5
const DRAFT_SETTLE := 6.0
const DRAFT_SPARE := 1.5
## The low perches: in the void band under the route, firing at him only
## off his feet (falling, under the sail; never tumbling or on the route).
## Each (along, aside, up) from the turn platform's middle along the piers.
## LOW_BLOCK m of stone under the top; they fire while he is ROUTE_CLEAR m
## under the turn platform, within LOW_REACH m above or below the top;
## a slower turn (LOW_COOLDOWN), a shorter reach (LOW_RANGE), and they lead
## him (LOW_LEAD: a sail flies steady, so the counter is a turn).
const LOW_PERCHES := [Vector3(16.0,-21.0,-22.0),Vector3(10.0,24.0,-32.0),Vector3(-30.0,-18.0,-18.0)]
const LOW_BLOCK := 5.0
const ROUTE_CLEAR := 3.0
const LOW_REACH := 30.0
const LOW_COOLDOWN := 3.0
const LOW_RANGE := 45.0
const LOW_LEAD := 0.6

## ART (docs/design/roguelike/crossing-viaduct-art.md; studies/crossings/
## viaduct_art.gd): the walk tops' clean boxes' depth (m) under the isles;
## the isles' keels (m under their tops: the start rim's, the turn
## platform's, the plinth's, the far rim's); the clods under the piers'
## feet (half across and along, keel depth); how deep the safe stair's
## broken piers and the launch lip's reach under their tops; the launch's
## lintel's thickness; the far rim's broken gate, in from its back corners
## (along, across).
const TOP_SOLID := 2.2
const START_DEPTH := 15.0
const TURN_DEPTH := 10.0
const PLINTH_DEPTH := 12.0
const FAR_DEPTH := 15.0
const CLOD_PIER := Vector2(2.6,1.9)
const CLOD_DEPTH := 7.0
const STAIR_ROOT := 7.0
const LIP_ROOT := 13.0
const SLAB_THICK := 0.9
const GATE_IN := Vector2(1.6,1.8)
## The growth (RuinKit `set_detail`) on the piers' and the stair's kit stone.
const COLUMN_DETAIL := 0.45

var m: PilotMotor
## Worked out by `lay_out` (local).
var deck := 0.0
var run_rise := 0.0
var safe_flights := 0
var fall_gap := 0.0
var lip := Vector3.ZERO
var far_start := Vector3.ZERO
var turn_mid := Vector3.ZERO
var pier_gap := 0.0
var pier_rise := 0.0
var first_rise := 0.0
var pier_tops: Array[Vector3] = []
var plinth_near := 0.0
var slot_foot := Vector3.ZERO
var launch_pace := 0.0
var far_gap := 0.0
var slab_top := Vector3.ZERO
var lip_end := Vector3.ZERO
var far_near := Vector3.ZERO
var numbers := {}
var arrows: GustArrows
## The perches' routes, worked out by `lay_out` (`_route`): "left" and
## "far", each {from (departure top, local), deg, sail_gap, stones
## [{kind, at, yaw}], top (perch top's middle), draft {base, top}}.
var routes := {}
var slam_over := 0.0
var sail_gap := 0.0
## The art's: the isles' walk boxes and outlines (the plants' ground) and
## the floors laid on them ([middle (x, z), heading]).
var turf_bodies: Array = []
var turf_outlines: Array = []
var paved: Array = []

func title() -> String:
	return "The Broken Viaduct"

func lay_out() -> void:
	m = walker()
	deck = Aqueduct.DECK
	# 1. The fallen span.
	var span := Aqueduct.SPAN
	run_rise = span*RUN_SPANS*tan(deg_to_rad(RUN_DEG))
	lip = Vector3(0.0,run_rise,-span*RUN_SPANS)
	var plain := m.long_speed
	var chain2 := minf(plain+m.long_add,m.long_top)
	var chain3 := minf(chain2+m.long_add,m.long_top)
	var miss := catch_reach(plain,FALL_DROP)
	var make := long_reach(chain3,FALL_DROP)
	fall_gap = miss+FALL_SPARE
	assert(fall_gap+1.0 < make,"viaduct: the chain of three does not outreach a plain catch by a takeoff's slack")
	var y2 := run_rise-FALL_DROP
	far_start = Vector3(0.0,y2,lip.z-fall_gap)
	var far_end := far_start.z-span
	turn_mid = Vector3(0.0,y2,far_end-TURN_PAD.y*0.5)
	# 2. The piers: the pump's flight onto a top PIER_RISE up, at a run.
	first_rise = float(m.jumps[0])-FIRST_SPARE
	pier_rise = float(m.jumps[1])-PUMP_SPARE
	var flight := m.run*jump_time(float(m.jumps[1]),pier_rise)
	# A pump taken anywhere in the chain window lands on the next top.
	pier_gap = flight-m.run*m.chain_window
	var s := TURN_PAD.y*0.5+pier_gap
	var y := y2+first_rise
	for i in range(PIERS):
		pier_tops.append(at(turn_mid,TURN_B,s+PIER_TOP.y*0.5,0.0,y-turn_mid.y))
		s += PIER_TOP.y+pier_gap
		y += pier_rise
	plinth_near = s
	var climb := float(RuinKit.STEPS)*RuinKit.RISER
	safe_flights = ceili((y-y2)/climb-0.05)
	slot_foot = at(turn_mid,TURN_B,s+SLOT_PLINTH,0.0,y-turn_mid.y)
	# 4. The launch: off the east head, slid down, long-jumped, twirled.
	var c_deg := TURN_B+90.0
	slab_top = at(slot_foot,c_deg,STAND_HALF.x,0.0,SLOT_HEIGHT)
	var drop := SLAB_RUN*tan(deg_to_rad(SLAB_DEG))
	var slab_low := at(slab_top,c_deg,SLAB_RUN,0.0,-drop)
	lip_end = at(slab_low,c_deg,LIP_RUN)
	launch_pace = surf_pace(drop)
	var bare := launch_reach(launch_pace,false)
	var twirled := launch_reach(launch_pace,true)
	var bare_catch := catch_reach(launch_pace,FAR_DROP)
	assert(maxf(bare,bare_catch) < twirled,"viaduct: the twirl does not outreach the bare launch")
	far_gap = maxf(bare,bare_catch)+LAUNCH_SPARE
	assert(far_gap < twirled,"viaduct: the twirl does not reach past the spare")
	far_near = at(lip_end,c_deg,far_gap,0.0,-FAR_DROP)
	# The perches' routes: a jump and the sail out, stones, the slam.
	slam_over = Slam.LOW*m.size+float(m.jumps[1])
	sail_gap = long_reach(m.long_speed,ROUTE_DROP)+SAIL_SPARE
	assert(sail_gap+1.0 < sail_reach(ROUTE_DROP),"viaduct: a perch route's sail gap is past the sail's reach")
	var left_deg := TURN_B-LEFT_TURN
	routes["left"] = _route(pier_tops[LEFT_FROM],left_deg,PIER_TOP*0.5,-LEFT_TURN,LEFT_SIDE)
	var far_deg := TURN_B+FAR_TURN
	routes["far"] = _route(slot_foot,far_deg,Vector2(SLOT_PLINTH,SLOT_PLINTH),FAR_TURN,FAR_SIDE)
	numbers = {"slam_over":slam_over,"sail_gap":sail_gap,"sail_reach":sail_reach(ROUTE_DROP),"left_perch_top":routes.left.top,"far_perch_top":routes.far.top,"run_rise":run_rise,"fall_gap":fall_gap,"plain_catch":miss,"chain3_land":make,"chain2_land":long_reach(chain2,FALL_DROP),
		"chain2_catch":catch_reach(chain2,FALL_DROP),"plain_land":long_reach(plain,FALL_DROP),
		"pier_gap":pier_gap,"pier_rise":pier_rise,"first_rise":first_rise,"pump_flight":flight,
		"slot_foot":slot_foot,"slot_top":slot_foot.y+SLOT_HEIGHT,"launch_pace":launch_pace,"bare_land":bare,
		"bare_catch":bare_catch,"twirl_land":twirled,"far_gap":far_gap,"far_top":far_near.y,"safe_flights":safe_flights}

# --- The walker's reach ------------------------------------------------------------

## Seconds a jump `high` m high from the ground is in the air until it is
## back down `rise` m over its takeoff (the motor's own arc: rising on
## gravity, falling on its FALL share).
func jump_time(high: float, rise: float) -> float:
	return sqrt(2.0*high/m.gravity)+sqrt(2.0*maxf(high-rise,0.0)/(m.gravity*m.fall))

## How far a long jump at `pace` comes down `drop` m under its takeoff
## (its own gravity rising and falling alike).
func long_reach(pace: float, drop: float) -> float:
	var g := m.long_gravity
	return pace*(sqrt(2.0*m.long_height/g)+sqrt(2.0*(m.long_height+drop)/g))

## The furthest a long jump at `pace` can still catch a lip `drop` m under
## its takeoff: the hands (hang_drop over the feet) come down to GRAB_HIGH
## under it, GRAB_REACH ahead.
func catch_reach(pace: float, drop: float) -> float:
	var g := m.long_gravity
	var low := m.long_height+drop+m.hang_drop+PilotMotor.GRAB_HIGH
	return pace*(sqrt(2.0*m.long_height/g)+sqrt(2.0*low/g))+PilotMotor.GRAB_REACH

## About how far a running jump opened into the sail at its top carries
## him, coming down `drop` m under its takeoff (no kick, no swoop: a
## cautious reach): the jump's rise at a run, then the sail's glide
## (PocketSail PACE on for SINK down) down the jump's height and the drop.
func sail_reach(drop: float) -> float:
	var up := float(m.jumps[0])
	return m.run*sqrt(2.0*up/m.gravity)+PocketSail.PACE/PocketSail.SINK*(up+drop)

## How far out from its middle a top `half` m round (across, along) ends,
## going `turn` degrees off its along.
static func _edge_out(half: Vector2, turn: float) -> float:
	var a := deg_to_rad(turn)
	var along := absf(cos(a))
	var across := absf(sin(a))
	return minf(half.y/along if along > 0.001 else INF,half.x/across if across > 0.001 else INF)

## A perch's route off the top `from` (its middle, local; `half` its half
## size, across and along the piers, the route leaving `turn` degrees off
## them), heading `deg` at the perch: the stones off to its `side` (1
## right, -1 left) of the sightline, so the horn stands clear past them
## from the departure. The sail gap out on a slant to the plain stone
## (ROUTE_ASIDE off the line), the sinking one beside it, the last stone
## stepped in (PERCH_STEP off the top's side, `slam_over` over it), the
## perch's top beside its far end; and its updraft back, just past the
## perch.
func _route(from: Vector3, deg: float, half: Vector2, turn: float, side: float) -> Dictionary:
	var y := from.y-ROUTE_DROP
	var aside := side*ROUTE_ASIDE
	# The slant out to the first stone: its edge on the departure that way,
	# the sail gap, half a stone.
	var slant := 0.0
	var edge := _edge_out(half,turn)
	var reach := edge+sail_gap+STONE.z*0.5
	for i in range(3):
		slant = asin(clampf(ROUTE_ASIDE/reach,-1.0,1.0))
		edge = _edge_out(half,turn+rad_to_deg(slant)*side)
		reach = edge+sail_gap+STONE.z*0.5
	var s := reach*cos(slant)
	var beside := side*(PERCH_TOP*0.5+PERCH_STEP+STONE.x*0.5)
	var stones := []
	for kind: String in ["bob","sink","bob"]:
		var last := stones.size() == 2
		stones.append({"kind":kind,"at":at(Vector3(from.x,y,from.z),deg,s,beside if last else aside),"yaw":yaw_of(deg)})
		s += STONE.z+STEP_GAP
	s += -STEP_GAP-STONE.z*0.5
	var top := at(Vector3(from.x,y-slam_over,from.z),deg,s)
	var out := PERCH_TOP*0.5+PERCH_DRAFT_RADIUS+1.0
	var base := at(top,deg,out)
	var back := Vector2(base.x-from.x,base.z-from.z).length()
	var draft_top := from.y+DRAFT_SETTLE+back*PocketSail.SINK/PocketSail.PACE+DRAFT_SPARE
	return {"from":from,"deg":deg,"edge":edge,"side":side,"slant":rad_to_deg(slant)*side,"stones":stones,"top":top,"draft":{"base":Vector3(base.x,-DROP,base.z),"top":draft_top}}

## The slide's pace off the launch's lip: in at a run, surfed down the slab
## (the motor's pull, drag and air), slid along half the flat lip.
func surf_pace(drop: float) -> float:
	var dt := 1.0/240.0
	var v := m.run
	var rise := drop/SLAB_RUN
	var pull := m.slide_pull*sin(atan(rise))-PilotMotor.SLIDE_DRAG
	var x := 0.0
	while x < SLAB_RUN:
		v = minf(v+(pull-m.slide_air*v*v)*dt,m.slide_top)
		x += v*dt
	x = 0.0
	while x < LIP_RUN*0.5:
		v -= (m.slide_runout+m.slide_air*v*v)*dt
		x += v*dt
	return v

## How far the motor's own long jump off flat ground at `pace` comes down
## FAR_DROP lower, twirled at its peak or not: stepped as the game steps
## him, the stick held on.
func launch_reach(pace: float, twirl: bool) -> float:
	var sim := walker()
	sim.reset(Vector3.ZERO,0.0,pace)
	var ground := func(p: Vector2) -> float: return 0.0 if p.y > -0.05 else -FAR_DROP
	var slide := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)
	sim.crouch = true
	var from := INF
	for i in range(600):
		var jump := i == 0
		sim.twirl = twirl and from != INF and sim.velocity.y <= 0.0
		var out: Dictionary = sim.step(1.0/120.0,Vector2(0.0,-1.0),sim.run,jump,ground,slide)
		if out.has("jumped"): from = sim.feet.z
		if from != INF and sim.grounded: return from-sim.feet.z
	return 0.0

# --- The contract ------------------------------------------------------------------

func entry() -> Dictionary:
	return {"at":Vector3(0.0,0.0,RIM.y*0.45),"face":ENTRY_FACE}

func exit() -> Dictionary:
	return {"at":at(far_near,TURN_B+90.0,4.0),"face":way(TURN_B+90.0)}

func exit_reached(feet: Vector3) -> bool:
	var w := way(TURN_B+90.0)
	var d := Vector2(feet.x-far_near.x,feet.z-far_near.z)
	var along := d.dot(w)
	var aside := d.dot(right_of(w))
	return absf(feet.y-far_near.y) < 0.3 and along > 0.0 and along < FAR_RIM.x and absf(aside) < FAR_RIM.y*0.5

func beats() -> Array:
	var c := way(TURN_B+90.0)
	return [
		{"name":"run-up","at":entry().at,"face":ENTRY_FACE},
		{"name":"piers","at":at(turn_mid,TURN_B,0.0),"face":way(TURN_B)},
		{"name":"chimney","at":at(turn_mid,TURN_B,plinth_near+0.8,0.0,slot_foot.y-turn_mid.y),"face":way(TURN_B)},
		{"name":"launch","at":at(slot_foot,TURN_B+90.0,(STAND_SHAFT.x+STAND_HALF.x)*0.5,0.0,SLOT_HEIGHT),"face":c},
		{"name":"far rim","at":exit().at,"face":c},
	]

func floor_y() -> float:
	return -DROP

## The updrafts back up (none to the far end: a recovery costs progress,
## not the run): beside the start rim, and either side of the turn
## platform, each rising from the void to UPDRAFT_OVER over its landing.
func updrafts() -> Array:
	var left := at(turn_mid,TURN_B,UPDRAFT_TURN_LEFT.x,UPDRAFT_TURN_LEFT.y)
	var right := at(turn_mid,TURN_B,UPDRAFT_TURN_RIGHT.x,UPDRAFT_TURN_RIGHT.y)
	var all := [
		{"name":"start rim","base":Vector3(UPDRAFT_START.x,-DROP,UPDRAFT_START.y),"top":UPDRAFT_OVER,"radius":UPDRAFT_RADIUS},
		{"name":"turn platform, left","base":Vector3(left.x,-DROP,left.z),"top":turn_mid.y+UPDRAFT_OVER,"radius":UPDRAFT_RADIUS},
		{"name":"turn platform, right","base":Vector3(right.x,-DROP,right.z),"top":turn_mid.y+UPDRAFT_OVER,"radius":UPDRAFT_RADIUS},
	]
	# The way back from each routed perch.
	for key: String in routes:
		var d: Dictionary = routes[key].draft
		all.append({"name":"%s perch" % key,"base":d.base,"top":d.top,"radius":PERCH_DRAFT_RADIUS})
	return all

## The stones' bodies once made (`foot_stones`): the gust arrows fly
## through them, so a route doesn't shield the line its perch guards.
func stones_made(rids: Array[RID]) -> void:
	if arrows != null: arrows.set_see_through(rids)

## The floating stones out to the perches ({kind "bob" or "sink", at (the
## top's middle, local), yaw, size}): the yard makes them as foot pieces
## (scripts/interactables/foot_pieces.gd), which carry him as they move.
func foot_stones() -> Array:
	var all := []
	for key: String in routes:
		for st: Dictionary in routes[key].stones:
			all.append({"kind":st.kind,"at":st.at,"yaw":st.yaw,"size":STONE,"route":key})
	return all

## The chimney slot's middle at its foot (local).
func slot_at() -> Vector3:
	return slot_foot

# --- Building ----------------------------------------------------------------------

func build(paint: Callable) -> void:
	super.build(paint)
	# The stone ends ROOTS under the walk, over the void.
	var low := -ROOTS
	turf_bodies = []
	turf_outlines = []
	paved = []
	# The start rim: a sky isle, a paved apron where the deck begins.
	_isle_under("StartIsle",Vector3(0.0,0.0,RIM.y*0.5),0.0,RIM*0.5,START_DEPTH,SEED+100)
	_pave(Vector3(0.0,0.0,RuinKit.FLOOR.x*0.5),0.0,SEED+110)
	_run_up(low)
	_piers(low)
	_safe_stair(low)
	var slot := slot_piece(SEED,WEATHERED,SLOT_HEIGHT)
	slot.name = "ChimneySlot"
	slot.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(SLOT_YAW_DEG)),slot_foot)
	add_child(slot)
	_launch(low)
	_arrows(low)

## ART (docs/design/roguelike/crossing-viaduct-art.md): a walk top's clean
## collision (a box TOP_SOLID deep, its top and edges the greybox's) under a
## sky isle drawn over it (ViaductArt `isle`: turf, a keel of hanging rock
## `depth` deep); `half` (across, along) round `middle`, heading `deg`.
## Its box is the plants' turf (`flora_turf`).
func _isle_under(called: String, middle: Vector3, deg: float, half: Vector2, depth: float, seed_value: int) -> void:
	var walk := box(Vector3(half.x*2.0,TOP_SOLID,half.y*2.0),middle-Vector3(0.0,TOP_SOLID*0.5,0.0),deg,"")
	walk.name = called+"Walk"
	turf_bodies.append(walk)
	var ring := ViaductArt.rect_ring(middle,deg,half,seed_value)
	var isle := ViaductArt.isle(ring,middle.y,depth,seed_value,_paved_wear(),TOP_SOLID)
	isle.name = called
	add_child(isle)
	turf_outlines.append(isle.get_meta("outline"))

## A kit floor (RuinKit `floor_slabs`, drawn only) laid on a walk top: its
## slabs' tops flush with `middle`'s height, turned to heading `deg`; the
## turf under it worn bare and no plants on it (`paved`).
func _pave(middle: Vector3, deg: float, seed_value: int) -> void:
	piece(RuinKit.floor_slabs(seed_value,0.45),Transform3D(Basis(Vector3.UP,yaw_of(deg)),middle-Vector3(0.0,RuinKit.FLOOR.z-0.01,0.0)),false)
	paved.append([Vector2(middle.x,middle.z),deg])

## Worn bare under the floors (`paved`): (x, z) local -> 0..1.
func _paved_wear() -> Callable:
	return func(p: Vector2) -> float:
		var most := 0.0
		for f: Array in paved:
			var w := way(float(f[1]))
			var d := p-(f[0] as Vector2)
			var out := maxf(absf(d.dot(w)),absf(d.dot(right_of(w))))-RuinKit.FLOOR.x*0.5
			most = maxf(most,clampf(1.0-out/0.6,0.0,1.0))
		return most

## The plants' ground (the yard grows its grass and flowers on it,
## scripts/kit_isle/kit_flora.gd): the isles' walk boxes, their outlines
## (local x, z), and the wear (`_paved_wear`).
func flora_turf() -> Array:
	return turf_bodies

func flora_outlines() -> Array:
	return turf_outlines

func flora_wear() -> Callable:
	return _paved_wear()

## A clod of turf and rock (ViaductArt `clod`) with its top at `middle`'s
## height, `half` round it (heading `deg`): piers' feet stand on it.
func _clod(middle: Vector3, deg: float, half: Vector2, depth: float, seed_value: int) -> void:
	add_child(ViaductArt.clod(ViaductArt.blob_ring(middle,deg,half,seed_value),middle.y,depth,seed_value))

## A pier's coursed stone (RuinKitAqueduct `pillar`, drawn only) over a
## column's clean collision (`column`, drawn nothing): its impost's top the
## column's top, its edge the column's edge (the shaft under it stands in
## by the impost's reach).
func _kit_column(foot: Vector3, size: Vector2, bottom: float, top: float, deg: float, seed_value: int) -> void:
	column(foot,size,bottom,top,deg,"")
	var drawn := Vector2(size.x-Aqueduct.IMPOST.y*2.0,size.y-0.12)
	# Sixteen tall piers: their ivy and moss thinned (RuinKit `set_detail`;
	# the stone is the same) to keep the frame's triangles sane.
	var was := RuinKit.Build.detail
	RuinKit.set_detail(minf(was,COLUMN_DETAIL))
	piece(Aqueduct.pillar(seed_value,WEATHERED,top-bottom,drawn),Transform3D(Basis(Vector3.UP,yaw_of(deg)),Vector3(foot.x,bottom,foot.z)),false)
	RuinKit.set_detail(was)

## 1. The spans (tilted, their piers grown down to the floor), a clean walk
## over their channel, the far deck; each pier's foot on a clod; the turn
## platform a sky isle.
func _run_up(low: float) -> void:
	var span := Aqueduct.SPAN
	var tilt := deg_to_rad(RUN_DEG)
	# A span runs along its x: turned so +x runs down -Z, nose up by tilt.
	var basis := Basis(Vector3.UP,PI*0.5)*Basis(Vector3.BACK,tilt)
	for i in range(RUN_SPANS):
		var s := span*(i+0.5)
		var mid := Vector3(0.0,s*tan(tilt),-s)
		var origin := mid-basis*Vector3(0.0,deck,0.0)
		var ground := func(x: float, _z: float) -> float: return (low-origin.y-x*sin(tilt))/cos(tilt)
		var node := Aqueduct.span(SEED+i,WEATHERED,3 if i == 0 else 2,false,ground)
		piece(node,Transform3D(basis,origin))
	slab(Vector3(0.0,0.0,0.0),lip,Aqueduct.CHANNEL,0.3,"")
	# The far deck: one span, level, its channel starting fall_gap on.
	var far_mid := Vector3(0.0,far_start.y,far_start.z-span*0.5)
	var far_origin := far_mid-Vector3(0.0,deck,0.0)
	var far_ground := func(_x: float, _z: float) -> float: return low-far_origin.y
	piece(Aqueduct.span(SEED+9,WEATHERED,3,false,far_ground),Transform3D(Basis(Vector3.UP,PI*0.5),far_origin))
	box(Vector3(Aqueduct.CHANNEL,0.3,span),far_mid-Vector3(0.0,0.15,0.0),0.0,"")
	# The piers' feet, each on its clod.
	var feet: Array[float] = []
	for i in range(RUN_SPANS+1): feet.append(-span*i)
	feet.append_array([far_start.z,far_start.z-span])
	for k in range(feet.size()):
		_clod(Vector3(0.0,low,feet[k]),0.0,CLOD_PIER,CLOD_DEPTH+float(k%3)*1.5,SEED+120+k)
	# The turn platform: a sky isle, paved where the route crosses it.
	var pad_mid := at(turn_mid,TURN_B,0.0,(TURN_PAD_RIGHT-TURN_PAD.x*0.5)*0.5)
	_isle_under("TurnIsle",pad_mid,TURN_B,Vector2((TURN_PAD.x*0.5+TURN_PAD_RIGHT)*0.5,TURN_PAD.y*0.5),TURN_DEPTH,SEED+130)
	_pave(turn_mid,TURN_B,SEED+131)
	_pave(at(turn_mid,TURN_B,0.0,RuinKit.FLOOR.x),TURN_B,SEED+132)

## 2. The piers (the kit's coursed stone over their clean columns), their
## feet on clods in runs; the slot's plinth a sky isle, paved under the
## tower.
func _piers(low: float) -> void:
	for i in range(pier_tops.size()):
		var top: Vector3 = pier_tops[i]
		_kit_column(top,PIER_TOP,low,top.y,TURN_B,SEED+140+i)
	for g: Array in [[0,1,2],[3,4,5],[6,7],[8,9]]:
		var a: Vector3 = pier_tops[g[0]]
		var b: Vector3 = pier_tops[g[g.size()-1]]
		var mid := (a+b)*0.5
		var half_along := Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))*0.5+PIER_TOP.y*0.5+0.7
		_clod(Vector3(mid.x,low,mid.z),TURN_B,Vector2(CLOD_PIER.x*0.75,half_along),CLOD_DEPTH+g.size(),SEED+150+int(g[0]))
	_isle_under("PlinthIsle",slot_foot,TURN_B,Vector2(SLOT_PLINTH,SLOT_PLINTH),PLINTH_DEPTH,SEED+160)
	for sx: float in [-1.0,1.0]:
		for sz: float in [-1.0,1.0]:
			_pave(at(slot_foot,TURN_B,sz*RuinKit.FLOOR.x*0.5,sx*RuinKit.FLOOR.x*0.5),TURN_B,SEED+161+int(sx+1.0)+int(sz+1.0)*2)

## The safe line: stair flights up beside the piers, a rest between each,
## the last arriving at the plinth's edge; the first's foot at or under the
## turn platform (stepped down onto from it). Each flight and rest on a
## kit pier STAIR_ROOT or so deep, broken off over the sky: the crumbling
## stair hangs.
func _safe_stair(_low: float) -> void:
	var climb := float(RuinKit.STEPS)*RuinKit.RISER
	var run := float(RuinKit.STEPS-1)*RuinKit.TREAD+RuinKit.LANDING
	var from := TURN_PAD.y*0.5
	var length := plinth_near-from
	var rest := (length-run*safe_flights)/float(safe_flights-1)
	var foot_y := slot_foot.y-climb*safe_flights
	assert(foot_y < turn_mid.y+PilotMotor.STEP_UP-RuinKit.RISER and rest > 0.5,"viaduct: the safe stair does not fit")
	var s := from
	for i in range(safe_flights):
		var y := foot_y+climb*i
		var mid := at(turn_mid,TURN_B,s+run*0.5,SAFE_ASIDE)
		_kit_column(mid,Vector2(RuinKit.STAIR_WIDTH+0.8,run),y-STAIR_ROOT-float(i%2)*2.5,y,TURN_B,SEED+170+i)
		piece(RuinKit.stairs(SEED+30+i,0.6),Transform3D(Basis(Vector3.UP,yaw_of(TURN_B)),Vector3(mid.x,y,mid.z)))
		s += run
		if i < safe_flights-1:
			_kit_column(at(turn_mid,TURN_B,s+rest*0.5,SAFE_ASIDE),Vector2(RuinKit.STAIR_WIDTH+0.8,rest+0.02),y+climb-STAIR_ROOT*0.6,y+climb,TURN_B,SEED+180+i)
			s += rest

## 4. The slab off the east head (a great lintel fallen from the tower,
## tilted, its clean walk under it), its lip a broken end on a broken pier,
## the far rim a sky isle with a broken gate's piers at its back.
func _launch(_low: float) -> void:
	var c_deg := TURN_B+90.0
	var drop := SLAB_RUN*tan(deg_to_rad(SLAB_DEG))
	var slab_low := at(slab_top,c_deg,SLAB_RUN,0.0,-drop)
	var walk := slab(slab_top,slab_low,SLAB_WIDE,0.5,"")
	# The lintel: its top the walk's, in the slab's own frame.
	var length := slab_top.distance_to(slab_low)
	var stone := ViaductArt.slab_stone(SEED+190,WEATHERED,Vector3(SLAB_WIDE+0.1,SLAB_THICK,length+0.25),3)
	piece(stone,Transform3D(walk.transform.basis,(slab_top+slab_low)*0.5),false)
	box(Vector3(SLAB_WIDE,0.5,LIP_RUN),at(slab_low,c_deg,LIP_RUN*0.5,0.0,-0.25),c_deg,"")
	var lip_stone := ViaductArt.slab_stone(SEED+191,WEATHERED,Vector3(SLAB_WIDE+0.1,SLAB_THICK,LIP_RUN),1)
	piece(lip_stone,Transform3D(Basis(Vector3.UP,yaw_of(c_deg)),at(slab_low,c_deg,LIP_RUN*0.5)),false)
	var lip_top := slab_low.y-0.5
	_kit_column(at(slab_low,c_deg,LIP_RUN*0.5),Vector2(1.6,1.6),lip_top-LIP_ROOT,lip_top,c_deg,SEED+192)
	var far_mid := at(far_near,c_deg,FAR_RIM.x*0.5)
	_isle_under("FarIsle",far_mid,c_deg,Vector2(FAR_RIM.y*0.5,FAR_RIM.x*0.5),FAR_DEPTH,SEED+200)
	for side: float in [-1.0,1.0]:
		var gate := at(far_near,c_deg,FAR_RIM.x-GATE_IN.x,side*(FAR_RIM.y*0.5-GATE_IN.y))
		piece(RuinKit.pier(SEED+210+int(side+1.0),0.55),Transform3D(Basis(Vector3.UP,yaw_of(c_deg+180.0)),gate))

## The gust arrows' perches (docs/design/roguelike/crossing-viaduct-
## perches.md), each a horn on a ruin-kit pillar with a standable top, and the
## zones they fire on: the left perch (launcher 0) and the far perch (1) at
## the ends of their routes, the deck's (2), the low ones (3..).
func _arrows(low: float) -> void:
	arrows = GustArrows.new()
	add_child(arrows)
	var left: Dictionary = routes.left
	_perch("ArcherPerch",left.top,left.deg,low,func(f: Vector3) -> bool: return on_pier_field(f) or on_route(f,"left"),{},0)
	var far: Dictionary = routes.far
	_perch("FarArcherPerch",far.top,far.deg,low,func(f: Vector3) -> bool: return on_far_piers(f) or on_route(f,"far"),{},1)
	var by_deck := deck_archer_at()-Vector3.UP*ARCHER_CLEAR
	_perch("DeckArcherPerch",by_deck,90.0,low,on_deck,{},2,0.0)
	for i in range(LOW_PERCHES.size()):
		var top := low_perch_at(i)
		var face := rad_to_deg(atan2(turn_mid.x-top.x,-(turn_mid.z-top.z)))
		var zone := func(f: Vector3) -> bool: return in_the_drop(f,top)
		_perch("LowPerch%d" % i,top,face+180.0,top.y-LOW_BLOCK,zone,{"airborne":true,"lead":LOW_LEAD,"cooldown":LOW_COOLDOWN,"range":LOW_RANGE},3+i,0.0)

## A perch: its column (`top` its top's middle, `bottom` its foot), facing
## heading `deg` (the way he comes in on its route), its horn (`perch_piece`)
## HORN_BACK further on, facing back; and its launcher.
func _perch(called: String, top: Vector3, deg: float, bottom: float, zone: Callable, opts: Dictionary, k: int, back := HORN_BACK) -> GustArrows.Launcher:
	var pillar := piece(Aqueduct.pillar(SEED+40+k,WEATHERED,top.y-bottom,Vector2(PERCH_TOP,PERCH_TOP)),Transform3D(Basis(Vector3.UP,yaw_of(deg)),Vector3(top.x,bottom,top.z)))
	pillar.name = called
	var horn := perch_piece(SEED+60+k,WEATHERED)
	horn.position = at(Vector3.ZERO,deg,back)
	horn.rotation.y = yaw_of(deg+180.0)
	var l := arrows.add_launcher(top,zone,horn,PERCH_TOP*0.5,opts)
	l.cap_rise = RuinKitHorn.TOP_HEIGHT
	l.name = called+"Launcher"
	return l

## THE PERCH'S HORN: the stone wind horn (studies/crossings/horn_perch.gd
## over scripts/ruin_kit_horn.gd). `_horn_stand_in` below is the greybox it
## replaced, the same nodes and methods.
func perch_piece(seed_value: int, weathered: float) -> Node3D:
	var horn := HornPerch.new()
	horn.setup(seed_value,weathered)
	return horn

func _horn_stand_in(_seed_value: int, _weathered: float) -> Node3D:
	var horn := HornStandIn.new()
	horn.setup(_paint)
	return horn

## The left perch's ball mouth (local; the stand-in's).
func archer_at() -> Vector3:
	return at(routes.left.top,routes.left.deg,HORN_BACK,0.0,ARCHER_CLEAR)

## The far side's perch's ball mouth (local; the stand-in's).
func far_archer_at() -> Vector3:
	return at(routes.far.top,routes.far.deg,HORN_BACK,0.0,ARCHER_CLEAR)

## The deck's perch's ball mouth (local).
func deck_archer_at() -> Vector3:
	var run := -lip.z
	return at(Vector3.ZERO,0.0,run*DECK_ARCHER_ALONG,DECK_ARCHER_ASIDE,run_rise*DECK_ARCHER_ALONG+DECK_ARCHER_UP)

## The `i`th low perch's top's middle (local).
func low_perch_at(i: int) -> Vector3:
	var p: Vector3 = LOW_PERCHES[i]
	return at(turn_mid,TURN_B,p.x,p.y,p.z)

## Whether `feet` (local) are in a low perch's band: under the route (the
## turn platform less ROUTE_CLEAR), within LOW_REACH of its top's height.
func in_the_drop(feet: Vector3, top: Vector3) -> bool:
	return feet.y < turn_mid.y-ROUTE_CLEAR and absf(feet.y-top.y) < LOW_REACH

## Whether `feet` (local) are on (or over) a perch's route ("left", "far"):
## off its departure's edge to its last stone, ROUTE_ZONE either side.
func on_route(feet: Vector3, key: String) -> bool:
	var r: Dictionary = routes[key]
	var from: Vector3 = r.from
	if feet.y <= from.y-ROUTE_UNDER or feet.y >= from.y+4.0: return false
	# The way out: the departure's edge, then stone to stone.
	var first: Vector3 = r.stones[0].at
	var out := Vector2(first.x-from.x,first.z-from.z).normalized()
	var pts: Array[Vector2] = [Vector2(from.x,from.z)+out*(float(r.edge)-0.5)]
	for st: Dictionary in r.stones: pts.append(Vector2(st.at.x,st.at.z))
	var p := Vector2(feet.x,feet.z)
	for i in range(pts.size()-1):
		if Geometry2D.get_closest_point_to_segment(p,pts[i],pts[i+1]).distance_to(p) < ROUTE_ZONE: return true
	return false

## Whether `feet` (local) are on the far half of the field: the piers and
## the safe stair beside them (on its side of the stair, the far perch has
## no stone between: the stair is the covered line only from the left).
func on_far_piers(feet: Vector3) -> bool:
	var w := way(TURN_B)
	var d := Vector2(feet.x-turn_mid.x,feet.z-turn_mid.z)
	var along := d.dot(w)
	var aside := d.dot(right_of(w))
	return along > plinth_near*FAR_ARCHER_FROM and along < plinth_near and aside > -(PIER_TOP.x*0.5+1.0) and aside < SAFE_ASIDE+ARCHER_ZONE.y and feet.y > turn_mid.y-1.0

## Whether `feet` (local) are on the run-up deck, start rim's edge to the
## fallen span's lip.
func on_deck(feet: Vector3) -> bool:
	return feet.z < -0.5 and feet.z > lip.z-0.5 and absf(feet.x) < DECK_ARCHER_ZONE and feet.y > -1.0

## Whether `feet` (local) are over the pier field or on the safe stair
## beside it (the turn platform's edge to the plinth, not down on the
## floor).
func on_pier_field(feet: Vector3) -> bool:
	var w := way(TURN_B)
	var d := Vector2(feet.x-turn_mid.x,feet.z-turn_mid.z)
	var along := d.dot(w)
	var aside := d.dot(right_of(w))
	return along > TURN_PAD.y*0.5-0.5 and along < plinth_near*ARCHER_TO and aside > -ARCHER_ZONE.x and aside < SAFE_ASIDE+ARCHER_ZONE.y and feet.y > turn_mid.y-1.0

func has_hazards() -> bool:
	return arrows != null

func set_hazards(on: bool) -> void:
	if arrows != null: arrows.set_on(on)

func step_hazards(delta: float, motor: Object, space: PhysicsDirectSpaceState3D) -> String:
	return arrows.step(delta,motor,space) if arrows != null else ""

func hazard_voices() -> Array:
	return arrows.voices() if arrows != null else []

## THE CHIMNEY SLOT: the ruin kit's tower shell (scripts/ruin_kit_tower.gd).
## `_stand_in` below is the greybox it replaced, the same footprint, shaft,
## doorway and rims.
func slot_piece(seed_value: int, weathered: float, height: float) -> Node3D:
	return RuinKitTower.tower_shell(seed_value,weathered,height)

## The stand-in, in the kit's conventions (foot on y 0 round the origin,
## front +Z): a hollow tower STAND_HALF round, the shaft STAND_SHAFT clear
## (kicked between its east and west walls), a doorway STAND_DOOR in the
## front wall at its foot. As the real piece: the east and west (kick)
## walls run only the shaft's depth (z within STAND_SHAFT.y), their heads
## the walkable rims at `height` (lip-capped, x STAND_SHAFT.x to
## STAND_HALF.x); the front and back walls run the whole width across
## their ends, STAND_LOW under the rims (the real one's, weathered, ragged
## and lower still).
func _stand_in(_seed_value: int, _weathered: float, height: float) -> Node3D:
	var root := Node3D.new()
	var built: Array[Node] = []
	var wall := STAND_HALF.x-STAND_SHAFT.x
	var end := STAND_HALF.y-STAND_SHAFT.y
	# The east and west walls, the shaft's depth.
	for sx: float in [-1.0,1.0]:
		built.append(box(Vector3(wall,height,STAND_SHAFT.y*2.0),Vector3(sx*(STAND_SHAFT.x+wall*0.5),height*0.5,0.0),0.0,"lip"))
	# The back wall, the whole width; the front wall either side of the
	# door and over it.
	var low := height-STAND_LOW
	built.append(box(Vector3(STAND_HALF.x*2.0,low,end),Vector3(0.0,low*0.5,-(STAND_SHAFT.y+end*0.5)),0.0,"wall"))
	var jamb := STAND_HALF.x-STAND_DOOR.x*0.5
	for sx: float in [-1.0,1.0]:
		built.append(box(Vector3(jamb,low,end),Vector3(sx*(STAND_DOOR.x*0.5+jamb*0.5),low*0.5,STAND_SHAFT.y+end*0.5),0.0,"wall"))
	built.append(box(Vector3(STAND_DOOR.x,low-STAND_DOOR.y,end),Vector3(0.0,(low+STAND_DOOR.y)*0.5,STAND_SHAFT.y+end*0.5),0.0,"wall"))
	for node in built:
		remove_child(node)
		root.add_child(node)
	return root
