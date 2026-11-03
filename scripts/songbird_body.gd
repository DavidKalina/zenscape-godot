extends Node3D
## One songbird's body (docs/scenic/songbirds.md): a simple, smooth woodland
## bird in four meshes per species: body (a teardrop with a soft breast tone
## and a small tail fan), head (a ball with a tiny beak, round about its
## pivot so it turns without a seam), and a folded and a spread wing each
## side (thin curved blades). The feet are the origin; it faces -z.
## scripts/songbirds.gd moves it; this only poses it.
##
## Built at the study's size and scaled by SIZE, so it stands about 15 cm.
const SIZE := 0.42
## sRGB colours by species, muted to sit with the land.
const SPECIES := {
	"sparrow":{"title":"House sparrow","body":"8c6c4e","head":"7d6450","wing":"6a4f37","breast":"b49c80","tail":"5c4431","beak":"8a7a66","legs":"5b4a3a"},
	"robin":{"title":"Robin","body":"7a6752","head":"7a6752","wing":"6a5845","breast":"c7663f","tail":"5f4f40","beak":"3a3330","legs":"6b5847"},
	"goldfinch":{"title":"Goldfinch","body":"b89a52","head":"c8a948","wing":"3f3a33","breast":"d9c27a","tail":"34302b","beak":"d9c3a5","legs":"8a7a6a"},
	"starling":{"title":"Starling","body":"38302a","head":"302925","wing":"4e3826","breast":"5a4230","tail":"2a2421","beak":"6e5c3c","legs":"4a3a2c"},
}
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
	var pts: Array[Vector3] = []
	_teardrop(body,pts,c)
	_tail(body,pts,c.tail)
	body.generate_normals()
	var head := SurfaceTool.new()
	head.begin(Mesh.PRIMITIVE_TRIANGLES)
	_head(head,c)
	head.generate_normals()
	var out := {"body":body.commit(),"head":head.commit(),"folded":[],"spread":[]}
	for side: float in [-1.0,1.0]:
		out.folded.append(_wing(_fold_basis(side),Vector3(0,0.012,-0.07),FOLD_SPAN,FOLD_CHORD,c.wing))
		out.spread.append(_wing(Basis.from_scale(Vector3(side,1,1)),Vector3.ZERO,WING_SPAN,1.0,c.wing))
	_meshes[kind] = out
	return out

## The spread wing's span out from the shoulder, and the folded wing's length
## and chord (over the spread one's).
const WING_SPAN := 0.38
const FOLD_SPAN := 0.28
const FOLD_CHORD := 0.6

## Wing space (x span out, y up, z back) to the folded wing: span back along
## the flank and a little down and in over the tail, chord down (leading
## edge on top), the upper face out.
static func _fold_basis(side: float) -> Basis:
	var lay := Basis(Vector3(0,0,1),Vector3(side,0,0),Vector3(0,-1,0))
	return Basis(Vector3.UP,-side*0.1)*Basis(Vector3.RIGHT,0.3)*lay

## One vertex: a place and a colour, kept in `pts` for winding.
static func _vert(tool: SurfaceTool, pts: Array[Vector3], p: Vector3, tint: Color) -> int:
	tool.set_color(tint)
	tool.add_vertex(p)
	pts.append(p)
	return pts.size()-1

## A triangle of indexed vertices facing `out`, wound clockwise for Godot.
static func _tri(tool: SurfaceTool, pts: Array[Vector3], a: int, b: int, c: int, out: Vector3) -> void:
	if (pts[b]-pts[a]).cross(pts[c]-pts[a]).dot(out) > 0.0:
		var t := b
		b = c
		c = t
	tool.add_index(a)
	tool.add_index(b)
	tool.add_index(c)

## A soft blend from `base` to the species' paler (or red) breast.
static func _belly(c: Dictionary, base: String, w: float) -> Color:
	return Color(base).srgb_to_linear().lerp(Color(c.breast).srgb_to_linear(),clampf(w,0.0,1.0))

## The body: a smooth teardrop round an axis pitched up to the head, its
## round end under the head and its taper under the tail; the breast tone
## soft on the front and belly.
static func _teardrop(tool: SurfaceTool, pts: Array[Vector3], c: Dictionary) -> void:
	const RINGS := 9
	const SEGS := 12
	var origin := Vector3(0,0.16,0.03)
	var fwd := Vector3(0,0.36,-1.0).normalized()
	var up := -fwd.cross(Vector3.RIGHT)
	if up.y < 0.0: up = -up
	var back := -0.23
	var front := 0.19
	var radius := 0.138
	# The axis bends up at the front, filling the nape under the head.
	var centre := func(u: float) -> Vector3: return origin+fwd*lerpf(back,front,u)+up*0.06*pow(u,2.5)
	var rear: Vector3 = centre.call(0.0)
	var tip: Vector3 = centre.call(1.0)
	var rear_pole := _vert(tool,pts,rear,_belly(c,c.body,0.0))
	var first := pts.size()
	for r in range(1,RINGS):
		var u := float(r)/RINGS
		var rad := radius*pow(sin(PI*pow(u,1.35)),0.8)
		var at: Vector3 = centre.call(u)
		for s in SEGS:
			var ang := TAU*s/SEGS
			var dir := Vector3.RIGHT*cos(ang)*0.92+up*sin(ang)
			var w := (1.0-smoothstep(-0.65,0.25,sin(ang)))*smoothstep(0.05,0.6,u)
			# Toward the head's colour where the body meets it.
			var nape := smoothstep(0.6,0.95,u)*smoothstep(-0.2,0.6,sin(ang))
			var tint := _belly(c,c.body,w).lerp(Color(c.head).srgb_to_linear(),nape)
			_vert(tool,pts,at+dir*rad,tint)
	var front_pole := _vert(tool,pts,tip,_belly(c,c.body,0.5))
	for s in SEGS:
		var s2 := (s+1)%SEGS
		_tri(tool,pts,rear_pole,first+s,first+s2,(pts[first+s]+pts[first+s2])*0.5-(rear+fwd*0.05))
		var l0 := first+(RINGS-2)*SEGS+s
		var l1 := first+(RINGS-2)*SEGS+s2
		_tri(tool,pts,l0,l1,front_pole,(pts[l0]+pts[l1])*0.5-(tip-fwd*0.05))
	for r in range(RINGS-2):
		for s in SEGS:
			var s2 := (s+1)%SEGS
			var a0 := first+r*SEGS+s
			var a1 := first+r*SEGS+s2
			var b0 := first+(r+1)*SEGS+s
			var b1 := first+(r+1)*SEGS+s2
			var mid: Vector3 = (pts[a0]+pts[b1])*0.5
			var out: Vector3 = mid-(centre.call(float(r+1)/RINGS)+centre.call(float(r+2)/RINGS))*0.5
			_tri(tool,pts,a0,b0,b1,out)
			_tri(tool,pts,a0,b1,a1,out)

## The tail: a small flat fan from under the rump, rounded at its end.
static func _tail(tool: SurfaceTool, pts: Array[Vector3], color: String) -> void:
	const STEPS := 5
	var tint := Color(color).srgb_to_linear()
	var root := Vector3(0,0.125,0.16)
	var tilt := Basis(Vector3.RIGHT,0.12)
	var rim: Array[Vector3] = []
	for i in STEPS+1:
		var f := float(i)/STEPS
		var ang := lerpf(-0.42,0.42,f)
		var length := 0.21*(0.94+0.06*cos(ang*3.0))
		rim.append(root+tilt*Vector3(sin(ang)*length+0.025*(f*2.0-1.0),0,cos(ang)*length))
	var thick := 0.008
	for face: float in [1.0,-1.0]:
		var normal := tilt*Vector3(0,face,0)
		var hub := _vert(tool,pts,root+normal*thick,tint)
		var start := pts.size()
		for p in rim: _vert(tool,pts,p,tint)
		for i in STEPS: _tri(tool,pts,hub,start+i,start+i+1,normal)

## The head: a smooth ball with a soft throat tone and a tiny beak.
static func _head(tool: SurfaceTool, c: Dictionary) -> void:
	const LAT := 6
	const LON := 12
	var r := Vector3(0.097,0.095,0.105)
	var pts: Array[Vector3] = []
	var shade := func(p: Vector3) -> Color:
		var d := p.normalized()
		return _belly(c,c.head,(1.0-smoothstep(-0.75,-0.05,d.y))*(1.0-smoothstep(-0.5,0.3,d.z))*0.9)
	var top := _vert(tool,pts,Vector3(0,r.y,0),shade.call(Vector3.UP))
	for la in range(1,LAT):
		var th := PI*la/LAT
		for lo in LON:
			var ph := TAU*lo/LON
			var p := Vector3(sin(th)*cos(ph)*r.x,cos(th)*r.y,sin(th)*sin(ph)*r.z)
			_vert(tool,pts,p,shade.call(p))
	var bottom := _vert(tool,pts,Vector3(0,-r.y,0),shade.call(Vector3.DOWN))
	for lo in LON:
		var l2 := (lo+1)%LON
		_tri(tool,pts,top,1+lo,1+l2,pts[1+lo]+pts[1+l2])
		var b0 := 1+(LAT-2)*LON+lo
		var b1 := 1+(LAT-2)*LON+l2
		_tri(tool,pts,bottom,b0,b1,pts[b0]+pts[b1])
	for la in range(LAT-2):
		for lo in LON:
			var l2 := (lo+1)%LON
			var a0 := 1+la*LON+lo
			var a1 := 1+la*LON+l2
			var b0 := 1+(la+1)*LON+lo
			var b1 := 1+(la+1)*LON+l2
			_tri(tool,pts,a0,b0,b1,pts[a0]+pts[b1])
			_tri(tool,pts,a0,b1,a1,pts[a0]+pts[b1])
	# The beak: a small five-sided cone, its base sunk in the face.
	var tint := Color(c.beak).srgb_to_linear()
	var base := Vector3(0,-0.016,-0.085)
	var first := pts.size()
	for i in 5:
		var a := TAU*i/5.0+PI*0.5
		_vert(tool,pts,base+Vector3(cos(a)*0.022,sin(a)*0.018,0),tint)
	var point := _vert(tool,pts,base+Vector3(0,-0.006,-0.055),tint)
	for i in 5:
		var a := first+i
		var b := first+(i+1)%5
		_tri(tool,pts,a,b,point,(pts[a]+pts[b])*0.5-base)

## A wing in wing space (x span out from the shoulder, y up, z back): a thin
## cambered blade with an elliptical, slightly swept outline, rounded at the
## tip; `place` turns (and mirrors) it, `at` moves it, `chord_k` narrows it.
static func _wing(place: Basis, at: Vector3, span: float, chord_k: float, color: String) -> ArrayMesh:
	const SPAN_N := 7
	const CHORD_N := 2
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint := Color(color).srgb_to_linear()
	var pts: Array[Vector3] = []
	# Each station is a ring: the leading edge, the top, the trailing edge
	# (k = CHORD_N), the bottom.
	var ring := 2*CHORD_N
	for i in SPAN_N:
		var u := float(i)/(SPAN_N-1)*0.97
		var chord := maxf(0.24*chord_k*(1.0-0.45*u)*sqrt(maxf(0.0,1.0-pow(u,3.0))),0.012)
		var lead := -0.3*chord+0.08*u*u
		var thick := 0.024*(1.0-0.7*u)
		for k in ring:
			var t := float(k)/CHORD_N if k <= CHORD_N else float(ring-k)/CHORD_N
			var y := sin(PI*t)*(thick*0.75 if k <= CHORD_N else -thick*0.25)
			var p := Vector3(u*span,0.03*u*u+y+sin(PI*t)*0.01,lead+t*chord)
			_vert(tool,pts,place*p+at,tint)
	for i in SPAN_N-1:
		for k in ring:
			var a0 := i*ring+k
			var a1 := i*ring+(k+1)%ring
			var b0 := (i+1)*ring+k
			var b1 := (i+1)*ring+(k+1)%ring
			var out: Vector3 = place*(Vector3.UP if k < CHORD_N else Vector3.DOWN)
			_tri(tool,pts,a0,b0,b1,out)
			_tri(tool,pts,a0,b1,a1,out)
	for end in [0,SPAN_N-1]:
		var o: int = end*ring
		var out: Vector3 = place*Vector3(-1.0 if end == 0 else 1.0,0,0)
		for k in range(1,ring-1):
			_tri(tool,pts,o,o+k,o+k+1,out)
	tool.generate_normals()
	return tool.commit()
