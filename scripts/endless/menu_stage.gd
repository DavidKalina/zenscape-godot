extends RefCounted
## The main menu's stage in endless flight (studies/endless_flight.gd makes
## one unless `--no-title`): the plane parked in a meadow (scripts/endless/
## menu_spot.gd), its engine started and idling (PlaneFigure `hum`), a slow
## camera circling it, the overlay (scripts/endless/main_menu.gd) over it;
## then Start's handoff into the flight. It only reads and poses: the study
## asks it for the flight input (`input`) and lets it place the eye after
## the chase's (`frame`).
##
## Its phases:
##   MENU     the engine comes on ENGINE_AT s in and runs up to idle over
##            ENGINE_UP s; the eye circles the plane at ORBIT rad/s, ORBIT_R
##            wingspans out from its middle and ORBIT_UP over it, starting
##            three-quarters on from the front (ORBIT_FROM radians off the
##            nose), at FOV degrees, the land past the plane softly blurred
##            (DOF). No flight input.
##   LEAVING  Start: the overlay fades; the eye swings round behind the
##            plane into the chase over SWING s (eased, round the plane, the
##            depth of field going); from SPOOL_AT s it runs up on the brakes
##            (ManualLanding's Brake and Boost held: the engine revs, the
##            plane strains).
##   TAKEOFF  the brakes let go and it rolls off and lifts off on its own:
##            Boost held, the stick pulled back PULL (the wheels let go at
##            the lift speed), the player's stick steering; held LIFT_HOLD s
##            more once it flies, then it is the player's. Brake on the
##            wheels takes it over there and then.
##   DONE     flying as ever.

const WorldScale = preload("res://scripts/world_scale.gd")

enum {MENU,LEAVING,TAKEOFF,DONE}
const NAMES := ["menu","leaving","takeoff","done"]

const ENGINE_AT := 0.6
const ENGINE_UP := 1.1
const ORBIT := 0.075
const ORBIT_R := 2.35
const ORBIT_UP := 0.12
const ORBIT_FROM := 0.75
## The eye looks a little under the plane's middle, and breathes BOB
## wingspans up and down over BOB_S s.
const LOOK_DOWN := 0.2
const BOB := 0.04
const BOB_S := 9.0
const FOV := 44.0
## The depth of field: blurred from DOF.x m past the plane over DOF.y m, by
## DOF.z (CameraAttributesPractical's amount).
const DOF := Vector3(8.0,40.0,0.035)
const SWING := 2.6
const SPOOL_AT := 0.9
const PULL := 1.0
const LIFT_HOLD := 1.0
## The eye keeps this far over the land (m), and in the menu EYE_OVER
## wingspans over it (over the meadow's grass).
const CLEAR := 0.6
const EYE_OVER := 0.95
## Behind it, swinging round and on the takeoff roll, the chase's eye is
## held CHASE_OVER wingspans over the land (the grass stands about 2 m).
const CHASE_OVER := 1.5

var phase := MENU
## Seconds in the phase, and in all.
var time := 0.0
var elapsed := 0.0
## The engine's run (0 to 1), for the study to lay over the landing's.
var engine := 0.0
## The orbit's angle round the plane (radians, world, as a heading).
var angle := 0.0
var overlay: Control
var _attributes: CameraAttributesPractical
var _flown := 0.0
## The depth of field's strength over DOF.z (`--menu-dof=X`; off by default:
## the look's painted land read smeared through it).
var dof_scale := 0.0

## Takes the stage: the plane parked on `heading`, the overlay shown.
func begin(heading: float, menu: Control) -> void:
	phase = MENU
	time = 0.0
	elapsed = 0.0
	engine = 0.0
	angle = heading+ORBIT_FROM
	overlay = menu
	overlay.present()
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--menu-dof="): dof_scale = maxf(0.0,a.get_slice("=",1).to_float())
	_attributes = CameraAttributesPractical.new()
	_attributes.dof_blur_far_enabled = true
	_attributes.dof_blur_far_distance = 10.0
	_attributes.dof_blur_far_transition = DOF.y
	_attributes.dof_blur_amount = DOF.z*dof_scale
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH,true)

## True while the menu holds the flight (no input of the player's reaches it).
func holding() -> bool:
	return phase == MENU or phase == LEAVING

## True until it is the player's.
func running() -> bool:
	return phase != DONE

## Start picked: the overlay goes, the swing begins.
func start() -> void:
	if phase != MENU: return
	overlay.leave()
	_enter(LEAVING)

func _enter(next: int) -> void:
	phase = next
	time = 0.0

## The flight input this frame (ManualLanding `step`'s), from `player`'s
## (the study's own `_fly_input`): none in the menu, the run-up on the
## brakes leaving, the takeoff's held Boost and pull with the player's
## steering; the player's once DONE. `landing` is the study's ManualLanding.
func input(delta: float, player: Dictionary, landing: RefCounted, figure: Node3D) -> Dictionary:
	time += delta
	elapsed += delta
	if phase == MENU or phase == LEAVING:
		engine = clampf((elapsed-ENGINE_AT)/ENGINE_UP,0.0,1.0) if phase == MENU else maxf(engine,clampf((elapsed-ENGINE_AT)/ENGINE_UP,0.0,1.0))
	else: engine = 1.0
	var none := {"turn":0.0,"pitch":0.0,"look":Vector2.ZERO,"lean":0.0,"boost":0.0,"brake":0.0,"roll":0.0}
	match phase:
		MENU:
			figure.hum = smoothstep(0.0,1.0,engine)
			figure.rev = 0.0
			return none
		LEAVING:
			# Engine on for the run-up even if Start came before it was.
			engine = maxf(engine,clampf(time/0.5,0.0,1.0))
			figure.hum = 1.0
			figure.rev = float(landing.strain)
			if time >= SWING:
				_enter(TAKEOFF)
			elif time >= SPOOL_AT:
				none.boost = 1.0
				none.brake = 1.0
			return none
		TAKEOFF:
			var flying: bool = landing.flying()
			var p := player.duplicate()
			if not flying and float(player.get("brake",0.0)) > 0.3:
				finish(figure)
				return player
			if flying:
				_flown += delta
				if _flown >= LIFT_HOLD or absf(float(player.get("pitch",0.0))) > 0.2:
					finish(figure)
					return player
			p.boost = 1.0
			p.brake = 0.0
			if absf(float(player.get("pitch",0.0))) < 0.2: p.pitch = PULL
			figure.rev = 1.0
			figure.sway = clampf(1.0-landing.roll_speed()/4.0,0.0,1.0) if not flying else 0.0
			return p
	return player

func finish(figure: Node3D) -> void:
	figure.hum = 0.0
	figure.rev = 0.0
	figure.sway = 1.0
	_enter(DONE)

## After the chase has placed `camera` (the study's `_frame`): in the menu
## the eye circles `centre` (the plane's middle) at `size` (the plane's
## drawn scale), looking at it; leaving, it swings from there round into
## the chase's eye; `ground` the land's height at a point (x, z).
func frame(delta: float, camera: Camera3D, centre: Vector3, size: float, ground: Callable) -> void:
	if phase == DONE:
		if camera.attributes == _attributes and _attributes != null: camera.attributes = null
		return
	var span := WorldScale.TOY_SPAN*size
	if phase == TAKEOFF:
		# The chase's own, kept up out of the grass while on the wheels and
		# let down to it over LIFT_HOLD s once it flies.
		if camera.attributes == _attributes and _attributes != null: camera.attributes = null
		var k := 1.0-smoothstep(0.0,LIFT_HOLD,_flown)
		var e := _over_grass(camera.global_position,span,ground,k)
		var ahead := camera.global_position-camera.global_basis.z*maxf(1.0,camera.global_position.distance_to(centre))
		_place(camera,e,ahead,camera.fov,_roll_of(camera),ground)
		return
	if phase == MENU: angle += ORBIT*delta
	var r := ORBIT_R*span
	var up := (ORBIT_UP+BOB*sin(elapsed*TAU/BOB_S))*span
	var look := centre+Vector3.DOWN*LOOK_DOWN*span
	var orbit_eye := centre+Vector3(-sin(angle),0.0,-cos(angle))*r+Vector3.UP*up
	var under := float(ground.call(orbit_eye.x,orbit_eye.z))
	if not is_nan(under): orbit_eye.y = maxf(orbit_eye.y,under+EYE_OVER*span)
	up = orbit_eye.y-centre.y
	if phase == MENU:
		_place(camera,orbit_eye,look,FOV,0.0,ground)
		_attributes.dof_blur_far_distance = r+DOF.x
		_attributes.dof_blur_amount = DOF.z*dof_scale
		camera.attributes = _attributes if dof_scale > 0.0 else null
		return
	# Leaving: round the plane from the orbit's eye to the chase's.
	var w := clampf(time/SWING,0.0,1.0)
	w = w*w*w*(w*(w*6.0-15.0)+10.0)
	var chase_look := camera.global_position-camera.global_basis.z*maxf(1.0,camera.global_position.distance_to(centre))
	var chase_eye := _over_grass(camera.global_position,span,ground,1.0)
	var chase_fov := camera.fov
	var off := chase_eye-centre
	var flat := Vector2(off.x,off.z)
	var chase_angle := atan2(-flat.x,-flat.y)
	var a := lerp_angle(angle,chase_angle,w)
	var rr := lerpf(r,flat.length(),w)
	var h := lerpf(up,off.y,w)
	var eye := centre+Vector3(-sin(a),0.0,-cos(a))*rr+Vector3.UP*h
	var roll_now := _roll_of(camera)
	_place(camera,eye,look.lerp(chase_look,w),lerpf(FOV,chase_fov,w),roll_now*w,ground)
	_attributes.dof_blur_amount = DOF.z*dof_scale*(1.0-w)
	if w >= 1.0: camera.attributes = null

## `eye` raised `k` of the way to CHASE_OVER wingspans over the land (out
## of the meadow's tall grass).
static func _over_grass(eye: Vector3, span: float, ground: Callable, k: float) -> Vector3:
	var under := float(ground.call(eye.x,eye.z))
	if is_nan(under) or k <= 0.0: return eye
	return Vector3(eye.x,lerpf(eye.y,maxf(eye.y,under+CHASE_OVER*span),k),eye.z)

## The chase's roll on `camera` as it placed it (about its view).
static func _roll_of(camera: Camera3D) -> float:
	var b := camera.global_basis
	var level := Basis.looking_at(-b.z,Vector3.UP)
	return level.x.signed_angle_to(b.x,-b.z)

static func _place(camera: Camera3D, eye: Vector3, look: Vector3, fov: float, roll: float, ground: Callable) -> void:
	var floor_y := float(ground.call(eye.x,eye.z))
	if not is_nan(floor_y): eye.y = maxf(eye.y,floor_y+CLEAR)
	camera.global_position = eye
	if eye.distance_to(look) > 0.01: camera.look_at(look,Vector3.UP)
	if roll != 0.0: camera.rotate_object_local(Vector3.FORWARD,roll)
	camera.fov = fov
