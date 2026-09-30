extends RefCounted
## How a thing that is its own cursor moves (docs/design/tools/PLAN.md "The
## hand at the rim"): a shaping tool's prop (scripts/land_clay.gd
## `_place_prop`) and a material carried from the bar (scripts/hand_materials.gd
## `Clump`). Its point (the tool's working end, the material's underside)
## follows the pointer's ground point on a stiff spring, so the cursor stays
## exact; the life is in how it hangs from there. It hovers HOVER over the
## land, bobbing and swaying a little once still; a press brings it down at
## once, on a soft spring so it bounces as it lands and as it lifts; it leans
## toward the way it goes by the pointer's speed and wobbles upright on a
## stop; and it grows in out of its point and shrinks back into it. The owner
## places it from `tip`, `way` and `turn` and sizes it by `size`.
##
## Plate coordinates, like the terrain's children it moves.

## The point follows on a stiff spring (1/s², 1/s: about 0.1 s to settle,
## barely a trail) and hovers HOVER metres over the land; pressed, it sits
## PRESS_IN into it (or where its owner says). Its height rides a soft
## spring, so it bounces as it lands and as it lifts off.
const FOLLOW := 900.0
const FOLLOW_DAMP := 55.0
const HOVER := 0.3
const PRESS_IN := 0.05
const DROP := 320.0
const DROP_DAMP := 16.0
## It leans LEAN_SPEED degrees per m/s of pointer speed, at most MAX_LEAN, on
## a loose spring (a wobble upright on a stop). Under STILL m/s it is still:
## its way holds, and after a moment it bobs BOB metres at BOB_HZ and sways
## SWAY degrees. It turns toward the way it goes at TURN (1/s).
const LEAN_SPEED := 1.6
const MAX_LEAN := 20.0
const LEAN_SPRING := 160.0
const LEAN_DAMP := 9.0
const STILL := 0.3
const BOB := 0.035
const BOB_HZ := 0.45
const SWAY := 2.5
const TURN := 6.0
## How quickly (1/s) it grows in and shrinks away.
const SHOW := 7.0

## Its point (plate), the way it goes (plate x, z, unit once moved), its lean
## and sway (degrees), its speed across the land (m/s), how far it has grown
## in (0..1) and how settled into stillness it is (0..1).
var tip := Vector3.ZERO
var way := Vector2.ZERO
var lean := 0.0
var sway := 0.0
var speed := 0.0
var shown := 0.0
var idle := 0.0
## Its point's speed across the land (plate m/s), for what it throws.
var tip_velocity := Vector2.ZERO
var _gap := 0.0
var _gap_v := 0.0
var _lean_v := 0.0
var _still := 0.0
var _clock := 0.0
var _placed := false

## Grow in toward `want` or shrink away. False once it has gone, when the next
## showing starts afresh where it is put.
func show(want: bool, delta: float) -> bool:
	shown = move_toward(shown,1.0 if want else 0.0,delta*SHOW)
	if shown <= 0.0: _placed = false
	return shown > 0.0

## Its size as it grows in and shrinks away (0..1, eased).
func size() -> float:
	return smoothstep(0.0,1.0,shown)

## Start afresh at the next step (a new prop, or one put away).
func reset() -> void:
	_placed = false
	shown = 0.0

## One frame toward `target` (plate). `ground` gives the land's height at a
## plate x, z (a Vector2), or null; the point never goes under `floor_least`.
## Pressed (`working`) it comes down to `press_gap` over the land, else it
## hovers. `rest_way` is the way it faces before it has moved.
func advance(delta: float, target: Vector3, working: bool, ground: Callable, rest_way: Vector2, floor_least := -INF, press_gap := -PRESS_IN) -> void:
	if not _placed:
		tip = target
		tip_velocity = Vector2.ZERO
		_gap = HOVER*2.0
		_gap_v = 0.0
		lean = 0.0
		_lean_v = 0.0
		way = Vector2.ZERO
		_placed = true
	# Across the land: a stiff spring, so the point is under the pointer.
	var flat := Vector2(tip.x,tip.z)
	tip_velocity += ((Vector2(target.x,target.z)-flat)*FOLLOW-tip_velocity*FOLLOW_DAMP)*delta
	flat += tip_velocity*delta
	var height: Variant = ground.call(flat) if ground.is_valid() else null
	var floor_y: float = maxf(float(height) if height != null else target.y,floor_least)
	speed = tip_velocity.length()
	_still = _still+delta if speed < STILL else 0.0
	_clock += delta
	# Height over the land: down while pressed, else hovering, with a bob that
	# eases in once it has been still a moment.
	idle = smoothstep(0.3,1.2,_still)
	var gap_goal := press_gap if working else HOVER+sin(_clock*TAU*BOB_HZ)*BOB*idle
	_gap_v += ((gap_goal-_gap)*DROP-_gap_v*DROP_DAMP)*delta
	_gap += _gap_v*delta
	tip = Vector3(flat.x,floor_y+_gap,flat.y)
	# Its way: toward where it goes, held when it stops.
	if speed > STILL: way = way.lerp(tip_velocity.normalized(),1.0-exp(-TURN*delta))
	if way.length() < 0.1: way = rest_way
	# The drag: it leans by the speed, and wobbles back on a stop.
	var lean_goal := minf(speed*LEAN_SPEED,MAX_LEAN)
	_lean_v += ((lean_goal-lean)*LEAN_SPRING-_lean_v*LEAN_DAMP)*delta
	lean += _lean_v*delta
	sway = sin(_clock*TAU*BOB_HZ*0.5+0.7)*SWAY*idle

## Its turn: facing its way and tipped `tilt` degrees about the axis across
## it (positive leans its top back against the way), plus the lean and sway.
func turn(tilt: float) -> Basis:
	var facing_way := Vector3(way.x,0.0,way.y).normalized()
	if facing_way.length_squared() < 0.5: facing_way = Vector3.BACK
	var axis := facing_way.cross(Vector3.UP).normalized()
	var facing := Basis(Vector3.UP,atan2(facing_way.x,facing_way.z))
	return Basis(axis,deg_to_rad(tilt+lean+sway))*facing

## The way across the view at rest (plate x, z), leaning as the roll's icons
## lean: toward the camera's left.
static func across_view(terrain: Node3D, camera: Camera3D) -> Vector2:
	var right: Vector3 = terrain.global_basis.inverse()*camera.global_basis.x
	return Vector2(-right.x,-right.z).normalized()
