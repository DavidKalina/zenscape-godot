extends Node
## Turning the world like a lazy Susan (docs/scenic/hand-turn.md). A mouse
## drag that orbits (a drag on the land or off it in Look, a right drag, a
## Ctrl-drag, an Alt-drag, a drag off the land with a brush) grabs the ground
## under the pointer and turns the world round the camera's pivot so that
## point keeps its bearing under the pointer: the yaw comes from the grabbed
## point's angle round the pivot, not from a pixels-to-radians gain. Up and
## down still tilt as they always have.
##
## Let go with speed and the world spins on like a basketball on a finger,
## faster than it was pushed and for a long while, easing to a stop by
## itself. A press during the spin catches it: the world carries on a few
## degrees against the hand, comes back and settles. A flick the same way
## during a spin bats it on instead, and each bat adds to the spin. The God Hand
## (scripts/god_hand.gd) shows it: it spreads its fingers on the grabbed
## ground and pushes it round, lets go with follow-through, and slaps down to
## catch a spin.
##
## scripts/camera_rig.gd owns this and calls `advance` each frame after its
## springs have stepped, so the yaw written here is the one the scene reads.
## Nothing here consumes input: presses are only watched, to catch a spin.
## `--classic-orbit` leaves this out and the rig orbits by pixels as before.
## Trackpad swipes, Shift+arrows and glides still orbit the rig's way, and
## stop a spin dead.
##
## The room stays put while the world turns: every change of the camera's
## yaw the rig makes while it drives (a grab, a spin, a catch, a swipe,
## Shift+arrows, a glide, Space's idle drift) also turns the room by as much
## (`turn_room`), and studies/celestial.gd turns the sun and moon, both lights,
## the stars, the aurora and the horizon hills by the room's yaw. Seen from the
## camera the room then never moves, and the diorama spins under it like a
## model on a turntable under a fixed lamp. Under `--modeless` the turntable's
## spindle is the plate's middle, not the camera's pivot: the whole rig, pivot
## and all, swings round it (`_set_yaw`), so however the view is panned the
## plate turns in place and the camera seems not to move. Poses set from outside (a
## regrowth, the menu's Overview, photo mode, a capture) move the camera, not
## the room.

## Below this turning speed (rad/s) a release lets the world stand; above it
## the world spins on at FLICK_GAIN times the speed it had, at most MAX_SPIN
## (about two turns a second).
const FLICK_MIN := 0.35
const FLICK_GAIN := 1.6
const MAX_SPIN := 12.0
## A flick the same way as a spin it pressed into bats it: the new spin is
## the flick's plus BAT_KEEP of the spin it had.
const BAT_KEEP := 1.0
## The spin's drag: its speed falls by e every SPIN_DRAG seconds, and a dry
## friction (rad/s²) takes FRICTION off per second on top. The friction fades
## out below FRICTION_SOFT rad/s, so the last of the spin eases away rather
## than stopping on a step. Under SPIN_STOP rad/s it has stopped. A spin of
## 6 rad/s goes round about two and a half times and runs down in about 8 s.
const SPIN_DRAG := 3.0
const FRICTION := 0.15
const FRICTION_SOFT := 0.25
const SPIN_STOP := 0.004
## The drag's turning speed is read over about this many seconds, so a drag
## that stops before it is let go does not flick.
const RATE_SMOOTH := 0.05
## The catch: the world's speed (at most MAX_CATCH rad/s) goes into a spring
## (natural frequency CATCH_W 1/s, damping ratio CATCH_ZETA) that carries it
## on past the hand and back. At MAX_CATCH it overshoots about 4.5 degrees,
## comes back past by about half a degree and has settled by 0.85 s.
const CATCH_W := 13.0
const CATCH_ZETA := 0.55
const MAX_CATCH := 2.2
## Seconds a caught click keeps the hand pressed down at least.
const CATCH_HAND := 0.4
## Near the pivot a point's bearing swings wildly with a small move, so a
## grab (or the pointer) closer than NEAR of the view's half height at the
## pivot turns by pixels instead (a screen height is a turn, as before),
## blending back to the true grab by twice that, and the grab takes up the
## ground now under the pointer as it goes.
const NEAR := 0.1
## Most radians the grab may turn in one frame.
const MAX_STEP := 0.4
## Under `--modeless` the world's speed that time reads (`own_rate`) is smoothed
## over this many seconds, and signed, so a shake's back and forth cancels
## rather than winding the clock.
const OWN_SMOOTH := 0.3

var rig: Node
var scene: Node3D
var camera: Camera3D
var enabled := "--classic-orbit" not in preload("res://scripts/launch_args.gd").user_args()
## `--modeless` (docs/scenic/modeless.md): the turn is the rim's alone. Only a
## grab held from outside (`hold_begin`) turns the world, and a spin or catch
## that follows; a right drag is the camera and moves the view by pixels, not
## the room. The room follows only the turn's own yaw, and `own_rate` is the
## turn's speed, which scripts/spin_time.gd reads as time.
var modeless := preload("res://scripts/modeless_input.gd").enabled()
## The rim (or another outside hand) holds the world: its grab point (global)
## and whether it holds now.
var external := false
var external_grab: Variant = null
## The yaw the turn itself made this frame, and its speed (rad/s, signed and
## smoothed over OWN_SMOOTH): a grab, a spin, a catch. Never a camera move.
var own_rate := 0.0
## Modeless: this turn (the hold and the spin it lets go into) winds no time,
## however fast: the rim was pushed with Shift held (scripts/hand_reach.gd sets
## it when a turn is decided; scripts/spin_time.gd reads it).
var timeless := false
var _own := 0.0
## True from the press that starts an orbiting drag to its release.
var grabbing := false
## The spin's speed (rad/s of yaw) after a flick, 0 when still.
var spin := 0.0
## The catch spring's yaw offset (radians) and its rate.
var settle := 0.0
var settle_speed := 0.0
## The grabbed point (global), on the land or on the level of the pivot.
var grab: Variant = null
## The grabbed point is on the land (the hand shows only then).
var on_land := false
## The drag's turning speed (rad/s), smoothed over RATE_SMOOTH.
var rate := 0.0
## The yaw's speed this frame (rad/s), whatever moved it: drag, spin, catch.
var turning := 0.0
## Where the pointer is, and where the last press was.
var pointer := Vector2.ZERO
var _press_at := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _lost := false
## The catch's offset already in the rig's yaw.
var _applied := 0.0
var _catch_pending := false
## The spin (rad/s) the press caught, which a flick the same way bats on.
var _caught := 0.0
var _catch_at: Variant = null
var _hand_hold := 0.0
var _hand_on := false
## The room's yaw (radians): how far the camera's yaw has turned under the
## rig since the scene started, which the room follows. Stays 0 with
## `--classic-orbit`.
var room_yaw := 0.0

func setup(owner_rig: Node) -> void:
	rig = owner_rig
	scene = rig.scene
	camera = rig.camera
	name = "WorldTurn"

## Takes the drag's side-to-side from the rig's orbit: the grab turns instead.
func takes_orbit() -> bool:
	return enabled and (grabbing if modeless else (scene._orbiting or grabbing))

## Under `--modeless`, the rim takes hold of the world at `press` (screen), on
## the global point `point` (the rim's edge under the pointer), and turns it
## from there. The press itself is the hand's, so this is told the pointer.
func hold_begin(press: Vector2, point: Variant) -> void:
	if not enabled or not modeless: return
	external = true
	external_grab = point
	pointer = press
	_press_at = press

## The held rim's pointer moved.
func hold_move(at: Vector2) -> void:
	pointer = at

## The rim let go. With `flick` false the world stays where it is (a shake
## took the rim); otherwise it spins on if it was turning fast.
func hold_end(flick := true) -> void:
	external = false
	if not flick: rate = 0.0

## Something else moves the camera (a swipe, keys, a glide, a pose set from
## outside): the spin and the catch stop where they are.
func stop() -> void:
	spin = 0.0
	settle = 0.0
	settle_speed = 0.0
	_applied = 0.0

## The rig stands aside (a menu, photo mode, a regrowth): let go of
## everything, the hand included.
func rest() -> void:
	if not enabled: return
	grabbing = false
	external = false
	grab = null
	rate = 0.0
	turning = 0.0
	own_rate = 0.0
	_own = 0.0
	timeless = false
	stop()
	_hand_on = false
	_hand_hold = 0.0
	_catch_pending = false
	_hand(0.0)

## The rig turned the camera's yaw by `by` radians this frame: the room
## follows, so it keeps its bearing to the camera and the diorama is what
## turns.
func turn_room(by: float) -> void:
	# Modeless: the room follows the turn's own yaw only, so looking round with
	# the camera moves the view and leaves the sun where it is in the world.
	if modeless:
		by = _own
		_own = 0.0
	if not enabled or by == 0.0: return
	room_yaw += by
	var sky: Object = scene.get("_celestial")
	if sky != null: sky.room_yaw = room_yaw

func spinning() -> bool:
	return absf(spin) > 0.0

func _input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventMouseMotion:
		pointer = event.position
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT] and event.pressed:
		pointer = event.position
		_press_at = event.position
		if rig.live and rig._world_pointer(event.position) and not rig._hands_full() and spinning(): catch_at(event.position)

## A press during a spin: the hand catches the world. Its speed carries on
## into the settle spring, which brings it back and to rest.
func catch_at(at: Vector2) -> void:
	settle_speed += clampf(spin,-MAX_CATCH,MAX_CATCH)
	_caught = spin
	spin = 0.0
	_catch_pending = true
	_catch_at = rig.inspector.ground_hit(at)
	_hand_hold = CATCH_HAND

## Each frame after the rig's springs: grab, spin and settle the yaw, and
## tell the hand. Writes the rig's eased yaw directly (the drag is held
## exactly, with no spring behind it).
func advance(delta: float) -> void:
	if not enabled: return
	delta = maxf(delta,0.0001)
	var before: float = rig._view.x
	var orbiting: bool = external if modeless else scene._orbiting
	if orbiting and not grabbing: _begin()
	elif grabbing and not orbiting: _release()
	_step_settle(delta)
	# The yaw is the turn's own (base) plus the catch's offset on top.
	var base: float = float(rig._view.x)-_applied
	if grabbing:
		base += _hold(delta)
		_set_yaw(base+settle)
	else:
		_step_spin(delta)
		if spin != 0.0 or settle != _applied: _set_yaw(base+spin*delta+settle)
	_applied = settle
	turning = lerpf(turning,(float(rig._view.x)-before)/delta,1.0-exp(-delta/RATE_SMOOTH))
	_own = float(rig._view.x)-before
	own_rate = lerpf(own_rate,_own/delta,1.0-exp(-delta/OWN_SMOOTH))
	_last_pointer = pointer
	_hand(delta)

func _set_yaw(yaw: float) -> void:
	if modeless:
		# The pivot swings round the plate's middle with the yaw, so the plate
		# turns about its own middle wherever the camera looks.
		var by: float = yaw-float(rig._view.x)
		var middle := _middle()
		rig._pivot = middle+(rig._pivot-middle).rotated(Vector3.UP,by)
		rig._pivot_goal = middle+(rig._pivot_goal-middle).rotated(Vector3.UP,by)
		rig._pivot_v = rig._pivot_v.rotated(Vector3.UP,by)
	rig._view.x = yaw
	rig._view_goal.x = yaw
	rig._view_v.x = 0.0

func _begin() -> void:
	grabbing = true
	rate = 0.0
	_lost = false
	rig._hand()
	rig._used.orbit = true
	# The ground where the press was, as it was seen; off the land, the level
	# of the pivot.
	var hit: Variant = rig.inspector.ground_hit(_press_at)
	on_land = hit != null
	grab = hit if hit != null else _on_level(rig._pivot.y,_press_at)
	# The rim's grab is the edge itself, and the rim shows its own hand.
	if external and external_grab != null:
		grab = external_grab
		on_land = false
	if grab == null: _lost = true
	_last_pointer = _press_at
	# Pressing into a spin is a catch, whatever the press became.
	if spinning(): catch_at(_press_at)

func _release() -> void:
	grabbing = false
	if absf(rate) > FLICK_MIN:
		var kept := _caught*BAT_KEEP if signf(_caught) == signf(rate) else 0.0
		spin = clampf(rate*FLICK_GAIN+kept,-MAX_SPIN,MAX_SPIN)
	_caught = 0.0
	rate = 0.0
	grab = null

## What the world turns about: under `--modeless` the plate's middle (from its
## skirt, as scripts/diorama_flip.gd finds it), at the pivot's height; else the
## camera's pivot.
func _middle() -> Vector3:
	var centre: Vector3 = rig._pivot
	if not modeless: return centre
	var skirt: Variant = rig.editor.get("_skirt") if rig.editor != null else null
	if skirt is MeshInstance3D and skirt.mesh != null:
		var box: AABB = skirt.global_transform*skirt.get_aabb()
		var mid := box.get_center()
		return Vector3(mid.x,centre.y,mid.z)
	return Vector3(0.0,centre.y,0.0)

## Where the pointer's ray meets the level `height`, for the rig's pose as it
## stands this frame (not the camera's last transform), or null above the
## horizon.
func _on_level(height: float, at: Vector2) -> Variant:
	var eye: Vector3 = rig.eye()
	var look: Vector3 = rig._pivot-eye
	if look.length_squared() < 0.000001: return null
	var direction := Basis.looking_at(look,Vector3.UP)*camera.project_local_ray_normal(at)
	if absf(direction.y) < 0.0001: return null
	var t := (height-eye.y)/direction.y
	if t <= 0.0: return null
	return eye+direction*t

## How far the turn's own yaw moves this frame to put the grabbed point back
## on the pointer's bearing round the pivot (the catch's offset is laid on
## top of it after). Near the pivot (or with the pointer above the horizon)
## it turns by pixels and takes up the ground under the pointer as the grab.
func _hold(delta: float) -> float:
	var pixels: float = -TAU*(pointer.x-_last_pointer.x)/rig._height()
	var centre := _middle()
	var under: Variant = _on_level(float(grab.y) if grab != null else centre.y,pointer)
	var step := pixels
	var weight := 0.0
	if under != null and grab != null and not _lost:
		var near: float = NEAR*exp(rig._view.z)*tan(deg_to_rad(camera.fov)*0.5)
		var held := Vector2(grab.x-centre.x,grab.z-centre.z)
		var now := Vector2(under.x-centre.x,under.z-centre.z)
		weight = smoothstep(near,2.0*near,minf(held.length(),now.length()))
		var bearing := angle_difference(atan2(now.x,now.y),atan2(held.x,held.y))
		# The bearing is measured with the catch's offset in the view; the
		# turn's own yaw holds the grab without it.
		step = lerpf(pixels,bearing+_applied,weight)
	step = clampf(step,-MAX_STEP,MAX_STEP)
	if under != null and (weight < 1.0 or _lost):
		# The ground now under the pointer, where it will be after this turn
		# and the catch's next offset.
		var taken: Vector3 = centre+(Vector3(under)-centre).rotated(Vector3.UP,step-_applied+settle)
		grab = taken
		_lost = false
	elif under == null:
		_lost = true
	rate = lerpf(rate,step/delta,1.0-exp(-delta/RATE_SMOOTH))
	return step

func _step_spin(delta: float) -> void:
	if spin == 0.0: return
	var speed := absf(spin)
	speed *= exp(-delta/SPIN_DRAG)
	speed -= FRICTION*minf(1.0,speed/FRICTION_SOFT)*delta
	spin = 0.0 if speed < SPIN_STOP else signf(spin)*speed

## The catch spring, in two half steps (semi-implicit), to rest when it has
## all but stopped.
func _step_settle(delta: float) -> void:
	if settle == 0.0 and settle_speed == 0.0: return
	var h := delta*0.5
	for i in range(2):
		settle_speed += (-CATCH_W*CATCH_W*settle-2.0*CATCH_ZETA*CATCH_W*settle_speed)*h
		settle += settle_speed*h
	if absf(settle) < 0.0002 and absf(settle_speed) < 0.002:
		settle = 0.0
		settle_speed = 0.0

## The God Hand grips the grabbed land ("turn"), or slaps down to catch a
## spin ("catch"), and leans into the push. Off the land it stays away.
func _hand(delta: float) -> void:
	var hand: Node3D = scene.get("god_hand")
	if hand == null: return
	var editor: NativeChunkEditor = rig.editor
	_hand_hold = maxf(0.0,_hand_hold-delta)
	var at: Variant = null
	var gesture := ""
	if _catch_pending:
		_catch_pending = false
		# A press that paints or holds a handful keeps its own gesture.
		var busy: bool = not grabbing and editor.active and not editor.hand_gesture().is_empty()
		if _catch_at != null and not busy: _hand_on = true
		else: _hand_hold = 0.0
	if grabbing and on_land:
		gesture = "turn" if not _hand_on else "catch"
		at = grab
	elif _hand_on and (_hand_hold > 0.0 or settle != 0.0) and _catch_at != null:
		gesture = "catch"
		at = _catch_at
	else:
		_hand_on = false
	if grabbing and _hand_on and at != null: _catch_at = at
	if gesture.is_empty():
		if hand.reach_gesture in ["turn","catch"]:
			hand.reach_gesture = ""
			hand.reach_point = null
			if "reach_push" in hand: hand.reach_push = Vector3.ZERO
		return
	var terrain: Node3D = editor.terrain
	var local := terrain.to_local(at)
	var ground: Variant = editor.data.ground_height(Vector2(local.x,local.z))
	if ground != null: local.y = float(ground)
	hand.reach_gesture = gesture
	hand.reach_point = local
	if "reach_push" in hand:
		# The grabbed ground's way across the view: the world turns by minus
		# the camera's yaw about the pivot.
		var arm: Vector3 = Vector3(at)-_middle()
		var push := Vector3(arm.z,0.0,-arm.x)*-turning
		hand.reach_push = terrain.global_basis.inverse()*push
