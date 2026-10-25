extends Node3D
## The little plane (scripts/sky_plane.gd), for the chase camera (scripts/
## glide_camera.gd): a small biplane with its cockpit closed over, painted
## from the land's colours: a terracotta body, wings the cream of the
## clouds and the snow, trimmed in the sea's deep teal. It is what flies.
##
## Drawn as a toy is, plump and plain, so it reads at the chase camera's
## distance against the painted land: a round body tapering to the tail, a
## round cowl and a brass spinner, a tinted canopy over the cockpit; thick
## wings with an airfoil's section, their cloth drawn smooth over a few ribs
## (`_wing`), rounded at the tips, roundels on the upper wing; a pair of
## struts a side, no wires; a sturdy V undercarriage and fat wheels.
##
## Smooth solids: its parts are built of flat faces and joined with their
## normals smoothed where the faces meet gently (`_smooth`, CREASE), so the
## round parts read round and the edges stay crisp. The paint (shaders/
## plane_surface.gdshader) is lit as the ruins' stone is, a plain
## terminator, under a glossy lacquer (a clear coat, COAT) with only a light
## grime (shaders/craft_grime.gdshaderinc, GRIT); the wings a doped cloth a
## little less glossy, the spinner and fittings brass with a tighter
## sheen. How worn it is (`set_wear`) runs
## from that to dusty, sun-faded and scuffed, the brass tarnished; a livery
## may carry its own (scripts/sky_traffic.gd). The propeller is a varnished
## wooden one with brass tips; once it turns too fast to see, only a soft
## disc of air shows (shaders/prop_blur.gdshader), its sweeps crawling round
## as a filmed one's do. It is drawn turned by the bank and the barrel roll
## together. The ailerons tip with the roll, the elevator with the pitch,
## so the stick shows on the wings. A soft mark under it shows where it
## would touch down, and on a hard pull vapour peels off its upper
## wingtips (`update`'s `near`).
##
## Its fixed parts are joined into one mesh for each material (`_join`), so
## a plane is a dozen draws however finely it is made (the sky's traffic
## flies several, scripts/sky_traffic.gd).
##
## Landed, it stands on its two wheels and a tail skid, nose up (`park`,
## scripts/plane_strip.gd `rest`), the propeller still.

const FacetMesh = preload("res://scripts/facet_mesh.gd")
const PLANE_SURFACE := preload("res://shaders/plane_surface.gdshader")
const PROP_BLUR := preload("res://shaders/prop_blur.gdshader")
## Each paint slot's colour: "wood" the body, "dark" the struts, legs and
## tail skid, "trim" the cowl, wingtips, fin and band, "cream" the wings,
## tailplane and rudder, "canopy" the cockpit's tinted cover, "brass" the
## spinner and hubs, "varnish" the propeller's wood, "steel" the tyres and
## the cowl's face. Taken from the land: the body a warm terracotta (the
## flowers' and the sunlit rock's), the wings a cloud cream, the trim and
## struts the sea's teal, the canopy a slate blue-grey.
const WOOD := Color("b9583b")
const DARK := Color("2f4a4f")
const TRIM := Color("2f6670")
const WING := Color("ece2c8")
const CANOPY := Color("38505d")
const BRASS := Color("c9a35a")
const STRIPE := Color("f3ead6")
const PROPWOOD := Color("70432a")
const STEEL := Color("33302d")
## The paint's light (shaders/plane_surface.gdshader): how much of the sky
## fills its shade, its sky rim, its roughness under the lacquer, the
## lacquer's own roughness, the grime's strength and its cells a toy unit.
const PAINT_FILL := 1.25
const PAINT_RIM := 0.22
const PAINT_ROUGH := 0.4
const COAT_ROUGH := 0.07
const GRIT := 0.2
const GRIT_SCALE := 4.5
## Each paint's weathering at worn (plane_surface `wear` at wear 1), its own
## colour shift (`own`, so neighbouring paints read as painted apart), its
## sheen (`shine`, the metal's and the canopy's) and its lacquer (`coat`).
const FINISH := {
	"wood":[1.0,0.3,0.3,1.0],
	"dark":[0.55,0.5,0.0,0.7],
	"trim":[1.0,0.25,0.3,1.0],
	"cream":[0.9,0.6,0.15,0.55],
	"canopy":[0.5,0.2,1.2,1.0],
	"varnish":[0.8,0.3,0.15,1.0],
	"brass":[0.55,0.4,0.8,0.3],
	"steel":[0.6,0.7,0.0,0.0],
}
## The joined meshes' normals are smoothed across edges whose faces turn
## less than CREASE (radians); points nearer than 1/SNAP m are one.
const CREASE := 0.75
const SNAP := 10000.0
## Brass: the dull brown it tarnishes toward (its share at worn), and its
## sheen's fall worn.
const TARNISH := Color("7d6a45")
const TARNISH_SHARE := 0.55
const BRASS_SHINE_WORN := 0.35
## The wings: the upper's span (m) and the lower's, the chord at the root
## and the tip, the thickness, the ribs out each side, the height of the
## lower and upper wing over the body's middle, and how far the upper sits
## forward. The cloth sags SAG (of the thickness) between the ribs above,
## SAG_UNDER below; the tips round off past ROUND of the half span.
const SPAN := 1.4
const LOWER_SPAN := 1.26
const CHORD := 0.3
const TIP_CHORD := 0.25
const THICK := 0.042
const RIBS := 5
const SAG := 0.05
const SAG_UNDER := 0.03
const ROUND := 0.84
const LOWER_Y := -0.1
const UPPER_Y := 0.31
const STAGGER := -0.06
## The ailerons, out along the upper wing's trailing edge (fractions of its
## half span), and their depth (m); the elevator's depth.
const AILERON_SPAN := Vector2(0.42,0.78)
const AILERON_DEPTH := 0.065
const ELEVATOR_DEPTH := 0.06
## The section of the wings, (along the chord, up) as fractions of the
## chord and the thickness: the upper surface from the leading edge back,
## then the lower forward.
const AIRFOIL_TOP := [Vector2(0.0,0.0),Vector2(0.04,0.42),Vector2(0.14,0.78),Vector2(0.3,1.0),Vector2(0.55,0.86),Vector2(0.8,0.5),Vector2(1.0,0.08)]
const AIRFOIL_UNDER := [Vector2(1.0,-0.02),Vector2(0.6,-0.135),Vector2(0.25,-0.22),Vector2(0.06,-0.2)]
const AIRFOIL_SCALE := 0.72
## Control surfaces: radians of aileron per radian a second of roll, of
## elevator per radian a second of pitch, and the most either tips.
const AILERON := 0.35
const ELEVATOR := 0.5
const DEFLECT := 0.5
## The propeller: turns a second at rest and per m/s of speed; the blades
## hide past PROP_HIDE turns a second (shown again under PROP_SHOW), leaving
## the disc; the disc's strength at rest and at speed, and how fast its
## sweeps crawl round (radians a second).
const PROP_TURNS := 3.0
const PROP_PER := 0.6
const PROP_HIDE := 9.5
const PROP_SHOW := 8.5
const BLUR := Vector2(0.22,0.55)
const BLUR_CRAWL := 1.4
## The landing mark shows within MARK_HEIGHT m of the ground.
const MARK_HEIGHT := 28.0
## The wingtip vapour: points kept a tip, laid every VAPOUR_EVERY seconds
## (so a trail lasts VAPOUR*VAPOUR_EVERY), its width new and old and its
## strength (toy m, grown with the plane), its drift up and outward (m/s),
## how fast a tip's strength follows `near` (seconds) and its colour.
const VAPOUR := 40
const VAPOUR_EVERY := 0.03
const VAPOUR_WIDTH := Vector2(0.07,1.1)
const VAPOUR_ALPHA := 0.45
const VAPOUR_DRIFT := Vector2(0.12,0.22)
const VAPOUR_EASE := 0.12
const VAPOUR_COLOR := Color(1.0,0.99,0.96)

var _prop: Node3D
var _blur: MeshInstance3D
## True while it stands parked on the land, not flying.
var parked := false
var _blur_material: ShaderMaterial
var _blades_shown := true
var _prop_angle := 0.0
## The ailerons (left, right) and the elevator, on their hinges.
var _ailerons: Array[Node3D] = []
var _elevator: Node3D
var _last_roll := 0.0
var _last_pitch := 0.0
var _mark: MeshInstance3D
var _mark_material: StandardMaterial3D
var _mark_bright := 0.0
var _vapour: MeshInstance3D
var _vapour_mesh: ImmediateMesh
var _vapour_points := PackedVector3Array()
var _vapour_strength := PackedFloat32Array()
var _vapour_clock := 0.0
## Each tip's vapour strength now, eased toward what `update` asks.
var _vapour_now := Vector2.ZERO
## The paints it was built in.
var _paints := {}
## How worn its paint is (`set_wear`).
var _wear := 0.0

## `livery` repaints it (scripts/sky_traffic.gd): any of body, dark, trim
## and wing, each a Color, and wear (0 to 1, `set_wear`); the wanderer's
## own plane takes none, new.
func _init(livery := {}) -> void:
	name = "Plane"
	var paint := paints(livery)
	_paints = paint
	_wear = clampf(float(livery.get("wear",0.0)),0.0,1.0)
	var wood: Material = paint.wood
	var dark: Material = paint.dark
	var trim: Material = paint.trim
	var cream: Material = paint.cream
	var canopy: Material = paint.canopy
	var brass: Material = paint.brass
	# The body runs along -Z, the nose forward: plump and round, deepest at
	# the cockpit, tapering to the tail post; a round cowl round the nose
	# and the brass spinner.
	_add(_hull([Vector3(-0.47,0.15,0.155),Vector3(-0.36,0.163,0.168),Vector3(-0.12,0.168,0.172),Vector3(0.1,0.152,0.156),Vector3(0.3,0.112,0.118),Vector3(0.5,0.068,0.078),Vector3(0.7,0.022,0.036)],20),wood,Vector3.ZERO,Vector3.ZERO)
	_add_piece("cowl",paint)
	_add_piece("spinner",paint)
	# A band of trim round the body before the tail.
	_add(_hull([Vector3(0.4,0.098,0.104),Vector3(0.46,0.087,0.094)],20),trim,Vector3.ZERO,Vector3.ZERO)
	# The cockpit closed over, behind the upper wing: a low tinted canopy,
	# rounded at both ends.
	_add(_hull([Vector3(0.03,0.02,0.012),Vector3(0.08,0.062,0.052),Vector3(0.15,0.084,0.078),Vector3(0.25,0.086,0.08),Vector3(0.33,0.07,0.062),Vector3(0.38,0.035,0.03)],18),canopy,Vector3(0.0,0.14,0.0),Vector3.ZERO)
	# The wings: a lower wing through the body and a longer upper one on
	# struts, the upper a little forward; cream doped cloth, tipped in the
	# trim, the upper with roundels near its tips.
	var rounded := SPAN*0.5*0.8
	var ailerons := Vector3(SPAN*0.5*AILERON_SPAN.x,SPAN*0.5*AILERON_SPAN.y,_hinge_z())
	_add(_wing(SPAN*0.5,-rounded,rounded,ailerons),cream,Vector3(0.0,UPPER_Y,STAGGER),Vector3.ZERO)
	var lower_round := LOWER_SPAN*0.5*0.8
	_add(_wing(LOWER_SPAN*0.5,-lower_round,lower_round),cream,Vector3(0.0,LOWER_Y,0.0),Vector3.ZERO)
	for side in [-1.0,1.0]:
		var tip := Vector2(rounded,SPAN*0.5) if side > 0.0 else Vector2(-SPAN*0.5,-rounded)
		_add(_wing(SPAN*0.5,tip.x,tip.y),trim,Vector3(0.0,UPPER_Y,STAGGER),Vector3.ZERO)
		var low := Vector2(lower_round,LOWER_SPAN*0.5) if side > 0.0 else Vector2(-LOWER_SPAN*0.5,-lower_round)
		_add(_wing(LOWER_SPAN*0.5,low.x,low.y),trim,Vector3(0.0,LOWER_Y,0.0),Vector3.ZERO)
		# A roundel on the upper wing, on the cloth as it lies.
		var at := Vector2(SPAN*0.3*side,-CHORD*0.5+0.42*_chord_at(SPAN*0.5,SPAN*0.3))
		var rings := [[0.066,trim],[0.03,wood]]
		for k in range(rings.size()):
			_add(_decal(SPAN*0.5,at,float(rings[k][0]),0.0015+0.0005*k),rings[k][1],Vector3(0.0,UPPER_Y,STAGGER),Vector3.ZERO)
	for side in [-1.0,1.0]:
		# The ailerons hinge into the upper wing's trailing edge, out towards
		# the tips.
		var hinge := Node3D.new()
		hinge.position = Vector3((ailerons.x+ailerons.y)*0.5*side,UPPER_Y+0.004,STAGGER+ailerons.z)
		add_child(hinge)
		var flap := MeshInstance3D.new()
		flap.mesh = _scaled(_prism([Vector2(0.0,0.008),Vector2(AILERON_DEPTH,-0.001),Vector2(0.0,-0.008)]),Vector3(ailerons.y-ailerons.x-0.004,1.0,1.0))
		flap.material_override = cream
		hinge.add_child(flap)
		_ailerons.append(hinge)
		# A pair of interplane struts a side and a cabane from the upper wing
		# to the body; no wires.
		var out: float = SPAN*0.34*side
		for dz in [-0.08,0.08]:
			_strut(Vector3(out,LOWER_Y,dz),Vector3(out,UPPER_Y,dz+STAGGER),dark,0.012)
		for dz in [-0.05,0.05]:
			_strut(Vector3(0.1*side,0.15,-0.25+dz),Vector3(0.13*side,UPPER_Y,STAGGER+dz),dark,0.01)
		# The undercarriage: a sturdy V of legs either side to the axle, and
		# the wheels on it.
		_strut(Vector3(0.08*side,-0.15,-0.38),Vector3(0.165*side,-0.33,-0.28),dark,0.013)
		_strut(Vector3(0.08*side,-0.15,-0.17),Vector3(0.165*side,-0.33,-0.28),dark,0.013)
		_add_piece("wheel",paint,null,side)
	_strut(Vector3(-0.17,-0.33,-0.28),Vector3(0.17,-0.33,-0.28),dark,0.011)
	# A tail skid it rests on, parked (scripts/plane_strip.gd TAIL).
	_strut(Vector3(0.0,-0.03,0.58),Vector3(0.0,-0.11,0.66),dark,0.013)
	_add(FacetMesh.gem(0.02),brass,Vector3(0.0,-0.1,0.66),Vector3.ZERO)
	# The tail: a teal fin with a cream rudder, a cream tailplane and its
	# elevator either side of the rudder.
	_add_piece("fin",paint)
	_add(_wing(0.26,-0.26,0.26,Vector3.ZERO,0.14,0.11,0.024,2),cream,Vector3(0.0,0.03,0.62),Vector3.ZERO)
	_elevator = Node3D.new()
	_elevator.position = Vector3(0.0,0.032,0.62+0.07)
	add_child(_elevator)
	for side in [-1.0,1.0]:
		var elevator := MeshInstance3D.new()
		elevator.mesh = _scaled(_prism([Vector2(0.0,0.006),Vector2(ELEVATOR_DEPTH,0.0),Vector2(0.0,-0.006)]),Vector3(0.21,1.0,1.0))
		elevator.material_override = cream
		elevator.position = Vector3(0.13*side,0.0,0.0)
		_elevator.add_child(elevator)
	# The propeller: two varnished wooden blades, brass-sheathed at the
	# tips, and the soft disc of air they turn into, at the nose.
	_prop = Node3D.new()
	_prop.position = Vector3(0.0,0.0,-0.68)
	add_child(_prop)
	var varnish: Material = paint.varnish
	_add_piece("propeller",paint,_prop)
	var blur := MeshInstance3D.new()
	_blur = blur
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE*0.6
	blur.mesh = disc
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = PROP_BLUR
	blur.material_override = _blur_material
	blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blur.position = Vector3(0.0,0.0,-0.69)
	add_child(blur)
	_mark = MeshInstance3D.new()
	var mark := QuadMesh.new()
	mark.size = Vector2.ONE
	mark.orientation = PlaneMesh.FACE_Y
	_mark.mesh = mark
	_mark.top_level = true
	_mark_material = StandardMaterial3D.new()
	_mark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_material.albedo_texture = FacetMesh.soft_ring()
	_mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mark.material_override = _mark_material
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.visible = false
	add_child(_mark)
	_vapour_mesh = ImmediateMesh.new()
	_vapour = MeshInstance3D.new()
	_vapour.name = "Vapour"
	_vapour.mesh = _vapour_mesh
	_vapour.top_level = true
	var mist := StandardMaterial3D.new()
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.vertex_color_use_as_albedo = true
	mist.albedo_texture = FacetMesh.soft_band()
	mist.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vapour.material_override = mist
	_vapour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vapour.visible = false
	add_child(_vapour)
	_vapour_points.resize(VAPOUR*2)
	_vapour_strength.resize(VAPOUR*2)
	# The body's paint first among its children (sky_traffic tells liveries
	# by it).
	_join(self,wood)
	_join(_prop,varnish)

## Its parent must be a plain Node (or the scene root): it is placed by its
## own transform. The mark and the vapour are top level, in global space.
##
## Starts it flying from where it is now, the vapour gone.
func reset(glide: RefCounted) -> void:
	parked = false
	_mark_bright = 0.0
	_vapour_clock = 0.0
	_vapour_points.fill(glide.position)
	_vapour_strength.fill(0.0)
	_vapour_now = Vector2.ZERO
	_last_roll = _roll(glide)
	_last_pitch = float(glide.pitch)
	update(0.0,glide,0.0,Callable(),false)

## The world moved under it (SkyIslands `arrive`): the vapour goes too.
func shift(by: Vector3) -> void:
	for i in range(_vapour_points.size()): _vapour_points[i] += by

## One frame: posed on `glide` (a SkyPlane, or a plain
## glide drawn without its roll), `dive` held 0..1 (unused), `ground` the
## height under a point, `landable` whether a touch now would land, and
## `near` (0 to 1) how hard the vapour pulls off its wingtips and `lean`
## the bank, the outer tip's the stronger.
func update(delta: float, glide: RefCounted, _dive: float, ground: Callable, landable: bool, near := 0.0, lean := 0.0) -> void:
	var at: Vector3 = glide.position
	var roll := _roll(glide)
	transform = pose(at,float(glide.heading),float(glide.pitch),roll)
	# The control surfaces follow how fast it rolls and pitches.
	var roll_rate := (roll-_last_roll)/delta if delta > 0.0 else 0.0
	var pitch_rate := (float(glide.pitch)-_last_pitch)/delta if delta > 0.0 else 0.0
	var running: Variant = glide.get("engine")
	if delta > 0.0:
		var rolled := clampf(roll_rate*AILERON,-DEFLECT,DEFLECT)
		var pitched := clampf(pitch_rate*ELEVATOR,-DEFLECT,DEFLECT)
		var k := 1.0-exp(-delta/0.08)
		for s in range(2):
			var hand := -1.0 if s == 0 else 1.0
			_ailerons[s].rotation.x = lerpf(_ailerons[s].rotation.x,rolled*hand,k)
		_elevator.rotation.x = lerpf(_elevator.rotation.x,pitched,k)
	_last_roll = roll
	_last_pitch = float(glide.pitch)
	var pace := float(glide.speed)
	_spin_prop(delta,pace,float(running) if running != null else 1.0)
	_trail_vapour(delta,near,lean)
	_place_mark(delta,at,ground,landable)

## The propeller turns with the speed while the engine runs (`running`, 0
## to 1), its blur fading as it spins down. Too fast to see, the blades
## give way to the disc alone, its sweeps crawling round.
func _spin_prop(delta: float, pace: float, running: float) -> void:
	var turns := (PROP_TURNS+PROP_PER*pace)*running
	_prop_angle = wrapf(_prop_angle+delta*turns*TAU,0.0,TAU)
	_prop.rotation.z = _prop_angle
	if _blades_shown and turns > PROP_HIDE: _blades_shown = false
	elif not _blades_shown and turns < PROP_SHOW: _blades_shown = true
	for blade in _prop.get_children(): blade.visible = _blades_shown
	var fast := clampf(pace/30.0,0.0,1.0)
	_blur_material.set_shader_parameter("strength",lerpf(BLUR.x,BLUR.y,fast)*smoothstep(0.0,0.6,running))
	_blur_material.set_shader_parameter("spread",fast)
	_blur_material.set_shader_parameter("phase",fmod(Time.get_ticks_msec()*0.001*BLUR_CRAWL,TAU)*running)
	_blur.visible = running > 0.01

## Where the figure stands for a flight's pose: its position (the flight's,
## the figure hangs FIGURE_DROP under it), heading, pitch and roll.
static func pose(at: Vector3, heading: float, pitch: float, roll: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch,heading,-roll)),at+Vector3.DOWN*0.2)

## Stands it parked: `placed` is its transform in its parent's frame (the
## plate's, so it turns and moves with the land); the engine off, no mark
## or vapour.
func park(placed: Transform3D) -> void:
	parked = true
	transform = placed
	_spin_prop(0.0,0.0,0.0)
	_mark.visible = false
	_vapour.visible = false

## The whole roll it is drawn at: the bank and, on a plane, the barrel roll.
func _roll(glide: RefCounted) -> float:
	var spin: Variant = glide.get("spin")
	return float(glide.bank)+(float(spin) if spin != null else 0.0)

## The vapour: each upper wingtip lays a point every VAPOUR_EVERY seconds,
## as strong as `near` asks (eased, so it swells and thins rather than
## pops), the tip on the outside of the bank `side` the stronger; the
## points hang, drifting and widening as they fade.
func _trail_vapour(delta: float, near: float, side: float) -> void:
	_vapour_clock += delta
	var lay := _vapour_clock >= VAPOUR_EVERY
	if lay: _vapour_clock = fmod(_vapour_clock,VAPOUR_EVERY)
	var grown := basis.x.length()
	var follow := 1.0-exp(-delta/VAPOUR_EASE) if delta > 0.0 else 1.0
	var shown := false
	for s in range(2):
		var hand := -1.0 if s == 0 else 1.0
		var o := s*VAPOUR
		if lay:
			for i in range(VAPOUR-1,0,-1):
				_vapour_points[o+i] = _vapour_points[o+i-1]
				_vapour_strength[o+i] = _vapour_strength[o+i-1]
		var drift := (Vector3.UP*VAPOUR_DRIFT.x+basis.x.normalized()*hand*VAPOUR_DRIFT.y)*grown*delta
		for i in range(1,VAPOUR): _vapour_points[o+i] += drift*float(i)/VAPOUR
		_vapour_points[o] = transform*Vector3(SPAN*0.5*hand,UPPER_Y,STAGGER)
		_vapour_now[s] = lerpf(_vapour_now[s],clampf(near,0.0,1.0)*clampf(0.6+0.6*side*hand,0.25,1.0),follow)
		_vapour_strength[o] = _vapour_now[s]
		for i in range(VAPOUR): shown = shown or _vapour_strength[o+i] > 0.004
	_vapour.visible = shown
	if not shown: return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	_vapour_mesh.clear_surfaces()
	for s in range(2):
		var o := s*VAPOUR
		_vapour_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in range(VAPOUR):
			var p := _vapour_points[o+i]
			var age := float(i)/(VAPOUR-1)
			var along := _vapour_points[o+maxi(i-1,0)]-_vapour_points[o+mini(i+1,VAPOUR-1)]
			var facing := basis.y
			if camera != null and along.length_squared() > 0.000001:
				var across := along.cross(camera.global_position-p)
				if across.length_squared() > 0.000001: facing = across
			facing = facing.normalized()*lerpf(VAPOUR_WIDTH.x,VAPOUR_WIDTH.y,sqrt(age))*grown*0.5
			var c := VAPOUR_COLOR
			c.a = _vapour_strength[o+i]*VAPOUR_ALPHA*(1.0-age)*(1.0-age)*smoothstep(0.0,0.08,age+0.02)
			_vapour_mesh.surface_set_color(c)
			_vapour_mesh.surface_set_uv(Vector2(0.0,age))
			_vapour_mesh.surface_add_vertex(p-facing)
			_vapour_mesh.surface_set_color(c)
			_vapour_mesh.surface_set_uv(Vector2(1.0,age))
			_vapour_mesh.surface_add_vertex(p+facing)
		_vapour_mesh.surface_end()

func _place_mark(delta: float, at: Vector3, ground: Callable, landable: bool) -> void:
	var under: Variant = ground.call(at) if ground.is_valid() else null
	if under is Vector2:
		var body := under as Vector2
		under = body.x if at.y > body.x else null
	var height := at.y-float(under) if under != null else INF
	_mark.visible = height < MARK_HEIGHT
	if not _mark.visible: return
	_mark_bright = lerpf(_mark_bright,float(landable),1.0-exp(-delta/0.2)) if delta > 0.0 else float(landable)
	var close := 1.0-clampf(height/MARK_HEIGHT,0.0,1.0)
	var size := lerpf(1.2,2.8,clampf(height/12.0,0.0,1.0))
	_mark.transform = Transform3D(Basis().scaled(Vector3(size,1.0,size)),Vector3(at.x,float(under)+0.06,at.z))
	_mark_material.albedo_color = Color(1.0,0.97,0.88,close*lerpf(0.35,0.85,_mark_bright))

# --- The paint ----------------------------------------------------------------------

func _ready() -> void:
	_finish(_paints,_wear)

## How worn its paint is, `t` from 0 (new: deep clean lacquer, crisp trim,
## bright brass, glowing varnish, taut clean cloth) to 1 (dusty, faded,
## scuffed, the coat dull, the brass tarnished).
func set_wear(t: float) -> void:
	_wear = clampf(t,0.0,1.0)
	_finish(_paints,_wear)

## How worn its paint is now (`set_wear`).
func get_wear() -> float:
	return _wear

## The plane's paints by name, `livery` (see `_init`) repainting the body,
## dark, trim and wing and setting their wear (new without); the pieces
## (`piece`) name theirs from these.
static func paints(livery := {}) -> Dictionary:
	var out := {
		"wood":_paint(livery.get("body",WOOD)),
		"dark":_paint(livery.get("dark",DARK)),
		"trim":_paint(livery.get("trim",TRIM)),
		"cream":_paint(livery.get("wing",WING)),
		"canopy":_metal(CANOPY),
		"brass":_metal(BRASS),
		"steel":_metal(STEEL),
		"varnish":_paint(PROPWOOD),
	}
	_finish(out,clampf(float(livery.get("wear",0.0)),0.0,1.0))
	return out

## Puts `paint` (`paints`) at wear `t` (`set_wear`): each paint's
## weathering, the brass tarnishing and dulling.
static func _finish(paint: Dictionary, t: float) -> void:
	for key: String in FINISH:
		if not paint.has(key): continue
		var m := paint[key] as ShaderMaterial
		var f: Array = FINISH[key]
		m.set_shader_parameter("wear",float(f[0])*t)
		m.set_shader_parameter("own",float(f[1]))
		m.set_shader_parameter("shine",float(f[2])*(lerpf(1.0,BRASS_SHINE_WORN,t) if key == "brass" else 1.0))
		m.set_shader_parameter("coat",float(f[3]))
	if paint.has("brass"):
		(paint.brass as ShaderMaterial).set_shader_parameter("albedo",BRASS.lerp(TARNISH,TARNISH_SHARE*t))

# --- The pieces ---------------------------------------------------------------------

## One of the plane's pieces, as [mesh, paint name (`paints`), transform]
## parts placed as on the figure: "cowl" (the round cowl round the nose and
## its dark face), "spinner", "propeller" (in the propeller's own frame,
## its hub at the origin), "wheel" (`side` -1 the left, 1 the right) and
## "fin" (the fin and its cream rudder). `fine` multiplies the sides round
## every hull and frustum.
static func piece(id: String, side := 1.0, fine := 1) -> Array:
	var out := []
	match id:
		"cowl":
			out.append([_hull([Vector3(-0.63,0.112,0.112),Vector3(-0.61,0.142,0.142),Vector3(-0.56,0.16,0.162),Vector3(-0.47,0.162,0.166),Vector3(-0.44,0.157,0.162)],20*fine),"trim",Transform3D.IDENTITY])
			out.append([FacetMesh.frustum(0.098,0.098,0.006,20*fine),"steel",_placed(Vector3(0.0,0.0,-0.632),Vector3(PI*0.5,0.0,0.0))])
		"spinner":
			out.append([_hull([Vector3(-0.78,0.0,0.0),Vector3(-0.755,0.036,0.036),Vector3(-0.71,0.06,0.06),Vector3(-0.66,0.068,0.068),Vector3(-0.63,0.066,0.066)],16*fine),"brass",Transform3D.IDENTITY])
		"propeller":
			# Two varnished wooden blades, brass-sheathed at the tips.
			for turn: float in [0.0,PI]:
				var lay := Transform3D(Basis(Vector3.BACK,turn)*Basis(Vector3.UP,0.32)*Basis(Vector3.RIGHT,-PI*0.5),Vector3.ZERO)
				out.append([_hull([Vector3(0.0,0.014,0.011),Vector3(0.04,0.03,0.01),Vector3(0.16,0.028,0.008),Vector3(0.24,0.02,0.006)],6*fine),"varnish",lay])
				out.append([_hull([Vector3(0.237,0.0205,0.0065),Vector3(0.266,0.014,0.005),Vector3(0.275,0.005,0.003)],6*fine),"brass",lay])
		"wheel":
			# A fat tyre, a cream wheel disc and a brass hub.
			out.append([FacetMesh.frustum(0.08,0.08,0.05,18*fine),"steel",_placed(Vector3(0.205*side,-0.33,-0.28),Vector3(0.0,0.0,PI*0.5))])
			out.append([FacetMesh.frustum(0.055,0.055,0.056,18*fine),"cream",_placed(Vector3(0.205*side,-0.33,-0.28),Vector3(0.0,0.0,PI*0.5))])
			out.append([FacetMesh.frustum(0.022,0.016,0.07,8*fine),"brass",_placed(Vector3(0.215*side,-0.33,-0.28),Vector3(0.0,0.0,PI*0.5))])
		"fin":
			out.append([_prism([Vector2(-0.11,0.0),Vector2(0.1,0.0),Vector2(0.1,0.21),Vector2(0.07,0.25),Vector2(0.03,0.265),Vector2(-0.01,0.25),Vector2(-0.06,0.15)],0.02),"trim",_placed(Vector3(0.0,0.03,0.58),Vector3.ZERO)])
			out.append([_prism([Vector2(0.1,-0.04),Vector2(0.15,-0.04),Vector2(0.168,0.06),Vector2(0.16,0.17),Vector2(0.13,0.215),Vector2(0.1,0.21)],0.016),"cream",_placed(Vector3(0.0,0.03,0.58),Vector3.ZERO)])
	return out

## A part at `at`, turned by `turn` (Euler angles, as Node3D.rotation).
static func _placed(at: Vector3, turn: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(turn),at)

# --- Building -----------------------------------------------------------------------

## Paint (shaders/plane_surface.gdshader): lit as the stone is, with a
## light grime; its wear is set by `_finish`.
static func _paint(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PLANE_SURFACE
	m.set_shader_parameter("albedo",color)
	m.set_shader_parameter("fill",PAINT_FILL)
	m.set_shader_parameter("rim",PAINT_RIM)
	m.set_shader_parameter("roughness_value",PAINT_ROUGH)
	m.set_shader_parameter("coat_roughness",COAT_ROUGH)
	m.set_shader_parameter("grit",GRIT)
	m.set_shader_parameter("grit_scale",GRIT_SCALE)
	return m

## Metal (and the canopy): the same paint with a tighter sheen (FINISH's
## `shine`).
static func _metal(color: Color) -> ShaderMaterial:
	var m := _paint(color)
	m.set_shader_parameter("shine",0.6)
	return m

## A fixed part on `parent` (the figure if null), joined with the rest of
## its material's by `_join`.
func _add(mesh: Mesh, material: Material, at: Vector3, turn: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = turn
	part.set_meta("join",true)
	(parent if parent != null else self).add_child(part)
	return part

## A strut from `from` to `to`, `radius` thick.
func _strut(from: Vector3, to: Vector3, material: Material, radius := 0.014) -> MeshInstance3D:
	var part := _add(FacetMesh.frustum(radius,radius,1.0,8),material,Vector3.ZERO,Vector3.ZERO)
	part.transform = _strut_at(from,to)
	return part

## Where a strut from `from` to `to` stands: a unit frustum along Y
## stretched and turned onto the line.
static func _strut_at(from: Vector3, to: Vector3) -> Transform3D:
	var y := (to-from)
	var x := y.cross(Vector3.FORWARD if absf(y.normalized().dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(x,y,x.cross(y.normalized()).normalized()),(from+to)*0.5)

## A piece's parts (`piece`) added as fixed parts on `parent`, in `paint`.
func _add_piece(id: String, paint: Dictionary, parent: Node3D = null, side := 1.0) -> void:
	for p: Array in piece(id,side):
		var part := _add(p[0],paint[p[1]],Vector3.ZERO,Vector3.ZERO,parent)
		part.transform = p[2]

## Joins `parent`'s fixed parts (`_add`'s) into one mesh for each material,
## that of `first` first among its children.
func _join(parent: Node3D, first: Material) -> void:
	var groups := {}
	for child in parent.get_children():
		if not (child is MeshInstance3D and child.has_meta("join")): continue
		var part := child as MeshInstance3D
		var material := part.material_override
		if not groups.has(material): groups[material] = [PackedVector3Array(),PackedVector3Array()]
		var into: PackedVector3Array = groups[material][0]
		var facing: PackedVector3Array = groups[material][1]
		var arrays := part.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var placed := part.transform
		var turn := placed.basis.inverse().transposed()
		var order: Variant = indices if indices is PackedInt32Array and (indices as PackedInt32Array).size() > 0 else range(vertices.size())
		for i: int in order:
			into.append(placed*vertices[i])
			facing.append((turn*normals[i]).normalized())
		groups[material] = [into,facing]
		parent.remove_child(part)
		part.free()
	for material: Material in groups:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = groups[material][0]
		arrays[Mesh.ARRAY_NORMAL] = _smooth(groups[material][0],groups[material][1])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var joined := MeshInstance3D.new()
		joined.mesh = mesh
		joined.material_override = material
		parent.add_child(joined)
		if material == first: parent.move_child(joined,0)

## Smooth normals for the triangles `vertices` from their flat `facing`:
## each vertex takes the mean of the faces meeting at its point that turn
## less than CREASE from its own.
static func _smooth(vertices: PackedVector3Array, facing: PackedVector3Array) -> PackedVector3Array:
	var at := {}
	for i in range(vertices.size()):
		var key := Vector3i((vertices[i]*SNAP).round())
		if not at.has(key): at[key] = []
		(at[key] as Array).append(i)
	var crease := cos(CREASE)
	var out := PackedVector3Array()
	out.resize(vertices.size())
	for i in range(vertices.size()):
		var sum := Vector3.ZERO
		for j: int in at[Vector3i((vertices[i]*SNAP).round())]:
			if facing[j].dot(facing[i]) >= crease: sum += facing[j]
		out[i] = sum.normalized() if sum.length_squared() > 1e-12 else facing[i]
	return out

# --- The wings ------------------------------------------------------------------------

## A wing's chord `x` m out along a wing of `half` span each side.
static func _chord_at(half: float, x: float, root := CHORD, tip := TIP_CHORD) -> float:
	return lerpf(root,tip,minf(absf(x)/(half*ROUND),1.0))

## Where the ailerons hinge, along the upper wing's chord from its middle.
static func _hinge_z() -> float:
	return -CHORD*0.5+_chord_at(SPAN*0.5,SPAN*0.5*(AILERON_SPAN.x+AILERON_SPAN.y)*0.5)-AILERON_DEPTH

## A wing's section `x` m out: its leading edge (z), chord, the scale of
## its upper and lower surface (m, sagging between the ribs) and where its
## trailing edge is cut back for an aileron (z). Past ROUND the tip rounds
## off, the chord and the thickness closing in an ellipse.
static func _station(half: float, x: float, root: float, tip: float, thick: float, ribs: int, cut := Vector3.ZERO) -> Dictionary:
	var a := absf(x)
	var edge := half*ROUND
	var le := -root*0.5
	var c := _chord_at(half,a,root,tip)
	var size := 1.0
	var top := 1.0
	var under := 1.0
	if a > edge:
		var q := clampf((a-edge)/(half-edge),0.0,1.0)
		var e := maxf(sqrt(maxf(1.0-q*q,0.0)),0.12)
		var mid := le+tip*0.5
		c = tip*e
		le = mid-c*0.5
		size = maxf(e,0.3)
	else:
		var bay := half/ribs
		var between := 1.0-absf(2.0*fposmod(a,bay)/bay-1.0)
		top -= SAG*between
		under -= SAG_UNDER*between
	var stop := INF
	if cut != Vector3.ZERO and a > cut.x and a < cut.y: stop = cut.z
	var t := thick*AIRFOIL_SCALE*size
	return {"le":le,"chord":c,"top":t*top,"under":t*under,"stop":stop}

## The section's outline as (z, y), the upper surface back, the lower forward.
static func _section(s: Dictionary) -> Array:
	var out := []
	for p: Vector2 in AIRFOIL_TOP: out.append(Vector2(minf(s.le+p.x*s.chord,s.stop),p.y*s.top))
	for p: Vector2 in AIRFOIL_UNDER: out.append(Vector2(minf(s.le+p.x*s.chord,s.stop),p.y*s.under))
	return out

## A wing of `half` span each side, the piece from `from` to `to` m out
## (negative to the left): an airfoil in section, tapering from `root` to
## `tip` chord and rounded at the tips, `thick` deep, its cloth drawn over
## `ribs` ribs each side and sagging a little between them. `cut` (out
## from, out to, z) cuts the trailing edge back to z between those for the
## ailerons.
static func _wing(half: float, from: float, to: float, cut := Vector3.ZERO, root := CHORD, tip := TIP_CHORD, thick := THICK, ribs := RIBS) -> ArrayMesh:
	var edge := half*ROUND
	var xs := [from,to]
	for k in range(-ribs*2,ribs*2+1):
		var x := half/ribs*k*0.5
		if absf(x) < edge: xs.append(x)
	for q in [0.0,0.4,0.7,0.88,0.97,1.0]:
		for hand in [-1.0,1.0]: xs.append(hand*(edge+(half-edge)*q))
	if cut != Vector3.ZERO:
		for e in [cut.x,cut.y]:
			for hand in [-1.0,1.0]:
				xs.append(hand*e-0.0005)
				xs.append(hand*e+0.0005)
	xs = xs.filter(func(x: float) -> bool: return x >= from-1e-6 and x <= to+1e-6)
	xs.sort()
	var stations := []
	for x: float in xs:
		if stations.is_empty() or x-float(stations[-1]) > 1e-5: stations.append(x)
	var tris := []
	var before := []
	var before_mid := Vector3.ZERO
	for i in range(stations.size()):
		var x: float = stations[i]
		var s := _station(half,x,root,tip,thick,ribs,cut)
		var points := []
		for p: Vector2 in _section(s): points.append(Vector3(x,p.y,p.x))
		var mid := Vector3(x,(s.top-s.under)*0.1,s.le+s.chord*0.35)
		var n := points.size()
		if i == 0 or i == stations.size()-1:
			var inward := Vector3(0.001 if i == 0 else -0.001,0.0,0.0)
			for k in range(n): tris.append([mid,points[k],points[(k+1)%n],mid+inward])
		if i > 0:
			var inside := (mid+before_mid)*0.5
			for k in range(n):
				var a0: Vector3 = before[k]
				var a1: Vector3 = before[(k+1)%n]
				var b0: Vector3 = points[k]
				var b1: Vector3 = points[(k+1)%n]
				tris.append([a0,b0,b1,inside])
				tris.append([a0,b1,a1,inside])
		before = points
		before_mid = mid
	return FacetMesh.shell(tris)

## The upper wing's top at (x, z), sagging between its ribs as the cloth.
static func _on_top(half: float, at: Vector2) -> Vector3:
	var s := _station(half,at.x,CHORD,TIP_CHORD,THICK,RIBS)
	var u := clampf((at.y-float(s.le))/float(s.chord),0.0,1.0)
	var v := 0.0
	for k in range(AIRFOIL_TOP.size()-1):
		var p: Vector2 = AIRFOIL_TOP[k]
		var q: Vector2 = AIRFOIL_TOP[k+1]
		if u >= p.x and u <= q.x:
			v = lerpf(p.y,q.y,(u-p.x)/maxf(q.x-p.x,1e-6))
			break
	return Vector3(at.x,v*float(s.top),at.y)

## A painted disc of `radius` on the upper wing's top at `at` (x, z),
## `lift` m over the cloth.
static func _decal(half: float, at: Vector2, radius: float, lift: float) -> ArrayMesh:
	var tris := []
	var n := 20
	var centre := _on_top(half,at)+Vector3.UP*lift
	for i in range(n):
		var a0 := TAU*i/n
		var a1 := TAU*(i+1)/n
		var p0 := _on_top(half,at+Vector2(cos(a0),sin(a0))*radius)+Vector3.UP*lift
		var p1 := _on_top(half,at+Vector2(cos(a1),sin(a1))*radius)+Vector3.UP*lift
		tris.append([centre,p0,p1,centre+Vector3.DOWN*0.01])
	return FacetMesh.shell(tris)

## A copy of `mesh` stretched by `by`, its normals kept flat.
static func _scaled(mesh: ArrayMesh, by: Vector3) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(vertices.size()):
		vertices[i] *= by
		normals[i] = (normals[i]/by).normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return out

## A flat-shaded body along Z (scripts/facet_mesh.gd `hull`).
static func _hull(rings: Array, sides: int) -> ArrayMesh:
	return FacetMesh.hull(rings,sides)

## A flat-shaded prism along X, from -0.5 to 0.5: `section` is its outline
## in (z, y), convex. With `width` it runs along X only that wide.
static func _prism(section: Array, width := 1.0) -> ArrayMesh:
	var tris := []
	var x := width*0.5
	var mid := Vector2.ZERO
	for p: Vector2 in section: mid += p
	mid /= section.size()
	var inside := Vector3(0.0,mid.y,mid.x)
	for i in range(section.size()):
		var p: Vector2 = section[i]
		var q: Vector2 = section[(i+1)%section.size()]
		tris.append([Vector3(-x,p.y,p.x),Vector3(x,p.y,p.x),Vector3(x,q.y,q.x),inside])
		tris.append([Vector3(-x,p.y,p.x),Vector3(x,q.y,q.x),Vector3(-x,q.y,q.x),inside])
		for e in [-x,x]:
			tris.append([Vector3(e,mid.y,mid.x),Vector3(e,p.y,p.x),Vector3(e,q.y,q.x),Vector3(0.0,mid.y,mid.x)])
	return _shell(tris)

## Triangles as a flat-shaded mesh (scripts/facet_mesh.gd `shell`).
static func _shell(tris: Array) -> ArrayMesh:
	return FacetMesh.shell(tris)
