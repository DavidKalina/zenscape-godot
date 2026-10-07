extends RefCounted
## A rope bridge's life (scripts/footbridge.gd draws it, scripts/rope_bridge.gd
## runs it): how far its deck and hand ropes stand off their static sag pose
## (Footbridge `lift`) as the pilot crosses, the wind pushes and a plane
## roars past. Never the pose itself: every number here is a displacement
## from it, so at rest the bridge is exactly the static one, a far bridge
## fades back into it by its displacement easing to nothing, and the walker
## reads the deck as the static height plus `drop`.
##
## Four ropes, each a string of NODES+1 points pinned at both ends and
## stepped as a damped wave on a string (a fixed sub-step, deterministic,
## unconditionally tame at these numbers): the two foot ropes under the
## planks' ends, moving up and down on their own (the planks between them
## roll as one sinks under a foot set off the middle) and side to side
## together (the planks hold them a deck's width apart); the two hand ropes
## above, pulled after the deck by the cords and blown on their own. Tuned
## by frequencies and by how far things move, not by masses: BOUNCE_HZ is
## the deck's first up-and-down beat, SAG_UNDER how far the pilot standing at
## the middle sinks it, and so on, whatever the span.
##
## What moves it: `load` (the weight stood on it, each frame), `kick` (a
## footfall's or a landing's push, once), `wind` (the air across and along
## it, each frame), `shudder` (a plane gone by). `step` advances it;
## `drop` / `sway` / `offset` read it back; `pack` writes it for the shader
## (shaders/rope_bridge.gdshader).

## Segments along a rope: about one per SEG m, between NODES_MIN and
## NODES_MAX (the shader holds NODES_MAX+1 samples).
const SEG := 0.55
const NODES_MIN := 10
const NODES_MAX := 32
## The fixed sub-step (s), and the most sub-steps one frame may take (a
## hitch past that is let go rather than caught up).
const DT := 1.0/120.0
const MAX_SUBSTEPS := 8
## The deck's first beats (Hz): up and down, side to side; the hand ropes'
## side to side; the planks' roll (the two foot ropes against each other).
const BOUNCE_HZ := 1.15
const SWAY_HZ := 0.62
const HAND_SWAY_HZ := 0.8
const ROLL_HZ := 2.6
## How quickly a swing dies (1/s on its speed: e^(-DAMP t/2) on its size), a
## little more on the sway; the spread of a bend along the rope damped too
## (m²/s, keeps the higher beats from fizzing).
const DAMP := 1.05
const SWAY_DAMP := 0.8
const SMOOTH := 0.35
## The hand ropes: how far they follow the deck's dip (share) and how stiffly
## the cords pull them after it (Hz).
const HAND_FOLLOW := 0.55
const CORD_HZ := 2.2
## The pilot stood at the middle sinks the deck this far (m); off the middle
## less, as a string does (4 t (1-t) of it), and one foot rope more than the
## other stood off to a side.
const SAG_UNDER := 0.17
## A footfall's push down (m/s at the feet, at a walk and at a full run), a
## landing's (m/s at the feet per m/s fallen, and the most). Each push is
## part the whole span's bounce (BROAD of it, in the shape the weight sinks
## it, so the deck rides down and springs back like a trampoline's bed) and
## the rest a ripple KICK_SPREAD m either side running off to the ends. A
## step pushes the deck a little sideways too, left foot then right (share
## of its push).
const STEP_KICK := Vector2(0.14,0.36)
const LAND_KICK := 0.15
const LAND_MOST := 2.0
const KICK_SPREAD := 0.9
const STEP_BROAD := 0.55
const LAND_BROAD := 0.8
const STEP_SWAY := 0.45
## The wind (m/s across the span) bows the deck sideways this far at the
## middle per m/s, at most SWAY_MOST m; the hand ropes, out in it, more.
## The push breathes (WIND_BREATH of it at about the sway's beat) so a steady
## wind still swings it; along the span a little of it lifts and drops the
## deck in a see-saw (WIND_LIFT of the push).
const SWAY_PER_WIND := 0.05
const SWAY_MOST := 0.3
const HAND_WIND := 1.6
const WIND_BREATH := 0.45
const WIND_LIFT := 0.2
## A plane gone by: the shudder's rate (Hz), how long it rings (s, e-folding)
## and its push per unit (m/s²).
const SHUDDER_HZ := 7.5
const SHUDDER_RING := 0.5
const SHUDDER_PUSH := 6.0
## No displacement or speed over this (m, m/s) anywhere, and nothing on it:
## asleep, all zero, the static bridge.
const REST := 0.0015
## Displacements are held within these (m): a guard, never reached in play.
const MOST := Vector2(0.9,0.7)

## The span (m, flat), the deck's width (m), and the segments.
var span := 10.0
var width := 0.74
var nodes := NODES_MIN
## Per point (0 to `nodes`): the foot ropes' drop (left, right; m, up
## positive), the deck's sideways shift (m, toward +across), the hand ropes'
## (drop left, right; shift left, right); and the speeds of each.
var yl := PackedFloat32Array()
var yr := PackedFloat32Array()
var x := PackedFloat32Array()
var hyl := PackedFloat32Array()
var hyr := PackedFloat32Array()
var hxl := PackedFloat32Array()
var hxr := PackedFloat32Array()
var vyl := PackedFloat32Array()
var vyr := PackedFloat32Array()
var vx := PackedFloat32Array()
var vhyl := PackedFloat32Array()
var vhyr := PackedFloat32Array()
var vhxl := PackedFloat32Array()
var vhxr := PackedFloat32Array()
## True while it moves (false: all zero, `step` does nothing until pushed).
var awake := false
## Seconds it has run (the wind's breath and the shudder read it).
var clock := 0.0
## A plank rattle's size now (m), from how fast the deck moves.
var rattle := 0.0
var _phase := 0.0
var _left := 0.0
var _shudder := 0.0
var _loads: Array[Vector3] = []
var _wind := Vector2.ZERO
var _fade := 0.0
var _c2y := 0.0
var _c2x := 0.0
var _c2h := 0.0
var _roll := 0.0
var _cord := 0.0
var _h := 1.0

## A bridge `span` m long and `width` wide; `seed_value` sets its wind's
## own breath.
func _init(span_m := 10.0, width_m := 0.74, seed_value := 0) -> void:
	span = maxf(span_m,1.0)
	width = width_m
	nodes = clampi(roundi(span/SEG),NODES_MIN,NODES_MAX)
	_h = span/nodes
	# A pinned string's first beat is c/(2L): c from the beat wanted.
	_c2y = pow(2.0*span*BOUNCE_HZ,2.0)
	_c2x = pow(2.0*span*SWAY_HZ,2.0)
	_c2h = pow(2.0*span*HAND_SWAY_HZ,2.0)
	# The roll: the two foot ropes against each other, k on each (ω² = 2k).
	_roll = pow(TAU*ROLL_HZ,2.0)*0.5
	_cord = pow(TAU*CORD_HZ,2.0)
	_phase = float(posmod(seed_value*7919,6283))*0.001
	for a: PackedFloat32Array in _arrays():
		a.resize(nodes+1)
		a.fill(0.0)

func _arrays() -> Array[PackedFloat32Array]:
	return [yl,yr,x,hyl,hyr,hxl,hxr,vyl,vyr,vx,vhyl,vhyr,vhxl,vhxr]

# --- What moves it --------------------------------------------------------------

## Weight stood on the deck this frame at `t` (0 one end, 1 the other) and
## `side` (m off the middle line, toward +across), `share` of the pilot's.
## Held until the next `step`.
func load(t: float, side: float, share := 1.0) -> void:
	_loads.append(Vector3(t,side,share))
	awake = true

## A push down at `t`, `side` of `speed` m/s at the feet (up is negative),
## and `lateral` m/s sideways: `broad` of it over the whole span (the shape
## a weight at `t` sinks it in), the rest a ripple KICK_SPREAD m along.
func kick(t: float, side: float, speed: float, lateral := 0.0, broad := 0.0) -> void:
	var w := _sides(side)
	var at := clampf(t,0.02,0.98)
	for i in range(1,nodes):
		var u := float(i)/nodes
		var d := (u-t)*span
		var tent := u/at if u < at else (1.0-u)/(1.0-at)
		var k := lerpf(exp(-d*d/(KICK_SPREAD*KICK_SPREAD)),tent,broad)
		if k < 0.01: continue
		vyl[i] -= speed*k*w.x*2.0
		vyr[i] -= speed*k*w.y*2.0
		vx[i] += lateral*k
	awake = true

## A footfall at `t`, `side`: `effort` 0 at a walk to 1 at a run; `foot` 0
## the left, 1 the right (the deck is pushed a little the other way).
func step_on(t: float, side: float, effort: float, foot: int) -> void:
	var push := lerpf(STEP_KICK.x,STEP_KICK.y,clampf(effort,0.0,1.0))
	kick(t,side,push,push*STEP_SWAY*(1.0 if foot == 0 else -1.0),STEP_BROAD)

## Landed on it at `t`, `side`, fallen at `speed` m/s.
func land(t: float, side: float, speed: float) -> void:
	kick(t,side,minf(speed*LAND_KICK,LAND_MOST),0.0,LAND_BROAD)

## The air over the bridge this frame: `across` m/s (toward +across) and
## `along` (m/s along the span), gusts and all. Held until changed.
func wind(across: float, along := 0.0) -> void:
	_wind = Vector2(across,along)
	if absf(across) > 0.05: awake = true

## A plane gone by: `strength` 0 (far, slow) to 1 (close and fast).
func shudder(strength: float) -> void:
	if strength <= 0.0: return
	_shudder = maxf(_shudder,clampf(strength,0.0,1.5))
	awake = true

# --- Stepping ---------------------------------------------------------------------

## Advance `delta` s. `fade` 0 lets it live; toward 1 (far off) its swing
## dies quicker, so a bridge left behind eases back into its static pose.
func step(delta: float, fade := 0.0) -> void:
	_fade = clampf(fade,0.0,1.0)
	if not awake:
		_loads.clear()
		return
	_left = minf(_left+delta,DT*MAX_SUBSTEPS)
	while _left >= DT:
		_left -= DT
		_substep()
	_loads.clear()
	_check_rest()

func _substep() -> void:
	clock += DT
	var inv_h2 := 1.0/(_h*_h)
	var damp := DAMP+_fade*6.0
	var sway_damp := SWAY_DAMP+_fade*6.0
	var live := 1.0-_fade
	# The loads, onto the nodes (a force per node, m/s²).
	var fl := PackedFloat32Array()
	var fr := PackedFloat32Array()
	fl.resize(nodes+1)
	fr.resize(nodes+1)
	# Each rope, under half the load, deflects SAG_UNDER at the middle: a
	# point force a = 4 δ c² / (L h) on a string pinned at both ends.
	var unit := 8.0*SAG_UNDER*_c2y/(span*_h)
	for l: Vector3 in _loads:
		var w := _sides(l.y)
		var at := clampf(l.x,0.0,1.0)*nodes
		var i := mini(floori(at),nodes-1)
		var f := at-i
		var push := unit*l.z*live
		fl[i] -= push*w.x*(1.0-f)
		fl[i+1] -= push*w.x*f
		fr[i] -= push*w.y*(1.0-f)
		fr[i+1] -= push*w.y*f
	# The wind: a uniform push bowing the deck sideways δ at the middle,
	# a = 8 δ c² / L², breathing, a little see-saw up and down along it.
	var breath := 1.0+WIND_BREATH*(0.65*sin(TAU*SWAY_HZ*0.93*clock+_phase)+0.35*sin(TAU*SWAY_HZ*2.31*clock+_phase*2.7))
	var bow := clampf(_wind.x*SWAY_PER_WIND,-SWAY_MOST,SWAY_MOST)*breath*live
	var wind_x := 8.0*bow*_c2x/(span*span)
	var wind_h := 8.0*bow*HAND_WIND*_c2h/(span*span)
	var lift := wind_x*WIND_LIFT*(0.5+0.5*sin(TAU*BOUNCE_HZ*0.8*clock+_phase*1.9))
	var shake := 0.0
	if _shudder > 0.001:
		shake = _shudder*SHUDDER_PUSH*live
		_shudder *= exp(-DT/SHUDDER_RING)
	var gl := 0.0
	var gr := 0.0
	for i in range(1,nodes):
		var u := float(i)/nodes
		# Foot ropes: the string, the bend's own damping, the roll pulling
		# them together, the load, the wind's see-saw, a shudder.
		var lap_l := (yl[i-1]-2.0*yl[i]+yl[i+1])*inv_h2
		var lap_r := (yr[i-1]-2.0*yr[i]+yr[i+1])*inv_h2
		var lap_vl := (vyl[i-1]-2.0*vyl[i]+vyl[i+1])*inv_h2
		var lap_vr := (vyr[i-1]-2.0*vyr[i]+vyr[i+1])*inv_h2
		var saw := lift*sin(TAU*u)
		var jolt := shake*sin(TAU*SHUDDER_HZ*clock+u*9.0+_phase)
		gl = _c2y*lap_l+SMOOTH*lap_vl-damp*vyl[i]+_roll*(yr[i]-yl[i])+fl[i]+saw+jolt
		gr = _c2y*lap_r+SMOOTH*lap_vr-damp*vyr[i]+_roll*(yl[i]-yr[i])+fr[i]+saw+jolt*0.8
		vyl[i] += gl*DT
		vyr[i] += gr*DT
		# The deck sideways, as one.
		var lap_x := (x[i-1]-2.0*x[i]+x[i+1])*inv_h2
		var lap_vx := (vx[i-1]-2.0*vx[i]+vx[i+1])*inv_h2
		vx[i] += (_c2x*lap_x+SMOOTH*lap_vx-sway_damp*vx[i]+wind_x+jolt*0.5)*DT
		# The hand ropes: their own string, drawn after the deck by the
		# cords, blown more.
		var hl := (hyl[i-1]-2.0*hyl[i]+hyl[i+1])*inv_h2
		var hr := (hyr[i-1]-2.0*hyr[i]+hyr[i+1])*inv_h2
		vhyl[i] += (_c2h*hl+_cord*(yl[i]*HAND_FOLLOW-hyl[i])-damp*vhyl[i])*DT
		vhyr[i] += (_c2h*hr+_cord*(yr[i]*HAND_FOLLOW-hyr[i])-damp*vhyr[i])*DT
		var sl := (hxl[i-1]-2.0*hxl[i]+hxl[i+1])*inv_h2
		var sr := (hxr[i-1]-2.0*hxr[i]+hxr[i+1])*inv_h2
		vhxl[i] += (_c2h*sl+_cord*(x[i]-hxl[i])-sway_damp*vhxl[i]+wind_h)*DT
		vhxr[i] += (_c2h*sr+_cord*(x[i]-hxr[i])-sway_damp*vhxr[i]+wind_h)*DT
	# Positions after speeds (semi-implicit), held in the guard.
	var speed := 0.0
	for i in range(1,nodes):
		yl[i] = clampf(yl[i]+vyl[i]*DT,-MOST.x,MOST.x)
		yr[i] = clampf(yr[i]+vyr[i]*DT,-MOST.x,MOST.x)
		x[i] = clampf(x[i]+vx[i]*DT,-MOST.y,MOST.y)
		hyl[i] = clampf(hyl[i]+vhyl[i]*DT,-MOST.x,MOST.x)
		hyr[i] = clampf(hyr[i]+vhyr[i]*DT,-MOST.x,MOST.x)
		hxl[i] = clampf(hxl[i]+vhxl[i]*DT,-MOST.y,MOST.y)
		hxr[i] = clampf(hxr[i]+vhxr[i]*DT,-MOST.y,MOST.y)
		speed = maxf(speed,absf(vyl[i])+absf(vyr[i]))
	rattle = clampf((speed-0.15)*0.012,0.0,0.012)

## Asleep once nothing stands on it, no wind pushes and it has come to rest:
## zeroed, so it is the static bridge again exactly.
func _check_rest() -> void:
	if absf(_wind.x)*(1.0-_fade) > 0.05 or _shudder > 0.001: return
	for a: PackedFloat32Array in _arrays():
		for v in a:
			if absf(v) > REST: return
	for a: PackedFloat32Array in _arrays(): a.fill(0.0)
	rattle = 0.0
	awake = false

# --- Reading it ---------------------------------------------------------------------

## How far the deck stands off its static pose at `t`, `side` (m off the
## middle line): Vector2(drop up, shift toward +across).
func offset(t: float, side: float) -> Vector2:
	if not awake: return Vector2.ZERO
	var at := clampf(t,0.0,1.0)*nodes
	var i := mini(floori(at),nodes-1)
	var f := at-i
	var w := _sides(side)
	var left := lerpf(yl[i],yl[i+1],f)
	var right := lerpf(yr[i],yr[i+1],f)
	return Vector2(left*w.x+right*w.y,lerpf(x[i],x[i+1],f))

## The planks' top's rise over the static pose at `t`, `side` (m; negative
## sunk).
func drop(t: float, side: float) -> float:
	return offset(t,side).x

## The deck's sideways shift at `t` (m).
func sway(t: float) -> float:
	return offset(t,0.0).y

## The deepest the deck stands under its static pose anywhere (m, positive
## sunk), for probes.
func deepest() -> float:
	var d := 0.0
	for i in range(nodes+1): d = maxf(d,-(yl[i]+yr[i])*0.5)
	return d

## Every value finite (a probe's check).
func sound() -> bool:
	for a: PackedFloat32Array in _arrays():
		for v in a:
			if is_nan(v) or is_inf(v): return false
	return true

## The shader's samples (NODES_MAX+1 each, the unused tail zero): the deck
## (drop left, drop right, shift, 0) and the hand ropes (drop left, drop
## right, shift left, shift right).
func pack(deck: PackedVector4Array, hand: PackedVector4Array) -> void:
	deck.resize(NODES_MAX+1)
	hand.resize(NODES_MAX+1)
	for i in range(NODES_MAX+1):
		if i <= nodes:
			deck[i] = Vector4(yl[i],yr[i],x[i],0.0)
			hand[i] = Vector4(hyl[i],hyr[i],hxl[i],hxr[i])
		else:
			deck[i] = Vector4.ZERO
			hand[i] = Vector4.ZERO

## The share of a load at `side` (m off the middle) on each foot rope
## (left at -across, right at +across), summing to 1.
func _sides(side: float) -> Vector2:
	var r := clampf(0.5+side/maxf(width,0.1),0.0,1.0)
	return Vector2(1.0-r,r)
