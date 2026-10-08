extends "res://scripts/sky_glide.gd"
## The skydive: out of the plane (scripts/sky_plane.gd), down through the
## air, and floating down under a canopy (scripts/wanderer_eye.gd runs it,
## scripts/canopy_figure.gd draws the canopy, scripts/dive_camera.gd
## frames it). Tuned for a toy's feel over a real one's, under the game's
## rules: never death, never a splat, always a way back up.
##
## It goes through its phases in order:
##   POP       out of the cockpit: a small kick up, keeping some of the
##             plane's way, the body tumbling over onto its belly over
##             POP_TIME. Then the fall.
##   FREEFALL  falling belly-down. Gravity against the air's drag holds the
##             fall at its terminal speed, which the posture sets: tucked
##             (Boost) it dives head-down to TERMINAL_TUCK, spread (Brake)
##             it slows to TERMINAL_SPREAD, else TERMINAL. Left and right
##             turn it; forward tracks (flies on over the ground, head
##             lower), back slides it gently backward. The plane's way it
##             kept fades out over GRIP. The wind drifts it a little.
##   OPENING   the canopy out (Open, or by itself, below): it streams and
##             fills over OPEN_TIME; at SNATCH it bites, the fall eases to
##             the canopy's over EASE_OPEN and the body swings upright.
##   CANOPY    floating down at FLY across and SINK down. Left and right
##             steer, forward speeds it up (and it sinks faster), back or
##             Brake slows it (and it floats). The body hangs on its lines
##             and swings: back and forth as it speeds up and slows, out
##             into a turn. Over FLARE_FROM metres off whatever is under it
##             it flares by itself, the sink and the way all but gone, so
##             every landing is soft. The wind carries it, and air rising
##             (a thermal, a ridge) holds it up.
##   DOWN      touched (`touched` on that step): the wanderer takes over.
##
## Nobody splats: falling, the canopy opens by itself AUTO_OPEN metres
## plus AUTO_OPEN_PER seconds of the fall over whatever is under it (the
## ground, an island's top, open water), with time to fill and slow. A
## fall that meets the ground before it has filled (off a cliff's side, say)
## comes down as a bump (`touched.hard`), never a hurt.
##
## Islands are solids as the glide reads them (`ground`: Vector2(top,
## underside) or null): only a top under the body counts as under it; coming
## at an island's side the fall is held off its face. Open water (`water`,
## the lower world's ocean) is a surface to land on too.
##
## Plain state and maths, as the glide is, so tests can step it.

enum {POP,FREEFALL,OPENING,CANOPY,DOWN}
const NAMES := ["pop","freefall","opening","canopy","down"]

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
## The opening: how long the canopy takes to fill (s), the share of that
## at which it bites, and how fast the fall then eases to the canopy's (s).
const OPEN_TIME := 1.1
const SNATCH := 0.4
const EASE_OPEN := 0.3
## Under the canopy: across at rest, full forward and braked (m/s), and
## the sink with each; how fast they follow (s); the turn (radians a
## second at full stick); the share of the wind that carries it; how much
## of the air's rise holds it up.
const FLY := 5.0
const FLY_FAST := 7.5
const FLY_SLOW := 2.4
const SINK_CANOPY := 2.4
const SINK_FAST := 3.6
const SINK_BRAKE := 1.6
const EASE_CANOPY := 0.6
const TURN_CANOPY := 1.2
const WIND_CANOPY := 0.8
const HELD_UP := 0.6
## The flare: from FLARE_FROM metres over the ground it eases in, to a
## sink of FLARE_SINK and a way of FLARE_FLY at the touch.
const FLARE_FROM := 3.2
const FLARE_SINK := 0.45
const FLARE_FLY := 1.4
## Falling, the canopy opens by itself AUTO_OPEN metres plus AUTO_OPEN_PER
## seconds of the fall over what is under it.
const AUTO_OPEN := 12.0
const AUTO_OPEN_PER := 1.0
## The body's hips over its feet (m): `position` is the hips; it touches
## down with the feet.
const HIPS := 0.43
## The swing on the lines: its spring (Hz, damping), how far a turn leans
## it out (radians at full stick) and how far a change of way swings it
## (radians per m/s²).
const SWING_HZ := 0.85
const SWING_DAMP := 0.28
const SWING_TURN := 0.38
const SWING_PUSH := 0.06
## The body's tilt (0 upright, PI/2 belly-down): its spring (Hz, damping),
## the tuck's and the track's extra lean head-down.
const TILT_HZ := 1.6
const TILT_DAMP := 0.55
const TILT_TUCK := 0.7
const TILT_TRACK := 0.3
## The bank in a freefall turn (radians at full stick).
const BANK_FALL := 0.45

var phase := POP
## Seconds in this phase.
var time := 0.0
## -1 spread to 1 tucked, eased; the body's tilt (and its pace), its
## swing on the lines (x back and forth, y side to side, and their pace).
var posture := 0.0
var tilt := 0.0
var _tilt_v := 0.0
var sway := Vector2.ZERO
var _sway_v := Vector2.ZERO
## The canopy: how far filled (0 packed to 1 full, for the drawing), and
## how far into the flare (0 to 1).
var open := 0.0
var flare := 0.0
## True if the canopy opened by itself.
var auto_opened := false
## Metres from the feet down to what is under the body (INF over open air),
## and what that is: "ground" or "water" ("" over open air).
var height := INF
var under := ""
## Set on the step it touches: {top, water, speed, hard}; else empty.
var touched := {}
## The way across the ground (m/s) it falls with, and under the canopy
## its speed along its heading.
var drift := Vector3.ZERO
var _fly := FLY
var _sink := SINK_CANOPY
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

func _begin(from: Vector3, towards: float) -> void:
	position = from
	heading = towards
	pitch = 0.0
	bank = 0.0
	time = 0.0
	airborne = 0.0
	posture = 0.0
	tilt = 0.0
	_tilt_v = 0.0
	sway = Vector2.ZERO
	_sway_v = Vector2.ZERO
	open = 0.0
	flare = 0.0
	auto_opened = false
	height = INF
	under = ""
	touched = {}
	drift = Vector3.ZERO
	_fly = FLY
	_sink = SINK_CANOPY
	_turn_held = 0.0
	velocity = Vector3.ZERO
	speed = 0.0

## Opens the canopy (falling only): `auto` when it opens by itself.
func open_canopy(auto := false) -> bool:
	if phase != POP and phase != FREEFALL: return false
	phase = OPENING
	time = 0.0
	auto_opened = auto
	return true

## True falling without the canopy (popping out or in freefall).
func falling() -> bool:
	return phase == POP or phase == FREEFALL

## True under the canopy (opening or open).
func under_canopy() -> bool:
	return phase == OPENING or phase == CANOPY

## The height at which a fall this fast opens by itself.
func auto_height() -> float:
	return AUTO_OPEN+AUTO_OPEN_PER*maxf(-velocity.y,0.0)

## One step. `input` holds turn and pitch (-1..1 held, right and back
## positive: forward on the stick is -1), boost and brake (0..1), and open
## (true on the frame the canopy is asked for). `ground` and `air` as for
## the glide. Returns what happened: "opened" (the canopy bit), "auto"
## (it opened by itself this step), "touched" (as `touched`).
func fall(delta: float, input: Dictionary, ground: Callable, air := Callable()) -> Dictionary:
	var out := {}
	touched = {}
	if phase == DOWN or delta <= 0.0: return out
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
	if input.get("open",false): open_canopy()
	_turn_held = lerpf(_turn_held,turn,_ease(0.2,delta))
	_probe(ground)
	# Nobody splats: the canopy opens by itself in time.
	if falling() and height < auto_height() and open_canopy(true): out["auto"] = true
	match phase:
		POP,FREEFALL: _freefall(delta,turn,stick,boost,brake)
		OPENING,CANOPY: _canopy(delta,turn,stick,brake,out)
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
	posture = lerpf(posture,boost-brake,_ease(EASE_POSTURE,delta))
	var terminal := lerpf(TERMINAL,TERMINAL_TUCK,posture) if posture > 0.0 else lerpf(TERMINAL,TERMINAL_SPREAD,-posture)
	var drag := GRAVITY*(velocity.y/terminal)*(velocity.y/terminal)
	drag = minf(drag,GRAVITY*DRAG_MOST)
	velocity.y += (-GRAVITY+(drag if velocity.y < 0.0 else -drag))*delta
	heading += -turn*TURN_FALL*delta
	var forward := Vector3(-sin(heading),0.0,-cos(heading))
	var track := maxf(-stick,0.0)
	var want := forward*(TRACK*track-BACKSLIDE*maxf(stick,0.0))+Vector3(wind.x,0.0,wind.z)*WIND_FALL
	drift = drift.lerp(want,_ease(GRIP,delta))
	velocity.x = drift.x
	velocity.z = drift.z
	bank = lerpf(bank,-turn*BANK_FALL,_ease(0.25,delta))
	var goal := PI*0.5+maxf(posture,0.0)*TILT_TUCK+track*TILT_TRACK
	_tilt_to(goal,delta)
	sway = sway.lerp(Vector2.ZERO,_ease(0.3,delta))

## Under the canopy: the opening's bite, the way and the sink, the swing,
## and the flare.
func _canopy(delta: float, turn: float, stick: float, brake: float, out: Dictionary) -> void:
	if phase == OPENING:
		open = clampf(time/OPEN_TIME,0.0,1.0)
		if time >= OPEN_TIME:
			phase = CANOPY
			time = 0.0
			open = 1.0
	else:
		open = 1.0
	var bitten := phase == CANOPY or time >= OPEN_TIME*SNATCH
	if phase == OPENING and time-delta < OPEN_TIME*SNATCH and bitten:
		out["opened"] = true
		# The snatch swings the body forward under the canopy.
		_sway_v.x += 2.2
	var forward := Vector3(-sin(heading),0.0,-cos(heading))
	if not bitten:
		# Streaming out: still falling, a little slower.
		velocity.y = move_toward(velocity.y,-TERMINAL*0.8,GRAVITY*delta)
		drift = drift.lerp(Vector3.ZERO,_ease(GRIP,delta))
		velocity.x = drift.x
		velocity.z = drift.z
		_tilt_to(PI*0.5,delta)
		return
	heading += -turn*TURN_CANOPY*delta
	var ahead := maxf(-stick,0.0)
	var slow := maxf(maxf(stick,0.0),brake)
	var fly := FLY+(FLY_FAST-FLY)*ahead-(FLY-FLY_SLOW)*slow
	var sink := SINK_CANOPY+(SINK_FAST-SINK_CANOPY)*ahead-(SINK_CANOPY-SINK_BRAKE)*slow
	# The flare: by itself over the ground, all of it by the touch.
	var want_flare := 0.0
	if under != "": want_flare = 1.0-smoothstep(0.15,FLARE_FROM,height)
	flare = lerpf(flare,want_flare,_ease(0.1,delta))
	var was_fly := _fly
	_fly = lerpf(_fly,fly,_ease(EASE_CANOPY,delta))
	_sink = lerpf(_sink,sink,_ease(EASE_CANOPY,delta))
	var rise := clampf(wind.y,0.0,4.0)*HELD_UP*(1.0-flare)
	var flown := lerpf(_fly,FLARE_FLY,flare)
	var sunk := lerpf(_sink,FLARE_SINK,flare)
	var target := forward*flown+Vector3(wind.x,0.0,wind.z)*WIND_CANOPY*(1.0-flare*0.7)+Vector3.DOWN*(sunk-rise)
	var k := _ease(EASE_OPEN,delta) if phase == OPENING else 1.0
	velocity = velocity.lerp(target,k)
	drift = Vector3(velocity.x,0.0,velocity.z)
	bank = lerpf(bank,-_turn_held*SWING_TURN,_ease(0.3,delta))
	# The swing on its lines: pushed back and forth by the change of way,
	# out into a turn.
	var push := (_fly-was_fly)/delta if delta > 0.0 else 0.0
	_sway_v.x += -push*SWING_PUSH
	var goal := Vector2(0.0,-_turn_held*SWING_TURN)
	var w := TAU*SWING_HZ
	_sway_v += (w*w*(goal-sway)-2.0*SWING_DAMP*w*_sway_v)*delta
	sway += _sway_v*delta
	sway = sway.clamp(Vector2(-0.7,-0.7),Vector2(0.7,0.7))
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
	if body != Vector2.INF and position.y > body.y:
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
			# At its side, under its rim: held off the face, falling on.
			position.x = was.x
			position.z = was.z
			drift = Vector3.ZERO
			velocity.x = 0.0
			velocity.z = 0.0
			return
		top = body.x
	if is_finite(water) and water > top:
		top = water
		on_water = true
	if feet > top: return
	var hard := not under_canopy() or (phase == OPENING and time < OPEN_TIME*SNATCH)
	touched = {"top":top,"water":on_water,"speed":velocity.length(),"hard":hard}
	out["touched"] = touched
	position.y = top+HIPS
	phase = DOWN
	time = 0.0

## The lines' frame: turned to the heading and swung on the lines, up
## along them from the pilot to the canopy.
func line_basis() -> Basis:
	return Basis(Vector3.UP,heading)*Basis(Vector3.RIGHT,sway.x)*Basis(Vector3.BACK,sway.y)

## The body's frame: on its lines, banked in a freefall turn and tipped
## over by its tilt (onto the belly at PI/2, the head forward).
func body_basis() -> Basis:
	return line_basis()*Basis(Vector3.BACK,bank*(1.0-open))*Basis(Vector3.RIGHT,-tilt)
