extends "res://studies/crossings/crossing.gd"
## The Broken Viaduct (docs/design/roguelike/crossing-viaduct-round1.md):
## a ruined aqueduct curving up about 15 m from the start rim to the far
## rim, a pure-skill crossing on the pilot's own moves (scripts/
## pilot_motor.gd). Everything hangs over the soft floor (the turn below,
## the aqueduct's own valley floor DECK under its channel); fallen, he
## climbs back up the aqueduct head's treads beside the start rim.
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

const SEED := 4107
## Weathering of the stone (0 new to 1 ruin).
const WEATHERED := 0.35

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

## The gust arrows' perch: along the piers from the turn platform's
## middle (m), out to their left (m), up over the turn platform (m); the
## perch's stone stops under the ball's mouth by ARCHER_CLEAR (m). The
## zone it fires on: the piers' line from the turn platform's edge to the
## plinth, ARCHER_ZONE.x to their left and the safe stair's line plus
## ARCHER_ZONE.y to their right (m), from the turn platform's top up.
const ARCHER_ALONG := 26.0
const ARCHER_ASIDE := 18.0
const ARCHER_UP := 0.0
const ARCHER_CLEAR := 1.2
const ARCHER_ZONE := Vector2(3.0,2.0)
## The second perch, the far side's: along the piers (share of the way to
## the plinth), right of the safe stair (m), over the pier there (m). It
## fires on the piers from that share on, not on the stair (the stair stays
## the covered line), so the two perches take turns down the field.
const FAR_ARCHER_ALONG := 0.75
const FAR_ARCHER_ASIDE := 16.0
const FAR_ARCHER_UP := 4.0
const FAR_ARCHER_FROM := 0.45
## The deck's perch: along the run-up (share of the way to the lip), right
## of it (m), over the deck there (m: over the parapets), and how far
## either side of the deck's line it fires on (m).
const DECK_ARCHER_ALONG := 0.55
const DECK_ARCHER_ASIDE := 16.0
const DECK_ARCHER_UP := 2.5
const DECK_ARCHER_ZONE := 3.0

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
	numbers = {"run_rise":run_rise,"fall_gap":fall_gap,"plain_catch":miss,"chain3_land":make,"chain2_land":long_reach(chain2,FALL_DROP),
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
	return -deck

## The chimney slot's middle at its foot (local).
func slot_at() -> Vector3:
	return slot_foot

# --- Building ----------------------------------------------------------------------

func build(paint: Callable) -> void:
	super.build(paint)
	var low := floor_y()
	# The soft floor, the start rim, the aqueduct head beside it (the way
	# back up from the floor: its treads, a jump each).
	box(Vector3(260.0,2.0,260.0),Vector3(20.0,low-1.0,-50.0),0.0,"floor").name = "Floor"
	column(Vector3(0.0,0.0,RIM.y*0.5),RIM,low,0.0,0.0,"pad")
	var head := Aqueduct.head(SEED,WEATHERED,true,false)
	piece(head,Transform3D(Basis.IDENTITY,Vector3(-RIM.x*0.5,low,RIM.y*0.6)))
	_run_up(low)
	_piers(low)
	_safe_stair(low)
	var slot := slot_piece(SEED,WEATHERED,SLOT_HEIGHT)
	slot.name = "ChimneySlot"
	slot.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(SLOT_YAW_DEG)),slot_foot)
	add_child(slot)
	_launch(low)
	_arrows(low)

## 1. The spans (tilted, their piers grown down to the floor), a clean walk
## over their channel, the fallen span's stones on the floor, the far deck.
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
	# What fell, on the floor under the gap.
	for k in range(2):
		var p := Vector3(-1.5+3.0*k,low,lip.z-fall_gap*(0.3+0.4*k))
		piece(RuinKit.fallen_pier(SEED+20+k,0.6),Transform3D(Basis(Vector3.UP,0.7+1.9*k),p))
	# The turn platform.
	var pad_mid := at(turn_mid,TURN_B,0.0,(TURN_PAD_RIGHT-TURN_PAD.x*0.5)*0.5)
	column(pad_mid,Vector2(TURN_PAD.x*0.5+TURN_PAD_RIGHT,TURN_PAD.y),low,turn_mid.y,TURN_B,"grey")

## 2. The piers, lip-capped, from the floor; the slot's plinth.
func _piers(low: float) -> void:
	for top: Vector3 in pier_tops:
		column(top,PIER_TOP,low,top.y,TURN_B,"lip")
	column(slot_foot,Vector2(SLOT_PLINTH,SLOT_PLINTH)*2.0,low,slot_foot.y,TURN_B,"grey")

## The safe line: stair flights up beside the piers, a rest between each,
## the last arriving at the plinth's edge; the first's foot at or under the
## turn platform (stepped down onto from it).
func _safe_stair(low: float) -> void:
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
		column(mid,Vector2(RuinKit.STAIR_WIDTH+0.8,run),low,y,TURN_B,"wall")
		piece(RuinKit.stairs(SEED+30+i,0.6),Transform3D(Basis(Vector3.UP,yaw_of(TURN_B)),Vector3(mid.x,y,mid.z)))
		s += run
		if i < safe_flights-1:
			column(at(turn_mid,TURN_B,s+rest*0.5,SAFE_ASIDE),Vector2(RuinKit.STAIR_WIDTH+0.8,rest+0.02),low,y+climb,TURN_B,"grey")
			s += rest

## 4. The slab off the east head, its lip on a broken pier, the far rim.
func _launch(low: float) -> void:
	var c_deg := TURN_B+90.0
	var drop := SLAB_RUN*tan(deg_to_rad(SLAB_DEG))
	var slab_low := at(slab_top,c_deg,SLAB_RUN,0.0,-drop)
	slab(slab_top,slab_low,SLAB_WIDE,0.5,"lane")
	box(Vector3(SLAB_WIDE,0.5,LIP_RUN),at(slab_low,c_deg,LIP_RUN*0.5,0.0,-0.25),c_deg,"lane")
	column(at(slab_low,c_deg,LIP_RUN*0.5),Vector2(1.6,1.6),low,slab_low.y-0.5,c_deg,"wall")
	column(at(far_near,c_deg,FAR_RIM.x*0.5),Vector2(FAR_RIM.y,FAR_RIM.x),low,far_near.y,c_deg,"lip")

## The gust arrows' perch (a stone column off the field, its ball's mouth
## over it) and the zone it fires on.
func _arrows(low: float) -> void:
	var mouth := archer_at()
	column(mouth,Vector2(1.0,1.0),low,mouth.y-ARCHER_CLEAR,TURN_B,"dark").name = "ArcherPerch"
	arrows = GustArrows.new()
	add_child(arrows)
	arrows.add_launcher(mouth,on_pier_field)
	var far := far_archer_at()
	column(far,Vector2(1.0,1.0),low,far.y-ARCHER_CLEAR,TURN_B,"dark").name = "FarArcherPerch"
	arrows.add_launcher(far,on_far_piers)
	var by_deck := deck_archer_at()
	column(by_deck,Vector2(1.0,1.0),low,by_deck.y-ARCHER_CLEAR,0.0,"dark").name = "DeckArcherPerch"
	arrows.add_launcher(by_deck,on_deck)

## The perch's ball mouth (local).
func archer_at() -> Vector3:
	return at(turn_mid,TURN_B,ARCHER_ALONG,-ARCHER_ASIDE,ARCHER_UP)

## The far side's perch's ball mouth (local).
func far_archer_at() -> Vector3:
	var along := plinth_near*FAR_ARCHER_ALONG
	var i := clampi(int(PIERS*FAR_ARCHER_ALONG),0,PIERS-1)
	return at(turn_mid,TURN_B,along,SAFE_ASIDE+FAR_ARCHER_ASIDE,pier_tops[i].y-turn_mid.y+FAR_ARCHER_UP)

## The deck's perch's ball mouth (local).
func deck_archer_at() -> Vector3:
	var run := -lip.z
	return at(Vector3.ZERO,0.0,run*DECK_ARCHER_ALONG,DECK_ARCHER_ASIDE,run_rise*DECK_ARCHER_ALONG+DECK_ARCHER_UP)

## Whether `feet` (local) are on the far half of the piers themselves (not
## the stair beside them).
func on_far_piers(feet: Vector3) -> bool:
	var w := way(TURN_B)
	var d := Vector2(feet.x-turn_mid.x,feet.z-turn_mid.z)
	var along := d.dot(w)
	var aside := d.dot(right_of(w))
	return along > plinth_near*FAR_ARCHER_FROM and along < plinth_near and absf(aside) < PIER_TOP.x*0.5+1.0 and feet.y > turn_mid.y-1.0

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
	return along > TURN_PAD.y*0.5-0.5 and along < plinth_near and aside > -ARCHER_ZONE.x and aside < SAFE_ASIDE+ARCHER_ZONE.y and feet.y > turn_mid.y-1.0

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
