extends Node3D
## The spade (docs/design/dig/spec-dig.md): a short garden spade, iron blade
## on an ash shaft with a D grip, drawn as one mesh of two surfaces (wood,
## iron). Built along its own +Y: the blade's tip at the origin, the grip's
## top at LENGTH. Sized for a wanderer of size 1 (WorldScale.WANDERER_TALL
## 1.19 m); the holder scales it with him.
##
## Model budget (docs/art/model-budget.md): about 400 triangles, one draw
## call per material; low-sided cylinders (6 sides on the shaft) since it is
## never seen bigger than a hand's width on screen.

const LENGTH := 0.86
const BLADE_W := 0.19
const BLADE_H := 0.24
const BLADE_T := 0.012
const SHAFT_R := 0.021
const SOCKET_TOP := 0.30
const GRIP_W := 0.11
## How deep the blade stands in the turf where it lies stuck.
const BITE := 0.09

const WOOD := Color(0.66,0.47,0.28)
const IRON := Color(0.62,0.63,0.66)

var mesh_instance: MeshInstance3D

func _init() -> void:
	name = "Spade"
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = build_mesh()
	add_child(mesh_instance)

## The blade's tip (local), where it bites.
static func tip() -> Vector3:
	return Vector3.ZERO

static func build_mesh() -> ArrayMesh:
	var out := ArrayMesh.new()
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_smooth_group(0xFFFFFFFF)
	var shaft_from := SOCKET_TOP-0.04
	var grip_y := LENGTH-0.03
	_cyl(wood,Vector3(0,shaft_from,0),Vector3(0,grip_y-0.09,0),SHAFT_R,6)
	# The D grip: two cheeks spreading up from the shaft's top to the bar.
	var fork := Vector3(0,grip_y-0.10,0)
	_cyl(wood,fork,Vector3(-GRIP_W*0.5,grip_y,0),SHAFT_R*0.75,5)
	_cyl(wood,fork,Vector3(GRIP_W*0.5,grip_y,0),SHAFT_R*0.75,5)
	_cyl(wood,Vector3(-GRIP_W*0.55,grip_y,0),Vector3(GRIP_W*0.55,grip_y,0),SHAFT_R*0.85,6)
	wood.generate_normals()
	var iron := SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	iron.set_smooth_group(0xFFFFFFFF)
	# The blade: a flat plate with a rounded point, its shoulders (treads)
	# a touch wider, extruded BLADE_T thick.
	var outline := PackedVector2Array()
	var half := BLADE_W*0.5
	for k in range(7):
		var a := PI+PI*float(k)/6.0
		outline.append(Vector2(cos(a)*half*0.92,0.07+sin(a)*0.07))
	outline.append(Vector2(half,BLADE_H-0.02))
	outline.append(Vector2(half*0.55,BLADE_H))
	outline.append(Vector2(-half*0.55,BLADE_H))
	outline.append(Vector2(-half,BLADE_H-0.02))
	_plate(iron,outline,BLADE_T)
	# The socket: a tapered sleeve from the blade's top up the shaft.
	_cyl(iron,Vector3(0,BLADE_H-0.01,0),Vector3(0,SOCKET_TOP,0),SHAFT_R*1.6,6,SHAFT_R*1.15)
	iron.generate_normals()
	var wood_mesh := wood.commit()
	var iron_mesh := iron.commit(wood_mesh)
	out = iron_mesh
	out.surface_set_material(0,_mat(WOOD,0.0,0.85))
	out.surface_set_material(1,_mat(IRON,0.55,0.5))
	return out

static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## A cylinder from `a` to `b`, `sides` around, radius `r` at a (and `r2`
## at b, if given); capped.
static func _cyl(st: SurfaceTool, a: Vector3, b: Vector3, r: float, sides: int, r2 := -1.0) -> void:
	if r2 < 0.0: r2 = r
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis).normalized()
	for k in range(sides):
		var a0 := TAU*float(k)/sides
		var a1 := TAU*float(k+1)/sides
		var d0 := side*cos(a0)+up*sin(a0)
		var d1 := side*cos(a1)+up*sin(a1)
		var p0 := a+d0*r
		var p1 := a+d1*r
		var q0 := b+d0*r2
		var q1 := b+d1*r2
		st.add_vertex(p0); st.add_vertex(q1); st.add_vertex(q0)
		st.add_vertex(p0); st.add_vertex(p1); st.add_vertex(q1)
		st.add_vertex(a); st.add_vertex(p1); st.add_vertex(p0)
		st.add_vertex(b); st.add_vertex(q0); st.add_vertex(q1)

## A flat plate of `outline` (x, y) in the XY plane, `t` thick along z.
static func _plate(st: SurfaceTool, outline: PackedVector2Array, t: float) -> void:
	var tris := Geometry2D.triangulate_polygon(outline)
	var front := t*0.5
	var cw := Geometry2D.is_polygon_clockwise(outline)
	for i in range(0,tris.size(),3):
		var a := outline[tris[i]]
		var b := outline[tris[i+1]]
		var c := outline[tris[i+2]]
		var order := [a,b,c] if not cw else [a,c,b]
		# Front (+z) wound so it faces out; back the other way.
		for p: Vector2 in [order[0],order[2],order[1]]: st.add_vertex(Vector3(p.x,p.y,front))
		for p: Vector2 in order: st.add_vertex(Vector3(p.x,p.y,-front))
	var n := outline.size()
	for k in range(n):
		var p := outline[k]
		var q := outline[(k+1)%n]
		var pf := Vector3(p.x,p.y,front)
		var pb := Vector3(p.x,p.y,-front)
		var qf := Vector3(q.x,q.y,front)
		var qb := Vector3(q.x,q.y,-front)
		if not cw:
			st.add_vertex(pf); st.add_vertex(qf); st.add_vertex(qb)
			st.add_vertex(pf); st.add_vertex(qb); st.add_vertex(pb)
		else:
			st.add_vertex(pf); st.add_vertex(qb); st.add_vertex(qf)
			st.add_vertex(pf); st.add_vertex(pb); st.add_vertex(qb)
