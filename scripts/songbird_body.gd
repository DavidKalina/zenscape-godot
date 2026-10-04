extends Node3D
## One songbird's body (docs/scenic/songbirds.md): the carved woodland bird of
## the perching-bird study (wip/parked-2026-09-26), merged into four faceted
## meshes per species: body (with breast, tail and legs), head, and a folded
## and a spread wing each side. The feet are the origin; it faces -z.
## scripts/songbirds.gd moves it; this only poses it.
##
## Built at the study's size and scaled by SIZE, so it stands about 15 cm.
const SIZE := 0.42
## sRGB colours by species, muted to sit with the land.
const SPECIES := {
	"sparrow":{"title":"House sparrow","body":"8c6c4e","head":"7d6450","wing":"6a4f37","breast":"b49c80","tail":"5c4431","beak":"8a7a66","legs":"5b4a3a"},
	"robin":{"title":"Robin","body":"7a6752","head":"7a6752","wing":"6a5845","breast":"c7663f","tail":"5f4f40","beak":"3a3330","legs":"6b5847"},
	"goldfinch":{"title":"Goldfinch","body":"b89a52","head":"c8a948","wing":"3f3a33","breast":"d9c27a","tail":"34302b","beak":"d9c3a5","legs":"8a7a6a"},
}
const EYE := "1d1f22"
const PROFILE := [Vector2(0.28,-0.5),Vector2(0.5,-0.22),Vector2(0.32,0.25),Vector2(-0.12,0.5),Vector2(-0.5,0.1),Vector2(-0.32,-0.4)]
const HEAD_PROFILE := [Vector2(0.3,-0.5),Vector2(0.5,-0.2),Vector2(0.5,0.22),Vector2(0.15,0.5),Vector2(-0.5,0.3),Vector2(-0.5,-0.35)]
const WING_PROFILE := [Vector2(0.5,-0.4),Vector2(0.3,0.1),Vector2(-0.3,0.5),Vector2(-0.5,-0.1),Vector2(-0.1,-0.5)]
const HEAD_AT := Vector3(0,0.29,-0.12)
const SHOULDER := Vector3(0.12,0.18,0.045)

## Meshes by species: {body, head, folded: [left, right], spread: [left, right]}.
static var _meshes := {}
static var _material: ShaderMaterial

var species := "sparrow"
var head := Node3D.new()
var wings: Array[Node3D] = []
var folded: Array[MeshInstance3D] = []
var spread: Array[MeshInstance3D] = []
var tail_flick := 0.0
var _riding := false
var _paint: ShaderMaterial

func build(kind: String) -> void:
	species = kind if SPECIES.has(kind) else "sparrow"
	_paint = material().duplicate()
	var meshes := meshes_for(species)
	scale = Vector3.ONE*SIZE
	_part(self,meshes.body)
	head.position = HEAD_AT
	add_child(head)
	_part(head,meshes.head)
	for i in range(2):
		var wing := Node3D.new()
		var side := -1.0 if i == 0 else 1.0
		wing.position = Vector3(SHOULDER.x*side,SHOULDER.y,SHOULDER.z)
		add_child(wing)
		wings.append(wing)
		folded.append(_part(wing,meshes.folded[i]))
		spread.append(_part(wing,meshes.spread[i]))
	spread_wings(false)

func _part(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _paint
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(part)
	return part

## Wings out (flying) or tucked (perched, or the closed beat of bounding flight).
func spread_wings(out: bool) -> void:
	for i in range(2):
		folded[i].visible = not out
		spread[i].visible = out

## Ride a perch: the tree's mesh-to-world transform, the perch in mesh space,
## the wood's bend shape, and how much (0 none, 1 all). Each bird has its own
## material, so this is one set of uniforms for all its parts.
func ride(tree: Transform3D, perch: Vector3, shape: Vector2, weight: float) -> void:
	if weight <= 0.0001:
		if _riding:
			_paint.set_shader_parameter("perch_ride",Vector4.ZERO)
			_riding = false
		return
	_riding = true
	_paint.set_shader_parameter("perch_tree_x",Vector4(tree.basis.x.x,tree.basis.x.y,tree.basis.x.z,0.0))
	_paint.set_shader_parameter("perch_tree_y",Vector4(tree.basis.y.x,tree.basis.y.y,tree.basis.y.z,0.0))
	_paint.set_shader_parameter("perch_tree_z",Vector4(tree.basis.z.x,tree.basis.z.y,tree.basis.z.z,0.0))
	_paint.set_shader_parameter("perch_tree_o",Vector4(tree.origin.x,tree.origin.y,tree.origin.z,1.0))
	_paint.set_shader_parameter("perch_ride",Vector4(perch.x,perch.y,perch.z,weight))
	_paint.set_shader_parameter("perch_bend",shape)

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/songbird.gdshader")
	return _material

static func title(kind: String) -> String:
	return str(SPECIES.get(kind,SPECIES.sparrow).title)

static func meshes_for(kind: String) -> Dictionary:
	if _meshes.has(kind): return _meshes[kind]
	var c: Dictionary = SPECIES[kind]
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	_carved(body,PROFILE,Transform3D(Basis.from_scale(Vector3(0.28,0.28,0.39)),Vector3(0,0.18,0)),c.body)
	# A breast or paler belly under the throat.
	_carved(body,PROFILE,Transform3D(Basis.from_scale(Vector3(0.24,0.18,0.18)),Vector3(0,0.15,-0.1)),c.breast)
	_carved(body,PROFILE,Transform3D(Basis(Vector3.RIGHT,-0.2).scaled(Vector3(0.12,0.055,0.21)),Vector3(0,0.14,0.235)),c.tail)
	for side: float in [-1.0,1.0]:
		_carved(body,PROFILE,Transform3D(Basis.from_scale(Vector3(0.023,0.05,0.035)),Vector3(side*0.06,0.025,-0.045)),c.legs)
	var head := SurfaceTool.new()
	head.begin(Mesh.PRIMITIVE_TRIANGLES)
	_carved(head,HEAD_PROFILE,Transform3D(Basis.from_scale(Vector3(0.2,0.19,0.21)),Vector3.ZERO),c.head)
	for side: float in [-1.0,1.0]:
		_carved(head,PROFILE,Transform3D(Basis.from_scale(Vector3(0.014,0.024,0.024)),Vector3(side*0.103,0.015,-0.045)),EYE)
	_beak(head,Vector3(0,-0.025,-0.08),0.026,0.08,c.beak)
	var out := {"body":body.commit(),"head":head.commit(),"folded":[],"spread":[]}
	for side: float in [-1.0,1.0]:
		var tucked := SurfaceTool.new()
		tucked.begin(Mesh.PRIMITIVE_TRIANGLES)
		_carved(tucked,WING_PROFILE,Transform3D(Basis.from_scale(Vector3(0.055,0.17,0.27)),Vector3.ZERO),c.wing)
		out.folded.append(tucked.commit())
		var open := SurfaceTool.new()
		open.begin(Mesh.PRIMITIVE_TRIANGLES)
		_carved(open,WING_PROFILE,Transform3D(Basis.from_scale(Vector3(0.36,0.05,0.23)),Vector3(side*0.15,0,0)),c.wing)
		out.spread.append(open.commit())
	_meshes[kind] = out
	return out

## The study's carved piece: a profile (y, z) extruded across x with bevelled
## ends, so it keeps broad flat sides and a crisp silhouette at small sizes.
static func _carved(tool: SurfaceTool, profile: Array, at: Transform3D, color: String) -> void:
	var vertices: Array[Vector3] = []
	for ring in range(4):
		var x: float = [-0.5,-0.34,0.34,0.5][ring]
		var inset := 0.76 if ring in [0,3] else 1.0
		for point: Vector2 in profile:
			vertices.append(Vector3(x,point.x*inset,point.y*inset))
	var count := profile.size()
	var tint := Color(color).srgb_to_linear()
	var centre := Vector3.ZERO
	for ring in range(3):
		for i in range(count):
			var a := ring*count+i
			var b := ring*count+(i+1)%count
			_face(tool,at,vertices[a],vertices[b],vertices[b+count],centre,tint)
			_face(tool,at,vertices[a],vertices[b+count],vertices[a+count],centre,tint)
	for i in range(1,count-1):
		_face(tool,at,vertices[0],vertices[i],vertices[i+1],centre,tint)
		_face(tool,at,vertices[3*count],vertices[3*count+i],vertices[3*count+i+1],centre,tint)

## A four-sided beak from `base` (its back) pointing -z.
static func _beak(tool: SurfaceTool, base: Vector3, radius: float, length: float, color: String) -> void:
	var tint := Color(color).srgb_to_linear()
	var tip := base+Vector3(0,0,-length)
	var ring: Array[Vector3] = []
	for i in range(4):
		var angle := TAU*i/4.0+PI*0.25
		ring.append(base+Vector3(cos(angle)*radius,sin(angle)*radius,0))
	var middle := base+Vector3(0,0,-length*0.3)
	for i in range(4):
		_face(tool,Transform3D.IDENTITY,ring[i],ring[(i+1)%4],tip,middle,tint)
		_face(tool,Transform3D.IDENTITY,ring[i],ring[(i+1)%4],base,middle,tint)

## One flat triangle facing away from `centre`, wound clockwise for Godot.
static func _face(tool: SurfaceTool, at: Transform3D, a: Vector3, b: Vector3, c: Vector3, centre: Vector3, tint: Color) -> void:
	var pa := at*a
	var pb := at*b
	var pc := at*c
	var normal := (pb-pa).cross(pc-pa).normalized()
	if normal.dot((pa+pb+pc)/3.0-at*centre) < 0.0: normal = -normal
	else:
		var swap := pb
		pb = pc
		pc = swap
	tool.set_normal(normal)
	tool.set_color(tint)
	for p in [pa,pb,pc]: tool.add_vertex(p)
