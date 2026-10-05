extends Node3D
## The wanderer flying the little plane (scripts/sky_plane.gd), for the chase
## camera (scripts/glide_camera.gd): a chunky toy biplane in warm wood
## browns, cream wings tipped in terracotta, a spinning propeller, and the
## wanderer's head in the open cockpit with the scarf streaming behind. It
## stands in for the glider (scripts/glider_figure.gd) under `--plane`, with
## the same calls, so the wanderer's eye can swap one for the other.
##
## Faceted solids and soft light, as the style asks: every solid is a few
## flat faces; the propeller is two dark blades inside a soft pale blur
## that thickens with speed. It is drawn turned by the bank and the barrel
## roll together. The ailerons tip with the roll, the elevator with the
## pitch, so the stick shows on the wings. Like the glider, a soft mark
## under it shows where it would touch down, and close past rock vapour
## peels off its upper wingtips.

const GliderFigure = preload("res://scripts/glider_figure.gd")
const WOOD := Color("8f5234")
const DARK := Color("6b3b28")
const TRIM := Color("c8643b")
const WING := Color("f3ead6")
const SKIN := Color("e8c39e")
## The wings: span (m), chord and thickness, the height of the lower and
## upper wing over the body's middle, and how far the upper sits forward.
const SPAN := 1.4
const CHORD := 0.3
const THICK := 0.05
const LOWER_Y := -0.1
const UPPER_Y := 0.3
const STAGGER := -0.06
## Control surfaces: radians of aileron per radian a second of roll, of
## elevator per radian a second of pitch, and the most either tips.
const AILERON := 0.35
const ELEVATOR := 0.5
const DEFLECT := 0.5
## The propeller: turns a second at rest and per m/s of speed, and the
## blur's opacity at rest and at speed.
const PROP_TURNS := 3.0
const PROP_PER := 0.6
const BLUR := Vector2(0.12,0.38)
## The scarf: points, the gap between them (m), and its width.
const SCARF := 12
const SCARF_GAP := 0.13
const SCARF_WIDTH := 0.075
## The landing mark shows within MARK_HEIGHT m of the ground.
const MARK_HEIGHT := 28.0
## The wingtip vapour, as the glider's.
const VAPOUR := 14
const VAPOUR_EVERY := 0.04
const VAPOUR_WIDTH := Vector2(0.06,0.55)
const VAPOUR_ALPHA := 0.42
const VAPOUR_DRIFT := Vector2(0.18,0.3)
const VAPOUR_COLOR := Color(1.0,0.98,0.94)

var _prop: Node3D
var _blur_material: StandardMaterial3D
var _prop_angle := 0.0
## The ailerons (left, right) and the elevator, on their hinges.
var _ailerons: Array[Node3D] = []
var _elevator: Node3D
var _last_roll := 0.0
var _last_pitch := 0.0
var _scarf_points := PackedVector3Array()
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

func _init() -> void:
	name = "Plane"
	var wood := _material(WOOD)
	var dark := _material(DARK)
	var trim := _material(TRIM)
	var cream := _material(WING)
	var skin := _material(SKIN)
	# The body runs along -Z, the nose forward: a round chunky barrel that
	# tapers to the tail, a terracotta cowl round the nose, a cream spinner.
	_add(_hull([Vector3(-0.5,0.15,0.15),Vector3(-0.36,0.19,0.2),Vector3(-0.05,0.2,0.21),Vector3(0.3,0.13,0.14),Vector3(0.72,0.05,0.07)],8),wood,Vector3.ZERO,Vector3.ZERO)
	_add(_hull([Vector3(-0.6,0.12,0.12),Vector3(-0.56,0.17,0.17),Vector3(-0.46,0.175,0.175),Vector3(-0.42,0.15,0.15)],8),trim,Vector3.ZERO,Vector3.ZERO)
	_add(_hull([Vector3(-0.74,0.0,0.0),Vector3(-0.66,0.06,0.06),Vector3(-0.6,0.065,0.065)],6),cream,Vector3.ZERO,Vector3.ZERO)
	# A dark band where the cockpit is cut, and the wanderer in it: the head
	# in a leather cap, peeking over the rim.
	_add(_hull([Vector3(-0.12,0.1,0.06),Vector3(0.12,0.1,0.06)],8),dark,Vector3(0.0,0.15,0.22),Vector3.ZERO)
	_add(GliderFigure._gem(0.085),skin,Vector3(0.0,0.23,0.22),Vector3.ZERO)
	_add(GliderFigure._gem(0.07),dark,Vector3(0.0,0.28,0.24),Vector3.ZERO).scale = Vector3(1.15,0.6,1.15)
	# The wings: a long lower wing through the body and an upper one on
	# struts, cream, tipped in terracotta, the upper a little forward.
	var wing := _prism([Vector2(-CHORD*0.5,0.0),Vector2(-CHORD*0.3,THICK*0.6),Vector2(CHORD*0.25,THICK*0.5),Vector2(CHORD*0.5,0.0),Vector2(CHORD*0.25,-THICK*0.4),Vector2(-CHORD*0.3,-THICK*0.4)])
	for y in [LOWER_Y,UPPER_Y]:
		var z: float = STAGGER if y == UPPER_Y else 0.0
		_add(_scaled(wing,Vector3(SPAN*0.8,1.0,1.0)),cream,Vector3(0.0,y,z),Vector3.ZERO)
		for side in [-1.0,1.0]:
			_add(_scaled(wing,Vector3(SPAN*0.1,1.0,1.0)),trim,Vector3(SPAN*0.45*side,y,z),Vector3.ZERO)
	for side in [-1.0,1.0]:
		# The ailerons hinge on the upper wing's trailing edge, out by the tips.
		var hinge := Node3D.new()
		hinge.position = Vector3(SPAN*0.3*side,UPPER_Y,STAGGER+CHORD*0.5)
		add_child(hinge)
		var flap := MeshInstance3D.new()
		flap.mesh = _scaled(_prism([Vector2(0.0,THICK*0.3),Vector2(0.09,0.0),Vector2(0.0,-THICK*0.3)]),Vector3(SPAN*0.18,1.0,1.0))
		flap.material_override = trim
		hinge.add_child(flap)
		_ailerons.append(hinge)
		# Struts between the wings, and a cabane from the upper to the body.
		for dz in [-0.08,0.08]:
			_strut(Vector3(SPAN*0.34*side,LOWER_Y,dz),Vector3(SPAN*0.34*side,UPPER_Y,dz+STAGGER),dark)
		_strut(Vector3(0.1*side,0.12,-0.25),Vector3(0.14*side,UPPER_Y,STAGGER-0.06),dark)
		# The wheels under the nose, on short legs.
		_strut(Vector3(0.08*side,-0.15,-0.3),Vector3(0.17*side,-0.33,-0.28),dark)
		_add(GliderFigure._frustum(0.08,0.08,0.05,8),dark,Vector3(0.2*side,-0.33,-0.28),Vector3(0.0,0.0,PI*0.5))
	# The tail: a terracotta fin, a cream tailplane and its elevator.
	var fin := _prism([Vector2(-0.1,0.0),Vector2(0.12,0.0),Vector2(0.14,0.26),Vector2(0.02,0.24)],THICK*0.5)
	_add(fin,trim,Vector3(0.0,0.03,0.58),Vector3.ZERO)
	_add(_scaled(wing,Vector3(0.52,0.7,0.6)),cream,Vector3(0.0,0.03,0.62),Vector3.ZERO)
	_elevator = Node3D.new()
	_elevator.position = Vector3(0.0,0.03,0.71)
	add_child(_elevator)
	var elevator := MeshInstance3D.new()
	elevator.mesh = _scaled(_prism([Vector2(0.0,THICK*0.25),Vector2(0.07,0.0),Vector2(0.0,-THICK*0.25)]),Vector3(0.48,1.0,1.0))
	elevator.material_override = trim
	_elevator.add_child(elevator)
	# The propeller: two blades and a soft blur round them, turning at the nose.
	_prop = Node3D.new()
	_prop.position = Vector3(0.0,0.0,-0.68)
	add_child(_prop)
	for turn in [0.0,PI]:
		var blade := MeshInstance3D.new()
		blade.mesh = GliderFigure._frustum(0.035,0.02,0.26,4)
		blade.material_override = dark
		blade.rotation = Vector3(0.0,0.0,turn)
		blade.position = Vector3(0.0,0.13,0.0).rotated(Vector3.BACK,turn)
		_prop.add_child(blade)
	var blur := MeshInstance3D.new()
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE*0.6
	blur.mesh = disc
	_blur_material = StandardMaterial3D.new()
	_blur_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blur_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blur_material.albedo_texture = GliderFigure._soft_ring()
	_blur_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blur_material.albedo_color = Color(1.0,0.96,0.88,BLUR.x)
	blur.material_override = _blur_material
	blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blur.position = Vector3(0.0,0.0,-0.69)
	add_child(blur)
	_scarf_mesh = ImmediateMesh.new()
	_scarf = MeshInstance3D.new()
	_scarf.mesh = _scarf_mesh
	_scarf.top_level = true
	var scarf_material := _material(Color("d9573a"))
	scarf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	_mark_material.albedo_texture = GliderFigure._soft_ring()
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
	mist.albedo_texture = GliderFigure._soft_band()
	mist.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vapour.material_override = mist
	_vapour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vapour.visible = false
	add_child(_vapour)
	_vapour_points.resize(VAPOUR*2)
	_vapour_strength.resize(VAPOUR*2)

## Its parent must be a plain Node (or the scene root): it is placed by its
## own transform. The scarf and the mark are top level, in global space.
##
## Starts the scarf streaming straight back from where it is now.
func reset(glide: RefCounted) -> void:
	_scarf_points.resize(SCARF)
	var back: Vector3 = -glide.forward()
	for i in range(SCARF): _scarf_points[i] = glide.position+back*SCARF_GAP*i
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
	for i in range(_vapour_points.size()): _vapour_points[i] += by

## One frame, as the glider's: posed on `glide` (a SkyPlane, or a plain
## glide drawn without its roll), `dive` held 0..1 (unused), `ground` the
## height under a point, `landable` whether a touch now would land, and
## `near` and `lean` the vapour's.
func update(delta: float, glide: RefCounted, _dive: float, ground: Callable, landable: bool, near := 0.0, lean := 0.0) -> void:
	var at: Vector3 = glide.position
	var roll := _roll(glide)
	transform = Transform3D(Basis.from_euler(Vector3(float(glide.pitch),float(glide.heading),-roll)),at+Vector3.DOWN*0.2)
	# The control surfaces follow how fast it rolls and pitches.
	if delta > 0.0:
		var rolled := clampf((roll-_last_roll)/delta*AILERON,-DEFLECT,DEFLECT)
		var pitched := clampf((float(glide.pitch)-_last_pitch)/delta*ELEVATOR,-DEFLECT,DEFLECT)
		var k := 1.0-exp(-delta/0.08)
		for s in range(2):
			var hand := -1.0 if s == 0 else 1.0
			_ailerons[s].rotation.x = lerpf(_ailerons[s].rotation.x,rolled*hand,k)
		_elevator.rotation.x = lerpf(_elevator.rotation.x,pitched,k)
	_last_roll = roll
	_last_pitch = float(glide.pitch)
	var pace := float(glide.speed)
	_prop_angle = wrapf(_prop_angle+delta*(PROP_TURNS+PROP_PER*pace)*TAU,0.0,TAU)
	_prop.rotation.z = _prop_angle
	_blur_material.albedo_color.a = lerpf(BLUR.x,BLUR.y,clampf(pace/30.0,0.0,1.0))
	_trail_scarf(delta,glide)
	_trail_vapour(delta,near,lean)
	_place_mark(delta,at,ground,landable)

## The whole roll it is drawn at: the bank and, on a plane, the barrel roll.
func _roll(glide: RefCounted) -> float:
	var spin: Variant = glide.get("spin")
	return float(glide.bank)+(float(spin) if spin != null else 0.0)

func _trail_scarf(delta: float, glide: RefCounted) -> void:
	if _scarf_points.size() != SCARF: return
	var neck := transform*Vector3(0.0,0.17,0.28)
	_scarf_points[0] = neck
	var wind: Vector3 = glide.velocity
	var t := Time.get_ticks_msec()*0.001
	for i in range(1,SCARF):
		# Each point is dragged back by the air past it and kept a gap
		# behind the one before; it flutters more towards the tail.
		var p := _scarf_points[i]-wind*delta*0.15
		p += Vector3(0.0,sin(t*9.0+i*0.9)*0.004*i,0.0)
		var d := p-_scarf_points[i-1]
		if d.length() > 0.0001: p = _scarf_points[i-1]+d.normalized()*SCARF_GAP
		_scarf_points[i] = p
	_scarf_mesh.clear_surfaces()
	_scarf_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var side := basis.x.normalized()
	for i in range(SCARF):
		var w := SCARF_WIDTH*(1.0-0.55*float(i)/SCARF)
		_scarf_mesh.surface_set_normal(basis.y)
		_scarf_mesh.surface_add_vertex(_scarf_points[i]-side*w*0.5)
		_scarf_mesh.surface_set_normal(basis.y)
		_scarf_mesh.surface_add_vertex(_scarf_points[i]+side*w*0.5)
	_scarf_mesh.surface_end()

## The vapour, as the glider's: each upper wingtip lays a point every
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

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m

func _add(mesh: Mesh, material: Material, at: Vector3, turn: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = turn
	add_child(part)
	return part

## A thin dark strut from `from` to `to`.
func _strut(from: Vector3, to: Vector3, material: Material) -> void:
	var part := _add(GliderFigure._frustum(0.014,0.014,1.0,4),material,(from+to)*0.5,Vector3.ZERO)
	var y := (to-from)
	var x := y.cross(Vector3.FORWARD if absf(y.normalized().dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	part.basis = Basis(x,y,x.cross(y.normalized()).normalized())

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

## A flat-shaded body along Z: `rings` of Vector3(z, half width, half
## height), `sides` faces round, capped at both ends.
static func _hull(rings: Array, sides: int) -> ArrayMesh:
	var tris := []
	var ring_at := func(r: Vector3, i: int) -> Vector3:
		var a := TAU*(float(i)+0.5)/sides
		return Vector3(cos(a)*r.y,sin(a)*r.z,r.x)
	for k in range(rings.size()-1):
		var r0: Vector3 = rings[k]
		var r1: Vector3 = rings[k+1]
		var inside := Vector3(0.0,0.0,(r0.x+r1.x)*0.5)
		for i in range(sides):
			var a0: Vector3 = ring_at.call(r0,i)
			var a1: Vector3 = ring_at.call(r0,i+1)
			var b0: Vector3 = ring_at.call(r1,i)
			var b1: Vector3 = ring_at.call(r1,i+1)
			tris.append([a0,b0,b1,inside])
			tris.append([a0,b1,a1,inside])
	for end in [0,rings.size()-1]:
		var r: Vector3 = rings[end]
		var centre := Vector3(0.0,0.0,r.x)
		var inside := Vector3(0.0,0.0,r.x+(0.01 if end == 0 else -0.01))
		if r.y > 0.0001:
			for i in range(sides): tris.append([centre,ring_at.call(r,i),ring_at.call(r,i+1),inside])
	return _shell(tris)

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

## Triangles [a, b, c, a point inside] as a flat-shaded mesh, each face
## wound and lit outward from its inside point.
static func _shell(tris: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n := -(b-a).cross(c-a)
		if n.length_squared() < 1e-12: continue
		n = n.normalized()
		if n.dot((a+b+c)/3.0-(t[3] as Vector3)) < 0.0:
			var swap := b
			b = c
			c = swap
			n = -n
		for v in [a,b,c]:
			vertices.append(v)
			normals.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
