extends Node3D
## The wanderer flying the little plane (scripts/sky_plane.gd), for the chase
## camera (scripts/glide_camera.gd): a small 1920s biplane in warm wood
## browns, cream doped wings tipped in terracotta, and the wanderer in the
## open cockpit behind a little windscreen, in a leather cap and brass
## goggles, the scarf's two tails streaming behind. It is what flies.
##
## Drawn as a real one is built, at a toy's size: a slim body tapering to a
## knife-edged tail, a round cowl with louvres, a seam of rivets and
## exhaust stacks bent back along the side, a padded coaming and a turtle
## deck behind the pilot's head; thin wings, tapered, rounded at the tips,
## with an airfoil's section, their cloth drawn tight over the ribs and
## sagging a little between them (`_wing`), so every rib shows as a crease
## in the light; roundels on the upper wing; fine struts, wires crossed
## between the wings, a V undercarriage on an axle and spoked-over wheels.
##
## Faceted solids and soft light, as the style asks: every solid is a few
## flat faces, lit as the folk are (shaders/folk_surface.gdshader, so it
## never goes black in shade); the paint lacquered and a little weathered,
## so each facet catches the sun as it turns; the wings a satin doped cloth,
## the spinner and fittings brass. The scarf is soft wool, fluttering faster
## the faster it flies. The propeller is a varnished wooden one with brass
## tips; once it turns too fast to see, only a soft disc of air shows
## (shaders/prop_blur.gdshader), its sweeps crawling round as a filmed one's
## do. It is drawn turned by the bank and the barrel roll together. The
## ailerons tip with the roll, the elevator with the pitch, so the stick
## shows on the wings. A soft mark under it shows where it
## would touch down, and close past rock vapour peels off its upper
## wingtips.
##
## Its fixed parts are joined into one mesh for each material (`_join`), so
## a plane is a dozen draws however finely it is made (the sky's traffic
## flies several, scripts/sky_traffic.gd).
##
## Landed, it stands on its two wheels and a tail skid, nose up (`park`,
## scripts/plane_strip.gd `rest`), the pilot out, the propeller still.

const PlanePilot = preload("res://scripts/plane_pilot.gd")
const FacetMesh = preload("res://scripts/facet_mesh.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const PersonKit = preload("res://scripts/person_kit.gd")
const PROP_BLUR := preload("res://shaders/prop_blur.gdshader")
const FOLK_RIBBON := preload("res://shaders/folk_ribbon.gdshader")
const WOOD := Color("8f5234")
const DARK := Color("6b3b28")
const TRIM := Color("c8643b")
const WING := Color("f3ead6")
const LEATHER := Color("5e3522")
const BRASS := Color("d6ad62")
const STRIPE := Color("f3ead6")
const PROPWOOD := Color("7a4429")
## How weathered the paint is (folk_surface `wear`), the body's and the
## wings' cloth.
const WEAR := Vector2(0.55,0.3)
## The wings: the upper's span (m) and the lower's, the chord at the root
## and the tip, the thickness, the ribs out each side, the height of the
## lower and upper wing over the body's middle, and how far the upper sits
## forward. The cloth sags SAG (of the thickness) between the ribs above,
## SAG_UNDER below; the tips round off past ROUND of the half span.
const SPAN := 1.4
const LOWER_SPAN := 1.26
const CHORD := 0.28
const TIP_CHORD := 0.22
const THICK := 0.028
const RIBS := 7
const SAG := 0.18
const SAG_UNDER := 0.1
const ROUND := 0.86
const LOWER_Y := -0.1
const UPPER_Y := 0.3
const STAGGER := -0.06
## The ailerons, out along the upper wing's trailing edge (fractions of its
## half span), and their depth (m); the elevator's depth.
const AILERON_SPAN := Vector2(0.42,0.78)
const AILERON_DEPTH := 0.06
const ELEVATOR_DEPTH := 0.055
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
## The scarf: points of the long tail and the short, the gap between them
## (m), its width, where its two pale stripes run (fractions of a tail's
## length), and its flutter: the waves' rate (radians a second) slow and
## fast, their reach at the tip (m), and the speed (m/s) it is fastest at.
const SCARF := 12
const SCARF_SHORT := 8
const SCARF_GAP := 0.09
const SCARF_WIDTH := 0.085
const SCARF_STRIPES := [Vector2(0.7,0.77),Vector2(0.83,0.9)]
const FLUTTER := Vector2(5.0,17.0)
const FLUTTER_REACH := 0.035
const FLUTTER_FAST := 18.0
## The landing mark shows within MARK_HEIGHT m of the ground.
const MARK_HEIGHT := 28.0
## The wingtip vapour (scripts/glide_vapour.gd says how near the rock is).
const VAPOUR := 14
const VAPOUR_EVERY := 0.04
const VAPOUR_WIDTH := Vector2(0.06,0.55)
const VAPOUR_ALPHA := 0.42
const VAPOUR_DRIFT := Vector2(0.18,0.3)
const VAPOUR_COLOR := Color(1.0,0.98,0.94)

var _prop: Node3D
var _blur: MeshInstance3D
## The pilot in the cockpit, hidden once they hop out.
var _pilot: Array[Node3D] = []
var _rig: Node3D
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
var _scarf_points := PackedVector3Array()
var _short_points := PackedVector3Array()
var _scarf: MeshInstance3D
var _scarf_mesh: ImmediateMesh
var _mark: MeshInstance3D
var _mark_material: StandardMaterial3D
var _mark_bright := 0.0
var _vapour: MeshInstance3D
var _vapour_mesh: ImmediateMesh
var _vapour_points := PackedVector3Array()
var _vapour_strength := PackedFloat32Array()
var _vapour_clock := 0.0

## `livery` repaints it (scripts/sky_traffic.gd): any of body, dark, trim,
## wing and scarf, each a Color; the wanderer's own plane takes none.
func _init(livery := {}) -> void:
	name = "Plane"
	var wood := _paint(livery.get("body",WOOD),0.32,0.8,WEAR.x)
	var dark := _paint(livery.get("dark",DARK),0.32,0.8,WEAR.x)
	var trim := _paint(livery.get("trim",TRIM),0.32,0.8,WEAR.x)
	var cream := _paint(livery.get("wing",WING),0.5,0.35,WEAR.y)
	var leather := _paint(LEATHER,0.55,0.3,0.0)
	var brass := _metal(BRASS,0.28)
	var steel := _metal(Color("3b3430"),0.4)
	# The body runs along -Z, the nose forward: slim, deepest at the
	# cockpit, tapering to a knife-edged tail post; a round terracotta cowl
	# round the nose, its face dark, its lip and the spinner brass.
	_add(_hull([Vector3(-0.47,0.13,0.135),Vector3(-0.36,0.142,0.15),Vector3(-0.1,0.146,0.158),Vector3(0.1,0.14,0.15),Vector3(0.3,0.105,0.12),Vector3(0.52,0.06,0.085),Vector3(0.72,0.016,0.05)],10),wood,Vector3.ZERO,Vector3.ZERO)
	_add(_hull([Vector3(-0.62,0.1,0.1),Vector3(-0.6,0.125,0.125),Vector3(-0.55,0.14,0.145),Vector3(-0.47,0.143,0.149),Vector3(-0.44,0.139,0.146)],12),trim,Vector3.ZERO,Vector3.ZERO)
	_add(FacetMesh.frustum(0.102,0.102,0.006,12),brass,Vector3(0.0,0.0,-0.619),Vector3(PI*0.5,0.0,0.0))
	_add(FacetMesh.frustum(0.082,0.082,0.006,12),steel,Vector3(0.0,0.0,-0.623),Vector3(PI*0.5,0.0,0.0))
	_add(_hull([Vector3(-0.76,0.0,0.0),Vector3(-0.73,0.03,0.03),Vector3(-0.67,0.052,0.052),Vector3(-0.63,0.056,0.056)],8),brass,Vector3.ZERO,Vector3.ZERO)
	# A seam of rivets where the cowl meets the body, louvres let into its
	# sides, and the exhaust stacks bent back into a pipe along each side.
	for i in range(14):
		var a := TAU*(float(i)+0.5)/14.0
		_add(FacetMesh.gem(0.0055),brass,Vector3(cos(a)*0.141,sin(a)*0.148,-0.452),Vector3.ZERO)
	for side in [-1.0,1.0]:
		for i in range(4):
			_add(_hull([Vector3(-0.035,0.0045,0.0045),Vector3(0.035,0.0045,0.0045)],4),steel,Vector3(0.139*side,0.042-0.026*i,-0.505),Vector3.ZERO)
		for i in range(3):
			var z := -0.56+0.045*i
			_strut(Vector3(0.12*side,-0.05,z),Vector3(0.168*side,-0.075,z+0.03),steel,0.009)
		_strut(Vector3(0.168*side,-0.075,-0.53),Vector3(0.152*side,-0.098,-0.22),steel,0.011)
	# A terracotta band round the body before the tail.
	_add(_hull([Vector3(0.42,0.085,0.104),Vector3(0.47,0.075,0.097)],10),trim,Vector3.ZERO,Vector3.ZERO)
	# The cockpit: a dark tub let into the back, a padded leather coaming,
	# a small glass windscreen in a brass frame before it and a turtle deck
	# behind, rising to a headrest. In it, the wanderer from the chest up,
	# alive in the seat (scripts/plane_pilot.gd).
	_add(_hull([Vector3(-0.12,0.095,0.06),Vector3(0.12,0.095,0.06)],8),dark,Vector3(0.0,0.15,0.22),Vector3.ZERO)
	var rim := _add(FacetMesh.frustum(0.108,0.096,0.03,12),leather,Vector3(0.0,0.2,0.22),Vector3.ZERO)
	rim.scale = Vector3(1.0,1.0,1.3)
	_add(_hull([Vector3(0.0,0.052,0.05),Vector3(0.1,0.04,0.035),Vector3(0.27,0.0,0.0)],8),dark,Vector3(0.0,0.17,0.33),Vector3(0.2,0.0,0.0))
	var screen := _add(_prism([Vector2(0.0,0.0),Vector2(0.005,0.0),Vector2(0.027,0.068),Vector2(0.022,0.068)],0.11),_glass(),Vector3(0.0,0.2,0.1),Vector3.ZERO)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.remove_meta("join")
	for side in [-1.0,1.0]: _strut(Vector3(0.056*side,0.2,0.1),Vector3(0.056*side,0.268,0.124),brass,0.004)
	_strut(Vector3(-0.056,0.268,0.124),Vector3(0.056,0.268,0.124),brass,0.003)
	_rig = PlanePilot.new(PersonKit.outfit(livery.get("scarf",PersonKit.SCARF)))
	# Drawn up by WorldScale.pilot_size so he is the walker's size in the
	# grown plane (the plane itself never changes for him).
	_rig.scale = Vector3.ONE*0.92*WorldScale.pilot_size
	add_child(_rig)
	_pilot.append(_rig)
	# The wings: a lower wing through the body and a longer upper one on
	# struts, the upper a little forward; cream doped cloth tight over the
	# ribs, tipped in terracotta, the upper with roundels near its tips.
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
		var rings := [[0.062,dark],[0.046,trim],[0.018,cream]]
		for k in range(rings.size()):
			_add(_decal(SPAN*0.5,at,float(rings[k][0]),0.0015+0.0005*k),rings[k][1],Vector3(0.0,UPPER_Y,STAGGER),Vector3.ZERO)
	for side in [-1.0,1.0]:
		# The ailerons hinge into the upper wing's trailing edge, out towards
		# the tips.
		var hinge := Node3D.new()
		hinge.position = Vector3((ailerons.x+ailerons.y)*0.5*side,UPPER_Y+0.004,STAGGER+ailerons.z)
		add_child(hinge)
		var flap := MeshInstance3D.new()
		flap.mesh = _scaled(_prism([Vector2(0.0,0.006),Vector2(AILERON_DEPTH,-0.001),Vector2(0.0,-0.006)]),Vector3(ailerons.y-ailerons.x-0.004,1.0,1.0))
		flap.material_override = cream
		hinge.add_child(flap)
		_ailerons.append(hinge)
		# Interplane struts, a cabane from the upper wing to the body, and
		# wires crossed between the wings, glinting.
		var out: float = SPAN*0.34*side
		for dz in [-0.075,0.075]:
			_strut(Vector3(out,LOWER_Y,dz),Vector3(out,UPPER_Y,dz+STAGGER),dark,0.008)
		for dz in [-0.05,0.05]:
			_strut(Vector3(0.09*side,0.14,-0.25+dz),Vector3(0.13*side,UPPER_Y,STAGGER+dz),dark,0.007)
		for dz in [-0.06,0.06]:
			_strut(Vector3(out,UPPER_Y,STAGGER+dz),Vector3(0.15*side,LOWER_Y,dz),steel,0.0028)
			_strut(Vector3(out,LOWER_Y,dz),Vector3(0.14*side,UPPER_Y,STAGGER+dz),steel,0.0028)
		# The undercarriage: a V of legs either side to the axle, and the
		# wheels on it, their spokes covered in cream, brass hubs.
		_strut(Vector3(0.07*side,-0.14,-0.38),Vector3(0.165*side,-0.33,-0.28),dark,0.009)
		_strut(Vector3(0.07*side,-0.14,-0.17),Vector3(0.165*side,-0.33,-0.28),dark,0.009)
		_add(FacetMesh.frustum(0.08,0.08,0.038,14),steel,Vector3(0.2*side,-0.33,-0.28),Vector3(0.0,0.0,PI*0.5))
		_add(FacetMesh.frustum(0.058,0.058,0.044,14),cream,Vector3(0.2*side,-0.33,-0.28),Vector3(0.0,0.0,PI*0.5))
		_add(FacetMesh.frustum(0.02,0.014,0.06,8),brass,Vector3(0.21*side,-0.33,-0.28),Vector3(0.0,0.0,PI*0.5))
	_strut(Vector3(-0.17,-0.33,-0.28),Vector3(0.17,-0.33,-0.28),dark,0.008)
	# A tail skid it rests on, parked (scripts/plane_strip.gd TAIL).
	_strut(Vector3(0.0,-0.03,0.58),Vector3(0.0,-0.11,0.66),dark,0.01)
	_add(FacetMesh.gem(0.018),steel,Vector3(0.0,-0.1,0.66),Vector3.ZERO)
	# The tail: a terracotta fin with a cream rudder, a cream tailplane and
	# its elevator either side of the rudder.
	_add(_prism([Vector2(-0.1,0.0),Vector2(0.1,0.0),Vector2(0.1,0.2),Vector2(0.065,0.24),Vector2(0.02,0.25),Vector2(-0.03,0.2)],0.012),trim,Vector3(0.0,0.03,0.58),Vector3.ZERO)
	_add(_prism([Vector2(0.1,-0.04),Vector2(0.15,-0.04),Vector2(0.165,0.1),Vector2(0.145,0.19),Vector2(0.1,0.2)],0.01),cream,Vector3(0.0,0.03,0.58),Vector3.ZERO)
	_add(_wing(0.25,-0.25,0.25,Vector3.ZERO,0.13,0.1,0.016,3),cream,Vector3(0.0,0.03,0.62),Vector3.ZERO)
	_elevator = Node3D.new()
	_elevator.position = Vector3(0.0,0.032,0.62+0.065)
	add_child(_elevator)
	for side in [-1.0,1.0]:
		var elevator := MeshInstance3D.new()
		elevator.mesh = _scaled(_prism([Vector2(0.0,0.004),Vector2(ELEVATOR_DEPTH,0.0),Vector2(0.0,-0.004)]),Vector3(0.2,1.0,1.0))
		elevator.material_override = cream
		elevator.position = Vector3(0.125*side,0.0,0.0)
		_elevator.add_child(elevator)
	# The propeller: two varnished wooden blades, brass-sheathed at the
	# tips, and the soft disc of air they turn into, at the nose.
	_prop = Node3D.new()
	_prop.position = Vector3(0.0,0.0,-0.68)
	add_child(_prop)
	var varnish := _paint(PROPWOOD,0.3,0.9,0.0)
	for turn in [0.0,PI]:
		var lay := Basis(Vector3.BACK,turn)*Basis(Vector3.UP,0.32)*Basis(Vector3.RIGHT,-PI*0.5)
		var blade := _add(_hull([Vector3(0.0,0.012,0.009),Vector3(0.04,0.026,0.008),Vector3(0.16,0.024,0.006),Vector3(0.235,0.017,0.005)],6),varnish,Vector3.ZERO,Vector3.ZERO,_prop)
		blade.basis = lay
		var sheath := _add(_hull([Vector3(0.232,0.0175,0.0055),Vector3(0.262,0.012,0.0045),Vector3(0.27,0.004,0.003)],6),brass,Vector3.ZERO,Vector3.ZERO,_prop)
		sheath.basis = lay
	var blur := MeshInstance3D.new()
	_blur = blur
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE*0.58
	blur.mesh = disc
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = PROP_BLUR
	blur.material_override = _blur_material
	blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blur.position = Vector3(0.0,0.0,-0.69)
	add_child(blur)
	_scarf_mesh = ImmediateMesh.new()
	_scarf = MeshInstance3D.new()
	_scarf.mesh = _scarf_mesh
	_scarf.top_level = true
	var scarf_material := ShaderMaterial.new()
	scarf_material.shader = FOLK_RIBBON
	scarf_material.set_shader_parameter("roughness_value",0.95)
	scarf_material.set_meta("scarf",livery.get("scarf",Color("d9573a")))
	_scarf.material_override = scarf_material
	_scarf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_scarf)
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
## own transform. The scarf and the mark are top level, in global space.
##
## Starts the scarf streaming straight back from where it is now.
func reset(glide: RefCounted) -> void:
	parked = false
	show_pilot(true)
	_scarf_points.resize(SCARF)
	_short_points.resize(SCARF_SHORT)
	var back: Vector3 = -glide.forward()
	for i in range(SCARF): _scarf_points[i] = glide.position+back*SCARF_GAP*i
	for i in range(SCARF_SHORT): _short_points[i] = glide.position+back*SCARF_GAP*i
	_mark_bright = 0.0
	_vapour_clock = 0.0
	_vapour_points.fill(glide.position)
	_vapour_strength.fill(0.0)
	_last_roll = _roll(glide)
	_last_pitch = float(glide.pitch)
	update(0.0,glide,0.0,Callable(),false)

## The world moved under it (SkyIslands `arrive`): the scarf goes too.
func shift(by: Vector3) -> void:
	for i in range(_scarf_points.size()): _scarf_points[i] += by
	for i in range(_short_points.size()): _short_points[i] += by
	for i in range(_vapour_points.size()): _vapour_points[i] += by

## One frame: posed on `glide` (a SkyPlane, or a plain
## glide drawn without its roll), `dive` held 0..1 (unused), `ground` the
## height under a point, `landable` whether a touch now would land, and
## `near` and `lean` the vapour's.
func update(delta: float, glide: RefCounted, _dive: float, ground: Callable, landable: bool, near := 0.0, lean := 0.0) -> void:
	var at: Vector3 = glide.position
	var roll := _roll(glide)
	transform = pose(at,float(glide.heading),float(glide.pitch),roll)
	# The control surfaces follow how fast it rolls and pitches, and so
	# does the pilot.
	var roll_rate := (roll-_last_roll)/delta if delta > 0.0 else 0.0
	var pitch_rate := (float(glide.pitch)-_last_pitch)/delta if delta > 0.0 else 0.0
	var spin: Variant = glide.get("spin")
	var throttle: Variant = glide.get("throttle")
	var running: Variant = glide.get("engine")
	if _rig.visible: _rig.animate(delta,float(glide.bank),float(glide.pitch),roll_rate,pitch_rate,float(throttle) if throttle != null else 0.0,float(spin) if spin != null else 0.0,float(running) if running != null else 1.0)
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
	_trail_scarf(delta,glide)
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

## The pilot in the cockpit, or not (hopped out).
func show_pilot(on: bool) -> void:
	for part in _pilot: part.visible = on
	_scarf.visible = on

## Where the figure stands for a flight's pose: its position (the flight's,
## the figure hangs FIGURE_DROP under it), heading, pitch and roll.
static func pose(at: Vector3, heading: float, pitch: float, roll: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch,heading,-roll)),at+Vector3.DOWN*0.2)

## Stands it parked: `placed` is its transform in its parent's frame (the
## plate's, so it turns and moves with the land); the engine off, the
## pilot out, no scarf, mark or vapour.
func park(placed: Transform3D) -> void:
	parked = true
	transform = placed
	show_pilot(false)
	_spin_prop(0.0,0.0,0.0)
	_mark.visible = false
	_vapour.visible = false

## The whole roll it is drawn at: the bank and, on a plane, the barrel roll.
func _roll(glide: RefCounted) -> float:
	var spin: Variant = glide.get("spin")
	return float(glide.bank)+(float(spin) if spin != null else 0.0)

## The scarf's two tails, from the knot at the back of the neck: each point
## is dragged back by the air past it and kept a gap behind the one before,
## sagging when slow. Drawn, ripples run down each tail, side to side and up
## and down, twisting it so the wool catches the light, reaching further
## towards the tip and running faster with the speed.
func _trail_scarf(delta: float, glide: RefCounted) -> void:
	if _scarf_points.size() != SCARF: return
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

## One tail as a ribbon, `phase` its ripples' clock, `wide` its width's
## share, with the pale stripes cut sharp near its end.
func _draw_tail(points: PackedVector3Array, side: Vector3, up: Vector3, phase: float, fast: float, wide: float, color: Color) -> void:
	var last := float(points.size()-1)
	var cuts := []
	for i in range(points.size()): cuts.append(float(i))
	for stripe: Vector2 in SCARF_STRIPES:
		cuts.append(stripe.x*last)
		cuts.append(stripe.y*last)
	cuts.sort()
	var reach := FLUTTER_REACH*lerpf(0.35,1.0,fast)
	_scarf_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var before := Color(0,0,0,0)
	for u: float in cuts:
		var i := mini(int(u),points.size()-2)
		var p := points[i].lerp(points[i+1],u-i)
		var along := (points[i+1]-points[i]).normalized()
		var tip := pow(u/last,1.3)
		var wave := phase-u*1.1
		p += side*sin(wave)*reach*tip+up*sin(wave*0.8+1.3)*reach*0.6*tip
		var across := side.rotated(along,sin(wave+0.6)*0.7*tip) if along.length_squared() > 0.5 else side
		var normal := across.cross(along).normalized()
		var f := u/last
		var c := color
		for stripe: Vector2 in SCARF_STRIPES:
			if f >= stripe.x-0.0001 and f < stripe.y-0.0001: c = STRIPE
		if before.a > 0.0 and c != before:
			# The stripe's edge: the same place again in the new colour.
			for e in [-1.0,1.0]:
				_scarf_mesh.surface_set_color(before)
				_scarf_mesh.surface_set_normal(normal)
				_scarf_mesh.surface_add_vertex(p+across*e*_scarf_width(f,wide)*0.5)
		before = c
		for e in [-1.0,1.0]:
			_scarf_mesh.surface_set_color(c)
			_scarf_mesh.surface_set_normal(normal)
			_scarf_mesh.surface_add_vertex(p+across*e*_scarf_width(f,wide)*0.5)
	_scarf_mesh.surface_end()

static func _scarf_width(along: float, wide: float) -> float:
	return SCARF_WIDTH*wide*(1.0-0.4*along)

## The vapour: each upper wingtip lays a point every
## VAPOUR_EVERY seconds; the points hang, drifting and widening as they fade.
func _trail_vapour(delta: float, near: float, side: float) -> void:
	_vapour_clock += delta
	var lay := _vapour_clock >= VAPOUR_EVERY
	if lay: _vapour_clock = fmod(_vapour_clock,VAPOUR_EVERY)
	var shown := false
	for s in range(2):
		var hand := -1.0 if s == 0 else 1.0
		var o := s*VAPOUR
		if lay:
			for i in range(VAPOUR-1,0,-1):
				_vapour_points[o+i] = _vapour_points[o+i-1]
				_vapour_strength[o+i] = _vapour_strength[o+i-1]
		var drift := (Vector3.UP*VAPOUR_DRIFT.x+basis.x.normalized()*hand*VAPOUR_DRIFT.y)*delta
		for i in range(1,VAPOUR): _vapour_points[o+i] += drift*float(i)/VAPOUR
		_vapour_points[o] = transform*Vector3(SPAN*0.5*hand,UPPER_Y,STAGGER)
		_vapour_strength[o] = near*clampf(0.6+0.6*side*hand,0.25,1.0)
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
			facing = facing.normalized()*lerpf(VAPOUR_WIDTH.x,VAPOUR_WIDTH.y,age)*0.5
			var c := VAPOUR_COLOR
			c.a = _vapour_strength[o+i]*VAPOUR_ALPHA*(1.0-age)*(1.0-age)*smoothstep(0.0,0.15,age+0.05)
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

# --- Building -----------------------------------------------------------------------

## Paint, lit as the folk are (shaders/folk_surface.gdshader): a
## `roughness` base under a clear coat of `coat`, weathered by `wear`.
static func _paint(color: Color, roughness: float, coat: float, wear: float) -> ShaderMaterial:
	var m := PersonKit._lacquer(color,roughness,coat)
	m.set_shader_parameter("wear",wear)
	return m

static func _metal(color: Color, roughness: float) -> ShaderMaterial:
	return PersonKit._metal(color,roughness)

## The windscreen: faint, clear and sharp-shining.
static func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85,0.93,0.96,0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.03
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
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

## A thin strut (or, `radius` finer, a wire) from `from` to `to`.
func _strut(from: Vector3, to: Vector3, material: Material, radius := 0.014) -> void:
	var part := _add(FacetMesh.frustum(radius,radius,1.0,4),material,(from+to)*0.5,Vector3.ZERO)
	var y := (to-from)
	var x := y.cross(Vector3.FORWARD if absf(y.normalized().dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	part.basis = Basis(x,y,x.cross(y.normalized()).normalized())

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
		arrays[Mesh.ARRAY_NORMAL] = groups[material][1]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var joined := MeshInstance3D.new()
		joined.mesh = mesh
		joined.material_override = material
		parent.add_child(joined)
		if material == first: parent.move_child(joined,0)

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
## `ribs` ribs each side and sagging between them, so each rib is a crease
## in the light. `cut` (out from, out to, z) cuts the trailing edge back to
## z between those for the ailerons.
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
