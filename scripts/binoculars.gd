extends Node
## The pilot's binoculars (docs/design/binoculars/round1.md): a small brass
## pair he raises to his eyes, on foot and on the ground only. Held (right
## mouse, pad LB) they come up over RAISE s: his arms lift them to his face,
## the camera eases from the chase view into his eyes, the view narrows to
## ZOOM_START times and two soft circles close round it (shaders/
## binoculars_view.gdshader). The mouse or the right stick looks, slowed as
## the zoom grows; the wheel steps the zoom (ZOOM_STEP a notch), the
## triggers run it smoothly (LT out, RT in), ZOOM.x to ZOOM.y times. His
## hands sway the view a little. He stands, or shuffles at SHUFFLE of his
## pace; nothing else he does on foot works while they're up. Let go, they
## come down the same way and the chase camera is where he looked.
##
## Two things show only through them:
## - An isle's card. Held on an isle (the aqueduct isle or a motif isle: the
##   host's `sight_isles`, as `lock_target` lists them for the plane) for
##   DWELL s, its card (scripts/isle_splash.gd, counted from the ledger)
##   comes up, and fades when the view leaves it or they come down. The isle
##   he stands on is left out.
## - Glints. Any find puts itself in GROUP with `spottable(node, id)`; while
##   it is unfound (its ledger objective not done, or no id), stands GLINT_NEAR
##   to GLINT_FAR m off, is in the view, inside the circles and in plain
##   sight (a ray from the eye), a small star twinkles on it. The rune tokens
##   do (scripts/kit_isle/kit_tokens.gd); plane parts can the same way.
##
## The host (studies/character_study.gd) owns it and calls, each frame on
## foot: `restore(camera)` first (the chase camera's own fov back), `step`
## before the motor (raised or not, the look and zoom), `view` after its
## camera is set (the camera, the figure's arms and the pair, the overlay,
## the aim and the glints). Its `sight_isles()` lists the isles to aim at.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Pad = preload("res://scripts/pad.gd")
const IsleSplash = preload("res://scripts/isle_splash.gd")
const Ledger = preload("res://scripts/ledger/ledger.gd")
const VIEW = preload("res://shaders/binoculars_view.gdshader")

## The group finds join to glint (`spottable`), and the meta naming their
## ledger objective.
const GROUP := &"binocular_finds"
const OBJECTIVE := &"binocular_objective"
## Seconds up (and down).
const RAISE := 0.25
## Times magnified: least, most, on first raising; a wheel notch's step;
## the triggers' rate (times a second, held fully).
const ZOOM := Vector2(2.0,8.0)
const ZOOM_START := 3.0
const ZOOM_STEP := 1.3
const ZOOM_RATE := 2.2
## The lens at 1x (the study's chase FOV, degrees).
const FOV := 60.0
## Look: radians per mouse pixel, and a second at the stick's full push, at 1x.
const LOOK := 0.0025
const STICK_LOOK := Vector2(2.2,1.4)
## How far up and down he can look (radians from level).
const PITCH := Vector2(-1.0,1.2)
## His pace while they're up, of what the stick asks.
const SHUFFLE := 0.18
## The hands' sway (radians, the larger of two slow sines).
const SWAY := 0.0035
## His eyes, in his figure's frame at size 1 (forward is -z).
const EYE := Vector3(0.0,0.95,-0.08)
## The view's circles (screen heights): their radius and how far each
## middle sits off the screen's middle. As the shader's.
const CIRCLE := 0.46
const APART := 0.2
## An isle is aimed at when the view's middle is within its circle seen
## from here (AIM of its angular radius); its card after DWELL s on it.
const AIM := 1.0
const DWELL := 0.5
## Glints: metres, nearest and furthest; their size (design px, 1080 high).
const GLINT_NEAR := 25.0
const GLINT_FAR := 2000.0
const GLINT_SIZE := 7.0
## The arms' lift to his face (kit_isle.gd's `_raise_arms` axes): the upper
## arms out and up, forward, the forearms bent, turned in.
const ARMS := Vector4(3.1,-0.6,0.0,-0.6)

var host: Node3D
## How far up they are (0 down to 1 at his eyes).
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
var pair: Node3D
var _dwell := 0.0
var _clock := 0.0
var _chase_fov := FOV
var _fov_set := false
var _overlay: CanvasLayer
var _view: ColorRect
var _stars: Control

## Any find to glint through the binoculars while unfound: `node` where it
## stands, `id` its ledger objective ("" glints until it's freed).
static func spottable(node: Node3D, id := "") -> void:
	node.add_to_group(GROUP)
	node.set_meta(OBJECTIVE,id)

## Whether `node` is still to be found.
static func unfound(node: Node3D) -> bool:
	var id := str(node.get_meta(OBJECTIVE,""))
	return id == "" or not Ledger.shared().is_done(id)

func setup(with: Node3D) -> void:
	name = "Binoculars"
	host = with
	host.add_child(self)
	_overlay = CanvasLayer.new()
	_overlay.name = "BinocularsView"
	_overlay.layer = 3
	_overlay.visible = false
	add_child(_overlay)
	_view = ColorRect.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = VIEW
	material.set_shader_parameter("radius",CIRCLE)
	material.set_shader_parameter("apart",APART)
	_view.material = material
	_overlay.add_child(_view)
	_stars = Control.new()
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stars.draw.connect(_draw_glints)
	_overlay.add_child(_stars)
	splash = IsleSplash.new()
	splash.name = "BinocularsCard"
	add_child(splash)
	pair = _make_pair()
	pair.visible = false
	host.figure.add_child(pair)

## Whether they're up at all (raising, raised or coming down).
func busy() -> bool:
	return up > 0.0

## Fully at his eyes.
func raised() -> bool:
	return up >= 1.0

## The chase camera's fov back, as it was before `view` narrowed it.
func restore(camera: Camera3D) -> void:
	if _fov_set and camera != null: camera.fov = _chase_fov
	_fov_set = false

## Down at once (a respawn, a placing).
func drop() -> void:
	held = false
	if up > 0.0:
		up = 0.0
		_lowered()

## A frame before the motor: `want` the button held, `allowed` whether he
## may (on foot, on the ground), `from_yaw` / `from_pitch` the chase
## camera's way as they come up. Reads the stick and triggers unless
## the host is scripted.
func step(delta: float, want: bool, allowed: bool, from_yaw: float, from_pitch: float) -> void:
	_clock += delta
	var was := held
	held = want and allowed
	if held and up <= 0.0:
		yaw = from_yaw
		pitch = clampf(from_pitch,PITCH.x,PITCH.y)
		_sound("cloth",0.3)
	if was and not held:
		_let_card_go()
		_sound("cloth",0.2,0.9)
	var had := up
	up = move_toward(up,1.0 if held else 0.0,delta/RAISE)
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

## After the host's camera is set: eases it to his eyes, lifts his arms and
## the pair, and while fully up finds the isle aimed at and the glints.
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
	# Fully at his eyes, his own figure would fill the lens.
	host.body.visible = s < 0.85
	pair.visible = s < 0.85
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
	pair.visible = false
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
## inside the circles, nothing between.
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
		if not in_circles(screen,size): continue
		var ray := PhysicsRayQueryParameters3D.create(from,from.move_toward(at,far-1.0))
		if not space.intersect_ray(ray).is_empty(): continue
		var phase := float(hash(find.get_instance_id()) & 0xffff)/6553.6
		var twinkle := pow(sin(_clock*1.7+phase)*0.5+0.5,6.0)
		glints.append({"node":find,"at":screen,"glow":0.35+0.65*twinkle})

## Whether screen point `p` is inside the view's circles on a `size` screen.
static func in_circles(p: Vector2, size: Vector2) -> bool:
	var h := size.y
	var middle := size*0.5
	var r := CIRCLE*h
	return p.distance_to(middle+Vector2(-APART*h,0.0)) < r or p.distance_to(middle+Vector2(APART*h,0.0)) < r

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

## His arms lifted `amount` (0 hanging to 1 at his face) over the clips'
## pose, the pair between his mitts, looking where he looks.
func _pose(amount: float) -> void:
	var body: Node3D = host.body
	var arms: Array[int] = body._upper_arms
	var forearms: Array[int] = body._forearms
	if amount <= 0.0 or arms.has(-1): return
	body._turn_bone(arms[0],Vector3.BACK,-ARMS.x*amount)
	body._turn_bone(arms[1],Vector3.BACK,ARMS.x*amount)
	body._turn_bone(arms[0],Vector3.RIGHT,ARMS.y*amount)
	body._turn_bone(arms[1],Vector3.RIGHT,ARMS.y*amount)
	if not forearms.has(-1):
		body._turn_bone(forearms[0],Vector3.BACK,ARMS.z*amount)
		body._turn_bone(forearms[1],Vector3.BACK,-ARMS.z*amount)
		body._turn_bone(forearms[0],Vector3.UP,ARMS.w*amount)
		body._turn_bone(forearms[1],Vector3.UP,-ARMS.w*amount)
	var hands: Vector3 = (body.mitt(0)+body.mitt(1))*0.5
	var tilt := pitch*amount
	var f := PilotMotor.forward(float(host.motor.facing))
	var ahead := Vector3(f.x*cos(tilt),sin(tilt),f.y*cos(tilt))
	pair.global_transform = Transform3D(Basis.looking_at(ahead,Vector3.UP).scaled(Vector3.ONE*float(host.wanderer_scale)),hands+Vector3.UP*0.03*float(host.wanderer_scale))

## The pair: two short hexagonal brass barrels and a bridge, small enough
## for his mitts.
static func _make_pair() -> Node3D:
	var pair := Node3D.new()
	pair.name = "BinocularsPair"
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.74,0.56,0.27)
	brass.metallic = 0.85
	brass.roughness = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08,0.07,0.06)
	dark.roughness = 0.6
	for side in [-1.0,1.0]:
		var barrel := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.026
		mesh.bottom_radius = 0.032
		mesh.height = 0.1
		mesh.radial_segments = 6
		mesh.rings = 1
		barrel.mesh = mesh
		barrel.material_override = brass
		barrel.rotation.x = PI*0.5
		barrel.position = Vector3(side*0.034,0.0,0.0)
		pair.add_child(barrel)
		var grip := MeshInstance3D.new()
		var band := CylinderMesh.new()
		band.top_radius = 0.0335
		band.bottom_radius = 0.0335
		band.height = 0.03
		band.radial_segments = 6
		band.rings = 1
		grip.mesh = band
		grip.material_override = dark
		grip.rotation.x = PI*0.5
		grip.position = Vector3(side*0.034,0.0,0.005)
		pair.add_child(grip)
	var bridge := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04,0.014,0.03)
	bridge.mesh = box
	bridge.material_override = brass
	pair.add_child(bridge)
	return pair

func _sound(kind: String, gain: float, pitch_scale := 1.0) -> void:
	var audio: Node = host.get("audio") if host != null else null
	if audio != null and audio.has_method("shot"): audio.shot(kind,gain,pitch_scale)
