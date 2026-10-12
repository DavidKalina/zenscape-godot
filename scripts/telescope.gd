extends Node
## The pilot's telescope (docs/design/telescope/round2.md): a small brass
## spyglass he raises to his right eye, on foot and on the ground only. Held
## (right mouse, pad LB) it comes up over RAISE s: his arms lift it to his
## eye, its three sections slide out (`extend`) and lock with a click, the
## camera eases from the chase view into his eye, the view narrows to
## ZOOM_START times and one big round lens with a thin brass rim closes
## round it (shaders/telescope_view.gdshader). The mouse or the right stick
## looks, slowed as the zoom grows; the wheel steps the zoom (ZOOM_STEP a
## notch), the triggers run it smoothly (LT out, RT in), ZOOM.x to ZOOM.y
## times. His hands sway the view a little. He stands, or shuffles at
## SHUFFLE of his pace; nothing else he does on foot works while it's up.
## Let go, it collapses and comes down the same way and the chase camera is
## where he looked.
##
## Two things show only through it:
## - An isle's card. Held on an isle (the aqueduct isle or a motif isle: the
##   host's `sight_isles`, as `lock_target` lists them for the plane) for
##   DWELL s, its card (scripts/isle_splash.gd, counted from the ledger)
##   comes up, and fades when the view leaves it or it comes down. The isle
##   he stands on is left out.
## - Glints. Any find puts itself in GROUP with `spottable(node, id)`; while
##   it is unfound (its ledger objective not done, or no id), stands GLINT_NEAR
##   to GLINT_FAR m off, is in the view, inside the lens and in plain sight
##   (a ray from the eye), a small star twinkles on it. The rune tokens do
##   (scripts/kit_isle/kit_tokens.gd); plane parts can the same way.
##
## The host (studies/character_study.gd) owns it and calls, each frame on
## foot: `restore(camera)` first (the chase camera's own fov back), `step`
## before the motor (raised or not, the look and zoom), `view` after its
## camera is set (the camera, the figure's arms and the spyglass, the
## overlay, the aim and the glints). Its `sight_isles()` lists the isles to
## aim at. The watcher (scripts/kit_isle/watcher.gd) holds the same spyglass
## the same way through the statics `make_glass`, `lift_arms`, `hold` and
## `extend`.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Pad = preload("res://scripts/pad.gd")
const IsleSplash = preload("res://scripts/isle_splash.gd")
const Ledger = preload("res://scripts/ledger/ledger.gd")
const VIEW = preload("res://shaders/telescope_view.gdshader")

## The group finds join to glint (`spottable`), and the meta naming their
## ledger objective.
const GROUP := &"telescope_finds"
const OBJECTIVE := &"telescope_objective"
## Seconds up (and down).
const RAISE := 0.3
## Times magnified: least, most, on first raising; a wheel notch's step;
## the triggers' rate (times a second, held fully).
const ZOOM := Vector2(3.0,12.0)
const ZOOM_START := 4.0
const ZOOM_STEP := 1.3
const ZOOM_RATE := 2.6
## The lens at 1x (the study's chase FOV, degrees).
const FOV := 60.0
## Look: radians per mouse pixel, and a second at the stick's full push, at 1x.
const LOOK := 0.0025
const STICK_LOOK := Vector2(2.2,1.4)
## How far up and down he can look (radians from level).
const PITCH := Vector2(-1.0,1.2)
## As they come up, the chase camera's way is eased into this band (radians
## from level): a camera dropped low looks far up, and the glass opens on the
## sky instead of the isles near the horizon.
const OPEN_PITCH := Vector2(-0.5,0.26)
## His pace while they're up, of what the stick asks.
const SHUFFLE := 0.18
## The hands' sway (radians, the larger of two slow sines).
const SWAY := 0.0025
## His eyes, in his figure's frame at size 1 (forward is -z).
const EYE := Vector3(0.0,0.95,-0.08)
## The lens's radius (screen heights, from the screen's middle; it runs
## past the top and bottom). As the shader's.
const LENS := 0.66
## An isle is aimed at when the view's middle is within its circle seen
## from here (AIM of its angular radius); its card after DWELL s on it.
const AIM := 1.0
const DWELL := 0.5
## Glints: metres, nearest and furthest; their size (design px, 1080 high).
const GLINT_NEAR := 25.0
const GLINT_FAR := 2000.0
const GLINT_SIZE := 7.0
## The arms' lift to his eye, left then right (radians, in the figure's
## frame: the upper arm about back, right and up, the forearm about back
## and up). Found by a headless search: the right mitt grips the spyglass's
## base under his right eye, about (0.06, 0.9, -0.14) m at size 1, the left
## steadies it from below, about (-0.03, 0.86, -0.15); his arms reach no
## further forward.
const ARMS := [[-3.12,-0.95,-0.49,0.06,0.0],[3.14,-0.73,0.28,-0.13,0.09]]
## The spyglass over the right mitt (m at size 1), its size against
## `make_glass`'s, and how far through the raise (`up`) its sections slide
## out: from, to.
const GLASS_LIFT := 0.04
## And in from the mitt toward his middle (m at size 1), onto his right eye.
const GLASS_IN := 0.035
const GLASS_SIZE := 1.3
const SLIDE := Vector2(0.3,0.75)

var host: Node3D
## How far up it is (0 down to 1 at his eye).
var up := 0.0
## Whether the button holds them up (and he may).
var held := false
var yaw := 0.0
var pitch := 0.0
var zoom := ZOOM_START
## The isle aimed at ({middle, radius, top, isle}), {} if none, and the one
## whose card shows (null if none).
var aimed := {}
var carded: Node = null
## The glints shown this frame: [{node, at (screen px), glow (0..1)}].
var glints: Array[Dictionary] = []
var splash: CanvasLayer
var glass: Node3D
var _dwell := 0.0
var _clock := 0.0
var _chase_fov := FOV
var _fov_set := false
var _out := 0.0
var _overlay: CanvasLayer
var _view: ColorRect
var _stars: Control

## Any find to glint through the telescope while unfound: `node` where it
## stands, `id` its ledger objective ("" glints until it's freed).
static func spottable(node: Node3D, id := "") -> void:
	node.add_to_group(GROUP)
	node.set_meta(OBJECTIVE,id)

## Whether `node` is still to be found.
static func unfound(node: Node3D) -> bool:
	var id := str(node.get_meta(OBJECTIVE,""))
	return id == "" or not Ledger.shared().is_done(id)

func setup(with: Node3D) -> void:
	name = "Telescope"
	host = with
	host.add_child(self)
	_overlay = CanvasLayer.new()
	_overlay.name = "TelescopeView"
	_overlay.layer = 3
	_overlay.visible = false
	add_child(_overlay)
	_view = ColorRect.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = VIEW
	material.set_shader_parameter("radius",LENS)
	_view.material = material
	_overlay.add_child(_view)
	_stars = Control.new()
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stars.draw.connect(_draw_glints)
	_overlay.add_child(_stars)
	splash = IsleSplash.new()
	splash.name = "TelescopeCard"
	add_child(splash)
	glass = make_glass()
	glass.visible = false
	host.figure.add_child(glass)

## Whether it's up at all (raising, raised or coming down).
func busy() -> bool:
	return up > 0.0

## Fully at his eye.
func raised() -> bool:
	return up >= 1.0

## The chase camera's fov back, as it was before `view` narrowed it.
func restore(camera: Camera3D) -> void:
	if _fov_set and camera != null: camera.fov = _chase_fov
	_fov_set = false

## Down at once (a respawn, a placing).
func drop() -> void:
	held = false
	_out = 0.0
	if up > 0.0:
		up = 0.0
		_lowered()

## A frame before the motor: `want` the button held, `allowed` whether he
## may (on foot, on the ground), `from_yaw` / `from_pitch` the chase
## camera's way as it comes up. Reads the stick and triggers unless
## the host is scripted.
func step(delta: float, want: bool, allowed: bool, from_yaw: float, from_pitch: float) -> void:
	_clock += delta
	var was := held
	held = want and allowed
	if held and up <= 0.0:
		yaw = from_yaw
		pitch = clampf(from_pitch,OPEN_PITCH.x,OPEN_PITCH.y)
		_sound("cloth",0.3)
	if was and not held:
		_let_card_go()
		_sound("cloth",0.2,0.9)
	var had := up
	up = move_toward(up,1.0 if held else 0.0,delta/RAISE)
	_slide_sounds(extension(up))
	if up <= 0.0:
		if had > 0.0: _lowered()
		return
	if host.scripted or not held: return
	var look := Pad.curve(Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down"),1.6)
	turn(Vector2(-look.x*STICK_LOOK.x,-look.y*STICK_LOOK.y)*delta)
	var trig := Input.get_action_strength(&"zoom_in")-Input.get_action_strength(&"zoom_out")
	if absf(trig) > 0.05: zoom = clampf(zoom*exp(trig*log(ZOOM_RATE)*delta),ZOOM.x,ZOOM.y)

## Turns the view by `by` (yaw, pitch; radians at 1x), slowed by the zoom.
func turn(by: Vector2) -> void:
	yaw = wrapf(yaw+by.x/zoom,-PI,PI)
	pitch = clampf(pitch+by.y/zoom,PITCH.x,PITCH.y)

## A wheel notch: `steps` in (+) or out (-).
func zoom_by(steps: int) -> void:
	var was := zoom
	zoom = clampf(zoom*pow(ZOOM_STEP,steps),ZOOM.x,ZOOM.y)
	if zoom != was: _sound("tick",0.12,1.8)

## The way the view looks (no sway).
func look_way() -> Vector3:
	var f := PilotMotor.forward(yaw)
	return Vector3(f.x*cos(pitch),sin(pitch),f.y*cos(pitch))

## The lens's fov (degrees) at the zoom now.
func lens_fov() -> float:
	return rad_to_deg(2.0*atan(tan(deg_to_rad(FOV)*0.5)/zoom))

## Where his eyes are now.
func eye() -> Vector3:
	return host.figure.global_transform*(EYE*float(host.wanderer_scale))

## After the host's camera is set: eases it to his eye, lifts his arms and
## the spyglass, and while fully up finds the isle aimed at and the glints.
func view(delta: float) -> void:
	if up <= 0.0: return
	var camera: Camera3D = host.camera
	var s := smoothstep(0.0,1.0,up)
	_chase_fov = camera.fov
	_fov_set = true
	var sway := Vector2(sin(_clock*1.3)*0.6+sin(_clock*2.9+1.0)*0.4,sin(_clock*1.1+2.0)*0.6+sin(_clock*3.7)*0.4)*SWAY
	var f := PilotMotor.forward(yaw+sway.x)
	var way := Vector3(f.x*cos(pitch+sway.y),sin(pitch+sway.y),f.y*cos(pitch+sway.y))
	var at_eyes := Transform3D(Basis.looking_at(way,Vector3.UP),eye())
	camera.global_transform = camera.global_transform.interpolate_with(at_eyes,s)
	camera.fov = lerpf(_chase_fov,lens_fov(),s)
	_pose(smoothstep(0.0,0.7,up))
	# Fully at his eye, his own figure would fill the lens.
	host.body.visible = s < 0.85
	glass.visible = s < 0.85
	_overlay.visible = true
	var size := _view.get_viewport_rect().size
	(_view.material as ShaderMaterial).set_shader_parameter("shown",smoothstep(0.45,1.0,up))
	(_view.material as ShaderMaterial).set_shader_parameter("aspect",size.x/maxf(size.y,1.0))
	if raised() and held:
		_aim(delta)
		_find_glints(camera)
	else:
		glints.clear()
	_stars.queue_redraw()

## Fully down: his figure and the chase camera back, the overlay gone.
func _lowered() -> void:
	_let_card_go()
	glints.clear()
	if host.body != null: host.body.visible = true
	glass.visible = false
	_overlay.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if up <= 0.0 or host == null: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		turn(Vector2(-event.relative.x,-event.relative.y)*LOOK)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		zoom_by(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		get_viewport().set_input_as_handled()
	# Up, nothing else on foot answers: no jump, no boarding, no picking up,
	# no camera reset.
	elif event.is_action_pressed(&"walk_jump") or event.is_action_pressed(&"camera_reset") or event.is_action_pressed(&"fly_land") \
			or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode in [KEY_E,KEY_F]):
		get_viewport().set_input_as_handled()

# --- The isle aimed at ---------------------------------------------------------------

## Of `isles` ({middle, radius, top, ...}), the one the view from `from`
## along `way` is on: the nearest to the view's middle in its own angular
## radius, within AIM of it; {} if none. An isle `from` stands within (its
## circle round) is left out.
static func pick(isles: Array, from: Vector3, way: Vector3) -> Dictionary:
	var best := {}
	var best_score := AIM
	for isle: Dictionary in isles:
		var middle: Vector3 = isle.middle
		var radius := float(isle.radius)
		if Vector2(from.x-middle.x,from.z-middle.z).length() < radius: continue
		var centre := Vector3(middle.x,float(isle.top)-radius*0.25,middle.z)
		var to := centre-from
		var far := to.length()
		if far < 1.0: continue
		var score := way.angle_to(to)/maxf(atan(radius/far),0.01)
		if score < best_score:
			best_score = score
			best = isle
	return best

func _aim(delta: float) -> void:
	var isles: Array = host.sight_isles() if host.has_method("sight_isles") else []
	var now := pick(isles,eye(),look_way())
	var isle: Node = now.get("isle")
	if isle != aimed.get("isle"):
		_dwell = 0.0
		if carded != null and isle != carded: _let_card_go()
	aimed = now
	if isle == null: return
	_dwell += delta
	if _dwell >= DWELL and carded == null and isle.has_method("isle_card"):
		carded = isle
		splash.hold = 3600.0
		splash.show_card(isle.isle_card())
		_sound("tick",0.1,1.3)

func _let_card_go() -> void:
	aimed = {}
	_dwell = 0.0
	if carded == null: return
	carded = null
	splash.hold = IsleSplash.HOLD
	splash.fade()

# --- Glints --------------------------------------------------------------------------

## The unfound finds in sight now: in front, GLINT_NEAR to GLINT_FAR m off,
## inside the lens, nothing between.
func _find_glints(camera: Camera3D) -> void:
	glints.clear()
	var size := camera.get_viewport().get_visible_rect().size
	var from := camera.global_position
	var space := host.get_world_3d().direct_space_state
	for node: Node in host.get_tree().get_nodes_in_group(GROUP):
		var find := node as Node3D
		if find == null or not find.is_visible_in_tree() or not unfound(find): continue
		var at := find.global_position
		var far := from.distance_to(at)
		if far < GLINT_NEAR or far > GLINT_FAR or camera.is_position_behind(at): continue
		var screen := camera.unproject_position(at)
		if not in_lens(screen,size): continue
		var ray := PhysicsRayQueryParameters3D.create(from,from.move_toward(at,far-1.0))
		if not space.intersect_ray(ray).is_empty(): continue
		var phase := float(hash(find.get_instance_id()) & 0xffff)/6553.6
		var twinkle := pow(sin(_clock*1.7+phase)*0.5+0.5,6.0)
		glints.append({"node":find,"at":screen,"glow":0.35+0.65*twinkle})

## Whether screen point `p` is inside the lens on a `size` screen.
static func in_lens(p: Vector2, size: Vector2) -> bool:
	return p.distance_to(size*0.5) < LENS*size.y

func _draw_glints() -> void:
	var px := _stars.get_viewport_rect().size.y/1080.0
	for g: Dictionary in glints:
		var at: Vector2 = g.at
		var glow := float(g.glow)
		var arm := GLINT_SIZE*px*(0.6+0.6*glow)
		var colour := Color(1.0,0.95,0.82,0.85*glow)
		_stars.draw_line(at-Vector2(arm,0.0),at+Vector2(arm,0.0),colour,maxf(1.0,1.2*px),true)
		_stars.draw_line(at-Vector2(0.0,arm),at+Vector2(0.0,arm),colour,maxf(1.0,1.2*px),true)
		_stars.draw_circle(at,1.6*px,Color(1.0,0.97,0.9,glow))

# --- The figure ----------------------------------------------------------------------

## His arms lifted `amount` (0 hanging to 1 at his eye) over the clips'
## pose, the spyglass in his right mitt, looking where he looks and slid
## out as far as the raise has come.
func _pose(amount: float) -> void:
	var body: Node3D = host.body
	if amount <= 0.0 or not lift_arms(body,amount): return
	var tilt := pitch*amount
	var f := PilotMotor.forward(float(host.motor.facing))
	hold(glass,body,Vector3(f.x*cos(tilt),sin(tilt),f.y*cos(tilt)),float(host.wanderer_scale))
	extend(glass,extension(up))

## Lifts `body`'s (scripts/pilot_figure.gd, after its clips) arms `amount`
## of the way to ARMS; false if it has no arms to lift.
static func lift_arms(body: Node3D, amount: float) -> bool:
	var arms: Array[int] = body._upper_arms
	var forearms: Array[int] = body._forearms
	if arms.has(-1): return false
	for side in 2:
		var a: Array = ARMS[side]
		body._turn_bone(arms[side],Vector3.BACK,a[0]*amount)
		body._turn_bone(arms[side],Vector3.RIGHT,a[1]*amount)
		body._turn_bone(arms[side],Vector3.UP,a[2]*amount)
		if forearms[side] < 0: continue
		body._turn_bone(forearms[side],Vector3.BACK,a[3]*amount)
		body._turn_bone(forearms[side],Vector3.UP,a[4]*amount)
	return true

## Puts `glass` in `body`'s right mitt, its eyepiece back at his eye and its
## barrel along `ahead`, at figure size `size`.
static func hold(glass: Node3D, body: Node3D, ahead: Vector3, size: float) -> void:
	glass.global_transform = Transform3D(Basis.looking_at(ahead,Vector3.UP).scaled(Vector3.ONE*size*GLASS_SIZE),body.mitt(1)+Vector3.UP*GLASS_LIFT*size-body.global_basis.x.normalized()*GLASS_IN*size)

## How far its sections are slid out (0 to 1) at `up` of the raise.
static func extension(up: float) -> float:
	return smoothstep(SLIDE.x,SLIDE.y,up)

## The spyglass: a faceted brass barrel with a leather grip band and a dark
## eyepiece, and two thinner draws that slide out of it one after the other
## (`extend`), the last ending in the objective's rim. About 0.13 m shut,
## 0.25 m out (before GLASS_SIZE), small enough for his mitts; forward is -z, the origin at
## the grip.
static func make_glass() -> Node3D:
	var glass := Node3D.new()
	glass.name = "Spyglass"
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78,0.58,0.28)
	brass.metallic = 0.85
	brass.roughness = 0.32
	var bright := StandardMaterial3D.new()
	bright.albedo_color = Color(0.92,0.74,0.4)
	bright.metallic = 0.9
	bright.roughness = 0.25
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.3,0.17,0.09)
	leather.roughness = 0.75
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06,0.05,0.04)
	dark.roughness = 0.5
	_tube(glass,0.022,0.1,-0.015,brass)
	_tube(glass,0.0235,0.045,-0.005,leather)
	_tube(glass,0.024,0.008,-0.062,bright)
	_tube(glass,0.013,0.025,0.045,dark)
	_tube(glass,0.016,0.006,0.03,bright)
	var draw := Node3D.new()
	draw.name = "Draw"
	glass.add_child(draw)
	_tube(draw,0.018,0.085,-0.02,brass)
	_tube(draw,0.0195,0.006,-0.06,bright)
	var tip := Node3D.new()
	tip.name = "Tip"
	draw.add_child(tip)
	_tube(tip,0.015,0.08,-0.02,brass)
	_tube(tip,0.019,0.02,-0.065,bright)
	return glass

## Slides `glass`'s draws out `amount` (0 shut to 1 out): the first draw,
## then the tip, each easing out.
static func extend(glass: Node3D, amount: float) -> void:
	var draw: Node3D = glass.get_node("Draw")
	draw.position.z = -0.065*smoothstep(0.0,0.6,amount)
	var tip: Node3D = draw.get_node("Tip")
	tip.position.z = -0.06*smoothstep(0.4,1.0,amount)

static func _tube(parent: Node3D, radius: float, length: float, at: float, material: Material) -> void:
	var tube := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	mesh.rings = 1
	tube.mesh = mesh
	tube.material_override = material
	tube.rotation.x = PI*0.5
	tube.position = Vector3(0.0,0.0,at)
	parent.add_child(tube)

## The slide's sounds as `out` (its extension now) moves: a brass swish as
## it starts out or in, a click as it locks out or shuts.
func _slide_sounds(out: float) -> void:
	if out > _out and _out <= 0.0: _sound("swish",0.05,1.7)
	elif out < _out and _out >= 1.0: _sound("swish",0.04,1.5)
	if out >= 1.0 and _out < 1.0:
		_sound("tick",0.22,0.75)
		_sound("tick",0.12,1.5)
	elif out <= 0.0 and _out > 0.0: _sound("tick",0.14,0.9)
	_out = out

func _sound(kind: String, gain: float, pitch_scale := 1.0) -> void:
	var audio: Node = host.get("audio") if host != null else null
	if audio != null and audio.has_method("shot"): audio.shot(kind,gain,pitch_scale)
