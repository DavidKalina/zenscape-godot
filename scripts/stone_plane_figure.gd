extends Node3D
## The stone plane, "A Swift" (docs/design/plane-stone.md, the Blender
## concept art/blender/plane/stone_build.py `build_A`), built procedurally
## as the wooden plane is (scripts/plane_figure.gd) and with its calls
## (`reset`, `update`, `shift`, `show_pilot`, `park`, `pose`), so a scene can
## fly one or the other (studies/aqueduct_isle.gd `--stone-plane`, its
## default there; the game's own plane is untouched).
##
## An ancient sky-builders' glider carved from the ruins' basalt: a long
## tapering shoulder wing in three slabs a side, a slim sky-boat hull broken
## either side of the heart chamber and where the boom leaves the pod, a
## cruciform tail. Every slab floats on its own: a thin gap of light between
## each, and each bobs a few millimetres out of step with its neighbours,
## so the craft breathes (`_bob`). No engine, no propeller: a lodestone
## (scripts/lodestone.gd) seated in the chamber in front of the pilot is
## why it flies (`seat`). Seated, a needle floats over it and points at the
## target, and a sync pulse ripples through the slabs from nose to tail.
## Empty, every seam and gap is dark and the slabs barely stir.
##
## The seam compass (`compass`, a straight port of stone_render.py's): the
## wing seams (a glyph channel on top, a band on the blunt trailing edge),
## the dorsal and ventral fins' trailing edges, the tailplane's, the prow's
## glyphs and the gaps, each its own glowing material at 0.15 + 9 level^2.5;
## soft ribbons behind them face the chase camera, scaled with the eye's
## distance; a few soft wisps stream from the nose toward the target.
##
## The speed cue, in place of the concept's rune ring at the nose (which
## haloed the pilot's head from the chase camera): runes of light along the
## deck, before and behind the pilot, running back along the hull faster
## the faster it flies, and flaring with the prow's glyphs on course.

const PlanePilot = preload("res://scripts/plane_pilot.gd")
const PersonKit = preload("res://scripts/person_kit.gd")
const FacetMesh = preload("res://scripts/facet_mesh.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const STONE_SHADER := preload("res://shaders/ruin_stone.gdshader")
const GLOW_SHADER := preload("res://shaders/stone_plane_glow.gdshader")
const BAND_SHADER := preload("res://shaders/stone_plane_band.gdshader")
const RUNE_SHADER := preload("res://shaders/stone_plane_runes.gdshader")
const FOLK_RIBBON := preload("res://shaders/folk_ribbon.gdshader")

## The span, as the wooden plane's (the isle's bump body is this wide).
const SPAN := 1.4
## The ruins' basalt as they are drawn now (scripts/ruin_stone_style.gd,
## its eroded look's stone and cool stone), worn tops a step paler, a
## lichen face here and there.
const STONE := Color("5a5d63")
const STONE_COOL := Color("52575f")
const EDGE := Color("7f8288")
const LICHEN := Color("8e9180")
## Pale gold (the concept's ffd896), a touch deeper so full glow, clipped
## by the tonemap, stays gold rather than white.
const GLOW := Color("ffc978")
const GLOW_WHITE := Color("fff0d6")
const BAND_GLOW := Color("ffe2a8")
const CHANNELS := ["L","R","UP","DN","BK","RING","GAP"]
## The seams' emission: CORE_FLOOR + CORE_MAX level^CURVE; the gaps' steady
## light while seated.
const CORE_MAX := 9.0
const CORE_FLOOR := 0.15
const CURVE := 2.5
const GAP_GLOW := 1.1
## The ribbons' strength at the chase distance and up close, and the eye's
## distance (m) they go from one to the other over.
const BAND_FAR := 1.6
const BAND_NEAR := 0.08
const EYE := Vector2(1.5,5.0)
## The hull's breaks lean back with height (z += SLANT y): broken, not sawn.
const SLANT := 0.3
## The pilot's seat (lower than the wooden plane's: only the head and the
## scarf show over the coaming), the heart chamber's middle, the seated
## stone's scale and the needle's height over the chamber.
const SEAT := Vector3(0.0,-0.05,0.19)
const PILOT_SCALE := 0.92
const CHAMBER := Vector3(0.0,0.012,-0.027)
const STONE_SCALE := 0.4
const NEEDLE_UP := 0.085
const NEEDLE_LENGTH := 0.13
## Seating: seconds for the stone to fly into the chamber, then for the
## sync pulse to run nose to tail (from PULSE_Z.x to PULSE_Z.y).
const SEAT_TIME := 0.9
const PULSE_TIME := 1.1
const PULSE_Z := Vector2(-0.8,0.95)
const PULSE_LIFT := 0.012
## The slabs' bob: metres up and down (wing slabs; the tail and the hull
## less), radians of tilt, and its pace (rad/s); dormant (no stone) it is
## DORMANT of that.
const BOB := 0.006
const BOB_TILT := 0.012
const BOB_RATE := Vector2(1.6,2.4)
const DORMANT := 0.25
## The runes' run back along the deck: metres a second per m/s of speed.
const RUNE_RUN := 0.06
## The wisps: strands, points each, length (m), half width (m), alpha, and
## the sweep back with speed.
const WISPS := 3
const WISP_POINTS := 24
const WISP_LENGTH := 2.4
const WISP_WIDTH := 0.022
const WISP_ALPHA := 0.55
const WISP_SWEEP := 0.7
## Seconds the levels take to follow the compass (they flow, not snap).
const FOLLOW := 0.18
## The scarf, as the wooden plane's but shorter (the pilot sits low: a long
## one lies along the boom and hides its runes).
const SCARF := 6
const SCARF_SHORT := 4
const SCARF_GAP := 0.075
const SCARF_WIDTH := 0.085
const SCARF_STRIPES := [Vector2(0.7,0.77),Vector2(0.83,0.9)]
const FLUTTER := Vector2(5.0,17.0)
const FLUTTER_REACH := 0.035
const FLUTTER_FAST := 18.0
const STRIPE := Color("f3ead6")

## True while it stands parked.
var parked := false
## The world point the compass points at (INF: none).
var target := Vector3.INF
## The lodestone seated in the chamber (null: empty), true once it has
## settled (the pulse has begun).
var stone: Node3D = null
var seated := false
## The compass levels this frame (0..1 each channel), as followed, and the
## raw ones from the target.
var levels := {}
var goal := {}
## How awake the seams are (0 dormant, 1 seated and synced).
var wake := 0.0
var _rig: Node3D
var _chamber: Node3D
var _needle: Node3D
var _needle_aim := Vector2.ZERO
var _glow := {}
var _bands := {}
var _runes: ShaderMaterial
var _stone_material: ShaderMaterial
## The floating slabs: [node, centre, phase, rate, amp, tilt axis].
var _slabs: Array = []
var _clock := 0.0
var _scroll := 0.0
var _seat_t := -1.0
var _seat_from := Vector3.ZERO
var _seat_scale := 1.0
var _pulse_t := INF
var _flash := 0.0
## The nose wisps toward the target; off by default (the user found they
## read like a spider web from the nose; the seams carry the compass).
var show_wisps := false
var _wisps: MeshInstance3D
var _wisp_mesh: ImmediateMesh
var _scarf_points := PackedVector3Array()
var _short_points := PackedVector3Array()
var _scarf: MeshInstance3D
var _scarf_mesh: ImmediateMesh
## The wooden plane's landing mark; the stone plane draws none (kept so a
## scene can hide it either way).
var _mark := Node3D.new()

func _init(_livery := {}) -> void:
	name = "StonePlane"
	for ch: String in CHANNELS:
		levels[ch] = 0.0
		goal[ch] = 0.0
	_stone_material = ShaderMaterial.new()
	_stone_material.shader = STONE_SHADER
	_stone_material.set_shader_parameter("fill",1.45)
	_stone_material.set_shader_parameter("rim",0.2)
	_stone_material.set_shader_parameter("roughness_value",0.95)
	for ch: String in CHANNELS:
		var m := ShaderMaterial.new()
		m.shader = GLOW_SHADER
		m.set_shader_parameter("glow",GLOW_WHITE if ch == "GAP" else GLOW)
		_glow[ch] = m
		var b := ShaderMaterial.new()
		b.shader = BAND_SHADER
		b.set_shader_parameter("glow",BAND_GLOW)
		_bands[ch] = b
	_runes = ShaderMaterial.new()
	_runes.shader = RUNE_SHADER
	_build()
	_rig = PlanePilot.new(PersonKit.outfit())
	_rig.position = SEAT
	_rig.scale = Vector3.ONE*PILOT_SCALE*WorldScale.pilot_size
	add_child(_rig)
	_chamber = Node3D.new()
	_chamber.name = "Chamber"
	_chamber.position = CHAMBER
	add_child(_chamber)
	_needle = _build_needle()
	_needle.position = Vector3(0.0,NEEDLE_UP,0.0)
	_needle.visible = false
	_chamber.add_child(_needle)
	_wisp_mesh = ImmediateMesh.new()
	_wisps = MeshInstance3D.new()
	_wisps.name = "Wisps"
	_wisps.mesh = _wisp_mesh
	_wisps.top_level = true
	var wisp := StandardMaterial3D.new()
	wisp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wisp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wisp.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	wisp.vertex_color_use_as_albedo = true
	wisp.albedo_texture = FacetMesh.soft_band()
	wisp.cull_mode = BaseMaterial3D.CULL_DISABLED
	wisp.disable_fog = true
	_wisps.material_override = wisp
	_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wisps.visible = false
	add_child(_wisps)
	_scarf_mesh = ImmediateMesh.new()
	_scarf = MeshInstance3D.new()
	_scarf.mesh = _scarf_mesh
	_scarf.top_level = true
	var scarf_material := ShaderMaterial.new()
	scarf_material.shader = FOLK_RIBBON
	scarf_material.set_shader_parameter("roughness_value",0.95)
	scarf_material.set_meta("scarf",Color("d9573a"))
	_scarf.material_override = scarf_material
	_scarf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_scarf)
	_mark.visible = false
	add_child(_mark)
	_apply_glow(0.0)

# --- As the wooden plane ------------------------------------------------------

## Starts the scarf streaming straight back from where it is now.
func reset(glide: RefCounted) -> void:
	parked = false
	show_pilot(true)
	_scarf_points.resize(SCARF)
	_short_points.resize(SCARF_SHORT)
	var back: Vector3 = -glide.forward()
	for i in range(SCARF): _scarf_points[i] = glide.position+back*SCARF_GAP*i
	for i in range(SCARF_SHORT): _short_points[i] = glide.position+back*SCARF_GAP*i
	update(0.0,glide,0.0,Callable(),false)

## The world moved under it: the scarf goes too.
func shift(by: Vector3) -> void:
	for i in range(_scarf_points.size()): _scarf_points[i] += by
	for i in range(_short_points.size()): _short_points[i] += by

## One frame, as the wooden plane's: posed on `glide`; the slabs bob, the
## stone settles and syncs, the compass points at `target`, the runes run.
func update(delta: float, glide: RefCounted, _dive: float, _ground: Callable, _landable: bool, _near := 0.0, _lean := 0.0) -> void:
	var roll := _roll(glide)
	transform = pose(glide.position,float(glide.heading),float(glide.pitch),roll)
	var spin: Variant = glide.get("spin")
	var throttle: Variant = glide.get("throttle")
	if _rig.visible and delta > 0.0:
		_rig.animate(delta,float(glide.bank),float(glide.pitch),0.0,0.0,float(throttle) if throttle != null else 0.0,float(spin) if spin != null else 0.0,0.0)
	_clock += delta
	_settle(delta)
	_point(delta)
	var pace := float(glide.speed)
	_scroll += delta*pace*RUNE_RUN
	_runes.set_shader_parameter("scroll",_scroll)
	_runes.set_shader_parameter("streak",clampf((pace-14.0)/10.0,0.0,1.0))
	_apply_glow(pace)
	_bob(delta)
	_trail_scarf(delta,glide)
	_draw_wisps(glide)

## The pilot in the cockpit, or not.
func show_pilot(on: bool) -> void:
	_rig.visible = on
	_scarf.visible = on

## Where the figure stands for a flight's pose (as the wooden plane's).
static func pose(at: Vector3, heading: float, pitch: float, roll: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch,heading,-roll)),at+Vector3.DOWN*0.2)

## Stands it parked: the pilot out, no scarf or wisps.
func park(placed: Transform3D) -> void:
	parked = true
	transform = placed
	show_pilot(false)
	_wisps.visible = false

func _roll(glide: RefCounted) -> float:
	var spin: Variant = glide.get("spin")
	return float(glide.bank)+(float(spin) if spin != null else 0.0)

# --- The lodestone, the needle and the compass -----------------------------------

## Seats `lode` (a Lodestone) in the chamber: it flies there from where it
## is now over SEAT_TIME s, then the sync pulse runs nose to tail and the
## seams wake.
func seat(lode: Node3D) -> void:
	if stone != null: return
	var from := lode.global_position if lode.is_inside_tree() else global_position
	_seat_scale = lode.scale.x
	if lode.get_parent() != null: lode.get_parent().remove_child(lode)
	_chamber.add_child(lode)
	lode.position = _chamber.global_transform.affine_inverse()*from if is_inside_tree() else Vector3(0.0,0.6,0.6)
	_seat_from = lode.position
	lode.rotation = Vector3.ZERO
	if lode.has_method("show_light"): lode.show_light(false)
	lode.set("hum_goal",1.0)
	lode.set("stream_goal",0.0)
	stone = lode
	seated = false
	_seat_t = 0.0

## Takes the stone out (the pilot hops out with it): returns it, unparented.
func unseat() -> Node3D:
	var lode := stone
	if lode == null: return null
	_chamber.remove_child(lode)
	stone = null
	seated = false
	_seat_t = -1.0
	_pulse_t = INF
	_needle.visible = false
	return lode

## True while the stone is flying into the chamber or the pulse runs.
func syncing() -> bool:
	return (_seat_t >= 0.0 and not seated) or _pulse_t < PULSE_TIME

## Arrived: every seam flares and the pulse runs again.
func flash() -> void:
	_flash = 1.0
	_pulse_t = 0.0

func _settle(delta: float) -> void:
	if stone != null and not seated and _seat_t >= 0.0:
		_seat_t += delta
		var t := smoothstep(0.0,1.0,clampf(_seat_t/SEAT_TIME,0.0,1.0))
		var arc := _seat_from.lerp(Vector3.ZERO,t)+Vector3.UP*sin(t*PI)*0.25
		stone.position = arc
		stone.scale = Vector3.ONE*lerpf(_seat_scale,STONE_SCALE,t)
		if _seat_t >= SEAT_TIME:
			seated = true
			_pulse_t = 0.0
			stone.position = Vector3.ZERO
			stone.set("hum_goal",0.7)
	if stone != null and seated:
		stone.position = Vector3(0.0,sin(_clock*1.7)*0.004,0.0)
	if _pulse_t < INF: _pulse_t += delta
	var awake := 1.0 if seated else 0.0
	# The seams wake behind the pulse's front.
	if seated and _pulse_t < PULSE_TIME: awake = smoothstep(0.0,PULSE_TIME,_pulse_t)
	wake = move_toward(wake,awake,delta*2.0) if awake < wake else awake
	_flash = maxf(_flash-delta/1.6,0.0)
	_needle.visible = seated

## The compass from the target, followed; the needle turned to it.
func _point(delta: float) -> void:
	var d := Vector3.ZERO
	if target != Vector3.INF:
		d = global_transform.basis.orthonormalized().inverse()*(target-global_position)
	var raw := compass(d) if seated and d.length() > 0.01 else {}
	var k := 1.0-exp(-delta/FOLLOW) if delta > 0.0 else 1.0
	for ch: String in CHANNELS:
		goal[ch] = float(raw.get(ch,0.0))
		levels[ch] = lerpf(float(levels[ch]),float(goal[ch]),k)
	if seated and d.length() > 0.01:
		var n := d.normalized()
		var aim := Vector2(atan2(-n.x,-n.z),asin(clampf(n.y,-1.0,1.0)))
		var kn := 1.0-exp(-delta/0.25) if delta > 0.0 else 1.0
		_needle_aim.x = lerp_angle(_needle_aim.x,aim.x,kn)
		_needle_aim.y = lerpf(_needle_aim.y,aim.y,kn)
		_needle.basis = Basis.from_euler(Vector3(_needle_aim.y,_needle_aim.x,0.0))
		_needle.position = Vector3(0.0,NEEDLE_UP+sin(_clock*2.3)*0.004,0.0)

## The seam compass, from the target's direction `d` in the plane's frame
## (+X right, +Y up, -Z ahead): a level 0..1 per channel. Ported as is from
## art/blender/plane/stone_render.py `compass` (docs/design/plane-stone.md).
##   L, R   both 0.3 on course; the side toward the target rises to 1 by 30
##          degrees off while the other falls toward 0.05; behind (|b| > 90),
##          the turn side is full, the other dark;
##   UP/DN  0 to 1 over 0 to 30 degrees above or below;
##   BK     0 at 90 degrees off, 1 at 135 and beyond (the tail lights);
##   RING   0.35, flaring to 1 within 12 degrees of dead ahead (the prow);
##   GAP    a steady 0.6 while a stone is seated.
static func compass(d: Vector3) -> Dictionary:
	var b := atan2(d.x,-d.z)
	var e := atan2(d.y,Vector2(d.x,d.z).length())
	var ab := absf(b)
	var base := 0.3
	var near := 1.0
	var far := 0.0
	if ab <= PI*0.5:
		var t := minf(1.0,ab/deg_to_rad(30.0))
		near = base+(1.0-base)*t
		far = base*(1.0-t)+0.05*t
	var out := {"L":near if b < 0.0 else far,"R":near if b >= 0.0 else far}
	out["UP"] = clampf(e/deg_to_rad(30.0),0.0,1.0)
	out["DN"] = clampf(-e/deg_to_rad(30.0),0.0,1.0)
	out["BK"] = clampf((ab-PI*0.5)/deg_to_rad(45.0),0.0,1.0)
	var on := maxf(0.0,1.0-Vector2(b,e).length()/deg_to_rad(12.0))
	out["RING"] = 0.35+0.65*on
	out["GAP"] = 0.6
	return out

## A channel's seam emission at `level` (0 when no stone is seated).
static func energy(level: float) -> float:
	return CORE_FLOOR+CORE_MAX*pow(clampf(level,0.0,1.0),CURVE)

## The seams' and the ribbons' light, the runes', and the pulse.
func _apply_glow(pace: float) -> void:
	var eye := _eye_distance()
	var band_k := lerpf(BAND_NEAR,BAND_FAR,smoothstep(EYE.x,EYE.y,eye))
	var front := lerpf(PULSE_Z.x,PULSE_Z.y,clampf(_pulse_t/PULSE_TIME,0.0,1.0)) if _pulse_t < PULSE_TIME else -10.0
	var amp := 1.0 if _pulse_t < PULSE_TIME else 0.0
	for ch: String in CHANNELS:
		var level := float(levels[ch])
		var e := GAP_GLOW*wake if ch == "GAP" else energy(level)*wake
		e += _flash*(4.0 if ch != "GAP" else 2.0)
		var m: ShaderMaterial = _glow[ch]
		m.set_shader_parameter("energy",e)
		m.set_shader_parameter("pulse_front",front)
		m.set_shader_parameter("pulse_amp",amp)
		var k := 0.35 if ch == "GAP" else pow(level,CURVE)
		(_bands[ch] as ShaderMaterial).set_shader_parameter("strength",band_k*(k*wake+_flash*0.8))
	var ring := float(levels.RING)
	var run := wake*(0.5+0.5*clampf(pace/22.0,0.0,1.0)+2.2*pow(ring,CURVE))+_flash*2.0
	_runes.set_shader_parameter("energy",run)
	_runes.set_shader_parameter("pulse_front",front)
	_runes.set_shader_parameter("pulse_amp",amp)

func _eye_distance() -> float:
	if not is_inside_tree(): return EYE.y
	var camera := get_viewport().get_camera_3d()
	return camera.global_position.distance_to(global_position) if camera != null else EYE.y

## Each slab bobs and tilts a little on its own, out of step with its
## neighbours (barely, dormant); the pulse lifts each as it passes.
func _bob(_delta: float) -> void:
	var live := lerpf(DORMANT,1.0,wake)
	var front := lerpf(PULSE_Z.x,PULSE_Z.y,clampf(_pulse_t/PULSE_TIME,0.0,1.0)) if _pulse_t < PULSE_TIME else INF
	for s: Array in _slabs:
		var node: Node3D = s[0]
		var centre: Vector3 = s[1]
		var phase: float = s[2]
		var rate: float = s[3]
		var amp: float = s[4]
		var axis: Vector3 = s[5]
		var a := _clock*rate+phase
		var lift := sin(a)*amp*BOB*live
		if front < INF:
			var dz := (centre.z-front)/0.15
			lift += PULSE_LIFT*exp(-dz*dz)
		var turn := Basis(axis,sin(a*0.83+1.1)*BOB_TILT*amp*live)
		node.transform = Transform3D(turn,centre-turn*centre+Vector3.UP*lift)

## The wisps: soft strands from the nose toward the target, curling round
## each other, swept back with the speed; stronger the further the eye.
func _draw_wisps(glide: RefCounted) -> void:
	var strength := wake*smoothstep(EYE.x,EYE.y,_eye_distance())
	if not show_wisps or target == Vector3.INF or not seated or strength < 0.01 or not is_inside_tree():
		_wisps.visible = false
		return
	var nose := global_transform*Vector3(0.0,0.03,-0.66)
	var way := target-nose
	var far := way.length()
	if far < 0.5:
		_wisps.visible = false
		return
	way /= far
	strength *= smoothstep(15.0,60.0,far)
	_wisps.visible = strength > 0.01
	if not _wisps.visible: return
	var forward: Vector3 = glide.forward() if glide.has_method("forward") else -global_basis.z
	var side := way.cross(Vector3.UP)
	if side.length() < 0.1: side = global_basis.x
	side = side.normalized()
	var up := side.cross(way).normalized()
	var sweep := WISP_SWEEP*clampf(float(glide.speed)/14.0,0.3,1.6)
	var camera := get_viewport().get_camera_3d()
	_wisp_mesh.clear_surfaces()
	for w in range(WISPS):
		var phase := TAU*float(w)/WISPS
		_wisp_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var points: Array[Vector3] = []
		for i in range(WISP_POINTS):
			var t := float(i)/(WISP_POINTS-1)
			var curl := t*6.0+phase-_clock*3.0
			var p := nose+way*WISP_LENGTH*t-forward*sweep*t*t
			p += (side*sin(curl)*0.06+up*cos(curl)*0.04)*t
			points.append(p)
		for i in range(WISP_POINTS):
			var t := float(i)/(WISP_POINTS-1)
			var along := points[mini(i+1,WISP_POINTS-1)]-points[maxi(i-1,0)]
			var across := up
			if camera != null:
				var c := along.cross(camera.global_position-points[i])
				if c.length_squared() > 1e-8: across = c.normalized()
			var half := WISP_WIDTH*sqrt(maxf(1.0-t,0.0))*minf(1.0,t*8.0+0.3)+0.003
			var c := Color(1.0,0.94,0.8,strength*WISP_ALPHA*smoothstep(0.0,0.15,t)*(1.0-t))
			_wisp_mesh.surface_set_color(c)
			_wisp_mesh.surface_set_uv(Vector2(0.0,t))
			_wisp_mesh.surface_add_vertex(points[i]-across*half)
			_wisp_mesh.surface_set_color(c)
			_wisp_mesh.surface_set_uv(Vector2(1.0,t))
			_wisp_mesh.surface_add_vertex(points[i]+across*half)
		_wisp_mesh.surface_end()

# --- The scarf (as the wooden plane's) ---------------------------------------------

func _trail_scarf(delta: float, glide: RefCounted) -> void:
	if _scarf_points.size() != SCARF or not _scarf.visible: return
	var knot: Vector3 = transform*_rig.knot()
	var side := basis.x.normalized()
	var up := basis.y.normalized()
	var fast := clampf(float(glide.speed)/FLUTTER_FAST,0.0,1.0)
	var wind: Vector3 = glide.velocity
	_drag_tail(_scarf_points,knot-side*0.012,wind,delta,fast)
	_drag_tail(_short_points,knot+side*0.014,wind,delta,fast)
	var t := Time.get_ticks_msec()*0.001
	var rate := lerpf(FLUTTER.x,FLUTTER.y,fast)
	var color: Color = _scarf.material_override.get_meta("scarf",Color("d9573a"))
	_scarf_mesh.clear_surfaces()
	_draw_tail(_scarf_points,side,up,t*rate,fast,1.0,color)
	_draw_tail(_short_points,side,up,t*rate*1.13+1.7,fast,0.85,color)

func _drag_tail(points: PackedVector3Array, root: Vector3, wind: Vector3, delta: float, fast: float) -> void:
	points[0] = root
	for i in range(1,points.size()):
		var p := points[i]-wind*delta*0.15+Vector3.DOWN*delta*0.5*(1.0-fast)
		var d := p-points[i-1]
		if d.length() > 0.0001: p = points[i-1]+d.normalized()*SCARF_GAP
		points[i] = p

func _draw_tail(points: PackedVector3Array, side: Vector3, up: Vector3, phase: float, fast: float, wide: float, color: Color) -> void:
	var last := float(points.size()-1)
	var reach := FLUTTER_REACH*lerpf(0.35,1.0,fast)
	_scarf_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var u := float(i)
		var p := points[i]
		var along := (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var tip := pow(u/last,1.3)
		var wave := phase-u*1.1
		p += side*sin(wave)*reach*tip+up*sin(wave*0.8+1.3)*reach*0.6*tip
		var across := side.rotated(along,sin(wave+0.6)*0.7*tip) if along.length_squared() > 0.5 else side
		var normal := across.cross(along).normalized()
		var f := u/last
		var c := color
		for stripe: Vector2 in SCARF_STRIPES:
			if f >= stripe.x and f < stripe.y: c = STRIPE
		var w := SCARF_WIDTH*wide*(1.0-0.4*f)*0.5
		for e in [-1.0,1.0]:
			_scarf_mesh.surface_set_color(c)
			_scarf_mesh.surface_set_normal(normal)
			_scarf_mesh.surface_add_vertex(p+across*e*w)
	_scarf_mesh.surface_end()

# --- Building -----------------------------------------------------------------------

## Gathers triangles per surface ("stone", "seam:<channel>", "runes",
## "band:<channel>"), each face flat, the stone coloured face by face as
## the ruin kit colours its blocks.
class Mesher extends RefCounted:
	var surfaces := {}
	var rng := RandomNumberGenerator.new()

	func _init(seed_value: int) -> void:
		rng.seed = seed_value

	func _surface(key: String) -> Dictionary:
		if not surfaces.has(key):
			surfaces[key] = {"v":PackedVector3Array(),"n":PackedVector3Array(),"c":PackedColorArray(),"uv":PackedVector2Array()}
		return surfaces[key]

	## Sections (each a PackedVector3Array, the same count) lofted in turn,
	## capped at both ends, placed by `xf`; wound outward whatever the
	## sections' turn (by the solid's signed volume).
	func loft(key: String, sections: Array, xf := Transform3D.IDENTITY, cap := true) -> void:
		var rings := []
		for s: PackedVector3Array in sections:
			var r := PackedVector3Array()
			for p in s: r.append(xf*p)
			rings.append(r)
		var n: int = (rings[0] as PackedVector3Array).size()
		var tris := []
		for k in range(rings.size()-1):
			var r0: PackedVector3Array = rings[k]
			var r1: PackedVector3Array = rings[k+1]
			for i in range(n):
				var j := (i+1)%n
				tris.append([r0[i],r0[j],r1[j]])
				tris.append([r0[i],r1[j],r1[i]])
		if cap:
			for end in [0,rings.size()-1]:
				var r: PackedVector3Array = rings[end]
				var c := Vector3.ZERO
				for p in r: c += p
				c /= r.size()
				for i in range(n):
					var j := (i+1)%n
					if end == 0: tris.append([c,r[j],r[i]])
					else: tris.append([c,r[i],r[j]])
		var volume := 0.0
		for t: Array in tris: volume += (t[0] as Vector3).dot((t[1] as Vector3).cross(t[2]))
		add(key,tris,volume < 0.0)

	## Triangles wound outward (counter-clockwise from outside; `flip` if
	## not), stored as Godot draws them, each flat.
	func add(key: String, tris: Array, flip := false) -> void:
		var s := _surface(key)
		var stone := key == "stone"
		for t: Array in tris:
			var a: Vector3 = t[0]
			var b: Vector3 = t[2] if flip else t[1]
			var c: Vector3 = t[1] if flip else t[2]
			var normal := (b-a).cross(c-a)
			if normal.length_squared() < 1e-14: continue
			normal = normal.normalized()
			var colour := _face(normal) if stone else Color.WHITE
			for p in [a,c,b]:
				s.v.append(p)
				s.n.append(normal)
				s.c.append(colour)
				s.uv.append(Vector2.ZERO)

	## A face's colour (linear), as the ruin kit's: worn tops toward EDGE,
	## the odd lichen face, undersides darker, each facet its own step.
	func _face(normal: Vector3) -> Color:
		var up := normal.y
		var base := STONE.lerp(STONE_COOL,rng.randf()).srgb_to_linear()
		var c := base.lerp(EDGE.srgb_to_linear(),clampf(maxf(0.0,up)*0.3*rng.randf_range(0.5,1.3)+rng.randf_range(0.0,0.15),0.0,1.0))
		if rng.randf() < 0.08 and up > 0.2: c = c.lerp(LICHEN.srgb_to_linear(),rng.randf_range(0.25,0.45))
		if up < -0.4: c *= 0.78
		c *= rng.randf_range(0.84,1.12)
		return Color(c.r,c.g,c.b,1.0)

	## A flat strip through `points`, `across` (per point or one) its width
	## way, UV.x running 0..1 along (or `metres`: the length from `from`).
	func strip(key: String, points: Array, across: Variant, width: float, metres := false, from := 0.0) -> void:
		var s := _surface(key)
		var run := from
		for i in range(points.size()-1):
			var p0: Vector3 = points[i]
			var p1: Vector3 = points[i+1]
			var a0: Vector3 = (across[i] if across is Array else across)*width*0.5
			var a1: Vector3 = (across[i+1] if across is Array else across)*width*0.5
			var u0 := run if metres else float(i)/(points.size()-1)
			var u1 := run+p0.distance_to(p1) if metres else float(i+1)/(points.size()-1)
			run += p0.distance_to(p1)
			var normal := (p1-p0).cross(a0).normalized()
			for q in [[p0-a0,Vector2(u0,0.0)],[p1-a1,Vector2(u1,0.0)],[p1+a1,Vector2(u1,1.0)],[p0-a0,Vector2(u0,0.0)],[p1+a1,Vector2(u1,1.0)],[p0+a0,Vector2(u0,1.0)]]:
				s.v.append(q[0])
				s.n.append(normal)
				s.c.append(Color.WHITE)
				s.uv.append(q[1])

	## A small box (glyph) of `size` placed by `xf`.
	func box(key: String, size: Vector3, xf: Transform3D) -> void:
		var h := size*0.5
		var a := PackedVector3Array([Vector3(-h.x,-h.y,-h.z),Vector3(h.x,-h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(-h.x,h.y,-h.z)])
		var b := PackedVector3Array([Vector3(-h.x,-h.y,h.z),Vector3(h.x,-h.y,h.z),Vector3(h.x,h.y,h.z),Vector3(-h.x,h.y,h.z)])
		loft(key,[a,b],xf)

	## A small carved dot: an octahedron of `radius`, squashed by `squash`.
	func gem(key: String, radius: float, at: Vector3, squash := Vector3.ONE) -> void:
		var axes := [Vector3(radius*squash.x,0,0),Vector3(0,radius*squash.y,0),Vector3(0,0,radius*squash.z)]
		var tris := []
		for sx in [-1.0,1.0]:
			for sy in [-1.0,1.0]:
				for sz in [-1.0,1.0]:
					var p: Vector3 = at+axes[0]*sx
					var q: Vector3 = at+axes[1]*sy
					var r: Vector3 = at+axes[2]*sz
					var t := [p,q,r]
					if (p-at).cross(q-at).dot(r-at) < 0.0: t = [p,r,q]
					tris.append(t)
		add(key,tris)

	func mesh(materials: Dictionary) -> ArrayMesh:
		var out := ArrayMesh.new()
		for key: String in surfaces:
			var s: Dictionary = surfaces[key]
			if (s.v as PackedVector3Array).is_empty(): continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = s.v
			arrays[Mesh.ARRAY_NORMAL] = s.n
			arrays[Mesh.ARRAY_COLOR] = s.c
			arrays[Mesh.ARRAY_TEX_UV] = s.uv
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			out.surface_set_material(out.get_surface_count()-1,materials.get(key))
		return out

func _materials() -> Dictionary:
	var out := {"stone":_stone_material,"runes":_runes}
	for ch: String in CHANNELS:
		out["seam:"+ch] = _glow[ch]
		out["band:"+ch] = _bands[ch]
	return out

## A slab's or hull piece's mesh, floating on its own node (bobbing about
## `centre`; `amp` its share of the bob, `axis` its tilt's).
func _float(m: Mesher, label: String, centre: Vector3, amp: float, axis: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = m.mesh(_materials())
	add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(label)
	# Neighbours a little out of step: the phase follows the place, jittered.
	var phase := centre.x*3.1+centre.z*2.3+rng.randf_range(-0.6,0.6)
	_slabs.append([node,centre,phase,rng.randf_range(BOB_RATE.x,BOB_RATE.y),amp,axis])

## A still part (the gaps, the ribbons) on the figure itself.
func _still(m: Mesher, label: String, shadows := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = m.mesh(_materials())
	if not shadows: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

## A faceted slab's section at `x`: a blunt leading edge, a flat-ish carved
## top, a blunt trailing edge (its rear face carries the seam), a keel line.
static func section(x: float, y: float, le: float, c: float, th: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(x,y,le),Vector3(x,y+th*0.85,le+0.16*c),Vector3(x,y+th*0.7,le+0.6*c),
		Vector3(x,y+th*0.28,le+c),Vector3(x,y-th*0.12,le+c),Vector3(x,y-th*0.42,le+0.32*c)])

## A wing-like slab through stations `xs`, `sec` (x → Vector4(y, le, chord,
## thick)) its sections, placed by `xf`: the stone, and for channel `ch` a
## band on the rear face, a glyph channel on top (dash, dot, dash) and a
## soft ribbon behind the rear face into `bands`.
func _slab(m: Mesher, bands: Mesher, xs: Array, sec: Callable, xf: Transform3D, ch: String, glyph: bool, band_w: float, glyph_u := 0.42) -> void:
	var secs := []
	for i in range(xs.size()):
		var x: float = xs[i]
		var s: Vector4 = sec.call(x)
		var le := s.y
		if i == 0 or i == xs.size()-1: le += m.rng.randf_range(-0.004,0.004)
		secs.append(section(x,s.x,le,s.z,s.w))
	m.loft("stone",secs,xf)
	if ch == "": return
	var key := "seam:"+ch
	var band_secs := []
	var points := []
	for x: float in xs:
		var s: Vector4 = sec.call(x)
		var z := s.y+s.z+0.0012
		band_secs.append(PackedVector3Array([Vector3(x,s.x-s.w*0.05,z),Vector3(x,s.x+s.w*0.21,z),Vector3(x,s.x+s.w*0.21,z+0.003),Vector3(x,s.x-s.w*0.05,z+0.003)]))
		points.append(xf*Vector3(x,s.x+s.w*0.08,s.y+s.z+0.006))
	m.loft(key,band_secs,xf)
	if band_w > 0.0: bands.strip("band:"+ch,points,(xf.basis*Vector3.UP).normalized(),band_w)
	if not glyph: return
	var x0: float = xs[0]
	var x1: float = xs[-1]
	var n := maxi(1,int(absf(x1-x0)/0.06))
	var step := (x1-x0)/n
	for k in range(n):
		var a := x0+step*(k+0.12)
		var b := x0+step*(k+0.88)
		var run := []
		for x in [a,(a+b)*0.5,b]:
			var s: Vector4 = sec.call(x)
			var yt := s.x+s.w*0.76+0.0008
			var z := s.y+glyph_u*s.z
			var w := 0.006+0.004*(s.z/0.25)
			run.append(PackedVector3Array([Vector3(x,yt-0.002,z-w),Vector3(x,yt-0.002,z+w),Vector3(x,yt+0.0015,z+w),Vector3(x,yt+0.0015,z-w)]))
		m.loft(key,run,xf)
		if k < n-1:
			var xm := x0+step*(k+1)
			var s: Vector4 = sec.call(xm)
			m.gem(key,0.0045,xf*Vector3(xm,s.x+s.w*0.76+0.0005,s.y+glyph_u*s.z),Vector3(1.0,0.45,1.0))

## The light in a gap between two slabs at `x`: a thin plate, inset.
func _gap(m: Mesher, x: float, sec: Callable, xf: Transform3D, w := 0.004) -> void:
	var s: Vector4 = sec.call(x)
	var p := section(0.0,s.x,s.y,s.z,s.w)
	var mid := Vector3.ZERO
	for q in p: mid += q
	mid /= p.size()
	var secs := []
	for xx in [x-w,x+w]:
		var ring := PackedVector3Array()
		for q in p: ring.append(Vector3(xx,mid.y+(q.y-mid.y)*0.82,mid.z+(q.z-mid.z)*0.82))
		secs.append(ring)
	m.loft("seam:GAP",secs,xf)

## A carved hull's section at `z`: a flat deck, chined sides, a sharp keel.
static func keel_section(z: float, hw: float, top: float, bot: float, rng: RandomNumberGenerator = null, j := 0.0) -> PackedVector3Array:
	var pts := [Vector2(-0.55*hw,top),Vector2(0.55*hw,top),Vector2(hw,0.3*top),Vector2(0.6*hw,0.55*bot),Vector2(0.0,bot),Vector2(-0.6*hw,0.55*bot),Vector2(-hw,0.3*top)]
	var out := PackedVector3Array()
	for p: Vector2 in pts:
		var q := p
		if rng != null: q = Vector2(p.x*(1.0+rng.randf_range(-j,j)),p.y*(1.0+rng.randf_range(-j,j)))
		out.append(Vector3(q.x,q.y,z))
	return out

static func _slanted(s: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in s: out.append(Vector3(p.x,p.y,p.z+SLANT*p.y))
	return out

## A hull piece lofted through `prof` [(z, half width, deck, keel)], its
## ends slanted like a break where `cut` says.
func _keel(m: Mesher, prof: Array, cut := [true,true]) -> void:
	var secs := []
	for p: Array in prof: secs.append(keel_section(p[0],maxf(p[1],1e-4),p[2],p[3],m.rng,0.04))
	if cut[0]: secs[0] = _slanted(secs[0])
	if cut[1]: secs[-1] = _slanted(secs[-1])
	m.loft("stone",secs)

func _keel_gap(m: Mesher, z: float, hw: float, top: float, bot: float) -> void:
	var secs := []
	for zz in [z-0.004,z+0.004]: secs.append(_slanted(keel_section(zz,hw*0.8,top*0.8,bot*0.8)))
	m.loft("seam:GAP",secs)

## The heart chamber: a keel piece open over the top, a U of stone.
func _trough(m: Mesher, z0: float, z1: float, hw: float, top: float, bot: float, wall := 0.022) -> void:
	var outer := [Vector2(hw*0.9,top*0.85),Vector2(hw,0.3*top),Vector2(0.6*hw,0.55*bot),Vector2(0.0,bot),Vector2(-0.6*hw,0.55*bot),Vector2(-hw,0.3*top),Vector2(-hw*0.9,top*0.85)]
	var inner := []
	for i in range(outer.size()-1,-1,-1):
		var p: Vector2 = outer[i]
		var x := p.x-signf(p.x)*wall if absf(p.x) > wall else 0.0
		var y := maxf(p.y+wall*1.1,bot+wall*1.4) if p.y < 0.0 else p.y
		inner.append(Vector2(x,y))
	var poly := outer+inner
	var secs := []
	for z in [z0,z1]:
		var ring := PackedVector3Array()
		for p: Vector2 in poly: ring.append(Vector3(p.x,p.y,z+SLANT*p.y))
		secs.append(ring)
	m.loft("stone",secs)

## A carved stone coaming round the pilot's head.
func _rim(m: Mesher, y: float, z: float, rx: float, rz: float) -> void:
	var secs := []
	var n := 12
	for i in range(n+1):
		var a := TAU*i/n
		var cc := cos(a)
		var ss := sin(a)
		secs.append(PackedVector3Array([Vector3(cc*rx,y-0.012,z+ss*rz),Vector3(cc*(rx+0.018),y-0.012,z+ss*(rz+0.018)),
			Vector3(cc*(rx+0.014),y+0.01,z+ss*(rz+0.014)),Vector3(cc*rx,y+0.01,z+ss*rz)]))
	m.loft("stone",secs,Transform3D.IDENTITY,false)

## Runes along a hull piece's deck: a strip just over it at `x` across
## (fraction of the half width) from `prof`'s first station to its last.
func _deck_runes(m: Mesher, prof: Array, x: float, from: float, to: float, width := 0.012) -> void:
	var points := []
	var steps := 16
	for i in range(steps+1):
		var z := lerpf(from,to,float(i)/steps)
		var k := 0
		while k < prof.size()-2 and z > float(prof[k+1][0]): k += 1
		var a: Array = prof[k]
		var b: Array = prof[k+1]
		var t := clampf((z-float(a[0]))/maxf(float(b[0])-float(a[0]),1e-5),0.0,1.0)
		var hw := lerpf(float(a[1]),float(b[1]),t)
		var top := lerpf(float(a[2]),float(b[2]),t)
		points.append(Vector3(x*0.55*hw,top*0.96+0.004,z))
	m.strip("runes",points,Vector3.RIGHT,width,true,from+0.7)

## The prow's glyphs (the compass's RING: they flare dead ahead): bars and
## pairs of dots round the hull's section at `z`, and a soft ribbon round
## it facing back.
func _prow_glyphs(m: Mesher, bands: Mesher, z: float, hw: float, top: float, bot: float) -> void:
	var s := keel_section(z,hw*1.04,top*1.04+0.002,bot*1.04)
	var n := s.size()
	var ribbon := []
	var across := []
	for i in range(n+1):
		var p := s[i%n]
		var q := s[(i+1)%n]
		var mid := (p+q)*0.5
		var tangent := (q-p).normalized()
		var out := Vector3(tangent.y,-tangent.x,0.0)
		if out.dot(mid-Vector3(0.0,(top+bot)*0.5,z)) < 0.0: out = -out
		if i < n:
			var xf := Transform3D(Basis(tangent,out,Vector3.BACK),mid+out*0.001)
			if i%2 == 0: m.box("seam:RING",Vector3(minf(0.02,(q-p).length()*0.6),0.003,0.006),xf)
			else:
				for d in [-0.006,0.006]: m.box("seam:RING",Vector3(0.005,0.003,0.005),xf*Transform3D(Basis(),Vector3(d,0.0,0.0)))
		ribbon.append(p+(p-Vector3(0.0,(top+bot)*0.5,z)).normalized()*0.012+Vector3(0.0,0.0,0.004))
		across.append((p-Vector3(0.0,(top+bot)*0.5,z)).normalized())
	bands.strip("band:RING",ribbon,across,0.022)

## The Swift, as stone_build.py `build_A` lays it out.
func _build() -> void:
	var bands := Mesher.new(7)
	var gaps := Mesher.new(8)
	# The hull: a sailplane's pod and boom, carved, the pod deepest under the
	# heart, rising to a raised prow; broken across the heart chamber (a gap
	# of light either side) and again where the boom leaves the pod.
	var prow_prof := [[-0.67,0.004,0.04,0.025],[-0.61,0.034,0.064,-0.03],[-0.49,0.062,0.078,-0.082],[-0.3,0.078,0.082,-0.108],[-0.115,0.082,0.082,-0.116]]
	var prow := Mesher.new(1)
	_keel(prow,prow_prof,[false,true])
	_prow_glyphs(prow,bands,-0.53,0.055,0.071,-0.062)
	for x in [-1.0,1.0]: _deck_runes(prow,prow_prof,x,-0.5,-0.15)
	_float(prow,"Prow",Vector3(0.0,0.0,-0.38),0.35,Vector3.RIGHT)
	_keel_gap(gaps,-0.107,0.082,0.082,-0.116)
	var trough := Mesher.new(2)
	_trough(trough,-0.098,0.045,0.082,0.082,-0.116)
	_float(trough,"Chamber",Vector3(0.0,-0.02,-0.027),0.3,Vector3.RIGHT)
	_keel_gap(gaps,0.054,0.082,0.082,-0.112)
	var mid := Mesher.new(3)
	_keel(mid,[[0.063,0.082,0.082,-0.11],[0.2,0.074,0.078,-0.085],[0.33,0.046,0.064,-0.045]])
	_rim(mid,0.084,0.19,0.07,0.085)
	_float(mid,"Cockpit",Vector3(0.0,0.0,0.2),0.15,Vector3.RIGHT)
	_keel_gap(gaps,0.34,0.044,0.062,-0.042)
	var boom_prof := [[0.35,0.04,0.06,-0.038],[0.55,0.025,0.05,-0.016],[0.78,0.014,0.042,-0.003],[0.83,0.003,0.038,0.0]]
	var boom := Mesher.new(4)
	_keel(boom,boom_prof,[true,false])
	_deck_runes(boom,boom_prof,0.0,0.38,0.76,0.014)
	_float(boom,"Boom",Vector3(0.0,0.02,0.6),0.45,Vector3.RIGHT)
	# The wing: long and tapering, three slabs a side, a little dihedral
	# rising toward the tips, the tips swept and pointed.
	var sec := func(x: float) -> Vector4:
		var t := minf(1.0,absf(x)/0.7)
		var y := 0.05+0.055*t+0.05*pow(maxf(0.0,t-0.7),1.5)
		var le := -0.125+0.13*pow(t,1.6)
		var c := 0.27-0.2*pow(t,1.3)
		if t > 0.9: c *= sqrt(maxf(0.0,1.0-pow((t-0.9)/0.1,2.0)))*0.8+0.2
		return Vector4(y,le,c,0.034-0.022*t)
	var slabs := [Vector2(0.088,0.3),Vector2(0.314,0.52),Vector2(0.534,0.7)]
	var mirror := Transform3D(Basis.from_scale(Vector3(-1.0,1.0,1.0)),Vector3.ZERO)
	for side in [[Transform3D.IDENTITY,"R",1.0],[mirror,"L",-1.0]]:
		var xf: Transform3D = side[0]
		for i in range(slabs.size()):
			var s: Vector2 = slabs[i]
			var xs := []
			for k in range(6): xs.append(lerpf(s.x,s.y,k/5.0))
			var m := Mesher.new(10+i+(0 if side[1] == "R" else 10))
			_slab(m,bands,xs,sec,xf,side[1],true,0.05)
			var mx := (s.x+s.y)*0.5
			var at: Vector4 = sec.call(mx)
			_float(m,"Wing%s%d" % [side[1],i],Vector3(mx*float(side[2]),at.x,at.y+at.z*0.5),1.0,Vector3.FORWARD)
			if i < slabs.size()-1: _gap(gaps,(s.y+(slabs[i+1] as Vector2).x)*0.5,sec,xf)
		_gap(gaps,0.08,sec,xf)
	# The tail: a tailplane in two floating slabs, a dorsal fin and a
	# ventral fin (the pitch cue), each held off the boom by a gap.
	var tsec := func(x: float) -> Vector4:
		var t := absf(x)/0.25
		return Vector4(0.012+0.01*t,0.6+0.07*pow(t,1.5),0.15-0.08*t,0.018-0.008*t)
	for side in [[Transform3D.IDENTITY,1.0],[mirror,-1.0]]:
		var m := Mesher.new(30+int(side[1]))
		_slab(m,bands,[0.045,0.113,0.182,0.25],tsec,side[0],"BK",false,0.035)
		_float(m,"Tail%s" % ("R" if side[1] > 0.0 else "L"),Vector3(0.15*float(side[1]),0.02,0.66),0.6,Vector3.FORWARD)
		_gap(gaps,0.039,tsec,side[0])
	var fsec := func(x: float) -> Vector4:
		var t := maxf(0.0,(x-0.045)/0.17)
		return Vector4(0.0,0.57+0.15*pow(t,1.2),0.2-0.12*t,0.018-0.006*t)
	var up := Transform3D(Basis(Vector3.BACK,PI*0.5),Vector3.ZERO)
	var fin := Mesher.new(40)
	var fxs := []
	for k in range(5): fxs.append(lerpf(0.05,0.215,k/4.0))
	_slab(fin,bands,fxs,fsec,up,"UP",false,0.04)
	_float(fin,"FinUp",Vector3(0.0,0.13,0.68),0.6,Vector3.FORWARD)
	_gap(gaps,0.043,fsec,up)
	var vsec := func(x: float) -> Vector4:
		var t := maxf(0.0,(x-0.04)/0.09)
		return Vector4(0.0,0.62+0.08*t,0.15-0.07*t,0.016-0.005*t)
	var down := Transform3D(Basis(Vector3.BACK,-PI*0.5),Vector3.ZERO)
	var ventral := Mesher.new(50)
	_slab(ventral,bands,[0.04,0.07,0.1,0.13],vsec,down,"DN",false,0.04)
	_float(ventral,"FinDown",Vector3(0.0,-0.085,0.68),0.6,Vector3.FORWARD)
	_gap(gaps,0.034,vsec,down)
	_still(gaps,"Gaps",false)
	_still(bands,"Bands",false)

## The needle: a slim four-sided basalt spindle, its north tip glowing, a
## gold band at its balance point; it floats over the stone and points.
func _build_needle() -> Node3D:
	var node := Node3D.new()
	node.name = "Needle"
	var m := Mesher.new(9)
	var l := NEEDLE_LENGTH
	var ring := func(z: float, r: float) -> PackedVector3Array:
		return PackedVector3Array([Vector3(r,0.0,z),Vector3(0.0,r*0.7,z),Vector3(-r,0.0,z),Vector3(0.0,-r*0.7,z)])
	m.loft("stone",[ring.call(l*0.5,0.0008),ring.call(l*0.18,0.0075),ring.call(0.0,0.0105),ring.call(-l*0.18,0.0075)])
	m.loft("seam:RING",[ring.call(-l*0.18,0.0075),ring.call(-l*0.5,0.0006)])
	m.loft("seam:GAP",[ring.call(0.003,0.0118),ring.call(-0.003,0.0118)])
	var mesh := MeshInstance3D.new()
	mesh.mesh = m.mesh(_materials())
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mesh)
	return node

## Triangles drawn (the cost), all its own meshes (not the pilot or stone).
func triangles() -> int:
	var count := 0
	for node in find_children("*","MeshInstance3D",true,false):
		if _rig.is_ancestor_of(node) or (stone != null and stone.is_ancestor_of(node)): continue
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			for s in range(mesh.get_surface_count()): count += mesh.surface_get_array_len(s)/3
	return count
