extends Node
## Flipping the diorama over: its other side is a new world
## (docs/scenic/modeless-flip.md). Behind `--modeless`.
##
## The rim gesture (scripts/hand_reach.gd) drives it with `begin(screen_pos)`,
## `drag(progress)` and `release(progress)`: progress runs 0..1 as the drag
## goes up and over the lip, and upright is the tipping point. Dragged, the
## diorama tips up on a hinge at the far edge, with weight and a little
## resistance. Let go slowly before upright and it falls back with a small
## bounce (the edge spring then sinks a basin); flicked, it is tossed (below).
## Upright or past it, it goes over: a pull back, a throw, a slow hover upside
## down (which lasts as long as the new world needs), a drop and a thump, and
## the world that lands face up is new.
##
## How it looks. The world's nodes are never moved: terrain, water, creatures,
## particles and the wind all work in world space. Instead `begin` takes a
## snapshot: a copy of every mesh and multimesh the diorama draws (sharing the
## meshes, so it is cheap) hangs on one pivot, and the real nodes move to a
## render layer the camera and the lights do not use. The pivot is what tips
## and turns, in front of the fixed room, so the sky, sun and lights stay put.
## The real world carries on hidden underneath, which is where the new one is
## made. The God Hand is a child of the real terrain, so the terrain node
## rides the pivot's pose and the hand grips the rim all the way over.
##
## The new world is made with the existing generator (scripts/cozy_regrowth.gd
## does it for Regrow): the world is sampled on a worker thread from a fresh
## seed once the drag passes GENERATE_AT, and formed with `form_inland` behind
## the snapshot while it is thrown. The flip hovers, alive, until it is done.
## The drop touches down on the new world, flat and folded like a Regrow's,
## and the land grows up out of it with the sky easing over.
##
## **The toss and the dip** (docs/scenic/modeless.md, "The agreed scheme"). Up
## is decided at the release: let go slowly and the plate settles back and
## says so (`set_down`, the edge spring sinks a basin); let go with a flick
## and it is tossed: it turns about its far edge at the flick's speed under a
## hinged slab's gravity (`TOSS_GRAVITY` times the cosine of its angle), and
## either falls back and wobbles or passes upright and goes over, which is the
## flip. While it is in the air a press catches it where it is (`catch`), so a
## second flick adds to the first, like pumping a swing. Pulled down, the
## plate dips as a unit and tips a little toward the hand (`dip_begin`,
## `dip_to`, `dip_release`); let go, it snaps back up and says so (`dipped`),
## and the edge spring (scripts/edge_spring.gd) raises its range.
##
## The old world is never lost. `form_inland` leaves it one step down the undo
## history (marked "flip"), and the world is also kept whole in memory and in
## `flip-previous.json` beside the places. `flip_back()` flips the other way
## and brings it back, by undo when the flip is still the last step, from the
## kept copy when it is not.

const Generator = preload("res://scripts/cozy_world_generator.gd")
const Budget = preload("res://scripts/frame_work_budget.gd")

## Emitted once the new world has landed, and when a flip fell back.
signal landed(world_seed: int)
signal fell_back
signal phase_changed(phase: int)
## A slow release: the plate settled back from `progress` (0..1) of the lift.
signal set_down(progress: float)
## A dip was let go and the plate is back at rest, with the pull it had.
signal dipped(amount: float)

enum Phase { IDLE, HELD, FALL, THROW, HOVER, DROP, LAND, TOSS, DIP, RISE }
## Which world the flip brings up: a fresh one, the last step of undo, or the
## copy kept in memory.
enum Source { NEW, UNDO, KEPT }

## The render layer (bit) the real world moves to while its snapshot flips.
## Nothing looks at it: the camera and every light drop it.
const HIDDEN_LAYER := 1 << 18
## Subtrees the snapshot leaves out, by script: the room (weather, sky, lights),
## things that are skinned or physical, and the hand, which is not a copy.
const LEAVE_OUT := ["precipitation.gd","lightning.gd","atmosphere.gd","landscape_lighting.gd","fire_effects.gd","god_hand.gd","creature_actor.gd","diorama_world_play.gd","native_explosives.gd","native_object_selection.gd","bigfoot_encounter.gd","resident_wind.gd","diorama_flip.gd"]
## The plate when its skirt cannot be read: half its width and the height of
## its middle (m).
const DEFAULT_HALF := 14.4
const DEFAULT_MIDDLE := -2.1

## Progress (or angle over pi) at which the world starts to be made. A
## release goes over once the plate is upright (TIP_ANGLE, below).
const GENERATE_AT := 0.2
## A drag that reaches this far goes over without waiting for the release.
const AUTO_COMMIT := 0.97
## Seconds the drag's rate is smoothed over (the toss reads it).
const RATE_SMOOTH := 0.06

## The hinge stays on the far edge while the plate tips up this far (radians),
## then slides to the middle by a quarter turn.
const HINGE_HOLD := 0.5
## While dragged the plate follows the drag's angle (progress times pi) on a
## spring (natural frequency 1/s, damping ratio), so it lags like something
## heavy, and RESIST of the lift is held back until the drag is well over.
const HOLD_W := 13.0
const HOLD_ZETA := 0.85
const RESIST := 0.16
## How high the middle rises while it turns, as a share of the plate's half
## width. Fully turned, and on the ground again, it has none.
const LIFT := 0.3
## The fall back: radians/s² pulling down (more when high), a light damping
## (1/s), the share of speed a landing keeps, and the speed under which it
## has stopped.
const FALL_ACCEL := 26.0
const FALL_DRAG := 0.6
const BOUNCE := 0.28
const REST_SPEED := 0.35
## The pull back before the throw: radians, seconds, and its spring (1/s).
const PULL_ANGLE := 0.16
const PULL_TIME := 0.2
const PULL_W := 16.0
## The throw and the hover: the angle it hangs at (radians, a little over
## 150 degrees), how far it creeps on while waiting, the springs (1/s and
## damping ratio), the extra height it floats at and how much it bobs (m),
## and the least it hovers for (s).
const HOVER_ANGLE := 2.7
const HOVER_CREEP := 0.16
const THROW_W := 7.5
const THROW_ZETA := 0.8
const HOVER_W := 5.0
const HOVER_ZETA := 0.7
const HOVER_LIFT := 1.6
const HOVER_BOB := 0.35
const HOVER_MIN := 0.3
## The slice of each frame (microseconds) forming the new world may take
## while it is hidden behind the snapshot, against the usual 2000
## (scripts/frame_work_budget.gd). Forming is then about a second instead of
## four; the frames stay under a third of a 60 Hz frame of work.
const MAKE_BUDGET_USEC := 6000
## A world that takes longer than this (s) to make is given up on and the
## old one falls back, untouched.
const GIVE_UP := 40.0
## The drop: radians/s² toward the ground.
const DROP_ACCEL := 15.0
## The landing thump, and the rumble held while it is made (0..1).
const THUMP := 0.6
const RUMBLE := 0.45
## The landing's bounce as the world shakes on screen: metres of dip, and the
## spring (1/s and damping ratio), and its length (s).
const LAND_DIP := 5.0
const LAND_W := 22.0
const LAND_ZETA := 0.28
const LAND_TIME := 0.9
## Seconds the new land takes to grow.
const GROW_SECONDS := 4.0
## The temporary trigger's pace: progress per second.
const DEBUG_PACE := 1.1
## The toss. A release whose drag rate (progress per second, smoothed over
## RATE_SMOOTH) is at least TOSS_RATE is a flick; slower is a set-down. A
## flick throws the plate at TOSS_GAIN of the hand's angular speed (progress
## rate times pi), or the plate's own if faster. In the air it is a hinged
## slab: angular acceleration -TOSS_GRAVITY*cos(angle) (rad/s², so going
## over from flat needs sqrt(2*TOSS_GRAVITY) = 5.7 rad/s) less TOSS_DRAG times
## its rate. Upright (TIP_ANGLE) is the point of no return. Landing it keeps
## BOUNCE of its speed, as the fall back does.
const TOSS_RATE := 1.5
const TOSS_GAIN := 0.5
const TOSS_GRAVITY := 16.0
const TOSS_DRAG := 0.3
const TIP_ANGLE := PI*0.5
## The dip: at a full pull the plate drops DIP_DROP metres and tips DIP_TILT
## radians toward the hand (about its far edge). It follows the pull on the
## hold spring; let go, it snaps back on a stiffer one (DIP_RISE_W 1/s,
## DIP_RISE_ZETA) and is handed back the moment it passes its rest.
const DIP_DROP := 0.9
const DIP_TILT := 0.06
const DIP_RISE_W := 26.0
const DIP_RISE_ZETA := 0.5

var scene: Node3D
var editor: NativeChunkEditor
var phase := Phase.IDLE
## The plate's angle (radians; pi is upside down) and its rate.
var angle := 0.0
var omega := 0.0
## Which world is brought up and how far the world's making has got.
var source := Source.NEW
## True once the world to land is made and hidden under the snapshot.
var world_ready := false
## The seed of the world that landed last, and a seed to use next (< 0 is a
## random one), for a probe.
var last_seed := -1
var next_seed := -1
## Seconds the throw and the hover have taken, and the world's making.
var throw_time := 0.0
var hover_time := 0.0
var making_time := 0.0
## What making the last world cost (ms): sampling on the worker, forming the
## land (spread over frames), fitting the view, and the longest single step
## the main thread took inside forming.
var sample_ms := 0.0
var form_ms := 0.0
var fit_ms := 0.0
## What keeping the old world whole cost the main thread (ms), at the drag.
var keep_ms := 0.0
## Seconds of game time (frames at 60 Hz) into the making at which each stage of making the world finished,
## for tuning: "begun", "sampled", "formed", "fitted", "ready".
var stamps := {}
## The snapshot's pivot: it is what tips and turns.
var pivot: Node3D
var _progress := 0.0
var _rate := 0.0
var _goal := 0.0
var _grab_dir := Vector3.BACK
var _axis := Vector3.RIGHT
var _centre := Vector3(0,DEFAULT_MIDDLE,0)
var _half := DEFAULT_HALF
var _hidden: Array = []
var _lights := {}
var _camera_mask := 0
var _terrain_base := Transform3D.IDENTITY
var _rim_local := Vector3.ZERO
## The world that was replaced, whole: document, scene state, label. Kept in
## memory for `flip_back`, and written beside the places.
var kept := {}
var _prepared := {}
var _preparing := false
var _prepare_id := 0
var _make_id := 0
var _world := {}
var _seed := -1
var _look := {}
var _hour := 0.0
var _distance := 40.0
var _paused_before := false
var _bounce := 0.0
var _bounce_speed := 0.0
var _land_time := 0.0
var _debug_progress := -1.0
var _debug_pace := DEBUG_PACE
var _debug_release := 1.0
var _forming_started := false
var _clock := 0.0
var _hand_on := false
## The toss: flicks since the plate left the ground (a pump is more than
## one), the highest it has been, and the angle a catch took it at (the drag
## adds to that).
var tosses := 0
var toss_peak := 0.0
var _base_angle := 0.0
var _tossed := false
## The dip: how far down (0..1 of the cap), its rate and the pull it follows.
var dip := 0.0
var dip_speed := 0.0
var _dip_goal := 0.0
var _dip_amount := 0.0

static func enabled() -> bool:
	return "--modeless" in OS.get_cmdline_user_args()

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	name = "DioramaFlip"

## True while a flip is anywhere between the grab and the end of the landing.
func active() -> bool:
	return phase != Phase.IDLE

## True from the moment a flip is decided until the world has landed. The rim
## routing ignores presses while it is.
func going_over() -> bool:
	return phase in [Phase.THROW,Phase.HOVER,Phase.DROP,Phase.LAND]

## What the rim reaches, plate coordinates, so the hand can grip it.
func can_begin() -> bool:
	return phase == Phase.IDLE and scene != null and _idle_world()

func _idle_world() -> bool:
	var places: Node = scene.get("places")
	return not editor.forming and (places == null or (places.initialized and not places.busy and not places.holding))

# --- The rim gesture's API ---------------------------------------------------

## The rim is grabbed at `screen_pos`. Takes the snapshot and hangs the hand on
## the lip. False when a flip (or a regrowth) is already in hand.
func begin(screen_pos: Vector2) -> bool:
	if not can_begin(): return false
	editor.finish_stroke()
	# A scripted drag left over from a flip that went over on its own.
	_debug_progress = -1.0
	_rate = 0.0
	_progress = 0.0
	_last_progress = 0.0
	angle = 0.0
	omega = 0.0
	_goal = 0.0
	_base_angle = 0.0
	tosses = 0
	toss_peak = 0.0
	_tossed = false
	source = Source.NEW
	_kept_pending = true
	_grab_from(screen_pos)
	_hold_world()
	_set_phase(Phase.HELD)
	_grip(true)
	return true

## The drag is `progress` (0..1) of the way over the lip (from the catch,
## after one).
func drag(progress: float) -> void:
	if phase != Phase.HELD: return
	progress = clampf(progress,0.0,1.0)
	_progress = progress
	_goal = _goal_angle(progress) if _base_angle <= 0.0 else _base_angle+PI*progress
	if progress >= GENERATE_AT or _goal >= GENERATE_AT*PI: _prepare()
	if progress >= AUTO_COMMIT or _goal >= PI*AUTO_COMMIT: _go_over()

## The drag is let go at `progress`. Upright or past it, it goes over; with a
## flick it is tossed; slowly, it settles back and `set_down` says how far it
## had been lifted.
func release(progress: float) -> void:
	if phase != Phase.HELD: return
	progress = clampf(progress,0.0,1.0)
	if angle >= TIP_ANGLE: _go_over()
	elif _rate >= TOSS_RATE: _toss()
	else:
		_set_down = progress if not _tossed else -1.0
		_fall_back()

var _set_down := -1.0

## True while the plate is in the air from a toss (or settling back) and a
## press may catch it.
func can_catch() -> bool:
	return phase in [Phase.TOSS,Phase.FALL] and pivot != null

## A press catches the plate in the air: it is held where it is, its speed
## kept, and the drag from here adds to its angle.
func catch(_screen_pos: Vector2) -> bool:
	if not can_catch(): return false
	_base_angle = maxf(angle,0.001)
	_progress = 0.0
	_last_progress = 0.0
	_rate = 0.0
	_goal = _base_angle
	_set_phase(Phase.HELD)
	_grip(true)
	return true

## A flick: the plate is thrown about its far edge.
func _toss() -> void:
	omega = maxf(omega,_rate*PI*TOSS_GAIN)
	tosses += 1
	_tossed = true
	_set_phase(Phase.TOSS)

func _step_toss(delta: float) -> void:
	var remaining := delta
	while remaining > 0.0:
		var h := minf(remaining,1.0/240.0)
		remaining -= h
		omega -= (TOSS_GRAVITY*cos(angle)+TOSS_DRAG*omega)*h
		angle += omega*h
	toss_peak = maxf(toss_peak,angle)
	if angle >= GENERATE_AT*PI: _prepare()
	if angle >= TIP_ANGLE:
		_go_over(true)
		return
	if angle <= 0.0:
		angle = 0.0
		if absf(omega) > REST_SPEED:
			omega = -omega*BOUNCE
			var thump: Variant = scene.get("_tremor")
			if thump != null: thump.add(clampf(absf(omega)*0.08,0.05,0.25))
		else:
			omega = 0.0
			_finish_fall_back()

# --- The dip -----------------------------------------------------------------

## The rim is pulled down at `screen_pos`: the snapshot is taken and the plate
## dips with the pull. False when a flip or a regrowth is busy.
func dip_begin(screen_pos: Vector2) -> bool:
	if not can_begin(): return false
	editor.finish_stroke()
	_debug_progress = -1.0
	angle = 0.0
	omega = 0.0
	dip = 0.0
	dip_speed = 0.0
	_dip_goal = 0.0
	_grab_from(screen_pos)
	_hold_world()
	_set_phase(Phase.DIP)
	_grip(true)
	return true

## How far down the plate is pulled, 0..1 of the cap.
func dip_to(amount: float) -> void:
	if phase == Phase.DIP: _dip_goal = clampf(amount,0.0,1.2)

## Let the dip go: the plate snaps back up and `dipped(amount)` is emitted
## the moment it is at rest again, with the pull it had.
func dip_release(amount: float) -> void:
	if phase != Phase.DIP: return
	_dip_amount = amount
	_set_phase(Phase.RISE)

## Finish a dip at once (an undo, a new press).
func dip_finish() -> void:
	if phase == Phase.DIP: dip_release(0.0)
	if phase == Phase.RISE: _dip_done()

func _step_dip(delta: float) -> void:
	var goal := _dip_goal if phase == Phase.DIP else 0.0
	var w := HOLD_W if phase == Phase.DIP else DIP_RISE_W
	var zeta := HOLD_ZETA if phase == Phase.DIP else DIP_RISE_ZETA
	var remaining := delta
	while remaining > 0.0:
		var h := minf(remaining,1.0/240.0)
		remaining -= h
		dip_speed += (w*w*(goal-dip)-2.0*zeta*w*dip_speed)*h
		dip += dip_speed*h
		if phase == Phase.RISE and dip <= 0.0:
			_dip_done()
			return

func _dip_done() -> void:
	dip = 0.0
	dip_speed = 0.0
	_release_world()
	_set_phase(Phase.IDLE)
	dipped.emit(_dip_amount)

## Flip the other way and bring the previous world back: by undo when the flip
## is still the last step of the undo history, from the kept copy when it is
## not. False when there is nothing to bring back.
func flip_back() -> bool:
	var kind := back_source()
	if kind == Source.NEW or not can_begin(): return false
	_grab_from(Vector2(-1.0,-1.0),true)
	_hold_world()
	_kept_pending = true
	source = kind
	_set_phase(Phase.HELD)
	_grip(true)
	_go_over()
	return true

## Which world `flip_back` would bring up: UNDO, KEPT, or NEW for none.
func back_source() -> Source:
	var history: Array = editor.data._undo
	if not history.is_empty() and history.back().get("flip",false): return Source.UNDO
	if not kept.is_empty(): return Source.KEPT
	return Source.NEW

# --- Scripted flips (probes) ------------------------------------------------
## For the probes: a scripted drag from the near lip (or, given `pace`, the
## speed of it in progress per second) that lets go at `release_at`. In play
## the rim drives begin / drag / release (scripts/hand_reach.gd flip_*
## signals, connected in studies/cozy_worlds.gd).
func debug_flip(release_at := 1.0, pace := DEBUG_PACE) -> bool:
	var size := scene.get_viewport().get_visible_rect().size
	if not begin(Vector2(size.x*0.5,size.y*0.85)): return false
	_debug_progress = 0.0
	_debug_pace = pace
	_debug_release = release_at
	return true

# --- Frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.IDLE: return
	delta = minf(delta,0.05)
	_clock += delta
	if _debug_progress >= 0.0 and phase == Phase.HELD:
		var last := _debug_progress
		_debug_progress = minf(1.0,_debug_progress+_debug_pace*delta)
		_feed_rate(_debug_progress-last,delta)
		drag(_debug_progress)
		if _debug_progress >= _debug_release:
			var at := _debug_progress
			_debug_progress = -1.0
			release(at)
	elif phase == Phase.HELD:
		_feed_rate(_progress-_last_progress,delta)
	_last_progress = _progress
	match phase:
		Phase.HELD: _step_held(delta)
		Phase.FALL: _step_fall(delta)
		Phase.THROW: _step_throw(delta)
		Phase.HOVER: _step_hover(delta)
		Phase.DROP: _step_drop(delta)
		Phase.LAND: _step_land(delta)
		Phase.TOSS: _step_toss(delta)
		Phase.DIP,Phase.RISE: _step_dip(delta)
	if phase in [Phase.HELD,Phase.FALL,Phase.THROW,Phase.HOVER,Phase.DROP,Phase.TOSS,Phase.DIP,Phase.RISE]: _pose_all()
	if phase in [Phase.THROW,Phase.HOVER]: making_time += delta
	var rumble: Node = scene.get("world_rumble")
	if rumble != null and phase in [Phase.THROW,Phase.HOVER]:
		rumble.hold(&"flip",RUMBLE)

var _last_progress := 0.0

func _feed_rate(step: float, delta: float) -> void:
	_rate = lerpf(_rate,step/maxf(delta,0.0001),1.0-exp(-delta/RATE_SMOOTH))

## The drag's angle: progress times pi, with the first stretch held back.
func _goal_angle(progress: float) -> float:
	var held := lerpf(1.0-RESIST,1.0,smoothstep(0.35,0.75,progress))
	return PI*progress*held

func _spring(goal: float, w: float, zeta: float, delta: float) -> void:
	var half := delta*0.5
	for i in range(2):
		omega += (w*w*(goal-angle)-2.0*zeta*w*omega)*half
		angle += omega*half

func _step_held(delta: float) -> void:
	_spring(_goal,HOLD_W,HOLD_ZETA,delta)
	angle = maxf(angle,0.0)

func _fall_back() -> void:
	_set_phase(Phase.FALL)

func _step_fall(delta: float) -> void:
	omega -= (FALL_ACCEL*(0.35+absf(sin(angle)))+omega*FALL_DRAG)*delta
	angle += omega*delta
	if angle <= 0.0:
		angle = 0.0
		if absf(omega) > REST_SPEED:
			omega = -omega*BOUNCE
			var thump: Variant = scene.get("_tremor")
			if thump != null: thump.add(clampf(absf(omega)*0.08,0.05,0.25))
		else:
			omega = 0.0
			_finish_fall_back()

func _finish_fall_back() -> void:
	_release_world()
	_settle_scene()
	_set_phase(Phase.IDLE)
	fell_back.emit()
	var settled := _set_down
	_set_down = -1.0
	if settled >= 0.0: set_down.emit(settled)

## Undo what making a world held: the pause, the rumble, the brush.
func _settle_scene() -> void:
	Budget.override_usec = 0
	if not _made: return
	_made = false
	var places: Node = scene.get("places")
	if places != null: places.busy = false
	scene._paused = _paused_before
	var rumble: Node = scene.get("world_rumble")
	if rumble != null: rumble.release(&"flip")
	if scene.has_method("resume_creation"): scene.resume_creation()

var _made := false

## Decided: go over. Starts the world's making and the pull back (none when
## it is tossed over: it is already on its way).
func _go_over(tossed := false) -> void:
	if phase == Phase.THROW: return
	_pull = 0.0 if tossed else PULL_TIME
	throw_time = 0.0
	hover_time = 0.0
	making_time = 0.0
	world_ready = false
	_forming_started = false
	_set_phase(Phase.THROW)
	_make_world.call_deferred()

var _pull := 0.0

func _step_throw(delta: float) -> void:
	throw_time += delta
	if _pull > 0.0:
		_pull -= delta
		_spring(_pull_goal(),PULL_W,0.7,delta)
		return
	_spring(HOVER_ANGLE,THROW_W,THROW_ZETA,delta)
	if angle >= HOVER_ANGLE-0.12: _set_phase(Phase.HOVER)

var _pull_from := -1.0

## The pull back's goal: a little under where the throw started, so the
## plate rocks back before it goes.
func _pull_goal() -> float:
	if _pull_from < 0.0: _pull_from = angle
	return maxf(0.0,_pull_from-PULL_ANGLE)

func _step_hover(delta: float) -> void:
	hover_time += delta
	var creep := HOVER_CREEP*(1.0-exp(-hover_time/1.5))
	_spring(HOVER_ANGLE+creep,HOVER_W,HOVER_ZETA,delta)
	if world_ready and hover_time >= HOVER_MIN:
		omega = maxf(omega,0.0)
		_set_phase(Phase.DROP)
	elif making_time > GIVE_UP and not _forming_started:
		# Nothing came: the old world falls back, unchanged.
		_make_id += 1
		_set_phase(Phase.FALL)
		omega = 0.0

func _step_drop(delta: float) -> void:
	omega += DROP_ACCEL*delta
	angle += omega*delta
	if angle >= PI:
		angle = PI
		_touchdown()

## Touchdown: the thump, and the new world is where the snapshot was.
func _touchdown() -> void:
	omega = 0.0
	var thump: Variant = scene.get("_tremor")
	if thump != null: thump.add(THUMP)
	_bounce = 0.0
	_bounce_speed = -LAND_DIP
	_land_time = 0.0
	_set_phase(Phase.LAND)
	_reveal()

func _step_land(delta: float) -> void:
	_land_time += delta
	var half := delta*0.5
	for i in range(2):
		_bounce_speed += (-LAND_W*LAND_W*_bounce-2.0*LAND_ZETA*LAND_W*_bounce_speed)*half
		_bounce += _bounce_speed*half
	var tremor: Variant = scene.get("_tremor")
	if tremor != null: tremor.jiggle = Vector3(0.0,_bounce,_bounce*0.01)
	if _land_time >= LAND_TIME:
		if tremor != null: tremor.jiggle = Vector3.ZERO
		_grip(false)
		_set_phase(Phase.IDLE)

func _set_phase(next: Phase) -> void:
	phase = next
	if next == Phase.THROW: _pull_from = -1.0
	phase_changed.emit(next)

# --- Pose --------------------------------------------------------------------

## The plate's transform at angle `a` (radians) with its middle `lift` metres
## up: about a hinge at the far edge that slides to the middle by a quarter
## turn, so it tips up like a lid and turns over like a coin.
func pose(a: float, lift: float) -> Transform3D:
	var s := clampf((a-HINGE_HOLD)/(PI*0.5-HINGE_HOLD),0.0,1.0)
	var hinge := _centre-_grab_dir*_half*(1.0-smoothstep(0.0,1.0,s))
	var turn := Basis(_axis,a)
	var t := Transform3D(turn,hinge-turn*hinge)
	t.origin += Vector3.UP*lift
	return t

## The middle's lift at the current angle.
func lift_now() -> float:
	var lift := LIFT*_half*sin(clampf(angle,0.0,PI))
	if phase in [Phase.HOVER,Phase.DROP]:
		var floating := HOVER_LIFT*clampf(1.0-(angle-HOVER_ANGLE)/(PI-HOVER_ANGLE),0.0,1.0)
		lift += floating*(1.0 if phase == Phase.DROP else minf(1.0,hover_time*3.0))
		if phase == Phase.HOVER: lift += HOVER_BOB*sin(hover_time*3.1)*minf(1.0,hover_time)
	return lift

func _pose_all() -> void:
	if pivot == null: return
	var t := pose(angle,lift_now())
	if phase in [Phase.DIP,Phase.RISE]: t = pose(-DIP_TILT*dip,-DIP_DROP*dip)
	pivot.transform = t
	editor.terrain.global_transform = t*_terrain_base

func _grab_from(screen_pos: Vector2, reverse := false) -> void:
	var box := _plate_box()
	_half = box.size.x*0.5
	_centre = Vector3(0.0,box.position.y+box.size.y*0.5,0.0)
	# Which way the grabbed edge lies from the middle: the pointer's ray
	# over the plate, snapped to the nearest of the four sides, else the
	# side facing the camera.
	var flat: Vector3 = scene.camera.global_position-_centre
	flat.y = 0.0
	var towards := flat.normalized() if flat.length() > 0.001 else Vector3.BACK
	if screen_pos.x >= 0.0:
		var origin: Vector3 = scene.camera.project_ray_origin(screen_pos)
		var direction: Vector3 = scene.camera.project_ray_normal(screen_pos)
		if absf(direction.y) > 0.0001:
			var hit := origin+direction*((0.0-origin.y)/direction.y)
			var away := Vector3(hit.x,0.0,hit.z)
			if away.length() > 0.5: towards = away.normalized()
	# The camera's own side of the plate, whichever way it is turned: the
	# grabbed edge is the one nearest the camera, so it lifts toward the view.
	_grab_dir = towards
	if reverse: _grab_dir = -towards
	_axis = _grab_dir.cross(Vector3.UP).normalized()
	_rim_local = Vector3(_grab_dir.x*(_half-0.4),0.3,_grab_dir.z*(_half-0.4))

## The plate's bounds: half width and the height of its middle, from the skirt.
func _plate_box() -> AABB:
	var skirt: Variant = editor.get("_skirt")
	if skirt is MeshInstance3D and skirt.mesh != null:
		return skirt.global_transform*skirt.get_aabb()
	return AABB(Vector3(-DEFAULT_HALF,DEFAULT_MIDDLE-2.7,-DEFAULT_HALF),Vector3(DEFAULT_HALF*2.0,5.4,DEFAULT_HALF*2.0))

# --- The snapshot ------------------------------------------------------------

func _left_out(node: Node) -> bool:
	var script: Variant = node.get_script()
	if script == null: return false
	return String(script.resource_path).get_file() in LEAVE_OUT

func _gather(node: Node, into: Array) -> void:
	for child in node.get_children():
		if child == pivot or child == self or _left_out(child): continue
		if child is CanvasLayer or child is Viewport: continue
		if child is MeshInstance3D and child.get_parent() is Skeleton3D: continue
		# Every mesh node is hidden, even one with nothing to draw yet: the new
		# world may give it something.
		if child is MeshInstance3D or child is MultiMeshInstance3D:
			if (child.layers & 1) != 0: into.append(child)
		_gather(child,into)

## True when a node draws something now, which the snapshot must copy.
func _drawn(node: GeometryInstance3D) -> bool:
	if not node.is_visible_in_tree(): return false
	if node is MeshInstance3D: return node.mesh != null
	return node.multimesh != null and node.multimesh.instance_count > 0

func _copy_of(node: GeometryInstance3D) -> GeometryInstance3D:
	var copy: GeometryInstance3D
	if node is MeshInstance3D:
		var mesh := MeshInstance3D.new()
		mesh.mesh = node.mesh
		for surface in range(node.mesh.get_surface_count()):
			var own: Material = node.get_surface_override_material(surface)
			if own != null: mesh.set_surface_override_material(surface,own)
		copy = mesh
	else:
		var many := MultiMeshInstance3D.new()
		many.multimesh = node.multimesh
		copy = many
	copy.material_override = node.material_override
	copy.material_overlay = node.material_overlay
	copy.cast_shadow = node.cast_shadow
	copy.transparency = node.transparency
	copy.extra_cull_margin = node.extra_cull_margin
	copy.custom_aabb = node.custom_aabb
	copy.lod_bias = node.lod_bias
	copy.gi_mode = node.gi_mode
	copy.visibility_range_begin = node.visibility_range_begin
	copy.visibility_range_end = node.visibility_range_end
	copy.visibility_range_begin_margin = node.visibility_range_begin_margin
	copy.visibility_range_end_margin = node.visibility_range_end_margin
	copy.visibility_range_fade_mode = node.visibility_range_fade_mode
	copy.layers = 1
	copy.transform = node.global_transform
	return copy

## Snapshot the diorama, hide the real one and hang the hand on the lip.
func _hold_world() -> void:
	pivot = Node3D.new()
	pivot.name = "FlipSnapshot"
	scene.add_child(pivot)
	var sources: Array = []
	_gather(scene,sources)
	_hidden.clear()
	for node: GeometryInstance3D in sources:
		if _drawn(node): pivot.add_child(_copy_of(node))
		_hidden.append([node,node.layers])
		node.layers = HIDDEN_LAYER
	# The camera and the lights never look at the hidden layer.
	_camera_mask = scene.camera.cull_mask
	scene.camera.cull_mask = _camera_mask & ~HIDDEN_LAYER
	_lights.clear()
	for light: Light3D in scene.find_children("*","Light3D",true,false):
		_lights[light] = light.light_cull_mask
		light.light_cull_mask = light.light_cull_mask & ~HIDDEN_LAYER
	_terrain_base = editor.terrain.global_transform
	get_tree().node_added.connect(_on_node_added)
	_paused_before = bool(scene.get("_paused"))

## A node the real world grows mid-flip (its meshes are rebuilt when the new
## world is made) is hidden the moment it appears.
func _on_node_added(node: Node) -> void:
	if not node is GeometryInstance3D or node == pivot or pivot == null or pivot.is_ancestor_of(node): return
	if not (node is MeshInstance3D or node is MultiMeshInstance3D) or not scene.is_ancestor_of(node) or _left_out_above(node): return
	# Meshes in a SubViewport (the palette's thumbnails) are not the diorama.
	if node.get_viewport() != scene.get_viewport(): return
	_hide_new.call_deferred(node)
	if node.layers & 1: _hidden.append([node,node.layers]); node.layers = HIDDEN_LAYER

func _hide_new(node: GeometryInstance3D) -> void:
	if is_instance_valid(node) and phase != Phase.IDLE and node.layers & 1:
		_hidden.append([node,node.layers])
		node.layers = HIDDEN_LAYER

func _left_out_above(node: Node) -> bool:
	var at := node
	while at != null and at != scene:
		if _left_out(at): return true
		at = at.get_parent()
	return false

## Put the real world back where it was: layers, lights, camera, terrain.
func _release_world() -> void:
	if pivot == null: return
	if get_tree().node_added.is_connected(_on_node_added): get_tree().node_added.disconnect(_on_node_added)
	scene.camera.cull_mask = _camera_mask
	for light in _lights:
		if is_instance_valid(light): light.light_cull_mask = _lights[light]
	_lights.clear()
	for entry: Array in _hidden:
		if is_instance_valid(entry[0]): entry[0].layers = entry[1]
	_hidden.clear()
	editor.terrain.global_transform = _terrain_base
	pivot.queue_free()
	pivot = null
	_grip(false)

func _grip(on: bool) -> void:
	var hand: Node3D = scene.get("god_hand")
	if hand == null: return
	if on:
		hand.reach_gesture = "flip"
		hand.reach_point = _rim_local
		hand.reach_facing = -_grab_dir
		_hand_on = true
	elif _hand_on:
		_hand_on = false
		hand.reach_gesture = ""
		hand.reach_point = null
		hand.reach_facing = null

# --- The new world -----------------------------------------------------------

## Start the world sampling (on a worker thread) so it is ready when wanted;
## also keep the world it will replace, whole. One sample is held for the
## next flip when this one fell back.
func _prepare() -> void:
	if _kept_pending: _keep_current()
	if _preparing or not _prepared.is_empty(): return
	_preparing = true
	var id := _prepare_id
	var places: Node = scene.get("places")
	var chosen := next_seed
	if chosen < 0: chosen = places._fresh_seed() if places != null else randi()%1000000
	var began := Time.get_ticks_usec()
	# The same job as Generator.sample_async, but with its task known here so
	# that leaving the tree (or quitting) joins it.
	var result: Array[Dictionary] = []
	_sampler = WorkerThreadPool.add_task(func() -> void: result.append(Generator.sample(chosen,{})))
	while not WorkerThreadPool.is_task_completed(_sampler): await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(_sampler)
	_sampler = -1
	var world: Dictionary = result[0]
	sample_ms = (Time.get_ticks_usec()-began)/1000.0
	_preparing = false
	if id != _prepare_id: return
	world["flip_seed"] = chosen
	_prepared = world

var _kept_pending := true
## The worker task writing the kept world beside the places, or -1.
var _writer := -1
## The worker task sampling the next world, or -1.
var _sampler := -1

func _join_writer() -> void:
	if _writer < 0: return
	WorkerThreadPool.wait_for_task_completion(_writer)
	_writer = -1

## Wait for everything the flip has in the background: the kept world's
## write and a world still being sampled. Call before quitting.
func wait_idle() -> void:
	_prepare_id += 1
	_make_id += 1
	while _preparing: await get_tree().process_frame
	_join_writer()

func _exit_tree() -> void:
	_join_writer()
	if _sampler >= 0:
		WorkerThreadPool.wait_for_task_completion(_sampler)
		_sampler = -1

## The world about to be replaced, whole, in memory and beside the places.
func _keep_current() -> void:
	_kept_pending = false
	var began := Time.get_ticks_usec()
	var places: Node = scene.get("places")
	var state := NativeGardenStore.capture(scene)
	var document: Dictionary = editor.data.to_document()
	var label: String = places._label(scene) if places != null else "World"
	kept = {"label":label,"document":document,"state":state}
	var path: String = scene.library_path.path_join("flip-previous.json")
	var payload := {"version":1,"layout":"regrowth","active":0,"slots":[kept]}
	keep_ms = (Time.get_ticks_usec()-began)/1000.0
	# One write at a time, and each is waited for: a pool task nobody joins
	# is torn down mid-flight when the game quits.
	_join_writer()
	_writer = WorkerThreadPool.add_task(func() -> void:
		var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
		if file == null: return
		file.store_string(JSON.stringify(payload))
		file.flush()
		file.close()
		DirAccess.rename_absolute(path+".tmp",path))

## Makes the world that will land, behind the snapshot, while it is thrown.
func _make_world() -> void:
	_make_id += 1
	var id := _make_id
	stamps = {}
	var places: Node = scene.get("places")
	if source != Source.KEPT and _kept_pending: _keep_current()
	_made = true
	_stamp("begun")
	scene.world_play.cancel()
	scene._paused = true
	if places != null:
		places.busy = true
		_look = scene._celestial.look.document()
		_hour = scene._celestial.phase
		_distance = scene.distance
	if scene.has_method("suspend_creation"): scene.suspend_creation()
	var rumble: Node = scene.get("world_rumble")
	if rumble != null: rumble.hold(&"flip",RUMBLE)
	match source:
		Source.NEW:
			await _make_new(id)
		Source.UNDO:
			editor.undo()
			await _settle_editor(id)
		Source.KEPT:
			await _make_kept(id)
	if id != _make_id: return
	_stamp("ready")
	world_ready = true

func _stamp(what: String) -> void:
	stamps[what] = snappedf(making_time,0.01)

func _settle_editor(id: int) -> void:
	await get_tree().process_frame
	while (editor.forming or editor.refresh_pending > 0) and id == _make_id: await get_tree().process_frame
	await get_tree().process_frame

func _make_new(id: int) -> void:
	var places: Node = scene.get("places")
	if _prepared.is_empty():
		_prepare()
		while _prepared.is_empty() and id == _make_id: await get_tree().process_frame
		if id != _make_id: return
	_stamp("sampled")
	_world = _prepared
	_prepared = {}
	_seed = int(_world.get("flip_seed",-1))
	_forming_started = true
	Budget.override_usec = MAKE_BUDGET_USEC
	var began := Time.get_ticks_usec()
	await editor.form_inland(_world.terrain,true,false)
	form_ms = (Time.get_ticks_usec()-began)/1000.0
	Budget.override_usec = 0
	_stamp("formed")
	if id != _make_id: return
	# A step of undo that brings the whole old scene back.
	if not editor.data._undo.is_empty(): editor.data._undo.back()["flip"] = true
	await get_tree().process_frame
	if places != null:
		began = Time.get_ticks_usec()
		places.next_distance = await places._fit_distance(get_tree())
		fit_ms = (Time.get_ticks_usec()-began)/1000.0
		_stamp("fitted")
	await get_tree().process_frame
	if places != null and not bool(scene.get("scenery_mode")):
		var nav_workers: int = scene.navigation.thread_workers
		scene.navigation.thread_workers = 2
		scene._refresh_habitat(true)
		while scene.navigation.rebuilding: await get_tree().process_frame; scene._refresh_habitat(true)
		scene.navigation.thread_workers = nav_workers

func _make_kept(id: int) -> void:
	var places: Node = scene.get("places")
	var document: Dictionary = kept.document
	var now := {"label":places._label(scene) if places != null else "World","document":editor.data.to_document(),"state":NativeGardenStore.capture(scene)}
	editor.data.begin_stroke()
	editor.data._before["favorite_scene"] = now.state
	editor.data.load_document(document)
	editor.data.end_stroke()
	await editor.refresh(get_tree())
	NativeGardenStore.restore(scene,kept.state)
	# What was replaced is kept in turn, so flipping back again undoes this.
	kept = now

## The new world is where the snapshot was: drop the snapshot, fold the land
## down and let it grow, the sky easing over as Regrow's does.
func _reveal() -> void:
	var places: Node = scene.get("places")
	var fresh := source == Source.NEW
	if fresh and places != null:
		Generator.apply_mood(scene,_world)
		places.generated_world = _world
		places.world_seed = _seed
		places.plain = false
		places._sync_plain_day(true)
		places.previous_look = _look
		places.previous_hour = _hour
		places.previous_distance = _distance
		places.next_look = scene._celestial.look.document()
		places.next_hour = scene._celestial.phase
		if places.next_distance <= 0.0: places.next_distance = _distance
		places.phase = "growing"
		places._set_growth(0.0)
		editor.land_seed = _seed
		last_seed = _seed
	_release_world()
	scene._growth.reset_feedback()
	_kept_pending = true
	if fresh and places != null:
		scene._paused = _paused_before
		_made = false
		_grow(places)
	else:
		_settle_scene()
	landed.emit(_seed)

func _grow(places: Node) -> void:
	await places._animate_growth(true,GROW_SECONDS)
	places.generation += 1
	places.phase = "ready"
	places.busy = false
	var rumble: Node = scene.get("world_rumble")
	if rumble != null: rumble.release(&"flip")
	if scene.has_method("resume_creation"): scene.resume_creation()
