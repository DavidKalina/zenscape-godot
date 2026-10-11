extends "res://scripts/sky_glide.gd"
## The skydive: out of the plane (scripts/sky_plane.gd), or off an island's
## edge on foot, down through the air, and coasting on the pocket sail
## (scripts/pocket_sail.gd, the walker's own, drawn by
## scripts/pocket_sail_figure.gd); scripts/wanderer_eye.gd runs it and
## scripts/dive_camera.gd frames it. Tuned for a toy's feel over a real
## one's, under the game's rules: never death, never a splat, always a way
## back up.
##
## It goes through its phases:
##   POP       out of the cockpit: a small kick up, keeping some of the
##             plane's way, the body tumbling over onto its belly over
##             POP_TIME. Then the fall.
##   FREEFALL  falling, belly-down out of the plane (upright off an edge on
##             foot, `upright`). Gravity against the air's drag holds the
##             fall at its terminal speed, which the posture sets: tucked
##             (Boost) it dives head-down to TERMINAL_TUCK, spread (Brake)
##             it slows to TERMINAL_SPREAD, else TERMINAL. Left and right
##             turn it; forward tracks (flies on over the ground, head
##             lower), back slides it gently backward. The plane's way it
##             kept fades out over GRIP. The wind drifts it a little.
##   SAIL      Jump (`open`) pops the pocket sail out overhead: its kick the
##             first time (once a dive), then it coasts down slowly, steered
##             with left and right, forward diving it faster, back or Brake
##             floating it; the wind carries it and air rising holds it up,
##             as the walker's does (the same maths, the same sail). Jump
##             again folds it, back to the fall; opened again, no kick.
##   DOWN      touched (`touched` on that step): the wanderer takes over.
##
## Nothing opens by itself: not opened, the fall comes down as a bump
## (`touched.hard`), never a hurt; under the sail falling slower than
## SOFT it is a soft touch.
##
## Islands are solids as the glide reads them (`ground`: Vector2(top,
## underside) or null): only a top under the body counts as under it; coming
## at an island's side the fall is held off its face. Open water (`water`,
## the lower world's ocean) is a surface to land on too.
##
## Plain state and maths, as the glide is, so tests can step it.

enum {POP,FREEFALL,SAIL,DOWN}
const NAMES := ["pop","freefall","sail","down"]
const PocketSail = preload("res://scripts/pocket_sail.gd")

## Gravity (m/s², a toy's: snappier than the world's), and the terminal
## speeds of the fall (m/s): belly-down, tucked and spread. The drag
## that holds them never pulls harder than DRAG_MOST gravities.
const GRAVITY := 13.0
const TERMINAL := 17.0
const TERMINAL_TUCK := 34.0
const TERMINAL_SPREAD := 9.5
const DRAG_MOST := 4.0
## How fast the posture follows Boost and Brake (s).
const EASE_POSTURE := 0.35
## The fall across the ground: tracking forward's speed and sliding back's
## (m/s), how fast the way across follows (s), the turn (radians a second
## at full stick), and the share of the wind that drifts it.
const TRACK := 8.0
const BACKSLIDE := 2.5
const GRIP := 0.9
const TURN_FALL := 2.4
const WIND_FALL := 0.35
## The pop: the kick up and back (m/s), the share of the plane's way it
## keeps, and the tumble onto the belly (s).
const POP_UP := 5.5
const POP_BACK := 1.5
const KEEP := 0.6
const POP_TIME := 0.6
## Under the sail: touching down slower than this (m/s down) is soft.
const SOFT := 4.0
## The body's lean forward falling upright off an edge (radians).
const UPRIGHT_LEAN := 0.2
## The body's hips over its feet (m): `position` is the hips; it touches
## down with the feet.
const HIPS := 0.43
## The body's tilt (0 upright, PI/2 belly-down): its spring (Hz, damping),
## the tuck's and the track's extra lean head-down.
const TILT_HZ := 1.6
const TILT_DAMP := 0.55
const TILT_TUCK := 0.7
const TILT_TRACK := 0.3
## The bank in a freefall turn and under the sail (radians at full stick).
const BANK_FALL := 0.45
const BANK_SAIL := 0.3

var phase := POP
## Seconds in this phase.
var time := 0.0
## The fall's gravity and terminal speed (the toy's; off an edge on foot,
## the walker's), and whether it falls upright (off an edge) or belly-down.
var gravity := GRAVITY
var terminal := TERMINAL
var upright := false
## -1 spread to 1 tucked, eased; the body's tilt (and its pace).
var posture := 0.0
var tilt := 0.0
var _tilt_v := 0.0
## The pocket sail (the walker's own, handed over off an edge, so its kick
## spent stays spent), and how far out it is drawn (0 packed to 1 out).
var sail := PocketSail.new()
var open := 0.0
## Metres from the feet down to what is under the body (INF over open air),
## and what that is: "ground" or "water" ("" over open air).
var height := INF
var under := ""
## Set on the step it touches: {top, water, speed, hard}; else empty.
var touched := {}
## The way across the ground (m/s) it falls with.
var drift := Vector3.ZERO
var _turn_held := 0.0

## Out of the plane at `from` (the cockpit, global), the plane flying at
## `plane_velocity` facing `towards` (the scene's yaw).
func eject(from: Vector3, plane_velocity: Vector3, towards: float) -> void:
	_begin(from,towards)
	phase = POP
	var back := Vector3(sin(towards),0.0,cos(towards))
	velocity = plane_velocity*KEEP+Vector3.UP*POP_UP+back*POP_BACK
	drift = Vector3(velocity.x,0.0,velocity.z)

## Falling from `from` already, belly-down, at `fall` m/s (a test, or
## `--skydive=fall`).
func drop(from: Vector3, towards: float, fall := TERMINAL) -> void:
	_begin(from,towards)
	phase = FREEFALL
	tilt = PI*0.5
	velocity = Vector3.DOWN*fall

## Off an edge on foot at `from` (the hips), moving at `moving`, facing
## `towards`: upright, under the walker's gravity and fastest fall, with
## the walker's sail (open still if it is, its kick spent if it was).
func step_off(from: Vector3, moving: Vector3, towards: float, walker_sail: RefCounted, walker_gravity: float, walker_terminal: float) -> void:
	_begin(from,towards)
	phase = FREEFALL
	upright = true
	gravity = walker_gravity
	terminal = walker_terminal
	velocity = moving
	drift = Vector3(moving.x,0.0,moving.z)
	if walker_sail != null: sail = walker_sail
	sail.peak = maxf(sail.peak,from.y-HIPS)
	if sail.open:
		phase = SAIL
		open = 1.0
		heading = sail.heading

func _begin(from: Vector3, towards: float) -> void:
	position = from
	heading = towards
	pitch = 0.0
	bank = 0.0
	time = 0.0
	airborne = 0.0
	gravity = GRAVITY
	terminal = TERMINAL
	upright = false
	posture = 0.0
	tilt = 0.0
	_tilt_v = 0.0
	sail = PocketSail.new()
	sail.rest()
	sail.peak = from.y-HIPS
	open = 0.0
	height = INF
	under = ""
	touched = {}
	drift = Vector3.ZERO
	_turn_held = 0.0
	velocity = Vector3.ZERO
	speed = 0.0

## Opens the sail (falling, with room under it): true if it opened.
func open_sail() -> bool:
	if not falling() or not sail.can_open(height,velocity.y): return false
	phase = SAIL
	time = 0.0
	velocity = sail.deploy(velocity,heading,position.y-HIPS)
	heading = sail.heading
	drift = Vector3(velocity.x,0.0,velocity.z)
	return true

## Folds the sail: falling again.
func fold_sail() -> bool:
	if phase != SAIL: return false
	phase = FREEFALL
	time = 0.0
	sail.fold()
	return true

## True falling without the sail (popping out or in freefall).
func falling() -> bool:
	return phase == POP or phase == FREEFALL

## True under the sail.
func sailing() -> bool:
	return phase == SAIL

## One step. `input` holds turn and pitch (-1..1 held, right and back
## positive: forward on the stick is -1), boost and brake (0..1), and open
## (true on the frame Jump is pressed: the sail opened, or folded). `ground`
## and `air` as for the glide. Returns what happened: "opened" or "folded"
## (the sail), "touched" (as `touched`).
func fall(delta: float, input: Dictionary, ground: Callable, air := Callable()) -> Dictionary:
	var out := {}
	touched = {}
	if phase == DOWN or delta <= 0.0: return out
	# In steps of at most STEP, so a long frame never throws the springs.
	var steps := ceili(delta/STEP)
	for i in range(steps):
		var one := _fall(delta/steps,input if i == 0 else _held(input),ground,air)
		out.merge(one,true)
		if phase == DOWN: break
	return out

## The longest step the dive takes at once (s).
const STEP := 1.0/90.0

## `input` as held on: the open asked once, not again.
static func _held(input: Dictionary) -> Dictionary:
	var held := input.duplicate()
	held["open"] = false
	return held

func _fall(delta: float, input: Dictionary, ground: Callable, air: Callable) -> Dictionary:
	var out := {}
	airborne += delta
	time += delta
	var here: Dictionary = air.call(position) if air.is_valid() else {}
	wind = here.get("wind",Vector3.ZERO)
	in_jet = float(here.get("jet",0.0))
	in_thermal = float(here.get("thermal",0.0))
	var turn := clampf(float(input.get("turn",0.0)),-1.0,1.0)
	var stick := clampf(float(input.get("pitch",0.0)),-1.0,1.0)
	var boost := clampf(float(input.get("boost",0.0)),0.0,1.0)
	var brake := clampf(float(input.get("brake",0.0)),0.0,1.0)
	_turn_held = lerpf(_turn_held,turn,_ease(0.2,delta))
	_probe(ground)
	if input.get("open",false):
		if phase == SAIL:
			if fold_sail(): out["folded"] = true
		elif open_sail(): out["opened"] = true
	match phase:
		POP,FREEFALL: _freefall(delta,turn,stick,boost,brake)
		SAIL: _sail(delta,turn,stick,brake,here)
	open = move_toward(open,1.0 if phase == SAIL else 0.0,delta/0.15)
	speed = velocity.length()
	var flat := Vector2(velocity.x,velocity.z).length()
	pitch = atan2(velocity.y,maxf(flat,0.001))
	var was := position
	position += velocity*delta
	_land(ground,was,out)
	return out

## Falling: the posture, the drag, the way across and the tumble.
func _freefall(delta: float, turn: float, stick: float, boost: float, brake: float) -> void:
	if phase == POP and time >= POP_TIME:
		phase = FREEFALL
		time = 0.0
	sail.track(position.y-HIPS,delta)
	posture = lerpf(posture,boost-brake,_ease(EASE_POSTURE,delta))
	var scale := terminal/TERMINAL
	var most := lerpf(terminal,TERMINAL_TUCK*scale,posture) if posture > 0.0 else lerpf(terminal,TERMINAL_SPREAD*scale,-posture)
	var drag := gravity*(velocity.y/most)*(velocity.y/most)
	drag = minf(drag,gravity*DRAG_MOST)
	velocity.y += (-gravity+(drag if velocity.y < 0.0 else -drag))*delta
	heading += -turn*TURN_FALL*delta
	var forward := Vector3(-sin(heading),0.0,-cos(heading))
	var track := maxf(-stick,0.0)
	var want := forward*(TRACK*track-BACKSLIDE*maxf(stick,0.0))+Vector3(wind.x,0.0,wind.z)*WIND_FALL
	if upright:
		# Off an edge on foot the run is kept, as the walker's fall keeps it.
		want += drift*(1.0-track)
		drift = drift.lerp(want,_ease(GRIP*4.0,delta))
	else:
		drift = drift.lerp(want,_ease(GRIP,delta))
	velocity.x = drift.x
	velocity.z = drift.z
	bank = lerpf(bank,-turn*BANK_FALL,_ease(0.25,delta))
	var goal := UPRIGHT_LEAN+track*TILT_TRACK if upright else PI*0.5+maxf(posture,0.0)*TILT_TUCK+track*TILT_TRACK
	_tilt_to(goal,delta)

## Under the sail: the walker's sail flown with the dive's keys (left and
## right steer, forward dives it, back or Brake floats it).
func _sail(delta: float, turn: float, stick: float, brake: float, here: Dictionary) -> void:
	var push := clampf(-stick-brake,-1.0,1.0)
	velocity = sail.step(delta,velocity,position.y-HIPS,-turn,push,here)
	heading = sail.heading
	drift = Vector3(velocity.x,0.0,velocity.z)
	bank = lerpf(bank,-_turn_held*BANK_SAIL,_ease(0.3,delta))
	_tilt_to(0.0,delta)

func _tilt_to(goal: float, delta: float) -> void:
	var w := TAU*TILT_HZ
	_tilt_v += (w*w*(goal-tilt)-2.0*TILT_DAMP*w*_tilt_v)*delta
	tilt += _tilt_v*delta

## What is under the body now: the top of an island under it (not one it
## is under), or open water, whichever is higher.
func _probe(ground: Callable) -> void:
	height = INF
	under = ""
	var feet := position.y-HIPS
	var body := _solid(ground,position)
	# (Not a top over the feet: beside a cliff the land under it is lower.)
	if body != Vector2.INF and position.y > body.y and feet >= body.x-LIP:
		height = feet-body.x
		under = "ground"
	if is_finite(water) and feet-water < height:
		height = feet-water
		under = "water"

## Touching down, or held off an island's side.
func _land(ground: Callable, was: Vector3, out: Dictionary) -> void:
	var body := _solid(ground,position)
	var feet := position.y-HIPS
	var top := -INF
	var on_water := false
	if body != Vector2.INF and position.y > body.y-CLEAR:
		var before := _solid(ground,was)
		if feet < body.x and (before == Vector2.INF or was.y-HIPS < before.x-LIP) and was.y > body.y:
			# At its side, under its rim: held off the face, falling on (onto
			# the water at its foot, if any).
			position.x = was.x
			position.z = was.z
			drift = Vector3.ZERO
			velocity.x = 0.0
			velocity.z = 0.0
			sail.speed = 0.0
			sail.drift = Vector2.ZERO
		else:
			top = body.x
	if is_finite(water) and water > top:
		top = water
		on_water = true
	if feet > top: return
	var hard := not sailing() or -velocity.y > SOFT
	touched = {"top":top,"water":on_water,"speed":velocity.length(),"hard":hard}
	out["touched"] = touched
	position.y = top+HIPS
	sail.rest()
	phase = DOWN
	time = 0.0

## The body's frame: turned to the heading, banked in a turn and tipped
## over by its tilt (onto the belly at PI/2, the head forward).
func body_basis() -> Basis:
	return Basis(Vector3.UP,heading)*Basis(Vector3.BACK,bank)*Basis(Vector3.RIGHT,-tilt)
