extends Node3D
## A grass snake by the water (docs/scenic/life.md). When a pond has banks and
## some life in it (fish, frogspawn or frogs), on a sunny morning a snake may
## slip out of the nearest cover, coil up on the bank to bask, hunt along the
## edge, sometimes swim across with its head held up, and leave into cover.
##
## Built and moved in code, not baked clips. The body is a faceted tube skinned
## to a chain of bones, and every ring follows the path the head has taken, so
## the serpentine comes from the head weaving and the body never slides
## sideways. The path is kept as points STEP apart, each read once from the
## live ground and water, so the body lies on banks and slopes and floats at the
## water's level; a new survey re-reads it. Where the path crosses the body
## (leaving the coil) the upper part rests on whatever of the lower part is
## still under it.
##
## The motion keeps the ambient Bigfoot's rules
## (tools/blender_bigfoot/ambient_clips.py), with nothing keyed pose to pose:
## every head and neck quantity is a goal that eases in and follows on a
## critically damped spring. It travels in bursts and holds, and settles its
## head and draws back before it sets off. At a stop it picks something to
## watch (you, if the camera comes close; a fish or frog; a bird; a slow drift
## over the water) and follows it smoothly with its head held still in space
## while the neck's S takes up the turn and the forebody slowly leans in. Come
## right in and it rears back and hisses, a warning and never a lunge. The rear
## settles into its curves after a stop, and breath, drift and tongue flicks
## never stop.
##
## Owned and advanced by LandLife on its clock. At most one snake at a time.

const Survey = preload("res://scripts/life_survey.gd")
const Variety = preload("res://scripts/seeded_variety.gd")

## Seconds between condition checks.
const CHECK := 2.0
## A pond of at least POND_AREA m² with POND_SHORE bank cells and some life in
## it for SNAKE_DELAY s; then SNAKE_CHANCE per check in the MORNING (celestial
## phase) with daylight above SUN and no rain. A visit is followed by at least
## SNAKE_COOLDOWN s without one.
const POND_AREA := 3.0
const POND_SHORE := 8
const SNAKE_DELAY := 40.0
const SNAKE_CHANCE := 0.1
const SNAKE_COOLDOWN := 420.0
const MORNING := Vector2(0.24,0.52)
const SUN := 0.5
## Seconds coiled on the bank, stops while hunting along the edge, and the
## chance it swims across before it leaves.
const BASK := Vector2(16.0,28.0)
const HUNT := Vector2i(3,5)
const SWIM_CHANCE := 0.5

## The body, in plate metres. A grass snake is about a metre long and 4 cm
## thick; this one is a big female, 1.2 m and 5.6 cm, so it reads from further
## off. At the default overview (43 m) it is still only a line a pixel or two
## wide; its motion and wake are what show there.
const LENGTH := 1.2
const RADIUS := 0.028
const HEAD := 0.068
## How far back from the snout the neck bends when the head comes up.
const NECK := 0.24
const STATIONS := 26
const NECK_SAMPLES := 8
## A ring's centre above its flat belly, as a share of its radius; the head's.
const BELLY := 0.736
const HEAD_BELLY := 0.69

## The path is kept as points STEP apart; TRAIL of them cover the body.
const STEP := 0.02
const TRAIL := 96
## Metres per second, and how quickly it gets there and stops.
const CRUISE := 0.24
const SWIM := 0.27
const ACCEL := 1.1
const DECEL := 0.07
## The head weaves WEAVE radians either side of its way, a wave every WAVE
## metres, and the body follows: this is the serpentine. Wider in the water.
const WEAVE := 0.5
const WAVE := 0.62
const SWIM_WEAVE := 0.7
const SWIM_WAVE := 0.5
## Radians per metre its way may turn toward a goal. Ground steeper than
## SLOPE_MAX is gone round.
const TURN := 3.0
const AVOID := 8.0
## A way ends this close to its goal.
const ARRIVE := 0.1
const SLOPE_MAX := 0.65
## Head heights over its resting place: carried while it travels, raised to
## look, over the water while it swims, resting while it basks, and the dip
## before it sets off.
const CARRY := 0.01
const LIFT := Vector2(0.045,0.07)
const SWIM_LIFT := 0.03
const REST := 0.003
const DIP := 0.0
## The draw-back before it sets off, and how long before a move it starts to
## settle its head.
const RECOIL := 0.012
const ANTICIPATION := 0.8
const FLICK := 0.44
## How it travels: a goal runs along its way, speeding up at GOAL_ACCEL and
## slowing at GOAL_DECEL, and the head follows it on a TRAVEL_HZ spring, so
## it eases off and eases in.
const GOAL_ACCEL := 0.8
const GOAL_DECEL := 0.6
const TRAVEL_HZ := 1.0
## Path points read ahead of the head, to see a climb coming.
const AHEAD := 8
## You. Within NOTICE metres it stops and watches you, for up to WATCH_MOST s
## at a stop, then once more at most every NOTICE_COOLDOWN s on the move.
## Within HISS_NEAR it rears back and hisses, at most every HISS_COOLDOWN s.
const NOTICE := 6.0
const WATCH_MOST := 20.0
const NOTICE_COOLDOWN := 25.0
const HISS_NEAR := 2.2
const HISS_COOLDOWN := 18.0
## The hiss: it draws its head back (to HISS_DRAW of the neck's reach) and up
## to HISS_LIFT over 1.1 s, opens its jaw JAW_OPEN radians and swells its
## forebody by SWELL, holds, and eases down again, all within HISS_TIME.
const HISS_TIME := 4.3
const HISS_LIFT := 0.085
const HISS_DRAW := 0.7
const JAW_OPEN := 0.3
const SWELL := 0.14
## The chance it hisses at whoever is watching before it leaves.
const PARTING_HISS := 0.3
## Taking a frog (docs/scenic/life.md, "Predation"), rare. TAKE_CHANCE of visits try,
## at a hunt stop, for a frog sitting on its bank within TAKE_REACH m, which keeps
## still from then on. It comes to STALK_FROM m, fixes on it, and creeps in at
## STALK_PACE of its cruise, head low (STALK_LIFT), to STRIKE_GAP short. It draws back
## into a tight S (STRIKE_DRAW of the neck's reach, head up to STRIKE_LIFT) and holds
## STRIKE_HOLD s, then strikes: the head shoots out over LUNGE s, jaw open to GAPE,
## the body surging up to SURGE m along its way, and eases back over STRIKE_AFTER s.
## ESCAPE of the time the frog leaps in ESCAPE_LEAD s before. Fed, it swallows
## (SWALLOW s, the jaws working and a bulge of BULGE, MEAL_SPREAD wide, running down
## to MEAL_AT of its length) and leaves at FED_PACE with no parting hiss.
const TAKE_CHANCE := 0.3
const TAKE_REACH := 3.0
const STALK_FROM := 0.75
const STALK_PACE := 0.3
const STALK_LIFT := 0.025
const STRIKE_GAP := 0.3
const STRIKE_DRAW := 0.62
const STRIKE_LIFT := 0.075
const STRIKE_HOLD := Vector2(1.8,2.8)
const STRIKE_AFTER := 1.4
const LUNGE := 0.13
const GAPE := 0.55
const SURGE := 0.16
const ESCAPE := 0.35
const ESCAPE_LEAD := 0.12
const SWALLOW := Vector2(5.5,7.5)
const BULGE := 0.3
const MEAL_SPREAD := 0.05
const MEAL_AT := 0.38
const FED_PACE := 0.6
## How far its head turns from the neck's way, in radians. Watching you from
## further round than TURN_TO for TURN_AFTER s, it turns its body to face you.
const LOOK_MAX := 2.0
const TURN_TO := 1.8
const TURN_AFTER := 1.5
## Seconds each wake from basking lasts.
const WAKE_TIME := 3.7
## The head and neck springs. Each goal first eases over SPRING_EASE seconds,
## then the value follows it at SPRING_HZ with SPRING_DAMP damping (1 is
## critical; the look is a touch under, so it settles with the smallest
## overshoot).
enum {S_LIFT,S_POSE,S_YAW,S_PITCH,S_LEAN,S_REACH,S_RECOIL,S_JAW,S_SWELL,S_COUNT}
const SPRING_HZ := [0.8,0.75,0.85,0.85,0.28,0.55,1.0,1.4,0.5]
const SPRING_DAMP := [1.0,1.0,0.85,0.9,1.0,1.0,1.0,1.0,1.0]
const SPRING_EASE := [0.12,0.12,0.1,0.1,0.3,0.15,0.1,0.06,0.15]
## Seconds between wake rings while it swims.
const WAKE := 0.42
## Rings shrink over this many metres as they pass into cover.
const GATE_SOFT := 0.1
## How much of it is out of cover when it first pauses to look.
const PEEK := 0.25
## Microseconds a frame may spend working out the next way while it holds.
const PLAN_BUDGET_USEC := 400
## Where its way crosses its own body it rides up over a bump this wide either
## side of the body under it, flat on top within OVER_TOP.
const OVER_REACH := RADIUS*2.8
const OVER_TOP := RADIUS*0.8
const NO_WATER := -1000.0
const WATERLINE := 0.03

const BACK := Color(0.19,0.24,0.11)
const FLANK := Color(0.25,0.31,0.15)
const LOW := Color(0.38,0.41,0.23)
const BAR := Color(0.09,0.09,0.07)
const UNDER := Color(0.74,0.72,0.58)
const COLLAR := Color(0.95,0.84,0.4)
const CRESCENT := Color(0.05,0.05,0.045)
const HEAD_TOP := Color(0.18,0.22,0.12)
const LIP := Color(0.84,0.82,0.7)
const EYE := Color(0.04,0.04,0.035)
const TONGUE := Color(0.24,0.03,0.05)
const MOUTH := Color(0.2,0.06,0.07)

const BREATH_KEYS := [[0.0,0.0],[0.38,1.0],[0.86,0.0],[1.0,0.0]]
const DEFLECT := [1,-1,2,-2,3,-3,4,-4,5,-5,6,-6,8,-8,10,-10]

var life: Node3D
## Every visit so far: {kind, at, p}.
var history: Array[Dictionary] = []
var visits := 0
var hisses := 0
## Frogs taken, for probes.
var takes := 0
## What it set out to do, and each way it worked out (length, distance left to
## its goal, microseconds, from, goal, end), for probes.
var journal: Array = []
## Microseconds the last and the worst advance took, for probes.
var last_usec := 0
var worst_usec := 0

var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _check := 0.0
var _next := 0.0
var _pond_since := {}
var _survey: RefCounted
var _resample := -1
var _water_seen: RefCounted
var _water_cells := {}

# The path: points at arcs k*STEP, in a ring buffer of TRAIL.
var _tx := PackedFloat32Array()
var _tz := PackedFloat32Array()
var _tg := PackedFloat32Array()
var _tw := PackedFloat32Array()
var _tr := PackedFloat32Array()
var _tp := PackedFloat32Array()
var _tq := PackedFloat32Array()
var _tf := PackedFloat32Array()
var _laid := -1
var _leg := PackedVector2Array()
var _leg_first := 0

# Stations: rings behind the snout at _arc metres.
var _arc := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _carry_w := PackedFloat32Array()
var _breath_w := PackedFloat32Array()
var _rear_w := PackedFloat32Array()
var _tail_w := PackedFloat32Array()
var _front_w := PackedFloat32Array()
var _neck_count := 0
var _pos := PackedVector3Array()
var _curve := PackedVector3Array()
var _curve_arc := PackedFloat32Array()
var _held := PackedVector3Array()
var _roll := PackedFloat32Array()
var _scale := PackedFloat32Array()

# The visit and its plan.
var _state := {}
var _plan: Array[Dictionary] = []
var _action := {}
var _stops := PackedInt32Array()

# The head and body. The spring values, velocities, eased goals and goals.
var _sx := PackedFloat32Array()
var _sv := PackedFloat32Array()
var _sf := PackedFloat32Array()
var _sg := PackedFloat32Array()
var _head_s := 0.0
var _head_v := 0.0
var _s_goal := 0.0
var _v_goal := 0.0
var _cruise := CRUISE
var _stop := 0
var _going := false
var _hold := {}
var _hold_age := 0.0
var _time := 0.0
var _lift := CARRY
var _pose_w := 0.0
var _tilt := 0.0
# What it watches, and you.
var _target := {}
var _retarget_in := 0.0
var _hiss_t := -1.0
var _hiss_ready := 0.0
var _hissed := false
var _notice_ready := 0.0
var _turn_ready := 0.0
var _camera := Vector3(0,1000,0)
## The wanderer's head, life-local, or INF (scripts/life_notice.gd).
var watcher := Vector3.INF
var _camera_d := INF
var _head_pos := Vector3.ZERO
var _rest_w := 0.0
var _flick := -10.0
var _next_flick := 0.0
var _head_fwd := Vector2(0,1)
var _gate := 0.0
var _gate_mode := 0
var _wake := 0.0
var _floating := false
## The neck, not just the head, is on the water: it is swimming.
var _swimming := false
var _level := NO_WATER
var _snout := Vector3.ZERO
## The strike: how far the head has shot out toward _strike_to (0-1), and how far
## past its spring the jaw is open. The meal: where the bulge is along the body and
## how much of it shows.
var _lunge := 0.0
var _strike_to := Vector3.ZERO
var _gape := 0.0
var _meal := 0.0
var _meal_w := 0.0

func setup(owner: Node3D) -> void:
	life = owner
	name = "Snakes"
	for buffer in [_tx,_tz,_tg,_tw,_tr,_tp,_tq,_tf]: buffer.resize(TRAIL)
	for spring in [_sx,_sv,_sf,_sg]: spring.resize(S_COUNT)
	_stations()
	_skeleton = Skeleton3D.new()
	_skeleton.name = "Snake"
	add_child(_skeleton)
	var skin := Skin.new()
	for k in range(STATIONS+3):
		_skeleton.add_bone("ring%d" % k if k < STATIONS else ["head","tongue","jaw"][k-STATIONS])
		skin.add_bind(k,Transform3D.IDENTITY)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = _build_mesh(life.material)
	_body.skin = skin
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# It roams the plate; one generous box keeps it from culling itself.
	_body.custom_aabb = AABB(Vector3(-16,-4,-16),Vector3(32,40,32))
	_skeleton.add_child(_body)
	visible = false

## A new world: the snake is gone at once and the pond clocks start again.
func clear() -> void:
	_let_prey_go()
	_state = {}
	_plan.clear()
	_pond_since.clear()
	visible = false

func advance(step: float) -> void:
	var began := Time.get_ticks_usec()
	_check += step
	if _check >= CHECK:
		_check = 0.0
		_consider()
	if _state.is_empty() or step <= 0.0: return
	_time += step
	if life.survey != _survey:
		_survey = life.survey
		_resample = _laid-TRAIL+1
		_watch_place()
	if _resample >= 0: _reread()
	_see_camera()
	if _going: _go_step(step)
	else: _hold_step(step)
	if _state.is_empty(): return
	_springs(step)
	_pose(step)
	last_usec = Time.get_ticks_usec()-began
	worst_usec = maxi(worst_usec,last_usec)

## Probes only: a snake now at the likeliest pond, skipping the delay, chance
## and hour but not the place. `options`: swim (bool), bask and hunts.
func force(options := {}) -> bool:
	var survey: RefCounted = life.survey
	if survey == null or not _state.is_empty(): return false
	var best := {}
	for record: Dictionary in survey.bodies:
		if record.area < Survey.MIN_BODY_AREA or record.shore.size() < 4: continue
		if best.is_empty() or record.area > best.area: best = record
	return not best.is_empty() and _arrive(best,options)

## What the snake is doing now, for probes: "" when there is none.
func showing() -> String:
	return str(_state.get("phase",""))

## The live bone poses, rings then head, tongue and jaw, for probes.
func poses() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for k in range(STATIONS+3): result.append(_skeleton.get_bone_pose(k))
	return result

## Where it is looking and at what, for probes: [kind, point].
func watching() -> Array:
	return [str(_target.get("kind","")) if _target.get("kind","") != "site" else str(_target.what),_target_point()]

func stations() -> PackedFloat32Array:
	return _arc

func radii() -> PackedFloat32Array:
	return _radius

func body_mesh() -> ArrayMesh:
	return _body.mesh

# --- When ---------------------------------------------------------------------

func _consider() -> void:
	var survey: RefCounted = life.survey
	if survey == null: return
	var clock: float = life.clock
	# Which ponds hold life. Body ids are per survey, so a pond is known by its
	# first cell, which a small edit leaves alone.
	var alive := {}
	for kind in ["fish","spawn","frog"]:
		for site: Dictionary in life.present(kind): alive[int(site.body)] = true
	var seen := {}
	for record: Dictionary in survey.bodies:
		if record.area < POND_AREA or record.shore.size() < POND_SHORE or not alive.has(record.id): continue
		var key: int = record.cells[0]
		seen[key] = record
		if not _pond_since.has(key): _pond_since[key] = clock
	for key in _pond_since.keys():
		if not seen.has(key): _pond_since.erase(key)
	if not _state.is_empty():
		if (_rain() > 0.4 or _frozen()) and not bool(_state.get("leaving",false)): _leave_now()
		return
	if clock < _next or life._daylight() < SUN or _rain() > 0.1 or _frozen(): return
	var phase := float(life.scene._celestial.phase)
	if phase < MORNING.x or phase > MORNING.y: return
	for key in _pond_since:
		if clock-float(_pond_since[key]) >= SNAKE_DELAY and life._rng.randf() < SNAKE_CHANCE:
			_arrive(seen[key])
			return

func _rain() -> float:
	return float(life.scene._precipitation.state.x)

## Rain or a drained pond sends it off early.
func _watch_place() -> void:
	if bool(_state.get("leaving",false)) or showing() in ["leave","slip"]: return
	var gone := _rain() > 0.4
	var record := _record()
	if record.is_empty(): gone = true
	if gone: _leave_now()

func _leave_now() -> void:
	_state.leaving = true
	_plan.clear()
	if not bool(_state.get("fed",false)): _let_prey_go()
	if _floating: _plan.append({"do":"shore"})
	_plan.append({"do":"leave"})
	# Whatever it was doing ends at the next chance: a burst stops short, a
	# hold rouses now.
	_stops = PackedInt32Array()
	if _going:
		_stop_soon()
		_action = {"do":"go"}
	elif not _hold.is_empty():
		_hold.time = minf(float(_hold.time),_hold_age+ANTICIPATION+0.05)

# --- Arrival and the plan -----------------------------------------------------------

func _arrive(record: Dictionary, options := {}) -> bool:
	var survey: RefCounted = life.survey
	_survey = survey
	visits += 1
	_rng.seed = Variety.mix([int(life.salt),"snake".hash(),visits,int(record.cells[0])])
	var center: Vector2 = record.center
	_state = {"phase":"emerge","center":center,"around":1.0 if _rng.randf() < 0.5 else -1.0,
		"hunts":int(options.get("hunts",_rng.randi_range(HUNT.x,HUNT.y))),
		"swim":bool(options.get("swim",_rng.randf() < SWIM_CHANCE)),
		"bask":float(options.get("bask",_rng.randf_range(BASK.x,BASK.y))),
		"take":bool(options.get("take",_rng.randf() < TAKE_CHANCE))}
	var bask := _bask_spot(record)
	var cover := _cover_near(bask,center)
	var way := bask-cover
	way = way.normalized() if way.length() > 0.1 else Vector2.from_angle(_rng.randf()*TAU)
	# The body lies in the cover with its head and neck out of it: its way is
	# laid back from the head into the cover, turning along the plate's edge
	# if it has to, and then read head-last.
	_laid = -1
	_head_s = 0.0
	_head_fwd = way
	var lay := _leg_begin(cover+way*PEEK,(-way).angle(),Vector2.ZERO,false,WEAVE,WAVE,0.0,LENGTH+PEEK+0.02,true)
	_leg_run(lay,1 << 30)
	var hidden: PackedVector2Array = lay.points
	hidden.reverse()
	_leg = hidden
	_leg_first = 0
	_head_s = float(hidden.size()-1)*STEP
	_lay_to(hidden.size()-1)
	_gate = _head_s-PEEK
	_gate_mode = 1
	_head_v = 0.0
	_s_goal = _head_s
	_v_goal = 0.0
	for i in range(S_COUNT):
		_sx[i] = 0.0
		_sv[i] = 0.0
	_sx[S_LIFT] = CARRY
	_sx[S_YAW] = way.angle()
	_sx[S_REACH] = 1.0
	_sf = _sx.duplicate()
	_sg = _sx.duplicate()
	_lift = CARRY
	_pose_w = 0.0
	_target = {}
	_hiss_t = -1.0
	_lunge = 0.0
	_gape = 0.0
	_meal_w = 0.0
	_hiss_ready = 0.0
	_notice_ready = 0.0
	_turn_ready = 0.0
	_head_pos = Vector3(cover.x,_ground_est(cover),cover.y)
	_rest_w = 0.0
	_flick = -10.0
	_time = 0.0
	_next_flick = 2.0
	_hold = {}
	_going = false
	_resample = -1
	_plan = [{"do":"hold","kind":"peek","time":_rng.randf_range(1.6,2.4)},{"do":"go","to":bask,"bursts":true,"phase":"emerge"},{"do":"hold","kind":"look","time":_rng.randf_range(1.0,1.6)},{"do":"coil","phase":"coil"},{"do":"hold","kind":"bask","time":float(_state.bask),"phase":"bask"},{"do":"hunt"}]
	visible = true
	var p := Vector3(bask.x,_ground_est(bask),bask.y)
	history.append({"kind":"snake","at":life.clock,"p":p})
	life.moment.emit("snake",life.to_global(p))
	_next_action()
	_pose(0.0)
	return true

func _gone() -> void:
	_let_prey_go()
	_state = {}
	_plan.clear()
	visible = false
	_next = life.clock+SNAKE_COOLDOWN

func _next_action() -> void:
	while true:
		if _state.is_empty(): return
		if _plan.is_empty():
			_gone()
			return
		_action = _plan.pop_front()
		if journal.size() > 400: journal = journal.slice(200)
		journal.append([snappedf(life.clock,0.1),str(_action.do),str(_action.get("kind",""))])
		if _start(_action): return

## Begin an action; false when there is nothing to do and the next should start.
func _start(action: Dictionary) -> bool:
	if action.has("phase"): _state.phase = action.phase
	match str(action.do):
		"hold":
			_begin_hold(float(action.time),str(action.kind))
			return true
		"go":
			var gen: Dictionary = action.get("gen",{})
			if gen.is_empty() or gen.from != _head_xz(): gen = _go_leg(action)
			_leg_run(gen,1 << 30)
			var begun := _begin_leg(gen.points,bool(action.get("bursts",false)) and not gen.water and not gen.get("wet_start",false),(SWIM if gen.water else CRUISE)*float(action.get("pace",1.0)),bool(action.get("pause",false)))
			# A stalk stops short; the rest of its way is there for the strike.
			if begun and action.has("short"): _stop = maxi(_leg_first+1,_stop-int(float(action.short)/STEP))
			return begun
		"coil":
			var record := _record()
			var to_water: Vector2 = (record.center if not record.is_empty() else _state.center)-_head_xz()
			var fwd := Vector2.from_angle(_heading())
			# Coil to the side away from the water.
			var side := -1.0 if fwd.cross(to_water) > 0.0 else 1.0
			# Either way round, then a little tighter, before it gives up and
			# basks as it lies.
			for attempt in [[side,1.0],[-side,1.0],[side,0.85],[-side,0.85]]:
				var leg := _make_coil(_head_xz(),_heading(),float(attempt[0]),float(attempt[1]))
				if leg.size() > 2: return _begin_leg(leg,false,CRUISE*0.6)
			journal.append([snappedf(life.clock,0.1),"coil","no room"])
			return false
		"slip":
			# It never vanishes on open water: first to the bank, and try again.
			if _wet(_head_xz()) and int(_state.get("ashore",0)) < 2:
				_state.ashore = int(_state.get("ashore",0))+1
				var bank := _nearest_shore(_record())
				_plan.push_front({"do":"leave"})
				if bank != Vector2.INF: _plan.push_front({"do":"go","to":bank,"water":true,"phase":"swim"})
				return false
			_gate = _head_s+0.03
			_gate_mode = -1
			var gen := _leg_begin(_head_xz(),_heading(),Vector2.ZERO,false,WEAVE,WAVE,0.0,LENGTH+0.3,true)
			_leg_run(gen,1 << 30)
			return _begin_leg(gen.points,false,CRUISE)
		_:
			_expand(action)
	return false

## Planning steps turn into the moves and holds they decide on, at the front
## of the plan. They only read where the head is, so they can run during the
## hold before them.
func _expand(action: Dictionary) -> void:
	match str(action.do):
		"hunt": _plan_hunt()
		"swim": _plan_swim()
		"leave":
			var cover := _cover_near(_head_xz(),_state.center)
			_plan.push_front({"do":"slip","phase":"slip"})
			_plan.push_front({"do":"hold","kind":"look","time":_rng.randf_range(0.9,1.5)})
			_plan.push_front({"do":"go","to":cover,"bursts":true,"phase":"leave"})
			# Now and then a parting warning at whoever is watching; not when fed.
			if not _floating and not bool(_state.get("fed",false)) and _rng.randf() < PARTING_HISS: _plan.push_front({"do":"hold","kind":"hiss","time":1.0})
		"shore":
			var target := _nearest_shore(_record())
			if target != Vector2.INF: _plan.push_front({"do":"go","to":target,"water":true,"phase":"swim"})

const PLANNING := ["hunt","swim","leave","shore"]

## While it holds before its next action, decide that action and work out its
## way a slice at a time, so no frame pays for a whole leg.
func _prefetch() -> void:
	while not _plan.is_empty() and str(_plan[0].do) in PLANNING:
		var action: Dictionary = _plan.pop_front()
		journal.append([snappedf(life.clock,0.1),str(action.do),"planned ahead"])
		_expand(action)
	if _plan.is_empty() or str(_plan[0].do) != "go": return
	var next: Dictionary = _plan[0]
	if not next.has("gen"): next.gen = _go_leg(next)
	_leg_run(next.gen,PLAN_BUDGET_USEC)

func _go_leg(action: Dictionary) -> Dictionary:
	var water: bool = action.get("water",false)
	var to: Vector2 = action.to
	var gen := _leg_begin(_head_xz(),_heading(),to,water,SWIM_WEAVE if water else WEAVE,SWIM_WAVE if water else WAVE,float(action.get("turn",TURN)),minf(_head_xz().distance_to(to)*2.5+1.0,12.0))
	# Setting off on land from the water's edge it may pass through the
	# shallows it starts in.
	gen.wet_start = not water and not action.get("dry",false) and _wet(_head_xz())
	return gen

## The next stop along the edge, a look toward the water, and the rest of the hunt.
func _plan_hunt() -> void:
	var record := _record()
	if not record.is_empty() and bool(_state.get("take",false)) and _plan_take(): return
	if record.is_empty() or int(_state.hunts) <= 0:
		_plan.push_front({"do":"swim"} if bool(_state.swim) else {"do":"leave"})
		return
	_state.hunts = int(_state.hunts)-1
	var here := _head_xz()
	var center: Vector2 = record.center
	var radius := maxf(here.distance_to(center),0.6)
	var want := (here-center).angle()+float(_state.around)*_rng.randf_range(0.55,1.1)/radius
	var fwd := Vector2.from_angle(_heading())
	var best := Vector2.INF
	var best_score := INF
	# Round the pond its own way, and rather ahead than behind it; failing
	# that, a little further and more to the side.
	for bounds: Array in [[0.6,1.8,-0.3],[0.5,2.6,-0.6]]:
		for cell in record.shore:
			var p := _dry_bank(Survey.center(cell),center)
			if p == Vector2.INF: continue
			var d := p.distance_to(here)
			if d < float(bounds[0]) or d > float(bounds[1]) or fwd.dot((p-here)/d) < float(bounds[2]): continue
			var score := absf(wrapf((p-center).angle()-want,-PI,PI))+0.5*(1.0-fwd.dot((p-here)/d))+_rng.randf()*0.15
			if score < best_score:
				best_score = score
				best = p
		if best != Vector2.INF: break
	if best == Vector2.INF:
		_state.hunts = 0
		_plan_hunt()
		return
	_plan.push_front({"do":"hunt"})
	_plan.push_front({"do":"hold","kind":"hunt","time":_rng.randf_range(1.8,3.4)})
	_plan.push_front({"do":"go","to":best,"phase":"hunt"})

## A frog sitting on its bank within reach over open ground: it keeps still, and
## the snake comes near, fixes on it, creeps in and strikes, then hunts on if it
## missed. False when there is none to try for.
func _plan_take() -> bool:
	var here := _head_xz()
	var best := {}
	var nearest := TAKE_REACH
	for site: Dictionary in life.present("frog"):
		if str(site.get("mode","")) != "sit": continue
		var home: Vector3 = site.home
		var at := Vector2(home.x,home.z)
		var d := at.distance_to(here)
		if d < nearest and d > STRIKE_GAP+0.1 and _open_line(here,at):
			nearest = d
			best = site
	if best.is_empty(): return false
	_state.take = false
	_state.prey = best
	best.frozen = true
	var home: Vector3 = best.home
	var at := Vector2(home.x,home.z)
	journal.append([snappedf(life.clock,0.1),"stalk",snappedf(nearest,0.01)])
	_plan.push_front({"do":"hunt"})
	_plan.push_front({"do":"hold","kind":"strike","time":_rng.randf_range(STRIKE_HOLD.x,STRIKE_HOLD.y)+LUNGE+STRIKE_AFTER,"phase":"strike","escape":_rng.randf() < ESCAPE})
	_plan.push_front({"do":"go","to":at,"short":STRIKE_GAP,"pace":STALK_PACE,"phase":"stalk"})
	if nearest > STALK_FROM+0.3:
		_plan.push_front({"do":"hold","kind":"look","time":_rng.randf_range(1.4,2.2)})
		_plan.push_front({"do":"go","to":at+(here-at).normalized()*STALK_FROM,"phase":"hunt"})
	return true

## The frog it was after goes back to its own life.
func _let_prey_go() -> void:
	var prey: Dictionary = _state.get("prey",{})
	prey.erase("frozen")
	_state.erase("prey")

## A crossing over open water to the far side, with one floating pause. It
## goes to the nearest bank cell (gentle by the survey's rule), looks at the
## water, slides in and swims to the far water's edge, then hauls out and
## pauses before it goes.
func _plan_swim() -> void:
	var record := _record()
	_plan.push_front({"do":"leave"})
	if record.is_empty(): return
	var bank := _nearest_shore(record)
	if bank == Vector2.INF: return
	var center: Vector2 = record.center
	var across := 1.2*sqrt(float(record.area)/PI)
	var best := Vector2.INF
	var best_score := -INF
	for cell in record.shore:
		var p := Survey.center(cell)
		# Only the far side, roughly opposite across the middle.
		var opposite := -(bank-center).normalized().dot((p-center).normalized())
		if opposite < 0.5: continue
		var d := p.distance_to(bank)
		if d < 2.0 or d > 9.0: continue
		# One run of open water from near this bank to near the far one,
		# reaching a good way over the pond.
		var first := -1.0
		var last := -1.0
		var broken := false
		var t := 0.0
		while t <= d:
			if _wet(bank.lerp(p,t/d)):
				if first < 0.0: first = t
				elif last < t-0.4: broken = true
				last = t
			t += 0.3
		if broken or first < 0.0 or first > 1.0 or last < d-1.0 or last-first < maxf(1.5,across): continue
		var score := opposite*2.0-absf(d-3.6)*0.3+_rng.randf()*0.6
		if score > best_score:
			best_score = score
			best = bank.lerp(p,clampf((last+0.05)/d,0.0,1.0))
	if best == Vector2.INF: return
	_plan.push_front({"do":"hold","kind":"look","time":_rng.randf_range(1.4,2.4)})
	_plan.push_front({"do":"go","to":best,"water":true,"pause":true,"phase":"swim"})
	if bank.distance_to(_head_xz()) > 0.15:
		_plan.push_front({"do":"hold","kind":"hunt","time":_rng.randf_range(1.0,1.6)})
		_plan.push_front({"do":"go","to":bank,"phase":"hunt"})

func _begin_leg(leg: PackedVector2Array, bursts: bool, cruise: float, pause := false) -> bool:
	if leg.size() < 3: return false
	var first := int(roundf(_head_s/STEP))
	_head_s = float(first)*STEP
	_leg = leg
	_leg_first = first
	_laid = mini(_laid,first)
	var last := first+leg.size()-1
	_stops = PackedInt32Array()
	if bursts:
		var at := first
		while true:
			at += int(_rng.randf_range(0.35,0.9)/STEP)
			if at >= last-int(0.2/STEP): break
			_stops.append(at)
	if pause:
		var middle := first+int(float(leg.size())*_rng.randf_range(0.42,0.6))
		if middle > first+10 and middle < last-10: _stops.append(middle)
	_stops.append(last)
	# Fed, it goes slowly.
	_cruise = cruise*(FED_PACE if bool(_state.get("fed",false)) else 1.0)
	_begin_go()
	return true

func _begin_go() -> void:
	_stop = _stops[0]
	_stops.remove_at(0)
	_going = true
	_s_goal = _head_s
	_v_goal = 0.0
	_hold = {}

## How much of a climb over its own body lies in the next AHEAD path points,
## 0 to 1.
func _climb_ahead() -> float:
	var head := _head_s-_sx[S_RECOIL]
	var first := ceili(_head_s/STEP)
	var most := 0.0
	for k in range(first,mini(first+AHEAD,_laid)+1):
		var i := k%TRAIL
		if _tp[i] >= 0.0: most = maxf(most,_raise(_tp[i],head)*_tf[i])
	return clampf(most/(2.0*BELLY*RADIUS),0.0,1.0)

## Bring the goal to a stop as soon as it can ease off, on a path point.
func _stop_soon() -> void:
	var room := _v_goal*_v_goal/(2.0*GOAL_DECEL)+0.01
	_stop = mini(_stop,ceili((_s_goal+room)/STEP)+1)

## The burst reached its stop: hold before the next, or finish the action.
func _arrived() -> void:
	_going = false
	if not _stops.is_empty():
		_begin_hold(_rng.randf_range(0.9,2.2),"swim" if _floating else "look")
		return
	if str(_action.get("do","")) == "slip":
		_gone()
		return
	_next_action()
	# An action that ends without a hold of its own settles into one.
	if not _state.is_empty() and not _going and _hold.is_empty(): _begin_hold(1.2,"look")

# --- Holds ------------------------------------------------------------------------

func _begin_hold(time: float, kind: String) -> void:
	_going = false
	_hold_age = 0.0
	var floating := _floating
	var up := _rng.randf_range(LIFT.x,LIFT.y)
	if kind == "peek": up = 0.045
	if floating: up = SWIM_LIFT+0.012
	var wakes := []
	if kind == "bask":
		# Now and then it wakes: the head comes up, it watches something and
		# tastes the air, and it settles again; and it rouses before it moves.
		var room := time-ANTICIPATION-1.6-1.0
		var count := 2 if room >= 11.0 else (1 if room >= 5.0 else 0)
		for n in range(count):
			var slot := room/count
			wakes.append(1.0+slot*n+(slot-WAKE_TIME)*_rng.randf_range(0.3,0.7))
	_hold = {"time":time,"kind":kind,"floating":floating,"up":up,"wakes":wakes,"watched":0.0,"escape":bool(_action.get("escape",false))}
	_retarget_in = 0.0
	if floating: life.ripple(Vector3(_snout.x,_level,_snout.z),0.22)
	if kind == "hiss": _start_hiss()

func _hold_step(step: float) -> void:
	if _hold.is_empty():
		_begin_hold(1.2,"look")
	if str(_hold.kind) in ["strike","swallow"]:
		_prey_step(step)
		return
	_hold_age += step
	if _stops.is_empty(): _prefetch()
	var age := _hold_age
	var floating: bool = _hold.floating
	var closing := age >= float(_hold.time)-ANTICIPATION and _hiss_t < 0.0
	# You, close by: it watches you while you stay, and if you come right in
	# it rears up and hisses.
	if _camera_d < NOTICE and not closing and float(_hold.watched) < WATCH_MOST:
		_hold.watched = float(_hold.watched)+step
		_hold.time = maxf(float(_hold.time),age+ANTICIPATION+1.2)
	# Coming right in stops even its wind-up to move. Not while it swims;
	# lying on the bank with its head over the water it may.
	if _camera_d < HISS_NEAR and _hiss_t < 0.0 and _time >= _hiss_ready and not _swimming:
		_start_hiss()
		closing = false
	# You have stayed round behind it: it turns its body to face you.
	if str(_target.get("kind","")) == "camera" and absf(_off(_camera)) > TURN_TO and _hiss_t < 0.0 and not closing and not _swimming and _time >= _turn_ready:
		_hold.behind = float(_hold.get("behind",0.0))+step
		if float(_hold.behind) > TURN_AFTER:
			_turn_ready = _time+6.0
			var goal := _turn_goal()
			if goal != Vector2.INF:
				_stops = PackedInt32Array()
				_plan.push_front({"do":"go","to":goal,"phase":showing(),"turn":TURN*1.6,"dry":true})
			# Nowhere dry to turn round onto: rather than strain round at you,
			# it moves on along its way, which brings it round.
			_hold.time = age+ANTICIPATION
			closing = true
	else:
		_hold.behind = 0.0
	var awake := true
	if _hold.kind == "bask":
		awake = _camera_d < NOTICE or _hiss_t >= 0.0 or age >= float(_hold.time)-ANTICIPATION-1.6
		for wake: float in _hold.wakes:
			if age >= wake and age < wake+WAKE_TIME: awake = true
	_retarget_in -= step
	if str(_target.get("kind","")) != "camera" and _hiss_t < 0.0 and absf(_off(_target_point())) > LOOK_MAX+0.2: _retarget_in = 0.0
	if _retarget_in <= 0.0:
		_retarget()
		_retarget_in = _rng.randf_range(1.2,2.2)
	var up: float = _hold.up
	_sg[S_POSE] = 1.0 if awake or floating else 0.0
	_sg[S_LIFT] = up if awake else REST
	_sg[S_RECOIL] = 0.0
	_sg[S_JAW] = 0.0
	_sg[S_SWELL] = 0.0
	_aim(awake or floating)
	if _hiss_t >= 0.0: _hiss_step(step)
	# Before it sets off: the head settles to the ground and turns home, the
	# body draws back a little, and the rear straightens, gathering.
	if closing:
		_sg[S_POSE] = 1.0 if floating else 0.0
		_sg[S_LIFT] = SWIM_LIFT if floating else DIP
		_aim_yaw(_head_fwd.angle())
		_sg[S_PITCH] = 0.0
		_sg[S_LEAN] = 0.0
		_sg[S_REACH] = 1.0
		_sg[S_RECOIL] = RECOIL*(0.5 if floating else 1.0)
	if floating: _sg[S_LIFT] = maxf(_sg[S_LIFT],SWIM_LIFT*0.8)
	var time: float = _hold.time
	_rest_w = _settle(clampf(age/0.9,0.0,1.0),0.35)*(1.0-_smooth((age-(time-ANTICIPATION))/ANTICIPATION))
	# It tastes the air while it watches: more often when what it watches
	# moves. Never mid-hiss.
	if awake and _hiss_t < 0.0 and not closing and _time >= _next_flick:
		_flick = _time
		var lively := str(_target.get("kind","")) in ["camera","site"]
		_next_flick = _time+(_rng.randf_range(1.1,2.2) if lively else _rng.randf_range(2.0,3.8))
	if age >= time:
		_hold = {}
		if _going: return
		if not _stops.is_empty() and str(_action.get("do","")) in ["go","coil","slip"]:
			_begin_go()
		else:
			_next_action()
			if not _state.is_empty() and not _going and _hold.is_empty(): _begin_hold(1.2,"look")

## The strike and the swallow: holds of their own, which nothing else interrupts.
func _prey_step(step: float) -> void:
	_hold_age += step
	var age := _hold_age
	var time: float = _hold.time
	_sg[S_POSE] = 1.0
	_sg[S_RECOIL] = 0.0
	_sg[S_SWELL] = 0.0
	_sg[S_JAW] = 0.0
	_rest_w = _settle(clampf(age/0.9,0.0,1.0),0.35)*(1.0-_smooth((age-(time-ANTICIPATION))/ANTICIPATION))
	if _hold.kind == "strike": _strike_step(age)
	else: _swallow_step(age)
	if _hold_age >= float(_hold.time):
		_hold = {}
		_lunge = 0.0
		_gape = 0.0
		_next_action()
		if not _state.is_empty() and not _going and _hold.is_empty(): _begin_hold(1.2,"look")

## Fixed on the frog it draws back into a tight S and holds, still; then the head
## shoots out, the jaw wide, and the body surges after it. It takes the frog, or
## the frog is gone and it strikes the bank, and eases back.
func _strike_step(age: float) -> void:
	var prey: Dictionary = _state.get("prey",{})
	var alive := not prey.is_empty() and _alive({"site":prey}) and not prey.has("taken")
	if not _hold.has("at"): _hold.at = float(_hold.time)-LUNGE-STRIKE_AFTER
	var t := age-float(_hold.at)
	if t < 0.0:
		# Driven off, or the frog gone before it struck: it lets it be.
		if bool(_state.get("leaving",false)) or not alive:
			_hold.time = age
			_let_prey_go()
			return
		_target = {"kind":"site","what":"frog","site":prey}
		_aim(true)
		var draw := _smoother(age/1.1)
		_sg[S_LIFT] = lerpf(STALK_LIFT,STRIKE_LIFT,draw)
		_sg[S_REACH] = lerpf(1.0,STRIKE_DRAW,draw)
		# It tastes the air once or twice, then nothing moves.
		if t < -1.0 and _time >= _next_flick:
			_flick = _time
			_next_flick = _time+_rng.randf_range(0.9,1.5)
		# The frog may see it coming.
		if bool(_hold.escape) and t >= -ESCAPE_LEAD and not _hold.has("fled"):
			_hold.fled = true
			prey.erase("frozen")
			life._hop(prey,prey.landing,"in")
		return
	if not _hold.has("to"):
		# At where the frog sat.
		var frog: Vector3 = prey.get("home",_head_pos)
		var reach := Vector2(frog.x,frog.z).distance_to(_head_xz())
		# Too far to reach: it only watches.
		if reach > STRIKE_GAP+0.25:
			_hold.time = age
			_let_prey_go()
			return
		_hold.to = frog+Vector3(0,0.02,0)
		_hold.from_s = _head_s
		_hold.surge = clampf(reach-0.12,0.0,SURGE)
		_strike_to = _hold.to
	var u := t/LUNGE
	var fed := bool(_state.get("fed",false))
	_lunge = _smoother(u) if t < LUNGE+0.18 else 1.0-_settle((t-LUNGE-0.18)/0.9,0.08)
	_gape = GAPE*_smoother(u/0.7)*(1.0-_smoother((t-LUNGE-(0.3 if fed else 0.0))/0.25))
	_head_s = float(_hold.from_s)+float(_hold.surge)*_smoother(u)
	_lay_to(ceili(_head_s/STEP)+1)
	_sg[S_LIFT] = LIFT.x
	_sg[S_REACH] = 1.0
	_sg[S_PITCH] = -0.2
	if u >= 1.0 and not _hold.has("struck"):
		_hold.struck = true
		var p: Vector3 = prey.get("p",Vector3.INF)
		if alive and not _hold.has("fled") and Vector2(p.x,p.z).distance_to(Vector2(_snout.x,_snout.z)) < 0.2:
			life.take(prey,_snout)
			takes += 1
			_state.fed = true
			_state.hunts = 0
			_state.swim = false
			_plan.clear()
			_plan.append({"do":"hold","kind":"swallow","time":_rng.randf_range(SWALLOW.x,SWALLOW.y)})
			_plan.append({"do":"leave"})
			life.moment.emit("snake_take",life.to_global(_snout))
			journal.append([snappedf(life.clock,0.1),"take",true])
		else:
			_let_prey_go()
			journal.append([snappedf(life.clock,0.1),"take",false])
	if _hold.has("struck") and _stops.is_empty(): _prefetch()

## It swallows: the jaws walk the frog in with slow gapes, the head low and still,
## and the bulge runs down the body, where it stays as it goes.
func _swallow_step(age: float) -> void:
	var time: float = _hold.time
	_aim_yaw(_head_fwd.angle())
	_sg[S_PITCH] = -0.12
	_sg[S_LEAN] = 0.0
	_sg[S_REACH] = 0.92
	_sg[S_LIFT] = LIFT.x*0.6
	var w := fposmod(age,1.3)/1.3
	_gape = 0.16*pow(sin(PI*clampf(w/0.55,0.0,1.0)),2.0)*(1.0-_smooth((age-time*0.5)/1.0))
	_meal = lerpf(HEAD+0.04,LENGTH*MEAL_AT,_smooth(age/time))
	_meal_w = _smooth(age/0.6)
	if _stops.is_empty(): _prefetch()

## Turn the head, lean and reach toward what it watches. Small, continuous
## adjustments; never a snap.
func _aim(awake: bool) -> void:
	if not awake:
		_aim_yaw(_head_fwd.angle())
		_sg[S_PITCH] = 0.0
		_sg[S_LEAN] = 0.0
		_sg[S_REACH] = 1.0
		return
	var p := _target_point()
	var d := Vector2(p.x-_head_pos.x,p.z-_head_pos.z)
	var drift := _drift(_time,7.0)
	var rel := _off(p)
	# Something behind it stays on the side it is already looking round.
	if absf(rel) > LOOK_MAX and signf(rel) != signf(_look_rel()) and absf(_look_rel()) > 0.3: rel = signf(_look_rel())*LOOK_MAX
	rel = clampf(rel,-LOOK_MAX,LOOK_MAX)+0.03*drift.x
	_aim_rel(rel)
	_sg[S_PITCH] = clampf(atan2(p.y-_head_pos.y,maxf(d.length(),0.05)),-0.45,0.6)*0.8+0.02*drift.y
	# The forebody leans slowly toward what interests it.
	var interest := 1.0 if str(_target.get("kind","")) in ["camera","site"] else 0.4
	_sg[S_LEAN] = rel*0.45*interest
	_sg[S_REACH] = 1.0+0.05*interest

## A point's bearing from the neck's way, -PI..PI.
func _off(p: Vector3) -> float:
	var d := Vector2(p.x-_head_pos.x,p.z-_head_pos.z)
	return wrapf(d.angle()-_head_fwd.angle(),-PI,PI) if d.length() > 0.03 else 0.0

## Where the head looks now, from the neck's way.
func _look_rel() -> float:
	return wrapf(_sx[S_YAW]-_head_fwd.angle(),-PI,PI)

## Aim the look `rel` round from the neck's way. Goals are set relative to
## where it looks now, so a turn never goes the long way round behind it.
func _aim_rel(rel: float) -> void:
	_sg[S_YAW] = _sx[S_YAW]+(rel-_look_rel())

func _aim_yaw(yaw: float) -> void:
	_aim_rel(wrapf(yaw-_head_fwd.angle(),-PI,PI))

## Dry, open ground a little way toward you, to turn round onto; or none.
func _turn_goal() -> Vector2:
	var here := _head_xz()
	var toward := Vector2(_camera.x-_head_pos.x,_camera.z-_head_pos.z).normalized()
	# Straight at you first; failing that, round to one side along the bank,
	# which still leaves you within its look.
	for reach: float in [0.9,0.7,0.5,0.35]:
		for off: float in [0.0,0.3,-0.3,0.6,-0.6,0.9,-0.9,1.2,-1.2]:
			var q := here+toward.rotated(off)*reach
			if _passable(q,false) and _passable(here.lerp(q,0.5),false): return q
	return Vector2.INF

## Something to watch: you if the camera is near; else a frog or fish in the
## pond, a firefly at dusk or a passing bird; else a slow drift over the water.
func _retarget() -> void:
	var prey: Dictionary = _state.get("prey",{})
	if not prey.is_empty() and _alive({"site":prey}):
		_target = {"kind":"site","what":"frog","site":prey}
		return
	if _camera_d < NOTICE:
		_target = {"kind":"camera"}
		return
	if str(_target.get("kind","")) == "site" and _alive(_target) and _target_point().distance_to(_head_pos) < 4.5 and absf(_off(_target_point())) < LOOK_MAX and _rng.randf() < 0.7: return
	var options := []
	var weights := []
	var total := 0.0
	for kind: String in ["frog","fish","firefly","bird"]:
		if kind == "firefly" and life._daylight() > 0.5: continue
		var reach: float = {"frog":3.0,"fish":4.5,"firefly":3.0,"bird":16.0}[kind]
		for site: Dictionary in life.present(kind):
			var at := _site_point(kind,site)
			var d := at.distance_to(_head_pos)
			if d > reach or absf(_off(at)) > LOOK_MAX: continue
			var weight: float = {"frog":3.0,"fish":2.0,"firefly":1.0,"bird":0.6}[kind]/(1.0+d)
			options.append({"kind":"site","what":kind,"site":site})
			weights.append(weight)
			total += weight
	if not options.is_empty():
		var roll := _rng.randf()*total
		for i in range(options.size()):
			roll -= float(weights[i])
			if roll <= 0.0 or i == options.size()-1:
				_target = options[i]
				return
	if str(_target.get("kind","")) == "drift" and absf(_off(_target_point())) < LOOK_MAX: return
	_target = {"kind":"drift","at":_drift_anchor(),"phase":_rng.randf()*TAU}

func _alive(target: Dictionary) -> bool:
	var site: Dictionary = target.site
	return bool(site.get("here",false)) and not bool(site.get("leaving",false))

func _site_point(kind: String, site: Dictionary) -> Vector3:
	if kind == "bird":
		var bird: Dictionary = life._birds.birds[int(site.slot)]
		return Vector3(float(bird.x),float(bird.y),float(bird.z))
	return site.p

func _target_point() -> Vector3:
	match str(_target.get("kind","")):
		"camera": return _camera
		"site":
			if _alive(_target): return _site_point(str(_target.what),_target.site)
		"drift":
			var at: Vector3 = _target.at
			var phase: float = _target.phase
			return at+Vector3(cos(_time*0.23+phase)*0.5,0.0,sin(_time*0.17+phase*1.3)*0.4)
	return _head_pos+Vector3(_head_fwd.x,0.0,_head_fwd.y)

## A point over the water toward the pond, or a little ahead on the ground.
func _drift_anchor() -> Vector3:
	var here := Vector2(_head_pos.x,_head_pos.z)
	var record := _record()
	if not record.is_empty():
		var toward: Vector2 = (record.center as Vector2)-here
		if toward.length() < sqrt(float(record.area)/PI)+4.0 and absf(wrapf(toward.angle()-_head_fwd.angle(),-PI,PI)) < LOOK_MAX:
			var q := here+toward.normalized()*minf(1.4,toward.length())
			var level := _water_est(q)
			return Vector3(q.x,level if level > NO_WATER else _ground_est(q)+0.05,q.y)
	var q := here+_head_fwd*1.5
	return Vector3(q.x,_ground_est(q)+0.05,q.y)

func _see_camera() -> void:
	var camera: Camera3D = life.scene.get("camera")
	if camera == null or not camera.is_inside_tree():
		_camera_d = INF
	else:
		_camera = life.to_local(camera.global_position)
		_camera_d = _camera.distance_to(_head_pos)
	# The wanderer is watched and hissed at as you are, when nearer.
	if watcher != Vector3.INF and watcher.distance_to(_head_pos) < _camera_d:
		_camera = watcher
		_camera_d = watcher.distance_to(_head_pos)

## A warning: it rears back and up with a slow wind-up, opens its jaw and
## swells, holds, and eases down again.
func _start_hiss() -> void:
	_hiss_t = 0.0
	_hissed = false
	_hiss_ready = _time+HISS_COOLDOWN
	hisses += 1
	if _camera_d < 15.0: _target = {"kind":"camera"}
	_retarget_in = HISS_TIME
	_hold.time = maxf(float(_hold.time),_hold_age+HISS_TIME+0.8+ANTICIPATION)
	journal.append([snappedf(life.clock,0.1),"hiss",snappedf(_camera_d,0.01)])

func _hiss_step(step: float) -> void:
	_hiss_t += step
	var t := _hiss_t
	var drawn := _smoother(t/1.1)*(1.0-_smoother((t-3.0)/1.1))
	_sg[S_POSE] = 1.0
	_sg[S_LIFT] = lerpf(_sg[S_LIFT],HISS_LIFT,drawn)
	_sg[S_REACH] = lerpf(_sg[S_REACH],HISS_DRAW,drawn)
	_sg[S_LEAN] = lerpf(_sg[S_LEAN],0.0,drawn)
	_sg[S_JAW] = JAW_OPEN*_smoother((t-1.0)/0.35)*(1.0-_smoother((t-2.75)/0.35))
	_sg[S_SWELL] = _smoother((t-0.9)/0.6)*(1.0-_smoother((t-2.9)/0.9))
	if t >= 1.1 and not _hissed:
		_hissed = true
		life.moment.emit("snake_hiss",life.to_global(_head_pos))
	if t >= HISS_TIME: _hiss_t = -1.0

## Every spring one step: the goal eases, and the value follows it.
func _springs(step: float) -> void:
	if step <= 0.0: return
	var count := ceili(step/0.02)
	var h := step/count
	for i in range(S_COUNT):
		var w := TAU*float(SPRING_HZ[i])
		var z := float(SPRING_DAMP[i])
		_sf[i] += (_sg[i]-_sf[i])*(1.0-exp(-step/float(SPRING_EASE[i])))
		var x := _sx[i]
		var v := _sv[i]
		for _n in range(count):
			v += ((_sf[i]-x)*w*w-v*2.0*z*w)*h
			x += v*h
		_sx[i] = x
		_sv[i] = v
	_lift = _sx[S_LIFT]
	_pose_w = clampf(_sx[S_POSE],0.0,1.0)

# --- Going ------------------------------------------------------------------------

func _go_step(step: float) -> void:
	var stop_s := float(_stop)*STEP
	var left := stop_s-_s_goal
	# It reads its way a little ahead, and slows to climb over its own body.
	_lay_to(mini(ceili(_head_s/STEP-1e-6)+AHEAD,_stop))
	var cruise := _cruise*(1.0-0.6*_climb_ahead())
	_v_goal = move_toward(_v_goal,minf(cruise,sqrt(2.0*GOAL_DECEL*maxf(left,0.0))),GOAL_ACCEL*step)
	_s_goal = minf(_s_goal+_v_goal*step,stop_s)
	var count := ceili(step/0.02)
	var h := step/count
	var w := TAU*TRAVEL_HZ
	for _i in range(count):
		_head_v += ((_s_goal-_head_s)*w*w-_head_v*2.0*w)*h
		_head_s += _head_v*h
	if _head_s > stop_s:
		_head_s = stop_s
		_head_v = 0.0
	var float_w := 1.0 if _floating else 0.0
	var drift := _drift(_time,5.0)
	_sg[S_POSE] = float_w
	_sg[S_LIFT] = SWIM_LIFT if _floating else CARRY
	_aim_yaw(_head_fwd.angle()+0.05*drift.y*float_w)
	_sg[S_PITCH] = -0.05*float_w
	_sg[S_LEAN] = 0.0
	_sg[S_REACH] = 1.0
	_sg[S_RECOIL] = 0.0
	_sg[S_JAW] = 0.0
	_sg[S_SWELL] = 0.0
	var phase := showing()
	# Stalking, its head is up a little and fixed on the frog.
	var prey: Dictionary = _state.get("prey",{})
	if phase == "stalk" and not prey.is_empty() and _alive({"site":prey}):
		_target = {"kind":"site","what":"frog","site":prey}
		_sg[S_POSE] = 1.0
		_sg[S_LIFT] = STALK_LIFT
		_aim(true)
	_rest_w = move_toward(_rest_w,0.0,step*4.0)
	# You, close: it eases to a stop to watch, and keeps the rest of its way.
	if not _swimming and phase not in ["slip","stalk"] and ((_camera_d < NOTICE and _time >= _notice_ready) or (_camera_d < HISS_NEAR and _time >= _hiss_ready)):
		_notice_ready = _time+NOTICE_COOLDOWN
		var before := _stop
		_stop_soon()
		if _stop < before: _stops.insert(0,before)
	# It tastes the air as it goes.
	if not _floating and _time >= _next_flick:
		_flick = _time
		_next_flick = _time+_rng.randf_range(2.0,4.5)
	if _floating:
		_wake -= step
		if _wake <= 0.0:
			_wake = WAKE
			life.ripple(Vector3(_snout.x,_level,_snout.z),0.36)
	else:
		_wake = 0.0
	if _s_goal >= stop_s-1e-6 and stop_s-_head_s < 0.0006 and absf(_head_v) < 0.004:
		_head_s = stop_s
		_head_v = 0.0
		_arrived()

# --- The path -----------------------------------------------------------------------

## A way from `from` toward `goal`, points STEP apart along the ground: the
## heading turns toward the goal at `turn` radians per metre and weaves about
## it, looks ahead to steer round water (unless `water`), steep ground and the
## plate's edge, and is smoothed so no corner is sharper than the weave. `free`
## ignores the goal and the ground and keeps straight on. Worked out a slice at
## a time by _leg_run.
func _leg_begin(from: Vector2, heading: float, goal: Vector2, water: bool, weave: float, wave: float, turn: float, most: float, free := false) -> Dictionary:
	return {"from":from,"straight":from.distance_to(goal),"closest":from.distance_to(goal),"closest_at":0,"points":PackedVector2Array([from]),"p":from,"base":heading,"travelled":0.0,"height":_surface_est(from),"goal":goal,"water":water,"weave":weave,"wave":wave,"turn":turn,"most":most,"free":free,"done":false,"usec":0}

## Extend a way for up to `budget` microseconds; true once it is finished.
func _leg_run(gen: Dictionary, budget: int) -> bool:
	if gen.done: return true
	var began := Time.get_ticks_usec()
	var points: PackedVector2Array = gen.points
	var p: Vector2 = gen.p
	var base: float = gen.base
	var travelled: float = gen.travelled
	var height: float = gen.height
	var goal: Vector2 = gen.goal
	var weave: float = gen.weave
	var wave: float = gen.wave
	var turn: float = gen.turn
	var free: bool = gen.free
	var finished := false
	var count := 0
	while true:
		if travelled >= float(gen.most):
			finished = true
			break
		count += 1
		if count%8 == 0 and Time.get_ticks_usec()-began > budget: break
		var near := 1.0
		if not free:
			var to_goal := goal-p
			var distance := to_goal.length()
			if distance < ARRIVE:
				finished = true
				break
			# Close to a goal ahead of it, it steers harder and stops weaving, so
			# it arrives instead of circling; a goal behind it is swung round to
			# wide, never in a hairpin.
			var off := wrapf(to_goal.angle()-base,-PI,PI)
			var steer := turn*clampf(0.45/distance,1.0,2.0) if absf(off) < 1.2 else turn
			near = smoothstep(0.08,0.5,distance)
			# A way that has wandered twice as far as the goal first lay stops
			# weaving and makes straight for it.
			if travelled > 2.0*float(gen.straight)+0.5:
				steer = turn*2.0
				near = 0.0
			base += clampf(off,-steer*STEP,steer*STEP)
			# Look ahead every third step and steer gently round what is coming,
			# never looking past the goal, which may be at the water's edge.
			var reach := minf(0.24,distance*0.8)
			if count%3 == 0 and not _clear(p,base,gen,reach):
				for k: int in DEFLECT:
					var b := base+float(k)*0.2
					if _clear(p,b,gen,reach):
						base += clampf(b-base,-AVOID*STEP*3.0,AVOID*STEP*3.0)
						break
		var a := base+weave*near*smoothstep(0.0,0.3,travelled)*sin(TAU*travelled/wave)
		var next := _stride(p,a,height)
		if not _open(next,gen):
			var found := false
			for k: int in DEFLECT:
				var b := a+float(k)*0.3
				var q := _stride(p,b,height)
				if _open(q,gen):
					base += b-a
					next = q
					found = true
					break
			if not found:
				finished = true
				break
		points.append(next)
		p = next
		height = _surface_est(p)
		travelled += STEP
		# A way that has come no closer for half a metre, plus the room to
		# turn round, ends where it was closest.
		if not free:
			var left := p.distance_to(goal)
			if left < float(gen.closest)-0.01:
				gen.closest = left
				gen.closest_at = points.size()-1
			elif points.size()-1-int(gen.closest_at) > int((0.5+PI/maxf(turn,0.5))/STEP):
				points.resize(int(gen.closest_at)+1)
				p = points[points.size()-1]
				finished = true
				break
	if finished: points = _smoothed(points)
	gen.points = points
	gen.p = p
	gen.base = base
	gen.travelled = travelled
	gen.height = height
	gen.done = finished
	gen.usec = int(gen.usec)+Time.get_ticks_usec()-began
	if finished: journal.append([snappedf(life.clock,0.1),"leg",snappedf(travelled,0.01),snappedf(p.distance_to(goal),0.01) if not free else -1.0,gen.usec,[snappedf(gen.from.x,0.01),snappedf(gen.from.y,0.01)],[snappedf(goal.x,0.01),snappedf(goal.y,0.01)],[snappedf(p.x,0.01),snappedf(p.y,0.01)],snappedf(float(gen.closest),0.01)])
	return finished

## One step from `p` along angle `a`, shortened on a slope so that it is STEP
## long over the ground (or the water).
func _stride(p: Vector2, a: float, height: float) -> Vector2:
	var way := Vector2.from_angle(a)
	var rise := _surface_est(p+way*STEP)-height
	return p+way*(STEP/sqrt(1.0+rise*rise/(STEP*STEP)))

func _surface_est(p: Vector2) -> float:
	return maxf(_ground_est(p),_water_est(p))

## Open ground (or water) half way to `reach` ahead and at it.
func _clear(p: Vector2, a: float, gen: Dictionary, reach := 0.24) -> bool:
	var way := Vector2.from_angle(a)
	return _open(p+way*reach*0.5,gen) and _open(p+way*reach,gen)

## Whether a way may pass `q`. A way on land may turn through the shallows in
## its first half metre, and one that starts in the water may use it for its
## first 1.5 m. A swim keeps to the water once it is more than a body's length
## from where it set off and where it is going.
func _open(q: Vector2, gen: Dictionary) -> bool:
	if gen.free: return _inside(q)
	if not gen.water:
		if _passable(q,false): return true
		# Setting off it may turn through the shallows at the water's edge;
		# started in the water, it may use it for a while.
		var start := q.distance_to(gen.from)
		if start < 0.5 and _at_waterline(q): return true
		return bool(gen.get("wet_start",false)) and start < 1.5 and _passable(q,true)
	if not _passable(q,true): return false
	return _wet(q) or q.distance_to(gen.from) < 1.2 or q.distance_to(gen.goal) < 1.2

## Two passes of a five-point average, the first points held so the new way
## leaves the old one smoothly.
static func _smoothed(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 8: return points
	var out := points.duplicate()
	for _pass in range(2):
		var copy := out.duplicate()
		for i in range(3,out.size()-2):
			out[i] = (copy[i-2]+copy[i-1]+copy[i]+copy[i+1]+copy[i+2])/5.0
	return out

## A spiral in to a loose coil, `side` +1 turning one way and -1 the other.
## Empty when the bank has no room for it.
func _make_coil(from: Vector2, heading: float, side: float, size := 1.0) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var p := from
	var a := heading
	var count := int((LENGTH+0.12)*size/STEP)
	var height := _surface_est(p)
	for j in range(count):
		var r := lerpf(0.2,0.08,float(j)/count)*size
		a += side*STEP/r
		p = _stride(p,a,height)
		height = _surface_est(p)
		if not _passable(p,false): return PackedVector2Array()
		points.append(p)
	return points

func _inside(p: Vector2) -> bool:
	return absf(p.x) < 13.4 and absf(p.y) < 13.4

func _passable(p: Vector2, water: bool) -> bool:
	if not _inside(p): return false
	var survey: RefCounted = life.survey
	var cell := Survey.cell_at(p)
	if cell < 0 or is_nan(survey.height[cell]): return false
	var wet := _wet(p)
	if water and (wet or _at_waterline(p)): return true
	return not wet and survey.slope[cell] <= SLOPE_MAX

## Within a hand's height of a pond's level: a bank it can slide into the
## water from, or haul out over, however steep.
func _at_waterline(p: Vector2) -> bool:
	var level := _water_est(p)
	return level > NO_WATER and _ground_est(p) < level+0.12

func _wet(p: Vector2) -> bool:
	return _water_est(p) > _ground_est(p)+0.01

## The ground from the survey's cell heights, bilinear.
func _ground_est(p: Vector2) -> float:
	var survey: RefCounted = life.survey
	var g := (p+Vector2(Survey.HALF,Survey.HALF))/Survey.STEP-Vector2(0.5,0.5)
	var x := clampi(floori(g.x),0,Survey.SIDE-2)
	var z := clampi(floori(g.y),0,Survey.SIDE-2)
	var fx := clampf(g.x-x,0.0,1.0)
	var fz := clampf(g.y-z,0.0,1.0)
	var h: PackedFloat32Array = survey.height
	var a := h[z*Survey.SIDE+x]
	var b := h[z*Survey.SIDE+x+1]
	var c := h[(z+1)*Survey.SIDE+x]
	var d := h[(z+1)*Survey.SIDE+x+1]
	if is_nan(a) or is_nan(b) or is_nan(c) or is_nan(d):
		for v in [a,b,c,d]:
			if not is_nan(v): return v
		return 0.0
	return lerpf(lerpf(a,b,fx),lerpf(c,d,fx),fz)

## Uphill per metre along x and z, from the same cells.
func _gradient(p: Vector2) -> Vector2:
	var survey: RefCounted = life.survey
	var g := (p+Vector2(Survey.HALF,Survey.HALF))/Survey.STEP-Vector2(0.5,0.5)
	var x := clampi(floori(g.x),0,Survey.SIDE-2)
	var z := clampi(floori(g.y),0,Survey.SIDE-2)
	var fx := clampf(g.x-x,0.0,1.0)
	var fz := clampf(g.y-z,0.0,1.0)
	var h: PackedFloat32Array = survey.height
	var a := h[z*Survey.SIDE+x]
	var b := h[z*Survey.SIDE+x+1]
	var c := h[(z+1)*Survey.SIDE+x]
	var d := h[(z+1)*Survey.SIDE+x+1]
	if is_nan(a) or is_nan(b) or is_nan(c) or is_nan(d): return Vector2.ZERO
	return Vector2(lerpf(b-a,d-c,fz),lerpf(c-a,d-b,fx))/Survey.STEP

## The level of any still water in or beside the cell at `p`. Past its shore
## the ground stands above it, so the body lies on the ground there.
func _water_est(p: Vector2) -> float:
	var survey: RefCounted = life.survey
	var cell := Survey.cell_at(p)
	if cell < 0: return NO_WATER
	if _water_seen != survey:
		_water_seen = survey
		_water_cells.clear()
	var known: Variant = _water_cells.get(cell)
	if known != null: return known
	var level := _water_look(survey,cell)
	_water_cells[cell] = level
	return level

func _water_look(survey: RefCounted, cell: int) -> float:
	var x := cell%Survey.SIDE
	var z := cell/Survey.SIDE
	for dz in [0,-1,1]:
		for dx in [0,-1,1]:
			var nx: int = x+dx
			var nz: int = z+dz
			if nx < 0 or nz < 0 or nx >= Survey.SIDE or nz >= Survey.SIDE: continue
			var index := nz*Survey.SIDE+nx
			if survey.body[index] >= 0: return survey.level[index]
	return NO_WATER

## Lay path points up to trail index `last` from the current leg.
func _lay_to(last: int) -> void:
	while _laid < last:
		var k := _laid+1
		var j := k-_leg_first
		if j < 0 or j >= _leg.size(): return
		_put(k,_leg[j],false)
		_laid = k

## Read the ground, water and roll under path point `k`, and whether it lies
## over an older part of the body.
func _put(k: int, p: Vector2, keep_partner: bool) -> void:
	var i := k%TRAIL
	_tx[i] = p.x
	_tz[i] = p.y
	var ground: Variant = life.data.ground_height(p)
	_tg[i] = float(ground) if ground != null else _ground_est(p)
	_tw[i] = _water_est(p)
	var along := Vector2.from_angle(_heading_at(k,p))
	var gradient := _gradient(p)
	# Uphill toward the ring's +x side (along × up), and how much further off
	# the ground a tilted ring's centre stands.
	_tr[i] = gradient.dot(Vector2(along.y,-along.x))
	_tq[i] = sqrt(1.0+gradient.length_squared())
	if keep_partner: return
	# The nearest older part of the body still lying within reach: the path
	# rides up over it on a smooth bump, full height over its middle.
	var partner := -1.0
	var nearest := OVER_REACH*OVER_REACH
	var tail := _head_s-_sx[S_RECOIL]-LENGTH
	var newest := k-int((NECK+0.08)/STEP)
	var oldest := maxi(maxi(_laid-TRAIL+2,0),ceili(tail/STEP))
	for q in range(newest,oldest-1,-1):
		var iq := q%TRAIL
		var dx := _tx[iq]-p.x
		var dz := _tz[iq]-p.y
		var d2 := dx*dx+dz*dz
		if d2 < nearest:
			nearest = d2
			partner = float(q)*STEP
	_tp[i] = partner
	_tf[i] = smoothstep(OVER_REACH,OVER_TOP,sqrt(nearest)) if partner >= 0.0 else 0.0

func _heading_at(k: int, p: Vector2) -> float:
	if k > 0 and _laid >= k-1:
		var j := (k-1)%TRAIL
		var d := p-Vector2(_tx[j],_tz[j])
		if d.length_squared() > 1e-8: return d.angle()
	return _head_fwd.angle()

## Re-read the path's ground and water a slice at a time after a survey.
func _reread() -> void:
	var first := maxi(_resample,maxi(_laid-TRAIL+1,0))
	var last := mini(first+12,_laid+1)
	for k in range(first,last):
		var i := k%TRAIL
		_put(k,Vector2(_tx[i],_tz[i]),true)
	_resample = last if last <= _laid else -1

func _head_xz() -> Vector2:
	var i := clampi(int(roundf(_head_s/STEP)),0,_laid)%TRAIL
	return Vector2(_tx[i],_tz[i])

func _heading() -> float:
	var k := clampi(int(roundf(_head_s/STEP)),1,_laid)
	var a := k%TRAIL
	var b := (k-1)%TRAIL
	var d := Vector2(_tx[a]-_tx[b],_tz[a]-_tz[b])
	return d.angle() if d.length_squared() > 1e-8 else _head_fwd.angle()

## The pond it came to, in the current survey: the body under its centre, or
## failing that the nearest one within 2 m. Empty once it is gone.
func _record() -> Dictionary:
	var survey: RefCounted = life.survey
	if survey == null or _state.is_empty(): return {}
	var center: Vector2 = _state.center
	var cell := Survey.cell_at(center)
	var id: int = survey.body[cell] if cell >= 0 else -1
	if id >= 0 and id < survey.bodies.size(): return survey.bodies[id]
	var best := {}
	for record: Dictionary in survey.bodies:
		if record.area < Survey.MIN_BODY_AREA: continue
		var d: float = (record.center as Vector2).distance_to(center)
		if d < 2.0 and (best.is_empty() or d < (best.center as Vector2).distance_to(center)): best = record
	return best

## A flat spot up the bank, 0.5-1.5 m from the water, with room to coil;
## failing that, a bank cell.
func _bask_spot(record: Dictionary) -> Vector2:
	var survey: RefCounted = life.survey
	var center: Vector2 = record.center
	var reach := sqrt(float(record.area)/PI)+2.0
	var home := Survey.cell_at(center)
	var span := ceili(reach/Survey.STEP)
	var candidates: Array[int] = []
	for dz in range(-span,span+1):
		for dx in range(-span,span+1):
			var x := home%Survey.SIDE+dx
			var z := home/Survey.SIDE+dz
			if home < 0 or x < 0 or z < 0 or x >= Survey.SIDE or z >= Survey.SIDE: continue
			var index := z*Survey.SIDE+x
			var dry: float = survey.water_distance[index]
			if dry < 0.5 or dry > 1.5 or survey.slope[index] > 0.35 or survey.depth(index) > 0.01: continue
			candidates.append(index)
	for i in range(candidates.size()-1,0,-1):
		var j := _rng.randi_range(0,i)
		var swap := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	for cell in candidates.slice(0,20):
		var p := Survey.center(cell)
		var room := 0
		for n in range(8):
			if _passable(p+Vector2.from_angle(TAU*n/8.0)*0.42,false): room += 1
		if room == 8: return p
	var shore: PackedInt32Array = record.shore
	return Survey.center(shore[_rng.randi_range(0,shore.size()-1)])

## Somewhere 1.5-5 m from `p` to hide: under trees or shrubs, or in thick
## grass, and failing those open ground away from the water.
func _cover_near(p: Vector2, center: Vector2) -> Vector2:
	var survey: RefCounted = life.survey
	var grass: PackedFloat32Array = life.data.grass
	var home := Survey.cell_at(p)
	var best := Vector2.INF
	var best_score := -INF
	if home < 0: return p+(p-center).normalized()*3.0
	for dz in range(-10,11):
		for dx in range(-10,11):
			var x := home%Survey.SIDE+dx
			var z := home/Survey.SIDE+dz
			if x < 0 or z < 0 or x >= Survey.SIDE or z >= Survey.SIDE: continue
			var q := Survey.center(z*Survey.SIDE+x)
			var d := q.distance_to(p)
			if d < 1.5 or d > 5.0: continue
			var g := Vector2i(clampi(int(q.x+Survey.HALF),0,Survey.COARSE-1),clampi(int(q.y+Survey.HALF),0,Survey.COARSE-1))
			var cover: float = minf(survey.tree_grid[g.y*Survey.COARSE+g.x]+survey.shrub_grid[g.y*Survey.COARSE+g.x],2.0)
			var index := z*Survey.SIDE+x
			if index < grass.size(): cover += maxf(grass[index]-0.4,0.0)
			var away := (q-center).normalized().dot((p-center).normalized())
			var score := cover*2.0-absf(d-2.8)*0.5+away*0.4+_rng.randf()*0.3
			if score > best_score and _passable(q,false) and _open_line(p,q):
				best_score = score
				best = q
	return best if best != Vector2.INF else p+(p-center).normalized()*2.5

## The nearest open ground to `p` on the side away from the pond's middle,
## within half a metre: a bank cell's centre can sit at the water's edge.
func _dry_bank(p: Vector2, center: Vector2) -> Vector2:
	var away := (p-center).normalized()
	for n in range(11):
		var q := p+away*0.05*n
		if _passable(q,false): return q
	return Vector2.INF

## Open ground along the straight line from `p` to `q`, past the first 0.6 m
## (it may start at the water's edge).
func _open_line(p: Vector2, q: Vector2) -> bool:
	var d := p.distance_to(q)
	var t := 0.6
	while t < d:
		if not _passable(p.lerp(q,t/d),false): return false
		t += 0.3
	return true

func _nearest_shore(record: Dictionary) -> Vector2:
	if record.is_empty(): return Vector2.INF
	var here := _head_xz()
	var best := Vector2.INF
	for cell in record.shore:
		var p := Survey.center(cell)
		if best == Vector2.INF or p.distance_squared_to(here) < best.distance_squared_to(here): best = p
	return best

# --- The body ----------------------------------------------------------------------

## Station arcs behind the snout: the collar and crescent close behind the
## head, then evenly to the tail.
func _stations() -> void:
	_arc.resize(STATIONS)
	_radius.resize(STATIONS)
	_carry_w.resize(STATIONS)
	_breath_w.resize(STATIONS)
	_rear_w.resize(STATIONS)
	_tail_w.resize(STATIONS)
	_front_w.resize(STATIONS)
	_roll.resize(STATIONS)
	_scale.resize(STATIONS)
	_pos.resize(STATIONS)
	_curve.resize(NECK_SAMPLES+1)
	_curve_arc.resize(NECK_SAMPLES+1)
	_held.resize(STATIONS)
	_arc[0] = HEAD+0.016
	_arc[1] = _arc[0]+0.022
	for k in range(2,STATIONS): _arc[k] = lerpf(_arc[1],LENGTH,float(k-1)/(STATIONS-2))
	_neck_count = 0
	for k in range(STATIONS):
		var u := _body_u(_arc[k])
		_radius[k] = RADIUS*_profile(u)
		_carry_w[k] = 1.0-smoothstep(HEAD,0.16,_arc[k])
		_breath_w[k] = sin(PI*clampf((u-0.1)/0.55,0.0,1.0))
		_rear_w[k] = smoothstep(0.5,0.78,u)
		_tail_w[k] = pow(smoothstep(0.82,1.0,u),2.0)
		_front_w[k] = 1.0-smoothstep(0.15,0.4,u)
		if _arc[k] < NECK: _neck_count = k+1

func _body_u(a: float) -> float:
	return clampf((a-(HEAD+0.016))/(LENGTH-(HEAD+0.016)),0.0,1.0)

## Radius share along the body, 0 at the neck and 1 at the tail's tip.
static func _profile(u: float) -> float:
	if u < 0.1: return lerpf(0.74,0.95,u/0.1)
	if u < 0.22: return lerpf(0.95,1.0,(u-0.1)/0.12)
	if u < 0.58: return 1.0
	if u < 0.74: return lerpf(1.0,0.78,(u-0.58)/0.16)
	return 0.78*pow(maxf(1.0-(u-0.74)/0.26,0.0),1.15)

## How high the body part `head - partner` behind the snout stands, for a path
## point laid over it; 0 once it has gone from under.
func _raise(partner: float, head: float) -> float:
	if partner < 0.0: return 0.0
	var a := head-partner
	if a < 0.0 or a > LENGTH: return 0.0
	return 2.0*BELLY*RADIUS*(0.85 if a < HEAD else _profile(_body_u(a)))

## The path at arc `s`: x, the centre's height for a ring of radius `r`, z.
func _sample(s: float, r: float, head: float) -> Vector3:
	var f := s/STEP
	var i := floori(f)
	var low := maxi(_laid-TRAIL+1,0)
	if i < low:
		i = low
		f = float(low)
	if i >= _laid:
		i = maxi(_laid-1,0)
		f = float(_laid)
	f -= i
	var a := i%TRAIL
	var b := (i+1)%TRAIL
	var y := _smax(lerpf(_tg[a],_tg[b],f)+BELLY*r*lerpf(_tq[a],_tq[b],f),lerpf(_tw[a],_tw[b],f)-0.1*r)
	if _tp[a] >= 0.0 or _tp[b] >= 0.0: y += lerpf(_raise(_tp[a],head)*_tf[a],_raise(_tp[b],head)*_tf[b],f)
	return Vector3(lerpf(_tx[a],_tx[b],f),y,lerpf(_tz[a],_tz[b],f))

func _pose(step: float) -> void:
	var head := _head_s-_sx[S_RECOIL]
	var low := maxi(_laid-TRAIL+1,0)
	var carry := _lift*(1.0-_pose_w)
	var breath := _beats(fposmod(_time/3.1,1.0),BREATH_KEYS)
	# Rings on the path, lying on the ground, over the body or on the water.
	for k in range(STATIONS):
		var s := head-_arc[k]
		var r := _radius[k]
		var f := s/STEP
		var i := floori(f)
		if i < low:
			i = low
			f = float(low)
		if i >= _laid:
			i = maxi(_laid-1,0)
			f = float(_laid)
		f -= i
		var a := i%TRAIL
		var b := (i+1)%TRAIL
		var ground := lerpf(_tg[a],_tg[b],f)+BELLY*r*lerpf(_tq[a],_tq[b],f)
		var afloat := lerpf(_tw[a],_tw[b],f)-0.1*r
		# A held breath swells the forebody; its belly stays on the ground.
		var swell := SWELL*_sx[S_SWELL]*_front_w[k]
		if _meal_w > 0.0: swell += BULGE*_meal_w*exp(-pow((_arc[k]-_meal)/MEAL_SPREAD,2.0))
		var y := _smax(ground,afloat)+carry*_carry_w[k]+swell*BELLY*r
		if _tp[a] >= 0.0 or _tp[b] >= 0.0: y += lerpf(_raise(_tp[a],head)*_tf[a],_raise(_tp[b],head)*_tf[b],f)
		_pos[k] = Vector3(lerpf(_tx[a],_tx[b],f),y,lerpf(_tz[a],_tz[b],f))
		_roll[k] = lerpf(_tr[a],_tr[b],f) if ground >= afloat else 0.0
		var gate := 1.0
		if _gate_mode > 0: gate = smoothstep(_gate,_gate+GATE_SOFT,s)
		elif _gate_mode < 0: gate = 1.0-smoothstep(_gate-GATE_SOFT,_gate,s)
		_scale[k] = maxf((1.0+0.035*breath*_breath_w[k]+swell)*gate,0.001)
	if _gate_mode > 0 and head-LENGTH > _gate+GATE_SOFT: _gate_mode = 0
	# The head's resting place on the path, and whether it is on the water.
	var head_r := RADIUS*0.85
	var snout := _sample(head,head_r,head)
	var back := _sample(head-HEAD,head_r,head)
	var fs := clampf(head/STEP,float(low),float(_laid))
	var si := mini(floori(fs),maxi(_laid-1,0))
	var water := lerpf(_tw[si%TRAIL],_tw[(si+1)%TRAIL],fs-si)
	var bed := lerpf(_tg[si%TRAIL],_tg[(si+1)%TRAIL],fs-si)
	_floating = water-0.1*head_r > bed+HEAD_BELLY*RADIUS*_tq[si%TRAIL]
	_level = water
	back.y += carry*0.9
	snout.y += carry
	var head_dir := (snout-back).normalized()
	# It holds its head's way steady: the weave passes under a swimming head.
	var neck := _sample(head-NECK,RADIUS,head)
	var nf := clampf((head-NECK)/STEP,float(low),float(_laid))
	var ni := mini(floori(nf),maxi(_laid-1,0))
	_swimming = lerpf(_tw[ni%TRAIL],_tw[(ni+1)%TRAIL],nf-ni)-0.1*RADIUS > lerpf(_tg[ni%TRAIL],_tg[(ni+1)%TRAIL],nf-ni)+BELLY*RADIUS*_tq[ni%TRAIL]
	var way := Vector2(snout.x-neck.x,snout.z-neck.z)
	if way.length_squared() > 1e-8 and step > 0.0:
		var rate := lerpf(12.0,3.0,_pose_w) if _going else 0.0
		_head_fwd = _head_fwd.slerp(way.normalized(),1.0-exp(-rate*step)).normalized()
	# The rear settles into its curves after a stop, and the tail's tip drifts.
	if _rest_w > 0.001:
		_held = _pos.duplicate()
		var drift := _drift(_time,9.0)
		for k in range(2,STATIONS-2):
			var w := _rest_w*_rear_w[k]
			if w <= 0.0: continue
			var mid := (_held[k-2]+_held[k+2])*0.5
			var push := _held[k]-mid
			push.y = 0.0
			_pos[k] += push*0.3*w
			if _tail_w[k] > 0.0:
				var t := _held[k-1]-_held[k+1]
				var side := Vector2(t.z,-t.x).normalized()*0.014*drift.x*_tail_w[k]*_rest_w
				_pos[k] += Vector3(side.x,0.0,side.y)
	# The neck lifts toward where the head is held and bends in an S from the
	# body's line to the head. The head's place moves only with the slow lean
	# and reach; its look turns on the spot, like a periscope.
	var hd := head_dir
	var hb := back
	var rel := clampf(_look_rel(),-LOOK_MAX-0.2,LOOK_MAX+0.2)
	_tilt = 0.12*clampf(rel,-1.0,1.0)*_pose_w
	if _pose_w > 0.001:
		var o := neck
		var o_back := _sample(head-NECK-0.03,RADIUS,head)
		var t0 := (o-o_back).normalized()
		var bend := _head_fwd.rotated(_sx[S_LEAN])
		var rest := back.y-carry*0.9
		var look := _head_fwd.rotated(rel)
		var pitch := _sx[S_PITCH]
		var held := Vector3(look.x*cos(pitch),sin(pitch),look.y*cos(pitch))
		# The curve keeps the neck's own length: its reach is corrected once
		# against the measured length, and the rings sit at their arc along it.
		# Drawn back (reach under 1) the head comes nearer the body and the S
		# deepens: its handles lengthen until the curve is the neck's length again.
		var length := NECK-HEAD
		var reach := sqrt(maxf(length*length-_lift*_lift,1e-4))*_sx[S_REACH]
		var raised := Vector3(o.x+bend.x*reach,rest+_lift,o.z+bend.y*reach)
		# The strike carries the head out to the frog, pointing at it.
		var strike_dir := Vector3.ZERO
		if _lunge > 0.0:
			strike_dir = (_strike_to-raised).normalized()
			raised = raised.lerp(_strike_to-strike_dir*HEAD*0.9,_lunge)
			held = held.slerp(strike_dir,_lunge).normalized()
		var span := o.distance_to(raised)
		var handle := 1.0
		for attempt in range(3):
			var total := 0.0
			var last := o
			for n in range(NECK_SAMPLES+1):
				var point := _hermite(o,t0*span*handle,raised,held*span*handle,float(n)/NECK_SAMPLES)
				total += point.distance_to(last)
				_curve[n] = point
				_curve_arc[n] = total
				last = point
			if attempt < 2: handle = clampf(handle*pow(length/maxf(total,1e-4),1.6),0.5,3.0)
		var total := _curve_arc[NECK_SAMPLES]
		# Drawn back, the neck's length gathers into the S's bend rather than
		# the rings bunching: they keep their share of the curve.
		for k in range(_neck_count):
			var want := (NECK-_arc[k])/(NECK-HEAD)*total
			var n := 1
			while n < NECK_SAMPLES and _curve_arc[n] < want: n += 1
			var u := clampf((want-_curve_arc[n-1])/maxf(_curve_arc[n]-_curve_arc[n-1],1e-6),0.0,1.0)
			_pos[k] = _pos[k].lerp(_curve[n-1].lerp(_curve[n],u),_pose_w)
		hb = back.lerp(raised,_pose_w)
		# Blend the way the head points by angle, from the neck's way, so it
		# turns and never flips.
		var trail_rel := wrapf(Vector2(head_dir.x,head_dir.z).angle()-_head_fwd.angle(),-PI,PI)
		var yaw := _head_fwd.angle()+lerpf(trail_rel,rel,_pose_w)
		var tilt := lerpf(asin(clampf(head_dir.y,-1.0,1.0)),pitch,_pose_w)
		hd = Vector3(cos(yaw)*cos(tilt),sin(tilt),sin(yaw)*cos(tilt))
		if _lunge > 0.0: hd = hd.slerp(strike_dir,_lunge).normalized()
	# Rings along the body.
	for k in range(STATIONS):
		var ahead := _pos[k-1] if k > 0 else hb
		var behind := _pos[k+1] if k < STATIONS-1 else _pos[k]
		var t := (ahead-behind).normalized()
		var up := (Vector3.UP-t*t.y).normalized()
		if _roll[k] != 0.0: up = up.rotated(t,atan(_roll[k]))
		var sc := _scale[k]
		_skeleton.set_bone_pose(k,Transform3D(Basis(up.cross(t)*sc,up*sc,t*sc),_pos[k]))
	# The head, tilted a touch into its look, and the tongue.
	var head_up := (Vector3.UP-hd*hd.y).normalized()
	if _tilt != 0.0: head_up = head_up.rotated(hd,_tilt)
	var head_side := head_up.cross(hd)
	var head_gate := 1.0
	if _gate_mode > 0: head_gate = smoothstep(_gate,_gate+GATE_SOFT,head-HEAD*0.5)
	elif _gate_mode < 0: head_gate = 1.0-smoothstep(_gate-GATE_SOFT,_gate,head-HEAD*0.5)
	var hs := maxf(head_gate,0.001)
	_skeleton.set_bone_pose(STATIONS,Transform3D(Basis(head_side*hs,head_up*hs,hd*hs),hb))
	_head_pos = hb
	_snout = hb+hd*HEAD
	# The jaw hinges at the back of the head; positive turns about the side
	# open it downward.
	var jaw := _sx[S_JAW]+_gape
	_skeleton.set_bone_pose(STATIONS+2,Transform3D(Basis(head_side*hs,head_up.rotated(head_side,jaw)*hs,hd.rotated(head_side,jaw)*hs),hb))
	var out := 0.0
	var flutter := 0.0
	var age := _time-_flick
	if age >= 0.0 and age < FLICK and _hiss_t < 0.0:
		out = smoothstep(0.0,0.07,age)*(1.0-smoothstep(FLICK-0.08,FLICK,age))
		flutter = sin(TAU*12.0*age)*0.5*out
	# Positive turns about the side tip the tongue down.
	var tongue := hd.rotated(head_side,0.15+flutter)
	var tongue_up := head_up.rotated(head_side,0.15+flutter)
	var ts := maxf(out*head_gate,0.001)
	_skeleton.set_bone_pose(STATIONS+1,Transform3D(Basis(head_side*ts,tongue_up*ts,tongue*ts),hb+hd*(HEAD*0.98)-head_up*RADIUS*0.3))

## The higher of the ground and the water, rounded over WATERLINE metres so
## the body glides onto the surface instead of meeting it at a corner.
static func _smax(a: float, b: float) -> float:
	var h := maxf(WATERLINE-absf(a-b),0.0)/WATERLINE
	return maxf(a,b)+h*h*WATERLINE*0.25

static func _hermite(p0: Vector3, m0: Vector3, p1: Vector3, m1: Vector3, t: float) -> Vector3:
	var t2 := t*t
	var t3 := t2*t
	return p0*(2.0*t3-3.0*t2+1.0)+m0*(t3-2.0*t2+t)+p1*(-2.0*t3+3.0*t2)+m1*(t3-t2)

# --- Curves (after tools/blender_bigfoot/ambient_clips.py) --------------------------

static func _smooth(x: float) -> float:
	x = clampf(x,0.0,1.0)
	return x*x*(3.0-2.0*x)

## A smoother ease: no jump in speed or acceleration at either end.
static func _smoother(x: float) -> float:
	x = clampf(x,0.0,1.0)
	return x*x*x*(x*(6.0*x-15.0)+10.0)

## 0..1 ease. With `over` it arrives early, overshoots by that share and settles.
static func _settle(x: float, over := 0.0) -> float:
	x = clampf(x,0.0,1.0)
	if over <= 0.0: return _smooth(x)
	var v := _smooth(x/0.72)
	if x > 0.5: v += over*pow(sin(PI*(x-0.5)/0.5),2.0)
	return v

## Value at `t` through [time, value, overshoot?] keys; each segment eases with
## _settle and equal neighbours hold.
static func _beats(t: float, keys: Array) -> float:
	var first: Array = keys[0]
	if t <= float(first[0]): return float(first[1])
	for i in range(keys.size()-1):
		var b: Array = keys[i+1]
		if t <= float(b[0]):
			var a: Array = keys[i]
			var over := float(b[2]) if b.size() > 2 else 0.0
			return lerpf(float(a[1]),float(b[1]),_settle((t-float(a[0]))/maxf(1e-6,float(b[0])-float(a[0])),over))
	return float(keys.back()[1])

## Three slow, seamless wander channels, roughly -1..1.
static func _drift(t: float, period: float) -> Vector3:
	var out := Vector3.ZERO
	for c in range(3):
		out[c] = 0.62*sin(TAU*t/period+1.7*c+2.3)+0.28*sin(TAU*2.0*t/period+1.7*c+4.6)+0.14*sin(TAU*3.0*t/period+1.7*c+6.9)
	return out

# --- The mesh ------------------------------------------------------------------------

## Faceted rings on their own bones, a head with a hinged jaw, and a forked
## tongue. Colours are per
## face with a slight shade each, like scripts/life_models.gd.
func _build_mesh(material: Material) -> ArrayMesh:
	var mesh := MeshParts.new()
	var rings: Array = []
	for k in range(STATIONS):
		var r := _radius[k]
		rings.append(_hexagon(r,1.0,0.85,0.0,0.0))
	# Body: segment k runs from station k back to k+1.
	for k in range(STATIONS-1):
		var u := _body_u(_arc[k])
		var bar := Variety.unit([k,17]) < 0.6 and k >= 2
		var spot := Variety.unit([k,29]) < 0.4
		for j in range(6):
			var plain := _body_color(k,j,u,false,false)
			var marked := _body_color(k,j,u,bar,spot)
			# Marks take half a face, so they read as bars and spots, not bands.
			mesh.quad(rings[k][j],k,rings[k][(j+1)%6],k,rings[k+1][j],k+1,rings[k+1][(j+1)%6],k+1,marked,plain)
	# Head sections on the head bone, their bellies level with the rings'.
	var hr := RADIUS
	var s0 := _hexagon(hr,0.95,0.8,-HEAD_BELLY*hr+0.866*0.8*hr,0.0)
	var s1 := _hexagon(hr,1.05,0.74,-HEAD_BELLY*hr+0.866*0.74*hr,HEAD*0.45)
	var s2 := _hexagon(hr,0.6,0.46,-HEAD_BELLY*hr+0.866*0.46*hr+0.02*hr,HEAD*0.86)
	var tip := Vector3(0,-0.38*hr,HEAD)
	var h := STATIONS
	var jaw := STATIONS+2
	for j in range(6):
		var n := (j+1)%6
		# The collar joins the head to the first ring.
		mesh.quad(s0[j],h,s0[n],h,rings[0][j],0,rings[0][n],0,_collar(j),_collar(j))
		# The lower half is the jaw, hinged at the back of the head: its back
		# edge stays with the head and the corner of the mouth stretches.
		var upper := j in [0,1,2]
		var bone := h if upper else jaw
		var top := HEAD_TOP if upper else (UNDER if j == 4 else LIP)
		mesh.quad(s1[j],bone,s1[n],bone,s0[j],h,s0[n],h,top,top)
		mesh.quad(s2[j],bone,s2[n],bone,s1[j],bone,s1[n],bone,top,top)
		mesh.tri(s2[j],bone,tip,bone,s2[n],bone,top)
	# Inside the mouth: a dark palate on the head and a floor on the jaw,
	# together along the lip line while it is closed.
	for bone in [h,jaw]:
		mesh.quad(s1[0],bone,s1[3],bone,s0[0],h,s0[3],h,MOUTH,MOUTH)
		mesh.quad(s2[0],bone,s2[3],bone,s1[0],bone,s1[3],bone,MOUTH,MOUTH)
		mesh.tri(s2[0],bone,tip,bone,s2[3],bone,MOUTH)
	# Small dark eyes high on the sides, just ahead of the head's widest,
	# standing a hair proud of the face they sit on.
	for j: int in [0,2]:
		var behind := (s1[j]+s1[j+1])*0.5
		var ahead := (s2[j]+s2[j+1])*0.5
		var center := behind.lerp(ahead,0.3)
		var along := (ahead-behind).normalized()
		var across := (s1[j+1]-s1[j]).normalized()
		var out := along.cross(across).normalized()
		if out.dot(Vector3(center.x,center.y,0.0)) < 0.0: out = -out
		center += out*0.0008
		var length := along*0.26*hr
		var width := across*0.17*hr
		mesh.quad(center+length,h,center+width,h,center-width,h,center-length,h,EYE,EYE)
	# A forked tongue, flat both ways so it shows from above and the side.
	var t := STATIONS+1
	var w := 0.0018
	for plane in [Vector3(1,0,0),Vector3(0,1,0)]:
		mesh.quad(plane*w+Vector3(0,0,0.02),t,-plane*w+Vector3(0,0,0.02),t,plane*w+Vector3(0,0,-0.004),t,-plane*w+Vector3(0,0,-0.004),t,TONGUE,TONGUE)
		for fork in [-1.0,1.0]:
			var end := Vector3(fork*0.0055,0,0.035)
			mesh.tri(plane*w*0.7+Vector3(0,0,0.019),t,end,t,-plane*w*0.7+Vector3(0,0,0.019),t,TONGUE)
	return mesh.commit(material)

static func _hexagon(r: float, w: float, h: float, lift: float, z: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for j in range(6):
		var a := TAU*j/6.0
		points.append(Vector3(cos(a)*r*w,sin(a)*r*h+lift,z))
	return points

## Faces 0 and 2 are the upper flanks, 1 the back, 3 and 5 the lower flanks and
## 4 the belly.
func _body_color(k: int, j: int, u: float, bar: bool, spot: bool) -> Color:
	if k == 0: return CRESCENT if j != 4 else UNDER
	var fade := 1.0-smoothstep(0.75,1.0,u)*0.6
	match j:
		1: return BACK.lerp(BAR,0.6) if spot and u < 0.85 else BACK
		0,2: return FLANK.lerp(BAR,0.8*fade) if bar else FLANK
		3,5: return LOW.lerp(BAR,0.55*fade) if bar else LOW
	return UNDER.lerp(BAR,0.5) if (spot and u < 0.7) else UNDER

## Two bright patches either side of the neck, nearly meeting on top.
func _collar(j: int) -> Color:
	if j == 1: return COLLAR.lerp(HEAD_TOP,0.55)
	return UNDER if j == 4 else COLLAR

class MeshParts:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var _face := 0

	func tri(a: Vector3, ba: int, b: Vector3, bb: int, c: Vector3, bc: int, color: Color) -> void:
		_face += 1
		var shade := 0.94+0.12*fposmod(sin(float(_face)*12.9898)*43758.5453,1.0)
		var painted := Color(color.r*shade,color.g*shade,color.b*shade,color.a)
		for pair in [[a,ba],[b,bb],[c,bc]]:
			var p: Vector3 = pair[0]
			vertices.append(p)
			var radial := Vector3(p.x,p.y,0.0)
			normals.append(radial.normalized() if radial.length_squared() > 1e-10 else Vector3.UP)
			colors.append(painted)
			bones.append_array([int(pair[1]),0,0,0])
			weights.append_array([1.0,0.0,0.0,0.0])

	## Front edge a-b, back edge c-d.
	func quad(a: Vector3, ba: int, b: Vector3, bb: int, c: Vector3, bc: int, d: Vector3, bd: int, first: Color, second: Color) -> void:
		tri(a,ba,c,bc,d,bd,first)
		tri(a,ba,d,bd,b,bb,second)

	func commit(material: Material) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(0,material)
		return mesh

## Ice on the ponds (life_winter.gd); stand-in lives in the probes have none.
func _frozen() -> bool:
	return "winter" in life and life.winter != null and life.winter.frozen()
