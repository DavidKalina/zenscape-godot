extends Node3D
## The wanderer seen gliding (scripts/sky_glide.gd), for the chase camera
## (scripts/glide_camera.gd): the same little figure in its terracotta
## cloth, lying out under a cream cloth wing, with a scarf streaming behind.
##
## Faceted solids and soft cloth, as the style asks: the body is a few flat
## faces; the wing is three hinged panels a side that flex with the air.
## The tips lift with the glide's lift and droop at the float, the panels
## beat on Rise, and in a dive the wing tucks back. A flap is one big
## stroke: the wing sweeps hard down and comes back up. The scarf is a ribbon
## that trails the neck's path through the air, so it swings in a turn.
##
## Under it, near the ground, a soft mark shows where it would touch down:
## dim while too fast to land, bright once a touch would set it down.

const CLOTH := Color("c8643b")
const SKIN := Color("e8c39e")
const DARK := Color("6b3b28")
const WING := Color("f3ead6")
## The wing: panels a side, the span of each (m), its chord at the root and
## how much each panel narrows, and how far each sweeps back.
const PANELS := 3
const PANEL_SPAN := Vector3(0.42,0.38,0.32)
const CHORD := 0.78
const NARROW := 0.72
const SWEEP := 0.14
const WING_Y := 0.42
## The flex: radians of tip lift per m/s of climb, at most; the beat's
## angle and rate (beats a second); how far a dive folds the wing back.
const FLEX := 0.05
const FLEX_MAX := 0.35
const BEAT_ANGLE := 0.55
const BEAT := 1.4
const TUCK_FOLD := 0.85
## A flap's stroke: the wing lifts to STROKE_UP, sweeps down to STROKE_DOWN
## by STROKE_DOWN_AT of the stroke, and is back by the stroke's end.
const STROKE_UP := 0.55
const STROKE_DOWN := -0.7
const STROKE_DOWN_AT := 0.35
## The scarf: points, the gap between them (m), and its width.
const SCARF := 12
const SCARF_GAP := 0.13
const SCARF_WIDTH := 0.075
## The landing mark shows within MARK_HEIGHT m of the ground.
const MARK_HEIGHT := 28.0

## The hinges, root to tip, a side: [[left...], [right...]].
var _hinges := [[],[]]
var _wing_root: Node3D
var _legs: Array[Node3D] = []
var _beat := 0.0
var _scarf_points := PackedVector3Array()
var _scarf: MeshInstance3D
var _scarf_mesh: ImmediateMesh
var _mark: MeshInstance3D
var _mark_material: StandardMaterial3D
var _mark_bright := 0.0

func _init() -> void:
	name = "Glider"
	var cloth := _material(CLOTH)
	var skin := _material(SKIN)
	var dark := _material(DARK)
	# The rider lies along -Z, its head forward, hanging under the wing.
	_add(_frustum(0.1,0.13,0.46,6),cloth,Vector3(0.0,0.0,0.05),Vector3(-PI*0.5,0.0,0.0))
	_add(_gem(0.1),skin,Vector3(0.0,0.03,-0.27),Vector3.ZERO)
	for side in [-1.0,1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.06*side,-0.01,0.27)
		add_child(leg)
		var shin := MeshInstance3D.new()
		shin.mesh = _frustum(0.05,0.035,0.42,5)
		shin.material_override = dark
		shin.rotation = Vector3(-PI*0.5,0.0,0.0)
		shin.position = Vector3(0.0,0.0,0.21)
		leg.add_child(shin)
		_legs.append(leg)
		# Arms reach up to the wing's root.
		var arm := MeshInstance3D.new()
		arm.mesh = _frustum(0.035,0.03,0.42,5)
		arm.material_override = cloth
		add_child(arm)
		var from := Vector3(0.11*side,0.05,-0.12)
		var to := Vector3(0.24*side,WING_Y-0.02,-0.08)
		arm.position = (from+to)*0.5
		arm.basis = _aim(to-from)
	_wing_root = Node3D.new()
	_wing_root.position = Vector3(0.0,WING_Y,0.0)
	add_child(_wing_root)
	var cream := _material(WING)
	cream.cull_mode = BaseMaterial3D.CULL_DISABLED
	cream.backlight_enabled = true
	cream.backlight = Color(0.55,0.45,0.35)
	var hem := _material(CLOTH)
	hem.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A short spine down the middle, then the panels out each side.
	_wing_root.add_child(_panel_mesh(0.18,CHORD,CHORD,0.0,cream,hem,1.0))
	for s in range(2):
		var side := -1.0 if s == 0 else 1.0
		var parent: Node3D = _wing_root
		var chord := CHORD
		var x := 0.09
		for i in range(PANELS):
			var hinge := Node3D.new()
			hinge.position = Vector3(x*side,0.0,SWEEP*float(i > 0))
			parent.add_child(hinge)
			var narrow := chord*NARROW
			var panel := _panel_mesh(PANEL_SPAN[i],chord,narrow,SWEEP,cream,hem,side)
			hinge.add_child(panel)
			_hinges[s].append(hinge)
			parent = hinge
			chord = narrow
			x = PANEL_SPAN[i]
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
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE
	disc.orientation = PlaneMesh.FACE_Y
	_mark.mesh = disc
	_mark.top_level = true
	_mark_material = StandardMaterial3D.new()
	_mark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_material.albedo_texture = _soft_ring()
	_mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mark.material_override = _mark_material
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.visible = false
	add_child(_mark)

## Its parent must be a plain Node (or the scene root): it is placed by its
## own transform. The scarf and the mark are top level, in global space.
##
## Starts the scarf streaming straight back from where it is now.
func reset(glide: RefCounted) -> void:
	_scarf_points.resize(SCARF)
	var back: Vector3 = -glide.forward()
	for i in range(SCARF): _scarf_points[i] = glide.position+back*SCARF_GAP*i
	_beat = 0.0
	_mark_bright = 0.0
	update(0.0,glide,0.0,Callable(),false)

## The world moved under it (SkyIslands `arrive`): the scarf goes too.
func shift(by: Vector3) -> void:
	for i in range(_scarf_points.size()): _scarf_points[i] += by

## One frame: posed on `glide`, `dive` held 0..1. `ground` is a
## Callable(Vector3) -> Variant (the height under a point, or null);
## `landable` says whether a touch now would land.
func update(delta: float, glide: RefCounted, dive: float, ground: Callable, landable: bool) -> void:
	var at: Vector3 = glide.position
	# Its parent is a plain Node, so its own transform is the global one.
	transform = Transform3D(Basis.from_euler(Vector3(float(glide.pitch),float(glide.heading),-float(glide.bank))),at+Vector3.DOWN*0.35)
	var climb: float = glide.climb
	if climb > 0.05: _beat += delta*BEAT*TAU
	else: _beat = lerpf(_beat,roundf(_beat/TAU)*TAU,1.0-exp(-delta/0.3))
	var lift := clampf((float(glide.velocity.y)+climb)*FLEX,-FLEX_MAX,FLEX_MAX)
	var beat := sin(_beat)*BEAT_ANGLE*clampf(climb/2.0,0.0,1.0)
	var droop := -0.18*float(glide.hang)
	beat += _stroke(float(glide.stroke)/float(glide.FLAP_STROKE))
	var fold := TUCK_FOLD*clampf(dive,0.0,1.0)
	for s in range(2):
		var side := -1.0 if s == 0 else 1.0
		for i in range(PANELS):
			var hinge: Node3D = _hinges[s][i]
			var share := float(i+1)/PANELS
			var up := (lift*0.6+beat+droop)*share+0.06
			# The tuck folds the panels back and down along the body.
			hinge.rotation = Vector3(0.0,-fold*side*(0.55 if i == 0 else 0.3),up*side)
	for i in range(_legs.size()):
		_legs[i].rotation.x = 0.08*sin(_beat*0.5+i*PI)+0.15*float(glide.hang)
	_trail_scarf(delta,glide)
	_place_mark(delta,at,ground,landable)

## The wing's angle through a flap's stroke, `t` from 0 (it begins) to 1.
func _stroke(t: float) -> float:
	if t >= 1.0: return 0.0
	if t < 0.1: return lerpf(0.0,STROKE_UP,smoothstep(0.0,0.1,t))
	if t < STROKE_DOWN_AT: return lerpf(STROKE_UP,STROKE_DOWN,smoothstep(0.1,STROKE_DOWN_AT,t))
	return lerpf(STROKE_DOWN,0.0,smoothstep(STROKE_DOWN_AT,1.0,t))

func _trail_scarf(delta: float, glide: RefCounted) -> void:
	if _scarf_points.size() != SCARF: return
	var neck := transform*Vector3(0.0,0.08,-0.18)
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

func _place_mark(delta: float, at: Vector3, ground: Callable, landable: bool) -> void:
	var under: Variant = ground.call(at) if ground.is_valid() else null
	if under is Vector2:
		var body := under as Vector2
		under = body.x if at.y > body.x else null
	var height := at.y-float(under) if under != null else INF
	_mark.visible = height < MARK_HEIGHT
	if not _mark.visible: return
	_mark_bright = lerpf(_mark_bright,float(landable),1.0-exp(-delta/0.2)) if delta > 0.0 else float(landable)
	var near := 1.0-clampf(height/MARK_HEIGHT,0.0,1.0)
	var size := lerpf(0.9,2.4,clampf(height/12.0,0.0,1.0))
	_mark.transform = Transform3D(Basis().scaled(Vector3(size,1.0,size)),Vector3(at.x,float(under)+0.06,at.z))
	_mark_material.albedo_color = Color(1.0,0.97,0.88,near*lerpf(0.35,0.85,_mark_bright))

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

## A basis whose +Y runs along `dir`.
func _aim(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Basis(x,y*dir.length()/0.42,z)

## A flat-shaded frustum along Y, `sides` faces round, centred.
static func _frustum(bottom: float, top: float, height: float, sides: int) -> ArrayMesh:
	var tris := []
	for i in range(sides):
		var a0 := TAU*i/sides
		var a1 := TAU*(i+1)/sides
		var b0 := Vector3(cos(a0)*bottom,-height*0.5,sin(a0)*bottom)
		var b1 := Vector3(cos(a1)*bottom,-height*0.5,sin(a1)*bottom)
		var t0 := Vector3(cos(a0)*top,height*0.5,sin(a0)*top)
		var t1 := Vector3(cos(a1)*top,height*0.5,sin(a1)*top)
		tris.append([b0,t0,t1])
		tris.append([b0,t1,b1])
		tris.append([Vector3(0.0,height*0.5,0.0),t1,t0])
		tris.append([Vector3(0.0,-height*0.5,0.0),b0,b1])
	return _faceted(tris)

## A small faceted gem (an octahedron, a little stretched) for the head.
static func _gem(r: float) -> ArrayMesh:
	var top := Vector3(0.0,r*1.15,0.0)
	var bottom := Vector3(0.0,-r,0.0)
	var ring := [Vector3(r,0.0,0.0),Vector3(0.0,0.0,r),Vector3(-r,0.0,0.0),Vector3(0.0,0.0,-r*1.1)]
	var tris := []
	for i in range(4):
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i+1)%4]
		tris.append([top,b,a])
		tris.append([bottom,a,b])
	return _faceted(tris)

## Triangles (each an outward-wound [a, b, c]) as a flat-shaded mesh: every
## face takes its own normal, so it reads as cut facets.
static func _faceted(tris: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		# Godot's front faces wind clockwise: the cross of the winding
		# points in, so the normal is its opposite.
		var n := -(b-a).cross(c-a).normalized()
		if n.dot((a+b+c)/3.0) < 0.0:
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

## One wing panel from its hinge out along +X (or -X for the left side):
## a root chord, a tip chord swept back by `sweep`, a faint ridge along the
## middle so it reads as cloth over a spar, and a terracotta hem behind.
func _panel_mesh(span: float, root: float, tip: float, sweep: float, cream: Material, hem: Material, side: float) -> MeshInstance3D:
	var x := span*side
	var lead_root := Vector3(0.0,0.0,-root*0.5)
	var tail_root := Vector3(0.0,0.0,root*0.5)
	var lead_tip := Vector3(x,0.0,-tip*0.5+sweep)
	var tail_tip := Vector3(x,0.0,tip*0.5+sweep)
	var ridge_root := Vector3(0.0,0.035,-root*0.12)
	var ridge_tip := Vector3(x,0.03,-tip*0.12+sweep)
	var hem_root := tail_root.lerp(ridge_root,0.22)
	var hem_tip := tail_tip.lerp(ridge_tip,0.22)
	var tris := [[lead_root,ridge_root,ridge_tip],[lead_root,ridge_tip,lead_tip],
		[ridge_root,hem_root,hem_tip],[ridge_root,hem_tip,ridge_tip]]
	var hems := [[hem_root,tail_root,tail_tip],[hem_root,tail_tip,hem_tip]]
	var mesh := MeshInstance3D.new()
	mesh.mesh = _cloth(tris)
	mesh.material_override = cream
	var trim := MeshInstance3D.new()
	trim.mesh = _cloth(hems)
	trim.material_override = hem
	mesh.add_child(trim)
	return mesh

## Cloth faces: flat-shaded, normals up (the material draws both sides).
static func _cloth(tris: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: Array in tris:
		var n: Vector3 = ((t[1] as Vector3)-(t[0] as Vector3)).cross((t[2] as Vector3)-(t[0] as Vector3)).normalized()
		if n.y < 0.0: n = -n
		for v: Vector3 in t:
			vertices.append(v)
			normals.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

## A soft white ring with a faint centre, for the landing mark.
static func _soft_ring() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.18,0.62,0.78,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0.55),Color(1,1,1,0.12),Color(1,1,1,0.3),Color(1,1,1,0.9),Color(1,1,1,0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1.0,0.5)
	texture.width = 128
	texture.height = 128
	return texture
