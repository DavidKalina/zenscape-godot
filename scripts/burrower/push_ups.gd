extends Node3D
## What the burrower pushes up (docs/design/endless-flight/spec-burrower.md,
## 4): glowing orbs (common), an old bronze bell (now and then), a gong on a
## frame (rare). While it leads the plane, every GAP s it pushes one up at
## its head, a beat ahead of the plane (at least the kind's beat of the
## plane's flight off, else a little ahead of the head), for the plane to
## steer for. Each rises with weight, the same phases for every kind (the
## heavier ones slower, a wider dome, a softer spring):
##
##   swell  the ground bulges over the kind's swell s (a dome of the
##          ground's colour, trembling, the grass pressed out round it);
##   crack  the dome tears: earth thrown out (or water, a ring and spray on
##          the pond), the dome falls to a torn mound;
##   push   the thing comes up out of it fast, sheds earth as it goes,
##          overshoots its hang height on a spring and settles;
##   hang   orbs and the bell hang over the ground or water, the gong's
##          frame stands on it;
##   sink   unhit after the kind's hang s: a little lift, then pulled down,
##          a puff where it goes under.
##
## Hits (each plays a note in the run: hits close together climb a
## pentatonic scale, NOTES, so a run plays a little tune):
##   orb   flown into (the plane's middle within its reach plus half a span):
##         bursts into motes, a high chime;
##   bell  clipped (the same reach test, the plane flies on): rings, swings
##         along the plane's way as a damped pendulum, the clapper tolling
##         again at each end of the swing while it swings wide;
##   gong  the disc is a static body on RuinBump.LAYER, the frame too: flown
##         into, the plane glances off (a dull clank, the disc rocks a
##         little). Only while the plane rolls is the disc let through
##         (its layer off); crossing it rolling strikes it: a deep note, the
##         disc swings back and shudders, the frame shakes, sparks, the grass
##         pressed out in a ring.

const Land = preload("res://scripts/burrower/burrower_land.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const HALO_SHADER = preload("res://shaders/burrower_halo.gdshader")
const SOIL_SHADER = preload("res://shaders/burrower_soil.gdshader")

## Timing (s): between push-ups (random in GAP).
const GAP := Vector2(1.5,2.8)
## The kinds: their hang height over the ground (the orb's middle, the bell's
## pivot, the gong frame's foot: 0), where the push starts under it, the
## push's speed (m/s), spring and damping, the dome (across, along the
## approach, m) and its swell (m), the swell's time, the most it hangs, the
## sink's time and how deep it goes, the beat the plane gets at least (s of
## its flight), the most it comes up off the plane's line (m), the room kept
## from trunks and stone (m), the swell's glow.
const KINDS := {
	&"orb": {"up": 3.6, "start": -0.6, "rise": 16.0, "spring": 55.0, "damp": 7.0, "dome": Vector2(2.3,2.3),
		"dome_up": 0.9, "swell": 0.5, "hang": 4.5, "sink": 0.75, "deep": 1.5, "beat": 1.8, "off": 2.0, "room": 5.0,
		"glow": 0.55},
	&"bell": {"up": 4.3, "start": -0.3, "rise": 10.0, "spring": 26.0, "damp": 6.0, "dome": Vector2(2.1,2.1),
		"dome_up": 0.95, "swell": 0.7, "hang": 6.5, "sink": 1.1, "deep": 0.4, "beat": 2.4, "off": 1.5, "room": 6.0,
		"glow": 0.35},
	&"gong": {"up": 0.0, "start": -6.4, "rise": 6.0, "spring": 14.0, "damp": 4.6, "dome": Vector2(4.6,1.5),
		"dome_up": 1.0, "swell": 0.9, "hang": 7.0, "sink": 1.6, "deep": 6.6, "beat": 2.8, "off": 0.5, "room": 9.0,
		"glow": 0.45},
}
## The share of push-ups that are bells and gongs (the rest orbs); a gong
## not within GONG_GAP s of the last.
const BELL_SHARE := 0.2
const GONG_SHARE := 0.1
const GONG_GAP := 20.0
## The orb's hang height and swell (KINDS.orb's, for the orb-era drivers).
const UP := 3.6
const SWELL := 0.5
## Sizes (m): the orb's radius, the glow's size, and the graze: how far past
## the plane's wingtip still counts as a hit (orbs and bells: generous, a
## near clip counts).
const ORB_R := 1.9
const HALO := 10.5
const GRAZE := 2.2
## The bell: its lip's radius, its height under the pivot, the reach of a
## clip; its pendulum (w^2, damping /s); a clip's kick (rad/s along the
## plane's way); it tolls again at each end of a swing wider than TOLL rad.
const BELL_R := 1.0
const BELL_H := 1.75
const BELL_REACH := 1.3
const BELL_W2 := 8.5
const BELL_DAMP := 0.32
const BELL_KICK := 2.4
const TOLL := 0.2
## The gong: the disc's radius and middle's height, the posts' half spacing
## and height, the crossbar's height; its swing (w^2, damping) and kick.
const GONG_R := 2.3
const GONG_Y := 3.3
const POST_X := 3.6
const BAR_Y := 6.0
const GONG_W2 := 3.6
const GONG_DAMP := 0.55
const GONG_KICK := 0.9
## A crossing this long (s) after a roll ended still strikes.
const ROLL_LATE := 0.45
## At most this many up at once.
const MOST := 6
const MOTES := 360
const ORB := Color(1.0,0.78,0.36)
const GLOW := Color(1.0,0.55,0.12)
const MOTE := Color(1.0,0.9,0.6)
const SPARK := Color(1.0,0.82,0.45)
const BRONZE := Color(0.55,0.37,0.17)
const VERDIGRIS := Color(0.33,0.5,0.42)
const WOOD := Color(0.3,0.21,0.14)
## The chimes: C6 pentatonic up two octaves; a run lapses after RUN_GAP s.
## The bell rings two octaves under the run's note, the gong four.
const NOTES := [1046.5,1174.7,1318.5,1568.0,1760.0,2093.0,2349.3,2637.0,3136.0,3520.0]
const RUN_GAP := 7.0
## Placing one on the plane's line: the extra lead past the beat (s, the
## first tried and the one the head surges for), the head's side offset
## while one is due (m), the share of the plane's turn carried forward and
## the most (rad/s; players straighten out), and how far the head may be
## from the spot (m) for it to have pushed it.
const LEAD_T := Vector2(0.25,0.6)
const NEAR_SIDE := 3.0
## Turning harder than TURNING rad/s, none comes up (its line is a guess).
const TURNING := 0.8
const YAW_KEEP := 0.6
const MOST_YAW := 1.2
const FAR := 45.0

var land: Land
var burrower: Node
var time := 0.0
## Everything up (named orbs for the orb-era drivers): each a Dictionary
## with its `kind`.
var orbs: Array = []
var stats := {"pushed": 0, "hits": 0, "sunk": 0, "skipped": 0, "why": {}, "notes": [], "kinds": {},
	"bell_rings": 0, "tolls": 0, "strikes": 0, "glances": 0, "through": 0}
## The next push-up's kind, when set (the study's 1 2 3 keys); else picked.
var next_kind := &""
## The next note in the run, and when the last hit was.
var note_i := 0
var _last_hit := -INF
var _last_gong := -INF
var _wait := 1.0
var _kind := &""
var _rng := RandomNumberGenerator.new()
## The kinds' own dice, so picking them leaves the push-ups' timing as it was.
var _pick_rng := RandomNumberGenerator.new()
## The plane last tick (hits test the way it flew, not one point) and its
## turn (rad/s, eased): where it will be in a beat comes from these.
var _prev_p := Vector3.INF
var _now_p := Vector3.INF
var _heading := NAN
var _yaw := 0.0
## When the plane last rolled: a gong crossed just after a roll still strikes.
var _rolled := -INF
var _core_mesh := SphereMesh.new()
var _core_mat := StandardMaterial3D.new()
var _dome_mesh: ArrayMesh
var _halo_mm := MultiMesh.new()
var _motes: Array = []
var _mote_mm := MultiMesh.new()
var _sounds := {}
var _players: Array = []
var _player_i := 0
var _bronze := StandardMaterial3D.new()
var _patina := StandardMaterial3D.new()
var _wood := StandardMaterial3D.new()
var _gong_mat := StandardMaterial3D.new()

func _init() -> void:
	name = "PushUps"

func setup(the_land: Land, the_burrower: Node) -> void:
	land = the_land
	burrower = the_burrower
	_rng.seed = 77
	_pick_rng.seed = 78
	_core_mesh.radius = ORB_R
	_core_mesh.height = ORB_R*2.0
	_core_mesh.radial_segments = 20
	_core_mesh.rings = 10
	_core_mat.albedo_color = ORB
	_core_mat.emission_enabled = true
	_core_mat.emission = GLOW
	_core_mat.emission_energy_multiplier = 3.2
	_core_mat.roughness = 0.35
	_core_mesh.material = _core_mat
	_dome_mesh = GritMesh.dome(11,0.22,16,5)
	_bronze.albedo_color = BRONZE
	_bronze.metallic = 0.85
	_bronze.roughness = 0.36
	_patina.albedo_color = VERDIGRIS
	_patina.metallic = 0.2
	_patina.roughness = 0.75
	_wood.albedo_color = WOOD
	_wood.roughness = 0.9
	_gong_mat.albedo_color = Color(0.68,0.5,0.22)
	_gong_mat.metallic = 0.9
	_gong_mat.roughness = 0.3
	var quad := QuadMesh.new()
	var halo_m := ShaderMaterial.new()
	halo_m.shader = HALO_SHADER
	quad.material = halo_m
	_halo_mm.transform_format = MultiMesh.TRANSFORM_3D
	_halo_mm.use_custom_data = true
	_halo_mm.mesh = quad
	_halo_mm.instance_count = MOST*2
	_halo_mm.visible_instance_count = 0
	var halos := MultiMeshInstance3D.new()
	halos.name = "Halos"
	halos.multimesh = _halo_mm
	halos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halos.custom_aabb = AABB(Vector3(-400,-50,-400),Vector3(800,200,800))
	add_child(halos)
	var mote := SphereMesh.new()
	mote.radius = 0.5
	mote.height = 1.0
	mote.radial_segments = 6
	mote.rings = 3
	var mote_m := StandardMaterial3D.new()
	mote_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_m.vertex_color_use_as_albedo = true
	mote.material = mote_m
	_mote_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mote_mm.use_colors = true
	_mote_mm.mesh = mote
	_mote_mm.instance_count = MOTES
	_mote_mm.visible_instance_count = 0
	var motes := MultiMeshInstance3D.new()
	motes.name = "Motes"
	motes.multimesh = _mote_mm
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.custom_aabb = AABB(Vector3(-400,-50,-400),Vector3(800,200,800))
	add_child(motes)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)

## One tick: push-ups due from the burrower while it leads `plane` (or roams,
## with `plane` null: the watch camera's), their motion, the plane's hits
## (its middle and half its span, m; `bumped`: RuinBump put it back out of
## something this tick).
func tick(delta: float, plane: Object, half_span: float, bumped := false) -> void:
	time += delta
	if time-_last_hit > RUN_GAP: note_i = 0
	if plane != null:
		var v: Vector3 = plane.velocity
		if Vector2(v.x,v.z).length() > 1.0:
			var h := atan2(v.x,v.z)
			if not is_nan(_heading) and delta > 0.0:
				_yaw = lerpf(_yaw,wrapf(h-_heading,-PI,PI)/delta,minf(1.0,delta*6.0))
			_heading = h
		if bool(plane.rolling): _rolled = time
		_now_p = plane.position
		if _prev_p == Vector3.INF: _prev_p = _now_p
	_due(delta,plane)
	var i := 0
	while i < orbs.size():
		var o: Dictionary = orbs[i]
		if _step(o,delta,plane,half_span,bumped):
			_free(o)
			orbs.remove_at(i)
			continue
		i += 1
	_draw_halos()
	_step_motes(delta)
	_prev_p = _now_p

## A push-up of `kind` at `at` (x, z) now; a gong's disc faces `face` (x, z:
## toward where the plane comes from).
func push(at: Vector2, kind := &"orb", face := Vector2(0.0,1.0)) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var ground := land.height(at.x,at.y)
	var wet := ground < Land.WATER_Y-0.15
	var base := maxf(ground,Land.WATER_Y)
	var n := Vector3(face.x,0.0,face.y).normalized() if face.length() > 0.01 else Vector3.BACK
	var turn := Basis(Vector3.UP.cross(n),Vector3.UP,n)
	var o := {"kind": kind, "k": k, "at": at, "base": base, "wet": wet, "phase": &"swell", "t": 0.0,
		"y": base+float(k.start)-1.0, "vy": 0.0, "hit": false, "spin": _rng.randf()*TAU, "bob": _rng.randf()*TAU,
		"glow": 0.0, "shed": 0.0, "turn": turn, "n": n, "dome_s": Vector3(0.6,0.01,0.6), "hold": 0.0}
	var dome := MeshInstance3D.new()
	dome.mesh = _dome_mesh
	var m: Material
	if wet:
		var wm := StandardMaterial3D.new()
		wm.roughness = 1.0
		wm.albedo_color = Color(0.32,0.42,0.42)
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.albedo_color.a = 0.75
		m = wm
	else:
		var sm := ShaderMaterial.new()
		sm.shader = SOIL_SHADER
		var tint := land.colour(at.x,at.y,ground,land.normal(at.x,at.y)).lerp(Color("4a3826"),0.8)
		sm.set_shader_parameter("tint",Vector3(tint.srgb_to_linear().r,tint.srgb_to_linear().g,tint.srgb_to_linear().b))
		sm.set_shader_parameter("seed",fposmod(at.x*0.37+at.y*0.71,20.0))
		sm.set_shader_parameter("dry",0.35)
		m = sm
	dome.material_override = m
	add_child(dome)
	o.dome = dome
	o.dome_mat = m
	_shape_dome(o)
	match kind:
		&"orb": _make_orb(o)
		&"bell": _make_bell(o)
		&"gong": _make_gong(o)
	orbs.append(o)
	stats.pushed = int(stats.pushed)+1
	stats.kinds[kind] = int(stats.kinds.get(kind,0))+1
	if kind == &"gong": _last_gong = time
	# The grass pressed out round the swelling ground.
	var react: Object = burrower.react
	if react != null and not wet:
		var dr: Vector2 = k.dome
		react._add({"at": at, "way": Vector2.ZERO, "strength": 3.0, "swirl": 0.0, "reach": maxf(dr.x,dr.y)*2.2,
			"front": 0.0, "hold": float(k.swell)+0.8, "press": 0.7})
	return o

func _make_orb(o: Dictionary) -> void:
	var core := MeshInstance3D.new()
	core.mesh = _core_mesh
	core.visible = false
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	o.core = core
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.omni_range = 7.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	add_child(light)
	o.light = light

## The bell: a rig at its pivot, a swing node under it (tilted by the
## pendulum), the crown's loop and shoulder, the flared waist, the lip's
## ring, the clapper.
func _make_bell(o: Dictionary) -> void:
	var rig := Node3D.new()
	rig.visible = false
	add_child(rig)
	var swing := Node3D.new()
	rig.add_child(swing)
	var loop := TorusMesh.new()
	loop.inner_radius = 0.16
	loop.outer_radius = 0.3
	_part(swing,loop,_patina,Transform3D(Basis(Vector3.RIGHT,PI*0.5),Vector3(0.0,-0.12,0.0)))
	var shoulder := SphereMesh.new()
	shoulder.radius = 0.54
	shoulder.height = 0.66
	shoulder.is_hemisphere = true
	_part(swing,shoulder,_bronze,Transform3D(Basis.IDENTITY,Vector3(0.0,-0.6,0.0)))
	# A slim waist, then the sound bow flaring out hard to the lip.
	var waist := CylinderMesh.new()
	waist.top_radius = 0.54
	waist.bottom_radius = 0.64
	waist.height = 0.72
	waist.radial_segments = 20
	waist.cap_top = false
	waist.cap_bottom = false
	_part(swing,waist,_bronze,Transform3D(Basis.IDENTITY,Vector3(0.0,-0.6-0.36,0.0)))
	var flare := CylinderMesh.new()
	flare.top_radius = 0.64
	flare.bottom_radius = BELL_R
	flare.height = 0.33
	flare.radial_segments = 24
	flare.cap_top = false
	flare.cap_bottom = false
	_part(swing,flare,_bronze,Transform3D(Basis.IDENTITY,Vector3(0.0,-1.32-0.165,0.0)))
	var lip := TorusMesh.new()
	lip.inner_radius = BELL_R-0.09
	lip.outer_radius = BELL_R+0.07
	lip.rings = 24
	_part(swing,lip,_patina,Transform3D(Basis.IDENTITY,Vector3(0.0,-BELL_H+0.08,0.0)))
	var inside := CylinderMesh.new()
	inside.top_radius = 0.5
	inside.bottom_radius = BELL_R-0.06
	inside.height = 1.0
	inside.cap_top = true
	inside.cap_bottom = false
	inside.flip_faces = true
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12,0.08,0.05)
	_part(swing,inside,dark,Transform3D(Basis.IDENTITY,Vector3(0.0,-0.62-0.5,0.0)))
	var clapper := SphereMesh.new()
	clapper.radius = 0.2
	clapper.height = 0.4
	o.clapper = _part(swing,clapper,dark,Transform3D(Basis.IDENTITY,Vector3(0.0,-BELL_H+0.15,0.0)))
	o.rig = rig
	o.swing = swing
	o.tilt = Vector2.ZERO
	o.tilt_v = Vector2.ZERO
	o.turning = 0.0

## The gong: a rig at the frame's foot turned to face the plane (its +z),
## two posts (sunk a metre, so the push's overshoot never shows their ends)
## and a crossbar, a pivot under the bar holding the cords and the disc,
## its boss and rim. A static body for the frame, one for the disc.
func _make_gong(o: Dictionary) -> void:
	var rig := Node3D.new()
	rig.visible = false
	add_child(rig)
	var frame := StaticBody3D.new()
	frame.collision_layer = RuinBump.LAYER
	frame.collision_mask = 0
	rig.add_child(frame)
	for side: float in [-1.0,1.0]:
		var post := BoxMesh.new()
		post.size = Vector3(0.4,BAR_Y+1.4,0.4)
		var at := Vector3(side*POST_X,(BAR_Y+1.4)*0.5-1.2,0.0)
		_part(rig,post,_wood,Transform3D(Basis.IDENTITY,at))
		var shape := BoxShape3D.new()
		shape.size = post.size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = at
		frame.add_child(cs)
		var foot := BoxMesh.new()
		foot.size = Vector3(0.9,0.35,1.4)
		_part(rig,foot,_wood,Transform3D(Basis.IDENTITY,Vector3(side*POST_X,0.05,0.0)))
	var bar := BoxMesh.new()
	bar.size = Vector3(POST_X*2.0+1.2,0.45,0.45)
	_part(rig,bar,_wood,Transform3D(Basis.IDENTITY,Vector3(0.0,BAR_Y,0.0)))
	var bar_shape := BoxShape3D.new()
	bar_shape.size = bar.size
	var bcs := CollisionShape3D.new()
	bcs.shape = bar_shape
	bcs.position = Vector3(0.0,BAR_Y,0.0)
	frame.add_child(bcs)
	for side: float in [-1.0,1.0]:
		var cap := BoxMesh.new()
		cap.size = Vector3(0.3,0.25,0.6)
		_part(rig,cap,_patina,Transform3D(Basis.IDENTITY,Vector3(side*(POST_X+0.55),BAR_Y+0.1,0.0)))
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0,BAR_Y-0.2,0.0)
	rig.add_child(pivot)
	var drop := BAR_Y-0.2-(GONG_Y+GONG_R)
	for side: float in [-1.0,1.0]:
		var cord := CylinderMesh.new()
		cord.top_radius = 0.04
		cord.bottom_radius = 0.04
		cord.height = drop+0.3
		_part(pivot,cord,_wood,Transform3D(Basis.IDENTITY,Vector3(side*0.8,-(drop+0.3)*0.5,0.0)))
	var disc_at := Node3D.new()
	disc_at.position = Vector3(0.0,GONG_Y-(BAR_Y-0.2),0.0)
	pivot.add_child(disc_at)
	var face := Basis(Vector3.RIGHT,PI*0.5)
	var disc := CylinderMesh.new()
	disc.top_radius = GONG_R
	disc.bottom_radius = GONG_R
	disc.height = 0.12
	disc.radial_segments = 40
	_part(disc_at,disc,_gong_mat,Transform3D(face,Vector3.ZERO))
	var rim := TorusMesh.new()
	rim.inner_radius = GONG_R-0.12
	rim.outer_radius = GONG_R+0.08
	rim.rings = 40
	_part(disc_at,rim,_bronze,Transform3D(face,Vector3.ZERO))
	var boss := SphereMesh.new()
	boss.radius = 0.55
	boss.height = 0.5
	for side: float in [-1.0,1.0]:
		_part(disc_at,boss,_patina,Transform3D(face,Vector3(0.0,0.0,side*0.04)))
	var body := StaticBody3D.new()
	body.collision_layer = RuinBump.LAYER
	body.collision_mask = 0
	var cyl := CylinderShape3D.new()
	cyl.radius = GONG_R
	cyl.height = 0.3
	var dcs := CollisionShape3D.new()
	dcs.shape = cyl
	dcs.basis = face
	body.add_child(dcs)
	disc_at.add_child(body)
	o.rig = rig
	o.pivot = pivot
	o.disc = disc_at
	o.disc_body = body
	o.frame = frame
	o.swing = 0.0
	o.swing_v = 0.0
	o.shake = 0.0
	o.struck = -INF
	o.glanced = -INF
	o.side = 0.0

func _part(under: Node3D, mesh: Mesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	under.add_child(mi)
	return mi

func _shape_dome(o: Dictionary) -> void:
	var s: Vector3 = o.dome_s
	var dr: Vector2 = o.k.dome
	var at: Vector2 = o.at
	var turn: Basis = o.turn
	(o.dome as MeshInstance3D).transform = Transform3D(turn*Basis.from_scale(Vector3(dr.x*s.x,maxf(s.y,0.01),dr.y*s.z)),
		Vector3(at.x,float(o.base)-0.05,at.y))

## The kind of the next push-up: the one asked for, else mostly an orb.
func _pick() -> StringName:
	if next_kind != &"":
		var k := next_kind
		next_kind = &""
		return k
	var up := {}
	for o: Dictionary in orbs: up[o.kind] = true
	var r := _pick_rng.randf()
	if r < GONG_SHARE and not up.has(&"gong") and time-_last_gong > GONG_GAP: return &"gong"
	if r < GONG_SHARE+BELL_SHARE and not up.has(&"bell"): return &"bell"
	return &"orb"

## Whether a push-up is due, and where. Leading the plane: on its own line
## ahead, where it will be in a beat or a little more at its heading and
## turn, a small step to the head's side (taking one is a nudge, not a
## chase); while it is due the head swings in toward that line and surges
## to it. Roaming (the watch camera's): at the head.
func _due(delta: float, plane: Object) -> void:
	if not burrower.active or burrower.diving() or float(burrower.strength) < 0.8:
		burrower.want_ahead = 0.0
		burrower.want_at = Vector2(NAN,NAN)
		_wait = maxf(_wait,0.6)
		return
	_wait -= delta
	if _wait > 0.0 or orbs.size() >= MOST: return
	if _kind == &"" or (next_kind != &"" and next_kind != _kind): _kind = _pick()
	var k: Dictionary = KINDS[_kind]
	var head: Vector2 = burrower.pos
	var at := head
	var face := -burrower.forward() as Vector2
	var why := ""
	if plane != null and burrower.mode == &"lead":
		var p: Vector3 = plane.position
		var v: Vector3 = plane.velocity
		var vp := maxf(Vector2(v.x,v.z).length(),8.0)
		var beat := float(k.beat)
		burrower.want_ahead = (beat+LEAD_T.y)*vp
		var run := _on_line(Vector2(p.x,p.z),vp,beat+LEAD_T.y)
		burrower.want_at = Vector2(run.x,run.y)+Vector2(-run.w,run.z)*burrower._side*NEAR_SIDE
		# Mid-turn its line is a guess: wait for it to roll out.
		if absf(_yaw) > TURNING: return _skip("turning")
		# A few beats out along its line; the first spot clear of stone.
		why = "rim"
		for lead: float in [LEAD_T.x,LEAD_T.y,0.0,LEAD_T.y*2.0]:
			var on := _on_line(Vector2(p.x,p.z),vp,beat+lead)
			var side := Vector2(-on.w,on.z)
			var s := signf((head-Vector2(on.x,on.y)).dot(side))
			var spot := Vector2(on.x,on.y)+side*(s if s != 0.0 else 1.0)*_rng.randf_range(0.0,float(k.off))
			why = _room(spot,k)
			if why == "":
				at = spot
				break
		if why == "" and head.distance_to(at) > FAR: why = "far"
		face = Vector2(p.x,p.z)-at
	else:
		why = _room(at,k)
	if why != "": return _skip(why)
	push(at,_kind,face)
	_wait = _rng.randf_range(GAP.x,GAP.y)*(1.4 if _kind == &"gong" else 1.0)
	_kind = &""
	burrower.want_ahead = 0.0
	burrower.want_at = Vector2(NAN,NAN)

## Where the plane will be in `t` s (x, z) and its way then (z, w), flying
## on at `vp` m/s and turning as it turns now (eased, held to a bank's).
func _on_line(p: Vector2, vp: float, t: float) -> Vector4:
	var h := _heading if not is_nan(_heading) else 0.0
	var w := clampf(_yaw*YAW_KEEP,-MOST_YAW,MOST_YAW)
	var n := 12
	var dt := t/n
	for i in n:
		h += w*dt*0.5
		p += Vector2(sin(h),cos(h))*vp*dt
		h += w*dt*0.5
	return Vector4(p.x,p.y,sin(h),cos(h))

## Why `at` won't do for kind `k` (under a crown, into a rock, by the
## rim), or "" when it will.
func _room(at: Vector2, k: Dictionary) -> String:
	for tree: Node3D in land.trees:
		if at.distance_to(Vector2(tree.position.x,tree.position.z)) < float(k.room): return "tree"
	for r: Dictionary in land.rocks+land.ruins:
		if at.distance_to(r.at) < float(r.reach)+float(k.room)-3.0: return "rock"
	if at.length() > Land.MEADOW_R-10.0: return "rim"
	return ""

func _skip(why: String) -> void:
	stats.skipped = int(stats.skipped)+1
	stats.why[why] = int(stats.why.get(why,0))+1
	_wait = 0.15

## Steps one push-up; true when it is done with.
func _step(o: Dictionary, delta: float, plane: Object, half_span: float, bumped: bool) -> bool:
	o.t = float(o.t)+delta
	var t: float = o.t
	var k: Dictionary = o.k
	var kind: StringName = o.kind
	var at: Vector2 = o.at
	var base: float = o.base
	var wet: bool = o.wet
	var dr: Vector2 = k.dome
	var swell: float = k.swell
	var stretch := 1.0
	match o.phase:
		&"swell":
			# The ground bulges, faster as it goes, trembling.
			var f := t/swell
			var h := float(k.dome_up)*f*f*(1.6-0.6*f)
			var shake := 0.06*f*sin(t*70.0)
			o.dome_s = Vector3(0.6+0.4*f+shake,h,0.6+0.4*f-shake)
			# Light leaking up through the grass, earth spat up: the beat's
			# warning, read from the chase camera before the dome shows.
			o.glow = float(k.glow)*f
			if f > 0.35:
				o.shed = float(o.shed)+delta*(14.0 if not wet else 30.0)*(dr.x/1.7)
				while float(o.shed) >= 1.0:
					o.shed = float(o.shed)-1.0
					var p := _along(o,_rng.randf_range(-0.7,0.7))+Vector3(0.0,0.4,0.0)
					if wet: burrower.throw_water(p,2,1.5,5.0*f)
					else: burrower.throw_earth(p,1,1.6,6.0*f,dr.y*0.6)
			if t >= swell:
				o.phase = &"push"
				o.t = 0.0
				o.shed = 0.0
				o.y = base+float(k.start)
				o.vy = float(k.rise)
				_show(o)
				var bits := 26 if kind == &"orb" else (40 if kind == &"bell" else 24)
				for s: float in ([0.0] if kind != &"gong" else [-0.85,0.0,0.85]):
					var top := _along(o,s)+Vector3(0.0,0.3,0.0)
					if wet:
						burrower.throw_water(top,70,5.0,9.0,1.8)
						burrower.puff(top,4,true)
					else:
						burrower.throw_earth(top,bits,5.5,8.0+(2.0 if kind != &"orb" else 0.0),dr.y*0.8)
						burrower.puff(top,5)
		&"push", &"hang":
			var hang := base+float(k.up)
			if o.phase == &"hang":
				if kind == &"orb": hang += 0.12*sin(time*2.2+float(o.bob))
				elif kind == &"bell": hang += 0.06*sin(time*1.4+float(o.bob))
			var y: float = o.y
			var vy: float = o.vy
			vy += (float(k.spring)*(hang-y)-float(k.damp)*vy)*delta
			y += vy*delta
			o.y = y
			o.vy = vy
			if kind == &"orb":
				stretch = clampf(1.0+absf(vy)*0.035,1.0,1.5)
				# Squash as it turns at the top of its overshoot.
				if absf(vy) < 2.5 and y > hang: stretch = 1.0-0.18*(1.0-absf(vy)/2.5)*clampf((y-hang)*3.0,0.0,1.0)
				o.glow = minf(float(o.glow)+delta*3.0,1.0)
			else:
				o.glow = maxf(float(o.glow)-delta*0.8,0.0)
			# The dome falls in to a torn mound.
			var fall := clampf(t/0.3,0.0,1.0)
			o.dome_s = Vector3(1.0+0.15*fall,lerpf(float(k.dome_up),0.22 if not wet else 0.01,fall),1.0+0.15*fall)
			if wet: (o.dome as Node3D).visible = fall < 1.0
			if not wet:
				var dm := o.dome_mat as ShaderMaterial
				var tc: Vector3 = dm.get_shader_parameter("tint")
				var tl := Color(tc.x,tc.y,tc.z).lerp(Color("3d2e20").srgb_to_linear(),delta*3.0)
				dm.set_shader_parameter("tint",Vector3(tl.r,tl.g,tl.b))
			# Earth (or water) shed off it on the way up.
			if o.phase == &"push" and t < 0.45+(0.4 if kind != &"orb" else 0.0):
				o.shed = float(o.shed)+delta*22.0
				while float(o.shed) >= 1.0:
					o.shed = float(o.shed)-1.0
					var p := _shed_point(o)
					if wet: burrower.throw_water(p,2,1.2,0.5)
					else: burrower.throw_earth(p,1,1.0,0.3,0.8)
			if o.phase == &"push" and t > (1.2 if kind == &"orb" else 2.2): o.phase = &"hang"
			if t > maxf(float(k.hang),float(o.hold)):
				o.phase = &"sink"
				o.t = 0.0
				o.top = y
		&"sink":
			# A little lift, then pulled down hard.
			var top: float = o.top
			var sink: float = k.sink
			var lift := 0.3 if kind == &"orb" else 0.15
			var y: float
			if t < 0.18: y = top+lift*sin(t/0.18*PI*0.5)
			else:
				var f := (t-0.18)/(sink-0.18)
				var down := base-float(k.deep)
				y = top+lift-(top+lift-down)*f*f
			o.vy = (y-float(o.y))/maxf(delta,0.001)
			o.y = y
			if kind == &"orb": stretch = clampf(1.0+absf(float(o.vy))*0.03,1.0,1.6)
			o.glow = minf(float(o.glow),clampf(1.0-t/sink,0.0,1.0))
			o.dome_s = Vector3(o.dome_s.x,maxf(float(o.dome_s.y)-delta*0.3,0.01),o.dome_s.z)
			var low := y+BAR_Y if kind == &"gong" else y
			if low < base and not o.has("under"):
				o.under = true
				for s: float in ([0.0] if kind != &"gong" else [-1.0,0.0,1.0]):
					var p := _along(o,s)+Vector3(0.0,0.1,0.0)
					if wet: burrower.throw_water(p,24,2.5,4.0,0.9)
					else:
						burrower.throw_earth(p,8,2.0,3.0,0.6)
						burrower.puff(p,3)
			if t >= sink:
				stats.sunk = int(stats.sunk)+1
				return true
	_shape_dome(o)
	match kind:
		&"orb": return _orb(o,delta,stretch,plane,half_span)
		&"bell": _bell(o,delta,plane,half_span)
		&"gong": _gong(o,delta,plane,half_span,bumped)
	return false

## A point along the dome's long axis (`s` -1..1 its half length), at ground.
func _along(o: Dictionary, s: float) -> Vector3:
	var dr: Vector2 = o.k.dome
	var at: Vector2 = o.at
	var turn: Basis = o.turn
	return Vector3(at.x,float(o.base),at.y)+turn.x*dr.x*s*0.8

## Where earth falls off it on the way up: off the orb, the bell's lip, the
## gong's bar and posts.
func _shed_point(o: Dictionary) -> Vector3:
	var at: Vector2 = o.at
	var y: float = o.y
	match o.kind:
		&"bell": return Vector3(at.x,y-BELL_H,at.y)+Vector3(_rng.randf_range(-1,1),0.0,_rng.randf_range(-1,1)).normalized()*BELL_R
		&"gong":
			var s := _rng.randf_range(-1.0,1.0)
			var turn: Basis = o.turn
			return Vector3(at.x,y+BAR_Y,at.y)+turn.x*POST_X*s
	return Vector3(at.x,y-ORB_R*0.5,at.y)

func _show(o: Dictionary) -> void:
	match o.kind:
		&"orb": (o.core as Node3D).visible = true
		_: (o.rig as Node3D).visible = true

func _orb(o: Dictionary, delta: float, stretch: float, plane: Object, half_span: float) -> bool:
	var at: Vector2 = o.at
	var core: MeshInstance3D = o.core
	var light: OmniLight3D = o.light
	var c := Vector3(at.x,float(o.y),at.y)
	if core.visible:
		var sx := 1.0/sqrt(stretch)
		o.spin = float(o.spin)+delta*1.4
		core.global_transform = Transform3D(Basis(Vector3.UP,float(o.spin)).scaled(Vector3(sx,stretch,sx)),c)
		light.position = c
		light.light_energy = 1.6*float(o.glow)
		# Flown into: motes and a chime.
		if plane != null and o.phase != &"swell" and float(o.y) > float(o.base):
			if _near(c,ORB_R+half_span+GRAZE):
				_burst(c,plane.velocity,70,MOTE,GLOW)
				_hit(&"orb",0.0)
				return true
	return false

## The bell's pendulum (two small angles, the lip's way off plumb), its
## clips and tolls.
func _bell(o: Dictionary, delta: float, plane: Object, half_span: float) -> void:
	var at: Vector2 = o.at
	var pivot := Vector3(at.x,float(o.y),at.y)
	var tilt: Vector2 = o.tilt
	var tv: Vector2 = o.tilt_v
	tv += (-BELL_W2*tilt-BELL_DAMP*2.0*tv)*delta
	tilt += tv*delta
	# A clapper's toll at each end of a wide swing.
	var turning := tilt.dot(tv)
	if float(o.turning) > 0.0 and turning <= 0.0 and tilt.length() > TOLL and bool(o.hit):
		stats.tolls = int(stats.tolls)+1
		_sound(&"bell",int(o.note),-12.0+clampf((tilt.length()-TOLL)*20.0,0.0,8.0))
	o.turning = turning
	o.tilt = tilt
	o.tilt_v = tv
	var a := tilt.length()
	var b := Basis.IDENTITY
	if a > 0.0001:
		var d := Vector3(tilt.x,0.0,tilt.y)/a
		b = Basis(d.cross(Vector3.UP).normalized(),a)
	var rig: Node3D = o.rig
	rig.position = pivot
	(o.swing as Node3D).basis = b
	# The clapper lags the swing.
	(o.clapper as Node3D).position = Vector3(-tv.x*0.06,-BELL_H+0.15,-tv.y*0.06)
	var mid := pivot+b*Vector3(0.0,-BELL_H*0.6,0.0)
	if plane == null or o.phase == &"swell" or float(o.y)-BELL_H < float(o.base): return
	var p: Vector3 = plane.position
	if _near(mid,BELL_REACH+half_span+GRAZE) and time-float(o.get("clip",-INF)) > 0.8:
		o.clip = time
		var v: Vector3 = plane.velocity
		var way := Vector2(v.x,v.z).normalized()
		o.tilt_v = tv+way*BELL_KICK
		o.hit = true
		o.hold = float(o.t)+4.5 if o.phase != &"sink" else 0.0
		stats.bell_rings = int(stats.bell_rings)+1
		o.note = note_i
		_burst(mid,v*0.3,24,SPARK,VERDIGRIS)
		_hit(&"bell",0.0)

## The gong: the disc let through only while the plane rolls; crossing it
## rolling strikes it, flown into otherwise the plane glances off.
func _gong(o: Dictionary, delta: float, plane: Object, half_span: float, bumped: bool) -> void:
	var at: Vector2 = o.at
	var turn: Basis = o.turn
	var n: Vector3 = o.n
	var since := time-float(o.struck)
	o.swing_v = float(o.swing_v)+(-GONG_W2*float(o.swing)-GONG_DAMP*2.0*float(o.swing_v))*delta
	o.swing = float(o.swing)+float(o.swing_v)*delta
	o.shake = float(o.shake)*exp(-2.4*delta)
	var sh: float = o.shake
	var jolt := Vector3(sin(time*53.0),sin(time*41.0)*0.4,sin(time*47.0+1.0))*0.07*sh
	var rig: Node3D = o.rig
	rig.global_transform = Transform3D(turn,Vector3(at.x,float(o.y),at.y)+jolt)
	(o.pivot as Node3D).basis = Basis(Vector3.RIGHT,float(o.swing))
	# The shudder: the disc trembling in and out of its face.
	var tremble := sh*sin(time*TAU*13.0)
	(o.disc as Node3D).basis = Basis(Vector3.UP,0.03*tremble)*Basis.from_scale(Vector3(1.0+0.02*tremble,1.0+0.02*tremble,1.0))
	var body: StaticBody3D = o.disc_body
	var rolling := plane != null and (bool(plane.rolling) or time-_rolled < ROLL_LATE)
	body.collision_layer = 0 if rolling or since < 0.6 else RuinBump.LAYER
	if plane == null or o.phase == &"swell" or o.phase == &"sink": return
	var c := Vector3(at.x,float(o.y)+GONG_Y,at.y)
	var p: Vector3 = plane.position
	var s := (p-c).dot(n)
	var lat := ((p-c)-n*s).length()
	var was: float = o.side
	o.side = s
	if was != 0.0 and signf(was) != signf(s) and lat < GONG_R+half_span+0.8 and since > 1.0:
		if rolling:
			o.struck = time
			o.swing_v = float(o.swing_v)-signf(was)*GONG_KICK
			o.shake = 1.0
			o.hold = float(o.t)+3.5
			stats.strikes = int(stats.strikes)+1
			_burst(c,Vector3.ZERO,110,SPARK,GLOW,n,0.45,GONG_R*0.75/ORB_R)
			for e: float in [-1.0,1.0]:
				burrower.puff(Vector3(at.x,float(o.y)+BAR_Y,at.y)+turn.x*POST_X*0.6*e,2)
			var react: Object = burrower.react
			if react != null and not bool(o.wet):
				react._add({"at": at, "way": Vector2.ZERO, "strength": 4.0, "swirl": 0.0, "reach": 11.0,
					"front": 0.0, "hold": 0.9, "press": 0.8})
			_hit(&"gong",0.0)
		else:
			stats.through = int(stats.through)+1
	elif bumped and absf(s) < 3.0 and lat < GONG_R+half_span+1.0 and time-float(o.glanced) > 1.0:
		o.glanced = time
		o.swing_v = float(o.swing_v)-signf(s if s != 0.0 else 1.0)*0.35
		o.shake = maxf(float(o.shake),0.3)
		stats.glances = int(stats.glances)+1
		_sound(&"clank",0,-6.0)

## Whether the plane passed within `reach` of `c` since last tick (the way
## it flew, so a fast pass can't skip over it).
func _near(c: Vector3, reach: float) -> bool:
	if _now_p == Vector3.INF: return false
	var ab := _now_p-_prev_p
	var l := ab.length_squared()
	var t := 0.0 if l < 0.0001 else clampf((c-_prev_p).dot(ab)/l,0.0,1.0)
	return c.distance_to(_prev_p+ab*t) < reach

func _free(o: Dictionary) -> void:
	for key: String in ["dome","core","light","rig"]:
		if o.has(key): (o[key] as Node).queue_free()

func _draw_halos() -> void:
	var n := 0
	for o: Dictionary in orbs:
		if n >= _halo_mm.instance_count: break
		var g: float = o.glow
		if g <= 0.0: continue
		var pulse := 0.85+0.15*sin(time*5.0+float(o.bob))
		# Swelling, the glow sits at the dome's top, coming through the grass.
		var y := maxf(float(o.y),float(o.base)+0.6) if o.phase == &"swell" or o.kind != &"orb" else float(o.y)
		if o.kind != &"orb" and o.phase != &"swell": y = float(o.base)+0.6
		var c := Vector3((o.at as Vector2).x,y,(o.at as Vector2).y)
		var size := HALO*(1.0 if o.kind == &"orb" else 1.4)
		_halo_mm.set_instance_transform(n,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size*(0.6+0.4*g)),c))
		_halo_mm.set_instance_custom_data(n,Color(GLOW.r,GLOW.g,GLOW.b,g*pulse))
		n += 1
	_halo_mm.visible_instance_count = n

# --- Hits ------------------------------------------------------------------------

## A hit of `kind`: its note in the run, the run climbing.
func _hit(kind: StringName, db: float) -> void:
	stats.hits = int(stats.hits)+1
	_last_hit = time
	(stats.notes as Array).append(note_i)
	_sound(kind,note_i,db)
	note_i = mini(note_i+1,NOTES.size()-1)

## `face` (when given) keeps the burst flat in that face's plane, flung
## out from `at` across it (the gong's sparks off its rim, not at the
## camera following the plane through); `size` scales the motes.
func _burst(at: Vector3, carry: Vector3, count: int, from: Color, to: Color, face := Vector3.ZERO, size := 1.0, out := 0.6) -> void:
	for i in count:
		if _motes.size() >= MOTES: _motes.pop_front()
		var d := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.6,1),_rng.randf_range(-1,1)).normalized()
		if face != Vector3.ZERO:
			d = (d-face*d.dot(face)*0.9).normalized()
		_motes.append({"p": at+d*ORB_R*out, "v": d*_rng.randf_range(4.0,13.0)+carry*_rng.randf_range(0.2,0.55),
			"age": 0.0, "life": _rng.randf_range(0.7,1.7)*(0.6 if face != Vector3.ZERO else 1.0),
			"size": _rng.randf_range(0.08,0.2)*size, "from": from, "to": to})

func _step_motes(delta: float) -> void:
	var i := 0
	while i < _motes.size():
		var m: Dictionary = _motes[i]
		m.age = float(m.age)+delta
		if float(m.age) >= float(m.life):
			_motes.remove_at(i)
			continue
		var v: Vector3 = m.v
		v *= 1.0-2.4*delta
		v.y += 1.2*delta
		m.v = v
		m.p = (m.p as Vector3)+v*delta
		i += 1
	var n := _motes.size()
	_mote_mm.visible_instance_count = n
	for k in n:
		var m: Dictionary = _motes[k]
		var t := float(m.age)/float(m.life)
		var s := float(m.size)*(1.0-t*t)*(0.85+0.3*sin(float(m.age)*30.0+k))
		_mote_mm.set_instance_transform(k,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*maxf(s,0.001)),m.p))
		_mote_mm.set_instance_color(k,(m.from as Color).lerp(m.to,t))

# --- Sounds ----------------------------------------------------------------------

## The bell's and gong's recordings (CC0, Freesound; assets/audio/ATTRIBUTION.md),
## two of each: the study's 4 and 5 keys, or --bell=1|2 / --gong=1|2, pick
## one. PITCH: the playback pitch of note 0 (the recordings are pitched by
## ear, the run's notes then climb it by NOTES[i]/NOTES[0]); DB: a level trim.
const BELLS := ["res://assets/audio/burrower/bell-417300.mp3","res://assets/audio/burrower/bell-531031.mp3"]
const GONGS := ["res://assets/audio/burrower/gong-369428.mp3","res://assets/audio/burrower/gong-711881.mp3"]
const BELL_PITCH := 0.7
const GONG_PITCH := 0.6
const BLIP_NOTES := [1046.5,1396.9]
const BLIP_RATE := 32000
const BLIP_DB := -9.0

## Which recording each kind plays now (0 or 1).
var bell_take := 0
var gong_take := 0

## Switches `kind` (bell or gong) to its other recording and plays it, so
## the key shows what it chose; returns the file's name.
func cycle_take(kind: StringName) -> String:
	var path := ""
	if kind == &"gong":
		gong_take = 1-gong_take
		path = GONGS[gong_take]
	else:
		bell_take = 1-bell_take
		path = BELLS[bell_take]
	_sound(kind,0,0.0)
	return path.get_file()

## The recording or blip for `kind`, loaded once.
func _stream(kind: StringName) -> AudioStream:
	var key := "%s%d" % [kind,bell_take if kind == &"bell" else gong_take if kind == &"gong" else 0]
	if not _sounds.has(key):
		match kind:
			&"bell": _sounds[key] = load(BELLS[bell_take])
			&"gong": _sounds[key] = load(GONGS[gong_take])
			&"clank": _sounds[key] = _tone(130.0,[[1.0,1.0,7.0],[2.3,0.5,11.0],[3.9,0.3,16.0]],0.6,22050)
			_: _sounds[key] = _blip()
	return _sounds[key]

## Plays `kind`'s sound for note `i` of the run, `db` up or down: the orb's
## blip and the bell and gong recordings are pitched up the run's tune.
func _sound(kind: StringName, i: int, db: float) -> void:
	var p: AudioStreamPlayer = _players[_player_i]
	_player_i = (_player_i+1) % _players.size()
	i = clampi(i,0,NOTES.size()-1)
	var up: float = NOTES[i]/NOTES[0]
	p.stream = _stream(kind)
	match kind:
		&"bell": p.pitch_scale = BELL_PITCH*up
		&"gong": p.pitch_scale = GONG_PITCH*up
		&"clank": p.pitch_scale = 1.0
		_: p.pitch_scale = up
	p.volume_db = -8.0+db+(BLIP_DB if kind == &"orb" else 0.0)
	p.play()

## The archived pickup blip (the red stone plummet's): a 45 ms grace note
## leaping a fourth into a note that rings out and shimmers away.
static func _blip() -> AudioStreamWAV:
	var n := int(0.45*BLIP_RATE)
	var data := PackedByteArray()
	data.resize(n*2)
	for i in n:
		var t := float(i)/BLIP_RATE
		var grace := _blip_note(BLIP_NOTES[0],t,9.0)*clampf((0.05-t)/0.008,0.0,1.0)
		var v := (grace+_blip_note(BLIP_NOTES[1],t-0.045,7.5))*0.5
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = BLIP_RATE
	w.stereo = false
	w.data = data
	return w

## One shiny note at `f` Hz from `s` s into it (the archive's _note).
static func _blip_note(f: float, s: float, decay: float) -> float:
	if s < 0.0: return 0.0
	var env := minf(s/0.003,1.0)*exp(-s*decay)
	var v := 0.5*(sin(TAU*f*s)+sin(TAU*(f+2.5)*s))
	v += (0.22*sin(TAU*f*3.0*s)+0.1*sin(TAU*f*5.0*s))*exp(-s*14.0)
	v += 0.3*sin(TAU*f*2.76*s)*exp(-s*40.0)
	return env*v

## A struck tone at `hz`: partials [ratio, loudness, decay /s], a fast
## strike, `long` s; `bloom` s for the upper partials to swell in (a gong's).
static func _tone(hz: float, partials: Array, long: float, rate: int, bloom := 0.0) -> AudioStreamWAV:
	var n := int(rate*long)
	var data := PackedByteArray()
	data.resize(n*2)
	var sum := 0.0
	for q: Array in partials: sum += float(q[1])
	for i in n:
		var t := float(i)/rate
		var s := 0.0
		var j := 0
		for q: Array in partials:
			var amp := float(q[1])*exp(-t*float(q[2]))
			if bloom > 0.0 and j > 0: amp *= 0.3+0.7*minf(t/bloom,1.0)
			s += amp*sin(TAU*hz*float(q[0])*t*(1.0+0.004*exp(-t*2.0)))
			j += 1
		s *= minf(t/0.003,1.0)*0.8/sum
		data.encode_s16(i*2,int(clampf(s,-1.0,1.0)*32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
